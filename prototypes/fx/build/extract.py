"""SPEED の現行素材・設定を読み、HTML 試作用の JSON を作る（本体のファイルは読むだけ）。"""
import sys, os, json, base64, io, math, hashlib
sys.path.insert(0, os.path.dirname(__file__))
import gdres
from PIL import Image
R = gdres.ROOT
def P(res): return R + '/' + res.replace('res://', '')
def durl(img):
    b = io.BytesIO(); img.save(b, 'PNG'); return 'data:image/png;base64,' + base64.b64encode(b.getvalue()).decode()
def file_durl(path, mime):
    return f'data:{mime};base64,' + base64.b64encode(open(path, 'rb').read()).decode()
def jsonable(v):
    if isinstance(v, gdres.Ref): return {'ref': v.kind, 'id': v.id}
    if isinstance(v, dict): return {k: jsonable(x) for k, x in v.items()}
    if isinstance(v, list): return [jsonable(x) for x in v]
    return v
# ---------- 装甲の領域分け（tools/content/visual_transforms.gd の layout/_partition/painted_image と同じ規則）
def layout(path):
    im = Image.open(path).convert('RGBA'); w, h = im.size; px = im.load()
    n = w * h; opaque = [0]*n; labels = [-1]*n; shades = [0.0]*n
    for i in range(n):
        r, g, b, a = px[i % w, i // w]
        opaque[i] = 1 if a > 0 else 0
        shades[i] = (r*0.2126 + g*0.7152 + b*0.0722) / 255.0
    regions = {}
    for s in range(n):
        if not opaque[s] or labels[s] >= 0: continue
        pix = [s]; labels[s] = s; cur = 0; bright = 0.001
        while cur < len(pix):
            p = pix[cur]; cur += 1; bright = max(bright, shades[p]); x = p % w
            for nb in (p-1 if x > 0 else -1, p+1 if x < w-1 else -1, p-w, p+w):
                if nb < 0 or nb >= n or not opaque[nb] or labels[nb] >= 0: continue
                labels[nb] = s; pix.append(nb)
        for p in pix: shades[p] = shades[p]/bright if bright > 0.001 else 1.0
        regions[s] = pix
    alpha_hash = hashlib.sha256(bytes(opaque)).hexdigest()
    res = 'res://' + os.path.relpath(path, R)
    key = '%s|%dx%d|%s' % (res, w, h, alpha_hash)
    parents = {}
    part = os.path.splitext(path)[0] + '.regions.json'
    if os.path.exists(part):
        pj = json.load(open(part)); rows = pj['rows']
        nl = [-1]*n; nreg = {}
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                i = y*w + x; parent = labels[i]
                if parent < 0: continue
                reg = n + ord(ch)
                nreg.setdefault(reg, []).append(i); parents[reg] = parent; nl[i] = reg
        labels = nl; regions = nreg
    return {'im': im, 'w': w, 'h': h, 'regions': regions, 'shades': shades, 'key': key, 'parents': parents}
def region_colors(data, palettes):
    colors = palettes.get(data['key'], {})
    if not data['parents']: return dict(colors)
    out = {}
    for reg in data['regions']:
        k = str(reg); par = str(data['parents'][reg])
        if k in colors: out[k] = colors[k]
        elif par in colors: out[k] = colors[par]
    return out
def painted(data, palettes):
    im = data['im'].copy(); px = im.load(); w = data['w']
    for reg, col in region_colors(data, palettes).items():
        c = tuple(int(col[i:i+2], 16)/255.0 for i in (0, 2, 4))
        for p in data['regions'].get(int(reg), []):
            a = px[p % w, p // w][3]; s = data['shades'][p]
            px[p % w, p // w] = (round(c[0]*s*255), round(c[1]*s*255), round(c[2]*s*255), a)
    return im
# ---------- 照明（shaders/pixel_armor.gdshader の ambient + key/fill の拡散光を、向き0で焼き込む近似）
LIGHT = {'key_energy': 1.1, 'fill_energy': 0.6, 'key_angle': -45.0, 'fill_angle': 135.0, 'height': 0.25, 'ambient': 0.08, 'normal_strength': 1.0}
def lit(armor, normal, vs):
    L = dict(LIGHT); L.update({k: v for k, v in vs.items() if k in L})
    def ldir(a):
        d = (math.cos(math.radians(a)), math.sin(math.radians(a)), L['height']); m = math.sqrt(sum(x*x for x in d)); return [x/m for x in d]
    kd, fd = ldir(L['key_angle']), ldir(L['fill_angle'])
    out = armor.copy(); po = out.load(); pa = armor.load(); pn = normal.convert('RGBA').load() if normal else None
    w, h = armor.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pa[x, y]
            if a == 0: continue
            if pn:
                nr, ng, nb, _ = pn[x, y]
                nx, ny, nz = (nr/255*2-1)*L['normal_strength'], -(ng/255*2-1)*L['normal_strength'], max(nb/255*2-1, 0.001)
                m = math.sqrt(nx*nx+ny*ny+nz*nz); nx, ny, nz = nx/m, ny/m, nz/m
            else: nx, ny, nz = 0, 0, 1
            k = L['ambient'] + L['key_energy']*max(0, nx*kd[0]+ny*kd[1]+nz*kd[2]) + L['fill_energy']*max(0, nx*fd[0]+ny*fd[1]+nz*fd[2])
            po[x, y] = (min(255, round(r*k)), min(255, round(g*k)), min(255, round(b*k)), a)
    return out
def look_image(look_path, palettes, vs):
    lk = gdres.resource(look_path); res = lk['res']; ext = lk['ext']
    def tex(name):
        v = res.get(name); return Image.open(P(ext[v.id])).convert('RGBA') if isinstance(v, gdres.Ref) else None
    base = tex('base'); deco = tex('decorations'); normal = tex('normal')
    if deco: base.alpha_composite(deco)
    armor_path = P(ext[res['armor'].id])
    data = layout(armor_path)
    pal = dict(palettes)
    if res.get('armor_color_regions'):
        src_key = res.get('armor_color_source_key', ''); src = palettes.get(src_key, {})
        cols = dict(pal.get(data['key'], {}))
        for reg, other in res['armor_color_regions'].items():
            if reg not in cols and str(other) in src: cols[reg] = src[str(other)]
        pal[data['key']] = cols
    armor = painted(data, pal)
    armor = lit(armor, normal, vs)
    img = base.copy(); img.alpha_composite(armor)
    return img, res, ext, data['key']
ENEMIES = ['beamer','crab','defender','ruler','telescope','auriga','corona','hound','lynx','phoenix','aquarius','cross','dolphin','reticle','aquila','cepheus','cepheus_soldier','crow','swarm','marlin','biter','splitling','splitter']
out = {'enemies': {}, 'images': {}}
cfg = gdres.resource('data/config.tres')['res']
out['config'] = {k: cfg.get(k) for k in ['character_scale','base_view','ship_radius','zoom_ref_speed','zoom_exp','zoom_min','base_max_speed']}
for t in ENEMIES:
    d = gdres.resource(f'data/enemies/{t}.tres')['res']
    vs = d.get('visual_settings', {}) or {}
    e = {k: jsonable(d.get(k)) for k in ['id','display_name','rank','radius','hp','armor','speed','accel','turn','color','shape','behavior','params']}
    e['visual_settings'] = vs
    lp = P(f'data/visuals/looks/{t}.tres')
    if os.path.exists(lp):
        img, res, ext, key = look_image(lp, d.get('armor_colors', {}) or {}, vs)
        e['look'] = {'angle': res.get('angle', 0.0), 'fixed_angle': res.get('fixed_angle', False), 'size_from_collision': res.get('size_from_collision', False), 'w': img.size[0], 'h': img.size[1]}
        out['images']['enemy/'+t] = durl(img)
        if isinstance(res.get('split_other'), gdres.Ref):
            op = P(ext[res['split_other'].id])
            img2, res2, _, _ = look_image(op, d.get('armor_colors', {}) or {}, vs)
            e['look']['split_other'] = {'angle': res2.get('angle', 0.0)}
            out['images']['enemy/'+t+'/lower'] = durl(img2)
            out['images']['enemy/'+t+'/upper'] = out['images']['enemy/'+t]
            both = img.copy(); both.alpha_composite(img2); out['images']['enemy/'+t] = durl(both)
    out['enemies'][t] = e
    print('enemy', t, e.get('look', {}).get('w'), file=sys.stderr)
# ---------- 機体
ship = Image.open(P('assets/pixel/airship.png')).convert('RGBA')
out['images']['ship'] = durl(ship)
for n in ['airship_flame','airship_blue_flame']: out['images'][n] = durl(Image.open(P(f'assets/pixel/{n}.png')).convert('RGBA'))
# ---------- 矢（現行 main の light_arrow.svg をそのまま）
out['images']['light_arrow'] = file_durl(P('assets/fx/light_arrow.svg'), 'image/svg+xml')
# ---------- ケンタウルス：パーツシーン・アトラス・アニメーション
sc = gdres.parse('scenes/bosses/centaurus_parts.tscn')
ext = {s['attrs']['id']: s['attrs'].get('path') for s in sc if s['tag'] == 'ext_resource'}
sub = {s['attrs']['id']: s for s in sc if s['tag'] == 'sub_resource'}
def atlas_of(ref):
    s = sub[ref.id]['props']; a = s['atlas']
    if a.kind == 'SubResource': a = sub[a.id]['props']['diffuse_texture']
    return {'tex': os.path.basename(ext[a.id]).replace('.png', ''), 'region': s['region']}
nodes = []
for s in sc:
    if s['tag'] != 'node': continue
    pr = s['props']; at = s['attrs']
    n = {'name': at['name'], 'parent': at.get('parent'), 'type': at.get('type'),
         'position': pr.get('position', {'x': 0, 'y': 0}), 'rotation': pr.get('rotation', 0.0), 'scale': pr.get('scale', {'x': 1, 'y': 1}),
         'z_index': pr.get('z_index', 0), 'flip_h': pr.get('flip_h', False), 'centered': pr.get('centered', True), 'label': pr.get('metadata/part_label')}
    if isinstance(pr.get('texture'), gdres.Ref): n['texture'] = atlas_of(pr['texture'])
    nodes.append(n)
anim = gdres.resource('data/visuals/centaurus_animation.tres')['res']
out['centaurus'] = {'nodes': nodes, 'poses': jsonable(anim['poses']), 'clips': jsonable(anim['clips']), 'part_pivots': jsonable(anim.get('part_pivots', {})),
    'def': jsonable(gdres.resource('data/bosses/centaurus.tres')['res']), 'moves': {}}
for f in os.listdir(P('data/bosses/centaurus_moves')):
    out['centaurus']['moves'][f[:-5]] = jsonable(gdres.resource('data/bosses/centaurus_moves/' + f)['res'])
for n in ['base', 'armor', 'bow']:
    out['images']['centaurus/' + n] = durl(Image.open(P(f'assets/pixel/centaurus/{n}.png')).convert('RGBA'))
# ボスの装甲：法線付き照明の近似を焼き込む
out['images']['centaurus/armor_lit'] = durl(lit(Image.open(P('assets/pixel/centaurus/armor.png')).convert('RGBA'), Image.open(P('assets/pixel/centaurus/armor_normal.png')), {}))
bow_n = P('assets/pixel/centaurus/bow_normal.png')
out['images']['centaurus/bow_lit'] = durl(lit(Image.open(P('assets/pixel/centaurus/bow.png')).convert('RGBA'), Image.open(bow_n) if os.path.exists(bow_n) else None, {}))
# ---------- 背景の天体
for n in ['planet_a', 'station_a', 'asteroid_a']:
    out['images']['bg/' + n] = durl(Image.open(P(f'assets/pixel/background/{n}.png')).convert('RGBA'))
out['images']['meteor_0'] = durl(Image.open(P('assets/pixel/meteor_0.png')).convert('RGBA'))
out['images']['water_noise'] = durl(Image.open(P('assets/fx/water_noise.png')).convert('RGBA'))
# ---------- 効果設定（矢の見た目の上書きなど）
eff = gdres.resource('data/visuals/effect_settings.tres')['res']
out['effect_settings'] = jsonable({k: v for k, v in (eff or {}).items() if k != 'script'})
# 承認した炎と爆発の透過コマ。爆発は既存bomber_burstシェーダーの青い出力。
fx_assets = os.path.normpath(os.path.join(os.path.dirname(__file__), '../assets'))
for stem in ['canis_breath', 'canis_flamethrower', 'canis_fireball', 'hydra_wind', 'canis_bomber_burst']:
    out['images'][stem] = durl(Image.open(fx_assets + '/' + stem + '.png').convert('RGBA'))
    out[stem + '_sheet'] = json.load(open(fx_assets + '/' + stem + '.json'))
from boss_data import extract_bosses
extract_bosses(out, durl, lit, Image)
if __name__ == '__main__': json.dump(out, open(sys.argv[1], 'w'), ensure_ascii=False)
print('ok', os.path.getsize(sys.argv[1]), file=sys.stderr)
