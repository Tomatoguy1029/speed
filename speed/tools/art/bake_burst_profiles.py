#!/usr/bin/env python3
"""Freeze authored explosion profiles into purpose-specific shaders/materials.

Manual authoring command; never starts Godot or changes saved profiles.
EndBlast and its plasma shader are deliberately outside this bake.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data/visuals/effect_settings.tres"
OUTPUT = ROOT / "data/visuals/burst_runtime.tres"
SHADERS = ROOT / "shaders/runtime_bursts"
UNIFORM = re.compile(r'^uniform (\w+) (\w+)\s*(:[^=;]+)?(?:=\s*([^;]+))?;', re.M)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def f32(value):
    return struct.unpack("f", struct.pack("f", float(value)))[0]


def number(value):
    value = float(value)
    if not math.isfinite(value):
        raise ValueError("Non-finite artist value")
    return value


def rgba(value):
    if value == "Color.WHITE":
        return [1.0] * 4
    match = re.fullmatch(r'Color\("#([0-9a-fA-F]{6})"\)', value)
    if match:
        return [f32(int(match[1][i:i + 2], 16) / 255) for i in (0, 2, 4)] + [1.0]
    match = re.fullmatch(r'(?:Color|vec4)\(([^)]+)\)', value)
    if not match:
        raise ValueError("Unsupported color: " + value)
    channels = [f32(number(v)) for v in match[1].split(",")]
    if len(channels) == 1:
        channels *= 4
    if len(channels) != 4:
        raise ValueError("Expected RGBA: " + value)
    return channels


def linear(channel):
    if channel < f32(0.04045):
        return f32(channel * f32(1 / 12.92))
    return f32(math.pow(f32((channel + 0.055) / 1.055), f32(2.4)))


def color_literal(channels, kind="vec4"):
    return kind + "(" + ", ".join(repr(f32(c)) for c in channels) + ")"


def resource_path(path):
    return "res://" + path.relative_to(ROOT).as_posix()


def generate():
    source_bytes = SOURCE.read_bytes()
    source = source_bytes.decode()
    profiles = {}
    profile_hashes = {}
    for match in re.finditer(r'^"([^"]+)": \{\n(.*?)^\}', source, re.M | re.S):
        profiles[match[1]] = dict(re.findall(r'^"([^"]+)": (.+?)(?:,)?$', match[2], re.M))
        profile_hashes[match[1]] = digest(match[0].encode())
    inputs = {}

    def read(path):
        path = ROOT / path
        data = path.read_bytes()
        inputs[resource_path(path)] = digest(data)
        return data.decode()

    read("tools/art/bake_burst_profiles.py")
    read("shaders/burst_noise.gdshaderinc")
    read("scripts/render/fx/blast_bursts.gd")
    read("scripts/render/fx/burst_runtime.gd")
    fire_owner = read("scripts/render/fx/fire_bursts.gd")
    read("scripts/render/attacks/zone_bomber.gd")
    read("scripts/render/attacks/zone_pump.gd")
    read("scripts/render/attacks/zone_phoenix.gd")
    read("scripts/render/equipment/mines.gd")
    bipolar = read("scripts/render/equipment/bipolar.gd")
    read("scripts/render/equipment/massTow.gd")
    hydra_code = read("scripts/bosses/hydra/technique_visual.gd")
    read("scripts/bosses/hydra_presentation.gd")
    roles = [
        ("pump", "res://scenes/attacks/zone_pump.tscn", "blast_burst", "blast", "", None),
        ("bomber", "res://scenes/attacks/zone_bomber.tscn", "bomber_burst", "blast", "", None),
        ("mine", "weapon/mines", "mine_burst", "blast", "", None),
        ("phoenix", "enemy/phoenix", "blast_burst", "blast", "", None),
    ]
    for role, key, code, palette_name, seconds in [
        ("anchor", "weapon/massTow", fire_owner, "EMBER", 0.45),
        ("bipolar", "weapon/bipolar", bipolar, "TEAL", 0.5),
    ]:
        palette = re.search(r'const ' + palette_name + r' := \[(.*?)\]', code, re.S)[1]
        colors = re.findall(r'Color\.WHITE|Color\([^)]*\)', palette)
        if len(colors) != 4:
            raise ValueError("Expected four owner colors: " + role)
        roles.append((role, key, "fire_burst", "fire", "", (colors, seconds)))
    roles.append(("hydra_body", "boss/body/hydra", "hydra_burst", "hydra", "", None))
    for path in sorted((ROOT / "data/bosses/hydra_moves").glob("*.tres")):
        definition = read(path.relative_to(ROOT))
        ident = re.search(r'^technique = &"([^"]+)"', definition, re.M)
        scene = re.search(r'type="PackedScene" path="([^"]+)" id="visual"', definition)
        if not ident or not scene:
            raise ValueError("Missing Hydra owner/visual: " + str(path))
        read(scene[1][len("res://"):])
        roles.append(("hydra_" + ident[1], "boss/move/hydra/" + ident[1], "hydra_burst", "hydra", scene[1], None))
    watched = set()
    generated = {}
    shader_ids = {}
    material_specs = []
    resolved_profiles = {}
    inactive = {}
    body = read("shaders/blast_burst_body.gdshaderinc")
    for role, key, base, kind, fallback, owner in roles:
        watched.update([key] + ([fallback] if fallback else []))
        saved = dict(profiles.get(fallback, {}))
        saved.update(profiles.get(key, {}))
        template = read("shaders/" + base + ".gdshader")
        template = template.replace('#include "res://shaders/blast_burst_body.gdshaderinc"', body)
        if kind == "blast":
            dynamic = {"half_cells", "radius", "age", "origin", "seed"}
        elif kind == "fire":
            dynamic = {"value_noise", "half_cells", "radius", "life", "origin", "seed"}
        else:
            dynamic = {"tint", "progress", "pixels", "seed"}
        values = {}
        names = set()
        prefix = "shader/" + base + "/"
        for match in UNIFORM.finditer(template):
            data_type, name, hint, default = match.groups()
            if name in dynamic:
                continue
            names.add(name)
            original = owner[0][int(name[1])] if kind == "fire" and name in ("c0", "c1", "c2", "c3") else default
            legacy = "shader/blast_burst/" + name if base in ("mine_burst", "bomber_burst") else prefix + name
            value = saved.get(prefix + name, saved.get(legacy, original))
            if name == "effect_color":
                value = saved.get("effect_tint", "Color.WHITE")
            elif name == "effect_energy":
                value = saved.get("glow_energy", "1.0")
            if value is None:
                raise ValueError("Missing fixed uniform: " + name)
            values[name] = rgba(value) if data_type == "vec4" else number(value)
        unknown = [name for name in saved if name.startswith(prefix) and name[len(prefix):] not in names]
        if unknown:
            raise ValueError("Unknown saved uniforms: " + str(unknown))
        inactive[key] = [name for name in saved if name.startswith("shader/") and not name.startswith(prefix) and not (base in ("mine_burst", "bomber_burst") and name.startswith("shader/blast_burst/"))]
        materials = []
        for mode in ([0, 1, 2, 3] if kind == "blast" else [0]):
            replacements = {}

            def constant(match):
                data_type, name, hint, default = match.groups()
                if name in dynamic:
                    return match[0]
                value = mode if name == "pass_mode" else values[name]
                baked = "_baked_" + name
                if data_type == "vec4":
                    replacements[name] = "(linear_colors ? " + baked + " : " + baked + "_srgb)"
                    converted = [linear(c) for c in value[:3]] + value[3:]
                    return "const vec4 " + baked + " = " + color_literal(converted) + ";\nconst vec4 " + baked + "_srgb = " + color_literal(value) + ";"
                replacements[name] = baked
                literal = str(int(value)) if data_type == "int" else repr(f32(value))
                return "const " + data_type + " " + baked + " = " + literal + ";"

            text = UNIFORM.sub(constant, template)
            text = re.sub(r'^group_uniforms[^\n]*\n', "", text, flags=re.M)
            for name, replacement in replacements.items():
                text = re.sub(r'\b' + re.escape(name) + r'\b', lambda match: replacement, text)
            text = re.sub(r'^(render_mode[^;]+;)', r'\1\nuniform bool linear_colors = true;', text, count=1, flags=re.M)
            text = "// Generated by tools/art/bake_burst_profiles.py; keep the editable base shader.\n" + text.rstrip() + "\n"
            signature = digest(text.encode())
            if signature not in shader_ids:
                name = role + ("_p" + str(mode) if kind == "blast" else "") + ".gdshader"
                path = SHADERS / name
                shader_ids[signature] = len(shader_ids) + 1
                generated[path] = text
                material_specs.append((shader_ids[signature], resource_path(path), kind))
            materials.append(shader_ids[signature])
        scalar = lambda name, default: number(saved.get(name, default))
        data = {"kind": kind, "materials": materials, "time_scale": max(0.05, scalar("burst_duration_scale", 1.0)),
                "pixel_scale": scalar("pixel_scale", 1.0), "effect_scale": scalar("effect_scale", 0.8333333333333333),
                "glow_energy": scalar("glow_energy", 1.0)}
        if kind == "blast":
            v = values
            data["life"] = max(v["fire_seconds"], v["ring_seconds"], 0.3 + v["smoke_seconds"], 0.67 * v["fire_seconds"] + v["cinder_seconds"], 0.06 + v["spark_seconds"])
            data["reach"] = [0.16 + 6.6 * v["spark_speed"] * (1.0 - math.exp(-0.6 * (v["spark_seconds"] + 0.06))) / 0.6,
                             0.21 + v["ring_size"], 1.05 + 22.0 / 38.0 * v["cinder_speed"] * v["cinder_seconds"],
                             0.8 + 15.0 / 38.0 * 1.3 + math.sqrt(12.0 ** 2 + 16.0 ** 2) / 38.0 * v["smoke_seconds"]]
        elif kind == "fire":
            data["fire_seconds"] = max(0.01, scalar("burst_fire_seconds", owner[1]))
        else:
            flash = re.search(r'var flash_duration := ([\d.]+)', hydra_code)[1]
            data.update(large_seconds=max(0.01, scalar("burst_large_seconds", 0.8)),
                        small_seconds=max(0.01, scalar("burst_small_seconds", max(0.3, scalar("flash_duration", flash)))),
                        burst_pixel_scale=scalar("burst_pixel_scale", 1.0))
        resolved_profiles[key] = data
    known = watched | {"hud/boost_gauge", "res://scenes/attacks/shell.tscn", "weapon/endBlast"}
    omitted = [key for key, values in profiles.items() if key not in known and any(name.startswith("shader/") for name in values)]
    if omitted:
        raise ValueError("Saved shader profiles need an explicit bake owner: " + str(omitted))
    lines = ['[gd_resource type="Resource" load_steps=%d format=3]' % (len(material_specs) * 2 + 3), '']
    for ident, path, kind in material_specs:
        lines.append('[ext_resource type="Shader" path="%s" id="s%d"]' % (path, ident))
    lines += ['[ext_resource type="Texture3D" path="res://assets/effects/build/burst_noise_volume.png" id="noise3"]',
              '[ext_resource type="Texture2D" path="res://assets/effects/build/value_noise.png" id="noise2"]', '']
    for ident, path, kind in material_specs:
        lines += ['[sub_resource type="ShaderMaterial" id="m%d"]' % ident, 'shader = ExtResource("s%d")' % ident]
        if kind in ("blast", "fire"):
            lines.append('shader_parameter/value_noise = ExtResource("%s")' % ("noise3" if kind == "blast" else "noise2"))
        lines.append('')
    lines += ['[resource]', 'metadata/bake_version = 1', 'metadata/profiles = {']
    for key, data in sorted(resolved_profiles.items()):
        lines.append(json.dumps(key) + ": {")
        for name, value in data.items():
            if name == "materials":
                literal = '[' + ', '.join('SubResource("m%d")' % i for i in value) + ']'
            elif name == "reach":
                literal = '[' + ', '.join(repr(v) for v in value) + ']'
            else:
                literal = json.dumps(value)
            lines.append(json.dumps(name) + ': ' + literal + ',')
        lines[-1] = lines[-1].rstrip(',')
        lines.append('},')
    lines[-1] = lines[-1].rstrip(',')
    lines += ['}', 'metadata/inputs = ' + json.dumps(inputs, indent=4),
              'metadata/saved_profiles = ' + json.dumps({key: profile_hashes.get(key, "") for key in sorted(watched)}, indent=4),
              'metadata/inactive_fields = ' + json.dumps({key: value for key, value in inactive.items() if value}, indent=4),
              'metadata/outputs = ' + json.dumps({resource_path(path): digest(text.encode()) for path, text in generated.items()}, indent=4)]
    generated[OUTPUT] = '\n'.join(lines) + '\n'
    if SOURCE.read_bytes() != source_bytes:
        raise ValueError("Saved profiles changed during bake; rerun from the new saved values")
    return generated, len(resolved_profiles), sum(key in profiles for key in resolved_profiles)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Compare generated text without writing")
    args = parser.parse_args()
    outputs, count, saved = generate()
    if args.check:
        different = [str(path.relative_to(ROOT)) for path, text in outputs.items() if not path.exists() or path.read_text() != text]
        if different:
            raise SystemExit("Burst bake differs: " + ', '.join(different))
    else:
        for path, text in outputs.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.exists() or path.read_text() != text:
                path.write_text(text)
    print("%s %d burst owners (%d saved profiles), %d runtime shaders; EndBlast excluded." % ("Matched" if args.check else "Baked", count, saved, len(outputs) - 1))
