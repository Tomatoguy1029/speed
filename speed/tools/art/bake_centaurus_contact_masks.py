#!/usr/bin/env python3
"""ケンタウルスの各シートから、表示上の接触位置用アルファを固定する。"""
from pathlib import Path
import hashlib
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/pixel/centaurus'
OUTPUT = ROOT / 'assets/effects/boss_contact/centaurus_masks.tres'
NAMES = ('base.png', 'armor.png', 'bow.png')
THRESHOLD = 60


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bake():
    inputs = {'res://tools/art/bake_centaurus_contact_masks.py': sha(Path(__file__))}
    entries = []
    for name in NAMES:
        path = SOURCE / name
        resource = 'res://assets/pixel/centaurus/' + name
        inputs[resource] = sha(path)
        image = Image.open(path).convert('RGBA')
        alpha = image.getchannel('A').tobytes()
        bits = bytearray((len(alpha) + 7) // 8)
        for index, value in enumerate(alpha):
            if value > THRESHOLD:
                bits[index // 8] |= 1 << (index % 8)
        entries.append('"%s": {"width": %d, "height": %d, "bits": PackedByteArray(%s)}' %
                       (resource, image.width, image.height, ', '.join(map(str, bits))))
    quoted = ', '.join('"%s": "%s"' % item for item in sorted(inputs.items()))
    text = ('[gd_resource type="Resource" format=3]\n\n[resource]\n'
            'metadata/version = 1\nmetadata/threshold = %d\nmetadata/inputs = {%s}\n'
            'metadata/sheets = {\n%s\n}\n' % (THRESHOLD, quoted, ',\n'.join(entries)))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(text)
    print('ケンタウルスの部位マスク:', OUTPUT)


if __name__ == '__main__':
    bake()
