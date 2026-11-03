"""残り4ボスの現行パーツ・技を、独立HTML用に読み取る。ゲーム側へは書き込まない。"""
import os
import re
import gdres


def extract_bosses(out, image_url, lit, Image):
    root = gdres.ROOT

    def clean(value):
        if isinstance(value, gdres.Ref):
            return {'ref': value.kind, 'id': value.id}
        if isinstance(value, dict):
            return {k: clean(v) for k, v in value.items()}
        if isinstance(value, list):
            return [clean(v) for v in value]
        return value

    def resource(path):
        data = gdres.resource(path)
        values = {}
        script = data['res'].get('script')
        if isinstance(script, gdres.Ref):
            source = open(root + '/' + data['ext'][script.id].replace('res://', ''), encoding='utf-8').read()
            for m in re.finditer(r'@export[^\n]*?var\s+(\w+)(?:\s*:\s*\w+)?\s*(?::=|=)\s*([^\n]+)', source):
                try:
                    values[m[1]] = gdres.parse_value(gdres.Tok(m[2].rstrip(':')))
                except (ValueError, AssertionError, IndexError):
                    pass
        values.update(data['res'])
        return clean(values)

    out['bosses'] = {}
    for name in ['canis_major', 'monoceros', 'hydra', 'draco']:
        boss = {'def': resource('data/bosses/' + name + '.tres'), 'moves': {}, 'nodes': []}
        folder = root + '/data/bosses/' + name + '_moves'
        if os.path.isdir(folder):
            for filename in sorted(os.listdir(folder)):
                if filename.endswith('.tres'):
                    boss['moves'][filename[:-5]] = resource('data/bosses/' + name + '_moves/' + filename)
        scene_path = 'scenes/bosses/' + name + '_parts.tscn'
        if os.path.exists(root + '/' + scene_path):
            scene = gdres.resource(scene_path)
            ext, subs = scene['ext'], scene['sub']

            def texture(ref):
                if ref.kind == 'ExtResource':
                    path = ext[ref.id]
                    if path.endswith('.tres'):
                        doc = gdres.resource(path)
                        props = doc['res']
                        if 'diffuse_texture' in props:
                            image_path = doc['ext'][props['diffuse_texture'].id]
                            key = name + '/' + os.path.basename(image_path)
                            im = Image.open(root + '/' + image_path.replace('res://', '')).convert('RGBA')
                            normal = props.get('normal_texture')
                            if normal:
                                normal_path = doc['ext'][normal.id]
                                im = lit(im, Image.open(root + '/' + normal_path.replace('res://', '')), {})
                            out['images'][key] = image_url(im)
                            return {'key': key, 'metadata': clean({k[9:]: v for k, v in props.items() if k.startswith('metadata/')})}
                        return None
                    key = name + '/' + os.path.basename(path)
                    if key not in out['images']:
                        im = Image.open(root + '/' + path.replace('res://', '')).convert('RGBA')
                        if not path.endswith('_normal.png'):
                            normal_path = root + '/' + path.replace('res://', '').replace('.png', '_normal.png')
                            if os.path.exists(normal_path):
                                im = lit(im, Image.open(normal_path), {})
                        out['images'][key] = image_url(im)
                    return {'key': key}
                sub = subs[ref.id]
                props, kind = sub['props'], sub['attrs']['type']
                if kind == 'CanvasTexture':
                    return texture(props['diffuse_texture'])
                if kind == 'AtlasTexture':
                    return {**texture(props['atlas']), 'region': props['region']}
                if kind == 'AnimatedTexture':
                    frames = []
                    for index in range(props.get('frames', 1)):
                        key = 'frame_' + str(index) + '/texture'
                        if key in props:
                            frames.append({**texture(props[key]), 'duration': props.get('frame_' + str(index) + '/duration', 1.0)})
                    return {'frames': frames, 'metadata': clean({k[9:]: v for k, v in props.items() if k.startswith('metadata/')})}
                return None

            for section in scene['sections']:
                if section['tag'] != 'node':
                    continue
                attrs, props = section['attrs'], section['props']
                node = {**attrs, **clean(props)}
                if isinstance(props.get('texture'), gdres.Ref):
                    node['texture'] = texture(props['texture'])
                boss['nodes'].append(node)
            boss['scene'] = scene_path
            if name == 'monoceros':
                horn = gdres.resource('scenes/bosses/monoceros_presentation.tscn')
                horn_node = next(s for s in horn['sections'] if s['attrs'].get('name') == 'Horn')
                # 外部Textureの参照だけ一時的に解決し、パーツの子として加える。
                ext['html_horn'] = horn['ext'][horn_node['props']['texture'].id]
                boss['nodes'].append({**horn_node['attrs'], **clean(horn_node['props']), 'parent': 'Head/Lower', 'texture': texture(gdres.Ref('ExtResource', 'html_horn'))})
                gait = gdres.resource('data/visuals/monoceros_gait.tres')
                ext.update({'gait_' + k: v for k, v in gait['ext'].items()})
                def remap(v):
                    if isinstance(v, gdres.Ref):
                        return gdres.Ref(v.kind, 'gait_' + v.id)
                    if isinstance(v, dict):
                        return {k: remap(x) for k, x in v.items()}
                    if isinstance(v, list):
                        return [remap(x) for x in v]
                    return v
                subs.update({'gait_' + k: {**v, 'props': remap(v['props'])} for k, v in gait['sub'].items()})
                boss['gait'] = {a['name']: {**clean(a), 'frames': [{**clean(f), 'texture': texture(remap(f['texture']))} for f in a['frames']]} for a in gait['res']['animations']}
        out['bosses'][name] = boss
    for name in ['star', 'large_star']:
        out['images']['canis_major/' + name] = image_url(Image.open(root + '/assets/pixel/canis_major/' + name + '.png').convert('RGBA'))
