// ===== ボス試作共通：現行パーツを組み立て、見た目だけを重ねる =====
const BOSSES = DATA.bosses;
const rotateV = (v, a) => V(v.x * Math.cos(a) - v.y * Math.sin(a), v.x * Math.sin(a) + v.y * Math.cos(a));
function bossRule(name, id, phase = 1) {
  const src = BOSSES[name].moves[id], out = { ...src };
  if (phase >= 2) for (const k in src) if (k.endsWith('_p2')) out[k.slice(0, -3)] = src[k];
  return out;
}
function bossActor(name, pos, facing = 0) {
  return { name, pos: { ...pos }, facing, r: BOSSES[name].def.radius * CS, charge: 0, mode: 'windup', vel: V(0, 0), gait: 0, pose: {}, phase: 1 };
}
function drawBossParts(B, edits = {}, opts = {}) {
  const nodes = BOSSES[B.name].nodes, transforms = {}, sprites = [], root = M.mul(M.mk(B.facing, 1, 1, B.pos.x, B.pos.y), opts.root || M.mk(-Math.PI / 2, CS, CS, 0, 0));
  for (let i = 1; i < nodes.length; i++) {
    const n = nodes[i], path = n.parent === '.' ? n.name : n.parent + '/' + n.name, e = edits[path] || {}, pos = e.position || n.position || V(0, 0), scale = e.scale || n.scale || V(1, 1);
    const parent = n.parent === '.' ? root : transforms[n.parent]; if (!parent) continue;
    transforms[path] = M.mul(parent, M.mk(e.rotation ?? n.rotation ?? 0, scale.x, scale.y, pos.x, pos.y));
    if (!n.texture || n.visible === false || e.visible === false) continue;
    let tex = e.texture || n.texture; if (tex.frames) tex = tex.frames[e.frame ?? 0]; if (!tex) continue;
    sprites.push({ n, e, tex, m: transforms[path], z: (n.z_index || 0) + (edits[n.parent]?.z_index || 0), i });
  }
  sprites.sort((a, b) => a.z - b.z || a.i - b.i);
  const ctx = opts.ctx || g;
  for (const { n, e, tex, m } of sprites) {
    const im = IMG[tex.key]; if (!im) continue;
    const r = tex.region || { x: 0, y: 0, w: im.width, h: im.height }, off = n.offset || V(0, 0), centered = n.centered !== false;
    ctx.save(); ctx.transform(...m); ctx.globalAlpha *= opts.alpha ?? 1;
    if (n.flip_h) ctx.scale(-1, 1); if (n.flip_v) ctx.scale(1, -1);
    const x = off.x - (centered ? r.w / 2 : 0), y = off.y - (centered ? r.h / 2 : 0);
    ctx.imageSmoothingEnabled = false; ctx.drawImage(im, r.x, r.y, r.w, r.h, x, y, r.w, r.h);
    if ((e.white || opts.white || 0) > 0) { ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha *= e.white || opts.white; ctx.filter = 'brightness(0) invert(1)'; ctx.drawImage(im, r.x, r.y, r.w, r.h, x, y, r.w, r.h); }
    ctx.restore();
  }
  return transforms;
}
// pixelFX flamethrower.js の噴流・ノイズ、SPEED pixel_fire の密度場を下敷きにする。
// 各サンプルは現行の炎粒の位置と半径。丸を描かず密度を足して面にし、縁を崩す。
function bossFire(p, samples, time, color, intensity = 1, size = 1) {
  if (!samples.length || intensity <= 0) return;
  const pts = samples.map(q => ({ ...q, pos: toL(q.pos), radius: Math.max(0.6, q.radius * WL * size) }));
  let x0 = LW, y0 = LH, x1 = 0, y1 = 0;
  for (const q of pts) { x0 = Math.min(x0, q.pos.x - q.radius * 1.8); y0 = Math.min(y0, q.pos.y - q.radius * 1.8); x1 = Math.max(x1, q.pos.x + q.radius * 1.8); y1 = Math.max(y1, q.pos.y + q.radius * 1.8); }
  x0 = Math.max(-2, Math.floor(x0)); y0 = Math.max(-2, Math.floor(y0)); x1 = Math.min(LW + 2, Math.ceil(x1)); y1 = Math.min(LH + 2, Math.ceil(y1));
  const w = x1 - x0, h = y1 - y0; if (w <= 0 || h <= 0) return;
  const field = new Float32Array(w * h * 3);
  for (const q of pts) { const age = q.age ?? 0.25, r = q.radius * (1.1 + 0.1 * Math.sin(time * 22 + (q.seed || 0))); phxSplat(field, w, h, x0, y0, q.pos.x, q.pos.y, r * 1.5, 0); phxSplat(field, w, h, x0, y0, q.pos.x, q.pos.y, r, 1, 1 - age * 0.4); if (age < 0.65) phxSplat(field, w, h, x0, y0, q.pos.x, q.pos.y, r * 0.5, 2); }
  const pal = FX.ramp(color), read = (x, y, c) => field[(clamp(y, 0, h - 1) * w + clamp(x, 0, w - 1)) * 3 + c];
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const x = i + x0, y = j + y0, u = Math.round(Math.sin(y * 0.8 - time * 17) + Math.sin(x * 0.6 + time * 11)), v = Math.round(Math.cos(x * 0.7 - time * 9));
    if (read(i + u, j + v, 0) < 0.32) continue;
    const lv = read(i + u, j + v, 2) > 0.32 ? 4 : read(i + u, j + v, 1) > 0.32 ? 3 : 1;
    p.px(x, y, pal[lv]); if ((x & 3) === 0 && (y & 3) === 0) p.glow(x, y, 4, pal[2], 0.14 * intensity);
  }
}
function bossGather(R, at, radius, charge, t, seed = 1) {
  const a = toL(at), pal = FX.ramp(R.P.color), n = 28;
  for (let i = 0; i < n; i++) { const life = 0.4 + hash(i + seed) * 0.55, phase = (t / life + hash(i * 9 + seed)) % 1, angle = hash(i * 19 + seed) * TAU;
    const d = radius * WL * (1 - phase) ** 1.4, q = add(a, mul(fromA(angle), d));
    R.front.px(q.x, q.y, pal[phase > 0.6 ? 3 : 1]); R.front.light(q.x, q.y, pal[2], charge * phase * R.P.intensity * 0.5);
  }
  R.front.glow(a.x, a.y, radius * WL * 0.6, pal[2], charge * R.P.intensity * 0.32);
}
// 咆哮の空気：不揃いの小さな光のかたまりが口から外へ流れ、薄れて崩れる。
function bossBreath(R, mouth, direction, age, seed = 1, spread = 1.1, reach = 170) {
  const t = age / R.P.timing; if (t < 0 || t > 0.7) return;
  const A = toL(mouth), pal = FX.ramp(R.P.color), fade = 1 - t / 0.7;
  for (let i = 0; i < 42; i++) { const an = direction + (hash(seed + i * 7) - 0.5) * spread * 2, speed = (0.4 + hash(seed + i * 3)) * reach * WL * R.P.size, d = speed * Math.sqrt(t);
    const q = add(A, mul(fromA(an), d)); R.front.glow(q.x, q.y, 1.2 + 2 * fade, pal[2], fade * 0.16 * R.P.intensity);
    if (hash(i * 3 + seed) > t) R.front.px(q.x, q.y, pal[t < 0.1 ? 3 : 1]);
  }
}
function bossTrail(R, points, age = 0, color = R.P.color) {
  const pal = FX.ramp(color);
  for (let i = 0; i < points.length; i++) { const q = toL(points[i]), f = (i + 1) / points.length * clamp(1 - age / 0.3); R.back.glow(q.x, q.y, 3 * R.P.size, pal[2], f * 0.22 * R.P.intensity); if (i % 2 === 0 && f > 0.25) R.back.px(q.x, q.y, pal[f > 0.7 ? 3 : 1]); }
}
function bossPhase(B) { return ({ windup: '予備動作（予告）', active: '攻撃中', bay: '吠え立て・包囲', recovery: '終了・硬直', idle: '終了' })[B.mode] || B.mode; }
