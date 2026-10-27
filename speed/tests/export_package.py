"""生成したPCKの配布境界と実行用データを確認する。引数はPCKのパス。"""
import re
import struct
import sys
from pathlib import Path


def inspect(path: Path) -> None:
    data = path.read_bytes()
    assert data[:4] == b"GDPC", "PCKの先頭にヘッダーが必要"
    version, _, _, _, flags, base = struct.unpack_from("<5IQ", data, 4)
    assert version in (2, 3) and not flags & 1, "暗号化なしのPCK v2/v3を検査する"
    position = struct.unpack_from("<Q", data, 32)[0] if version == 3 else 96
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
    print(f"[export_package] {count} files, 5 stages, OK")


if __name__ == "__main__":
    inspect(Path(sys.argv[1]))
