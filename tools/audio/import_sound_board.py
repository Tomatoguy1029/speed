#!/usr/bin/env python3
"""共有の音づけ表の内容を Godot の音の表へ取り込む。

入力は音づけ表の欄（slots の文書を1欄1ファイルの JSON にしたもの）と、上げられた音（素材ID.json）。
効果音は使う範囲で切り出して speed/assets/audio/sfx/board/<欄ID>.wav に、曲はそのまま
speed/assets/audio/music/board/<欄ID>.<拡張子> に置く。曲の範囲とループは実行時に当てる。
既存の素材と同じ音を切らずに使う欄は、既存の素材をそのまま参照する。
プリセット（is_preset の文書）は欄の一覧に入れない。プリセットを使う欄は、プリセットの音と設定で鳴らし、
音のファイルはプリセットごとに1つだけ <プリセットID>.wav（曲はそのまま）に置いて共有する。
欄の一覧を speed/scripts/data_types/sound_slots.gd に書き出し、Godot で import してから
speed/tools/audio/apply_sound_board.gd で speed/assets/audio/sound_table.tres を上書きする。

音の変換は macOS の afconvert を使う。Godot は無音で起動する。
"""
import argparse
import array
import base64
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
SFX_BOARD = "assets/audio/sfx/board"
# 音の高さを変えない速さの範囲（音づけ表の SPEED_MIN・SPEED_MAX と同じ）
SPEED_MIN = 0.5
SPEED_MAX = 10.0
# りゅう座の決着の「叩き込む」で通り抜けるたびの欄。1発の音を連撃の各一撃の時刻へ並べた1本の音にして取り込む
RUSH_SLOT = "scene.finale.pass"
RUSH_DATA = "data/visuals/draco_finale_rush.tres"
RUSH_STRIDE = 9
# 重ねた音がこれを超えるときは全体を縮めて割れを防ぐ（16bit の最大の 98%）
RUSH_PEAK = 32767 * 0.98
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


# プリセットから欄へ写す値。音なし・ループするかどうかは欄ごとに持つ。
PRESET_KEYS = ("asset", "file_name", "duration", "trim_start", "trim_end", "volume_db", "pitch_min", "pitch_max", "max_voices", "loop_start", "fade_out", "fade_in", "speed")


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


def stretch(channels: list[list[float]], rate: int, speed: float) -> list[list[float]]:
    """音の高さを変えずに長さを 1/speed 倍にする（WSOLA）。音づけ表の試し聞きも同じ手順で伸び縮みさせる。"""
    if abs(speed - 1.0) < 1e-6 or not channels or not channels[0]:
        return channels
    size = max(64, int(round(0.04 * rate)) // 2 * 2)
    hop = size // 2
    tol = max(4, int(round(0.01 * rate)))
    window = [0.5 - 0.5 * math.cos(2.0 * math.pi * i / size) for i in range(size)]
    length = len(channels[0])
    mono = [sum(ch[i] for ch in channels) / len(channels) for i in range(length)]
    padded = mono + [0.0] * (size * 2 + tol * 2)
    out_len = int(math.ceil(length / speed))
    outs = [[0.0] * (out_len + size) for _ in channels]
    prev = 0
    k = 0
    while k * hop < out_len:
        natural = int(round(k * hop * speed))
        best = max(0, min(length - 1, natural))
        if k > 0:
            target = prev + hop
            best_score = None
            for step, lo, hi in ((4, natural - tol, natural + tol), (1, None, None)):
                if step == 1:
                    lo, hi = best - 3, best + 3
                for cand in range(lo, hi + 1, step):
                    if cand < 0 or cand >= length:
                        continue
                    score = 0.0
                    for i in range(0, hop, 4):
                        score += padded[cand + i] * padded[target + i]
                    if best_score is None or score > best_score:
                        best_score, best = score, cand
        at = k * hop
        for ch, out in zip(channels, outs):
            for i in range(size):
                src = best + i
                if src < length:
                    out[at + i] += ch[src] * window[i]
        prev = best
        k += 1
    return [out[:out_len] for out in outs]


def shape(channels: list[list[float]], rate: int, speed: float, fade_in: float, fade_out: float) -> list[list[float]]:
    """速さを変え、始まりと終わりの指定秒を直線で無音から・無音へつなぐ。"""
    channels = stretch(channels, rate, speed)
    count = len(channels[0]) if channels else 0
    if count and fade_in > 0.0:
        n = max(1, min(count, int(round(fade_in * rate))))
        for ch in channels:
            for i in range(n):
                ch[i] *= i / n
    if count and fade_out > 0.0:
        n = max(1, min(count, int(round(fade_out * rate))))
        for ch in channels:
            for i in range(n):
                ch[count - n + i] *= (n - 1 - i) / n
    return channels


def read_clip(raw: bytes, suffix: str, start: float, end: float) -> tuple[list[list[float]], int, tuple]:
    """音を 16bit の PCM にして使う範囲を切り出し、チャンネルごとの値の並びで返す。"""
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
    samples = array.array("h", data)
    if sys.byteorder == "big":
        samples.byteswap()
    n = params.nchannels
    return [[float(v) for v in samples[c::n]] for c in range(n)], rate, params


def write_wav(out: Path, channels: list[list[float]], params: tuple) -> None:
    n = len(channels)
    count = len(channels[0]) if channels else 0
    mixed = array.array("h", [0]) * (count * n)
    for c, ch in enumerate(channels):
        mixed[c::n] = array.array("h", (max(-32768, min(32767, int(round(v)))) for v in ch))
    if sys.byteorder == "big":
        mixed.byteswap()
    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), "wb") as writer:
        writer.setparams(params)
        writer.writeframes(mixed.tobytes())


def cut_sfx(raw: bytes, suffix: str, start: float, end: float, out: Path,
            speed: float = 1.0, fade_in: float = 0.0, fade_out: float = 0.0) -> None:
    """使う範囲を切り出し、速さとフェードを当てて 16bit の wav に書く。"""
    channels, rate, params = read_clip(raw, suffix, start, end)
    write_wav(out, shape(channels, rate, speed, fade_in, fade_out), params)


def resample(channels: list[list[float]], ratio: float) -> list[list[float]]:
    """ratio 倍の速さで読み進める（速さと音の高さが一緒に変わる。ゲームのピッチと同じ）。"""
    if abs(ratio - 1.0) < 1e-6:
        return channels
    length = len(channels[0])
    count = max(1, int(length / ratio))
    outs = []
    for ch in channels:
        out = [0.0] * count
        for i in range(count):
            x = i * ratio
            j = int(x)
            if j + 1 < length:
                f = x - j
                out[i] = ch[j] * (1.0 - f) + ch[j + 1] * f
            elif j < length:
                out[i] = ch[j]
        outs.append(out)
    return outs


def rush_hits(project: Path) -> list[tuple[float, float]]:
    """りゅう座の決着の連撃の、各一撃の時刻と次までの間隔。"""
    text = (project / RUSH_DATA).read_text(encoding="utf-8")
    found = re.search(r"^hits = PackedFloat32Array\(([^)]*)\)", text, re.M)
    if not found:
        sys.exit(f"連撃の時刻が読めません: {RUSH_DATA}")
    values = [float(v) for v in found.group(1).split(",")]
    return [(values[i], values[i + 1]) for i in range(0, len(values) - RUSH_STRIDE + 1, RUSH_STRIDE)]


def rush_progress(hits: list[tuple[float, float]], curve: str) -> list[float]:
    """各一撃の進み具合（0〜1）。"time" は時刻、それ以外は間隔の縮み具合で決める。"""
    if curve == "time":
        last = hits[-1][0] or 1.0
        return [t / last for t, _ in hits]
    first, final = hits[0][1], hits[-1][1]
    span = first - final or 1.0
    return [max(0.0, min(1.0, (first - g) / span)) for _, g in hits]


def bake_rush(raw: bytes, suffix: str, d: dict, hits: list[tuple[float, float]], out: Path) -> None:
    """1発の音を、連撃の各一撃の時刻へ、進み具合に合わせたピッチと速さで並べて1本の音にする。"""
    channels, rate, params = read_clip(raw, suffix, number(d, "trim_start", 0.0), number(d, "trim_end", 0.0))
    fade_in, fade_out = number(d, "fade_in", 0.0), number(d, "fade_out", 0.0)
    pitch = (number(d, "rush_pitch_from", 1.0), number(d, "rush_pitch_to", 1.0))
    speed = (number(d, "rush_speed_from", 1.0), number(d, "rush_speed_to", 1.0))
    progress = rush_progress(hits, str(d.get("rush_curve") or "gap"))
    parts = []
    for (t, _), u in zip(hits, progress):
        s = clamp(speed[0] + (speed[1] - speed[0]) * u, SPEED_MIN, SPEED_MAX)
        p = clamp(pitch[0] + (pitch[1] - pitch[0]) * u, 0.25, 4.0)
        one = resample(shape([list(ch) for ch in channels], rate, s, fade_in, fade_out), p)
        parts.append((int(round(t * rate)), one))
    total = max(at + len(one[0]) for at, one in parts)
    track = [[0.0] * total for _ in channels]
    for at, one in parts:
        for c, ch in enumerate(one):
            dst = track[c]
            for i, v in enumerate(ch):
                dst[at + i] += v
    peak = max((abs(v) for ch in track for v in ch), default=0.0)
    if peak > RUSH_PEAK:
        scale = RUSH_PEAK / peak
        track = [[v * scale for v in ch] for ch in track]
    write_wav(out, track, params)


def uncut(d: dict) -> bool:
    """効果音の使う範囲が音全体のままなら True。"""
    end = number(d, "trim_end", 0.0)
    return (number(d, "trim_start", 0.0) <= 0.0005 and (end <= 0.0 or end >= number(d, "duration", 0.0) - 0.0005)
            and number(d, "fade_out", 0.0) <= 0.0 and number(d, "fade_in", 0.0) <= 0.0
            and abs(number(d, "speed", 1.0) - 1.0) < 1e-6)


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def number(d: dict, key: str, default: float) -> float:
    value = d.get(key)
    return float(value) if isinstance(value, (int, float)) else default


# 取り込んだ時の値の印に使う値と、値がない時の値。音づけ表のページも同じ式で今の値の印を作り、
# 取り込み後に変わった欄を示す。
RECORD_KEYS = (("asset", ""), ("trim_start", 0), ("trim_end", 0), ("volume_db", 0), ("pitch_min", 1),
               ("pitch_max", 1), ("max_voices", 0), ("loop", False), ("loop_start", 0), ("silent", False),
               ("fade_out", 0), ("fade_in", 0), ("speed", 1), ("rush_pitch_from", 1), ("rush_pitch_to", 1),
               ("rush_speed_from", 1), ("rush_speed_to", 1), ("rush_curve", "gap"))


def record_sign(d: dict) -> str:
    parts = []
    for key, default in RECORD_KEYS:
        value = d.get(key)
        if value is None:
            value = default
        if isinstance(value, bool):
            parts.append("1" if value else "0")
        elif isinstance(value, (int, float)):
            parts.append(str(math.floor(value * 1000 + 0.5)))
        else:
            parts.append(str(value))
    return "|".join(parts)


def split_presets(docs: list[dict]) -> tuple[list[dict], dict[str, dict]]:
    """欄とプリセットに分け、プリセットを使う欄にプリセットの音と設定を写す。"""
    presets = {d["_id"]: d for d in docs if d.get("is_preset")}
    slots = []
    for d in docs:
        if d.get("is_preset"):
            continue
        preset = presets.get(d.get("preset") or "")
        if preset is not None:
            d = {k: v for k, v in d.items() if k not in PRESET_KEYS and k != "repo"}
            d.update({k: preset[k] for k in PRESET_KEYS if k in preset})
            d["_preset"] = preset["_id"]
            d["_preset_label"] = str(preset.get("label") or preset["_id"]).replace("/", "／")
        slots.append(d)
    if not slots:
        sys.exit("欄が見つかりません")
    return slots, presets


def build_plan(slots: list[dict], assets: Path | None, project: Path) -> list[dict]:
    plan = []
    kept: set[Path] = set()
    for d in slots:
        sid, music = d["_id"], d.get("kind") == "music"
        # プリセットの欄は、プリセットごとの1つのファイルを共有する
        name = sid if sid == RUSH_SLOT else (d.get("_preset") or sid)
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
            "preset": d.get("_preset_label", ""),
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
            if sid == RUSH_SLOT and not music:
                out = project / SFX_BOARD / (name + ".wav")
                bake_rush(raw, suffix, d, rush_hits(project), out)
                row["pitch_min"] = row["pitch_max"] = 1.0
                row["loop"] = False
            elif original is not None and original.exists() and original.read_bytes() == raw and (music or uncut(d)):
                row["stream"] = f"res://assets/audio/{folder}/{d['repo']}"
            elif music:
                out = project / MUSIC_BOARD / (name + suffix)
                if out not in kept:
                    out.parent.mkdir(parents=True, exist_ok=True)
                    out.write_bytes(raw)
            else:
                out = project / SFX_BOARD / (name + ".wav")
                if out not in kept:
                    looped = bool(d.get("loop"))
                    cut_sfx(raw, suffix, number(d, "trim_start", 0.0), number(d, "trim_end", 0.0), out,
                            clamp(number(d, "speed", 1.0), SPEED_MIN, SPEED_MAX),
                            0.0 if looped else number(d, "fade_in", 0.0), 0.0 if looped else number(d, "fade_out", 0.0))
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
    parser.add_argument("--record", type=Path, help="取り込んだ時の値の印を書き出す JSON（音づけ表の imports/last へ上げる）")
    args = parser.parse_args()
    if shutil.which("afconvert") is None:
        sys.exit("afconvert がありません（macOS で実行してください）")
    project = args.project.resolve()
    slots, presets = split_presets(load_slots(args.slots))
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
    if args.record:
        record = {"at": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "slots": {d["_id"]: record_sign(d) for d in slots}}
        args.record.write_text(json.dumps(record, ensure_ascii=False), encoding="utf-8")
    linked = sum(1 for r in plan if r["preset"])
    print(f"{len(plan)}欄を取り込みました（音あり {sum(1 for r in plan if r['stream'])}欄、プリセット {len(presets)}個を {linked}欄で使用）")


if __name__ == "__main__":
    main()
