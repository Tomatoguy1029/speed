#!/usr/bin/env python3
"""承認した咆哮の固定模様を、元と同じCanvas2Dで生成する。"""
from pathlib import Path
import argparse
import base64
import hashlib
import html
import json
import re
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[2]
JAVASCRIPT = 'class Rng {\n  constructor(seed = 1) {\n    this.s = seed >>> 0 || 1;\n  }\n  next() {\n    let t = (this.s = (this.s + 0x6d2b79f5) >>> 0);\n    t = Math.imul(t ^ (t >>> 15), t | 1);\n    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);\n    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;\n  }\n  range(a, b) {\n    return a + (b - a) * this.next();\n  }\n  int(a, b) {\n    return Math.floor(this.range(a, b + 1));\n  }\n  chance(p) {\n    return this.next() < p;\n  }\n  sign() {\n    return this.next() < 0.5 ? -1 : 1;\n  }\n  pick(list) {\n    return list[Math.floor(this.next() * list.length)];\n  }\n  /** Roughly normal, mean 0, sd 1. */\n  gauss() {\n    return (this.next() + this.next() + this.next() + this.next() - 2) * 1.732;\n  }\n}\nconst PX={Rng}; const TAU=Math.PI*2; let roarStreaks=null,roarLumps=null;\nfunction roarStreakTex() { // 放射状の筋（角度ごとに濃さと長さが違う）。咆哮ごとに回して使う\n  if (roarStreaks) return roarStreaks; const c = document.createElement(\'canvas\'); c.width = c.height = 512; const x = c.getContext(\'2d\'), Rg = new PX.Rng(9);\n  x.translate(256, 256); for (let i = 0; i < 420; i++) { const a = Rg.range(0, TAU), r0 = Rg.range(40, 150), r1 = r0 + Rg.range(60, 220), al = Rg.range(0.25, 1); x.strokeStyle = `rgba(255,255,255,${al})`; x.lineWidth = Rg.range(1, 4); x.beginPath(); x.moveTo(Math.cos(a) * r0, Math.sin(a) * r0); x.lineTo(Math.cos(a) * r1, Math.sin(a) * r1); x.stroke(); }\n  return (roarStreaks = c);\n}\nfunction roarLumpTex() { // 大きなむら（角度ごとに帯を途切れさせる）\n  if (roarLumps) return roarLumps; const c = document.createElement(\'canvas\'); c.width = c.height = 256; const x = c.getContext(\'2d\'), Rg = new PX.Rng(21);\n  for (let i = 0; i < 26; i++) { const px = Rg.range(0, 256), py = Rg.range(0, 256), r = Rg.range(25, 70), gr = x.createRadialGradient(px, py, 0, px, py, r); gr.addColorStop(0, `rgba(255,255,255,${Rg.range(0.6, 1)})`); gr.addColorStop(1, \'rgba(255,255,255,0)\'); x.fillStyle = gr; x.fillRect(0, 0, 256, 256); }\n  return (roarLumps = c);\n}\ndocument.getElementById("result").textContent=JSON.stringify({streaks:roarStreakTex().toDataURL(),lumps:roarLumpTex().toDataURL()});'


def bake(chrome):
    with tempfile.TemporaryDirectory(prefix='speed-roar-bake.',dir='/private/tmp') as temporary:
        directory=Path(temporary)
        page=directory/'bake.html'
        page.write_text('<!doctype html><meta charset="utf-8"><pre id="result"></pre><script>'+JAVASCRIPT+'</script>')
        result=subprocess.run([chrome,'--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking','--disable-sync','--disable-gpu','--user-data-dir='+str(directory/'profile'),'--dump-dom',page.as_uri()],capture_output=True,text=True,check=True)
        match=re.search(r'<pre id="result">([^<]+)</pre>',result.stdout)
        if not match: raise RuntimeError('Canvas2Dの生成結果がありません: '+result.stderr[-1000:])
        images=json.loads(html.unescape(match[1]))
    output=ROOT/'assets/effects/reference/roar'
    output.mkdir(parents=True,exist_ok=True)
    inputs={'res://'+Path(__file__).resolve().relative_to(ROOT).as_posix():hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    outputs={}
    for name,data in images.items():
        path=output/(name+'.png')
        path.write_bytes(base64.b64decode(data.split(',',1)[1],validate=True))
        asset='res://'+path.relative_to(ROOT).as_posix()
        cache='res://.godot/imported/'+path.name+'-'+hashlib.md5(asset.encode()).hexdigest()+'.ctex'
        settings=path.with_suffix('.png.import')
        settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\npath="'+cache+'"\n\n[deps]\nsource_file="'+asset+'"\ndest_files=["'+cache+'"]\n\n[params]\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=false\n')
        inputs['res://'+settings.relative_to(ROOT).as_posix()]=hashlib.sha256(settings.read_bytes()).hexdigest()
        outputs[asset]=hashlib.sha256(path.read_bytes()).hexdigest()
    version=subprocess.check_output([chrome,'--version'],text=True).strip()
    (output/'textures.tres').write_text('[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/bake_version = 1\nmetadata/inputs = '+json.dumps(inputs,sort_keys=True)+'\nmetadata/outputs = '+json.dumps(outputs,sort_keys=True)+'\nmetadata/canvas_engine = '+json.dumps(version)+'\n')
    print('咆哮の筋とむらを生成:',output)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chrome',default='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
    bake(parser.parse_args().chrome)
