#!/usr/bin/env python3
"""Bake inward fragment erosion from the existing landmark silhouettes (Pillow only).

No runtime partitioning, random numbers, particle trajectories or image reads.
Each source pixel stores its disappearance time during the half-second death.
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
        cells = [[] for _ in seeds]
        for y in range(height):
            for x in range(width):
                index = min(range(len(seeds)),key=lambda i:(x-seeds[i][0])**2+(y-seeds[i][1])**2)
                distance = math.hypot(x-seeds[index][0],y-seeds[index][1])
                cells[index].append((x,y,distance))
        image = Image.new('L',(width,height))
        for seed, cell in zip(seeds,cells):
            extent = max(1.0,max(p[2] for p in cell))
            for x,y,distance in cell:
                # Edges disappear first, leaving small islands that contract in place.
                threshold = 0.10+(seed[2]-0.10)*(1.0-distance/(extent+0.5))
                image.putpixel((x,y),max(1,min(250,round(threshold*255))))
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
    lines += ['', '[resource]', 'metadata/bake_version = 1', 'metadata/lifetime = 0.5',
              'metadata/inputs = '+json.dumps(inputs,sort_keys=True),
              'metadata/outputs = '+json.dumps(outputs,sort_keys=True),
              'metadata/masks = {'+',\n'.join(json.dumps(key)+f': ExtResource("{i+1}")' for i,key in enumerate(entries))+'}']
    (OUTPUT/'masks.tres').write_text('\n'.join(lines)+'\n')
    print(f'Baked {len(entries)} death masks: {sum(Image.open(ROOT/p[6:]).width*Image.open(ROOT/p[6:]).height for p in entries.values())} pixels')

if __name__ == '__main__':
    bake()
