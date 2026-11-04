"""素材JSON・pixelFX・試作コードを1枚のHTMLへまとめる。
作り直す手順（pixelFX は https://github.com/patch-gg/pixelfx をリポジトリの外へ clone する）：
  python3 extract.py /tmp/fx_data.json
  python3 assemble.py /tmp/fx_data.json <pixelfx> ../speed_fx_prototypes.html
"""
import json, os, sys, subprocess
B = os.path.dirname(os.path.abspath(__file__))
data_path, pixelfx_dir, out = sys.argv[1], sys.argv[2], sys.argv[3]
shell = open(f'{B}/app/shell.html', encoding='utf-8').read()
data = open(data_path, encoding='utf-8').read()
px = subprocess.check_output([sys.executable, f'{B}/bundle_pixelfx.py', pixelfx_dir, 'src/core/index.js', 'src/fx/impacts/_lib.js', 'src/fx/melee/_lib.js', 'src/fx/fire/_lib.js'], text=True)
order = ['core.js', 'fxlib.js', 'runtime.js', 'ledger.js', 'centaurus.js', 'enemies_a.js', 'enemies_b.js', 'enemies_c.js', 'bosses_common.js', 'roar.js', 'canis_fx.js', 'canis_light.js', 'canis.js', 'monoceros_fx.js', 'mono_boost.js', 'monoceros.js', 'hydra.js', 'hydra_major.js', 'draco.js']
app = '\n'.join(open(f'{B}/app/{f}', encoding='utf-8').read() for f in order)
app += "\nconst CAT_ORDER = ['ボスへの命中 G10', '鳳凰 G11', '敵（ステージ1以外）G12', 'ケンタウルス座（C）', 'おおいぬ座（O）', 'いっかくじゅう座（I）', 'うみへび座（H）', 'りゅう座（D）', '参照（ステージ1）'];\nDEMOS.sort((a, b) => CAT_ORDER.indexOf(a.cat) - CAT_ORDER.indexOf(b.cat));\n"
lic = ('■ pixelFX（MIT） https://github.com/patch-gg/pixelfx\n' + open(f'{pixelfx_dir}/LICENSE', encoding='utf-8').read()
       + '\n' + open(f'{pixelfx_dir}/NOTICE.md', encoding='utf-8').read()
       + '\n■ 試作で同梱・利用した pixelFX のコード：src/core（Painter・フレーム・色・数学など）。効果の形は arcane-beam.js・laser-bolt.js・sword-slash.js・heavy-cleave.js の手法を参考に SPEED 向けに書き直した。impacts/_lib.js・melee/_lib.js は原本を同梱し、圧力の面と斬撃の描画に使用。fire/_lib.js は残り火の炎と熾火に使用。fire/flamethrower.js・fire/fire-breath.js・fire/fireball.js・ice/frost-breath.js は原本から配色を指定して出力したスプライトを同梱。flamethrower は射程・流速・出力範囲も調整。pixelFX の Patch Pixel フォントは使っていない。'
       + '\n\n■ SPEED の素材・データ（このリポジトリの speed/assets・speed/data・speed/shaders・speed/scenes を読み取り、塗装・照明を焼き込んで埋め込み）。プロジェクトの素材の扱いに従う。')
app += '\nconst LICENSE_TEXT = ' + json.dumps(lic, ensure_ascii=False) + ';\n'
html = shell.replace('/*DATA*/', 'const DATA = ' + data + ';').replace('/*PIXELFX*/', px.replace('</script', '<\\/script')).replace('/*APP*/', app.replace('</script', '<\\/script'))
open(out, 'w', encoding='utf-8').write(html)
print('wrote', out, len(html))
