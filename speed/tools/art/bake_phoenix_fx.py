#!/usr/bin/env python3
"""鳳凰の実画像のアルファから、ぼかし前の影素材を作る。"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
INPUTS = [ROOT / 'assets/pixel/phoenix' / f'phoenix_{name}.png'
          for name in ('base', 'decoration', 'armor')]
OUT = ROOT / 'assets/effects/reference/phoenix_shadow.png'
META = ROOT / 'assets/effects/reference/phoenix_shadow.tres'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def res(path):
    return 'res://' + path.relative_to(ROOT).as_posix()


def bake():
    images = [Image.open(path).convert('RGBA') for path in INPUTS]
    if any(image.size != (137, 94) for image in images):
        raise ValueError('鳳凰の素材サイズが異なります')
    combined = images[0]
    for image in images[1:]:
        combined = Image.alpha_composite(combined, image)
    shadow = Image.new('RGBA', (177, 134), (26, 6, 8, 0))
    alpha = Image.new('L', shadow.size, 0)
    alpha.paste(combined.getchannel('A'), (20, 20))
    shadow.putalpha(alpha)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    shadow.save(OUT)
    asset = res(OUT)
    digest = hashlib.md5(asset.encode()).hexdigest()
    cache = f'res://.godot/imported/{OUT.name}-{digest}.ctex'
    settings = OUT.with_suffix('.png.import')
    settings.write_text(f"""[remap]
importer="texture"
type="CompressedTexture2D"
path="{cache}"

[deps]
source_file="{asset}"
dest_files=["{cache}"]

[params]
compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=false
""")
    inputs = {res(Path(__file__).resolve()): sha(Path(__file__))}
    inputs.update({res(path): sha(path) for path in INPUTS})
    inputs[res(settings)] = sha(settings)
    META.write_text('\n'.join([
        '[gd_resource type="Resource" load_steps=2 format=3]', '',
        f'[ext_resource type="Texture2D" path="{asset}" id="1"]', '',
        '[resource]', 'metadata/bake_version = 1',
        'metadata/inputs = ' + json.dumps(inputs, sort_keys=True),
        'metadata/outputs = ' + json.dumps({asset: sha(OUT)}, sort_keys=True),
        'metadata/texture = ExtResource("1")',
        'metadata/source_size = Vector2i(137, 94)',
        'metadata/padding = 20', '',
    ]))
    print('鳳凰の影を生成しました:', OUT)


if __name__ == '__main__':
    bake()
