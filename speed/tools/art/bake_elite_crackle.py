#!/usr/bin/env python3
"""Freeze the saved elite profile; retain the editable source and dynamic instances."""
from pathlib import Path
import hashlib
import json
import math
import re
import struct

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data/visuals/elite_mark.tres"
SCHEMA = ROOT / "scripts/data_types/enemy_mark_settings.gd"
TEMPLATE = ROOT / "shaders/elite_mark.gdshader"
SHADER = ROOT / "shaders/elite_crackle_runtime.gdshader"
RUNTIME = ROOT / "data/visuals/elite_runtime.tres"
COLORS = {"color": "mark_color", "highlight": "highlight_color", "shadow": "shadow_color"}
TIMING = ("interval_min", "interval_random", "interval_max", "arc_count", "spark_count")


def f32(value):
    return struct.unpack("f", struct.pack("f", float(value)))[0]


def rgba(text):
    match = re.fullmatch(r'Color\("#([0-9a-fA-F]{6})"\)', text)
    if match:
        return [f32(int(match[1][n:n+2], 16) / 255) for n in (0, 2, 4)] + [1.0]
    match = re.fullmatch(r"Color\(([\d.eE+\-, ]+)\)", text)
    if not match:
        raise ValueError("Unsupported elite color: " + text)
    result = [f32(v) for v in match[1].split(",")]
    if len(result) != 4 or not all(math.isfinite(v) for v in result):
        raise ValueError("Expected finite RGBA: " + text)
    return result


def linear(channel):
    if channel < f32(0.04045):
        return f32(channel * f32(1 / 12.92))
    return f32(math.pow(f32((channel + 0.055) / 1.055), f32(2.4)))


def bake():
    sources = (SOURCE, SCHEMA, TEMPLATE, ROOT / "tools/art/bake_elite_crackle.py")
    hashes = {"res://" + p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    values = dict(re.findall(r"@export[^\n]*? var (\w+) := ([^\n]+)", SCHEMA.read_text()))
    values.update(re.findall(r"^(\w+) = (.+)$", SOURCE.read_text(), re.M))
    resolved = {key: values[key] for key in (*COLORS, "intensity", *TIMING)}
    timing = {key: int(values[key]) if key in ("arc_count", "spark_count") else float(values[key]) for key in TIMING}
    if not all(math.isfinite(v) for v in timing.values()):
        raise ValueError("Non-finite elite timing")
    text = TEMPLATE.read_text()
    declarations = ["uniform bool linear_colors = true;"]
    locals_ = []
    for key, name in COLORS.items():
        srgb = rgba(values[key])
        rgb_linear = [linear(c) for c in srgb[:3]] + srgb[3:]
        replacement = "const vec4 " + name + " = vec4(" + ", ".join(map(repr, rgb_linear)) + ");"
        text, count = re.subn(r"^uniform vec4 " + name + r"\s*:[^;]+;", replacement, text, flags=re.M)
        if count != 1:
            raise ValueError("Missing elite color uniform: " + name)
        declarations.append("const vec4 " + name + "_srgb = vec4(" + ", ".join(map(repr, srgb)) + ");")
        alias = "elite_" + name
        text = text.replace(name + ".rgb", alias + ".rgb")
        locals_.append(" vec4 " + alias + " = linear_colors ? " + name + " : " + name + "_srgb;")
    intensity = f32(values["intensity"])
    if not math.isfinite(intensity):
        raise ValueError("Non-finite elite intensity")
    text, count = re.subn(r"^uniform float intensity[^;]*;", "const float intensity = " + repr(intensity) + ";", text, flags=re.M)
    if count != 1:
        raise ValueError("Missing elite intensity uniform")
    text = text.replace("void vertex() {", "\n".join(declarations) + "\nvoid vertex() {", 1)
    text = text.replace("void fragment() {", "void fragment() {\n" + "\n".join(locals_), 1)
    text = "// Specialized by tools/art/bake_elite_crackle.py; edit elite_mark.tres, then rebake.\n" + text
    # Recheck all input bytes before publishing either output.
    for path in sources:
        key = "res://" + path.relative_to(ROOT).as_posix()
        if hashlib.sha256(path.read_bytes()).hexdigest() != hashes[key]:
            raise RuntimeError("Elite input changed during bake: " + key)
    SHADER.write_text(text)
    shader_path = "res://" + SHADER.relative_to(ROOT).as_posix()
    outputs = {shader_path: hashlib.sha256(SHADER.read_bytes()).hexdigest()}
    lines = ['[gd_resource type="Resource" load_steps=2 format=3]', '',
             '[ext_resource type="Shader" path="' + shader_path + '" id="1"]', '',
             '[resource]', 'metadata/bake_version = 1', 'metadata/shader = ExtResource("1")',
             'metadata/values = ' + json.dumps(timing, sort_keys=True),
             'metadata/resolved_values = ' + json.dumps(resolved, sort_keys=True, indent=4),
             'metadata/inputs = ' + json.dumps(hashes, sort_keys=True, indent=4),
             'metadata/outputs = ' + json.dumps(outputs, sort_keys=True, indent=4)]
    RUNTIME.write_text("\n".join(lines) + "\n")
    print("Baked 4 shader artist constants and 5 CPU timing/count values; source inputs unchanged.")


if __name__ == "__main__":
    bake()
