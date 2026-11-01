#!/usr/bin/env python3
"""Resolve only the saved BOOST profile into a runtime style, without Godot."""
from pathlib import Path
import hashlib
import math
import re

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data/visuals/effect_settings.tres"
RENDERER = ROOT / "scripts/ui/boost_gauge_visual.gd"
OUTPUT = ROOT / "data/visuals/boost_gauge_runtime.tres"


def bake():
    match = re.search(r'^"hud/boost_gauge": (\{[^{}]*\})', SOURCE.read_text(), re.M)
    if match is None:
        raise ValueError("Missing saved BOOST profile")
    body = match[1][1:-1]
    values = dict(re.findall(r'^"(\w+)": (.+?)(?:,)?$', body, re.M))
    code = RENDERER.read_text()
    colors = re.search(r'const DEFAULT_COLORS := \{(.*?)\n\}', code, re.S)[1]
    defaults = dict(re.findall(r'^\s*"(\w+)": (.+),$', colors, re.M))
    lines = ['[gd_resource type="Resource" script_class="BoostGaugeStyle" load_steps=2 format=3]', '',
             '[ext_resource type="Script" path="res://scripts/data_types/boost_gauge_style.gd" id="1"]', '',
             '[resource]', 'script = ExtResource("1")']
    for name, fallback in defaults.items():
        value = values.get(name, fallback)
        if value == "Color.WHITE":
            value = "Color(1, 1, 1, 1)"
        elif value.startswith('Color("#'):
            hex_color = value[8:14]
            value = "Color(" + ", ".join(str(int(hex_color[n:n + 2], 16) / 255) for n in (0, 2, 4)) + ", 1)"
        if not re.fullmatch(r"Color\([\d.eE+\-, ]+\)", value):
            raise ValueError("Unsupported saved color: " + value)
        lines.append(name + " = " + value)

    def number(name, fallback):
        value = float(values.get(name, fallback))
        return value if math.isfinite(value) else fallback

    def clamp(value, low, high):
        return min(max(value, low), high)

    first_width = clamp(number("first_ring_width", 8.0), 1.0, 12.0)
    second_width = clamp(number("outer_ring_width", 2.0), 0.5, 6.0)
    a = clamp(number("first_inner_radius", 14 - first_width * 0.5), 0.0, 127.5)
    b = clamp(number("first_outer_radius", 14 + first_width * 0.5), a + 0.5, 128.0)
    c = clamp(number("second_inner_radius", 21 - second_width * 0.5), 0.0, 127.5)
    d = clamp(number("second_outer_radius", 21 + second_width * 0.5), c + 0.5, 128.0)
    width = min(max(0.5, number("tick_width", 2.0)), (b - a) * 0.5)
    half = width * 0.5
    start = a + half
    end = max(start, math.sqrt(max(0.0, b * b - half * half)) - half)
    lines += ["bounds = Vector4(%s, %s, %s, %s)" % (a, b, c, d),
              "tick_width = " + repr(width), "tick_start = " + repr(start), "tick_end = " + repr(end),
              'metadata/profile_sha256 = "' + hashlib.sha256(match[0].encode()).hexdigest() + '"']
    OUTPUT.write_text("\n".join(lines) + "\n")
    print("Saved BOOST style: boundaries=%s tick=%s..%s" % ((a, b, c, d), start, end))


if __name__ == "__main__":
    bake()
