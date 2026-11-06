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
  if (!['bite', 'leap'].includes(S.tech)) S.tell.forEach((path, i) => { if (path.length > 2) { for (let m = 0; m < path.length; m += 4) dGroundTremble(S, R, path[m], 40, k, 500 + m); } else FX.warnRail(R.back, toL(path[0]), toL(path[1]), { color: R.P.color, k: 0.3 + 0.7 * k, time: S.t, seed: 300 + i, maxLv: 2, intensity: R.P.intensity }); });
  if (S.B.mode !== 'windup' || (S.staging && S.staging.phase !== 'ready')) return;
  const id = S.tech;
  if (id === 'rifts') for (let i = 0; i < 2; i++) { bossGather(R, pose.claws[i], 66, k, S.t, 191 + i); dSupply(R, pose.chest, pose.claws[i], k, S.t, 211 + i, i ? 32 : -32); }
  else if (['tail_sweep', 'tail_slam'].includes(id)) { const end = pose.points[pose.points.length - 1]; bossGather(R, end, 100, k, S.t, 193); dSupply(R, pathAt(pose.points, pathLength(pose.points) * 0.72).pos, end, k, S.t, 213); }
  else if (id === 'picaro_wall') { const e = smooth(0.62, 1, k); if (e > 0) dDarkGather(S, R, pose.mouth, e); }
  else if (!['charge', 'leap', 'bite', 'spiral', 'clones'].includes(id)) { bossGather(R, pose.mouth, 85, k, S.t, 191); dSupply(R, pose.chest, pose.mouth, k, S.t, 215, 30); }
  if (id === 'tail_slam' && S.target) dGroundTremble(S, R, S.target, S.r.radius, k, 121);
  if (id === 'star_fan') (S.starPositions || []).forEach((q, i) => { dSupply(R, pose.mouth, q.pos, smooth(0.1, 0.75, k), S.t, 230 + i, (i - S.starPositions.length * 0.5) * 7); dStarCharge(S, R, q, i, smooth(0.08 + i * 0.03, 0.85, k)); });
}
const D_EYE = { fw: 77, side: 25 }; // 頭の絵の赤い目の位置（頭の絵の画素 × head_scale × 2）
// 目の光：飛びかかる技の合図。ゆっくり灯って、出る直前に強くまたたく
function dEyes(S, R, pose, k, color) {
  if (k <= 0) return; const c = hexc(color), fw = fromA(pose.facing), sd = orth(fw), blink = 0.72 + 0.28 * Math.sin(S.t * (14 + 26 * k)), L = (2 + 5 * k) * R.P.size;
  for (const side of [-1, 1]) { const e = toL(add(add(pose.points[0], mul(fw, D_EYE.fw)), mul(sd, side * D_EYE.side)));
    R.back.glow(e.x, e.y, (4 + 7 * k) * R.P.size, c, (0.4 + 0.5 * k) * blink * R.P.intensity); R.front.disc(e.x, e.y, (1 + 0.8 * k) * R.P.size, c, 1); if (k > 0.6) R.front.disc(e.x, e.y, 0.5 * R.P.size, PX.WHITE, 1);
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
// 闇の矢：黒い槍の形に紫の縁が走り、闇の煙を引く。放つと口で闇が弾け、落ちる前に地面へ闇が広がって縮み、闇の爆発になる
const D_DARK = ['#f4e2ff', '#d39bff', '#9a4cf0', '#6a24c4', '#3e1484', '#220b50', '#110630', '#070214'].map(hexc);
function dDarkGather(S, R, mouth, k) {
  const p = R.front, c = toL(mouth), H = D_DARK, s = R.P.size, fire = PIXELFX.fx['src/fx/fire/_lib.js'];
  for (let i = 0; i < 34; i++) { const ph = (S.t * (0.7 + 0.8 * hash(i)) + hash(i * 3.1)) % 1, a = hash(i * 7.7) * TAU + (1 - ph) * 1.6, d = (46 * (1 - ph) ** 1.4 + 4) * s, len = (6 + 12 * ph) * s; for (let m = 0; m < len; m += 0.5) p.blend(c.x + Math.cos(a + m * 0.04) * (d + m), c.y + Math.sin(a + m * 0.04) * (d + m), H[ph > 0.6 ? 2 : 3], (1 - m / len) * ph * k); }
  fire.soft(p, c.x, c.y, (3 + 11 * k) * s, H[3], 0.35 * k); fire.solid(p, c.x, c.y, (1 + 6 * k) * s, H[7]); p.glow(c.x, c.y, (8 + 12 * k) * s, H[2], 0.5 * k * R.P.intensity);
}
function dDarkShot(R, q, age, u) {
  const fire = PIXELFX.fx['src/fx/fire/_lib.js'], p = R.front, H = D_DARK, s = R.P.size, tip = toL(q.pos), L = 58 * s, W = 11 * s, nx = -u.y, ny = u.x, seed = q.t * 13;
  for (let i = 0; i < 14; i++) { const d = L * 0.6 + (i * 13 + age * 900 * ((i % 3) * 0.1 + 0.2) % 13) * s, off = (hash(i * 3.3 + seed) - 0.5) * (6 + i * 1.1) * s, f = i / 14; fire.soft(p, tip.x - u.x * d + nx * off, tip.y - u.y * d + ny * off, (7 - f * 3) * s, H[i % 3 ? 5 : 4], 0.5 * (1 - f)); }
  for (let d = 0; d < L; d += 0.5) { const f = d / L, w = (f < 0.3 ? f / 0.3 : Math.pow(1 - (f - 0.3) / 0.7, 0.7)) * W * (1 + 0.16 * Math.sin(d * 0.9 + age * 40 + seed) * f); for (let o = -w; o <= w; o += 0.5) { const e = Math.abs(o) / Math.max(0.5, w); p.blend(tip.x - u.x * d + nx * o, tip.y - u.y * d + ny * o, e > 0.8 ? H[2] : e > 0.55 ? H[4] : H[7], e > 0.8 ? 1 : 0.97); } p.blend(tip.x - u.x * d + nx * w, tip.y - u.y * d + ny * w, H[1], 1 - f * 0.5); p.blend(tip.x - u.x * d - nx * w, tip.y - u.y * d - ny * w, H[1], 1 - f * 0.5); }
  p.glow(tip.x - u.x * L * 0.4, tip.y - u.y * L * 0.4, 20 * s, H[2], 0.55 * R.P.intensity);
}
function dDarkMuzzle(S, R, pose) {
  const fire = PIXELFX.fx['src/fx/fire/_lib.js'], p = R.front, H = D_DARK, s = R.P.size, c = toL(pose.mouth), fw = fromA(pose.facing), NL = fire.noiseFor(1.5);
  for (const at of S.shotTimes || []) { const age = S.t - at; if (age < 0 || age > 0.42) continue; const k = 1 - age / 0.42, N = (rate, seed = 0, off = 0) => NL(age, rate, seed, off);
    for (let i = 0; i < 4; i++) { const off = (i - 1.5) * 0.3; fire.flameBlade(p, c.x, c.y, Math.cos(pose.facing + off), Math.sin(pose.facing + off), (70 - Math.abs(off) * 50) * s * k, 11 * s * k, N(3, i) * 3, N, 70 + i * 13, H, fire.LAYERS, 0.5, 1.4); }
    for (let i = 0; i < 12; i++) { const a = hash(i * 3.7) * TAU, d = (10 + 44 * hash(i * 1.3)) * (1 - Math.exp(-age / 0.1)) * s; fire.smokePuff(p, c.x + Math.cos(a) * d - fw.x * d * 0.3, c.y + Math.sin(a) * d - fw.y * d * 0.3, k, 8 * s, H[5], true, 0.9); }
    p.glow(c.x, c.y, 26 * s, H[2], 0.8 * k * R.P.intensity); fire.solid(p, c.x, c.y, 7 * s * k, H[0]); }
}
function dDarkFall(S, R, q) { // 着弾点：闇の染みが広がってから縮む。縮みきる直前に矢が真上から刺さる
  const age = S.t - q.t - q.wait, warn = q.warn, k = clamp(age / warn), p = R.back, H = D_DARK, c = toL(q.at), s = R.P.size, rr = S.r.radius * WL * s * lerp(1.8, 0.8, smooth(0, 1, k)), t = S.t, on = smooth(0, 0.14, age);
  p.each(c.x - rr * 1.3, c.y - rr * 1.3, c.x + rr * 1.3, c.y + rr * 1.3, (x, y, sx, sy) => { const dx = x - c.x, dy = y - c.y, d = Math.hypot(dx, dy) / rr; if (d > 1.3) return; const edge = 1 + 0.2 * PX.tileFbm(Math.atan2(dy, dx) * 2 + 7, t * 2.4, 0, 0, 17, 2), e = d / edge; if (e > 1.06) return; if (e > 0.93) p.blendPx(sx, sy, H[2], 0.9 * on * (1.06 - e) / 0.13); else p.blendPx(sx, sy, H[e < 0.6 ? 7 : 6], (0.62 + 0.3 * k) * on); });
  const drop = clamp((age - (warn - 0.14)) / 0.14); if (drop > 0) dDarkShot(R, { pos: add(q.at, V(0, -900 * (1 - drop))), t: q.t }, age, V(0, 1));
}
function dDarkBlast(S, R, at, age, radius, seed, H = D_DARK) {
  if (age < 0 || age > 1) return; const fire = PIXELFX.fx['src/fx/fire/_lib.js'], p = R.front, c = toL(at), rr = radius * WL * R.P.size * 1.3, flash = 1 - smooth(0, 0.14, age);
  if (flash > 0) { p.glow(c.x, c.y, rr * 2, H[2], 0.6 * flash * R.P.intensity); fire.solid(p, c.x, c.y, rr * (0.15 + 0.22 * smooth(0, 0.1, age)) * flash, H[0]); }
  for (let i = 0; i < 46; i++) { const rnd = k => hash(i * 5.3 + k * 2.1 + seed), life = lerp(0.35, 0.75, rnd(1)); if (age > life) continue; const a = rnd(2) * TAU, d = rr * lerp(0.5, 1.25, rnd(3)) * (1 - Math.exp(-age / 0.13)), x = c.x + Math.cos(a) * d, y = c.y + Math.sin(a) * d, k = 1 - age / life; fire.firePuff(p, x, y, k, Math.min(rr * lerp(0.18, 0.36, rnd(4)), 11 * R.P.size), rnd(5), H, 0.06, Math.cos(a) * 0.7, Math.sin(a) * 0.7); }
  for (let i = 0; i < 14; i++) { const rnd = k => hash(i * 9.1 + k * 3.7 + seed), life = lerp(0.6, 1, rnd(1)); if (age > life) continue; const a = rnd(2) * TAU, d = rr * 1.2 * (1 - Math.exp(-age / 0.22)); fire.smokePuff(p, c.x + Math.cos(a) * d, c.y + Math.sin(a) * d, 1 - age / life, rr * 0.4, H[5], true, 0.8); }
}
// 飛ぶ隕石：大気を焼くように進行方向の前が白熱し、後ろへ炎の塊が長くちぎれて流れ、煙に冷える。炎は通った場所に残って後ろから消える
function dRockTrail(S, R, b, age, dir, stop) {
  const fire = PIXELFX.fx['src/fx/fire/_lib.js'], p = R.back, H = D_FLAME, s = R.P.size, flying = Math.min(age, stop), head = add(b.from, mul(dir, b.speed * flying)), rad = b.radius * WL * s, rate = 90, side = orth(dir), aw = Math.atan2(dir.y, dir.x);
  for (let i = Math.max(0, Math.floor((age - 0.75) * rate)); i / rate <= flying; i++) { const tb = i / rate, a = age - tb, rnd = k => hash(i * 6.13 + k * 2.71 + b.seed * 3), life = lerp(0.28, 0.55, rnd(1)), smokeLife = life + 0.3; if (a > smokeLife) continue; const off = (rnd(2) - 0.5) * b.radius * (1.5 + a * 3), at = toL(add(add(b.from, mul(dir, b.speed * tb - b.radius * 0.5 - a * 60)), mul(side, off)));
    if (a > life) fire.smokePuff(p, at.x, at.y, 1 - (a - life) / 0.3, rad * 0.45, H[7], true, 0.7); else fire.firePuff(p, at.x, at.y, 1 - a / life, rad * lerp(0.3, 0.62, rnd(3)), rnd(4), H, 0.05, -dir.x * 0.8, -dir.y * 0.8); }
  if (age < stop) { const c = toL(head), on = smooth(0, 0.05, age); fire.soft(p, c.x, c.y, rad * 1.7, H[4], 0.4 * on); fire.soft(p, c.x + dir.x * rad * 0.35, c.y + dir.y * rad * 0.35, rad * 1.25, H[2], 0.55 * on); p.glow(c.x, c.y, rad * 2.8, H[3], 0.6 * on * R.P.intensity); }
}
// 星弾のため：空に星が生まれてふくらみ、光の芯が脈打つ
function dStarCharge(S, R, q, i, k) {
  if (k <= 0) return; const fire = PIXELFX.fx['src/fx/fire/_lib.js'], p = R.front, H = D_FLAME, s = R.P.size, c = toL(q.pos), rad = (1.5 + 3.5 * k) * s * (1 + 0.08 * Math.sin(S.t * 22 + i));
  fire.soft(p, c.x, c.y, rad * 2, H[6], 0.3 * k); fire.solid(p, c.x, c.y, rad, H[4]); fire.solid(p, c.x, c.y, rad * 0.5, H[1]); p.glow(c.x, c.y, rad * 2.2, H[5], 0.3 * k * R.P.intensity); dStar(R, c, (3 + 5 * k) * s, S.t * 2 + i, k * 0.8, dRamp(R));
}
// 星弾を放つ口元：光が前へ扇に吹き出す
function dStarBlast(S, R, pose) {
  const at = S.shotTimes && S.shotTimes[0]; if (at == null) return; const age = S.t - at; if (age < 0 || age > 0.35) return; const k = 1 - age / 0.35, c = toL(pose.mouth), s = R.P.size; R.front.glow(c.x, c.y, 11 * s, D_FLAME[4], 0.55 * k * R.P.intensity); R.front.disc(c.x, c.y, 2.5 * s * k, D_FLAME[1], 1);
}
function dStarDim(S) { if (S.tech !== 'star_fan') return; const r = S.r, on = S.B.mode === 'windup' ? 0.5 * smooth(0.1, 1, S.elapsed / r.warn) : S.B.mode === 'active' ? 0.5 : S.B.mode === 'recovery' ? 0.5 * (1 - smooth(0.1, 0.8, S.elapsed / r.recover)) : 0, flash = S.shotTimes.length ? Math.exp(-(S.t - S.shotTimes[0]) / 0.08) : 0; if (on <= 0 && flash < 0.01) return; g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.fillStyle = `rgba(4,2,12,${on})`; g.fillRect(0, 0, W, H); if (flash > 0.01) { g.fillStyle = `rgba(190,170,255,${flash * 0.12})`; g.fillRect(0, 0, W, H); } g.restore(); }
// 尻尾の薙ぎ払い：尾の先と胴の後ろが通った跡に、光の帯が太く残って後ろから消える。地面の土ぼこりが帯に沿って立つ
function dSweepWake(S, R, pose) {
  if (S.tech !== 'tail_sweep' || !S.wake) return; const life = 0.6, list = S.wake.filter(q => S.t - q.t < life); if (list.length < 3) return; const H = D_FLAME, p = R.back, ramp = v => { const q = lerp(7, 1, clamp(v)), i = Math.min(6, Math.floor(q)); return PX.mix(H[i], H[i + 1], q - i); };
  for (let i = 1; i < list.length; i++) { const q0 = list[i - 1], q1 = list[i], f = (S.t - q1.t) / life, A0 = toL(q0.a), A1 = toL(q1.a), B0 = toL(q0.b), B1 = toL(q1.b), steps = Math.ceil(Math.max(dist(A0, A1), dist(B0, B1)) * 2 + 1), span = Math.ceil(dist(A1, B1) * 2 + 1);
    for (let n = 0; n <= steps; n++) { const u = n / steps, A = lerpV(A0, A1, u), B = lerpV(B0, B1, u); for (let m = 0; m <= span; m++) { const v = m / span, heat = Math.pow(1 - v, 1.5) * (1 - f), at = lerpV(A, B, v); if (heat > 0.03) p.blend(at.x, at.y, ramp(heat * 1.35), Math.min(0.85, heat * 1.1)); } } }
  const tip = list[list.length - 1]; R.front.glow(toL(tip.a).x, toL(tip.a).y, 16 * R.P.size, H[3], 0.8 * R.P.intensity);
}
// 星：白い芯と4本の光条。回りながらまたたく
function dStar(R, c, size, spin, a, pal) {
  if (a <= 0.02) return; R.front.px(c.x, c.y, pal[4]);
  for (let j = 0; j < 4; j++) { const an = spin + j * Math.PI / 2, L = size * (j % 2 ? 0.7 : 1); for (let d = 0.5; d <= L; d += 0.5) R.front.light(c.x + Math.cos(an) * d, c.y + Math.sin(an) * d, pal[d < L * 0.4 ? 4 : 3], a * (1 - d / (L + 0.5))); }
  R.front.glow(c.x, c.y, size * 1.4, pal[2], 0.35 * a * R.P.intensity);
}
// 星のブレス（pixelFX fire/fire-breath の作りを上から見た形へ）：炎の塊が口から吹き出され、減速しながらふくらんで紫へ冷え、煙になる。
// 首を振っても塊は吹いた向きへ少し残るので、炎は手前から奥へしなる。隕石の裏には届かない。
const D_FLAME = ['#ffffff', '#fbf4ff', '#e6d8ff', '#c9b0ff', '#a884ff', '#8259ee', '#5f3cc8', '#412a94', '#291c62'].map(hexc);
function dBreathFx(S, R) {
  if (!S.fan || S.B.mode !== 'active') return; const fire = PIXELFX.fx['src/fx/fire/_lib.js'], p = R.front, r = S.r, e = S.elapsed, H = D_FLAME, NL = fire.noiseFor(1.5), N = (rate, seed = 0, off = 0) => NL(e, rate, seed, off), s = R.P.size;
  const O = toL(S.fan[0]), Lmax = r.reach * WL * s, hw = r.half_angle * 1.15, n = S.fan.length - 1, angleAt = tb => S.axis + lerp(-r.sweep, r.sweep, smooth(0, 1, tb / r.active)), v0 = Lmax * 2.3, drag = 2, stopE = r.active - 0.2, rate = 340, live = [], smoke = [];
  const limit = (lat) => dist(S.fan[0], S.fan[1 + Math.min(n - 1, Math.max(0, Math.round((lat * 0.5 + 0.5) * (n - 1))))]) * WL * s;
  for (let i = Math.max(0, Math.floor((e - 1.7) * rate)); i / rate < Math.min(e, stopE); i++) { const tb = i / rate, age = e - tb, rnd = k => hash(i * 7.31 + k * 3.17), lat = rnd(1) * 2 - 1, fl = lerp(0.6, 1.1, rnd(2)) * (1 - 0.3 * Math.abs(lat)), sm = rnd(3) < 0.25 + 0.4 * Math.abs(lat), sl = lerp(0.3, 0.5, rnd(4));
    if (age > fl + (sm ? sl : 0)) continue; const way = e > 0 ? angDiff(angleAt(tb), S.fanAngle) : 0, a = S.fanAngle + clamp(way, -hw * 0.75, hw * 0.75) + lat * hw * (0.55 + 0.45 * smooth(0, 0.25, age)), d0 = v0 * lerp(0.75, 1.1, rnd(5)) / drag * (1 - Math.exp(-drag * age)), lim = limit(clamp(angDiff(a, S.fanAngle) / r.half_angle, -1, 1)), d = d0; if (d > lim - 8 * s) continue;
    const ux = Math.cos(a), uy = Math.sin(a), q = { age, x: O.x + ux * d + (rnd(8) - 0.5) * d * 0.05, y: O.y + uy * d + (rnd(9) - 0.5) * d * 0.05, ux, uy, lat, fl, sl, sm, size: lerp(4, 11, rnd(6) ** 1.6) * s, f: rnd(7) };
    if (age < q.fl) live.push(q); else if (sm && age < q.fl + sl) smoke.push(q); }
  for (const q of smoke) fire.smokePuff(p, q.x, q.y, 1 - (q.age - q.fl) / q.sl, q.size * 1.1, H[7], true, 0.4);
  live.sort((x, y) => y.age - x.age);
  for (const q of live) { const u = q.age / q.fl; fire.soft(p, q.x, q.y, q.size * (1.4 + 2.2 * u), H[u < 0.5 ? 4 : 6], 0.1 * (1 - u * 0.6)); }
  for (const q of live) { const u = q.age / q.fl, edge = Math.abs(q.lat), size = q.size * (0.7 + 2 * u), heat = Math.min(0.999, Math.pow(u, 0.9) * (0.8 + 0.2 * edge) + 0.32 * edge * edge), tear = clamp((u - 0.3) / 0.2);
    fire.firePuff(p, q.x, q.y, 1 - heat, size * (1 - 0.45 * tear), q.f, H, 0.04, -q.ux * 0.8, -q.uy * 0.8);
    if (tear > 0 && q.f < 0.35) { const id = Math.floor(q.f * 1e5), len = size * (1.2 + 0.5 * N(4, id)) * tear, sway = N(2.5, id + 1) * 0.5 + q.lat * 0.5, cs = Math.cos(sway), sn = Math.sin(sway); fire.flameBlade(p, q.x, q.y, q.ux * cs - q.uy * sn, q.uy * cs + q.ux * sn, len, Math.min(4, size * 0.2), N(2.5, id + 2) * 2, N, id, H, heat < 0.5 ? fire.BACK_LAYERS : [[1, 1, 7], [0.72, 0.82, 6], [0.44, 0.58, 5]]); } }
  const roar = 0.85 + 0.15 * N(3, 7), on = 1 - smooth(stopE - 0.12, stopE, e), ca = Math.cos(S.fanAngle), sa = Math.sin(S.fanAngle);
  if (on > 0) { for (let i = 0; i < 4; i++) { const off = [0, -0.1, 0.1, 0][i], L = [30, 23, 23, 15][i] * s * roar * on, w = [3.6, 3.2, 3.2, 4][i] * s; fire.flameBlade(p, O.x, O.y, Math.cos(S.fanAngle + off), Math.sin(S.fanAngle + off), L, w, N(3, i + 3) * 3, N, 30 + i * 17, H, fire.LAYERS, 0.5, 1.5); } p.glow(O.x, O.y, 7 * s, H[3], 0.5 * on * R.P.intensity); }
  for (let i = 0; i < 16; i++) { const j = 1 + Math.floor(hash(i * 4.3) * n), dir = norm(sub(S.fan[j], S.fan[0])), reach = dist(S.fan[0], S.fan[j]), at = (e * 1100 + hash(i * 6.6) * 1500) % reach; dStar(R, toL(add(S.fan[0], mul(dir, at))), 1.4, e * 6 + i, on * 0.65, FX.ramp(R.P.color)); }
}
// ためた光が口から強く広がり、隕石の裏に本物の影が落ちる。首を振っても炎が届かない場所だけが影になり、線では囲まない
function dLightMask(S) {
  if (S.lightMask) return S.lightMask; const r = S.r, rays = 9, mouths = Array.from({ length: rays }, (_, i) => add(S.B.pos, mul(fromA(S.axis - r.sweep + 2 * r.sweep * i / (rays - 1)), 120 * DP.head_scale))), hit = (m, p) => S.rocks.some(q => { const d = sub(p, m), f = sub(q.to, m), l2 = d.x * d.x + d.y * d.y, u = clamp((f.x * d.x + f.y * d.y) / l2); return u > 0 && u < 1 && dist(add(m, mul(d, u)), q.to) < q.radius * 0.97 && dist(p, q.to) > q.radius; }), base = S.camBase || cam, far = r.reach, wide = r.sweep + r.half_angle; let v = new Float32Array(LW * LH);
  for (let y = 0; y < LH; y++) for (let x = 0; x < LW; x++) { const p = V((x - LW / 2) / WL + base.x, (y - LH / 2) / WL + base.y), off = sub(p, S.mouth), d = len(off); if (d > far) continue; const ang = Math.abs(angDiff(angOf(off), S.axis)), inside = 1 - smooth(wide * 0.8, wide * 1.1, ang); if (inside <= 0) continue; const seen = mouths.reduce((n, m) => n + (hit(m, p) ? 0 : 1), 0) / rays; v[y * LW + x] = Math.pow(1 - d / far, 1.2) * inside * seen; } // 首の振りのどの位置から見えるかの割合で影の境目がぼやける
  for (let pass = 0; pass < 3; pass++) { const o = new Float32Array(LW * LH), R3 = 3; for (let y = 0; y < LH; y++) for (let x = 0; x < LW; x++) { let n = 0, s = 0; for (let k = -R3; k <= R3; k++) { const c = x + k; if (c >= 0 && c < LW) { s += v[y * LW + c]; n++; } } o[y * LW + x] = s / n; } const q = new Float32Array(LW * LH); for (let y = 0; y < LH; y++) for (let x = 0; x < LW; x++) { let n = 0, s = 0; for (let k = -R3; k <= R3; k++) { const c = y + k; if (c >= 0 && c < LH) { s += o[c * LW + x]; n++; } } q[y * LW + x] = s / n; } v = q; }
  const list = []; for (let y = 0; y < LH; y++) for (let x = 0; x < LW; x++) { const f = v[y * LW + x]; if (f > 0.008) list.push({ x, y, fall: f }); }
  return (S.lightMask = list);
}
function dSafeFx(S, R, pose) {
  if (S.tech !== 'breath' || !S.rocks.length) return; const r = S.r, last = 1.6 * 0.62 + DR_FLIGHT, charge = S.B.mode === 'windup' ? smooth(last, r.warn - 0.1, S.elapsed) : S.B.mode === 'active' ? 1 - smooth(0.2, r.active, S.elapsed) * 0.55 : 0; if (charge <= 0) return;
  const H = D_FLAME, p = R.back, ox = (cam.x - (S.camBase?.x ?? cam.x)) * WL, oy = (cam.y - (S.camBase?.y ?? cam.y)) * WL, pulse = 0.88 + 0.12 * Math.sin(S.t * 14), c = toL(pose.mouth); for (const q of dLightMask(S)) p.blend(q.x - ox, q.y - oy, H[4], 0.5 * q.fall * charge * pulse);
  if (S.B.mode === 'windup') { R.front.glow(c.x, c.y, 34 * R.P.size, H[3], 0.85 * charge * R.P.intensity); R.front.disc(c.x, c.y, 4 * R.P.size * charge, H[0], 1); }
}
// 炎に耐える隕石：当たっている間にひびが広がって熱を持ち、欠片がこぼれて震える。ブレスが終わると耐えきれず砕ける（破片は演出で、当たりはない）
function dRockHeat(S, q) { return clamp((q.burn || 0) / (S.r.active * 0.28)); }
function dMeteorDraw(S, R, q, i) {
  if (q.born == null) return; const age = S.t - q.born, on = smooth(0, 0.12, age); drawImg('meteor_0', q.pos, q.seed * 1.7 + age * 1.9, q.radius * (0.6 + 0.4 * on)); if (!R.proto) return;
  const H = D_FLAME, c = toL(q.pos), rr = q.radius * WL * R.P.size, u = q.dir, flick = 0.8 + 0.2 * Math.sin(S.t * 17 + i);
  for (const k of aqCracks(61 + i * 7, rr * 0.92)) for (const [x, y] of k.pts) R.front.blend(c.x + x, c.y + y, H[3], 0.55 * flick * on);
  for (let n = 0; n <= 40; n++) { const a = -1.25 + 2.5 * n / 40, e = 1 - Math.abs(a) / 1.25, x = c.x + Math.cos(Math.atan2(u.y, u.x) + a) * rr * 1.04, y = c.y + Math.sin(Math.atan2(u.y, u.x) + a) * rr * 1.04; R.front.blend(x, y, H[1], e * 0.95 * on); R.front.blend(x + u.x, y + u.y, H[3], e * 0.6 * on); }
  R.front.glow(c.x + u.x * rr * 0.7, c.y + u.y * rr * 0.7, rr * 1.2, H[4], 0.45 * on * R.P.intensity);
}
// 飛ぶ隕石：通った道に尾が伸び、前で焼けた炎が後ろへ流れて冷え、煙と火の粉になる。遅くても勢いが見えるよう、尾の中を炎が走る
function dMeteorTrail(S, R, q, age, i, speed = DM.speed, gone = 0) {
  const fire = PIXELFX.fx['src/fx/fire/_lib.js'], p = R.back, H = D_FLAME, s = R.P.size, u = q.dir, nx = -u.y, ny = u.x, c = toL(q.pos), rad = q.radius * WL * s, L = Math.min(age * speed, 760) * WL * s * (1 - gone), seed = i * 13.7 + 3; if (L < 2) return; age += gone;
  for (let d = 0; d < L; d += 0.75) { const f = d / L, w = rad * 1.05 * Math.pow(1 - f, 0.75) * (1 + 0.12 * Math.sin(d * 0.14 - age * 9 + seed)); for (let o = -w; o <= w; o += 0.75) { const e = Math.abs(o) / Math.max(1, w), heat = clamp((1 - f) * (1.15 - e) * (0.75 + 0.5 * (0.5 + 0.5 * PX.tileNoise(d * 0.05 - age * 5, o * 0.12 + seed, 0, 0, 5)))); if (heat > 0.05) p.blend(c.x - u.x * d + nx * o, c.y - u.y * d + ny * o, H[Math.min(7, Math.round(lerp(7, 3, heat)))], Math.min(0.85, heat * 1.15)); } }
  for (let n = 0; n < 12; n++) { const h = k => hash(n * 7.31 + k * 3.17 + seed), ph = (age * lerp(0.35, 0.6, h(1)) + h(2)) % 1, d = L * (0.55 + 0.6 * ph), lat = (h(3) - 0.5) * rad * (1.4 + ph * 1.6); fire.smokePuff(p, c.x - u.x * d + nx * lat, c.y - u.y * d + ny * lat, 1 - ph, rad * 0.4, H[7], true, 0.5); }
  for (let n = 0; n < 34; n++) { const h = k => hash(n * 4.19 + k * 2.71 + seed), ph = (age * lerp(0.9, 1.6, h(1)) + h(2)) % 1, d = ph * L * 0.8 + rad * 0.2, lat = (h(3) - 0.5) * rad * 1.7 * (1 - ph * 0.5) + Math.sin(ph * 7 + n) * rad * 0.12; fire.firePuff(p, c.x - u.x * d + nx * lat, c.y - u.y * d + ny * lat, 1 - ph, rad * lerp(0.14, 0.32, h(4)) * (1 - 0.35 * ph), h(5), H, 0.03, -u.x * 0.8, -u.y * 0.8); }
  for (let n = 0; n < 18; n++) { const h = k => hash(n * 9.13 + k * 1.9 + seed), ph = (age * lerp(0.7, 1.3, h(1)) + h(2)) % 1, d = ph * L * 1.1, lat = (h(3) - 0.5) * rad * (2 + 3 * ph); R.front.blend(c.x - u.x * d + nx * lat, c.y - u.y * d + ny * lat, H[n % 2 ? 1 : 3], 1 - ph); }
}
function dRockDraw(S, R, rock, i) {
  if (S.tech === 'meteor') return dMeteorDraw(S, R, rock, i);
  const age = dRockAge(S, i); if (age < 0 || (rock.breakAt && S.t >= rock.breakAt)) return; const land = age - DR_FLIGHT, thud = land > 0 ? Math.exp(-land / 0.09) * Math.sin(Math.min(land, 0.3) * 30) : 0, k = dRockHeat(S, rock), shake = 5 * k * k, pos = add(rock.pos, V(Math.sin(S.t * 71 + i) * shake, Math.cos(S.t * 83 + i) * shake)), size = rock.radius * (1 + 0.08 * thud) * (1 - 0.1 * k);
  drawImg('meteor_0', pos, rock.seed * 1.7 + Math.min(age, DR_FLIGHT) * 11 + Math.max(0, thud) * 0.12, size);
  if (!R.proto || k <= 0) return; const pal = dRamp(R), c = toL(pos), rr = size * WL * R.P.size, cracks = aqCracks(61 + i * 7, rr);
  for (const q of cracks) { const show = Math.ceil(q.pts.length * k); for (let m = 0; m < show; m++) { const [x, y] = q.pts[m], h = k * (1 - 0.5 * m / q.pts.length); R.front.blend(c.x + x, c.y + y, pal[h > 0.6 ? 4 : 3], Math.min(1, 0.45 + h * 0.7)); } }
  R.front.glow(c.x, c.y, rr * 0.8, pal[2], 0.3 * k * R.P.intensity);
  for (let m = 0; m < 16; m++) { const th = m / 16; if (k <= th) continue; const life = 0.5, ph = (rock.burn - th * S.r.active * 0.28) / life; if (ph >= 1) continue; const a = hash(m * 3.7 + i) * TAU, d = rr * (0.85 + 0.9 * (1 - Math.exp(-ph * 2.2))), x = c.x + Math.cos(a) * d, y = c.y + Math.sin(a) * d; R.front.blend(x, y, H_STONE[m % 2 ? 3 : 4], 1 - ph); R.front.blend(x + 1, y, H_STONE[3], (1 - ph) * 0.8); }
}
function dRockBreak(S, R, rock, i) {
  if (!rock.breakAt || S.t < rock.breakAt) return; const t = S.t - rock.breakAt; if (t > 1.1) return; const seed = 91 + i * 5;
  for (let m = 0; m < 14; m++) { const rnd = k => hash(m * 7.3 + k * 3.1 + seed), life = lerp(0.45, 0.85, rnd(1)); if (t > life) continue; const a = rnd(2) * TAU, d = rock.radius * (0.2 + lerp(0.9, 1.9, rnd(3)) * (1 - Math.exp(-t / 0.16))), f = t / life; drawImg('meteor_0', add(rock.pos, mul(fromA(a), d)), rnd(4) * 6 + t * lerp(-5, 5, rnd(5)), rock.radius * lerp(0.14, 0.36, rnd(6)) * (1 - f * 0.3), 1 - f * f); }
  if (R.proto) dImpactFx(S, R, rock.pos, t, rock.radius * 1.1, seed);
}
// 空間の裂け目：予兆は細いひび。爪が通ると端から一気に裂け、裂け目の奥に次元の狭間がのぞき、まわりの景色が押しのけられて歪む。
// 閉じるときは破ったときの逆再生で、裂けた先から裂き始めへ戻りながらくっつく。
function dRiftAge(S, q) { return S.t - q.fireT; }
function dRiftSpan(q, age) { const open = dBurst(age / DS.open), close = smooth(0, 1, (age - q.hold) / DS.close); return { tip: open * (1 - close), closing: close > 0 && close < 1, life: age < q.hold + DS.close }; }
function dRiftFx(S, R) {
  const pal = dRamp(R), p = R.front;
  for (const q of S.rifts || []) { const age = dRiftAge(S, q), A = toL(q.a), B = toL(q.b), L = dist(A, B); if (L < 1) continue; const u = norm(sub(B, A)), n = orth(u);
    if (age < 0) { const k = clamp(1 + age / DS.tell); if (k <= 0) continue; for (let d = 0; d < L; d += 0.5) { const f = d / L; if (Math.abs(f - 0.5) * 2 > 0.25 + 0.75 * k) continue; const j = (hash(q.seed * 3 + Math.floor(d / 4)) - 0.5) * 3 * k * Math.sin(Math.PI * f); p.blend(A.x + u.x * d + n.x * j, A.y + u.y * d + n.y * j, pal[k > 0.7 ? 3 : 2], (0.3 + 0.6 * k) * (0.7 + 0.3 * Math.sin(S.t * 40 + d * 0.3))); } continue; }
    const sp = dRiftSpan(q, age); if (!sp.life) continue; const tx = A.x + u.x * L * sp.tip, ty = A.y + u.y * L * sp.tip;
    if (age < DS.open + 0.05 || sp.closing) { p.glow(tx, ty, 11 * R.P.size, pal[3], 0.9 * R.P.intensity); p.disc(tx, ty, 2.2 * R.P.size, PX.WHITE, 1); for (let m = 0; m < 10; m++) { const a = hash(m * 3.3 + q.seed + Math.floor(S.t * 30)) * TAU, d = (3 + 16 * hash(m * 7.1 + Math.floor(S.t * 24))) * R.P.size; p.blend(tx + Math.cos(a) * d, ty + Math.sin(a) * d, pal[4], 0.9); } } }
}
const D_GAP = { deep: [6, 3, 16], mid: [38, 18, 92], pink: [255, 110, 214], cyan: [120, 226, 255] };
let dWarp = null;
function dRiftPost(S, R) {
  const list = (S.rifts || []).filter(q => { const age = dRiftAge(S, q); return age >= 0 && dRiftSpan(q, age).life; }); if (!list.length) return;
  dWarp ||= (() => { const mk = () => { const c = document.createElement('canvas'); c.width = LW; c.height = LH; return { c, x: c.getContext('2d', { willReadFrequently: true }) }; }; return { from: mk(), to: mk() }; })();
  const { from, to } = dWarp; from.x.imageSmoothingEnabled = false; from.x.drawImage(g.canvas, 0, 0, LW, LH); const src = from.x.getImageData(0, 0, LW, LH).data, img = to.x.createImageData(LW, LH), out = img.data, t = S.t, band = 34 * R.P.size;
  for (const q of list) { const age = dRiftAge(S, q), sp = dRiftSpan(q, age), A = toL(q.a), B = toL(q.b), L = dist(A, B), ux = (B.x - A.x) / L, uy = (B.y - A.y) / L, nx = -uy, ny = ux, wide = q.w * WL * R.P.size, tipS = L * sp.tip, tear = s => (hash(Math.floor(s / 5) * 1.7 + q.seed) * 2 - 1) * 0.3 + (s % 5) / 5 * 0.16;
    const widthAt = (s, side) => { const f = s / L, lens = Math.pow(Math.sin(Math.PI * clamp(f)), 0.55), mouth = smooth(0, Math.max(8, tipS * 0.35), tipS - s); return wide * lens * mouth * (1 + tear(s + side * 13)); };
    const x0 = Math.max(0, Math.floor(Math.min(A.x, B.x) - band - wide)), x1 = Math.min(LW - 1, Math.ceil(Math.max(A.x, B.x) + band + wide)), y0 = Math.max(0, Math.floor(Math.min(A.y, B.y) - band - wide)), y1 = Math.min(LH - 1, Math.ceil(Math.max(A.y, B.y) + band + wide));
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) { const dx = x - A.x, dy = y - A.y, al = dx * ux + dy * uy, lat = dx * nx + dy * ny; if (al < 0 || al > tipS + band * 0.6 || Math.abs(lat) > band + wide * 1.3) continue;
      const s = Math.min(al, L), up = al <= tipS ? widthAt(s, 1) : 0, dn = al <= tipS ? widthAt(s, -1) : 0, k = (y * LW + x) * 4;
      if (al <= tipS && lat < up && lat > -dn) { const edge = Math.min(up - lat, lat + dn), depth = 1 - Math.abs(lat) / Math.max(1, lat > 0 ? up : dn);
        if (edge < 1) { out[k] = 255; out[k + 1] = 244; out[k + 2] = 255; out[k + 3] = 255; continue; } if (edge < 2.2) { out[k] = 196; out[k + 1] = 150; out[k + 2] = 255; out[k + 3] = 255; continue; }
        const n1 = 0.5 + 0.5 * PX.tileFbm(al * 0.035 + t * 0.35, lat * 0.09 - t * 0.9 + q.seed, 0, 0, 13, 3), n2 = 0.5 + 0.5 * PX.tileFbm(al * 0.07 - t * 0.6, lat * 0.16 + t * 0.5, 0, 0, 29, 2), core = smooth(0.35, 1, depth), mixK = smooth(0.35, 0.8, n1) * (1 - core * 0.55), col = n2 > 0.5 ? D_GAP.pink : D_GAP.cyan, glowK = smooth(0.62, 0.92, n1) * 0.7 * (1 - core * 0.6);
        let c0 = D_GAP.deep[0] + (D_GAP.mid[0] - D_GAP.deep[0]) * mixK, c1 = D_GAP.deep[1] + (D_GAP.mid[1] - D_GAP.deep[1]) * mixK, c2 = D_GAP.deep[2] + (D_GAP.mid[2] - D_GAP.deep[2]) * mixK; c0 += (col[0] - c0) * glowK; c1 += (col[1] - c1) * glowK; c2 += (col[2] - c2) * glowK;
        const star = hash(Math.floor(al * 0.9 - t * 26 * (1 + (Math.floor(lat) & 1))) * 7.1 + Math.floor(lat) * 13.3 + q.seed); if (star > 0.985) { c0 = 255; c1 = 255; c2 = 255; }
        out[k] = c0; out[k + 1] = c1; out[k + 2] = c2; out[k + 3] = 255; continue; }
      const sign = lat >= 0 ? 1 : -1, gap = Math.abs(lat) - (lat >= 0 ? up : dn), fade = 1 - clamp(gap / band), end = clamp(Math.min(al, L - al) / 18), push = 9 * R.P.size * fade * fade * sp.tip * end * (1 - smooth(0, 1, (age - q.hold) / DS.close) * 0.5); if (push < 0.4 || out[k + 3]) continue;
      const wob = Math.sin(al * 0.12 + t * 7) * 1.4 * fade, sx = Math.round(x - nx * sign * push + ux * wob), sy = Math.round(y - ny * sign * push + uy * wob); if (sx < 0 || sy < 0 || sx >= LW || sy >= LH) continue; const f = (sy * LW + sx) * 4; out[k] = src[f]; out[k + 1] = src[f + 1]; out[k + 2] = src[f + 2]; out[k + 3] = 255; } }
  to.x.putImageData(img, 0, 0); g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.imageSmoothingEnabled = false; g.drawImage(to.c, 0, 0, W, H); g.restore();
}
for (const d of DEMOS) if (d.id === 'D-rifts') d.post = dRiftPost;
// 吸い込み：まわりの光の筋と星屑が、口へ向かって流れながら細く伸びる
function dInhaleFx(S, R) {
  const r = S.r; if (S.tech !== 'inhale' || S.B.mode !== 'active' || S.elapsed >= r.inhale_time) return; const pal = dRamp(R), mouth = dMouth(S), k = smooth(0, 0.4, S.elapsed) * (1 - smooth(r.inhale_time - 0.3, r.inhale_time, S.elapsed));
  for (let i = 0; i < 90; i++) { const ph = (hash(i * 17) + S.t * (0.45 + 0.6 * hash(i))) % 1, an = hash(i * 31) * TAU + ph * 2.6, rad = r.pull_range * 0.6 * (1 - ph) ** 1.3, sl = 20 + 70 * ph, head = add(mouth, mul(fromA(an), rad));
    for (let s = 0; s < sl; s += 0.5 / WL) { const q = toL(add(head, mul(fromA(an - 0.9 - (s / sl) * 1.1), s))), b = (1 - s / sl) * ph * k; if (b < 0.06) continue; R.back.blend(q.x, q.y, pal[b > 0.55 ? 3 : 2], Math.min(0.7, b * 0.85)); }
    if (i % 9 === 0) dStar(R, toL(head), 1 + ph * 2, S.t * 4 + i, k * ph, pal); }
  const m = toL(mouth); R.front.glow(m.x, m.y, 8 * R.P.size, pal[3], 0.5 * k * R.P.intensity);
}
// 吐き出し：溜めた星を一気に吐く太い光の奔流。縁はまっすぐで、白い芯から紫へなめらかに冷え、外側へ広い光がにじむ。中を星屑が走り、口元で炎が暴れる
const D_NEB = { pink: hexc('#ff5fd2'), cyan: hexc('#58d8ff'), violet: hexc('#8a5cff') };
function dExhaleLife(S) { // 0：吐いていない、1：全力。吐き始めの瞬間は1を超える
  const e = S.exhale; if (!e || S.B.mode !== 'active') return 0; const r = S.r, age = S.t - e.t - r.beam_warn; if (age < 0) return 0; return smooth(0, 0.08, age) * (1 - smooth(r.active - 0.45, r.active, S.elapsed)) * (1 + 0.5 * Math.exp(-age / 0.16));
}
function dExhaleFx(S, R) {
  if (!S.exhale || S.B.mode !== 'active') return; const r = S.r, e = S.exhale, age = S.t - e.t, s = R.P.size;
  if (age < r.beam_warn) { const k = clamp(age / r.beam_warn), end = add(e.at, mul(fromA(e.a), r.reach)); bossGather(R, e.at, 150, k, S.t, 21); FX.warnRail(R.front, toL(e.at), toL(end), { color: R.P.color, k, time: S.t, seed: 5, maxLv: 2, intensity: R.P.intensity }); return; }
  const life = dExhaleLife(S); if (life <= 0) return; const p = R.front, H = D_FLAME, t = S.t, a0 = e.a, ux = Math.cos(a0), uy = Math.sin(a0), O = toL(e.at), beamAge = age - r.beam_warn, L = r.reach * WL * s * dBurst(beamAge / r.beam_extend), hw = r.width * 0.5 * WL * s * life, halo = hw * 3.2, X = [O.x - ux * 8, O.x + ux * L], Y = [O.y - uy * 8, O.y + uy * L], pad = halo + 6, pink = D_NEB.pink, cyan = D_NEB.cyan, pulses = [0, 1, 2].map(i => ((t * 1.1 + i / 3) % 1) * L);
  p.each(Math.min(...X) - pad, Math.min(...Y) - pad, Math.max(...X) + pad, Math.max(...Y) + pad, (x, y, sx, sy) => {
    const dx = x - O.x, dy = y - O.y, along = dx * ux + dy * uy, lat = dy * ux - dx * uy, abs = Math.abs(lat); if (abs > halo * 1.4 || along < -8 || along > L + 8) return;
    let node = 0; for (const c of pulses) node = Math.max(node, Math.exp(-(((along - c) / 16) ** 2)));
    const w = hw * lerp(0.55, 1, smooth(-4, 34, along)) * (1 + 0.14 * Math.sin(along * 0.075 - t * 24) + 0.08 * Math.sin(along * 0.17 - t * 37 + 1) + 0.42 * node), q = abs / w, tip = 1 - smooth(L - 8, L + 6, along), base = smooth(-8, 3, along) * tip, flow = 0.5 + 0.5 * PX.tileFbm(along * 0.02 - t * 7, lat * 0.1, 0, 0, 41, 3), hue = 0.5 + 0.5 * PX.tileFbm(along * 0.009 - t * 3.2, lat * 0.04 + 3, 0, 0, 17, 2), neb = PX.mix(pink, cyan, smooth(0.3, 0.7, hue));
    if (q > 1) { const g = clamp(1 - (abs - w) / (halo * (1 + 0.3 * flow) - w)); if (g > 0) p.blendPx(sx, sy, g > 0.55 ? neb : H[6], g * g * (0.62 + 0.25 * node) * base); }
    else { const core = clamp((1 - q * q) * (0.85 + 0.5 * flow) + node * 0.35); p.blendPx(sx, sy, core > 0.72 ? PX.mix(H[2], H[0], smooth(0.72, 0.95, core)) : core > 0.34 ? PX.mix(neb, H[2], smooth(0.34, 0.72, core)) : PX.mix(H[6], neb, smooth(0, 0.34, core)), base); }
    for (let k = 0; k < 2; k++) { const ph = along * 0.052 - t * 15 + k * Math.PI, yy = Math.sin(ph) * w * 1.18, d = Math.abs(lat - yy), front = 0.55 + 0.45 * Math.cos(ph); if (d < 2.2 * s) p.blendPx(sx, sy, k ? pink : cyan, (1 - d / (2.2 * s)) * (0.5 + 0.5 * front) * base); } });
  for (const c of pulses) { const at = V(O.x + ux * c, O.y + uy * c); p.glow(at.x, at.y, hw * 2.2, cyan, 0.3 * clamp(life) * R.P.intensity); }
  for (let i = 0; i < 34; i++) { const ph = (t * (0.9 + hash(i) * 1.3) + hash(i * 3.3)) % 1, along = ph * L, side = hash(i * 7.1) > 0.5 ? 1 : -1, off = side * hw * (1.25 + 1.9 * ph * hash(i * 5.1)) + Math.sin(along * 0.03 + i) * 5, on = Math.sin(Math.PI * ph) * clamp(life), c = V(O.x + ux * along - uy * off, O.y + uy * along + ux * off); if (i % 3 === 0) dStar(R, c, (3 + 6 * hash(i * 2.2)) * s, t * 4 + i, on, FX.ramp(hash(i) > 0.5 ? '#ff9ae6' : '#9fefff')); else p.blend(c.x, c.y, i % 2 ? pink : cyan, on); }
  const pal = dRamp(R), big = (24 + 5 * Math.sin(t * 19)) * s * Math.min(1.3, life); dStar(R, O, big, t * 1.4, clamp(life), pal); dStar(R, O, big * 0.7, -t * 2.1 + 0.6, clamp(life) * 0.8, FX.ramp('#9fefff')); p.glow(O.x, O.y, hw * 2.6, pink, 0.55 * clamp(life) * R.P.intensity); p.glow(O.x, O.y, hw * 1.3, H[0], 0.8 * clamp(life) * R.P.intensity);
}
// 吐いている間は画面を暗くして光を際立たせ、吐いた瞬間だけ強く光る
function dExhaleDim(S) {
  const life = dExhaleLife(S), e = S.exhale; if (!e || S.B.mode !== 'active') return; const r = S.r, age = S.t - e.t, dim = age < r.beam_warn ? 0.55 * smooth(0.1, r.beam_warn, age) : 0.62 * clamp(life) + 0.0, flash = age >= r.beam_warn ? Math.exp(-(age - r.beam_warn) / 0.07) : 0;
  g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.fillStyle = `rgba(4,2,12,${dim})`; g.fillRect(0, 0, W, H); if (flash > 0.01) { g.fillStyle = `rgba(190,170,255,${flash * 0.3})`; g.fillRect(0, 0, W, H); } g.restore();
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
// 彗星弾：渦巻く星雲の玉が、ねじれながら揺れる光のリボンと星屑を引く。リボンの表と裏で桃と水色が入れ替わる
function dCometShot(R, q, age, u, tail = 240, shine = 0.5) {
  const p = R.front, H = D_FLAME, s = R.P.size, on = smooth(0, 0.12, age), head = toL(q.pos), rad = q.radius * WL * 1.7 * s * on, L = Math.min(age * q.speed, tail * 1.5) * WL * s, nx = -u.y, ny = u.x, seed = q.t * 7 + q.a * 11, wave = d => Math.sin(d * 0.035 - age * 9 + seed) * (d / Math.max(1, L)) * rad * 2.2;
  for (let d = 0; d < L; d += 0.5) { const f = d / L, off = wave(d), tw = Math.sin(d * 0.085 - age * 15 + seed), w = rad * 1.05 * Math.pow(1 - f, 0.9) * (0.25 + 0.75 * Math.abs(tw)), c = tw > 0 ? D_NEB.pink : D_NEB.cyan, x = head.x - u.x * d + nx * off, y = head.y - u.y * d + ny * off; for (let o = -w; o <= w; o += 0.5) { const e = Math.abs(o) / Math.max(0.5, w); p.blend(x + nx * o, y + ny * o, e < 0.35 ? PX.mix(c, H[1], (1 - f) * 0.8) : c, (1 - f) * (1 - e * e) * 0.85 * on); } }
  for (let i = 0; i < 12; i++) { const ph = (age * (1.2 + hash(i + seed)) + hash(i * 3.3 + seed)) % 1, d = ph * L, off = wave(d) + (hash(i * 5.7 + seed) - 0.5) * rad * 3.4 * ph, x = head.x - u.x * d + nx * off, y = head.y - u.y * d + ny * off; if (i % 3 === 0) dStar(R, V(x, y), 2.4 * s, age * 7 + i, (1 - ph) * on, FX.ramp(i % 2 ? '#ff9ae6' : '#9fefff')); else p.blend(x, y, H[1], (1 - ph) * on); }
  const R2 = Math.ceil(rad) + 1; for (let dy = -R2; dy <= R2; dy++) for (let dx = -R2; dx <= R2; dx++) { const d = Math.hypot(dx, dy) / Math.max(1, rad); if (d > 1) continue; const ang = Math.atan2(dy, dx) + d * 3 - age * 6, n = 0.5 + 0.5 * Math.sin(ang * 2 + seed), col = d < 0.42 ? H[0] : d > 0.82 ? H[4] : PX.mix(D_NEB.pink, D_NEB.cyan, n); p.blend(head.x + dx, head.y + dy, col, 1); }
  p.glow(head.x, head.y, rad * 2.6, D_NEB.violet, shine * on * R.P.intensity); dStar(R, head, rad * 1.9, age * 3 + seed, on, dRamp(R));
}
function dShotsFx(S, R) {
  const pal = dRamp(R);
  for (const q of S.shots) { const age = S.t - q.t, u = fromA(q.a);
    if (q.kind === 'arrow') { drawArrow(q.pos, q.a, q.radius); for (let d = 0; d < 60; d += 2) { const w = toL(sub(q.pos, mul(u, d))); R.front.light(w.x, w.y, pal[2], (1 - d / 60) * 0.3 * R.P.intensity); } continue; }
    if (q.kind === 'comet') { dCometShot(R, q, age, u); continue; }
    if (q.kind === 'dark') { dDarkShot(R, q, age, u); continue; }
    if (q.kind === 'star') { dCometShot(R, { ...q, radius: 24 }, age, u, 520, 0.2); dStar(R, toL(q.pos), 7 * R.P.size, age * 5, 0.8, pal); continue; }
    const big = false, tl = 70; // 星弾：回る星と、後ろへ冷えていくまたたきの尾
    for (let d = 2; d < Math.min(tl, age * q.speed); d += 0.5 / WL) { const w = toL(add(sub(q.pos, mul(u, d)), mul(orth(u), Math.sin(d * 0.03 - age * 14) * 5 * (d / tl)))), f = 1 - d / tl; R.front.blend(w.x, w.y, pal[f > 0.6 ? 4 : f > 0.3 ? 3 : 2], f * f * 0.9); R.front.light(w.x, w.y, pal[2], f * 0.2 * R.P.intensity); }
    dStar(R, toL(q.pos), (big ? 4 : 2.5) * R.P.size, age * 8, 1, pal); }
}
function dDraw(S, R) {
  R = bossView(R, '#ab9cff');
  if (R.proto) { dExhaleDim(S); dStarDim(S); }
  const r = S.r, B = S.B, P = R.P, id = S.tech, t = S.t, pose = R.proto ? dOrganic(S, R, dPresentation(S)) : null; dTellDraw(S, R, pose);
  if (!R.proto) {
    if (S.fan && B.mode === 'active') { D2.poly(S.fan, rgba('#5775ff', 0.5)); D2.polyline(S.fan, '#addbff', 4); }
    if (S.exhale && B.mode === 'active') { const e = S.exhale, age = t - e.t, end = add(e.at, mul(fromA(e.a), r.reach)); if (age < r.beam_warn) D2.line(e.at, end, rgba('#d4bbff', 0.35), 4); else D2.line(e.at, add(e.at, mul(fromA(e.a), r.reach * clamp((age - r.beam_warn) / r.beam_extend))), '#d4bbff', r.width); }
    for (const q of S.rifts) if (q) D2.line(q.a, q.b, '#34224d', r.width);
  } else { dBreathFx(S, R); dRiftFx(S, R); dInhaleFx(S, R); dExhaleFx(S, R); dRushFx(S, R, pose); dCloneFx(S, R);
    if (id === 'bite') dBiteTear(S, R, pose);
    for (const impact of S.impacts) { const age = t - impact.t, seed = 83 + Math.floor(impact.t * 10); if (impact.big) { dImpactFx(S, R, impact.at, age, impact.radius * 2.6, seed); dDarkBlast(S, R, impact.at, age, impact.radius * 1.5, seed, D_FLAME); for (let m = 0; m < 6; m++) hDust(S, R, impact.at, age - m * 0.02, seed + m, m * TAU / 6, 2.4); } else (impact.dark ? dDarkBlast : dImpactFx)(S, R, impact.at, age, impact.radius, seed); }
    for (const q of S.arrowImpacts || []) if (q.at && !q.hit) dDarkFall(S, R, q);
    if (id === 'picaro_wall') dDarkMuzzle(S, R, pose);
    if (id === 'star_fan') dStarBlast(S, R, pose);
    dSweepWake(S, R, pose);
    dSafeFx(S, R, pose);
  }
  if (R.proto) for (const q of S.projectiles) if (q.vel && q.t != null) { const sp = len(q.vel), dir = norm(q.vel), age = t - q.t; dRockTrail(S, R, { from: sub(q.pos, mul(q.vel, age)), speed: sp, radius: q.radius, seed: q.seed || 1 }, age, dir, Infinity); }
  if (R.proto && id === 'meteor') S.rocks.forEach((q, i) => { if (q.born != null) dMeteorTrail(S, R, q, t - q.born, i); });
  if (R.proto && id === 'breath') S.rocks.forEach((q, i) => { const age = dRockAge(S, i); if (age < 0) return; const d = norm(sub(q.to, q.from)), speed = dist(q.from, q.to) / DR_FLIGHT, fly = Math.min(age, DR_FLIGHT); q.dir = d; if (age < DR_FLIGHT + 0.5) dMeteorTrail(S, R, q, fly, i, speed, smooth(DR_FLIGHT, DR_FLIGHT + 0.45, age)); if (age >= DR_FLIGHT) dImpactFx(S, R, q.to, age - DR_FLIGHT, q.radius * 1.25, 71 + i); });
  R.blitBack();
  for (const q of S.projectiles) { if (R.proto) { if (q.vel) hRockGhosts(q.pos, norm(q.vel), len(q.vel), q.seed + t, q.radius); drawImg('meteor_0', q.pos, q.seed + t, q.radius); } else D2.circle(q.pos, q.radius, '#8c704c'); }
  S.rocks.forEach((rock, i) => { dRockDraw(S, R, rock, i); dRockBreak(S, R, rock, i); });
  if (id === 'clones' && B.mode === 'active') { const on = smooth(0, 0.45, S.elapsed), off = 1 - smooth(r.active - 0.9, r.active - 0.25, S.elapsed); for (const unit of S.units) { dPicaroBody = R.proto && unit.index > 0 ? { t, seed: unit.index * 3.7 } : null; drawDraco(R.proto ? dSwimPoints(unit.points, t + unit.index * 2, 0.8, unit.index) : unit.points, unit.face ?? unit.angle, unit.index > 0 ? on * off : 1); dPicaroBody = null; } }
  else if (R.proto) drawDraco(pose.points, pose.facing, 1, pose.width || DP.body_width, pose.arms);
  else drawDraco(S.points, B.facing);
  if (id === 'rifts' && B.mode === 'active' && R.proto) for (let hand = 0; hand < 2; hand++) { const local = S.elapsed - hand * r.interval, path = S.paths?.[hand * r.claw_count]; if (path && local >= 0 && local < 0.18) dSupply(R, pose.claws[hand], path[0], 1 - local / 0.18, t * 3, 311 + hand, hand ? 22 : -22); }
  if (S.picaro && S.shouts[0]) { const since = t - S.shouts[0].t; for (const [i, q] of S.picaro.entries()) if (since > 0.25 + i * 0.3) drawEnemy(q, { white: clamp(1 - (since - 0.25 - i * 0.3) * 1.6) * 0.8 }); }
  const chest = toL(R.proto ? pose.chest : sub(B.pos, mul(fromA(B.facing), 110 * DP.head_scale))); R.front.glow(chest.x, chest.y, 10, hexc('#8dbdff'), 0.35);
  if (R.proto) dShotsFx(S, R);
  else { for (const q of S.shots) { if (q.kind === 'arrow' || q.kind === 'dark') drawArrow(q.pos, q.a, q.radius); else { const u = fromA(q.a), side = orth(u); D2.poly([add(q.pos, mul(u, q.radius * 1.5)), add(q.pos, mul(side, q.radius)), sub(q.pos, mul(u, q.radius * 1.5)), sub(q.pos, mul(side, q.radius))], '#d4bbff'); } }
    for (const impact of S.arrowImpacts || []) if (impact.at && !impact.hit) D2.arc(impact.at, r.radius, 0, TAU, '#b7a3ff', 3);
    for (const impact of S.impacts) { const age = t - impact.t; if (age < 0.65) D2.arc(impact.at, impact.radius * (0.35 + age / 0.65 * 1.4), 0, TAU, rgba('#9fbaff', 1 - age / 0.65), 6); } }
  if (!(S.caught && !S.spat)) drawShip(S.ship);
}
// 状態欄：作り直した見た目の説明を足す
for (const d of DEMOS) if (d.id.startsWith('D-')) d.status = { ...d.status, '状態': '見た目と動きを作り直した試作（未承認）', '試作の見た目': '飛びかかる技の予兆は目の光。口から出す技は口へ集める光と照準の光。ブレスは本当の半透明で重ねた炎の塊で、隕石で切れた所で止まり火花が散る。爪はぎざぎざの空間の裂け目。星弾は回る星とつながった光の尾。隕石は飛ぶ間に尾を引く。着弾は白い光・冷える割れ目・土ぼこり・欠片。全身複製はうみへびの技の本物の見た目', '動き': '胴はいつも波打ち、予兆で止まって震え、発動で一気に出る。突進・噛みつきは出だしが最速で止まり際に減速し、叩きつけは加速して落ちる。戻りはずれの大きい所から遅れて波打って戻る。全身複製は弧を描いて持ち場へ回り込む。本番の cpp/bosses/draco は未変更' };
for (const d of DEMOS) if (d.id === 'D-spiral') d.status = { ...d.status, '螺旋（本人指示で変更）': '中心は巻き始めの自機の位置で固定し、外周から内周まで2周で一定に半径を縮める（中心へずらす補正をやめ、2周目が1周目に寄って通り道を塞がない）。上から入って上で巻き終わり、頭は自機の少し上で画面の下へ向ける。直進では頭が真下へ抜け、残りの胴は紐を結ぶように渦ごと中心へ締まる', '本番との違い': '本番（spiral.cpp）は2周目に中心を自機へ寄せる補正があり、直進後の胴は通った道をたどってほどける。採用するなら本番の動きと判定を変える必要がある' };
for (const d of DEMOS) if (d.id === 'D-spiral') d.params = [...(d.params || []), { k: 'spiralScale', label: '渦の外周の大きさ（周回の間）', type: 'range', min: 1, max: 1.7, step: 0.05, def: 1.3 }];

// 生き物らしさ（螺旋）：絵の動きだけに、頭から尾へ流れるうねり・頭の振り・直進前のための引きを足す（当たりの点列は変えない）
// 胴のうねり：頭は動かさず、尾へ向かって流れる波を足す。少し弓なりにして、棒のように伸びきらせない
// 不規則なうねり：長さと速さの違う波を重ね、胴の場所と時間で強さをむらにする。ときどき一部だけ大きく力む
function dLiveWave(s, t, seed = 0) {
  const n = PX.tileNoise(s * 0.0016 - t * 0.55, t * 0.37 + seed, 0, 0, 7), surge = Math.pow(0.5 + 0.5 * PX.tileNoise(s * 0.0009 + t * 0.9, seed - t * 0.23, 0, 0, 19), 3) * 2.6;
  return (0.62 * Math.sin(s * 0.0071 - t * 3.3 + 1.4 * n + seed) + 0.42 * Math.sin(s * 0.0029 + t * 1.7 + seed * 2) + 0.3 * Math.sin(s * 0.016 - t * 6.1 + 2 * n)) * (0.45 + 0.75 * Math.abs(n) + surge);
}
function dSwimPoints(pts, t, swim, seed = 0, bow = 1) {
  const N = pts.length - 1; let s = 0;
  return dFit(pts.map((p, i) => { if (i > 0) s += dist(pts[i - 1], p); const u = i / N, n = orth(norm(sub(pts[Math.min(N, i + 8)], pts[Math.max(0, i - 8)]))), amp = 30 * swim * smooth(0.04, 0.4, u), arch = bow * 70 * smooth(0.06, 0.32, u) * Math.sin(u * Math.PI * 1.35 + 0.5 + seed); return add(p, mul(n, dLiveWave(s, t, seed) * amp + arch)); }), pts);
}
// 静と動：予兆が進むほど波を止めて力をため、最後に震える。発動で一気に動き、戻りながら波が戻る
function dSwimAmount(S) {
  const B = S.B, e = S.elapsed, r = S.r; if (S.staging && S.staging.phase !== 'ready') return 1;
  if (B.mode === 'windup') return 0.7 * (1 - smooth(0.1, 0.8, e / Math.max(0.01, r.warn)));
  if (B.mode === 'active') return ['charge', 'leap'].includes(S.tech) ? 1 : ['breath', 'meteor', 'star_fan', 'inhale'].includes(S.tech) ? 0.25 : 0.35;
  if (B.mode === 'recovery') return 0.7 * smooth(0, 1, e / Math.max(0.01, r.recover)); return 0.7;
}
function dSpitKick(S) { if (['picaro_wall', 'star_fan'].includes(S.tech)) { let kick = 0; for (const at of S.shotTimes || []) { const t = S.t - at; if (t >= 0) kick -= 1.1 * Math.exp(-t / 0.12) * (1 - Math.exp(-t / 0.015)); } return kick; } if (!S.rocks.length || S.B.mode !== 'windup') return 0; let kick = 0; S.rocks.forEach((q, i) => { const t = dRockAge(S, i); if (t >= -0.16) kick += t < 0 ? -0.6 * smooth(-0.16, 0, t) : Math.exp(-t / 0.1) * (1 - Math.exp(-t / 0.02)) - 0.6 * Math.exp(-t / 0.02); }); return kick; }
function dBodyAlive(S, R, pose) {
  const roar = dExhaleLife(S); if (roar > 0) { const fw = fromA(pose.facing), sd = orth(fw), back = 26 * Math.min(1.4, roar), rattle = Math.sin(S.t * 74) * 4 * roar; pose = { ...pose, points: pose.points.map((p, i) => { const w = 1 - smooth(0, 0.35, i / (pose.points.length - 1)); return add(p, add(mul(fw, -back * w), mul(sd, rattle * w))); }) }; }
  const kick = dSpitKick(S); if (kick) { const fw = fromA(pose.facing); pose = { ...pose, points: pose.points.map((p, i) => add(p, mul(fw, 46 * kick * (1 - smooth(0, 0.3, i / (pose.points.length - 1)))))) }; }
  const k = R.P.alive ?? 1, tail = ['tail_sweep', 'tail_slam'].includes(S.tech), swim = dSwimAmount(S) * k * (tail ? 0.3 : 1), points = dSwimPoints(pose.points, S.t, swim, 0, tail ? 0 : k), B = S.B;
  if (B.mode === 'windup' && (!S.staging || S.staging.phase === 'ready')) { const q = smooth(0.72, 1, S.elapsed / Math.max(0.01, S.r.warn)), shake = mul(orth(fromA(pose.facing)), Math.sin(S.t * 90) * 3 * q * k); if (q > 0) for (let i = 0; i <= 6; i++) points[i] = add(points[i], mul(shake, 1 - i / 7)); }
  const facing = pose.facing + Math.sin(S.t * 5.3) * 0.05 * swim, total = pathLength(points);
  return { ...pose, points, facing, mouth: add(points[0], mul(fromA(facing), 120 * DP.head_scale)), chest: pathAt(points, Math.min(total, DP.body_width * 0.9)).pos, claws: pose.arms.map((turn, i) => dArmFrame(points, DP.body_width, total, i, turn).claw) };
}
function dOrganic(S, R, pose) {
  if (pose && S.tech !== 'spiral') return dBodyAlive(S, R, pose);
  if (S.tech !== 'spiral' || !S.spiral || !pose) return pose; const sp = S.spiral, k = R.P.alive ?? 1; if (k <= 0) return pose;
  const t = S.t, active = S.B.mode === 'active', e = S.elapsed, shrinkAt = sp.coil + sp.pause;
  const swim = !active ? 1 : e < sp.coil ? 1 : e < shrinkAt ? 0.35 : 0.7, pts = pose.points, N = pts.length - 1;
  let s = 0; const out = pts.map((p, i) => { if (i > 0) s += dist(pts[i - 1], p); const a = i === 0 ? sub(pts[1], pts[0]) : sub(p, pts[i - 1]), n = orth(norm(a)), u = i / N;
    const amp = 34 * k * swim * (0.15 + 0.85 * smooth(0, 0.35, u)), wave = dLiveWave(s, t * 1.15) * amp;
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
  if (last > 0) { for (const sx of [-1, 1]) { const ey = toL(add(head, add(mul(fromA(pose.facing), D_EYE.fw), mul(orth(fromA(pose.facing)), sx * D_EYE.side)))); R.front.glow(ey.x, ey.y, 3 + 4 * last, pal[3], last * R.P.intensity); R.front.px(ey.x, ey.y, pal[4]); } }
}
for (const d of DEMOS) if (d.id === 'D-spiral') d.params = [...(d.params || []), { k: 'spiralTail', label: '胴（しっぽ）の長さ', type: 'range', min: 0.6, max: 1, step: 0.05, def: 0.85 }, { k: 'spiralWait', label: '円になってから飛び出すまで（秒）', type: 'range', min: 1.6, max: 4.5, step: 0.1, def: 2.8 }];
