#!/usr/bin/env python3
"""猟犬の実画像から、シリウスの閃光が使う固定輪郭を生成する。"""
import hashlib
import json
import re
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOOK = ROOT / "data/visuals/looks/hound.tres"
OUTPUT = ROOT / "data/visuals/canis_nova_hull.tres"


def image(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"PNGではありません: {path}")
    width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", data[16:29])
    if (depth, color, compression, filtering, interlace) != (8, 6, 0, 0, 0):
        raise ValueError(f"8bit RGBAのPNGが必要です: {path}")
    offset, chunks = 8, bytearray()
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        if kind == b"IDAT":
            chunks.extend(data[offset + 8:offset + 8 + length])
        offset += 12 + length
        if kind == b"IEND":
            break
    raw = zlib.decompress(chunks)
    stride = width * 4
    if len(raw) != height * (stride + 1):
        raise ValueError(f"画像の長さが不正です: {path}")
    previous, rows, offset = bytearray(stride), [], 0
    for _ in range(height):
        mode = raw[offset]
        row = bytearray(raw[offset + 1:offset + stride + 1])
        offset += stride + 1
        if mode > 4:
            raise ValueError(f"未対応のPNGフィルターです: {path}")
        for i in range(stride):
            left = row[i - 4] if i >= 4 else 0
            above = previous[i]
            upper_left = previous[i - 4] if i >= 4 else 0
            if mode == 1:
                value = left
            elif mode == 2:
                value = above
            elif mode == 3:
                value = (left + above) // 2
            elif mode == 4:
                p = left + above - upper_left
                a, b, c = abs(p - left), abs(p - above), abs(p - upper_left)
                value = left if a <= b and a <= c else above if b <= c else upper_left
            else:
                value = 0
            row[i] = (row[i] + value) & 255
        rows.append(row)
        previous = row
    return width, height, rows


def hull(points):
    points = sorted(set(points))

    def half(items):
        result = []
        for point in items:
            while len(result) > 1:
                a, b = result[-2:]
                cross = (b[0] - a[0]) * (point[1] - b[1]) - (b[1] - a[1]) * (point[0] - b[0])
                if cross > 0:
                    break
                result.pop()
            result.append(point)
        return result[:-1]

    return half(points) + half(reversed(points))


def main():
    text = LOOK.read_text()
    refs = {ident: path for path, ident in re.findall(r'\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"\]', text)}
    layers = []
    for field in ("base", "armor"):
        match = re.search(r'^' + field + r' = ExtResource\("([^"]+)"\)', text, re.M)
        if not match or match[1] not in refs or not refs[match[1]].startswith("res://"):
            raise ValueError(f"猟犬の{field}画像がありません")
        layers.append(ROOT / refs[match[1]][6:])
    width, height, base = image(layers[0])
    armor_width, armor_height, armor = image(layers[1])
    if (width, height) != (armor_width, armor_height) or width % 2 or height % 2:
        raise ValueError("猟犬の画像寸法が一致しないか、中心が半画素です")
    points = []
    for y in range(height):
        for x in range(width):
            i = x * 4 + 3
            a, b = base[y][i], armor[y][i]
            if b * 255 + a * (255 - b) >= 128 * 255:
                points.extend(((x - width // 2, y - height // 2), (x + 1 - width // 2, y + 1 - height // 2)))
    polygon = hull(points)
    if len(polygon) < 3:
        raise ValueError("猟犬の輪郭を生成できません")
    inputs = [Path(__file__).resolve(), LOOK]
    for path in layers:
        inputs.extend((path, path.with_suffix(".png.import")))
    hashes = {"res://" + p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    canonical = "".join(f"{x},{y};" for x, y in polygon)
    coordinates = ", ".join(str(value) for point in polygon for value in point)
    output = ('[gd_resource type="Resource" format=3]\n\n[resource]\n'
              'metadata/bake_version = 1\n'
              f'metadata/inputs = {json.dumps(hashes, ensure_ascii=False, sort_keys=True)}\n'
              f'metadata/source_width = {width}\nmetadata/source_height = {height}\n'
              f'metadata/hull = PackedVector2Array({coordinates})\n'
              f'metadata/hull_sha256 = "{hashlib.sha256(canonical.encode()).hexdigest()}"\n')
    OUTPUT.write_text(output)
    print(f"猟犬の閃光用輪郭: {len(polygon)}点")


if __name__ == "__main__":
    main()
