#!/usr/bin/env python3
"""Freeze authored explosion profiles into purpose-specific shaders/materials.

Manual authoring command; never starts Godot or changes saved profiles.
EndBlast and its plasma shader are deliberately outside this bake.
Only pump impact, bomber and mine profiles are generated.
The visual editor retains the editable shaders and saved profiles.
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


ROLES = [
    ("pump", "res://scenes/attacks/zone_pump.tscn", "blast_burst"),
    ("bomber", "res://scenes/attacks/zone_bomber.tscn", "bomber_burst"),
    ("mine", "weapon/mines", "mine_burst"),
]


def block_end(text, start):
    depth = 1
    for pos in range(start + 1, len(text)):
        depth += (text[pos] == "{") - (text[pos] == "}")
        if depth == 0:
            return pos + 1
    raise ValueError("Unbalanced shader block")


def select_pass(text, mode):
    """Select the shared body's pass branches before emitting a dedicated shader."""
    pattern = re.compile(r'if\s*\(pass_mode == ([0-3])\)\s*\{')
    while True:
        match = pattern.search(text)
        if not match:
            return text
        start, end, selected = match.start(), match.start(), ""
        branch = match
        while branch:
            opening = text.index("{", branch.start())
            end = block_end(text, opening)
            if int(branch[1]) == mode:
                selected = text[opening + 1:end - 1]
            tail = re.match(r'\s*else\s+', text[end:])
            if not tail:
                break
            next_start = end + tail.end()
            branch = pattern.match(text, next_start)
            if not branch:
                if text[next_start] != "{":
                    raise ValueError("Expected final pass branch")
                final_end = block_end(text, next_start)
                if not selected:
                    selected = text[next_start + 1:final_end - 1]
                end = final_end
                break
        text = text[:start] + selected + text[end:]


def remove_ring(body, mode):
    # ring_alpha only multiplies the final ring opacity. Fire/flash use other alpha.
    for needle in ("\tif (age < ring_seconds) max_reach =",):
        body = re.sub(r'^' + re.escape(needle) + r'.*\n', '', body, flags=re.M)
    if mode != 0:
        return body
    needle = "\t\tif (age < ring_seconds) {"
    start = body.index(needle)
    end = block_end(body, body.index("{", start))
    body = body[:start] + body[end:]
    start = body.index("\t\tfloat ru = age / ring_seconds;")
    opening = body.index("{", start)
    end = block_end(body, opening)
    return body[:start] + body[end:]


def trim_functions(body):
    pattern = re.compile(r'^(?:void|float|vec[234]) (\w+)\([^\n]*\)\s*\{', re.M)
    functions = {}
    for match in pattern.finditer(body):
        functions[match[1]] = (match.start(), block_end(body, body.index("{", match.start())))
    needed = {"vertex", "fragment"}
    pending = list(needed)
    while pending:
        name = pending.pop()
        first, last = functions[name]
        for other in functions:
            if other not in needed and re.search(r'\b' + other + r'\s*\(', body[first:last]):
                needed.add(other)
                pending.append(other)
    for name, (first, last) in sorted(functions.items(), key=lambda pair: pair[1][0], reverse=True):
        if name not in needed:
            body = body[:first] + body[last:]
    return body


def specialize(template, body, values, mode):
    body = select_pass(body, mode)
    if values["ring_alpha"] == 0:
        body = remove_ring(body, mode)
    body = trim_functions(body)
    uses_noise = bool(re.search(r'\bvnoise\(', body))
    if not uses_noise:
        template = template.replace('#include "res://shaders/burst_noise.gdshaderinc"', '')
    template = template.replace('#include "res://shaders/blast_burst_body.gdshaderinc"', body)
    replacements = {}
    dynamic = {"half_cells", "radius", "age", "origin", "seed"}

    def constant(match):
        kind, name, hint, default = match.groups()
        if name in dynamic:
            return match[0]
        value = mode if name == "pass_mode" else values[name]
        baked = "_baked_" + name
        if kind == "vec4":
            replacements[name] = "(linear_colors ? " + baked + " : " + baked + "_srgb)"
            return "const vec4 " + baked + " = " + color_literal([linear(c) for c in value[:3]] + value[3:]) + ";\nconst vec4 " + baked + "_srgb = " + color_literal(value) + ";"
        replacements[name] = baked
        return "const " + kind + " " + baked + " = " + (str(int(value)) if kind == "int" else repr(f32(value))) + ";"

    text = UNIFORM.sub(constant, template)
    text = re.sub(r'^group_uniforms[^\n]*\n', '', text, flags=re.M)
    for name, replacement in replacements.items():
        text = re.sub(r'\b' + re.escape(name) + r'\b', lambda match: replacement, text)
    text = re.sub(r'^[ \t]*//[^\n]*\n', '', text, flags=re.M)
    for name in ("particle_state", "particle_extra", "particle_color"):
        if len(re.findall(r'\b' + name + r'\b', text)) == 2:
            text = re.sub(r'^[ \t]*(?:varying flat vec4 ' + name + r';|' + name + r' = vec4\(0.0\);)\n', '', text, flags=re.M)
    text = re.sub(r'^(render_mode[^;]+;)', r'\1\nuniform bool linear_colors = true;', text, count=1, flags=re.M)
    # Dead declarations disappear together with the removed passes and functions.
    declaration = re.compile(r'^(?:(?:const|uniform) \w+ \w+[^;]*;|varying(?: flat)? \w+ \w+;)\s*$', re.M)
    changed = True
    while changed:
        changed = False
        for match in list(declaration.finditer(text))[::-1]:
            name = re.search(r'(?:const|uniform|varying(?: flat)?) \w+ (\w+)', match[0])[1]
            if len(re.findall(r'\b' + name + r'\b', text)) == 1:
                text = text[:match.start()] + text[match.end():]
                changed = True
    parameters = re.findall(r'^uniform \w+ (\w+)', text, re.M)
    text = '\n'.join(line.rstrip() for line in text.splitlines())
    text = re.sub(r'\n\n+', '\n\n', text)
    return "// Generated by tools/art/bake_burst_profiles.py; keep the editable base shader.\n" + text.rstrip() + "\n", parameters, uses_noise


def generate():
    source_bytes = SOURCE.read_bytes()
    profiles = {}
    profile_hashes = {}
    for match in re.finditer(r'^"([^"]+)": \{\n(.*?)^\}', source_bytes.decode(), re.M | re.S):
        profiles[match[1]] = dict(re.findall(r'^"([^"]+)": (.+?)(?:,)?$', match[2], re.M))
        profile_hashes[match[1]] = digest(match[0].encode())
    inputs = {}

    def read(path):
        data = (ROOT / path).read_bytes()
        inputs["res://" + path] = digest(data)
        return data.decode()

    for path in ("tools/art/bake_burst_profiles.py", "shaders/burst_noise.gdshaderinc", "scripts/render/fx/blast_bursts.gd",
                 "scripts/render/fx/burst_runtime.gd", "scripts/render/attacks/zone_bomber.gd",
                 "scripts/render/attacks/zone_pump.gd", "scripts/render/equipment/mines.gd"):
        read(path)
    body = read("shaders/blast_burst_body.gdshaderinc")
    generated, owners, materials, inactive = {}, {}, [], {}
    for role, key, base in ROLES:
        if key not in profiles:
            raise ValueError("Missing saved profile: " + key)
        saved = profiles[key]
        template = read("shaders/" + base + ".gdshader")
        prefix = "shader/" + base + "/"
        values = {}
        for match in UNIFORM.finditer(template):
            kind, name, hint, default = match.groups()
            if name in {"half_cells", "radius", "age", "origin", "seed"}:
                continue
            legacy = "shader/blast_burst/" + name
            value = saved.get(prefix + name, saved.get(legacy, default))
            # ShaderTuning.apply gives shader-specific overrides final precedence.
            if name == "effect_color":
                value = saved.get(prefix + name, saved.get(legacy, saved.get("effect_tint", "Color.WHITE")))
            elif name == "effect_energy":
                value = saved.get(prefix + name, saved.get(legacy, saved.get("glow_energy", "1.0")))
            if value is None:
                raise ValueError("Missing fixed value: " + name)
            values[name] = rgba(value) if kind == "vec4" else number(value)
        unknown = [name for name in saved if name.startswith(prefix) and name[len(prefix):] not in values]
        if unknown:
            raise ValueError("Unknown saved uniforms: " + str(unknown))
        inactive[key] = [name for name in saved if name.startswith("shader/") and not name.startswith(prefix) and not name.startswith("shader/blast_burst/")]
        passes = []
        removed = ["ring"] if values["ring_alpha"] == 0 else []
        for mode in (1, 0, 2, 3):
            layer = {1: "smoke", 2: "cinder", 3: "spark"}.get(mode)
            count = min({1: 24, 2: 96, 3: 64}.get(mode, 1), max(0, math.ceil(values[layer + "_count"]))) if layer else 1
            if layer and (count == 0 or (mode == 1 and (values["smoke_alpha"] == 0 or all(values[n][3] == 0 for n in ("smoke_dark", "smoke_mid", "smoke_light"))))):
                removed.append(layer)
                continue
            text, parameters, noise = specialize(template, body, values, mode)
            path = SHADERS / (role + "_p" + str(mode) + ".gdshader")
            generated[path] = text
            ident = len(materials) + 1
            materials.append((ident, resource_path(path), noise))
            passes.append((ident, mode, count, parameters))
        scalar = lambda name, default: number(saved.get(name, default))
        v = values
        owners[key] = {
            "passes": passes, "time_scale": max(0.05, scalar("burst_duration_scale", 1.0)),
            "pixel_scale": scalar("pixel_scale", 1.0), "effect_scale": scalar("effect_scale", 5.0 / 6.0),
            "glow_energy": scalar("glow_energy", 1.0), "effect_tint": rgba(saved.get("effect_tint", "Color.WHITE")),
            "life": max(v["fire_seconds"], v["ring_seconds"], 0.3 + v["smoke_seconds"], 0.67 * v["fire_seconds"] + v["cinder_seconds"], 0.06 + v["spark_seconds"]),
            "reach": [0.16 + 6.6 * v["spark_speed"] * (1.0 - math.exp(-0.6 * (v["spark_seconds"] + 0.06))) / 0.6,
                      0.21 + v["ring_size"], 1.05 + 22.0 / 38.0 * v["cinder_speed"] * v["cinder_seconds"],
                      0.8 + 15.0 / 38.0 * 1.3 + math.sqrt(12.0 ** 2 + 16.0 ** 2) / 38.0 * v["smoke_seconds"]],
            "removed_layers": removed,
        }
    lines = ['[gd_resource type="Resource" load_steps=%d format=3]' % (len(materials) * 2 + 2), '']
    for ident, path, noise in materials:
        lines.append('[ext_resource type="Shader" path="%s" id="s%d"]' % (path, ident))
    lines += ['[ext_resource type="Texture3D" path="res://assets/effects/build/burst_noise_volume.png" id="noise"]', '']
    for ident, path, noise in materials:
        lines += ['[sub_resource type="ShaderMaterial" id="m%d"]' % ident, 'shader = ExtResource("s%d")' % ident]
        if noise:
            lines.append('shader_parameter/value_noise = ExtResource("noise")')
        lines.append('')
    lines += ['[resource]', 'metadata/bake_version = 2', 'metadata/source_sha256 = "' + digest(source_bytes) + '"', 'metadata/profiles = {']
    for key, data in owners.items():
        lines.append(json.dumps(key) + ': {')
        for name, value in data.items():
            if name == "passes":
                literal = '[' + ', '.join('{"material": SubResource("m%d"), "mode": %d, "count": %d, "parameters": %s}' % (ident, mode, count, json.dumps(parameters)) for ident, mode, count, parameters in value) + ']'
            elif name == "effect_tint":
                literal = color_literal(value, "Color")
            else:
                literal = json.dumps(value)
            lines.append(json.dumps(name) + ': ' + literal + ',')
        lines[-1] = lines[-1].rstrip(',')
        lines.append('},')
    lines[-1] = lines[-1].rstrip(',')
    lines += ['}', 'metadata/inputs = ' + json.dumps(inputs, indent=4),
              'metadata/saved_profiles = ' + json.dumps({key: profile_hashes[key] for key in owners}, indent=4),
              'metadata/inactive_fields = ' + json.dumps({key: names for key, names in inactive.items() if names}, indent=4),
              'metadata/outputs = ' + json.dumps({resource_path(path): digest(text.encode()) for path, text in generated.items()}, indent=4)]
    generated[OUTPUT] = '\n'.join(lines) + '\n'
    if SOURCE.read_bytes() != source_bytes:
        raise ValueError("Saved profiles changed during bake; rerun from the new saved values")
    return generated, owners


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Compare generated text without writing")
    args = parser.parse_args()
    outputs, owners = generate()
    different = [path for path, text in outputs.items() if not path.exists() or path.read_text() != text]
    if args.check:
        if different:
            raise SystemExit("Burst bake differs: " + ', '.join(str(path.relative_to(ROOT)) for path in different))
    else:
        for path in different:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(outputs[path])
    for key, values in owners.items():
        print(key + ': ' + str(len(values["passes"])) + ' passes; removed=' + str(values["removed_layers"]))
    print("%s 3 explosion profiles; other explosions excluded." % ("Matched" if args.check else "Baked"))
