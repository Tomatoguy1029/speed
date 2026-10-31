#!/usr/bin/env python3
"""Prepare the existing 64-cubed explosion noise for hardware 3D sampling.

Run during authoring, without Godot. Preserve every lattice value and slice;
the sampler replaces the shader's eight lookups and trilinear interpolation.
"""
import hashlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/effects/build/value_noise.png"
OUTPUT = ROOT / "assets/effects/build/burst_noise_volume.png"
MANIFEST = ROOT / "assets/effects/build/burst_noise.tres"
VERSION = 1


def resource_path(path):
    return "res://" + path.relative_to(ROOT).as_posix()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bake():
    with Image.open(SOURCE) as image:
        if image.mode != "L" or image.size != (512, 512):
            raise ValueError("Expected the original 8-by-8 atlas of 64-by-64 L8 slices")
        image.save(OUTPUT, compress_level=9)
    path = resource_path(OUTPUT)
    imported = "res://.godot/imported/" + OUTPUT.name + "-" + hashlib.md5(path.encode()).hexdigest() + ".ctex3d"
    settings = OUTPUT.with_suffix(".png.import")
    settings.write_text(f'''[remap]

importer="3d_texture"
type="CompressedTexture3D"
path="{imported}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{path}"
dest_files=["{imported}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/channel_pack=1
mipmaps/generate=false
mipmaps/limit=-1
slices/horizontal=8
slices/vertical=8
''')
    inputs = [SOURCE, Path(__file__).resolve()]
    outputs = [OUTPUT]
    lines = ['[gd_resource type="Resource" load_steps=2 format=3]', '',
             f'[ext_resource type="Texture3D" path="{path}" id="1_noise"]', '',
             '[resource]', f'metadata/bake_version = {VERSION}',
             'metadata/texture = ExtResource("1_noise")']
    for name, paths in [("inputs", inputs), ("outputs", outputs)]:
        entries = [f'"{resource_path(item)}": "{digest(item)}"' for item in paths]
        lines.append(f'metadata/{name} = {{' + ", ".join(entries) + "}")
    # Only the sampling/import contract is fixed; the editor may add an import UID.
    lines.append('metadata/slices = Vector3i(64, 64, 64)')
    MANIFEST.write_text("\n".join(lines) + "\n")
    print(f"Baked {path}: 64 x 64 x 64 L8, 262144 texel bytes, linear/repeat, no mipmaps")


if __name__ == "__main__":
    bake()
