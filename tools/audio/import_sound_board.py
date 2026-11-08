#!/usr/bin/env python3
"""共有の音づけ表の内容を Godot の音の表へ取り込む。

入力は音づけ表の欄（slots の文書を1欄1ファイルの JSON にしたもの）と、上げられた音（素材ID.json）。
効果音は使う範囲で切り出して speed/assets/audio/sfx/board/<欄ID>.wav に、曲はそのまま
speed/assets/audio/music/board/<欄ID>.<拡張子> に置く。曲の範囲とループは実行時に当てる。
既存の素材と同じ音を切らずに使う欄は、既存の素材をそのまま参照する。
欄の一覧を speed/scripts/data_types/sound_slots.gd に書き出し、Godot で import してから
speed/tools/audio/apply_sound_board.gd で speed/assets/audio/sound_table.tres を上書きする。

音の変換は macOS の afconvert を使う。Godot は無音で起動する。
"""
import argparse
import base64
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
SFX_BOARD = "assets/audio/sfx/board"
MUSIC_BOARD = "assets/audio/music/board"
# 素材のない間だけ鳴らす仮の合成音（開始Hz・終了Hz・秒・波形）。素材に差し替えたら使わない。
SYNTH = {
    "growth.level.levelup_step": (440.0, 880.0, 0.25, "sine"),
    "ship.combat.hit": (520.0, 260.0, 0.06, "square"),
    "weapon.blaster.hit": (700.0, 500.0, 0.04, "square"),
    "elite.shield.block": (180.0, 140.0, 0.08, "square"),
    "elite.shield.reflect": (180.0, 140.0, 0.08, "square"),
    "elite.shield.stolen": (880.0, 1200.0, 0.05, "sine"),
    "boss.common.roar": (90.0, 38.0, 1.0, "saw"),
    "boss.common.explode": (120.0, 30.0, 0.5, "noise"),
}


def load_slots(folder: Path) -> list[dict]:
    slots = []
    for path in sorted(folder.rglob("*.json")):
        doc = json.loads(path.read_text(encoding="utf-8"))
        data = doc.get("data", doc) if isinstance(doc, dict) else None
        if not isinstance(data, dict) or "group" not in data:
            continue
        data = dict(data)
        data["_id"] = doc.get("id") or path.stem
        slots.append(data)
    slots.sort(key=lambda d: (d.get("order", 1e9), d["_id"]))
    if not slots:
        sys.exit(f"欄が見つかりません: {folder}")
    return slots


def gd_string(text: str) -> str:
    return json.dumps(text, ensure_ascii=False)


def write_slot_list(slots: list[dict], project: Path) -> None:
    lines = [
        "## 音の欄の一覧。共有の音づけ表から tools/audio/import_sound_board.py が書き出す。手で直さない。",
        "## 各行: [欄ID, 分類, 項目, 欄の名前, 種類（sfx・music）, 鳴る時]",
        "extends RefCounted",
        "const ROWS := [",
    ]
    for d in slots:
        row = [d["_id"], d["group_label"], d["section_label"], d["label"], d.get("kind", "sfx"), d.get("when", "")]
        lines.append("\t[" + ", ".join(gd_string(str(v)) for v in row) + "],")
    lines.append("]")
    (project / "scripts/data_types/sound_slots.gd").write_text("\n".join(lines) + "\n", encoding="utf-8")


def unpack(asset: Path) -> tuple[bytes, str]:
    pack = json.loads(asset.read_text(encoding="utf-8"))
    if pack.get("format") != "speed-audio":
        sys.exit(f"音のファイルの形式が違います: {asset}")
    return base64.b64decode(pack["data"]), Path(pack.get("name") or "sound.mp3").suffix.lower() or ".mp3"


def find_asset(folder: Path, asset_id: str) -> Path:
    for path in folder.glob(asset_id + "*"):
        return path
    sys.exit(f"上げられた音が見つかりません: {asset_id}")


def cut_sfx(raw: bytes, suffix: str, start: float, end: float, out: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / ("src" + suffix)
        src.write_bytes(raw)
        pcm = Path(tmp) / "pcm.wav"
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", str(src), str(pcm)], check=True)
        with wave.open(str(pcm), "rb") as reader:
            rate = reader.getframerate()
            frames = reader.getnframes()
            first = max(0, min(frames, int(round(start * rate))))
            last = frames if end <= 0 else max(first + 1, min(frames, int(round(end * rate))))
            reader.setpos(first)
            data = reader.readframes(last - first)
            params = reader.getparams()
        out.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(out), "wb") as writer:
            writer.setparams(params)
            writer.writeframes(data)


def uncut(d: dict) -> bool:
    """効果音の使う範囲が音全体のままなら True。"""
    end = number(d, "trim_end", 0.0)
    return number(d, "trim_start", 0.0) <= 0.0005 and (end <= 0.0 or end >= number(d, "duration", 0.0) - 0.0005)


def number(d: dict, key: str, default: float) -> float:
    value = d.get(key)
    return float(value) if isinstance(value, (int, float)) else default


def build_plan(slots: list[dict], assets: Path | None, project: Path) -> list[dict]:
    plan = []
    kept: set[Path] = set()
    for d in slots:
        sid, music = d["_id"], d.get("kind") == "music"
        row = {
            "id": sid,
            "stream": "",
            "silent": bool(d.get("silent", False)),
            "volume_db": number(d, "volume_db", 0.0),
            "pitch_min": number(d, "pitch_min", 1.0),
            "pitch_max": number(d, "pitch_max", 1.0),
            "max_voices": int(number(d, "max_voices", 0)),
            "loop": bool(d.get("loop", False)),
            "trim_start": 0.0,
            "trim_end": 0.0,
            "loop_start": number(d, "loop_start", 0.0),
        }
        if music:
            row["trim_start"] = number(d, "trim_start", 0.0)
            row["trim_end"] = number(d, "trim_end", 0.0)
        asset_id = d.get("asset") or ""
        if asset_id:
            if assets is None:
                sys.exit("--assets がありません: 上げられた音のある欄があります")
            raw, suffix = unpack(find_asset(assets, asset_id))
            folder = "music" if music else "sfx"
            original = project / "assets/audio" / folder / d["repo"] if d.get("repo") else None
            if original is not None and original.exists() and original.read_bytes() == raw and (music or uncut(d)):
                row["stream"] = f"res://assets/audio/{folder}/{d['repo']}"
            elif music:
                out = project / MUSIC_BOARD / (sid + suffix)
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_bytes(raw)
            else:
                out = project / SFX_BOARD / (sid + ".wav")
                cut_sfx(raw, suffix, number(d, "trim_start", 0.0), number(d, "trim_end", 0.0), out)
            if not row["stream"]:
                kept.add(out)
                row["stream"] = "res://" + out.relative_to(project).as_posix()
        elif d.get("repo"):
            folder = "music" if music else "sfx"
            row["stream"] = f"res://assets/audio/{folder}/{d['repo']}"
        if sid in SYNTH:
            row["synth"] = dict(zip(("from_hz", "to_hz", "seconds", "wave"), SYNTH[sid]))
        plan.append(row)
    for folder in (project / SFX_BOARD, project / MUSIC_BOARD):
        if not folder.exists():
            continue
        for path in folder.iterdir():
            if path.suffix != ".import" and path not in kept:
                path.unlink()
                Path(str(path) + ".import").unlink(missing_ok=True)
    return plan


def add_uids(project: Path) -> None:
    """保存した音の表の外部参照へ、参照先の uid を付ける。"""
    table = project / "assets/audio/sound_table.tres"
    lines = []
    for line in table.read_text(encoding="utf-8").splitlines():
        match = re.match(r'(\[ext_resource type="[^"]+") (path="res://([^"]+)".*)$', line)
        if match and " uid=" not in line:
            target = project / match.group(3)
            uid = ""
            if Path(str(target) + ".uid").exists():
                uid = Path(str(target) + ".uid").read_text(encoding="utf-8").strip()
            elif Path(str(target) + ".import").exists():
                found = re.search(r'^uid="([^"]+)"', Path(str(target) + ".import").read_text(encoding="utf-8"), re.M)
                uid = found.group(1) if found else ""
            if uid:
                line = f'{match.group(1)} uid="{uid}" {match.group(2)}'
        lines.append(line)
    table.write_text("\n".join(lines) + "\n", encoding="utf-8")


def godot(project: Path, *args: str, timeout: int) -> None:
    command = [os.environ.get("GODOT", GODOT), "--headless", "--audio-driver", "Dummy", "--path", str(project), *args]
    subprocess.run(command, check=True, timeout=timeout)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--slots", required=True, type=Path, help="音づけ表の欄の JSON を置いたフォルダ")
    parser.add_argument("--assets", type=Path, help="上げられた音（素材ID.json）を置いたフォルダ")
    parser.add_argument("--project", type=Path, default=ROOT / "speed", help="Godot プロジェクトのフォルダ")
    args = parser.parse_args()
    if shutil.which("afconvert") is None:
        sys.exit("afconvert がありません（macOS で実行してください）")
    project = args.project.resolve()
    slots = load_slots(args.slots)
    write_slot_list(slots, project)
    plan = build_plan(slots, args.assets, project)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as handle:
        json.dump({"slots": plan}, handle, ensure_ascii=False)
        plan_path = handle.name
    try:
        godot(project, "--editor", "--import", timeout=1800)
        godot(project, "--script", "res://tools/audio/apply_sound_board.gd", "--", plan_path, timeout=300)
    finally:
        os.unlink(plan_path)
    add_uids(project)
    print(f"{len(plan)}欄を取り込みました（音あり {sum(1 for r in plan if r['stream'])}欄）")


if __name__ == "__main__":
    main()
