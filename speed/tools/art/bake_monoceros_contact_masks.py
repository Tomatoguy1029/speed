#!/usr/bin/env python3
"""一角獣の部位シートを、表示上の接触位置用アルファとして固定する。"""
from pathlib import Path
import hashlib
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'assets/effects/boss_contact/monoceros_masks.tres'
SOURCE = 'assets/pixel/monoceros/'
NAMES = ('layers/body_armor.png', 'layers/body_armor_base.png',
         'layers/body_armor_layered.png', 'layers/booster.png',
         'layers/head_armor.png', 'layers/head_armor_back.png',
         'layers/head_base.png', 'layers/head_base_back.png',
         'layers/head_gold_armor.png', 'layers/leg_armor.png',
         'layers/leg_base.png', 'layers/leg_root.png', 'horn/horn.png')
THRESHOLD = 60


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bake():
    inputs = {'res://tools/art/bake_monoceros_contact_masks.py': sha(Path(__file__))}
    entries = []
    for name in NAMES:
        path = ROOT / SOURCE / name
        resource = 'res://' + SOURCE + name
        inputs[resource] = sha(path)
        image = Image.open(path).convert('RGBA')
        alpha = image.getchannel('A').tobytes()
        # 角以外は不透明か透明。角は単一Spriteなので閾値以下の半透明も合成で増えない。
        allowed = (lambda value: value in (0, 255)) if name != 'horn/horn.png' else (lambda value: value <= THRESHOLD or value == 255)
        if any(not allowed(value) for value in alpha):
            raise ValueError('半透明の合成を再評価してください: ' + resource)
        bits = bytearray((image.width * image.height + 7) // 8)
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
    print('一角獣の部位マスク:', OUTPUT)


if __name__ == '__main__':
    bake()
