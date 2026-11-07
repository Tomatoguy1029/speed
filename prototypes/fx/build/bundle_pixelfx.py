"""pixelFX の ES モジュールを、依存順に関数スコープへ包んで1本のスクリプトにする（コードは改変せず import/export だけ書き換える）。"""
import re, os, sys, json
SRC = sys.argv[1]; entry = sys.argv[2:]
mods = {}; order = []
def norm(base, spec):
    return os.path.normpath(os.path.join(os.path.dirname(base), spec))
def load(path):
    if path in mods: return
    mods[path] = None
    txt = open(os.path.join(SRC, path)).read()
    deps = []; body = txt
    def imp(m):
        names, spec = m.group(1).strip(), m.group(2)
        p = norm(path, spec); deps.append(p)
        if names.startswith('* as'):
            return f'const {names[4:].strip()} = __req({json.dumps(p)});'
        inner = names.strip('{} ')
        parts = [x.strip() for x in inner.split(',') if x.strip()]
        js = ', '.join(f'{a.split(" as ")[0].strip()}: {a.split(" as ")[1].strip()}' if ' as ' in a else a for a in parts)
        return f'const {{ {js} }} = __req({json.dumps(p)});'
    body = re.sub(r'^import\s+(.+?)\s+from\s+"([^"]+)";', imp, body, flags=re.M | re.S)
    exports = []
    def star(m):
        p = norm(path, m.group(1)); deps.append(p); return f'Object.assign(__exp, __req({json.dumps(p)}));'
    body = re.sub(r'^export \* from "([^"]+)";', star, body, flags=re.M)
    def reexp(m):
        p = norm(path, m.group(2)); deps.append(p); out = []
        for a in [x.strip() for x in m.group(1).split(',') if x.strip()]:
            src, dst = (a.split(' as ') + [a])[:2] if ' as ' in a else (a, a)
            out.append(f'__exp[{json.dumps(dst.strip())}] = __req({json.dumps(p)})[{json.dumps(src.strip())}];')
        return ' '.join(out)
    body = re.sub(r'^export\s*\{([^}]*)\}\s*from\s*"([^"]+)";', reexp, body, flags=re.M)
    def decl(m):
        kind, name = m.group(1), m.group(2); exports.append(name); return f'{kind} {name}'
    body = re.sub(r'^export\s+(function\*?|async function|class|const|let|var)\s+([A-Za-z_$][\w$]*)', decl, body, flags=re.M)
    def lst(m):
        out = []
        for a in [x.strip() for x in m.group(1).split(',') if x.strip()]:
            src, dst = [y.strip() for y in a.split(' as ')] if ' as ' in a else (a, a)
            out.append(f'__exp[{json.dumps(dst)}] = {src};')
        return ' '.join(out)
    body = re.sub(r'^export\s*\{([^}]*)\};?', lst, body, flags=re.M)
    # const の分割代入 export（export const { a, b } = ...）は使われていない前提。見つかったら止める。
    assert not re.search(r'^\s*export ', re.sub(r'//.*', '', body), re.M), path
    tail = ''.join(f'\n__exp[{json.dumps(n)}] = {n};' for n in exports)
    mods[path] = f'__def({json.dumps(path)}, function(__exp, __req) {{\n{body}{tail}\n}});'
    for d in deps: load(d)
for e in entry: load(e)
print('/* pixelFX (MIT) https://github.com/patch-gg/pixelfx — Copyright (c) 2026 Patch, Copyright (c) 2026 Hugo Duprez. See LICENSE/NOTICE in this page. */')
print('const PIXELFX = (function(){ const __defs = {}, __cache = {};')
print('function __def(p, f) { __defs[p] = f; }')
print('function __req(p) { if (__cache[p]) return __cache[p]; const e = __cache[p] = {}; __defs[p](e, __req); return e; }')
for p, code in mods.items(): print(code)
print('return { core: __req("src/core/index.js"), fx: { ' + ', '.join(f'{json.dumps(e)}: __req({json.dumps(e)})' for e in entry if e.startswith('src/fx')) + ' } };')
print('})();')
