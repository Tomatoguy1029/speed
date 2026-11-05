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
  dEyesTell(S, R, pose, k);
  if (S.tech !== 'bite') S.tell.forEach((path, i) => { if (path.length > 2) { for (let m = 0; m < path.length; m += 4) dGroundTremble(S, R, path[m], 40, k, 500 + m); } else FX.warnRail(R.back, toL(path[0]), toL(path[1]), { color: R.P.color, k: 0.3 + 0.7 * k, time: S.t, seed: 300 + i, maxLv: 2, intensity: R.P.intensity }); });
  if (S.B.mode !== 'windup' || (S.staging && S.staging.phase !== 'ready')) return;
  const id = S.tech;
  if (id === 'rifts') for (let i = 0; i < 2; i++) { bossGather(R, pose.claws[i], 66, k, S.t, 191 + i); dSupply(R, pose.chest, pose.claws[i], k, S.t, 211 + i, i ? 32 : -32); }
  else if (['tail_sweep', 'tail_slam'].includes(id)) { const end = pose.points[pose.points.length - 1]; bossGather(R, end, 100, k, S.t, 193); dSupply(R, pathAt(pose.points, pathLength(pose.points) * 0.72).pos, end, k, S.t, 213); }
  else if (!['charge', 'leap', 'bite', 'spiral', 'clones'].includes(id)) { bossGather(R, pose.mouth, 85, k, S.t, 191); dSupply(R, pose.chest, pose.mouth, k, S.t, 215, 30); }
  if (id === 'tail_slam' && S.target) dGroundTremble(S, R, S.target, S.r.radius, k, 121);
  if (id === 'star_fan') (S.starPositions || []).forEach((q, i) => { dSupply(R, pose.mouth, q.pos, smooth(0.15, 0.8, k), S.t, 230 + i, (i - S.starPositions.length * 0.5) * 7); dStar(R, toL(q.pos), 1 + 2.5 * k, S.t * 3 + i, k, dRamp(R)); });
}
// 目の光：飛びかかる技の合図。ゆっくり灯って、出る直前に強くまたたく
function dEyes(S, R, pose, k, color) {
  if (k <= 0) return; const c = hexc(color), fw = fromA(pose.facing), sd = orth(fw), blink = 0.72 + 0.28 * Math.sin(S.t * (14 + 26 * k)), L = (3 + 10 * k) * R.P.size;
  for (const side of [-1, 1]) { const e = toL(add(add(pose.points[0], mul(fw, 40)), mul(sd, side * 34)));
    R.back.glow(e.x, e.y, (6 + 13 * k) * R.P.size, c, (0.5 + 0.7 * k) * blink * R.P.intensity); R.front.disc(e.x, e.y, (1.6 + 1.2 * k) * R.P.size, c, 1); if (k > 0.6) R.front.disc(e.x, e.y, 0.7 * R.P.size, PX.WHITE, 1);
    for (let d = -L; d <= L; d += 0.5) R.front.blend(e.x + sd.x * d, e.y + sd.y * d, c, Math.pow(1 - Math.abs(d) / L, 2) * 0.95 * k * blink); }
}
function dEyesTell(S, R, pose, k) {
  if (S.B.mode !== 'windup' || (S.staging && S.staging.phase !== 'ready')) return;
  if (['bite', 'charge', 'leap', 'clones'].includes(S.tech)) dEyes(S, R, pose, smooth(0.15, 0.95, k), '#ff5470');
  else if (['tail_sweep', 'tail_slam', 'rifts'].includes(S.tech)) dEyes(S, R, pose, 0.45 * smooth(0.3, 1, k), R.P.color);
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
// 星のブレス：口から広がる炎の塊。画素ごとに流れるノイズの濃さを求め、本当の半透明で重ねる。隕石で切れた所は手前で止まり、火花が散る
function dBreathFx(S, R) {
  if (!S.fan || S.B.mode !== 'active') return; const pal = dRamp(R), p = R.front, r = S.r, t = S.elapsed, n = S.fan.length - 1, a0 = S.fanAngle, ha = r.half_angle * 1.2, back = 70 * WL * R.P.size, M = toL(S.fan[0]), O = V(M.x - Math.cos(a0) * back, M.y - Math.sin(a0) * back); // 炎の根元を口の奥へ置き、口の幅から出す
  const on = smooth(0, 0.14, t) * (1 - smooth(r.active - 0.3, r.active, t)), Lmax = r.reach * WL * R.P.size, reach = S.fan.slice(1).map(q => dist(S.fan[0], q) * WL * R.P.size), front = Lmax * smooth(0, 0.3, t);
  const ramp = v => { const q = clamp(v) * 3, i = Math.min(2, Math.floor(q)); return PX.mix(pal[1 + i], pal[2 + i], q - i); };
  const xs = [O.x, O.x + Math.cos(a0 - ha) * Lmax, O.x + Math.cos(a0 + ha) * Lmax, O.x + Math.cos(a0) * Lmax], ys = [O.y, O.y + Math.sin(a0 - ha) * Lmax, O.y + Math.sin(a0 + ha) * Lmax, O.y + Math.sin(a0) * Lmax];
  p.each(Math.min(...xs) - 4, Math.min(...ys) - 4, Math.max(...xs) + 4, Math.max(...ys) + 4, (x, y, sx, sy) => {
    const dx = x - O.x, dy = y - O.y, d = Math.hypot(dx, dy); if (d < back || d > front + back) return; const lat = angDiff(Math.atan2(dy, dx), a0) / ha; if (Math.abs(lat) > 1) return;
    const lim = back + reach[Math.min(n - 1, Math.max(0, Math.round((lat * 0.83 + 1) * 0.5 * (n - 1))))]; if (d > lim) return;
    const u = d / Lmax, flow = PX.tileFbm(d * 0.045 - t * 7, lat * 2.2 + Math.sin(d * 0.03 - t * 3) * 0.3, 0, 0, 23, 3), fine = PX.tileFbm(d * 0.12 - t * 12, lat * 6, 0, 0, 9, 2);
    const edge = 1 - Math.pow(Math.abs(lat), 2.2) * (1.1 - 0.5 * flow), body = clamp(edge * (0.62 + 0.75 * flow + 0.25 * fine)), far = 1 - smooth(0.62, 1, u) * (0.95 - 0.6 * flow), stop = clamp((lim - d) / 6 + 0.2), a = clamp(body * 1.2) * far * stop * on;
    if (a < 0.03) return; const heat = clamp(body * (1 - 0.7 * u) + (1 - Math.abs(lat) * 1.6) * 0.22 * (1 - u)); p.blendPx(sx, sy, ramp(heat), Math.min(0.96, a));
    if (heat > 0.88 && a > 0.5) p.blendPx(sx, sy, pal[4], (heat - 0.88) * 3 * a); });
  for (let i = 0; i < 14; i++) { const j = 1 + Math.floor(hash(i * 4.3) * n), dir = norm(sub(S.fan[j], S.fan[0])), s = ((t * 900 + hash(i * 6.6) * 1500) % dist(S.fan[0], S.fan[j])); dStar(R, toL(add(S.fan[0], mul(dir, s))), 1.5, t * 6 + i, on * 0.7, pal); }
  for (let j = 1; j <= n; j += 3) { if (dist(S.fan[0], S.fan[j]) >= r.reach - 1) continue; const q = toL(S.fan[j]), back = a0 + Math.PI; for (let m = 0; m < 2; m++) { const a = back + (hash(j + m * 7 + Math.floor(t * 30)) - 0.5) * 2.4, dd = 2 + 7 * hash(j * m + 3 + Math.floor(t * 24)); p.blend(q.x + Math.cos(a) * dd, q.y + Math.sin(a) * dd, pal[4], on * 0.9); } }
  p.glow(M.x, M.y, 6 * R.P.size, pal[3], 0.45 * on * R.P.intensity);
}
// 空間の裂け目：爪の通った所に、ぎざぎざの細い割れ目が走る。芯は光り、両脇は暗い宇宙がのぞく。終わりは両端から閉じる（輪郭で囲まない）
function dRiftFx(S, R) {
  const r = S.r, pal = dRamp(R), closeK = S.B.mode === 'active' ? smooth(r.active - 0.6, r.active, S.elapsed) : 1;
  for (const q of S.rifts || []) { if (!q) continue;
    const A = toL(q.a), B = toL(q.b), L = dist(A, B); if (L < 1) continue; const u = norm(sub(B, A)), sd = orth(u), open = smooth(0, 0.12, q.age);
    for (let d = 0; d <= L; d += 0.5) { const f = d / L; if (Math.abs(f - 0.5) * 2 > 1 - closeK) continue;
      const jag = (hash(q.seed * 13 + Math.floor(d / 3)) - 0.5) * 3 + Math.sin(d * 0.21 + q.seed) * 1.2, w = (0.6 + r.scratch_width * 0.25 * WL * R.P.size * Math.sin(Math.PI * f) ** 0.8) * open, cx = A.x + u.x * d + sd.x * jag, cy = A.y + u.y * d + sd.y * jag;
      R.front.px(cx, cy, pal[hash(d * 3 + Math.floor(S.t * 20) + q.seed) > 0.55 ? 4 : 3]); R.front.light(cx, cy, pal[2], 0.25 * R.P.intensity);
      for (let o = 0.5; o <= w; o += 0.5) for (const sg of [-1, 1]) R.back.blend(cx + sd.x * o * sg, cy + sd.y * o * sg, D_SPACE[o < w * 0.5 ? 0 : 1], Math.pow(1 - o / (w + 0.5), 0.7) * 0.9); }
    if (q.age < r.scratch_time) { for (let m = 0; m < 6; m++) { const a = angOf(u) + Math.PI + (hash(q.seed + m * 3 + Math.floor(S.t * 40)) - 0.5) * 1.6, dd = 2 + 5 * hash(m * 7 + q.seed); R.front.px(B.x + Math.cos(a) * dd, B.y + Math.sin(a) * dd, pal[4]); } R.front.glow(B.x, B.y, 4, pal[3], 0.5 * R.P.intensity); }
  }
}
// 吸い込み：まわりの光の筋と星屑が、口へ向かって流れながら細く伸びる
function dInhaleFx(S, R) {
  const r = S.r; if (S.tech !== 'inhale' || S.B.mode !== 'active' || S.elapsed >= r.inhale_time) return; const pal = dRamp(R), mouth = dMouth(S), k = smooth(0, 0.4, S.elapsed) * (1 - smooth(r.inhale_time - 0.3, r.inhale_time, S.elapsed));
  for (let i = 0; i < 90; i++) { const ph = (hash(i * 17) + S.t * (0.45 + 0.6 * hash(i))) % 1, an = hash(i * 31) * TAU + ph * 2.6, rad = r.pull_range * 0.6 * (1 - ph) ** 1.3, sl = 20 + 70 * ph, head = add(mouth, mul(fromA(an), rad));
    for (let s = 0; s < sl; s += 0.5 / WL) { const q = toL(add(head, mul(fromA(an - 0.9 - (s / sl) * 1.1), s))), b = (1 - s / sl) * ph * k; if (b < 0.06) continue; R.back.blend(q.x, q.y, pal[b > 0.55 ? 3 : 2], Math.min(0.7, b * 0.85)); }
    if (i % 9 === 0) dStar(R, toL(head), 1 + ph * 2, S.t * 4 + i, k * ph, pal); }
  const m = toL(mouth); R.front.glow(m.x, m.y, 8 * R.P.size, pal[3], 0.5 * k * R.P.intensity);
}
// 吐き出し：口から光線。予告は口へ光が集まって照準の光（白くしない）
function dExhaleFx(S, R) {
  if (!S.exhale || S.B.mode !== 'active') return; const r = S.r, e = S.exhale, age = S.t - e.t, end = add(e.at, mul(fromA(e.a), r.reach));
  if (age < r.beam_warn) { const k = clamp(age / r.beam_warn); bossGather(R, e.at, 150, k, S.t, 21); FX.warnRail(R.front, toL(e.at), toL(end), { color: R.P.color, k, time: S.t, seed: 5, maxLv: 2, intensity: R.P.intensity }); }
  else { const f = clamp((age - r.beam_warn) / r.beam_extend), A = toL(e.at); FX.beam(R.front, A, toL(end), { w: r.width * 0.5 * WL * R.P.size, source: false, color: R.P.color, time: S.t, from: 0, to: f, taper: 8, alpha: 1, intensity: R.P.intensity }); FX.flare(R.front, A, 1.8 * R.P.size, R.P.color, S.t, 0.55, 4); }
}
// 突進・飛びかかり：体の縁から空気がはがれて細く尾を引き、踏み切った所に土ぼこりが立つ
function dRushFx(S, R, pose) {
  if (!['charge', 'leap'].includes(S.tech) || S.B.mode !== 'active') return; const pal = dRamp(R), pts = pose.points, e = S.elapsed, k = 1 - smooth(S.r.active * 0.55, S.r.active, e), wind = 1 - smooth(0, 0.5, e / S.r.active), start = S.tech === 'leap' ? S.takeoff : S.origin;
  hDust(S, R, start, e, 61, S.axis + Math.PI, 1.3);
  const total = pathLength(pts), hw = DP.body_width * 0.5;
  for (const side of [-1, 1]) for (let j = 0; j < 2; j++) { const reach = Math.min(total, (240 + 130 * j) * wind + 60), from = 60 + j * 90;
    for (let s = from; s < from + reach; s += 0.5 / WL) { const at = pathAt(pts, s), u = (s - from) / reach, off = hw * dTaper(s / total) + 4 + u * u * 26, q = toL(add(at.pos, mul(orth(fromA(at.angle)), side * off))); R.front.blend(q.x, q.y, pal[j ? 2 : 3], Math.sin(Math.PI * u) ** 0.8 * k * 0.55); } }
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
// りゅうの噛みつき：閉じる牙の形に空間が裂ける。口が離れても裂け目はその場に残り、暗い宇宙と星がのぞいて、根元から閉じる
function dBiteTear(S, R, pose) {
  const B = S.B, r = S.r; if (B.mode === 'windup' || B.mode === 'idle') return; const t = (B.mode === 'active' ? S.elapsed : r.active + S.elapsed) - r.active * 0.7; if (t < 0) return;
  S.bite ||= { at: { ...pose.mouth }, angle: pose.facing }; const pal = dRamp(R), fw = fromA(S.bite.angle), sd = orth(fw), size = r.width * 1.25 * R.P.size, c = add(S.bite.at, mul(fw, size * 0.3)), snap = dBurst(t / 0.07), close = smooth(0.16, r.recover * 0.7, t); if (close >= 1) return;
  for (const side of [-1, 1]) for (let i = 0; i < 4; i++) { const along = (i - 1.5 + side * 0.22) * size * 0.46, big = (1 - Math.abs(i - 1.5) * 0.2) * (0.78 + 0.4 * hash(i * 3.1 + side * 2)), base = add(add(c, mul(fw, along)), mul(sd, side * size * lerp(1.5, 0.82, snap))), tip = add(base, mul(sd, -side * size * 1.02 * big)), A = toL(base), Bp = toL(tip), L = dist(A, Bp), u = norm(sub(Bp, A)), n = orth(u), wide = (5.5 + 2.5 * big) * R.P.size;
    for (let d = 0; d <= L; d += 0.5) { const f = d / L; if (f < close) continue; const open = Math.pow(1 - f, 0.8), jag = (hash(i * 7 + side * 3 + Math.floor(d / 2)) - 0.5) * 1.4 * f + f * f * wide * 0.3 * (i < 2 ? 1 : -1) * side, w = wide * open * (1 - close * 0.7), x = A.x + u.x * d + n.x * jag, y = A.y + u.y * d + n.y * jag, fade = 1 - close;
      for (let o = -w; o <= w; o += 0.5) { const e = Math.abs(o) / Math.max(0.5, w); R.front.blend(x + n.x * o, y + n.y * o, D_SPACE[e < 0.45 ? 1 : e < 0.8 ? 2 : 3], 0.95 * fade); }
      const rim = pal[t < 0.14 ? 4 : 3]; R.front.blend(x + n.x * w, y + n.y * w, rim, 0.8 * fade); R.front.blend(x - n.x * w, y - n.y * w, rim, 0.8 * fade); if (hash(d * 3.7 + i * 9 + side) > 0.86) dStar(R, V(x, y), 1, S.t * 5 + d, fade, pal); } }
  const k = toL(c), flash = 1 - smooth(0.05, 0.16, t); if (snap >= 1 && flash > 0) R.front.glow(k.x, k.y, size * WL * 1.3, pal[3], 0.75 * flash * R.P.intensity);
  if (snap >= 1) for (let i = 0; i < 12; i++) { const age = t - 0.07, life = 0.3 + 0.4 * hash(i * 3.7); if (age > life) continue; const a = hash(i * 5.3) * TAU, d = (24 + 46 * hash(i * 1.9)) * (1 - Math.exp(-age / 0.16)) * R.P.size; dStar(R, V(k.x + Math.cos(a) * d, k.y + Math.sin(a) * d), 1.6, age * 9 + i, 1 - age / life, pal); }
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
    if (u.mode === 'beam_fixed' && e < r.beam_time) { const from = clamp((e - r.beam_time + 0.1) / 0.1); FX.beam(R.front, toL(mouth), toL(add(mouth, mul(fromA(u.angle), r.beam_len))), { w: r.beam_width * 0.5 * WL * R.P.size, source: false, color: col, time: S.t, from, to: clamp(e / 0.07), taper: 6, alpha: 1, intensity: R.P.intensity }); FX.flare(R.front, toL(mouth), 1.4 * R.P.size, col, S.t, 0.55 * (1 - from), 4); }
    if (u.mode === 'wind_band') hWindBand({ tech: 'wind_band', r, t: S.t }, R, { kind: 'vortex', sweep: u.angle }, { rel: e, T: { active: r.wind_time }, head: mouth, angle: u.angle });
    if (u.mode === 'thunder_drop') hBoltStrike(S, RP, toL(u.target), r.thunder_radius * WL * R.P.size, e, 29 + u.index, voltRamp(col), toL(mouth));
    if (u.mode === 'bite_thrust') dFangs(S, RP, add(u.pos, mul(fromA(u.angle), 120 * DP.head_scale)), u.angle, e - r.normal_lunge, r.bite_radius, u.index * 13);
  }
}
function dShotsFx(S, R) {
  const pal = dRamp(R);
  for (const q of S.shots) { const age = S.t - q.t, u = fromA(q.a);
    if (q.kind === 'arrow') { drawArrow(q.pos, q.a, q.radius); for (let d = 0; d < 60; d += 2) { const w = toL(sub(q.pos, mul(u, d))); R.front.light(w.x, w.y, pal[2], (1 - d / 60) * 0.3 * R.P.intensity); } continue; }
    const big = q.kind === 'comet', tl = big ? 140 : 70; // 星弾：回る星と、後ろへ冷えていくまたたきの尾
    for (let d = 2; d < Math.min(tl, age * q.speed); d += 0.5 / WL) { const w = toL(add(sub(q.pos, mul(u, d)), mul(orth(u), Math.sin(d * 0.03 - age * 14) * 5 * (d / tl)))), f = 1 - d / tl; R.front.blend(w.x, w.y, pal[f > 0.6 ? 4 : f > 0.3 ? 3 : 2], f * f * 0.9); R.front.light(w.x, w.y, pal[2], f * 0.2 * R.P.intensity); }
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
    if (id === 'bite') dBiteTear(S, R, pose);
    for (const impact of S.impacts) dImpactFx(S, R, impact.at, t - impact.t, impact.radius, 83 + Math.floor(impact.t * 10));
    for (const q of S.arrowImpacts || []) if (q.at && !q.hit) dGroundTremble(S, R, q.at, r.radius, clamp((t - q.t - q.wait) / q.warn), 171);
  }
  if (R.proto) for (const q of S.projectiles) if (q.vel && q.t != null) { const sp = len(q.vel), dir = norm(q.vel), age = t - q.t; hRockComet(R, { from: sub(q.pos, mul(q.vel, age)), speed: sp, radius: q.radius, seed: q.seed || 1 }, age, dir); }
  if (R.proto && S.rocks.length && B.mode === 'windup') S.rocks.forEach((q, i) => { const d = norm(sub(q.to, q.from)), sp = dist(q.from, q.to) / Math.max(0.01, r.warn), age = S.elapsed; hRockComet(R, { from: q.from, speed: sp, radius: q.radius, seed: i + 1 }, age, d, { stop: r.warn, pace: 0.6 }); });
  if (R.proto && S.rocks.length && B.mode !== 'windup') S.rocks.forEach((q, i) => hDust(S, R, q.to, S.age - r.warn, 71 + i, 0, 1.4));
  R.blitBack();
  for (const q of S.projectiles) { if (R.proto) { if (q.vel) hRockGhosts(q.pos, norm(q.vel), len(q.vel), q.seed + t, q.radius); drawImg('meteor_0', q.pos, q.seed + t, q.radius); } else D2.circle(q.pos, q.radius, '#8c704c'); }
  for (const rock of S.rocks) drawImg('meteor_0', rock.pos, rock.seed * 1.7, rock.radius);
  if (id === 'clones' && B.mode === 'active') { const on = smooth(0, 0.45, S.elapsed), off = 1 - smooth(r.active - 0.9, r.active - 0.25, S.elapsed); for (const unit of S.units) drawDraco(R.proto ? dSwimPoints(unit.points, t + unit.index * 2, 0.8, unit.index) : unit.points, unit.face ?? unit.angle, unit.index > 0 ? 0.9 * on * off : 1); }
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
for (const d of DEMOS) if (d.id.startsWith('D-')) d.status = { ...d.status, '状態': '見た目と動きを作り直した試作（未承認）', '試作の見た目': '飛びかかる技の予兆は目の光。口から出す技は口へ集める光と照準の光。ブレスは本当の半透明で重ねた炎の塊で、隕石で切れた所で止まり火花が散る。爪はぎざぎざの空間の裂け目。星弾は回る星とつながった光の尾。隕石は飛ぶ間に尾を引く。着弾は白い光・冷える割れ目・土ぼこり・欠片。全身複製はうみへびの技の本物の見た目', '動き': '胴はいつも波打ち、予兆で止まって震え、発動で一気に出る。突進・噛みつきは出だしが最速で止まり際に減速し、叩きつけは加速して落ちる。戻りはずれの大きい所から遅れて波打って戻る。全身複製は弧を描いて持ち場へ回り込む。本番の cpp/bosses/draco は未変更' };
for (const d of DEMOS) if (d.id === 'D-spiral') d.status = { ...d.status, '螺旋（本人指示で変更）': '中心は巻き始めの自機の位置で固定し、外周から内周まで2周で一定に半径を縮める（中心へずらす補正をやめ、2周目が1周目に寄って通り道を塞がない）。上から入って上で巻き終わり、頭は自機の少し上で画面の下へ向ける。直進では頭が真下へ抜け、残りの胴は紐を結ぶように渦ごと中心へ締まる', '本番との違い': '本番（spiral.cpp）は2周目に中心を自機へ寄せる補正があり、直進後の胴は通った道をたどってほどける。採用するなら本番の動きと判定を変える必要がある' };
for (const d of DEMOS) if (d.id === 'D-spiral') d.params = [...(d.params || []), { k: 'spiralScale', label: '渦の外周の大きさ（周回の間）', type: 'range', min: 1, max: 1.7, step: 0.05, def: 1.3 }];

// 生き物らしさ（螺旋）：絵の動きだけに、頭から尾へ流れるうねり・頭の振り・直進前のための引きを足す（当たりの点列は変えない）
// 胴のうねり：頭は動かさず、尾へ向かって流れる波を足す。少し弓なりにして、棒のように伸びきらせない
function dSwimPoints(pts, t, swim, seed = 0, bow = 1) {
  const N = pts.length - 1; let s = 0;
  return pts.map((p, i) => { if (i > 0) s += dist(pts[i - 1], p); const u = i / N, n = orth(norm(sub(pts[Math.min(N, i + 8)], pts[Math.max(0, i - 8)]))), amp = 34 * swim * smooth(0.04, 0.4, u) * (0.75 + 0.25 * Math.sin(t * 3.1 + u * 4)), arch = bow * 70 * smooth(0.06, 0.32, u) * Math.sin(u * Math.PI * 1.35 + 0.5 + seed); return add(p, mul(n, Math.sin(s / 620 * TAU - t * 6.5) * amp + arch)); });
}
// 静と動：予兆が進むほど波を止めて力をため、最後に震える。発動で一気に動き、戻りながら波が戻る
function dSwimAmount(S) {
  const B = S.B, e = S.elapsed, r = S.r; if (S.staging && S.staging.phase !== 'ready') return 1;
  if (B.mode === 'windup') return 0.7 * (1 - smooth(0.1, 0.8, e / Math.max(0.01, r.warn)));
  if (B.mode === 'active') return ['charge', 'leap'].includes(S.tech) ? 1 : ['breath', 'meteor', 'star_fan', 'inhale'].includes(S.tech) ? 0.25 : 0.35;
  if (B.mode === 'recovery') return 0.7 * smooth(0, 1, e / Math.max(0.01, r.recover)); return 0.7;
}
function dBodyAlive(S, R, pose) {
  const k = R.P.alive ?? 1, tail = ['tail_sweep', 'tail_slam'].includes(S.tech), swim = dSwimAmount(S) * k * (tail ? 0.3 : 1), points = dSwimPoints(pose.points, S.t, swim, 0, tail ? 0 : k), B = S.B;
  if (B.mode === 'windup' && (!S.staging || S.staging.phase === 'ready')) { const q = smooth(0.72, 1, S.elapsed / Math.max(0.01, S.r.warn)), shake = mul(orth(fromA(pose.facing)), Math.sin(S.t * 90) * 3 * q * k); if (q > 0) for (let i = 0; i <= 6; i++) points[i] = add(points[i], mul(shake, 1 - i / 7)); }
  return { ...pose, points, facing: pose.facing + Math.sin(S.t * 5.3) * 0.05 * swim };
}
function dOrganic(S, R, pose) {
  if (pose && S.tech !== 'spiral') return dBodyAlive(S, R, pose);
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
