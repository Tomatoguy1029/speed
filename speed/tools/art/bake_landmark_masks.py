#!/usr/bin/env python3
"""Bake checked-in landmark distance masks from the visible enemy alpha, without Godot.

Requires Pillow, NumPy and SciPy. Run from any directory. Enemy size/paint are
observations in the manifest; the mask remains in source pixels and shares the
body's runtime scale. This command writes only assets/effects/landmark/.
"""
from pathlib import Path
import hashlib
import json
import math
import re

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
from elite_contacts import PackedPoints, contacts_for

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/effects/landmark"
PAD = 32
# Unused enemy definitions remain in the catalog; these masks are outside the asset set.
EXCLUDED_CANDIDATES = ("clock", "missile", "spreader")
inputs = {}
entries = {}
observed_sizes = {}
fallback_shapes = {}
contact_entries = {}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resource_path(path):
    return "res://" + path.relative_to(ROOT).as_posix()


def source_text(path):
    inputs[resource_path(path)] = sha(path)
    return path.read_text()


def value(text, name, default=None):
    match = re.search(r"^" + re.escape(name) + r" = (.+)$", text, re.M)
    return match[1] if match else default


def look_alpha(name):
    path = ROOT / "data/visuals/looks" / (name + ".tres")
    text = source_text(path)
    refs = dict((ident, file) for file, ident in re.findall(
        r'\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"\]', text))
    alpha = None
    layers = []
    for field in ("base", "decorations", "armor"):
        match = re.search(r'^' + field + r' = ExtResource\("([^"]+)"\)', text, re.M)
        if not match:
            continue
        file = refs[match[1]]
        image = Image.open(ROOT / file[6:]).convert("RGBA")
        inputs[file] = sha(ROOT / file[6:])
        import_path = (ROOT / file[6:]).with_suffix(".png.import")
        if import_path.exists(): inputs[resource_path(import_path)] = sha(import_path)
        layer = np.array(image.getchannel("A")) > 0
        if alpha is not None and alpha.shape != layer.shape:
            raise ValueError("Mismatched layer dimensions: " + file)
        alpha = layer if alpha is None else alpha | layer
        layers.append(file)
    if alpha is None or not alpha.any():
        raise ValueError("Missing visible alpha: " + str(path))
    return alpha, layers, text


def encode(alpha):
    padded = np.pad(alpha, PAD)
    return np.clip(np.rint(distance_transform_edt(~padded) * 8), 0, 255).astype(np.uint8)


def bake(key, name, alpha, layers, extra=None):
    encoded = encode(alpha)
    channels = [encoded] * 3
    if extra and extra.get("pump"):
        # G/B keep the stationary front and deformable rear separate. The GPU
        # applies the same reservoir mapping as the body before reading B.
        front = alpha.copy()
        front[18:] = False
        rear = alpha.copy()
        rear[:18] = False
        channels = [encoded, encode(front), encode(rear)]
    image = Image.fromarray(np.stack(channels, axis=2), "RGB")
    file = OUTPUT / (name + ".png")
    # Preserve byte-identical existing masks, including their checked-in import identity.
    if not file.exists() or not np.array_equal(np.array(Image.open(file).convert("RGB")), np.array(image)):
        image.save(file)
    # Import configuration is a source asset. Godot creates its own cache later.
    digest = hashlib.md5(resource_path(file).encode()).hexdigest()
    cache = "res://.godot/imported/" + file.name + "-" + digest + ".ctex"
    if not file.with_suffix(".png.import").exists():
        file.with_suffix(".png.import").write_text(
            '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n'
            + 'path=' + json.dumps(cache) + '\n\n[deps]\nsource_file='
            + json.dumps(resource_path(file)) + '\ndest_files=[' + json.dumps(cache)
            + ']\n\n[params]\ncompress/mode=0\ncompress/normal_map=0\n'
            + 'mipmaps/generate=false\nprocess/fix_alpha_border=false\n'
            + 'process/premult_alpha=false\nprocess/size_limit=0\n')
    h, w = alpha.shape
    entry = {"file": resource_path(file), "source_size": (w, h),
             "texture_size": (w + PAD * 2, h + PAD * 2),
             "body_origin": (w / 2, h / 2), "mask_origin": (w / 2 + PAD, h / 2 + PAD),
             "source_radius": max(w, h) / 2, "padding": PAD,
             "mask_sha256": sha(file),
             "alpha_sha256": hashlib.sha256(alpha.tobytes()).hexdigest(),
             "layers": layers}
    entry.update(extra or {})
    entries[key] = entry
    contact_alpha = encoded[PAD:-PAD, PAD:-PAD] == 0
    groups = None
    if key == "res://data/visuals/looks/biter.tres":
        groups = []
        parts_text = source_text(ROOT / "data/visuals/biter_parts.tres")
        for part, name in enumerate(re.findall(r'"name": "([^"]+)"', parts_text)):
            mask = ROOT / "assets/pixel/biter/parts" / name / "mask.png"
            inputs[resource_path(mask)] = sha(mask)
            # Partition maps are CPU source bytes, independent of Godot's import UID/cache.
            groups.append((part, contact_alpha & (np.array(Image.open(mask).convert("L")) > 0)))
    contact_entries[key] = {"source_radius": entry["source_radius"],
                            "origin": entry["body_origin"],
                            "biter": key == "res://data/visuals/looks/biter.tres",
                            "pump": bool(entry.get("pump", False)),
                            "patterns": contacts_for(key, contact_alpha, groups)}


def placeholder(shape):
    # Match RunPresentation._placeholder_points and InstanceBatch's unit radius.
    # These are the existing polygon bodies, not substitute enemy artwork.
    if shape == "orb":
        points = [(math.cos(math.tau * i / 20), math.sin(math.tau * i / 20)) for i in range(20)]
    else:
        if shape != "square":
            raise ValueError("Unsupported actual placeholder shape: " + shape)
        points = [(0.8, -0.8), (0.8, 0.8), (-0.8, 0.8), (-0.8, -0.8)]
    yy, xx = np.mgrid[:64, :64]
    x, y = (xx + 0.5 - 32) / 32, (yy + 0.5 - 32) / 32
    inside = np.zeros((64, 64), dtype=bool)
    for (ax, ay), (bx, by) in zip(points, points[1:] + points[:1]):
        if ay != by:
            inside ^= ((ay > y) != (by > y)) & (x < (bx - ax) * (y - ay) / (by - ay) + ax)
    return inside, points


def gd(value):
    if isinstance(value, PackedPoints):
        return "PackedVector2Array(" + ", ".join(str(float(v)) for point in value for v in point) + ")"
    if isinstance(value, dict):
        return "{" + ",\n".join(json.dumps(k) + ": " + gd(v) for k, v in sorted(value.items())) + "}"
    if isinstance(value, tuple):
        return "Vector2(%s, %s)" % value
    if isinstance(value, list):
        return "[" + ", ".join(gd(v) for v in value) + "]"
    if isinstance(value, str) and value.startswith("EXT:"):
        return 'ExtResource("' + value[4:] + '")'
    return json.dumps(value)


def elite_candidates():
    result = set()
    for path in sorted((ROOT / "data/stages").glob("stage_*.tres")):
        text = path.read_text()
        match = re.search(r'^zako_curves = (.+)$', text, re.M)
        if not match:
            continue
        refs = re.findall(r'SubResource\("([^"]+)"\)', match[1])
        for ref in refs:
            block = re.search(r'\[sub_resource[^\n]*id="' + re.escape(ref) + r'"\]\n(.*?)(?=\n\[|\Z)', text, re.S)
            ident = value(block[1], "type", '&""').strip('&"') if block else ""
            definition = ROOT / "data/enemies" / (ident + ".tres")
            if definition.exists() and int(value(definition.read_text(), "max_alive", "0")) == 0:
                result.add(ident)
    return sorted(result)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source_text(ROOT / "shaders/pump_outline.gdshaderinc")
    source_text(ROOT / "tools/art/bake_landmark_masks.py")
    source_text(ROOT / "tools/art/elite_contacts.py")
    candidates = {}
    for path in sorted((ROOT / "data/enemies").glob("*.tres")):
        text = path.read_text()
        if path.stem not in EXCLUDED_CANDIDATES and 2 <= int(value(text, "rank", "0")) <= 5:
            candidates[path.stem] = text
    elites = [ident for ident in elite_candidates() if ident not in EXCLUDED_CANDIDATES]
    covered = dict(candidates)
    for ident in elites:
        covered[ident] = (ROOT / "data/enemies" / (ident + ".tres")).read_text()
    looks = set()
    for ident, text in covered.items():
        # Values are observed from the current working tree, never baked into alpha.
        size_text = value(text, "radius", "0") + "|" + (re.search(
            r'visual_settings = \{(.*?)\n\}', text, re.S)[1] if "visual_settings = {" in text else "")
        observed_sizes[ident] = {"radius": float(value(text, "radius", "0")),
                                 "visual_settings": size_text.split("|", 1)[1].strip(),
                                 "size_input_sha256": hashlib.sha256(size_text.encode()).hexdigest()}
        if ident == "triangle":
            looks.add("triangle_star")
        elif (ROOT / "data/visuals/looks" / (ident + ".tres")).exists():
            looks.add(ident)
        else:
            path = ROOT / "assets/pixel" / (ident + ".png")
            if path.exists():
                inputs[resource_path(path)] = sha(path)
                if path.with_suffix(".png.import").exists(): inputs[resource_path(path.with_suffix(".png.import"))] = sha(path.with_suffix(".png.import"))
                alpha = np.array(Image.open(path).convert("RGBA").getchannel("A")) > 0
                bake("sprite:" + ident, ident, alpha, [resource_path(path)])
            else:
                shape = value(text, "shape", '&""').strip('&"')
                fallback_shapes[ident] = shape
                alpha, points = placeholder(shape)
                bake("shape:" + shape, "shape_" + shape, alpha, [], {"polygon": points})
    # Resolve every stage override, including definitions available to Draco.
    aliases = {}
    for path in sorted((ROOT / "data/stages").glob("stage_*.tres")):
        match = re.search(r'enemy_looks = \{(.*?)\n\}', path.read_text(), re.S)
        if match:
            for ident, skin in re.findall(r'"([^"]+)": "([^"]+)"', match[1]):
                if ident in covered:
                    if not (ROOT / "data/visuals/looks" / (skin + ".tres")).exists():
                        raise ValueError("Unresolved stage landmark look: " + skin)
                    looks.add(skin)
                    aliases[ident + ":" + path.stem] = skin
    # The visible child controls triangle's scale even though its rank is zero.
    child = (ROOT / "data/enemies/triangle_star.tres").read_text()
    child_size = value(child, "radius", "0") + "|" + (re.search(r'visual_settings = \{(.*?)\n\}', child, re.S)[1] if "visual_settings = {" in child else "")
    observed_sizes["triangle_star"] = {"radius": float(value(child, "radius", "0")), "visual_settings": child_size.split("|", 1)[1].strip(), "size_input_sha256": hashlib.sha256(child_size.encode()).hexdigest()}
    for name in sorted(looks):
        alpha, layers, text = look_alpha(name)
        key = "res://data/visuals/looks/" + name + ".tres"
        bake(key, name, alpha, layers, {"pump": True} if name == "pump" else None)
        split = re.search(r'^split_other = ExtResource\("([^"]+)"\)', text, re.M)
        if split:
            refs = dict((ident, file) for file, ident in re.findall(
                r'\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"\]', text))
            bottom_name = Path(refs[split[1]]).stem
            lower, lower_layers, _ = look_alpha(bottom_name)
            if lower.shape != alpha.shape:
                raise ValueError("Split canvas mismatch: " + name)
            bake(refs[split[1]], bottom_name, lower, lower_layers)
            bake(key + ":joined", name + "_joined", alpha | lower, layers + lower_layers)
    texture_paths = sorted(set(entry["file"] for entry in entries.values()))
    indices = {path: str(i + 1) for i, path in enumerate(texture_paths)}
    masks = {}
    for key, entry in sorted(entries.items()):
        masks[key] = dict(entry, texture="EXT:" + indices[entry["file"]])
    header = '[gd_resource type="Resource" load_steps=%d format=3]\n\n' % (len(indices) + 1)
    for path, index in indices.items():
        header += '[ext_resource type="Texture2D" path=%s id="%s"]\n' % (json.dumps(path), index)
    metadata = {"bake_version": 1, "padding": PAD, "distance_units_per_channel": 8,
                "size_policy": "source pixels; body scale applied at runtime; size changes need no rebake",
                "inputs": inputs, "candidates": sorted(candidates), "excluded_candidates": list(EXCLUDED_CANDIDATES),
                "elite_candidates": elites, "stage_aliases": aliases,
                "fallback_shapes": fallback_shapes,
                "observed_size_inputs": observed_sizes, "masks": masks}
    body = "\n[resource]\n" + "\n".join("metadata/" + k + " = " + gd(v) for k, v in metadata.items()) + "\n"
    (OUTPUT / "masks.tres").write_text(header + body)
    outline = re.search(r'float\[72\]\((.*?)\)', (ROOT / "shaders/pump_outline.gdshaderinc").read_text())[1]
    contact_header = '[gd_resource type="Resource" load_steps=2 format=3]\n\n[ext_resource type="Resource" path="res://assets/effects/landmark/masks.tres" id="1"]\n\n[resource]\n'
    contact_data = {"bake_version": 1, "masks": "EXT:1", "inputs": dict(inputs),
                    "mask_manifest_sha256": sha(OUTPUT / "masks.tres"),
                    "pump_outline": [float(v) for v in outline.split(",")], "entries": contact_entries}
    (OUTPUT / "elite_contacts.tres").write_text(contact_header + "\n".join("metadata/" + k + " = " + gd(v) for k, v in contact_data.items()) + "\n")
    print("Baked %d masks for %d candidate definitions into %s" % (len(texture_paths), len(candidates), OUTPUT))


if __name__ == "__main__":
    main()
