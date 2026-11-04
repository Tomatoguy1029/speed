"""Offline comet assets. Requires Pillow, Node 18+, ffmpeg, Aseprite and pixelfx.

python generate_comet_effects.py --pixelfx-root PATH --aseprite PATH --preview-dir PATH
pixelfx: https://github.com/patch-gg/pixelfx at a84159688af3ca37a4be05a0d422b94451b2e24e.
"""
import argparse
import json
import math
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image


def aseprite_layers(executable, work, destination):
    script = work / 'assemble.lua'
    # Lua long strings preserve paths with spaces, Unicode and Windows separators.
    script.write_text(f"""local dir = [=[{work.as_posix()}/]=]
local output = [=[{destination.as_posix()}]=]
local function loadImage(file)
 local s=app.open(file); local image=s.cels[1].image:clone(); s:close(); return image
end
local sprite=Sprite(248,128,ColorMode.RGB)
local core=sprite.layers[1]; core.name='Hand-drawn comet - slow sway'
if sprite.cels[1] then sprite:deleteCel(sprite.cels[1]) end
local effect=sprite:newLayer(); effect.name='Frost effect - original opacity'
for i=1,108 do
 if i>1 then sprite:newEmptyFrame() end
 sprite:newCel(core,i,loadImage(dir..string.format('core-%03d.png',i-1)),Point(0,0))
 sprite:newCel(effect,i,loadImage(dir..string.format('tail-%02d.png',(i-1)%36)),Point(0,0))
 sprite.frames[i].duration=(i%3==0) and 0.034 or 0.033
end
sprite:saveAs(output); sprite:close()
local check=app.open(output)
assert(#check.frames==108 and #check.layers==2)
assert(check.layers[2].name=='Frost effect - original opacity')
assert(check.layers[1].opacity==255 and check.layers[2].opacity==255)
check:close()
""", encoding='utf-8')
    subprocess.run([executable, '--batch', '--script', str(script)], check=True)
    if not destination.is_file():
        raise RuntimeError(f'Aseprite did not produce {destination}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pixelfx-root', type=Path, required=True)
    parser.add_argument('--aseprite', required=True)
    parser.add_argument('--preview-dir', type=Path, required=True)
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    assets = here.parents[1] / 'assets/fx/comets'
    args.preview_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='speed-comet-', dir=args.preview_dir.resolve()) as temp:
        temp = Path(temp)
        subprocess.run(['node', str(here / 'pixelfx/export_comet_tails.mjs'),
                        str(args.pixelfx_root.resolve()), str(temp)], check=True)
        for variant, source in [('normal', 'comet.png'), ('rare', 'comet_rare.png')]:
            work = temp / variant
            art = Image.open(assets / 'source' / source).convert('RGBA')
            bbox = art.getbbox()
            if bbox is None:
                raise ValueError(f'Empty art: {source}')
            core_resource = ('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
                             f'[ext_resource type="Texture2D" path="res://assets/fx/comets/source/{source}" id="1"]\n\n'
                             '[resource]\natlas = ExtResource("1")\n'
                             f'region = Rect2({bbox[0]}, {bbox[1]}, {bbox[2] - bbox[0]}, {bbox[3] - bbox[1]})\n')
            (assets / f'{variant}_core.tres').write_text(core_resource, encoding='utf-8')
            crop = art.crop(bbox)
            crop = crop.resize((round(crop.width * .8), round(crop.height * .8)), Image.Resampling.NEAREST)
            x0, y0 = round(190 - crop.width / 2), round(60 - crop.height / 2)
            tails = [Image.open(work / f'tail-{i:02}.png').convert('RGBA') for i in range(36)]
            atlas = Image.new('RGBA', (1240, 1024))
            frames = []
            for i, tail in enumerate(tails):
                x, y = i % 5 * 248, i // 5 * 128
                atlas.paste(tail, (x, y))  # Copy straight RGBA; alpha compositing here would premultiply twice.
                frames.append({'filename': f'{variant}-tail {i}', 'frame': {'x': x, 'y': y, 'w': 248, 'h': 128},
                               'rotated': False, 'trimmed': False, 'duration': 34 if i % 3 == 2 else 33,
                               'sourceSize': {'w': 248, 'h': 128},
                               'spriteSourceSize': {'x': 0, 'y': 0, 'w': 248, 'h': 128}})
            assert atlas.getchannel('A').getextrema()[0] == 0
            atlas.save(assets / f'{variant}_tail.png')
            metadata = {'frames': frames, 'meta': {'image': f'{variant}_tail.png', 'size': {'w': 1240, 'h': 1024},
                        'frameTags': [{'name': 'Tail', 'from': 0, 'to': 35, 'direction': 'forward'}],
                        'pixelfx': {'fps': 30, 'loop': True, 'frames': 36, 'frameSize': [248, 128],
                                    'pivot': [194, 60], 'columns': 5}}}
            (assets / f'{variant}_tail.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
            previews = []
            for i in range(108):
                core = Image.new('RGBA', (248, 128))
                dy = round(2 * math.sin(2 * math.pi * i / 108))
                core.alpha_composite(crop, (x0, y0 + dy))
                core.save(work / f'core-{i:03}.png')
                composed = Image.alpha_composite(core, tails[i % 36])
                bg = Image.new('RGBA', (248, 128), (20, 19, 30, 255))
                bg.alpha_composite(composed)
                previews.append(bg.tobytes())
                if i == 9:
                    bg.resize((744, 384), Image.Resampling.NEAREST).save(args.preview_dir / f'{variant}.png')
            aseprite_layers(args.aseprite, work, assets / f'{variant}.aseprite')
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', '248x128',
                            '-r', '30', '-i', '-', '-vf', 'scale=744:384:flags=neighbor,split[a][b];'
                            '[a]palettegen=max_colors=255:stats_mode=full[p];[b][p]paletteuse=dither=none',
                            '-loop', '0', str(args.preview_dir / f'{variant}.gif')], input=b''.join(previews), check=True)
            shutil.copy2(assets / f'{variant}.aseprite', args.preview_dir / f'{variant}.aseprite')
            print(f'{variant}: 36 tail frames, 108 composition frames; art {crop.size}, opacity unchanged.')


if __name__ == '__main__':
    main()
