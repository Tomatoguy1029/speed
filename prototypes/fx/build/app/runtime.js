// ===== 再生・切り替え・調整値・対応表 =====
const DEMOS = [];
const DT = 1 / 60;
const PARAMS = {};               // { demoId: { key: value } }。調整した値はこのブラウザに自動で残す（読み込み直しても消えない）
const PARAMS_KEY = 'speed-fx-params';
try { Object.assign(PARAMS, JSON.parse(localStorage.getItem(PARAMS_KEY) || '{}')); } catch (e) { }
function saveParams() { try { localStorage.setItem(PARAMS_KEY, JSON.stringify(PARAMS)); } catch (e) { } }
let demo = null, S = null, playT = 0, playing = true, loop = true, speed = 1, mode = 'proto', bgMode = 'game', showPlayerRef = false;
const STD_PARAMS = [
  { k: 'color', label: '主色', type: 'color' },
  { k: 'size', label: 'サイズ倍率', type: 'range', min: 0.5, max: 1.6, step: 0.01, def: 1 },
  { k: 'intensity', label: '強度', type: 'range', min: 0, max: 2, step: 0.01, def: 1 },
  { k: 'timing', label: 'FXの時間倍率', type: 'range', min: 0.5, max: 2, step: 0.01, def: 1 },
];
function paramDefs(d) { return [...STD_PARAMS.map(p => p.k === 'color' ? { ...p, def: d.color || '#ffffff' } : d.defaults?.[p.k] != null ? { ...p, def: d.defaults[p.k] } : p), ...(d.params || [])]; }
// 初期値と違う値だけを、試作ごとにまとめた文字列にする（貼り付けて渡せば初期値に入れられる）
function changedParamsText() {
  const out = {};
  for (const d of DEMOS) { const cur = PARAMS[d.id]; if (!cur) continue; for (const p of paramDefs(d)) if (cur[p.k] != null && cur[p.k] !== p.def) (out[d.id] ||= {})[p.k] = cur[p.k]; }
  return Object.keys(out).length ? 'FX試作の調整値\n' + JSON.stringify(out, null, 1) : '';
}
function P() { const out = {}; for (const p of paramDefs(demo)) out[p.k] = PARAMS[demo.id]?.[p.k] ?? p.def; return out; }
function resetSim() { S = { t: 0, ev: [], ents: [], hz: [], fx: [], rng: mkRng(7) }; cam.x = demo.cam?.x ?? 0; cam.y = demo.cam?.y ?? 0; cam.zoom = 1; WL = Z / LP; demo.setup(S); demo.step(S, 0); } // 最初のコマを描く前に状態を整える（t=0 で描画が落ちないように）
function simTo(t) {
  if (!S || t < S.t - 1e-9) resetSim();
  let guard = 0;
  while (S.t + DT <= t + 1e-9 && guard++ < 20000) { demo.step(S, DT); S.t += DT; }
}
function emit(S, kind, data) { S.ev.push({ kind, t: S.t, ...data }); }
const since = (S, e) => S.t - e.t;

// ---------- 背景（現行の背景近似：暗い宇宙色・視差つきの星・ステージの天体）
const STARS = Array.from({ length: 220 }, (_, i) => ({ x: hash(i * 3.1), y: hash(i * 7.7 + 2), z: hash(i * 1.3 + 9) }));
function drawBackground() {
  g.setTransform(1, 0, 0, 1, 0, 0);
  if (bgMode === 'dark') { g.fillStyle = '#000'; g.fillRect(0, 0, W, H); return; }
  g.fillStyle = '#05060f'; g.fillRect(0, 0, W, H);
  const pl = IMG['bg/' + (demo.bg || 'planet_a')];
  if (pl) { g.globalAlpha = 0.55; g.imageSmoothingEnabled = false; const s = 2.2; g.drawImage(pl, W * 0.72 - cam.x * Z * 0.15, H * 0.12 - cam.y * Z * 0.15, pl.width * s, pl.height * s); g.globalAlpha = 1; }
  for (const st of STARS) {
    const par = 1 - st.z * 0.3, x = ((st.x * 5000 - cam.x * par) * Z % W + W) % W, y = ((st.y * 5000 - cam.y * par) * Z % H + H) % H;
    const r = 1.2 * st.z * 1.6; g.fillStyle = `rgba(200,215,255,${0.25 + 0.5 * st.z})`; g.fillRect(Math.round(x), Math.round(y), Math.max(1, r), Math.max(1, r));
  }
}
// ---------- 1フレームの描画
function render() {
  WL = Z / LP * cam.zoom;
  drawBackground();
  PX.clearFrame(FR.back); PX.clearFrame(FR.front);
  const R = {
    mode, P: P(), proto: mode === 'proto',
    back: painter('back'), front: painter('front'),
    blitBack() { g.save(); blitFrame(FR.back); g.restore(); worldTransform(); PX.clearFrame(FR.back); },
  };
  worldTransform();
  demo.draw(S, R);
  g.save(); blitFrame(FR.front); g.restore();
  // 情報表示
  g.setTransform(1, 0, 0, 1, 0, 0);
  const ph = demo.phase ? demo.phase(S) : '';
  g.font = '15px system-ui, sans-serif'; g.fillStyle = 'rgba(0,0,0,.55)'; g.fillRect(10, 10, 560, 52);
  g.fillStyle = '#fff'; g.fillText(`${demo.group}｜${demo.title}　[${demo.ids.join(' / ')}]`, 20, 31);
  g.fillStyle = mode === 'proto' ? '#ffd27a' : '#9fd3ff';
  g.fillText(`${mode === 'proto' ? '試作' : '現行'}　t=${S.t.toFixed(2)}s　${ph}`, 20, 52);
}

// ---------- UI
const $ = (s) => document.querySelector(s);
function el(tag, attrs = {}, ...kids) { const e = document.createElement(tag); for (const [k, v] of Object.entries(attrs)) { if (k === 'class') e.className = v; else if (k.startsWith('on')) e.addEventListener(k.slice(2), v); else e.setAttribute(k, v); } for (const k of kids) e.append(k); return e; }
function buildList() {
  const cats = [...new Set(DEMOS.map(d => d.cat))];
  const sel = $('#cat'); sel.innerHTML = '';
  sel.append(el('option', { value: '' }, 'すべてのカテゴリ'));
  for (const c of cats) sel.append(el('option', { value: c }, c));
  refreshDemoSelect();
}
function refreshDemoSelect() {
  const c = $('#cat').value, q = $('#idfilter').value.trim().toUpperCase();
  const s = $('#demo'); const keep = demo?.id; s.innerHTML = '';
  for (const d of DEMOS) {
    if (c && d.cat !== c) continue;
    if (q && !d.ids.some(x => x.toUpperCase().includes(q)) && !d.id.toUpperCase().includes(q)) continue;
    s.append(el('option', { value: d.id }, `${d.group}｜${d.title}（${d.ids.join(',')}）`));
  }
  if (keep && [...s.options].some(o => o.value === keep)) s.value = keep;
}
function selectDemo(id) {
  demo = DEMOS.find(d => d.id === id) || DEMOS[0];
  $('#demo').value = demo.id;
  playT = 0; resetSim(); buildParams(); buildInfo();
  $('#scrub').max = demo.duration;
}
function buildParams() {
  const box = $('#params'); box.innerHTML = '';
  for (const p of paramDefs(demo)) {
    const v = PARAMS[demo.id]?.[p.k] ?? p.def;
    const inp = p.type === 'color' ? el('input', { type: 'color', value: v }) : el('input', { type: 'range', min: p.min, max: p.max, step: p.step, value: v });
    const out = el('span', { class: 'val' }, p.type === 'color' ? '' : (+v).toFixed(2));
    inp.addEventListener('input', () => { (PARAMS[demo.id] ||= {})[p.k] = p.type === 'color' ? inp.value : +inp.value; out.textContent = p.type === 'color' ? '' : (+inp.value).toFixed(2); saveParams(); resetSim(); });
    box.append(el('label', {}, el('span', { class: 'pl' }, p.label), inp, out));
  }
  const copied = el('span', { class: 'val' }, '');
  box.append(el('button', { onclick: () => { const t = changedParamsText(); if (!t) { copied.textContent = '初期値から変えた値はありません'; return; } const done = () => { copied.textContent = 'コピーしました（全部の試作の分）'; }; (navigator.clipboard?.writeText(t) || Promise.reject()).then(done, () => { window.prompt('この文字列をコピーしてください', t.replace(/\n/g, ' ')); }); } }, '調整した値をコピー'), copied);
  box.append(el('button', { onclick: () => { delete PARAMS[demo.id]; saveParams(); buildParams(); resetSim(); } }, 'この試作を元の初期値に戻す'));
}
function buildInfo() {
  const i = $('#info'); i.innerHTML = '';
  i.append(el('h3', {}, `${demo.group}｜${demo.title}`));
  i.append(el('p', {}, el('b', {}, '改善ID：'), demo.ids.join('、'), '　', el('b', {}, '試作ID：'), demo.id));
  for (const [k, v] of Object.entries(demo.status || {})) i.append(el('p', {}, el('b', {}, k + '：'), v));
  if (demo.notes) i.append(el('p', { class: 'note' }, demo.notes));
  if (demo.refs?.length) { const ul = el('ul'); demo.refs.forEach(r => ul.append(el('li', {}, r))); i.append(el('h4', {}, '参照した現行実装・素材・pixelFX'), ul); }
}
function buildLedger() {
  const tb = $('#ledger tbody'); tb.innerHTML = '';
  for (const L of LEDGER) {
    const demos = DEMOS.filter(d => d.ids.includes(L.id));
    const links = el('td');
    demos.forEach(d => links.append(el('a', { href: '#', onclick: (e) => { e.preventDefault(); selectDemo(d.id); window.scrollTo(0, 0); } }, d.id), ' '));
    if (!demos.length) links.append('—');
    tb.append(el('tr', { class: 'st-' + L.cls }, el('td', {}, L.id), el('td', {}, L.title), el('td', {}, L.timing), el('td', {}, L.state), links, el('td', {}, L.open || '')));
  }
  const n = LEDGER.length, ids = new Set(LEDGER.map(l => l.id));
  $('#ledgerCount').textContent = `台帳 ${n} 件（重複なし：${ids.size === n ? 'OK' : 'NG'}）／試作 ${DEMOS.length} 本`;
}
function saveJSON() {
  const blob = new Blob([JSON.stringify({ format: 'speed-fx-proto/1', params: PARAMS }, null, 2)], { type: 'application/json' });
  const a = el('a', { href: URL.createObjectURL(blob), download: 'speed_fx_params.json' }); document.body.append(a); a.click(); a.remove();
}
function loadJSON(file) {
  file.text().then(t => { const j = JSON.parse(t); const p = j.params || j; for (const [id, v] of Object.entries(p)) PARAMS[id] = { ...v }; buildParams(); $('#status').textContent = `読み込み：${Object.keys(p).length} 件の試作の値`; })
    .catch(e => { $('#status').textContent = '読み込み失敗：' + e.message; });
}
// ---------- メインループ
let last = performance.now();
function frame(now) {
  const real = Math.min(0.1, (now - last) / 1000); last = now;
  if (playing && demo) {
    playT += real * speed;
    if (playT > demo.duration) { if (loop) playT = 0; else { playT = demo.duration; playing = false; syncPlay(); } }
  }
  if (demo) { try { simTo(playT); render(); } catch (err) { g.setTransform(1, 0, 0, 1, 0, 0); g.fillStyle = '#300'; g.fillRect(0, H - 40, W, 40); g.fillStyle = '#fff'; g.font = '14px system-ui'; g.fillText('描画エラー：' + err.message, 12, H - 15); console.error(err); } $('#scrub').value = playT; $('#time').textContent = `${playT.toFixed(2)} / ${demo.duration.toFixed(2)} s`; }
  requestAnimationFrame(frame);
}
function syncPlay() { $('#play').textContent = playing ? '停止' : '再生'; }
function boot() {
  buildList(); buildLedger();
  $('#cat').onchange = () => { refreshDemoSelect(); selectDemo($('#demo').value); };
  $('#idfilter').oninput = () => { if ($('#idfilter').value.trim()) $('#cat').value = ''; refreshDemoSelect(); if ($('#demo').value) selectDemo($('#demo').value); };
  $('#demo').onchange = () => selectDemo($('#demo').value);
  $('#play').onclick = () => { playing = !playing; if (playing && playT >= demo.duration) playT = 0; syncPlay(); };
  $('#reset').onclick = () => { playT = 0; resetSim(); };
  $('#loop').onchange = (e) => loop = e.target.checked;
  $('#scrub').oninput = (e) => { playT = +e.target.value; playing = false; syncPlay(); };
  $('#prev').onclick = () => { playT = Math.max(0, Math.round(playT / DT) * DT - DT); playing = false; syncPlay(); };
  $('#next').onclick = () => { playT = Math.min(demo.duration, Math.round(playT / DT) * DT + DT); playing = false; syncPlay(); };
  document.querySelectorAll('input[name=speed]').forEach(r => r.onchange = () => speed = +r.value);
  document.querySelectorAll('input[name=mode]').forEach(r => r.onchange = () => { mode = r.value; resetSim(); }); // 試作と現行で動きが違うデモがあるため作り直す
  document.querySelectorAll('input[name=bg]').forEach(r => r.onchange = () => bgMode = r.value);
  $('#scale1').onchange = (e) => document.body.classList.toggle('fit', !e.target.checked);
  $('#save').onclick = saveJSON;
  $('#load').onchange = (e) => e.target.files[0] && loadJSON(e.target.files[0]);
  selectDemo(DEMOS[0].id); syncPlay();
  requestAnimationFrame(frame);
}
function loadImages() {
  const keys = Object.keys(DATA.images);
  return Promise.all(keys.map(k => new Promise(res => { const im = new Image(); im.onload = () => { IMG[k] = im; res(); }; im.onerror = () => res(); im.src = DATA.images[k]; })));
}
