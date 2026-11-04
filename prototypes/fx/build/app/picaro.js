// ===== りゅう：ピカロの見た目と生成（試作）=====
// 仕様：docs/game/bosses/draco.md 8.2。既存の敵の絵を流用し、全種類に共通するフィルターとオーラで統一する。
// フィルターは絵の画素ごとに塗り直す（本番では共通 shader）。3案をつまみで切り替える。
const PC_VIOLET = ['#0d0820', '#1d1446', '#352a7c', '#5e52b8', '#9a8cf0', '#e6e0ff'].map(parseCol);
const PC_BASE = {};
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
    if (style === 0) { // 陰影を紫の段に置き換え、中を星がゆっくり流れてまたたく。縁は光る
      let c = PC_VIOLET[Math.min(4, Math.floor(lum * 4.2))]; const sx = Math.floor(i + t * 5 + seed * 7), sy = Math.floor(j - t * 2.5), hs = hash(sx * 7.13 + sy * 13.7 + seed);
      if (hs > 0.975) { const tw = 0.5 + 0.5 * Math.sin(t * 7 + hs * 60); c = tw > 0.55 ? PC_VIOLET[5] : PC_VIOLET[4]; }
      if (rim) c = pulse > 0.5 ? PC_VIOLET[5] : PC_VIOLET[4]; set(k, c, 255);
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
    const q = toL(add(add(from, mul(dir, ph * 26)), V(0, -ph * 18))), f = (1 - ph) * k; if (f < 0.05) continue; if (f > 0.55) R.front.px(q.x, q.y, pal[ph < 0.2 ? 4 : 3]); else R.front.dot(q.x, q.y, pal[2], f * 1.3); R.front.light(q.x, q.y, pal[2], 0.25 * f * R.P.intensity); }
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

// ---------- 生成：星が集まって塊になり、半透明の膜がうねる → 帯状に裂けてらせんにほどけ、中から敵が現れる（仕様 8.2）
const PC_SPAWN = { gather: 0.55, membrane: 1.25, deform: 1.55, tear: 1.95, fade: 2.8 };
function pcSpawnFx(S, R, e, t0, style) {
  const t = S.t - t0, pal = FX.ramp(R.P.color), c = toL(e.pos), Rr = e.r * WL * 1.35 * R.P.size, T = PC_SPAWN, seed = e.seed || 0; if (t < 0) return;
  // 星が渦を巻いて集まる
  if (t < T.membrane) for (let m = 0; m < 34; m++) { const st = hash(m * 3.1 + seed) * 0.25, a = clamp((t - st) / (T.gather - st)), an = hash(m * 7.7 + seed) * TAU + a * 3.2, rad = (Rr * 3.2 + 30 * hash(m * 1.9)) * (1 - a) ** 1.3 + Rr * 0.3 * a; if (t < st) continue;
    const q = V(c.x + Math.cos(an) * rad, c.y + Math.sin(an) * rad), f = a < 1 ? 1 : clamp(1 - (t - T.gather) / 0.4); if (f <= 0) continue; dStar(R, q, 1 + 1.2 * (1 - a), t * 6 + m, f, pal); }
  // 膜：うねる半透明の球。表面に渦模様、明るい縁、まわりを細い帯が回る
  if (t >= T.gather - 0.1 && t < T.tear) {
    const grow = smooth(T.gather - 0.1, T.gather + 0.25, t), def = smooth(T.membrane, T.deform, t), sq = 1 + 0.18 * Math.sin((t - T.membrane) * 18) * def * (1 - smooth(T.deform, T.tear, t)), op = 1 - smooth(T.deform + 0.05, T.tear, t);
    const radius = (th) => Rr * grow * (1 + 0.1 * Math.sin(3 * th + t * 6) + 0.07 * Math.sin(5 * th - t * 9) + 0.05 * Math.sin(2 * th + t * 3.3)) * (1 + 0.06 * Math.sin(t * 7));
    for (let y = -Rr * 1.4; y <= Rr * 1.4; y += 1) for (let x = -Rr * 1.4; x <= Rr * 1.4; x += 1) { const xx = x / sq, yy = y * sq, th = Math.atan2(yy, xx), rr = Math.hypot(xx, yy), lim = radius(th); if (rr > lim) continue;
      const e2 = rr / Math.max(1, lim), swirl = 0.5 + 0.5 * Math.sin(th * 3 + rr * 0.45 - t * 7), px2 = c.x + x, py = c.y + y;
      // 縁は光の強い所だけ明るく、ほかは薄く（輪郭線で囲まない）。中は渦模様が透けて流れる
      const rimK = smooth(0.78, 1, e2) * (0.35 + 0.65 * (0.5 + 0.5 * Math.sin(th * 2 - t * 5)));
      if (rimK > 0.55) { R.front.px(px2, py, pal[rimK > 0.8 ? 4 : 3]); R.front.light(px2, py, pal[2], 0.25 * op * R.P.intensity); }
      else if (rimK > 0.2) R.front.dot(px2, py, pal[3], rimK * op);
      else if (swirl > 0.45) R.front.dot(px2, py, pal[swirl > 0.8 ? 3 : 2], (0.15 + 0.4 * (swirl - 0.45)) * op * (0.6 + 0.4 * e2)); }
    for (let rb = 0; rb < 2; rb++) { const tilt = rb ? 0.9 : -0.5, len0 = 1.7, rot = t * (rb ? 5.5 : -4.2); // 帯は全周を描かず、先が細る弧
      for (let u = 0; u < len0; u += 0.04) { const an = rot + u, ex = Math.cos(an) * Rr * 1.4, ey = Math.sin(an) * Rr * 0.8, q = V(c.x + ex * Math.cos(tilt) - ey * Math.sin(tilt), c.y + ex * Math.sin(tilt) + ey * Math.cos(tilt)), f = Math.sin(Math.PI * u / len0) * grow * op; if (f > 0.4) R.front.px(q.x, q.y, pal[f > 0.8 ? 4 : 3]); else R.front.dot(q.x, q.y, pal[2], f); } }
  }
  // 裂けて、帯がらせんにほどけながら外へ飛ぶ
  if (t >= T.deform + 0.15 && t < T.fade) { const a = (t - T.deform - 0.15) / (T.fade - T.deform - 0.15);
    // 帯は5本の太い腕。途切れずにねじれながら外へほどけ、終わり際だけ虫食いで消える
    for (let s2 = 0; s2 < 5; s2++) { const base = s2 * TAU / 5 + seed + hash(s2 * 2.9) * 0.8, len0 = 0.7 + 0.4 * hash(s2 * 4.4), sp2 = 0.7 + 0.9 * hash(s2 * 6.1);
      for (let u = 0; u < len0; u += 0.012) { const an = base + u * 0.8 + a * (1.4 + 1.2 * hash(s2)) * (1 + u * 0.4), rad = Rr * (0.8 + u * 1.6 * (0.35 + a) + a * 1.5 * sp2), f = (1 - a) * Math.sin(Math.PI * u / len0) ** 0.6; if (f < 0.06) continue;
        if (a > 0.55 && hash(s2 * 9 + Math.floor(u * 60) + Math.floor(t * 20)) > (1 - a) * 2.2) continue;
        const q = V(c.x + Math.cos(an) * rad, c.y + Math.sin(an) * rad), w = 0.5 + 1.5 * f, nx = Math.cos(an), ny = Math.sin(an);
        for (let o = -w; o <= w; o += 0.5) { const e3 = Math.abs(o) / w; if (e3 < 0.5 && f > 0.5) R.front.px(q.x + nx * o, q.y + ny * o, pal[f > 0.8 ? 4 : 3]); else R.front.dot(q.x + nx * o, q.y + ny * o, pal[2], f * (1 - e3 * 0.6)); } } }
    for (let m = 0; m < 20; m++) { const an = hash(m * 4.1 + seed) * TAU + a * (hash(m * 2.2) - 0.5) * 3, d = Rr * (0.3 + hash(m * 8.8) * 0.6 + a * (0.6 + 2.6 * hash(m))), q = V(c.x + Math.cos(an) * d, c.y + Math.sin(an) * d - a * 10); dStar(R, q, 1.2, t * 5 + m, (1 - a) * 0.9, pal); }
    if (t < T.tear + 0.08) R.front.glow(c.x, c.y, Rr * 1.4, pal[4], 0.6 * (1 - (t - T.deform - 0.15) / 0.4) * R.P.intensity); }
}
DEMOS.push({ id: 'D-picaro_spawn', ids: ['D04', 'GFX-008'], cat: 'りゅう座（D）', group: 'りゅう座', title: 'ピカロの生成', duration: 5.2, color: '#ab9cff',
  params: [{ k: 'style', label: '現れる姿の案（0 星空の窓／1 星座／2 光の霊）', type: 'select', options: [{ value: 0, label: '星空の窓' }, { value: 1, label: '星座' }, { value: 2, label: '光の霊' }], def: 0 }],
  status: { '状態': '試作（未承認）', '作り': '星が渦を巻いて集まり塊になる → 半透明の膜がスライムのようにうねり、表面に渦模様と明るい縁、まわりを細い帯が回る → 塊がゆがんだあと、膜が帯状に裂けてらせんにほどけながら外へ飛ぶ → 中から白く光った敵が現れ、ピカロの姿へ落ち着く。星と粒が残って消える（仕様 8.2）', '現行': '現行表示は敵がそのまま出る' },
  refs: ['docs/game/bosses/draco.md 8.2'],
  setup(S) { cam.zoom = 1.6; S.ents = ['biter', 'telescope', 'lynx'].map((type, i) => { const e = mkE(type, V(-260 + i * 260, 0), Math.PI); e.seed = i * 5.3; e.t0 = 0.3 + i * 0.6; return e; }); S.ship = shipState(V(0, 380), -Math.PI / 2, 0); },
  step() {},
  draw(S, R) { const st = +(R.P.style ?? 0);
    if (R.proto) for (const e of S.ents) { pcSpawnFx(S, R, e, e.t0, st); if (S.t - e.t0 > PC_SPAWN.tear) pcAura(R, e, S.t, smooth(PC_SPAWN.tear, PC_SPAWN.tear + 0.6, S.t - e.t0)); }
    R.blitBack();
    for (const e of S.ents) { const t = S.t - e.t0; if (!R.proto) { if (t > 0) drawEnemy(e); continue; } if (t > PC_SPAWN.deform + 0.2) { const k = smooth(PC_SPAWN.deform + 0.2, PC_SPAWN.tear + 0.1, t); pcDraw(e, st, S.t, k, 1 - smooth(PC_SPAWN.tear, PC_SPAWN.tear + 0.5, t)); } }
    drawShip(S.ship); },
  phase(S) { return '' } });
