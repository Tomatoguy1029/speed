#!/usr/bin/env python3
"""おおいぬの実画像から接触位置用アルファを固定する。"""
import hashlib
import json
import sys
from pathlib import Path
from bake_canis_fx import image

ROOT = Path(__file__).resolve().parents[2]
NAMES = ('body', 'head', 'leg_back', 'leg_front', 'tail')

def main():
    if len(sys.argv) != 2:
        raise SystemExit('出力先を指定してください')
    paths = [Path(__file__).resolve(), ROOT / 'tools/art/bake_canis_fx.py']
    sheets = []
    for name in NAMES:
        path = ROOT / 'assets/pixel/canis_major' / (name + '.png')
        paths.append(path)
        width, height, rows = image(path)
        bits = bytearray((width * height + 7) // 8)
        for y, row in enumerate(rows):
            for x in range(width):
                if row[x * 4 + 3] > 60:
                    index = y * width + x
                    bits[index >> 3] |= 1 << (index & 7)
        resource = 'res://' + path.relative_to(ROOT).as_posix()
        sheets.append('%s: {"width": %d, "height": %d, "bits": PackedByteArray(%s)}' %
                      (json.dumps(resource), width, height, ', '.join(map(str, bits))))
    inputs = {'res://' + p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    text = ('[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/version = 1\n'
            'metadata/threshold = 60\nmetadata/inputs = %s\nmetadata/sheets = {\n%s\n}\n' %
            (json.dumps(inputs, ensure_ascii=False, sort_keys=True), ',\n'.join(sheets)))
    Path(sys.argv[1]).write_text(text)

if __name__ == '__main__':
    main()
