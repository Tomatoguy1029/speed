"""Validate the reusable Stage 5 library and optionally compare a Git baseline.

Run from the repository root:
    python3 speed/tests/stage5_formations.py --baseline-ref <commit>
"""
import argparse
import math
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SPECIES = ("pump", "crab", "cross", "auriga", "dolphin", "crow", "cepheus", "aquila")


def read(path, ref=None):
    if ref:
        return subprocess.check_output(["git", "show", f"{ref}:{path}"], cwd=ROOT, text=True)
    return (ROOT / path).read_text()


def sections(text, kind):
    pattern = rf'^\[{kind} ([^\n]+)\]\n(.*?)(?=^\[(?:node |sub_resource |resource\])|\Z)'
    return re.findall(pattern, text, re.M | re.S)


def props(body):
    return dict(re.findall(r'^([\w]+)\s*=\s*(.*)$', body, re.M))


def vector(value="Vector2(0, 0)"):
    return tuple(float(n.strip()) for n in value[len("Vector2("):-1].split(","))


def formation(path, ref=None):
    text = read(path, ref)
    scripts = dict((i, p) for p, i in re.findall(r'path="([^"]+\.gd)" id="([^"]+)"', text))
    nodes = []
    for head, body in sections(text, "node"):
        attributes = dict(re.findall(r'(\w+)="([^"]*)"', head))
        values = props(body)
        script = scripts[re.search(r'"([^"]+)"', values["script"])[1]]
        nodes.append((attributes, values, Path(script).stem))
    layouts = {}
    entries = []
    for attr, values, script in nodes:
        if script == "formation_layout":
            markers = []
            for a, v, s in nodes:
                if s == "formation_marker" and a.get("parent") == attr["name"]:
                    markers.append((v["enemy"], vector(v.get("position", "Vector2(0, 0)")), float(v.get("rotation", 0))))
            layouts[attr["name"]] = (float(values.get("weight", 1)), tuple(markers))
        elif script == "formation_entry":
            entries.append((vector(values["position"]), float(values.get("weight", 1))))
    return layouts, entries


def stage(ref=None):
    text = read("speed/data/stages/stage_5.tres", ref)
    scenes = {i: p[len("res://"):] for p, i in re.findall(r'path="([^"]+\.tscn)" id="([^"]+)"', text)}
    clips = {}
    for head, body in sections(text, "sub_resource"):
        values = props(body)
        if values.get("script") != 'ExtResource("clip")':
            continue
        key = re.search(r'id="([^"]+)"', head)[1]
        scene = re.search(r'ExtResource\("([^"]+)"\)', values["formations"])[1]
        path = "speed/" + scenes[scene]
        layouts, entries = formation(path, ref)
        selected = re.findall(r'&"([^"]+)"', values.get("layouts", ""))
        signatures = []
        for item in selected:
            basename, name = item.split("/", 1)
            assert basename == Path(path).stem, f"broken scene key: {item}"
            assert name in layouts, f"missing layout: {item}"
            signatures.append(layouts[name])
        clips[key] = (values, signatures, entries)
    return text, clips


def placed(entry, marker, turn, stretch):
    (ex, ey), _ = entry
    _, (mx, my), rotation = marker
    angle = math.atan2(-ey, -ex) + math.pi / 2
    x = ex * stretch + mx * math.cos(angle) - my * math.sin(angle)
    y = ey * stretch + mx * math.sin(angle) + my * math.cos(angle)
    return (x * math.cos(turn) - y * math.sin(turn), x * math.sin(turn) + y * math.cos(turn), angle + rotation + turn)


def validate(baseline):
    _, clips = stage()
    config = props(read("speed/data/config.tres"))
    view = float(config["base_view"])
    safe_radius = math.hypot(view * 16 / 9, view) / 2 + 300
    assert len(clips) == 31
    assert {int(c[0]["track"]) for c in clips.values()} == set(range(8))
    for species in SPECIES:
        layouts, entries = formation(f"speed/data/formations/s5_{species}.tscn")
        assert len(entries) == 4
        assert len(set(tuple(sorted(markers)) for _, markers in layouts.values())) == len(layouts), f"{species}: duplicate placements"
        assert not any(re.search(r'(?:peak|grow|phase)\d*', name) for name in layouts), f"{species}: phase identity"
        multis = [markers for _, markers in layouts.values() if len(markers) > 1]
        assert len(multis) >= 2, f"{species}: needs distinct multi-member alternatives"
        path = f"speed/data/formations/s5_{species}.tscn"
        assert f'types = Array[StringName]([&"{species}"])' in read(path)
        for reference in re.findall(r'path="res://([^"]+)"', read(path)):
            assert (ROOT / "speed" / reference).is_file(), f"broken asset: {reference}"
        radius = float(props(read(f"speed/data/enemies/{species}.tres"))["radius"])
        for _, markers in layouts.values():
            assert markers and all(m[0] == f'&"{species}"' for m in markers)
            for entry in entries:
                for marker in markers:
                    x, y, _ = placed(entry, marker, 0, 1)
                    assert math.hypot(x, y) >= safe_radius, f"{species}: visible spawn"
            for i, a in enumerate(markers):
                for b in markers[i + 1:]:
                    assert math.dist(a[1], b[1]) >= radius * 2 * 1.3, f"{species}: overlapping members"
        if species == "crow":
            flock = int(re.search(r'"flock": (\d+)', read("speed/data/enemies/crow.tres"))[1])
            assert flock == 4 and all(len(markers) * flock == 8 for markers in multis), "crow alternatives must represent two four-bird flocks"
    for _, signatures, _ in clips.values():
        assert len(signatures) == 1 and len(signatures[0][1]) == 1, "new multi-member choice was enabled"
    if baseline:
        old_text, old = stage(baseline)
        new_text, _ = stage()
        scrub = lambda s: re.sub(r'^layouts = .*$', '', s, flags=re.M)
        assert scrub(old_text) == scrub(new_text), "stage changed beyond layout references"
        assert old.keys() == clips.keys()
        comparisons = 0
        for key, (values, signatures, entries) in clips.items():
            old_values, old_signatures, old_entries = old[key]
            assert {k: v for k, v in values.items() if k != "layouts"} == {k: v for k, v in old_values.items() if k != "layouts"}
            assert signatures == old_signatures and entries == old_entries, f"{key}: spawn semantics changed"
            for entry, old_entry in zip(entries, old_entries):
                for turn in (0, math.pi / 2, -0.73):
                    for stretch in (1, 1.8):
                        assert placed(entry, signatures[0][1][0], turn, stretch) == placed(old_entry, old_signatures[0][1][0], turn, stretch)
                        comparisons += 1
        print(f"PASS: 31 clips unchanged except references; {comparisons} spawn transforms identical")
    print("PASS: 8 reusable libraries; distinct optional formations; valid types, spacing and safe entries")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-ref")
    validate(parser.parse_args().baseline_ref)
