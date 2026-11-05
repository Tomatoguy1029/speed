// ===== りゅう：試作の見た目（作り直し）=====
// 体の動き・技の時刻・軌道・範囲は draco.js の再生（現行の値）のまま。ここでは試作の表示だけを描き直す。
// 決まり：円・輪・扇・まっすぐな線の組み合わせや点線を使わず、光・粒・実際の絵・ノイズで描く。部位から出す。消え方は前から順・虫食い。
const D_SPACE = ['#07040f', '#140a26', '#2a1650', '#4b2c8a'].map(hexc);
function dRamp(R) { return FX.ramp(R.P.color); }
// 予兆：照準の光は白くしない。部位から部位へ光を運ぶ（dSupply）
function dTellDraw(S, R, pose) {
  const k = clamp(S.elapsed / Math.max(0.01, S.r.warn));
  if (!R.proto) { for (const path of S.tell) D2.polyline(path, rgba('#f8b05b', 0.42 + k * 0.4), 3); if (S.tech === 'tail_slam' && S.B.mode === 'windup' && S.target) D2.arc(S.target, S.r.radius, 0, TAU, '#f8b05b', 3); if (S.tech === 'star_fan' && S.B.mode === 'windup') for (const q of S.starPositions || []) D2.circle(q.pos, 8 + k * 4, '#ffca7a'); return; }
  if (S.tech === 'spiral') { dSpiralCountdown(S, R, pose); return; }
  S.tell.forEach((path, i) => { if (path.length > 2) { for (let m = 0; m < path.length; m += 4) dGroundTremble(S, R, path[m], 40, k, 500 + m); } else FX.warnRail(R.back, toL(path[0]), toL(path[1]), { color: R.P.color, k: 0.3 + 0.7 * k, time: S.t, seed: 300 + i, maxLv: 2, intensity: R.P.intensity }); });
  if (S.B.mode !== 'windup' || (S.staging && S.staging.phase !== 'ready')) return;
  const id = S.tech;
  if (id === 'rifts') for (let i = 0; i < 2; i++) { bossGather(R, pose.claws[i], 66, k, S.t, 191 + i); dSupply(R, pose.chest, pose.claws[i], k, S.t, 211 + i, i ? 32 : -32); }
  else if (['tail_sweep', 'tail_slam'].includes(id)) { const end = pose.points[pose.points.length - 1]; bossGather(R, end, 100, k, S.t, 193); dSupply(R, pathAt(pose.points, pathLength(pose.points) * 0.72).pos, end, k, S.t, 213); }
  else if (['charge', 'leap', 'spiral', 'clones'].includes(id)) bossGather(R, pose.chest, 100, k, S.t, 194);
  else { bossGather(R, pose.mouth, 85, k, S.t, 191); dSupply(R, pose.chest, pose.mouth, k, S.t, 215, 30); }
  if (id === 'tail_slam' && S.target) dGroundTremble(S, R, S.target, S.r.radius, k, 121);
  if (id === 'star_fan') (S.starPositions || []).forEach((q, i) => { dSupply(R, pose.mouth, q.pos, smooth(0.15, 0.8, k), S.t, 230 + i, (i - S.starPositions.length * 0.5) * 7); dStar(R, toL(q.pos), 1 + 2.5 * k, S.t * 3 + i, k, dRamp(R)); });
}
// 地面の予告：小石が震えて浮き、光が溜まる（円を描かない）
function dGroundTremble(S, R, at, radius, k, seed) {
  const c = toL(at), rr = radius * WL * R.P.size, pal = dRamp(R);
  for (let i = 0; i < 26; i++) { const a = hash(seed + i * 3.1) * TAU, d = rr * Math.sqrt(hash(seed + i * 7.7)), j = Math.sin(S.t * 50 + i) * k * 0.8; if (hash(seed + i * 2.3) > 0.3 + 0.7 * k) continue; R.back.px(c.x + Math.cos(a) * d + j, c.y + Math.sin(a) * d - k * 1.5 * hash(i), H_STONE[k > 0.6 ? 4 : 3]); }
  R.back.glow(c.x, c.y, rr * 0.5, pal[2], 0.3 * k * R.P.intensity);
}
// 星：白い芯と4本の光条。回りながらまたたく
function dStar(R, c, size, spin, a, pal) {
  if (a <= 0.02) return; R.front.px(c.x, c.y, pal[4]);
  for (let j = 0; j < 4; j++) { const an = spin + j * Math.PI / 2, L = size * (j % 2 ? 0.7 : 1); for (let d = 0.5; d <= L; d += 0.5) R.front.light(c.x + Math.cos(an) * d, c.y + Math.sin(an) * d, pal[d < L * 0.4 ? 4 : 3], a * (1 - d / (L + 0.5))); }
  R.front.glow(c.x, c.y, size * 1.4, pal[2], 0.35 * a * R.P.intensity);
}
// 星のブレス：口から扇の中を流れる光の筋の束。真ん中ほど白く、岩で止まった所は火花が散る
function dBreathFx(S, R) {
  if (!S.fan || S.B.mode !== 'active') return; const pal = dRamp(R), o = S.fan[0], n = S.fan.length - 1, t = S.elapsed;
  const on = smooth(0, 0.12, t) * (1 - smooth(S.r.active - 0.25, S.r.active, t));
  for (let i = 0; i < 170; i++) {
    const h = hash(i * 1.37), j = 1 + Math.floor(h * n), end = S.fan[j], reach = dist(o, end), dir = norm(sub(end, o)), c = 1 - Math.abs(j - n / 2) / (n / 2), v = 1400 + 700 * hash(i * 2.9), sl = 50 + 90 * hash(i * 3.3);
    const head = ((t * v + hash(i * 5.1) * reach) % (reach + sl)); if (head < 0) continue;
    for (let s = Math.max(0, head - sl); s <= Math.min(head, reach); s += 0.6 / WL) {
      const b = ((s - head + sl) / sl) * on * (0.4 + 0.6 * c) * (s > reach - 60 ? (reach - s) / 60 : 1); if (b < 0.05) continue;
      const q = toL(add(o, mul(dir, s))); if (b > 0.5) R.front.px(q.x, q.y, pal[c > 0.75 && b > 0.8 ? 4 : 3]); else R.front.dot(q.x, q.y, pal[2], b * 1.4);
    }
    if (reach < S.r.reach - 1 && hash(i * 9 + Math.floor(t * 20)) < 0.25) { const q = toL(end); for (let m = 0; m < 3; m++) { const a = angOf(dir) + Math.PI + (hash(i + m * 7 + Math.floor(t * 30)) - 0.5) * 2.2, d = 2 + 6 * hash(i * m + 3); R.front.px(q.x + Math.cos(a) * d, q.y + Math.sin(a) * d, pal[3]); } }
  }
  for (let i = 0; i < 18; i++) { const j = 1 + Math.floor(hash(i * 4.3) * n), dir = norm(sub(S.fan[j], o)), s = ((t * 900 + hash(i * 6.6) * 1500) % dist(o, S.fan[j])); dStar(R, toL(add(o, mul(dir, s))), 1.5, t * 6 + i, on * 0.8, pal); }
  const m = toL(o); R.front.glow(m.x, m.y, 7 * R.P.size, pal[3], 0.5 * on * R.P.intensity);
}
// 空間の裂け目：爪の通った所に、ぎざぎざの細い割れ目が走る。芯は光り、両脇は暗い宇宙がのぞく。終わりは両端から閉じる（輪郭で囲まない）
function dRiftFx(S, R) {
  const r = S.r, pal = dRamp(R), closeK = S.B.mode === 'active' ? smooth(r.active - 0.6, r.active, S.elapsed) : 1;
  for (const q of S.rifts || []) { if (!q) continue;
    const A = toL(q.a), B = toL(q.b), L = dist(A, B); if (L < 1) continue; const u = norm(sub(B, A)), sd = orth(u), open = smooth(0, 0.12, q.age);
    for (let d = 0; d <= L; d += 0.5) { const f = d / L; if (Math.abs(f - 0.5) * 2 > 1 - closeK) continue;
      const jag = (hash(q.seed * 13 + Math.floor(d / 3)) - 0.5) * 3 + Math.sin(d * 0.21 + q.seed) * 1.2, w = (0.6 + r.scratch_width * 0.25 * WL * R.P.size * Math.sin(Math.PI * f) ** 0.8) * open, cx = A.x + u.x * d + sd.x * jag, cy = A.y + u.y * d + sd.y * jag;
      R.front.px(cx, cy, pal[hash(d * 3 + Math.floor(S.t * 20) + q.seed) > 0.55 ? 4 : 3]); R.front.light(cx, cy, pal[2], 0.25 * R.P.intensity);
      for (let o = 0.5; o <= w; o += 0.5) for (const sg of [-1, 1]) { if (hash(d * 5.3 + o * 9.1 + sg * 3 + q.seed) > 0.85 - o / (w + 1) * 0.4) continue; R.back.px(cx + sd.x * o * sg, cy + sd.y * o * sg, hash(d * 7.1 + o * 3.3 + sg) > 0.97 ? pal[4] : D_SPACE[o < w * 0.5 ? 0 : 1]); } }
    if (q.age < r.scratch_time) { for (let m = 0; m < 6; m++) { const a = angOf(u) + Math.PI + (hash(q.seed + m * 3 + Math.floor(S.t * 40)) - 0.5) * 1.6, dd = 2 + 5 * hash(m * 7 + q.seed); R.front.px(B.x + Math.cos(a) * dd, B.y + Math.sin(a) * dd, pal[4]); } R.front.glow(B.x, B.y, 4, pal[3], 0.5 * R.P.intensity); }
  }
}
// 吸い込み：まわりの光の筋と星屑が、口へ向かって流れながら細く伸びる
function dInhaleFx(S, R) {
  const r = S.r; if (S.tech !== 'inhale' || S.B.mode !== 'active' || S.elapsed >= r.inhale_time) return; const pal = dRamp(R), mouth = dMouth(S), k = smooth(0, 0.4, S.elapsed) * (1 - smooth(r.inhale_time - 0.3, r.inhale_time, S.elapsed));
  for (let i = 0; i < 110; i++) { const ph = (hash(i * 17) + S.t * (0.45 + 0.6 * hash(i))) % 1, an = hash(i * 31) * TAU + ph * 0.8, rad = r.pull_range * 0.6 * (1 - ph) ** 1.3, sl = 20 + 70 * ph, head = add(mouth, mul(fromA(an), rad));
    for (let s = 0; s < sl; s += 0.6 / WL) { const q = toL(add(head, mul(fromA(an), s))), b = (1 - s / sl) * ph * k; if (b < 0.06) continue; if (b > 0.55) R.back.px(q.x, q.y, pal[3]); else R.back.dot(q.x, q.y, pal[2], b * 1.4); }
    if (i % 9 === 0) dStar(R, toL(head), 1 + ph * 2, S.t * 4 + i, k * ph, pal); }
  const m = toL(mouth); R.front.glow(m.x, m.y, 8 * R.P.size, pal[3], 0.5 * k * R.P.intensity);
}
// 吐き出し：口から光線。予告は口へ光が集まって照準の光（白くしない）
function dExhaleFx(S, R) {
  if (!S.exhale || S.B.mode !== 'active') return; const r = S.r, e = S.exhale, age = S.t - e.t, end = add(e.at, mul(fromA(e.a), r.reach));
  if (age < r.beam_warn) { const k = clamp(age / r.beam_warn); bossGather(R, e.at, 150, k, S.t, 21); FX.warnRail(R.front, toL(e.at), toL(end), { color: R.P.color, k, time: S.t, seed: 5, maxLv: 2, intensity: R.P.intensity }); }
  else { const f = clamp((age - r.beam_warn) / r.beam_extend); FX.beam(R.front, toL(e.at), toL(end), { w: r.width * WL * R.P.size, color: R.P.color, time: S.t, from: 0, to: f, taper: 8, alpha: 1, intensity: R.P.intensity }); }
}
// 突進・飛びかかり：体の両脇に空気の筋がはがれて後ろへ流れ、頭の先で砂ぼこり
function dRushFx(S, R, pose) {
  if (!['charge', 'leap'].includes(S.tech) || S.B.mode !== 'active') return; const pal = dRamp(R), pts = pose.points, head = pts[0], dir = norm(sub(pts[0], pts[3])), sd = orth(dir), k = 1 - smooth(S.r.active * 0.7, S.r.active, S.elapsed);
  for (const side of [-1, 1]) for (let j = 0; j < 3; j++) { const id = side * 5 + j, off = (DP.body_width * 0.55 + 20 * j) * R.P.size, len0 = (140 + 120 * hash(id)) * k;
    for (let s = 0; s < len0; s += 0.6 / WL) { const p = pathAt(pts, s), q = toL(add(p.pos, mul(orth(fromA(p.angle)), side * (off + s * 0.08)))), b = (1 - s / len0) * k; if (b > 0.5) R.front.px(q.x, q.y, pal[3]); else R.front.dot(q.x, q.y, pal[2], b * 1.2); } }
  const q = toL(add(head, mul(dir, 140))); R.front.glow(q.x, q.y, 8, pal[2], 0.35 * k * R.P.intensity);
}
// 噛みつき：口先で上下の牙の鉤が寄り、閃光
function dFangs(S, R, mouth, angle, t, radius, seed) {
  if (t < 0 || t > 0.5) return; const pal = dRamp(R), fw = fromA(angle), sd = orth(fw), Rr = radius * R.P.size, p = clamp(t / 0.06), out = clamp((t - 0.06) / 0.2);
  for (const side of [-1, 1]) { const P0 = add(add(mouth, mul(sd, side * Rr * 0.8)), mul(fw, 0.1 * Rr)), C = add(add(mouth, mul(sd, side * Rr * 0.72)), mul(fw, 0.72 * Rr)), P1 = add(add(mouth, mul(fw, 0.92 * Rr)), mul(sd, side * Rr * 0.14)), steps = Math.ceil(Rr * 2.2 * WL);
    for (let i = 0; i <= steps; i++) { const u = i / steps; if (u > p || u < out) continue; if (out > 0.3 && hash(i * 7 + side * 3 + seed + Math.floor(t * 40)) > (1 - out) * 1.6) continue;
      const q = toL(add(add(mul(P0, (1 - u) ** 2), mul(C, 2 * u * (1 - u))), mul(P1, u * u))), w = (0.4 + 1.6 * Math.sin(Math.PI * u) ** 0.7) * R.P.size * (1 - out * 0.6);
      for (let o = -w; o <= w; o += 0.5) { const e = Math.abs(o) / Math.max(0.3, w); R.front.px(q.x + sd.x * o * side, q.y + sd.y * o * side, pal[(p - u < 0.25 || e < 0.35) && out < 0.5 ? 4 : e < 0.7 ? 3 : 2]); } } }
  const hit = toL(add(mouth, mul(fw, 0.45 * Rr))), fl = Math.exp(-Math.max(0, t - 0.05) / 0.07);
  if (t > 0.04) { for (const [u, l] of [[fw, 16], [mul(fw, -1), 5], [sd, 8], [mul(sd, -1), 7]]) for (let d = 0; d <= l * fl * R.P.size; d += 0.5) R.front.light(hit.x + u.x * d, hit.y + u.y * d, pal[3], (1 - d / (l * fl * R.P.size + 0.01)) * 0.9 * R.P.intensity); R.front.px(hit.x, hit.y, pal[4]); }
}
// 着弾：最初に白く光り、割れ目が光って冷え、土ぼこりと欠片が外へ散る
function dImpactFx(S, R, at, age, radius, seed) {
  if (age < 0 || age > 1.4) return; const pal = dRamp(R), c = toL(at), rr = radius * WL * R.P.size, heat = Math.pow(clamp(1 - age / 1.1), 1.4);
  if (heat > 0) for (const q of aqCracks(seed, rr)) for (let i = 0; i < q.pts.length; i++) { const [x, y] = q.pts[i], h = heat * (1 - 0.5 * i / q.pts.length) - hash(x * 7.1 + y * 3.3) * 0.25; R.back.px(c.x + x, c.y + y, h > 0.6 ? pal[4] : h > 0.35 ? pal[3] : h > 0.12 ? pal[1] : D_SPACE[1]); }
  if (age < 0.08) { R.front.glow(c.x, c.y, rr * 1.1, pal[3], (1 - age / 0.08) * 0.8 * R.P.intensity); R.front.glow(c.x, c.y, rr * 0.35, pal[4], (1 - age / 0.08) * R.P.intensity); }
  hDust(S, R, at, age - 0.03, seed, 0, 1.6);
  for (let i = 0; i < 18; i++) { const life = 0.3 + 0.35 * hash(seed + i * 3.7); if (age > life) continue; const a = hash(seed + i * 5.3) * TAU, d = (90 + 160 * hash(i * 1.9)) * 0.14 * (1 - Math.exp(-age / 0.14)) * WL + rr * 0.3, k = age / life; R.front.px(c.x + Math.cos(a) * d, c.y + Math.sin(a) * d, k < 0.3 ? pal[3] : H_STONE[k < 0.6 ? 4 : 3]); }
}
// 全身複製：それぞれの分身が、うみへびの技を自分の口から出す
function dCloneFx(S, R) {
  if (S.tech !== 'clones' || S.B.mode !== 'active') return;
  for (const u of S.units) { if (!u.mode || u.t <= 0) continue; const r = hRule(u.mode), e = u.t - r.normal_charge, mouth = add(u.pos, mul(fromA(u.angle), 120 * DP.head_scale)), col = HM_COLORS[{ bite_thrust: 'bite', wind_band: 'vortex', rubble_fan: 'debris', beam_fixed: 'beam', thunder_drop: 'thunder' }[u.mode]], pal = FX.ramp(col), RP = { ...R, P: { ...R.P, color: col } };
    if (e < 0) { bossGather(RP, mouth, 70, clamp(u.t / r.normal_charge), S.t, 400 + u.index); continue; }
    if (u.mode === 'beam_fixed' && e < r.beam_time) FX.beam(R.front, toL(mouth), toL(add(mouth, mul(fromA(u.angle), r.beam_len))), { w: r.beam_width * WL * R.P.size, color: col, time: S.t, from: clamp((e - r.beam_time + 0.1) / 0.1), to: clamp(e / 0.07), taper: 6, alpha: 1, intensity: R.P.intensity });
    if (u.mode === 'wind_band' && e < r.wind_time + 0.3) { const dir = fromA(u.angle), sd = orth(dir), on = e < r.wind_time ? 1 : 1 - (e - r.wind_time) / 0.3; for (let i = 0; i < 50; i++) { const lane = (hash(i * 1.37 + u.index) - 0.5) * 2, v = 900 + 500 * hash(i * 2.1), sl = 40 + 50 * hash(i * 3.9), head = ((e * v + hash(i * 5.3) * r.wind_length) % (r.wind_length * 1.2)); for (let s = Math.max(0, head - sl); s <= head; s += 0.6 / WL) { const q = toL(add(add(mouth, mul(dir, s)), mul(sd, lane * r.wind_width * 0.5 * (0.55 + 0.45 * clamp(s / r.wind_length))))), b = ((s - head + sl) / sl) * on; if (b > 0.5) R.front.px(q.x, q.y, pal[3]); else if (b > 0.06) R.front.dot(q.x, q.y, pal[2], b * 1.3); } } }
    if (u.mode === 'thunder_drop') hStrike(S, RP, toL(u.target), r.thunder_radius * WL * R.P.size, e, 29 + u.index, voltRamp(col), toL(mouth));
    if (u.mode === 'bite_thrust') dFangs(S, RP, add(u.pos, mul(fromA(u.angle), 120 * DP.head_scale)), u.angle, e - r.normal_lunge, r.bite_radius, u.index * 13);
  }
}
function dShotsFx(S, R) {
  const pal = dRamp(R);
  for (const q of S.shots) { const age = S.t - q.t, u = fromA(q.a);
    if (q.kind === 'arrow') { drawArrow(q.pos, q.a, q.radius); for (let d = 0; d < 60; d += 2) { const w = toL(sub(q.pos, mul(u, d))); R.front.light(w.x, w.y, pal[2], (1 - d / 60) * 0.3 * R.P.intensity); } continue; }
    const big = q.kind === 'comet', tl = big ? 140 : 70; // 星弾：回る星と、後ろへ冷えていくまたたきの尾
    for (let d = 2; d < tl; d += 1.5) { const w = toL(add(sub(q.pos, mul(u, d)), mul(orth(u), Math.sin(d * 0.08 + age * 9) * 3))), f = 1 - d / tl; if (hash(d * 3 + Math.floor(S.t * 24) + q.t * 7) < f * 0.8) R.front.dot(w.x, w.y, pal[f > 0.6 ? 3 : 2], f); }
    dStar(R, toL(q.pos), (big ? 4 : 2.5) * R.P.size, age * 8, 1, pal); }
}
function dDraw(S, R) {
  R = bossView(R, '#ab9cff');
  const r = S.r, B = S.B, P = R.P, id = S.tech, t = S.t, pose = R.proto ? dOrganic(S, R, dPresentation(S)) : null; dTellDraw(S, R, pose);
  if (!R.proto) {
    if (S.fan && B.mode === 'active') { D2.poly(S.fan, rgba('#5775ff', 0.5)); D2.polyline(S.fan, '#addbff', 4); }
    if (S.exhale && B.mode === 'active') { const e = S.exhale, age = t - e.t, end = add(e.at, mul(fromA(e.a), r.reach)); if (age < r.beam_warn) D2.line(e.at, end, rgba('#d4bbff', 0.35), 4); else D2.line(e.at, add(e.at, mul(fromA(e.a), r.reach * clamp((age - r.beam_warn) / r.beam_extend))), '#d4bbff', r.width); }
    for (const q of S.rifts) if (q) D2.line(q.a, q.b, '#34224d', r.width);
  } else { dBreathFx(S, R); dRiftFx(S, R); dInhaleFx(S, R); dExhaleFx(S, R); dRushFx(S, R, pose); dCloneFx(S, R);
    if (id === 'bite' && B.mode !== 'windup') dFangs(S, R, pose.mouth, pose.facing, (B.mode === 'active' ? S.elapsed : r.active + S.elapsed) - r.active * 0.7, r.width * 0.7, 3);
    for (const impact of S.impacts) dImpactFx(S, R, impact.at, t - impact.t, impact.radius, 83 + Math.floor(impact.t * 10));
    for (const q of S.arrowImpacts || []) if (q.at && !q.hit) dGroundTremble(S, R, q.at, r.radius, clamp((t - q.t - q.wait) / q.warn), 171);
  }
  if (R.proto) for (const q of S.projectiles) if (q.vel && q.t != null) { const sp = len(q.vel), dir = norm(q.vel), age = t - q.t; hRockComet(R, { from: sub(q.pos, mul(q.vel, age)), speed: sp, radius: q.radius, seed: q.seed || 1 }, age, dir); }
  R.blitBack();
  for (const q of S.projectiles) { if (R.proto) { if (q.vel) hRockGhosts(q.pos, norm(q.vel), len(q.vel), q.seed + t, q.radius); drawImg('meteor_0', q.pos, q.seed + t, q.radius); } else D2.circle(q.pos, q.radius, '#8c704c'); }
  for (const rock of S.rocks) drawImg('meteor_0', rock.pos, rock.seed * 1.7, rock.radius);
  if (id === 'clones' && B.mode === 'active') { for (const unit of S.units) drawDraco(unit.points, unit.angle, unit.index > 0 ? 0.85 : 1); }
  else if (R.proto) drawDraco(pose.points, pose.facing, 1, pose.width || DP.body_width, pose.arms);
  else drawDraco(S.points, B.facing);
  if (id === 'rifts' && B.mode === 'active' && R.proto) for (let hand = 0; hand < 2; hand++) { const local = S.elapsed - hand * r.interval, path = S.paths?.[hand * r.claw_count]; if (path && local >= 0 && local < 0.18) dSupply(R, pose.claws[hand], path[0], 1 - local / 0.18, t * 3, 311 + hand, hand ? 22 : -22); }
  if (S.picaro) for (const q of S.picaro) drawEnemy(q, { white: clamp(1 - S.age) * 0.6 });
  const chest = toL(R.proto ? pose.chest : sub(B.pos, mul(fromA(B.facing), 110 * DP.head_scale))); R.front.glow(chest.x, chest.y, 10, hexc('#8dbdff'), 0.35 + (R.proto ? Math.max(0, pose.charge) * 0.25 : 0));
  if (R.proto) dShotsFx(S, R);
  else { for (const q of S.shots) { if (q.kind === 'arrow') drawArrow(q.pos, q.a, q.radius); else { const u = fromA(q.a), side = orth(u); D2.poly([add(q.pos, mul(u, q.radius * 1.5)), add(q.pos, mul(side, q.radius)), sub(q.pos, mul(u, q.radius * 1.5)), sub(q.pos, mul(side, q.radius))], '#d4bbff'); } }
    for (const impact of S.arrowImpacts || []) if (impact.at && !impact.hit) D2.arc(impact.at, r.radius, 0, TAU, '#b7a3ff', 3);
    for (const impact of S.impacts) { const age = t - impact.t; if (age < 0.65) D2.arc(impact.at, impact.radius * (0.35 + age / 0.65 * 1.4), 0, TAU, rgba('#9fbaff', 1 - age / 0.65), 6); } }
  drawShip(S.ship);
}
// 状態欄：作り直した見た目の説明を足す
for (const d of DEMOS) if (d.id.startsWith('D-')) d.status = { ...d.status, '状態': '見た目を作り直した試作（未承認）', '試作の見た目': '予兆は照準の光（白くしない）と部位へ光を運ぶ粒。ブレスは口から流れる光の筋の束と星、岩で止まると火花。爪はぎざぎざの空間の裂け目。星弾は回る星とまたたきの尾。着弾は白い光・冷える割れ目・土ぼこり・欠片。吸い込みは口へ流れる筋と星屑。突進は体の両脇の空気の筋。全身複製は分身の口からうみへびの技', '動き': '体の動き・技の時刻・軌道は以前の再生（現行の値）のまま。main の cpp/bosses/draco との行ごとの照合はしていない' };
for (const d of DEMOS) if (d.id === 'D-spiral') d.status = { ...d.status, '螺旋（本人指示で変更）': '中心は巻き始めの自機の位置で固定し、外周から内周まで2周で一定に半径を縮める（中心へずらす補正をやめ、2周目が1周目に寄って通り道を塞がない）。上から入って上で巻き終わり、頭は自機の少し上で画面の下へ向ける。直進では頭が真下へ抜け、残りの胴は紐を結ぶように渦ごと中心へ締まる', '本番との違い': '本番（spiral.cpp）は2周目に中心を自機へ寄せる補正があり、直進後の胴は通った道をたどってほどける。採用するなら本番の動きと判定を変える必要がある' };
for (const d of DEMOS) if (d.id === 'D-spiral') d.params = [...(d.params || []), { k: 'spiralScale', label: '渦の外周の大きさ（周回の間）', type: 'range', min: 1, max: 1.7, step: 0.05, def: 1.3 }];

// 生き物らしさ（螺旋）：絵の動きだけに、頭から尾へ流れるうねり・頭の振り・直進前のための引きを足す（当たりの点列は変えない）
function dOrganic(S, R, pose) {
  if (S.tech !== 'spiral' || !S.spiral || !pose) return pose; const sp = S.spiral, k = R.P.alive ?? 1; if (k <= 0) return pose;
  const t = S.t, active = S.B.mode === 'active', e = S.elapsed, shrinkAt = sp.coil + sp.pause;
  const swim = !active ? 1 : e < sp.coil ? 1 : e < shrinkAt ? 0.35 : 0.7, pts = pose.points, N = pts.length - 1;
  let s = 0; const out = pts.map((p, i) => { if (i > 0) s += dist(pts[i - 1], p); const a = i === 0 ? sub(pts[1], pts[0]) : sub(p, pts[i - 1]), n = orth(norm(a)), u = i / N;
    const amp = 26 * k * swim * (0.15 + 0.85 * smooth(0, 0.35, u)) * (0.75 + 0.25 * Math.sin(t * 3.1 + u * 4)), wave = Math.sin(s / 560 * TAU - t * 7.5) * amp;
    return add(p, mul(n, wave)); });
  let facing = pose.facing + Math.sin(t * 5.3) * 0.07 * k * swim;
  // 直進の前：頭を少し引いて力み、震えて止まる → 飛び出す
  if (active && e >= sp.coil && e < shrinkAt + 0.15) { const pull = smooth(shrinkAt - 0.45, shrinkAt - 0.05, e) * (1 - smooth(shrinkAt, shrinkAt + 0.12, e)), back = mul(fromA(pose.facing), -48 * pull * k), shake = mul(orth(fromA(pose.facing)), Math.sin(t * 90) * 3 * pull * k);
    for (let i = 0; i <= 6; i++) out[i] = add(out[i], mul(add(back, shake), 1 - i / 7)); }
  return { ...pose, points: out, facing };
}
for (const d of DEMOS) if (d.id === 'D-spiral') d.params = [...(d.params || []), { k: 'alive', label: '生き物らしさ（うねり・頭の振り・ため）', type: 'range', min: 0, max: 2, step: 0.05, def: 1 }];

// 螺旋の待ちの予兆：光が尾から頭へ胴を満たしていき、頭に届いたら飛び出す（照準の線は出さない）
function dSpiralCountdown(S, R, pose) {
  const sp = S.spiral; if (!sp || S.B.mode !== 'active' || !pose) return; const e = S.elapsed, shrinkAt = sp.coil + sp.pause; if (e < sp.coil || e >= shrinkAt + 0.1) return;
  const q = clamp((e - sp.coil) / sp.pause), pal = dRamp(R), pts = pose.points, N = pts.length - 1, cut = N * (1 - q), last = smooth(0.85, 1, q);
  for (let i = N; i >= Math.max(0, Math.floor(cut)); i--) { const c = toL(pts[i]), edge = clamp(1 - (i - cut) / 6), pulse = 0.75 + 0.25 * Math.sin(S.t * 9 - i * 0.5);
    R.front.glow(c.x, c.y, (7 + 4 * edge) * R.P.size, pal[edge > 0.5 ? 3 : 2], (0.38 + 0.5 * edge) * pulse * R.P.intensity); R.front.px(c.x, c.y, pal[edge > 0.3 ? 4 : 3]);
    for (let m = 0; m < 3; m++) { const a = hash(i * 7 + m * 13 + Math.floor(S.t * 12)) * TAU, d = 2 + 9 * hash(i * 3 + m); if (hash(i + m * 5 + Math.floor(S.t * 8)) < 0.5) R.front.px(c.x + Math.cos(a) * d, c.y + Math.sin(a) * d, pal[3]); } }
  const head = pts[0], M = toL(add(head, mul(fromA(pose.facing), 120 * DP.head_scale))), end = toL(add(head, V(0, 950)));
  bossGather(R, add(head, mul(fromA(pose.facing), 120 * DP.head_scale)), 120, q, S.t, 88);
  if (last > 0) { for (const sx of [-1, 1]) { const ey = toL(add(head, add(mul(fromA(pose.facing), 40), mul(orth(fromA(pose.facing)), sx * 34)))); R.front.glow(ey.x, ey.y, 3 + 4 * last, pal[3], last * R.P.intensity); R.front.px(ey.x, ey.y, pal[4]); } }
}
for (const d of DEMOS) if (d.id === 'D-spiral') d.params = [...(d.params || []), { k: 'spiralTail', label: '胴（しっぽ）の長さ', type: 'range', min: 0.6, max: 1, step: 0.05, def: 0.85 }, { k: 'spiralWait', label: '円になってから飛び出すまで（秒）', type: 'range', min: 1.6, max: 4.5, step: 0.1, def: 2.8 }];
