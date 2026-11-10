"""生成したPCKの配布境界と実行用データを確認する。引数はPCKのパス。"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import struct
import sys
from pathlib import Path


def inspect(path: Path, runtime_package=False) -> dict:
    data = path.read_bytes()
    assert data[:4] == b"GDPC", "PCKの先頭にヘッダーが必要"
    version, _, _, _, flags, base = struct.unpack_from("<5IQ", data, 4)
    # Godot 4.7の通常PCK v4はv3と同じファイル索引を使う。
    assert version in (2, 3, 4) and not flags & 5, "暗号化・sparse bundleなしのPCK v2/v3/v4を検査する"
    position = struct.unpack_from("<Q", data, 32)[0] if version >= 3 else 96
    count = struct.unpack_from("<I", data, position)[0]
    position += 4
    files = {}
    for _ in range(count):
        length = struct.unpack_from("<I", data, position)[0]
        position += 4
        name = data[position:position + length].rstrip(b"\0").decode().replace("res://", "", 1)
        position += length
        offset, size = struct.unpack_from("<QQ", data, position)
        position += 36
        files[name] = data[base + offset:base + offset + size]
    excluded = ("gyms/", "tests/", "tools/", "scripts/dev/", ".content/dev/",
                "addons/content_build/", "addons/spawn_timeline/",
                "addons/speed_data_editor/", "addons/stage_launcher/",
                "addons/stage_enemy_tuning/", "addons/boss_flow/")
    forbidden = [name for name in files if name.startswith(excluded)]
    assert not forbidden, f"開発用ファイルが残っている: {forbidden}"
    assert b"autoload/DevBootstrap" not in files["project.binary"], "開発用Autoloadを除外"
    assert not any(name.startswith("addons/limboai/") for name in files), "廃止した拡張を含めない"
    assert ".content/boss_monoceros.tres" in files, "一角獣の生成AIを含める"
    assert ".content/boss_hydra.tres" in files, "生成したボスAIを含める"
    assert ".content/boss_preview.tres" not in files, "試遊用の編集結果を配布へ含めない"
    assert ".content/visual_index.tres" in files, "生成済みの外観索引を含める"
    assert not any(name.startswith("scripts/render/armor_paint.gd") for name in files), "実行時の装甲解析を残さない"
    for look in re.findall(r'"(res://\.content/look_[^"\n]+\.res)"', files[".content/visual_index.tres"].decode()):
        assert look.replace("res://", "", 1) in files, f"生成済み外観の欠落: {look}"
    for index in range(1, 6):
        stage = files[f".content/stage_{index}.tres"].decode()
        assert not re.search(r'\[ext_resource type="Texture2D"[^\n]+background/', stage), "背景画像をステージへ直接結合しない"
        assert 'path="res://scripts/data_types/stage_resources.gd"' in stage and 'resources = SubResource(' in stage, f"ステージ{index}に資源一覧が必要"
        for dependency in re.findall(r'"(res://[^"\n]+)"', stage):
            name = dependency.replace("res://", "", 1)
            assert name in files or name + ".remap" in files or name + ".import" in files, f"配布から欠落: {dependency}"
    if runtime_package:
        for name in ["GODOT.txt", "GODOT-THIRD-PARTY.txt", "GODOT-CPP.txt", "dependencies.json"]:
            assert files.get("licenses/run/" + name), f"ライセンス・固定依存が必要: {name}"
        lock = json.loads(files["licenses/run/dependencies.json"])
        assert lock == json.loads((Path(__file__).resolve().parents[3] / "cpp/dependencies.json").read_text()), "固定依存を配布へ保持する"
        assert "extensions/run/run_core.gdextension" in files, "ラン拡張の接続定義を含める"
        indexes = [(f".content/run/stage_{stage}.json", stage) for stage in range(1, 6)]
        for index_path, stage in indexes:
            index = json.loads(files[index_path])
            assert index["format"] == 1 and index["stage_id"] == str(stage), "本番のステージ索引が必要"
            binary, resources = [index[key].replace("res://", "", 1) for key in ["binary", "resources"]]
            assert binary.startswith(".content/run/") and resources.startswith(".content/run/"), "本番生成物へ参照する"
            content = files[binary]
            assert content[24:56].hex() == index["input_sha256"] and content[56:88].hex() == index["payload_sha256"], "定義と索引のハッシュが一致する"
            assert hashlib.sha256(files[resources]).hexdigest() == index["resources_sha256"], "資源一覧と索引のハッシュが一致する"
            # dependenciesは制作入力の署名表で、配布時には読み込まない。
            resource_text = re.sub(r'(?ms)^dependencies = \{\n.*?^\}\n', '', files[resources].decode(), count=1)
            for dependency in re.findall(r'"(res://[^"\n]+)"', resource_text):
                name = dependency.replace("res://", "", 1)
                assert name in files or name + ".remap" in files or name + ".import" in files, f"ランの配布依存から欠落: {dependency}"
    print(f"[export_package] {count} files, 5 stages, OK")
    return files


def package(path: Path, platform: str, runtime: bool, script: Path, rendered=False, loading=False, final_runtime=False) -> None:
    packs = list(path.rglob("*.pck"))
    assert len(packs) == 1, "配布物にはPCKが1つ必要"
    files = inspect(packs[0], True)
    config = files["extensions/run/run_core.gdextension"].decode()
    if platform == "macos":
        libraries = list(path.glob("*.app/Contents/Frameworks/*speed_runtime*.dylib"))
        assert len(libraries) == 1, "Mac配布にはUniversalライブラリを1つ含める"
        library = libraries[0]
        subprocess.run(["lipo", str(library), "-verify_arch", "arm64", "x86_64"], check=True)
        assert config.count(".template_release.universal.dylib") == 2, "両CPUの参照先がUniversalで一致する"
        executables = list(path.glob("*.app/Contents/MacOS/*"))
        assert len(executables) == 1, "配布エンジンを確認する"
        engine = executables[0]
    else:
        libraries = list(path.rglob("speed_runtime.windows.template_release.x86_64.dll"))
        assert len(libraries) == 1, "WindowsのランDLLを同梱する"
        library = libraries[0]
        engine = path / "Speed.exe"
        assert engine.is_file(), "配布エンジンを確認する"
        wrappers = list(path.glob("*console.exe"))
        if wrappers: engine = wrappers[0]
    print(f"[export_package] {platform} 拡張・生成物・ライセンス OK")
    if not runtime and not final_runtime:
        return
    environment = os.environ.copy()
    executable = str(engine)
    if rendered:
        launcher = shutil.which("godot-bg")
        if launcher:
            executable = launcher
            environment["GODOT"] = str(engine)
    if runtime:
        command = [executable, *([] if rendered else ["--headless"]), "--log-file", str(path.parent / "runtime.log"), "--"]
        result = subprocess.run([*command, "--package-runtime"], env=environment, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180, cwd=path)
        print(result.stdout)
        assert result.returncode == 0 and "[package_runtime] OK" in result.stdout, "通常ランの開始と最小更新を最後まで実施する"
        # 元の配布物を保ち、DLLを抜いた別コピーで旧実装へのfallbackがないことを確かめる。
        with tempfile.TemporaryDirectory(prefix="speed-package-missing-") as temporary:
            missing = Path(temporary) / "export"
            shutil.copytree(path, missing)
            (missing / library.relative_to(path)).unlink()
            missing_engine = missing / engine.relative_to(path)
            missing_pack = missing / packs[0].relative_to(path)
            result = subprocess.run([str(missing_engine), "--headless", "--log-file", str(path.parent / "missing-runtime.log"), "--", "--package-missing-runtime"], text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180, cwd=missing)
            print(result.stdout)
            assert result.returncode == 0 and "[package_missing_runtime] OK" in result.stdout, "拡張欠落を開始失敗として確認する"
    if final_runtime:
        command = [executable, *([] if rendered else ["--headless"]), "--log-file", str(path.parent / "final-runtime.log"), "--", "--package-final-runtime"]
        result = subprocess.run(command, env=environment, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180, cwd=path)
        print(result.stdout)
        assert result.returncode == 0 and "[package_final_runtime] OK" in result.stdout, f"撤去後の通常出撃から自然な結果保存・戻るまでを確認する（終了コード {result.returncode}）"
    if loading:
        loading_command = [executable, "--log-file", str(path.parent / "loading.log"), "--", "--package-loading"]
        result = subprocess.run(loading_command, env=environment, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180, cwd=path)
        print(result.stdout)
        assert result.returncode == 0 and "[package_loading] OK" in result.stdout, "描画付き配布版で出撃準備と資源回収を確認する"



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--platform", choices=["macos", "windows"])
    parser.add_argument("--runtime", action="store_true")
    parser.add_argument("--rendered", action="store_true")
    parser.add_argument("--loading", action="store_true")
    parser.add_argument("--final-runtime", action="store_true")
    parser.add_argument("--script", type=Path, default=Path(__file__).resolve().parents[1] / "content/check_rules.gd")
    args = parser.parse_args()
    if args.rendered and (args.platform != "macos" or not (args.runtime or args.final_runtime)):
        parser.error("--rendered はMacの --runtime または --final-runtime と合わせて指定してください")
    if args.loading and not (args.rendered and (args.runtime or args.final_runtime)):
        parser.error("--loading はMacの --rendered と --runtime または --final-runtime に合わせて指定してください")
    if args.final_runtime and not args.platform:
        parser.error("--final-runtime は --platform と合わせて指定してください")
    if args.platform:
        package(args.path.resolve(), args.platform, args.runtime, args.script, args.rendered, args.loading, args.final_runtime)
    else:
        inspect(args.path)
