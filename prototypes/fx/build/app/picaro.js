// ===== りゅう：ピカロの見た目と生成（試作）=====
// 仕様：docs/game/bosses/draco.md 8.2。既存の敵の絵を流用し、全種類に共通するフィルターとオーラで統一する。
// フィルターは絵の画素ごとに塗り直す（本番では共通 shader）。3案をつまみで切り替える。
const PC_VIOLET = ['#0d0820', '#1d1446', '#352a7c', '#5e52b8', '#9a8cf0', '#e6e0ff'].map(parseCol);
const PC_BASE = {};
const PC_NEB = ['#ff6fd8', '#4fb8ff', '#8ff0ff'].map(parseCol), PC_STAR = ['#ffffff', '#9ff4ff', '#ffb0f0'].map(parseCol);
const mixC = (a, b, k) => ({ r: a.r + (b.r - a.r) * k, g: a.g + (b.g - a.g) * k, b: a.b + (b.b - a.b) * k });
function pcNoise(x, y) { const xi = Math.floor(x), yi = Math.floor(y), fx = x - xi, fy = y - yi, sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy), h = (a, b) => hash(a * 57.3 + b * 131.7);
  return lerp(lerp(h(xi, yi), h(xi + 1, yi), sx), lerp(h(xi, yi + 1), h(xi + 1, yi + 1), sx), sy); }
function pcBase(type) { // 絵の画素と縁の画素（種類ごとに一度だけ作る）
  if (PC_BASE[type]) return PC_BASE[type]; const im = IMG['enemy/' + type]; if (!im) return null;
  const c = document.createElement('canvas'); c.width = im.width; c.height = im.height; const x = c.getContext('2d'); x.drawImage(im, 0, 0);
  const d = x.getImageData(0, 0, im.width, im.height), w = im.width, h = im.height, a = (i, j) => (i < 0 || j < 0 || i >= w || j >= h) ? 0 : d.data[(j * w + i) * 4 + 3];
  const edge = []; for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (a(i, j) > 100 && (a(i - 1, j) < 100 || a(i + 1, j) < 100 || a(i, j - 1) < 100 || a(i, j + 1) < 100)) edge.push([i, j]);
  const out = document.createElement('canvas'); out.width = w; out.height = h;
  return (PC_BASE[type] = { w, h, src: d, edge, out, ctx: out.getContext('2d'), img: out.getContext('2d').createImageData(w, h) });
}
// style 0：星空の窓／1：星座／2：光の霊
function pcFilter(type, style, t, seed = 0) {
  const b = pcBase(type); if (!b) return null; const { w, h, src, img } = b, s = src.data, o = img.data, a = (i, j) => (i < 0 || j < 0 || i >= w || j >= h) ? 0 : s[(j * w + i) * 4 + 3];
  const set = (k, c, al) => { o[k] = c.r * 255; o[k + 1] = c.g * 255; o[k + 2] = c.b * 255; o[k + 3] = al; };
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const k = (j * w + i) * 4; if (s[k + 3] < 100) { o[k + 3] = 0; continue; }
    const lum = (0.3 * s[k] + 0.59 * s[k + 1] + 0.11 * s[k + 2]) / 255, rim = a(i - 1, j) < 100 || a(i + 1, j) < 100 || a(i, j - 1) < 100 || a(i, j + 1) < 100, pulse = 0.5 + 0.5 * Math.sin(t * 4 + (i + j) * 0.25 + seed);
    if (style === 0) { // 星空の窓：陰影を紫の段にし、中を桃・青の星雲がゆっくり流れ、色つきの星がまたたく。縁は水色〜桃色に移ろって光る
      const base = PC_VIOLET[Math.min(4, Math.floor(lum * 4.2))], neb = pcNoise((i + t * 3 + seed * 9) * 0.11, (j - t * 1.5) * 0.11), neb2 = pcNoise((i - t * 2 + 40) * 0.07, (j + t + seed * 5) * 0.07);
      let c = mixC(base, neb2 > 0.5 ? PC_NEB[0] : PC_NEB[1], smooth(0.45, 0.85, neb) * 0.55 * (0.4 + lum)); const sx = Math.floor(i + t * 5 + seed * 7), sy = Math.floor(j - t * 2.5), hs = hash(sx * 7.13 + sy * 13.7 + seed);
      if (hs > 0.972) { const tw = 0.5 + 0.5 * Math.sin(t * 7 + hs * 60); c = tw > 0.55 ? PC_STAR[Math.floor(hs * 997) % 3] : PC_VIOLET[4]; }
      if (rim) { const hue = 0.5 + 0.5 * Math.sin(i * 0.25 + j * 0.18 + t * 2.2 + seed); c = mixC(PC_NEB[2], PC_NEB[0], hue); if (pulse > 0.7) c = mixC(c, PC_VIOLET[5], 0.6); } set(k, c, 255);
    } else if (style === 1) { // 元の色を暗く紫寄りに。体のあちこちの星がまたたく
      const r0 = s[k] / 255, g0 = s[k + 1] / 255, b0 = s[k + 2] / 255, m = 0.42; let c = { r: r0 * m * 0.6 + 0.16 * 0.4, g: g0 * m * 0.6 + 0.11 * 0.4, b: b0 * m * 0.6 + 0.42 * 0.4 };
      const hs = hash(i * 3.17 + j * 11.3 + seed * 5), star = hs > 0.988, near = !star && (hash((i - 1) * 3.17 + j * 11.3 + seed * 5) > 0.988 || hash((i + 1) * 3.17 + j * 11.3 + seed * 5) > 0.988 || hash(i * 3.17 + (j - 1) * 11.3 + seed * 5) > 0.988 || hash(i * 3.17 + (j + 1) * 11.3 + seed * 5) > 0.988);
      const tw = 0.5 + 0.5 * Math.sin(t * 5 + hs * 80); if (star) c = tw > 0.3 ? PC_VIOLET[5] : PC_VIOLET[4]; else if (near && tw > 0.6) c = PC_VIOLET[3];
      if (rim) c = PC_VIOLET[pulse > 0.6 ? 4 : 3]; set(k, c, 255);
    } else { // 半透明の紫に、斜めの光の帯が流れる。縁は光る
      const band = 0.5 + 0.5 * Math.sin((i + j) * 0.3 - t * 5 + seed), c = rim ? PC_VIOLET[pulse > 0.4 ? 5 : 4] : PC_VIOLET[2 + Math.floor(band * 2.2 + lum)]; set(k, c, rim ? 255 : 150);
    }
  }
  b.ctx.putImageData(img, 0, 0); return b.out;
}
function pcDraw(e, style, t, alpha = 1, white = 0) { // drawEnemy と同じ向き・大きさで、塗り直した絵を描く
  const d = enemyDef(e.type), cv2 = pcFilter(e.type, style, t, e.seed || 0); if (!cv2 || !d.look) return;
  const ang = d.look.fixed_angle ? d.look.angle : d.look.angle + e.facing, half = spriteR(e.type, e.r), sc = 2 * half / Math.max(cv2.width, cv2.height);
  g.save(); g.translate(e.pos.x, e.pos.y); g.rotate(ang); g.globalAlpha = alpha; g.imageSmoothingEnabled = false; g.drawImage(cv2, -cv2.width * sc / 2, -cv2.height * sc / 2, cv2.width * sc, cv2.height * sc);
  if (white > 0) { g.globalCompositeOperation = 'lighter'; g.globalAlpha = white; g.filter = 'brightness(0) invert(1)'; g.drawImage(cv2, -cv2.width * sc / 2, -cv2.height * sc / 2, cv2.width * sc, cv2.height * sc); g.filter = 'none'; }
  g.restore();
}
function pcEdgeWorld(e, idx) { // 縁の画素をワールドへ
  const d = enemyDef(e.type), b = pcBase(e.type); if (!b || !b.edge.length) return e.pos; const [i, j] = b.edge[idx % b.edge.length], ang = d.look.fixed_angle ? d.look.angle : d.look.angle + e.facing, half = spriteR(e.type, e.r), sc = 2 * half / Math.max(b.w, b.h);
  return add(e.pos, rotateV(V((i - b.w / 2 + 0.5) * sc, (j - b.h / 2 + 0.5) * sc), ang));
}
function pcAura(R, e, t, k = 1) { // 縁から星屑がはがれて漂い、薄れて消える。体のまわりはほのかに光る
  const pal = FX.ramp(R.P.color), c = toL(e.pos), b = pcBase(e.type); if (!b) return;
  R.back.glow(c.x, c.y, e.r * WL * 1.6, pal[1], 0.22 * k * R.P.intensity);
  for (let m = 0; m < 16; m++) { const life = 0.9 + 0.8 * hash(m * 3.3 + (e.seed || 0)), ph = ((t + hash(m * 7.1 + (e.seed || 0)) * life) % life) / life, from = pcEdgeWorld(e, Math.floor(hash(m * 5.7 + (e.seed || 0) + Math.floor((t + hash(m * 7.1) * life) / life) * 0.37) * b.edge.length)), dir = norm(sub(from, e.pos));
    const q = toL(add(add(from, mul(dir, ph * 26)), V(0, -ph * 18))), f = (1 - ph) * k; if (f < 0.05) continue; const sc = [hexc('#ffb0f0'), hexc('#9ff4ff'), pal[4]][m % 3]; if (f > 0.55) R.front.px(q.x, q.y, ph < 0.3 ? sc : pal[3]); else R.front.dot(q.x, q.y, m % 3 === 0 ? hexc('#c46bd8') : pal[2], f * 1.3); R.front.light(q.x, q.y, pal[2], 0.25 * f * R.P.intensity); }
}

// ---------- 見た目の比較：いろいろな敵をピカロにして並べる
const PC_TYPES = ['biter', 'hound', 'splitter', 'telescope', 'lynx', 'crab', 'dolphin', 'aquila'];
DEMOS.push({ id: 'D-picaro_look', ids: ['D04', 'GFX-008'], cat: 'りゅう座（D）', group: 'りゅう座', title: 'ピカロの見た目（3案）', duration: 8, color: '#ab9cff',
  params: [{ k: 'style', label: '案（0 星空の窓／1 星座／2 光の霊）', type: 'select', options: [{ value: 0, label: '星空の窓' }, { value: 1, label: '星座' }, { value: 2, label: '光の霊' }], def: 0 }, { k: 'aura', label: 'オーラの強さ', type: 'range', min: 0, max: 2, step: 0.05, def: 1 }],
  status: { '状態': '試作（未承認）。配色・オーラ・フィルターは仕様で未決', '作り': '元の敵の絵の画素ごとに共通のフィルターで塗り直す。星空の窓：陰影を紫の段に置き換え、中を星が流れてまたたき縁が光る／星座：元の色を暗く紫寄りにして星が光る／光の霊：半透明の紫に光の帯が流れる。どれも縁から星屑が漂い、体のまわりがほのかに光る', '現行': '現行表示は元の敵の絵のまま' },
  refs: ['docs/game/bosses/draco.md 8.2', 'docs/game/graphics-improvements.md GFX-008'],
  setup(S) { cam.zoom = 1.7; S.ents = PC_TYPES.map((type, i) => { const e = mkE(type, V(-330 + (i % 4) * 220, i < 4 ? -110 : 120), Math.PI); e.seed = i * 3.7; e.base = { ...e.pos }; return e; }); S.ship = shipState(V(0, 260), -Math.PI / 2, 0); },
  step(S, dt) { for (const e of S.ents) e.pos = add(e.base, V(Math.sin(S.t * 1.3 + e.seed) * 8, Math.cos(S.t * 1.7 + e.seed) * 6)); },
  draw(S, R) { const st = +(R.P.style ?? 0); if (R.proto) for (const e of S.ents) pcAura(R, e, S.t, R.P.aura ?? 1); R.blitBack(); for (const e of S.ents) { if (R.proto) pcDraw(e, st, S.t); else drawEnemy(e); } drawShip(S.ship); },
  phase() { return '' } });

// ---------- 生成：紫の塊がもにょもにょうねりながら、だんだん敵の形に変わる
// 塊の形（うねる円と回るこぶ）と敵の絵の形の距離場を、時間でなめらかに移す。色は紫の塊からピカロの姿へ移る
const PC_SDF = {};
function pcSdf(type) {
  if (PC_SDF[type]) return PC_SDF[type]; const b = pcBase(type); if (!b) return null; const pad = Math.ceil(Math.max(b.w, b.h) * 0.4), W2 = b.w + pad * 2, H2 = b.h + pad * 2, s = b.src.data, inside = (i, j) => i >= 0 && j >= 0 && i < b.w && j < b.h && s[(j * b.w + i) * 4 + 3] > 100;
  const d = new Float32Array(W2 * H2); let area = 0; for (let j = 0; j < b.h; j++) for (let i = 0; i < b.w; i++) if (inside(i, j)) area++;
  for (let y = 0; y < H2; y++) for (let x = 0; x < W2; x++) { const i = x - pad, j = y - pad, inn = inside(i, j); let best = 1e9; for (const [ei, ej] of b.edge) { const dd = (ei - i) ** 2 + (ej - j) ** 2; if (dd < best) best = dd; } d[y * W2 + x] = (inn ? -1 : 1) * Math.sqrt(best); }
  const c = document.createElement('canvas'); c.width = W2; c.height = H2;
  return (PC_SDF[type] = { pad, W2, H2, d, R0: Math.sqrt(area / Math.PI), canvas: c, ctx: c.getContext('2d'), img: c.getContext('2d').createImageData(W2, H2) });
}
const PC_BLOB = ['#2a0c4e', '#4a1a86', '#7a2fc4', '#b25cff', '#e3b8ff', '#ffffff'].map(parseCol);
function pcMorph(e, t, k, style) { // k：0＝塊 → 1＝敵の形
  const f = pcSdf(e.type), b = pcBase(e.type); if (!f) return null; const pic = pcFilter(e.type, style, t, e.seed || 0), pd = pic.getContext('2d').getImageData(0, 0, b.w, b.h).data, o = f.img.data, cx = f.W2 / 2, cy = f.H2 / 2, R0 = f.R0;
  const kk = smooth(0, 1, k), wobK = 1 - smooth(0.55, 1, k), lobes = [0, 1, 2].map(n => { const an = t * (2.2 + n * 0.7) + n * 2.1; return [cx + Math.cos(an) * R0 * 0.55, cy + Math.sin(an * 1.3) * R0 * 0.45, R0 * (0.42 + 0.1 * Math.sin(t * 5 + n))]; });
  const sqx = 1 + 0.12 * Math.sin(t * 9) * wobK, sqy = 1 - 0.12 * Math.sin(t * 9) * wobK;
  for (let y = 0; y < f.H2; y++) for (let x = 0; x < f.W2; x++) { const q = (y * f.W2 + x) * 4, X = (x - cx) / sqx, Y = (y - cy) / sqy, th = Math.atan2(Y, X), rho = Math.hypot(X, Y);
    let db = rho - R0 * (1 + 0.15 * Math.sin(3 * th + t * 7) + 0.1 * Math.sin(5 * th - t * 11) + 0.06 * Math.sin(2 * th + t * 4));
    for (const [lx, ly, lr] of lobes) { const dl = Math.hypot(x - lx, y - ly) - lr, h = clamp(0.5 + 0.5 * (dl - db) / 6); db = lerp(dl, db, h) - 6 * h * (1 - h); } // こぶをなめらかにつなぐ
    const de = f.d[y * f.W2 + x], dd = lerp(db, de, kk) + Math.sin(x * 0.4 + t * 8) * Math.cos(y * 0.35 - t * 7) * 1.6 * wobK;
    if (dd > 0) { o[q + 3] = 0; continue; }
    const depth = clamp(-dd / (R0 * 0.55)), swirl = 0.5 + 0.5 * Math.sin(th * 3 + rho * 0.35 - t * 6), lv = depth < 0.12 ? 4 : depth < 0.3 ? 3 : swirl > 0.75 ? 3 : depth < 0.6 ? 2 : 1; let c = PC_BLOB[lv];
    if (depth < 0.08 && swirl > 0.6) c = PC_BLOB[5];
    const i = x - f.pad, j = y - f.pad, pk = (j * b.w + i) * 4, show = smooth(0.62, 1, k); if (show > 0 && i >= 0 && j >= 0 && i < b.w && j < b.h && pd[pk + 3] > 0) c = mixC(c, { r: pd[pk] / 255, g: pd[pk + 1] / 255, b: pd[pk + 2] / 255 }, show);
    o[q] = c.r * 255; o[q + 1] = c.g * 255; o[q + 2] = c.b * 255; o[q + 3] = 255; }
  f.ctx.putImageData(f.img, 0, 0); return f;
}
function pcDrawMorph(e, f, alpha = 1, white = 0) { const d = enemyDef(e.type), b = pcBase(e.type), ang = d.look.fixed_angle ? d.look.angle : d.look.angle + e.facing, sc = 2 * spriteR(e.type, e.r) / Math.max(b.w, b.h);
  g.save(); g.translate(e.pos.x, e.pos.y); g.rotate(ang); g.globalAlpha = alpha; g.imageSmoothingEnabled = false; g.drawImage(f.canvas, -f.W2 * sc / 2, -f.H2 * sc / 2, f.W2 * sc, f.H2 * sc);
  if (white > 0) { g.globalCompositeOperation = 'lighter'; g.globalAlpha = white; g.filter = 'brightness(0) invert(1)'; g.drawImage(f.canvas, -f.W2 * sc / 2, -f.H2 * sc / 2, f.W2 * sc, f.H2 * sc); g.filter = 'none'; } g.restore(); }
const PC_SPAWN = { grow: 0.35, blob: 1.3, morph: 2.3, settle: 2.7 };
function pcSpawnFx(S, R, e, t) { // まわりの粒：塊のしずくが飛び、ふくらむ紫の煙、形が決まる瞬間にきらめき
  if (t < 0) return; const c = toL(e.pos), Rr = e.r * WL * 1.3, P2 = PC_SPAWN, purple = [hexc('#4a1a86'), hexc('#7a2fc4'), hexc('#b25cff'), hexc('#e3b8ff')];
  for (let m = 0; m < 10; m++) { const born = 0.2 + hash(m * 3.3 + (e.seed || 0)) * (P2.morph - 0.4), a = t - born, life = 0.5; if (a < 0 || a > life) continue; const an = hash(m * 7.1) * TAU, d = Rr * (0.9 + a * 2.4), q = V(c.x + Math.cos(an) * d, c.y + Math.sin(an) * d + a * a * 20), k = a / life; R.front.px(q.x, q.y, purple[k < 0.4 ? 3 : 2]); if (k < 0.5) R.front.px(q.x + 1, q.y, purple[2]); }
  if (t < P2.blob) for (let m = 0; m < 18; m++) { const ph = (t * 0.8 + hash(m * 2.7)) % 1, an = hash(m * 5.3) * TAU + t, d = Rr * (0.7 + ph * 1.2), q = V(c.x + Math.cos(an) * d, c.y + Math.sin(an) * d - ph * 6); R.back.dot(q.x, q.y, purple[0], (1 - ph) * 0.6 * smooth(0, P2.grow, t)); }
  const pop = t - P2.morph; if (pop > 0 && pop < 0.6) { const pal = FX.ramp(R.P.color); for (let m = 0; m < 12; m++) { const an = hash(m * 4.1 + 9) * TAU, d = Rr * (0.8 + pop * 2.5 * (0.5 + hash(m))), q = V(c.x + Math.cos(an) * d, c.y + Math.sin(an) * d); dStar(R, q, 1.5, t * 6 + m, 1 - pop / 0.6, pal); } if (pop < 0.1) R.front.glow(c.x, c.y, Rr * 1.3, purple[3], (1 - pop / 0.1) * 0.6 * R.P.intensity); }
}
DEMOS.push({ id: 'D-picaro_spawn', ids: ['D04', 'GFX-008'], cat: 'りゅう座（D）', group: 'りゅう座', title: 'ピカロの生成', duration: 4.6, color: '#ab9cff', params: [],
  status: { '状態': '試作（未承認）', '作り': '紫の塊がふくらんで現れ、こぶを回しながらもにょもにょうねる（押しつぶし・伸び）→ 塊の形がだんだん敵の形へ移り、色もピカロの姿（星空の窓）へ移る → 形が決まる瞬間に白く光り、星がはじけて落ち着く。まわりにしずくと紫の煙', '現行': '現行表示は敵がそのまま出る' },
  refs: ['docs/game/bosses/draco.md 8.2'],
  setup(S) { cam.zoom = 1.8; S.ents = ['biter', 'telescope', 'lynx'].map((type, i) => { const e = mkE(type, V(-240 + i * 240, 0), Math.PI); e.seed = i * 5.3; e.t0 = 0.2 + i * 0.35; return e; }); S.ship = shipState(V(0, 260), -Math.PI / 2, 0); },
  step() {},
  draw(S, R) {
    if (R.proto) for (const e of S.ents) { const t = S.t - e.t0; pcSpawnFx(S, R, e, t); if (t > PC_SPAWN.morph) pcAura(R, e, S.t, smooth(PC_SPAWN.morph, PC_SPAWN.settle, t)); }
    R.blitBack();
    for (const e of S.ents) { const t = S.t - e.t0; if (!R.proto) { if (t > 0) drawEnemy(e); continue; } if (t < 0) continue;
      if (t < PC_SPAWN.settle) { const grow = smooth(0, PC_SPAWN.grow, t), k = smooth(PC_SPAWN.blob, PC_SPAWN.morph, t), f = pcMorph(e, S.t, k, 0); const save = e.r; e.r = save * (0.3 + 0.7 * grow); pcDrawMorph(e, f, 1, Math.max(0, 1 - Math.abs(t - PC_SPAWN.morph) / 0.12) * 0.45); e.r = save; }
      else pcDraw(e, 0, S.t); }
    drawShip(S.ship); },
  phase() { return '' } });
