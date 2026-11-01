#!/usr/bin/env python3
"""Specialize only the saved landmark aura. Manual authoring command, without Godot.

Keep the generic editor/ship shader intact. Resolve absent settings from the
EnemyMarkSettings exports, and keep dynamic mask/deformation fields per instance.
Writes only the landmark runtime shader and its shared material.
"""
from pathlib import Path
import hashlib
import json
import math
import re
import struct

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data/visuals/landmark_mark.tres"
SCHEMA = ROOT / "scripts/data_types/enemy_mark_settings.gd"
TEMPLATE = ROOT / "shaders/build_aura.gdshader"
SHADER = ROOT / "shaders/landmark_aura_runtime.gdshader"
MATERIAL = ROOT / "data/visuals/landmark_aura_material.tres"


def f32(value):
    return struct.unpack("f", struct.pack("f", float(value)))[0]


def literal(value):
    return repr(f32(value))


def color(value):
    match = re.fullmatch(r'Color\("#([0-9a-fA-F]{6})"\)', value)
    if match:
        return [f32(int(match[1][n:n + 2], 16) / 255) for n in (0, 2, 4)] + [1.0]
    match = re.fullmatch(r"Color\(([\d., ]+)\)", value)
    if not match:
        raise ValueError("Unsupported color: " + value)
    channels = [f32(v) for v in match[1].split(",")]
    if len(channels) != 4:
        raise ValueError("Expected RGBA: " + value)
    return channels


def linear(channel):
    # Godot Color::srgb_to_linear(), preserving alpha separately.
    if channel < f32(0.04045):
        return f32(channel * f32(1 / 12.92))
    return f32(math.pow(f32((channel + 0.055) / 1.055), f32(2.4)))


def bake():
    schema = SCHEMA.read_text()
    values = dict(re.findall(r"@export[^\n]*? var (\w+) := ([^\n]+)", schema))
    values.update(re.findall(r"^(\w+) = (.+)$", SOURCE.read_text(), re.M))
    fields = dict(re.findall(r'^\t"(\w+)": \[.*?, "(\w+)"\],$', schema, re.M))
    if not fields:
        raise ValueError("Missing artist field mappings")
    resolved = {uniform: values[key] for key, uniform in fields.items()}
    resolved.update(landmark_mode="true", distance_scale="1.0")
    dynamic = {"mask_size", "mask_padding", "pump_mask", "pump_full"}
    remaining = {"noise_tex", "clock"}
    found = set()
    colors = []

    def specialize(match):
        kind, name, hint, default = match.groups()
        if name in remaining:
            return match[0]
        if name in dynamic:
            return "instance " + match[0]
        value = resolved.get(name, default)
        if value is None:
            raise ValueError("Missing default: " + name)
        found.add(name)
        if name in ("aura_core", "aura_outer"):
            rgba = color(value)
            srgb = "vec4(" + ",".join(map(literal, rgba)) + ")"
            rgb_linear = [linear(c) for c in rgba[:3]] + rgba[3:]
            colors.append("const vec4 " + name + "_srgb=" + srgb + ";")
            value = "vec4(" + ",".join(map(literal, rgb_linear)) + ")"
        elif name in resolved and kind == "float":
            value = literal(value)
        return "const " + kind + " " + name + "=" + value + ";"

    text = TEMPLATE.read_text()
    text = re.sub(r"^uniform (\w+) (\w+)\s*(:[^=;]+)?(?:=([^;]+))?;", specialize, text, flags=re.M)
    if not set(resolved).issubset(found):
        raise ValueError("Shader mapping mismatch: " + str(set(resolved) - found))
    text = re.sub(r"^group_uniforms[^\n]*\n", "", text, flags=re.M)
    text = text.replace("vec2 landmark_flow", "uniform bool linear_colors=true;\n" + "\n".join(colors) + "\nvec2 landmark_flow", 1)
    text = text.replace("col=mix(aura_core,aura_outer,edge);", "col=mix(linear_colors?aura_core:aura_core_srgb,linear_colors?aura_outer:aura_outer_srgb,edge);")
    text = "// Specialized by tools/art/bake_landmark_aura.py; edit the saved profile, then rebake.\n" + text
    SHADER.write_text(text)
    lines = ['[gd_resource type="ShaderMaterial" load_steps=3 format=3]', '',
             '[ext_resource type="Shader" path="res://shaders/landmark_aura_runtime.gdshader" id="1_shader"]',
             '[ext_resource type="Texture2D" path="res://assets/effects/build/aura_noise.png" id="2_noise"]', '',
             '[resource]', 'shader = ExtResource("1_shader")',
             'shader_parameter/noise_tex = ExtResource("2_noise")']
    inputs = {}
    for path in (SOURCE, SCHEMA, TEMPLATE, Path(__file__).resolve()):
        name = "res://" + path.relative_to(ROOT).as_posix()
        inputs[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    lines += ["metadata/bake_version = 1", "metadata/inputs = " + json.dumps(inputs, indent=4),
              'metadata/shader_sha256 = "' + hashlib.sha256(SHADER.read_bytes()).hexdigest() + '"']
    MATERIAL.write_text("\n".join(lines) + "\n")
    print("Baked %d artist constants; shared clock/noise/color-space, 4 instance fields." % len(fields))


if __name__ == "__main__":
    bake()
