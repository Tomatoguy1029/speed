#!/usr/bin/env python3
"""Rebuild the authored biter partition offline; requires Pillow, never Godot."""
from pathlib import Path
import hashlib
import json
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PARTS = ROOT / "assets/pixel/biter/parts"
PIVOTS = {"body": (10, 17), "jaw_left": (6, 16), "jaw_right": (13, 16)}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def res(path):
    return "res://" + path.relative_to(ROOT).as_posix()


def main():
    inputs = {"res://data/visuals/looks/biter.tres": sha(ROOT / "data/visuals/looks/biter.tres")}
    output_hashes = {}
    paths = []
    for part in PIVOTS:
        mask_path = PARTS / part / "mask.png"
        inputs[res(mask_path)] = sha(mask_path)
        mask = Image.open(mask_path).convert("L")
        for layer in ["base", "armor", "normal"]:
            source = ROOT / "assets/pixel/biter" / (layer + ".png")
            inputs[res(source)] = sha(source)
            image = Image.open(source).convert("RGBA")
            if image.size != mask.size or image.size != (20, 34):
                raise ValueError("The authored partition requires the original 20x34 canvas")
            piece = Image.new("RGBA", image.size)
            piece.paste(image, (0, 0), mask)
            target = PARTS / part / (layer + ".png")
            piece.save(target)
            paths.append(target)
            output_hashes[res(target)] = sha(target)
            import_path = target.with_suffix(".png.import")
            if not import_path.exists():
                text = source.with_suffix(".png.import").read_text()
                text = re.sub(r'^uid="[^\n]+"\n', '', text, flags=re.M)
                source_res = res(source)
                target_res = res(target)
                cache = "res://.godot/imported/" + target.name + "-" + hashlib.md5(target_res.encode()).hexdigest() + ".ctex"
                text = re.sub(r'res://\.godot/imported/[^"\n]+', cache, text)
                import_path.write_text(text.replace(source_res, target_res))
    header = '[gd_resource type="Resource" load_steps=10 format=3]\n\n'
    refs = {}
    for index, path in enumerate(paths, 1):
        refs[(path.parent.name, path.stem)] = str(index)
        header += '[ext_resource type="Texture2D" path=%s id="%s"]\n' % (json.dumps(res(path)), index)
    entries = []
    for part, pivot in PIVOTS.items():
        fields = ['"name": ' + json.dumps(part), '"pivot": Vector2(%s, %s)' % pivot]
        for layer in ["base", "armor", "normal"]:
            fields.append('"%s": ExtResource("%s")' % (layer, refs[(part, layer)]))
        entries.append("{" + ", ".join(fields) + "}")
    body = '\n[resource]\nmetadata/bake_version = 1\nmetadata/source_size = Vector2(20, 34)\n'
    body += 'metadata/source_look = "res://data/visuals/looks/biter.tres"\n'
    body += 'metadata/inputs = ' + json.dumps(inputs, sort_keys=True, indent=0) + '\n'
    body += 'metadata/outputs = ' + json.dumps(output_hashes, sort_keys=True, indent=0) + '\n'
    body += 'metadata/parts = [' + ',\n'.join(entries) + ']\n'
    (ROOT / "data/visuals/biter_parts.tres").write_text(header + body)
    print("Baked body and two jaws: 9 maps, unchanged source canvas and authored pivots")


if __name__ == "__main__":
    main()
