#!/usr/bin/env python3
"""猟犬の実画像合成から、飛びかかり炎に使う輪郭画素を固定する。"""
import hashlib
import json
import sys
from pathlib import Path
from bake_canis_fx import image

ROOT = Path(__file__).resolve().parents[2]

def main():
    if len(sys.argv) != 2:
        raise SystemExit('出力先を指定してください')
    paths = [Path(__file__).resolve(), ROOT / 'tools/art/bake_canis_fx.py', ROOT / 'data/visuals/looks/hound.tres']
    images = []
    for name in ('base.png', 'armor.png'):
        path = ROOT / 'assets/pixel/hound' / name
        paths.append(path)
        images.append(image(path))
    width, height, base = images[0]
    if images[1][:2] != (width,height): raise ValueError('画像のサイズが一致しません')
    armor = images[1][2]
    def on(x,y):
        if not (0<=x<width and 0<=y<height): return False
        a,b=base[y][x*4+3],armor[y][x*4+3]
        return b*255+a*(255-b)>80*255
    points=[]
    for y in range(height):
        for x in range(width):
            if on(x,y) and any(not on(x+dx,y+dy) for dx,dy in ((-1,0),(1,0),(0,-1),(0,1))):
                points.extend((x+.5-width/2,y+.5-height/2))
    inputs={'res://'+p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    Path(sys.argv[1]).write_text('[gd_resource type="Resource" format=3]\n\n[resource]\n'
        'metadata/version = 1\nmetadata/inputs = '+json.dumps(inputs,ensure_ascii=False,sort_keys=True)+'\n'
        'metadata/width = '+str(width)+'\nmetadata/height = '+str(height)+'\nmetadata/points = PackedVector2Array('
        +', '.join(str(n) for n in points)+')\n')

if __name__=='__main__': main()
