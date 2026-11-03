#!/usr/bin/env python3
"""Bake fragment contraction from the existing landmark silhouettes (Pillow only).

No runtime partitioning, random numbers, particle trajectories or image reads.
Sixteen frames store source coordinates of independently shrinking fragments.
Their centers inherit the original world velocity; no outward scattering is added.
"""
from pathlib import Path
import hashlib
import json
import math
import random
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'assets/effects/elite_death'
MANIFEST = ROOT / 'assets/effects/landmark/masks.tres'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def bake():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    inputs = {'res://tools/art/bake_elite_death.py': sha(Path(__file__)),
              'res://assets/effects/landmark/masks.tres': sha(MANIFEST)}
    outputs, entries = {}, {}
    source = MANIFEST.read_text().split('metadata/masks = ', 1)[1]
    for key, body in re.findall(r'"(res://data/visuals/looks/[^\"]+)": \{(.*?)\}', source, re.S):
        # Joined silhouettes are only for outlines; each rendered half uses its own source UV.
        if not key.endswith(".tres"): continue
        path = re.search(r'"file": "([^\"]+)"', body)[1]
        mask_path = ROOT / path[6:]
        inputs[path] = sha(mask_path)
        mask = Image.open(mask_path).convert('RGB')
        pad = int(re.search(r'"padding": (\d+)', body)[1])
        width, height = mask.width-2*pad, mask.height-2*pad
        rng = random.Random(int(hashlib.sha256(key.encode()).hexdigest()[:16], 16))
        # Roughly 3 source pixels per fragment; jitter removes a square grid.
        seeds = []
        for y in range(0, height, 3):
            for x in range(0, width, 3):
                sx, sy = min(width-1,x+rng.randrange(3)), min(height-1,y+rng.randrange(3))
                if mask.getpixel((sx+pad,sy+pad))[0] == 0:
                    seeds.append((sx,sy,rng.uniform(0.56,0.98)))
        if not seeds:
            raise ValueError('Empty death silhouette: '+key)
        assert max(width,height)<=256, 'Source coordinates use one byte per axis'
        labels = []
        for y in range(height):
            for x in range(width):
                labels.append(min(range(len(seeds)),key=lambda i:(x-seeds[i][0])**2+(y-seeds[i][1])**2))
        # RG stores original source pixel coordinates, B stores coverage. Inverse
        # mapping moves the painted pixels with the entire fragment, unlike an
        # alpha threshold which only erodes a stationary image. Each Voronoi cell
        # is convex, so contracting around its seed cannot overlap another cell.
        image = Image.new('RGB',(width*4,height*4))
        for frame in range(16):
            age = frame/15.0
            for y in range(height):
                for x in range(width):
                    label = labels[y*width+x]
                    cx,cy,end = seeds[label]
                    scale = max(0.0,1.0-age/end)
                    if scale<=0.001: continue
                    sx = math.floor(cx+0.5+(x-cx)/scale)
                    sy = math.floor(cy+0.5+(y-cy)/scale)
                    if 0<=sx<width and 0<=sy<height and labels[sy*width+sx]==label:
                        image.putpixel(((frame%4)*width+x,(frame//4)*height+y),(sx,sy,255))
        name = Path(key).stem
        target = OUTPUT / (name+'.png')
        image.save(target)
        texture_path = 'res://assets/effects/elite_death/'+target.name
        digest = hashlib.md5(texture_path.encode()).hexdigest()
        cache = 'res://.godot/imported/'+target.name+'-'+digest+'.ctex'
        config = target.with_suffix('.png.import')
        if not config.exists():
            config.write_text(f'''[remap]
importer="texture"
type="CompressedTexture2D"
path="{cache}"

[deps]
source_file="{texture_path}"
dest_files=["{cache}"]

[params]
compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=false
''')
        outputs[texture_path] = sha(target)
        inputs[texture_path+'.import'] = sha(config)
        entries[key] = texture_path
    lines = [f'[gd_resource type="Resource" load_steps={len(entries)+1} format=3]', '']
    for i,path in enumerate(entries.values()):
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{i+1}"]')
    lines += ['', '[resource]', 'metadata/bake_version = 2', 'metadata/lifetime = 0.5',
              'metadata/inputs = '+json.dumps(inputs,sort_keys=True),
              'metadata/outputs = '+json.dumps(outputs,sort_keys=True),
              'metadata/masks = {'+',\n'.join(json.dumps(key)+f': ExtResource("{i+1}")' for i,key in enumerate(entries))+'}']
    (OUTPUT/'masks.tres').write_text('\n'.join(lines)+'\n')
    print(f'Baked {len(entries)} death masks: {sum(Image.open(ROOT/p[6:]).width*Image.open(ROOT/p[6:]).height for p in entries.values())} pixels')

if __name__ == '__main__':
    bake()
