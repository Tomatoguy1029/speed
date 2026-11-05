#!/usr/bin/env python3
"""試作と同じ可視アルファの輪郭を、制作時に EnemyLook ごとに保存する。"""
from pathlib import Path
import hashlib
import json
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/effects/reference/edges.tres'


def res(path):
    return 'res://' + path.relative_to(ROOT).as_posix()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bake():
    inputs = {res(Path(__file__).resolve()): sha(Path(__file__))}
    entries = {}
    for look in sorted((ROOT / 'data/visuals/looks').glob('*.tres')):
        text = look.read_text()
        refs = {ident: path for path, ident in re.findall(r'path="([^"]+)"[^\n]*id="([^"]+)"', text)}
        layers = []
        for field in ('base', 'decorations', 'armor'):
            found = re.search(r'^' + field + r' = ExtResource\("([^"]+)"\)', text, re.M)
            if found:
                path = ROOT / refs[found[1]][6:]
                inputs[res(path)] = sha(path)
                layers.append(Image.open(path).convert('RGBA'))
        if not layers:
            continue
        image = layers[0]
        for layer in layers[1:]:
            if layer.size != image.size:
                raise ValueError('外観の画像サイズが一致しません: ' + str(look))
            image = Image.alpha_composite(image, layer)
        inputs[res(look)] = sha(look)
        alpha = image.getchannel('A')
        w, h = image.size
        def on(x, y):
            return 0 <= x < w and 0 <= y < h and alpha.getpixel((x, y)) > 80
        points = []
        for y in range(h):
            for x in range(w):
                if on(x, y) and any(not on(x+dx, y+dy) for dx, dy in ((-1,0),(1,0),(0,-1),(0,1))):
                    points.extend((x+0.5-w/2, y+0.5-h/2))
        entries[res(look)] = (w, h, points)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    lines = ['[gd_resource type="Resource" format=3]', '', '[resource]',
             'metadata/bake_version = 1', 'metadata/inputs = ' + json.dumps(inputs, sort_keys=True),
             'metadata/edges = {']
    for key, (w, h, points) in entries.items():
        values = ', '.join(str(v) for v in points)
        lines.append(json.dumps(key) + ': {"size": Vector2i(%d, %d), "points": PackedVector2Array(%s)},' % (w, h, values))
    lines.extend(['}', ''])
    OUT.write_text('\n'.join(lines))
    print('外観の輪郭を生成しました:', len(entries))


if __name__ == '__main__':
    bake()
