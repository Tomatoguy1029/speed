// ===== うみへび：コンボと大技（作り直し）=====
// 時刻・参加者・軌道は main の cpp/bosses/hydra/technique.cpp と各技（tornado・debris_shatter・beam_pincer・north・sequence・curve・grid・swarm）を写す。
// 参加する首は発動の瞬間の頭の位置（strike_pos）で止まり、向きだけを技が決める。試作の表示は見た目だけを重ねる。
const HM_COLORS = { bite: '#ff5470', vortex: '#5fe3c4', debris: '#a9bccd', beam: '#ff6fb4', thunder: '#7fb8ff' };
const HM_ROCK_R = 22; // data/enemies/hydra_rubble.tres の radius
function hmPick(S, kinds) { const out = []; for (const k of kinds) { const n = S.necks.find(m => m.kind === k && !out.includes(m)); if (n) out.push(n); } return out; }
function hmSetup(S, id, o) {
  S.tech = id; S.r = hRule(id); S.B = bossActor('hydra', o.boss || V(-300, 0)); S.age = -0.6; S.necks = []; S.shots = []; S.fx = [];
  S.ship = shipState({ ...(o.ship || V(430, 40)) }, Math.PI, 0); S.ship.vel = V(0, 0);
  for (let i = 0; i < (o.count || 8); i++) S.necks.push({ kind: H_KINDS[i], baseAngle: TAU * i / (o.count || 8), aimV: 0, glow: 0, hist: [], length: HP.neck_rest });
  S.parts = o.kinds ? hmPick(S, o.kinds) : o.front ? null : S.necks.slice();
  if (!S.parts) { S.B.facing = o.facing || 0; S.parts = hmFront(S, o.front); }
  const mean = Math.atan2(S.parts.reduce((s, n) => s + Math.sin(n.baseAngle), 0), S.parts.reduce((s, n) => s + Math.cos(n.baseAngle), 0));
  S.B.facing = o.facing ?? -mean; // 本体を回して参加する首を機体側へ向ける（front_body）
  for (const n of S.necks) { n.angle = n.baseAngle + S.B.facing; n.pos = add(hBase(S, n), mul(fromA(n.angle), HP.neck_rest)); hChain(S, n, 0); }
}
// 連携技の見た目：参加する頭が重ならないよう、予兆のあいだに左右へ開く。参加しない首も頭を寄せず、自分の付け根の向きに留まる（判定の計算は本番のまま）
function hmOpenHeads(S) {
  if (!S.open) { const parts = S.parts.slice(0, 3).map((n) => ({ n, a0: angOf(sub(n.strike, hBase(S, n))), len: dist(n.strike, hBase(S, n)) })).sort((a, b) => angDiff(a.a0, b.a0)), count = parts.length, close = count > 1 && count <= 3 && parts.slice(1).some((q, i) => dist(q.n.strike, parts[i].n.strike) < 170); S.open = close ? parts.map((q, i) => ({ ...q, off: (i - (count - 1) / 2) * (count === 2 ? 1.3 : 0.6) })) : []; }
  const k = smooth(0, 1, clamp(S.age / S.r.warning_time)); for (const o of S.open) o.n.strike = add(hBase(S, o.n), mul(fromA(o.a0 + o.off * k), o.len));
}
function hmHoldBystanders(S, dt) { for (const n of S.necks) { if (n.major || n.gone) continue; const home = n.baseAngle + S.B.facing, off = angDiff(n.angle, home), lim = 0.22; if (Math.abs(off) > lim) { n.angle -= Math.sign(off) * Math.min(Math.abs(off) - lim, 2.4 * dt); n.pos = add(hBase(S, n), mul(fromA(n.angle), dist(n.pos, hBase(S, n)))); } } }
// 噛みついた首の戻り：首ごとに時間をずらし、ゆっくり引き始めて途中で一気に戻り、少し行き過ぎて落ち着く。頭は左右に振れ、首に蛇のうねりが走る（見た目だけ）
function hmStartRecover(S) { if (S.tech === 'curve') { for (const n of S.parts) { const b = hBase(S, n); n.rec = { calm: true, start: S.age, T: 0.55, L0: dist(n.pos, b), a0: angOf(sub(n.pos, b)), tilt0: n.tilt || 0, bend0: n.bend || 0 }; } return; } // 全部の首が一緒になめらかに戻る
  S.parts.forEach((n, i) => { const b = hBase(S, n), L0 = dist(n.pos, b); if (L0 > HP.neck_rest * 1.3) n.rec = { start: S.age + i * 0.14 + hash(i * 3.3) * 0.08, T: 0.85 + 0.25 * hash(i * 5.1), L0, a0: angOf(sub(n.pos, b)), ph: hash(i * 7.7) * TAU, side: hash(i * 2.9) < 0.5 ? -1 : 1 }; }); }
function hmRecover(S, n) {
  const q = n.rec, b = hBase(S, n), tau = S.age - q.start, k = clamp(tau / q.T); if (tau >= q.T) { n.length = HP.neck_rest; n.aimV = 0; n.tilt = 0; n.bend = 0; n.rec = null; return; }
  if (q.calm) { const e = k * k * (3 - 2 * k); n.tilt = q.tilt0 * (1 - e); n.bend = q.bend0 * (1 - e); n.angle = q.a0 + angDiff(n.baseAngle + S.B.facing, q.a0) * e; n.length = lerp(q.L0, HP.neck_rest, e); n.pos = add(b, mul(fromA(n.angle), n.length)); return; }
  const home = n.baseAngle + S.B.facing, pull = k * k * (3 - 2 * k), over = Math.sin(k * Math.PI) * Math.pow(k, 3) * 0.16, tug = tau < 0 ? 0 : Math.sin(Math.min(1, tau / 0.14) * Math.PI) * 0.035; // 最初に小さく引いてから戻る
  n.angle = q.a0 + angDiff(home, q.a0) * pull + Math.sin(Math.max(0, tau) * 8 + q.ph) * 0.13 * (1 - k) * smooth(0, 0.2, tau) * q.side; n.length = lerp(q.L0, HP.neck_rest, pull + over - tug); n.pos = add(b, mul(fromA(n.angle), n.length));
}
// 参加中の首は頭を止め、技の向きだけを変える。終わったら待機へ戻る（technique.cpp finish）
function hmStep(S, dt, tick) {
  S.age += dt; S.ship.pos = add(S.ship.pos, mul(S.ship.vel, dt)); const r = S.r, end = r.warning_time + r.performance_time;
  if (S.age >= 0 && !S.begun) { S.begun = true; for (const n of S.parts) { n.strike = { ...n.pos }; n.major = true; n.target = { ...S.ship.pos }; } }
  if (S.age >= end && !S.ended) { S.ended = true; for (const n of S.parts) { const b = hBase(S, n); n.angle = angOf(sub(n.pos, b)); n.length = dist(n.pos, b); n.major = false; } hmStartRecover(S); }
  S.mt = S.age - r.warning_time;
  if (S.begun && !S.ended) { hmOpenHeads(S); tick(S, dt); }
  for (const n of S.necks) { if (n.rec) hmRecover(S, n); if (!n.major && !n.rec) { hIdle(S, n, dt); if (S.begun && !S.ended) hmHoldBystanders(S, dt); } else if (n.rec) { /* 戻りの動きで動かす */ } else n.pos = n.moving ? n.pos : { ...n.strike }; hChain(S, n, dt); n.hist.push({ t: S.t, pos: { ...n.pos }, angle: n.angle }); if (n.hist.length > 48) n.hist.shift(); }
}
function hmPhase(S) { const r = S.r; return S.age < 0 ? '待機' : S.mt < 0 ? '予兆（構え）' : S.age < r.warning_time + r.performance_time ? '攻撃中' : S.age < r.warning_time + r.performance_time + r.tech_recovery ? '全体の硬直（攻めどき）' : '戻り'; }
// 参加する首の見た目：予兆で頭を引いてため、最後は震えて止まる。発動 at（技の時刻）で前へ突き出して戻る
function hmPose(S, n, at = 0) {
  const out = { head: n.pos, angle: n.angle, sx: 1, sy: 1 }; if (!n.major || S.age < 0) return out;
  const fw = fromA(n.angle), u = clamp(S.age / Math.max(0.01, S.r.warning_time + at)), rel = S.mt - at;
  if (rel < 0) { const c = smooth(0, 0.6, u), fz = smooth(0.6, 0.85, u); out.head = add(add(n.pos, mul(fw, -14 * c * S.P.coil)), mul(orth(fw), Math.sin(S.t * 95) * 1.4 * fz)); out.sx = 1 + 0.05 * c; out.sy = 1 - 0.07 * c; }
  else { const j = Math.exp(-rel / 0.1) * Math.min(1, rel / 0.03); out.head = add(n.pos, mul(fw, 12 * j * S.P.snap)); out.sy = 1 + 0.08 * j; }
  return out;
}
function hmVisNeck(S, n, pose) { // 頭の見た目の位置まで首の先をなめらかに寄せる
  const pts = n.points, N = pts.length - 1, d = sub(pose.head, n.pos), bend = n.bend || 0; if (len(d) < 0.01 && !bend) return pts;
  const side = orth(norm(sub(pts[N], pts[0]))), ph = n.baseAngle * 3;
  return pts.map((p, i) => { const u = i / N, o = bend ? Math.sin(u * Math.PI) * (bend + Math.sin(u * 5 - S.t * 3 + ph) * bend * 0.12) : 0; return add(add(p, mul(side, o)), mul(d, u * u)); });
}
function hmDrawBody(S, R, poses) {
  S.necks.forEach((n, i) => { if (!n.gone) hDrawNeck(S, n, R.proto && poses.has(n) ? hmVisNeck(S, n, poses.get(n)) : n.points, i); });
  hStamp('body', null, S.B.pos, S.B.facing, S.B.r * 2 / IMG['hydra/body'].width);
  for (const n of S.necks) { if (n.gone) continue; const p = R.proto && poses.get(n); if (p) hDrawHead(n, p.head, p.angle, p.sx, p.sy); else hDrawHead(n, n.pos, n.angle); }
}
function hmMouth(n, pose) { return add(pose.head, mul(fromA(pose.angle), hMouthDist(n))); }
function hmEyes(S, R, n, pose, k, color) { // 目の光（参加する首の合図）
  if (k <= 0.01) return; if (color === HM_COLORS.bite) { hBiteEyes(S, R, pose, k ** 0.7, color); return; } const pal = FX.ramp(color);
  for (const sx of [-8.5, 8.5]) { const e = toL(hLocal(pose.head, pose.angle, sx, -9.5, pose.sx, pose.sy)); R.front.glow(e.x, e.y, 1.6 + 3 * k, pal[3], (0.2 + 0.5 * k) * R.P.intensity); if (k > 0.4) R.front.px(e.x, e.y, pal[k > 0.8 ? 4 : 3]); }
}
function hmGather(S, R, M, k, color, seed) { bossGather({ ...R, P: { ...R.P, color } }, M, 42, k, S.t, seed); }
function hmChew(S, R, n, pose, k) { // 瓦礫の首：首の瓦礫が口へ送られ、口先で砕ける
  const pts = hmVisNeck(S, n, pose), N = pts.length - 1, M = toL(hmMouth(n, pose));
  for (let j = 0; j < 8; j++) { const ph = (S.t * 1.6 + hash(j * 3.1)) % 1, f = ph * N, i = Math.min(N - 1, Math.floor(f)), at = lerpV(pts[i], pts[i + 1], f - i), q = toL(at); R.front.px(q.x, q.y, H_STONE[4]); R.front.px(q.x + 1, q.y, H_STONE[3]); }
  for (let j = 0; j < 14; j++) { const an = hash(j * 2.3) * TAU + S.t * 6 * (hash(j) - 0.5), d = 3 * Math.sqrt(hash(j * 5.9)) * k; R.front.px(M.x + Math.cos(an) * d, M.y + Math.sin(an) * d, H_STONE[3]); }
}
// 瓦礫竜巻は見下ろしの渦：らせんの腕が中心へ巻き込み、緑の風の腕に瓦礫の砂ぼこりの腕が混ざる。色は風の帯と同じで、腕の濃さはなめらかに変える。
const HM_TOR_ROCKS = [[0.42, 15, 0.86], [0.56, 19, 0.62], [0.68, 12, 0.42], [0.78, 16, 0.74], [0.87, 10, 0.54]];
function hmTorView(S, R, c, Rw, fade, grow) { return { c, L: toL(c), Rr: Rw * WL * R.P.size, fade, grow, t: S.t }; }
function hmTorSwirl(R, G) { // 渦の本体：画素ごとに腕の濃さを求める。太い腕と細い腕を速さを変えて重ね、腕の間も濃い緑の地で埋める
  const p = R.back, C = H_WIND, ramp = (v) => { const q = clamp(v) * 5, i = Math.min(4, Math.floor(q)); return PX.mix(C[1 + i], C[2 + i], q - i); }, Rr = G.Rr, t = G.t, turn = t * 10;
  p.each(G.L.x - Rr * 1.2, G.L.y - Rr * 1.2, G.L.x + Rr * 1.2, G.L.y + Rr * 1.2, (x, y, sx, sy) => {
    const dx = x - G.L.x, dy = y - G.L.y, r = Math.hypot(dx, dy) / Rr; if (r > 1.15) return; const ph = Math.atan2(dy, dx), tw = 5.2 * Math.log(r + 0.1), n = PX.tileFbm((ph / TAU + 0.5) * 8, r * 3 - t * 1.4, 8, 0, 37, 2), n2 = PX.tileFbm((ph / TAU + 0.5) * 16, r * 6 - t * 3, 16, 0, 11, 2);
    const big = Math.pow(0.5 + 0.5 * Math.cos(3 * ph + tw + turn), 1.2), thin = Math.pow(0.5 + 0.5 * Math.cos(7 * ph + tw * 1.25 + turn * 1.5 + 1.3), 1.6), arm = clamp((0.72 * big + 0.42 * thin) * (0.72 + 0.8 * n)), grit = clamp(Math.pow(0.5 + 0.5 * Math.cos(2 * ph + tw + turn + 2.1), 3) * smooth(0.3, 0.75, r) * (0.5 + 1.1 * n2));
    const env = smooth(0.03, 0.16, r) * (1 - smooth(0.82, 1.12, r)), core = 1 - smooth(0.04, 0.12, r), a = (0.62 + 0.36 * arm) * env * G.fade;
    if (core > 0) p.blendPx(sx, sy, C[0], core * 0.85 * G.fade); if (a > 0.015) p.blendPx(sx, sy, ramp(arm * (1.12 - 0.4 * r)), a);
    if (grit * env > 0.03) p.blendPx(sx, sy, H_DUST[n2 > 0.5 ? 0 : 1], grit * env * 0.8 * G.fade); });
  for (let k = 0; k < 16; k++) { const a0 = k * TAU / 16 + hash(k * 3.1) * 1.2 - t * 12 * (0.85 + 0.3 * hash(k * 5.3)), r0 = lerp(0.14, 0.5, hash(k * 2.7)), r1 = r0 + lerp(0.3, 0.55, hash(k * 7.9)), n = Math.ceil(Rr * 3); // 細い風の筋：外から中へ巻き込み、両端が細い
    for (let m = 0; m <= n; m++) { const u = m / n, rr = lerp(r0, r1, u), ang = a0 - 5.2 / 3 * Math.log(rr + 0.1), x = G.L.x + Math.cos(ang) * rr * Rr, y = G.L.y + Math.sin(ang) * rr * Rr, f = Math.sin(Math.PI * u); p.blend(x, y, C[k % 3 === 0 && f > 0.7 ? 7 : 6], f * f * (k % 3 === 0 ? 0.8 : 0.5) * G.fade); } }
}
function hmTorLitter(R, G) { // 砂利と葉：外から回りながら速くなって中へ吸い込まれる
  const p = R.back, C = H_WIND;
  hCycle(G.t, 1e9, 44, 0.7, 1.1, 53, (age, life, rnd) => { const k = age / life, rr = lerp(1.3, 0.14, Math.pow(k, 1.3)) * G.Rr, th = rnd(1) * TAU - lerp(2, 3, rnd(2)) * TAU * Math.pow(k, 1.6), x = G.L.x + Math.cos(th) * rr, y = G.L.y + Math.sin(th) * rr, a = Math.min(1, k * 6) * (1 - smooth(0.8, 1, k)) * G.fade * G.grow, leaf = rnd(3) < 0.45, spin = age * lerp(-14, 14, rnd(4));
    p.blend(x, y, leaf ? C[5] : H_STONE[3], a); p.blend(x + Math.round(Math.cos(spin)), y + Math.round(Math.sin(spin)), leaf ? C[4] : H_STONE[2], a); });
}
function hmTorWake(R, G, T, r, a) { // 走った跡：通った所に土ぼこりが残り、ふくらんで薄れる
  const RATE = 40, sd = orth(T.dir);
  for (let i = Math.max(0, Math.floor((a - 0.55) * RATE)); i / RATE <= a; i++) { const born = i / RATE, rnd = (k) => hash(i * 6.1 + k * 2.9 + 17), age = a - born, life = lerp(0.3, 0.55, rnd(1)), k = 1 - age / life; if (k <= 0) continue;
    const q = toL(add(add(T.center, mul(T.dir, r.tornado_speed * born)), mul(sd, (rnd(2) - 0.5) * r.tornado_width * 0.8))), rr = lerp(2, 3.6, rnd(4)) * (0.8 + (1 - k) * 1.6) * R.P.size * R.P.dust, col = H_DUST[rnd(5) < 0.5 ? 0 : 1]; R.back.disc(q.x, q.y, rr, col, (d) => Math.pow(k, 1.3) * 0.5 * (1 - d * d) * G.fade); }
}
// 風の首の口元で風が集まる：まわりの空気が巻きながら渦へ吸い込まれる筋。渦が育つほど筋が増えて速くなる
function hmTorGather(R, G, k) {
  const p = R.back, C = H_WIND, n = Math.round(6 + 16 * k);
  for (let i = 0; i < n; i++) { const h = hash(i * 4.7 + 2), ph = (G.t * (0.9 + 1.1 * k + 0.5 * h) + hash(i * 9.1)) % 1, an0 = hash(i * 1.7) * TAU, R0 = G.Rr + 14 + 22 * hash(i * 3.3), L = 10 + 8 * h;
    for (let m = 0; m < L; m++) { const u = m / L, ph2 = Math.max(0, ph - u * 0.1), rr = lerp(R0, G.Rr * 0.5, Math.pow(ph2, 1.5)), an = an0 - 2.2 * Math.pow(ph2, 1.5), f = (1 - u) * Math.sin(Math.PI * ph) * (0.35 + 0.65 * k); if (f > 0.04) p.blend(G.L.x + Math.cos(an) * rr, G.L.y + Math.sin(an) * rr, C[u < 0.3 ? 6 : 5], f * 0.8); } }
}
// 岩：瓦礫の首がまっすぐ渦へ打ち込み、渦に捕まるとそのまま中を回る。終わりに外へ放り出される
function hmTorRock(S, G, from, j, t) {
  const [s0, size, ru] = HM_TOR_ROCKS[j], ch = S.r.tornado_charge, start = s0 * ch, dur = 0.17, p = clamp((t - start) / dur), Fo = toL(from), d = sub(Fo, G.L), th0 = Math.atan2(d.y, d.x), rr = G.Rr * ru, tau = Math.max(0, t - start - dur);
  const entry = V(G.L.x + Math.cos(th0) * rr, G.L.y + Math.sin(th0) * rr), th = th0 - 6 * tau - 5 * (1 - Math.exp(-3 * tau)), rho = rr * (1 + (1 - G.fade) * 2.2), q = p < 1 ? lerpV(Fo, entry, p) : V(G.L.x + Math.cos(th) * rho, G.L.y + Math.sin(th) * rho);
  return { p, tau, dur, start, size, th, rho, flight: dist(Fo, entry) / WL, aim: norm(sub(entry, Fo)), world: V(G.c.x + (q.x - G.L.x) / WL, G.c.y + (q.y - G.L.y) / WL) };
}
function hmTorHit(R, G, k) { const u = k.tau / 0.28; if (u >= 1) return; const q = toL(k.world); R.back.disc(q.x, q.y, 3 + 5 * u, H_DUST[2], (d) => (1 - u) * 0.6 * (1 - d * d)); for (let m = 0; m < 8; m++) { const an = m * TAU / 8 + k.th, r0 = (2 + 9 * u) * (0.8 + 0.4 * hash(m * 2.3 + k.size)); R.back.blend(q.x + Math.cos(an) * r0, q.y + Math.sin(an) * r0, H_STONE[3], 1 - u); } } // 打ち込まれた瞬間の土ぼこりと砂利
function hmTorRockTrail(R, G, k) { for (let m = 1; m <= 14; m++) { const th = k.th + m * 0.09, q = V(G.L.x + Math.cos(th) * k.rho, G.L.y + Math.sin(th) * k.rho), f = 1 - m / 15; R.back.disc(q.x, q.y, 1.6 * f + 0.6, H_DUST[0], (d) => f * f * 0.5 * (1 - d * d) * G.fade); } }

// ---------- 瓦礫竜巻（tornado.cpp）
// 頭は hmOpenHeads で開く。渦の中心と向きは開く前の位置から本番の計算で決める
function hmTornadoTick(S) {
  const r = S.r, [wind, debris] = S.parts, t = S.mt;
  if (!S.tor) { const base = S.open.find((o) => o.n === wind), from = base ? add(hBase(S, wind), mul(fromA(base.a0), base.len)) : wind.strike, dir = norm(sub(S.ship.pos, from)); S.tor = { dir, center: add(from, mul(dir, 120)), from: { ...debris.strike }, faces: [wind, debris].map((n) => ({ n, face0: n.angle })) }; }
  const k = smooth(0, 1, clamp(S.age / r.warning_time)); for (const o of S.tor.faces) o.n.angle = o.face0 + angDiff(angOf(sub(S.tor.center, o.n.strike)), o.face0) * k;
  S.tor.from = add(debris.strike, mul(fromA(debris.angle), hMouthDist(debris)));
  if (t >= r.tornado_charge && !S.tor.launched) S.tor.launched = S.t;
}
function hmTornadoDraw(S, R) {
  const r = S.r, [wind, debris] = S.parts, poses = new Map(S.parts.map(n => [n, hmPose(S, n, 0)])), col = HM_COLORS.vortex, T = S.tor; let G = null;
  if (R.proto && S.age >= 0) {
    const u = clamp(S.age / r.warning_time);
    if (S.mt < 0) { hmEyes(S, R, wind, poses.get(wind), u, col); hmEyes(S, R, debris, poses.get(debris), u, HM_COLORS.debris); hmChew(S, R, debris, poses.get(debris), u); }
    if (T && S.mt >= 0) { const a = T.launched ? S.t - T.launched : 0;
      if (a < r.tornado_life) { const grow = T.launched ? 1 : Math.pow(clamp(S.mt / r.tornado_charge), 1.4), fade = clamp((r.tornado_life - a) / 0.4), Rw = r.tornado_width * 0.5 * (T.launched ? lerp(0.8, 1, smooth(0, 0.15, a)) : 0.8 * lerp(0.1, 1, grow)), M = add(wind.strike, mul(T.dir, hMouthDist(wind))), rest = add(M, mul(T.dir, r.tornado_width * 0.4 + 8)), c = T.launched ? add(rest, mul(T.dir, r.tornado_speed * a)) : add(M, mul(T.dir, Rw + 8)); // 渦は口のすぐ前で育つ。育ち切ると本番の中心とほぼ同じ位置になる
        G = hmTorView(S, R, c, Rw, fade, grow); if (T.launched) hmTorWake(R, G, T, r, a); else hmTorGather(R, G, grow);
        hmTorSwirl(R, G); if (S.mt > r.tornado_charge * 0.4) hmTorLitter(R, G);
        for (let j = 0; j < HM_TOR_ROCKS.length; j++) { const k = hmTorRock(S, G, T.from, j, S.mt); if (k.p >= 1) { hmTorRockTrail(R, G, k); hmTorHit(R, G, k); } else if (k.p > 0) { const age = S.mt - k.start; hRockComet(R, { from: T.from, speed: k.flight / k.dur, radius: k.size, seed: j * 3 + 1 }, age, k.aim, { stop: k.dur }); } } } }
  }
  R.blitBack(); hmDrawBody(S, R, poses);
  if (G) for (let j = 0; j < HM_TOR_ROCKS.length; j++) { const k = hmTorRock(S, G, T.from, j, S.mt); if (k.p > 0) drawImg('meteor_0', k.world, S.t * (5 + j), k.size, G.fade); }
  if (!R.proto && S.tor && S.mt >= 0) { if (!S.tor.launched) D2.circle(S.tor.center, r.tornado_width * 0.4, rgba('#4dd9b8', 0.25)); else { const a = S.t - S.tor.launched; if (a < r.tornado_life) { const c = add(S.tor.center, mul(S.tor.dir, r.tornado_speed * a)); D2.roundBeam(sub(c, mul(S.tor.dir, 45)), add(c, mul(S.tor.dir, 45)), rgba('#4dd9b8', 0.45), r.tornado_width); } } }
  drawShip(S.ship);
}

// ---------- 瓦礫のビーム破砕（debris_shatter.cpp）
const HM_SHATTER_SPEED = 220; // 試作の値：岩の速さ。打ち出しからずっと同じ速さで進む
function hmShatterTick(S, dt) {
  const r = S.r, [debris, beam] = S.parts, t = S.mt;
  // 瓦礫の首は岩を吐く扇の真ん中を向く（予兆のあいだに少しずつ向きを変える）
  S.shFace ??= debris.angle; debris.angle = S.shFace + angDiff(angOf(sub(S.ship.pos, debris.strike)), S.shFace) * smooth(0, 1, clamp(S.age / r.warning_time)); if (t < 0) return;
  if (!S.sh) { const aim = angOf(sub(S.ship.pos, beam.strike)), from = add(debris.strike, mul(fromA(debris.angle), hMouthDist(debris))); S.sh = { aim, stones: [] }; for (let j = 0; j < r.rubble_count; j++) { const off = (j / Math.max(1, r.rubble_count - 1) - 0.5) * 1.4; S.sh.stones.push({ from: { ...from }, pos: { ...from }, a: debris.angle + off, seed: j }); } }
  // 岩は扇の真ん中が機体を狙うように打ち出され、同じ速さでまっすぐ進む
  for (const s of S.sh.stones) { if (s.shattered) continue; s.vel = mul(fromA(s.a), HM_SHATTER_SPEED); s.pos = add(s.pos, mul(s.vel, dt)); }
  if (t >= r.shatter_deploy && t < r.shatter_deploy + r.shatter_time) {
    beam.angle = S.sh.aim - r.shatter_arc * 0.5 + r.shatter_arc * clamp((t - r.shatter_deploy) / r.shatter_time);
    const A = beam.strike, B = add(A, mul(fromA(beam.angle), r.beam_len)), d = sub(B, A);
    for (const s of S.sh.stones) { if (s.shattered) continue; const u = clamp(((s.pos.x - A.x) * d.x + (s.pos.y - A.y) * d.y) / (d.x * d.x + d.y * d.y)); if (dist(s.pos, add(A, mul(d, u))) > HM_ROCK_R + r.beam_width * 0.5) continue;
      s.shattered = S.t; const base = angOf(sub(s.pos, A)); for (let k = 0; k < 6; k++) S.shots.push({ kind: 'shard', from: { ...s.pos }, angle: base + (k - 2.5) * 0.45, t: S.t, seed: s.seed * 7 + k }); }
  } else if (t < r.shatter_deploy) beam.angle = S.sh.aim - r.shatter_arc * 0.5;
}
function hmShatterDraw(S, R) {
  const r = S.r, [debris, beam] = S.parts, poses = new Map([[debris, hmPose(S, debris, 0)], [beam, hmPose(S, beam, r.shatter_deploy)]]), pal = FX.ramp(HM_COLORS.beam);
  if (R.proto && S.age >= 0) {
    const u = clamp(S.age / r.warning_time), pb = poses.get(beam), M = hmMouth(beam, pb);
    if (S.mt < 0) { hmEyes(S, R, debris, poses.get(debris), u, HM_COLORS.debris); hmChew(S, R, debris, poses.get(debris), u); }
    hmEyes(S, R, beam, pb, S.mt < r.shatter_deploy ? clamp(S.age / (r.warning_time + r.shatter_deploy)) : 0.5, HM_COLORS.beam);
    if (S.sh) {
      for (const s of S.sh.stones) if (!s.shattered && S.mt > 0 && s.vel) { const dir = fromA(s.a); hRockComet(R, { from: sub(s.pos, mul(dir, HM_SHATTER_SPEED * S.mt)), speed: HM_SHATTER_SPEED, radius: HM_ROCK_R, seed: s.seed }, S.mt, dir, { pace: HM_SHATTER_SPEED / 676 }); }
      const A = toL(M), B = toL(add(M, mul(fromA(beam.angle), r.beam_len)));
      if (S.mt < r.shatter_deploy) { const k = clamp(S.age / (r.warning_time + r.shatter_deploy)); FX.warnRail(R.front, A, B, { color: HM_COLORS.beam, k, time: S.t, seed: 4, maxLv: 2, intensity: R.P.intensity }); hmGather(S, R, M, k, HM_COLORS.beam, 8); }
      else if (S.mt < r.shatter_deploy + r.shatter_time + 0.1) { const e = S.mt - r.shatter_deploy, from = clamp((e - r.shatter_time + 0.1) / 0.1); FX.beam(R.front, A, B, { w: r.beam_width * 0.5 * WL * R.P.size, source: false, color: HM_COLORS.beam, time: S.t, from, to: clamp(e / 0.07), taper: 6, alpha: 1, intensity: R.P.intensity }); FX.flare(R.front, A, 1.4 * R.P.size, HM_COLORS.beam, S.t, 0.5 * (1 - from), 4); }
      for (const s of S.sh.stones) if (s.shattered) { const a = S.t - s.shattered; if (a < 0.6) { const L = toL(s.pos); if (a < 0.1) { R.front.glow(L.x, L.y, 9 * R.P.size, pal[3], (1 - a / 0.1) * 0.8 * R.P.intensity); R.front.px(L.x, L.y, pal[4]); } hDust(S, R, s.pos, a, 5 + s.seed, angOf(sub(s.pos, beam.strike)), 0.8);
        for (let i = 0; i < 14; i++) { const life = 0.25 + 0.3 * hash(s.seed * 9 + i); if (a > life) continue; const an = hash(s.seed * 5 + i * 3.3) * TAU, d = (120 + 160 * hash(i * 7.7)) * 0.1 * (1 - Math.exp(-a / 0.1)) * WL, k = a / life; R.front.px(L.x + Math.cos(an) * d, L.y + Math.sin(an) * d, k < 0.3 ? pal[3] : H_STONE[k < 0.6 ? 4 : 3]); } } }
      for (const b of S.shots) { if (b.kind !== 'shard') continue; const a = S.t - b.t; if (a > 2.5) continue; const dir = fromA(b.angle), P0 = add(b.from, mul(dir, r.shard_speed * a)), q = toL(P0), heat = Math.exp(-a / 0.35);
        for (let d = 0; d < 7 + 8 * heat; d += 0.5) { const w = toL(sub(P0, mul(dir, d / WL))), k = 1 - d / (7 + 8 * heat); if (k > 0.6) R.front.px(w.x, w.y, heat > 0.5 ? pal[3] : H_STONE[4]); else R.front.dot(w.x, w.y, heat > 0.4 ? pal[2] : H_STONE[2], k * 1.2); }
        R.front.px(q.x, q.y, heat > 0.5 ? pal[4] : H_STONE[4]); R.front.px(q.x + 1, q.y, H_STONE[3]); R.front.light(q.x, q.y, pal[2], 0.4 * heat * R.P.intensity); }
    }
  }
  R.blitBack(); hmDrawBody(S, R, poses);
  if (S.sh) for (const s of S.sh.stones) if (!s.shattered && S.mt >= 0) drawImg('meteor_0', s.pos, S.t * 1.6 + s.seed, HM_ROCK_R * 1.2);
  if (!R.proto && S.sh) { const A = beam.strike, B = add(A, mul(fromA(beam.angle), r.beam_len)); if (S.mt >= r.shatter_deploy && S.mt < r.shatter_deploy + r.shatter_time) D2.roundBeam(A, B, rgba('#ff4066', 0.85), r.beam_width); for (const b of S.shots) { const a = S.t - b.t; if (a < 2.5) D2.circle(add(b.from, mul(fromA(b.angle), r.shard_speed * a)), 8, '#c98f6a'); } }
  drawShip(S.ship);
}

// ---------- ビーム2本のはさみ（beam_pincer.cpp）
function hmPincerTick(S) {
  const r = S.r; if (S.mt < 0) return;
  if (!S.aims) S.aims = S.parts.map(n => angOf(sub(S.ship.pos, n.strike)));
  // それぞれ相手の首から離れる側へ開き、そこから機体へ閉じる（交差して自分の首の上を通らない）
  S.parts.forEach((n, j) => { const o = sub(n.strike, S.parts[1 - j].strike), d = fromA(S.aims[j]), side = Math.sign(d.x * o.y - d.y * o.x) || (j === 0 ? 1 : -1), f = clamp((S.mt - r.pincer_delay) / r.pincer_time); n.angle = S.aims[j] + side * (r.pincer_open_angle + (r.pincer_close_angle - r.pincer_open_angle) * f); });
}
function hmPincerDraw(S, R) {
  const r = S.r, poses = new Map(S.parts.map(n => [n, hmPose(S, n, r.pincer_delay)])), col = HM_COLORS.beam;
  if (R.proto && S.age >= 0) for (const n of S.parts) {
    const p = poses.get(n), M = hmMouth(n, p), A = toL(M), B = toL(add(M, mul(fromA(n.angle), r.beam_len))), e = S.mt - r.pincer_delay;
    if (e < 0) { const k = clamp(S.age / (r.warning_time + r.pincer_delay)); hmEyes(S, R, n, p, k, col); if (S.aims) FX.warnRail(R.front, A, B, { color: col, k, time: S.t, seed: 6 + S.parts.indexOf(n), maxLv: 2, intensity: R.P.intensity }); hmGather(S, R, M, k, col, 3 + S.parts.indexOf(n)); }
    else if (e < r.pincer_time + 0.12) { const from = clamp((e - r.pincer_time + 0.05) / 0.12); FX.beam(R.front, A, B, { w: r.beam_width * 0.5 * WL * R.P.size, source: false, color: col, time: S.t, from, to: clamp(e / 0.07), taper: 6, alpha: 1, intensity: R.P.intensity }); FX.flare(R.front, A, 1.4 * R.P.size, col, S.t, 0.5 * (1 - from), 4); hmEyes(S, R, n, p, 0.6, col); }
  }
  R.blitBack(); hmDrawBody(S, R, poses);
  if (!R.proto && S.aims) for (const n of S.parts) { const A = n.strike, B = add(A, mul(fromA(n.angle), r.beam_len)), e = S.mt - r.pincer_delay; if (e < 0) D2.line(A, B, rgba('#ff4066', 0.35), 3); else if (e < r.pincer_time) D2.roundBeam(A, B, rgba('#ff4066', 0.85), r.beam_width); }
  drawShip(S.ship);
}

const HM_STATUS = { '状態': '作り直しの試作（未承認）。本番への組み込みは本人の承認後', '動きと判定': '参加する首・時刻・軌道・範囲は main の C++（technique.cpp と各技）と .tres の値のまま。試作の姿勢は絵の位置・向き・大きさだけ' };
const HM_PARAMS = H_PARAMS;
function hmRegister(id, ids, o, tick, draw, desc) {
  const r = hRule(id);
  DEMOS.push({ id: 'H-' + id, ids, cat: 'うみへび座（H）', group: 'うみへび座', title: r.display_name, duration: r.warning_time + r.performance_time + (o.extra ?? 1.6), color: o.color,
    params: HM_PARAMS, status: { ...HM_STATUS, '作り': desc }, refs: ['cpp/bosses/hydra/technique.cpp・' + id + '.cpp', 'data/bosses/hydra_moves/' + id + '.tres'],
    setup(S) { hmSetup(S, id, o); S.P = P(); }, step(S, dt) { hmStep(S, dt, tick); }, draw(S, R) { S.P = R.P; draw(S, R); }, phase: hmPhase });
}
hmRegister('tornado', ['H04', 'H08', 'H13'], { kinds: ['vortex', 'debris'], color: HM_COLORS.vortex, ship: V(520, 60) }, hmTornadoTick, hmTornadoDraw,
  '予兆：渦の首と瓦礫の首が左右へ開き、渦の首は目が光ってため、瓦礫の首は首の瓦礫を口へ送って噛み砕く → 風の首の口元にまわりの風が巻きながら集まり、小さな渦が少しずつ育つ。らせんの腕が中心へ巻き込み、緑の風の腕に瓦礫の砂ぼこりの腕が混ざる。育った渦へ瓦礫の首が岩をまっすぐ打ち込み、岩は土ぼこりを上げて捕まり、渦の中を回る。砂利と葉も外から巻き込まれる → 渦が機体の方向へ走り、通った跡に土ぼこりが残る → 寿命の終わりに岩が外へ放り出され、渦が薄れて消える');
hmRegister('debris_shatter', ['H04', 'H08', 'H14'], { kinds: ['debris', 'beam'], color: HM_COLORS.beam, ship: V(722, 60) }, hmShatterTick, hmShatterDraw,
  '予兆：瓦礫の首は吐く方向を向いて瓦礫を噛み砕き、ビームの首は目が光って口に光を集める → 岩6つを扇に打ち出す。扇の真ん中が機体を狙い、岩は打ち出しから同じ速さでまっすぐゆっくり進む（速さに合わせた土煙の尾）。ビームの首は振り始めの向きに照準の光（白くしない）→ 光線が弧を薙ぎ、当たった岩は閃光と欠片・土ぼこりを出して砕け、赤く熱い破片6つが尾を引いて飛び、冷えて石の色になる');
hmRegister('beam_pincer', ['H04', 'H10', 'H15'], { kinds: ['beam', 'beam'], color: HM_COLORS.beam, ship: V(560, 0) }, hmPincerTick, hmPincerDraw,
  '予兆：2本のビームの首が目を光らせ、口へ光を集め、左右に開いた向きへ照準の光（白くしない）→ 2本の光線が左右から機体の方向へ閉じていく → 根元から消える');

// ---------- 噛みつきの大技で使う、首ごとの伸びと噛む衝撃
function hmFront(S, count = 3) { const aim = angOf(sub(S.ship.pos, S.B.pos)); return S.necks.slice().sort((a, b) => Math.abs(angDiff(a.baseAngle + S.B.facing, aim)) - Math.abs(angDiff(b.baseAngle + S.B.facing, aim))).slice(0, count); }
function hmTurnBody(S, dt) { // front_body：参加する首の真ん中が機体を向くように本体を回す
  let mx = 0, my = 0; for (const n of S.parts) { mx += Math.cos(n.baseAngle); my += Math.sin(n.baseAngle); }
  S.B.facing += clamp(angDiff(angOf(sub(S.ship.pos, S.B.pos)) - Math.atan2(my, mx), S.B.facing), -HYDRA.def.turn * dt, HYDRA.def.turn * dt);
}
// 伸びる首の見た目：fire（伸び始めの時刻）の前はS字にためて震え、伸びたら頭の残像と空気の筋、着いたら牙と閃光
function hmLungePose(S, n, fire, flight) {
  const out = { head: n.pos, angle: n.angle, sx: 1, sy: 1, coil: 0 }, t = S.mt, fw = fromA(n.angle); if (!n.major || S.age < 0) return out;
  const rel = t - fire;
  if (rel < 0) { const u = clamp(S.age / Math.max(0.01, S.r.warning_time + fire)); out.coil = smooth(0, 0.6, u); const fz = smooth(0.6, 0.85, u); out.head = add(add(n.pos, mul(fw, -12 * out.coil * S.P.coil)), mul(orth(fw), Math.sin(S.t * 95 + n.baseAngle) * 1.5 * fz)); out.sy = 1 - 0.07 * out.coil; out.sx = 1 + 0.05 * out.coil; }
  else if (rel < flight) { const k = rel / flight; out.sy = 1 + 0.14 * Math.sin(Math.PI * k); out.sx = 1 - 0.06 * Math.sin(Math.PI * k); }
  else { const a = rel - flight, j = Math.exp(-a / 0.07) * Math.sin(Math.min(1, a / 0.05) * Math.PI); out.head = add(n.pos, mul(fw, 9 * j * S.P.snap)); }
  return out;
}
function hmLungeNeck(S, n, pose) { // ため：S字。伸びたあと：波が根元へ抜ける
  const pts = n.points, N = pts.length - 1, dir = norm(sub(pts[N], pts[0])), side = orth(dir), d = sub(pose.head, n.pos);
  const q = n.rec, tau = q ? S.age - q.start : 0, wave = q && tau > 0 ? 34 * Math.pow(1 - clamp(tau / q.T), 0.7) * smooth(0, 0.15, tau) : 0; // 戻るあいだ、うねりが頭から根元へ走る
  return pts.map((p, i) => { const u = i / N; let o = Math.sin(u * TAU) * Math.sin(u * Math.PI) * 18 * pose.coil * S.P.coil + (wave ? Math.sin(u * 7.5 + tau * 11 + q.ph) * Math.sin(u * Math.PI) * wave * q.side : 0); return add(add(p, mul(side, o)), mul(d, u * u)); });
}
function hmBiteFx(S, R, n, from, to, fire, flight, color, seed) {
  const pal = FX.ramp(color), rel = S.mt - fire; if (rel < 0 || !from) return;
  const fw = norm(sub(to, from)), sd = orth(fw), L = dist(from, to), speed = L / flight, head = Math.min(L, rel * speed);
  if (rel < flight + 0.2) for (const side of [-1, 1]) for (let j = 0; j < 2; j++) { // 両脇の空気の筋
    const id = side * 7 + j * 3 + seed, life = (0.05 + 0.07 * hash(id + 4)) * R.P.timing, base = (22 + 9 * j + 6 * hash(id)) * R.P.size;
    for (let s = 0; s < head; s += 0.6 / WL) { const age = (head - s) / speed + Math.max(0, rel - flight), k = age / life; if (k >= 1) continue; const q = toL(add(add(from, mul(fw, s)), mul(sd, side * (base + age * 160 + Math.sin(s * 0.045 + id) * 3)))); R.front.dot(q.x, q.y, pal[k < 0.3 ? 3 : 2], (1 - k) * 0.75); }
  }
  const t = (rel - flight + 0.03) / R.P.timing; if (t < 0 || t > 0.6) return;
  const mouth = add(to, mul(fw, hMouthDist(n))), Rr = S.r.bite_radius * R.P.size * R.P.snap, p = clamp(t / 0.05), out = clamp((t - 0.05) / 0.16);
  for (const side of [-1, 1]) { // 上下の牙の鉤
    const P0 = add(add(mouth, mul(sd, side * Rr * 0.8)), mul(fw, 0.1 * Rr)), C = add(add(mouth, mul(sd, side * Rr * 0.72)), mul(fw, 0.72 * Rr)), P1 = add(add(mouth, mul(fw, 0.92 * Rr)), mul(sd, side * Rr * 0.14)), steps = Math.ceil(Rr * 2.2 * WL);
    for (let i = 0; i <= steps; i++) { const u = i / steps; if (u > p || u < out) continue; if (out > 0.3 && hash(i * 7 + side * 3 + seed + Math.floor(t * 40)) > (1 - out) * 1.6) continue;
      const q = toL(add(add(mul(P0, (1 - u) ** 2), mul(C, 2 * u * (1 - u))), mul(P1, u * u))), w = (0.3 + 1.3 * Math.sin(Math.PI * u) ** 0.7) * R.P.size * (1 - out * 0.6);
      for (let o = -w; o <= w; o += 0.5) { const e = Math.abs(o) / Math.max(0.3, w); R.front.px(q.x + sd.x * o * side, q.y + sd.y * o * side, pal[(p - u < 0.25 || e < 0.35) && out < 0.5 ? 4 : e < 0.7 ? 3 : 2]); } }
  }
  const hit = toL(add(mouth, mul(fw, 0.45 * Rr))), fl = Math.exp(-Math.max(0, t - 0.04) / 0.06);
  if (t > 0.03 && fl > 0.05) { for (const [u, l] of [[fw, 13], [mul(fw, -1), 4], [sd, 6], [mul(sd, -1), 5]]) for (let d = 0; d <= l * R.P.size * fl; d += 0.5) { const a = 1 - d / (l * R.P.size * fl + 0.01); R.front.light(hit.x + u.x * d, hit.y + u.y * d, pal[a > 0.6 ? 4 : 3], a * 0.9 * R.P.intensity); } R.front.px(hit.x, hit.y, pal[4]); }
  hDust(S, R, add(mouth, mul(fw, 0.3 * Rr)), t - 0.05, 41 + seed, angOf(fw), 0.8);
}
// 着地点の予告：機体の位置に、牙の形の光が小さくちらつき、狙いが決まると止まって強まる（円は描かない）
function hmMarkFx(S, R, n, at, dirA, k, locked, color, seed) {
  const pal = FX.ramp(color), fw = fromA(dirA), sd = orth(fw), Rr = S.r.bite_radius * 0.8 * R.P.size, jit = locked ? 0 : 1;
  for (const side of [-1, 1]) { const P0 = add(at, mul(sd, side * Rr)), P1 = add(at, mul(fw, Rr * 0.7)), steps = Math.ceil(Rr * 1.6 * WL);
    for (let i = 0; i <= steps; i++) { const u = i / steps, q = toL(add(add(lerpV(P0, P1, u), mul(sd, side * Math.sin(u * Math.PI) * Rr * 0.25)), V((hash(i + seed + Math.floor(S.t * 20)) - 0.5) * 6 * jit, 0))); if (hash(i * 3 + seed + Math.floor(S.t * 12)) > 0.55 + 0.45 * k) continue; R.back.dot(q.x, q.y, pal[locked ? 3 : 2], (0.25 + 0.55 * k)); } }
  const c = toL(at); R.back.glow(c.x, c.y, 6 * R.P.size, pal[2], 0.2 * k * R.P.intensity);
}

// ---------- 3本の同時噛みつき（north.cpp）
function hmNorthTargets(S) {
  const r = S.r, at = S.B.pos, dir = norm(sub(S.ship.pos, at)), side = orth(dir), center = add(at, mul(dir, Math.max(dist(S.ship.pos, at), S.B.r + HP.neck_rest)));
  const ordered = S.parts.slice().sort((a, b) => { const A = hBase(S, a), B = hBase(S, b); return (A.x * side.x + A.y * side.y) - (B.x * side.x + B.y * side.y); });
  ordered.forEach((n, i) => { n.target = add(center, mul(side, r.north_spread * (i - 1))); });
}
function hmNorthTick(S, dt) {
  const r = S.r, t = S.age, warn = r.warning_time, flight = r.north_flight;
  if (!S.nlocked) { hmTurnBody(S, dt); hmNorthTargets(S); if (t >= r.north_lock_time) S.nlocked = true; }
  for (const n of S.parts) {
    n.moving = true; const b = hBase(S, n);
    if (t < warn) { n.angle += angDiff(angOf(sub(n.target, b)), n.angle) * Math.min(1, dt * 6); n.length += clamp(HP.neck_rest * 0.35 - n.length, -HP.neck_rest * dt * 2, HP.neck_rest * dt * 2); n.pos = add(b, mul(fromA(n.angle), n.length)); n.from = { ...n.pos }; }
    else { const f = Math.min(1, (t - warn) / flight); n.angle = angOf(sub(n.target, n.from)); n.pos = lerpV(n.from, n.target, f); }
  }
}
function hmNorthDraw(S, R) {
  const r = S.r, fire = 0, flight = r.north_flight, col = HM_COLORS.bite, poses = new Map(S.parts.map(n => [n, hmLungePose(S, n, fire, flight)]));
  if (R.proto && S.age >= 0) S.parts.forEach((n, i) => {
    const p = poses.get(n), u = clamp(S.age / r.warning_time);
    if (S.mt < 0) { hmEyes(S, R, n, p, u, col); const M = hmMouth(n, p); FX.warnRail(R.back, toL(M), toL(n.target), { color: col, k: S.nlocked ? 0.6 + 0.4 * u : 0.3 * u, time: S.t, seed: 9 + i, maxLv: 2, intensity: R.P.intensity }); }
    hmBiteFx(S, R, n, n.from, n.target, fire, flight, col, i * 17);
  });
  R.blitBack();
  S.necks.forEach((n, i) => hDrawNeck(S, n, R.proto && poses.has(n) ? hmLungeNeck(S, n, poses.get(n)) : n.points, i));
  hStamp('body', null, S.B.pos, S.B.facing, S.B.r * 2 / IMG['hydra/body'].width);
  for (const n of S.necks) { const p = R.proto && poses.get(n); if (p) hDrawHead(n, p.head, p.angle, p.sx, p.sy); else hDrawHead(n, n.pos, n.angle); }
  if (!R.proto && S.age >= 0 && S.mt < 0) for (const n of S.parts) { const c = S.nlocked ? '#fff2b0' : '#ffd16c'; D2.line(n.pos, n.target, rgba(c, 0.55), 3); D2.arc(n.target, r.bite_radius, 0, TAU, c, 3); }
  drawShip(S.ship);
}

// ---------- 順番に伸ばす噛みつき（sequence.cpp）
function hmSeqTick(S, dt) {
  const r = S.r; hmTurnBody(S, dt); if (S.mt < 0) return;
  S.parts.forEach((n, i) => { const local = S.mt - i * r.sequence_gap; if (local < 0) return;
    if (!n.locked) { n.target = { ...S.ship.pos }; if (local < r.sequence_charge) return; n.locked = true; n.from = { ...n.strike }; n.angle = angOf(sub(n.target, n.from)); }
    n.moving = true; n.pos = lerpV(n.from, n.target, clamp((local - r.sequence_charge) / r.normal_lunge)); });
}
function hmSeqDraw(S, R) {
  const r = S.r, col = HM_COLORS.bite, poses = new Map(S.parts.map((n, i) => [n, hmLungePose(S, n, i * r.sequence_gap + r.sequence_charge, r.normal_lunge)]));
  if (R.proto && S.age >= 0) S.parts.forEach((n, i) => {
    const p = poses.get(n), fire = i * r.sequence_gap + r.sequence_charge, k = clamp(S.age / (r.warning_time + fire));
    if (S.mt < fire) { hmEyes(S, R, n, p, k, col); if (S.mt > fire - r.sequence_charge) { const M = hmMouth(n, p); FX.warnRail(R.back, toL(M), toL(n.target || S.ship.pos), { color: col, k: 0.4 + 0.6 * k, time: S.t, seed: 12 + i, maxLv: 2, intensity: R.P.intensity }); } }
    hmBiteFx(S, R, n, n.from, n.target, fire, r.normal_lunge, col, i * 19);
  });
  R.blitBack();
  S.necks.forEach((n, i) => hDrawNeck(S, n, R.proto && poses.has(n) ? hmLungeNeck(S, n, poses.get(n)) : n.points, i));
  hStamp('body', null, S.B.pos, S.B.facing, S.B.r * 2 / IMG['hydra/body'].width);
  for (const n of S.necks) { const p = R.proto && poses.get(n); if (p) hDrawHead(n, p.head, p.angle, p.sx, p.sy); else hDrawHead(n, n.pos, n.angle); }
  drawShip(S.ship);
}

// ---------- 回転するビーム（curve.cpp を元に見た目を変更）：首を伸ばし、頭だけ傾けて直線のビームを撃つ。本体の回転で風車のように回る
function hmCurvePoints(S, n) { const r = S.r, pts = [add(hBase(S, n), mul(fromA(n.angle), HP.neck_rest))]; for (let j = 1; j <= 24; j++) pts.push(add(pts[pts.length - 1], mul(fromA(n.angle - j / 24 * r.curve_lag), r.beam_len / 24))); return pts; }
const HM_CURVE_TILT = 35 * Math.PI / 180;
function hmCurveTick(S, dt) {
  const r = S.r; if (S.mt >= 0) S.B.facing += r.curve_turn * dt;
  // 首は伸ばしきらず弓なりに曲げ、先が頭の向きへつながる。長さはゆるく呼吸する
  const ext = smooth(0, 1, clamp(S.age / r.warning_time)); for (const n of S.parts) { n.moving = true; const b = hBase(S, n), home = n.baseAngle + S.B.facing; n.curveFrom ??= { a: angOf(sub(n.pos, b)), L: dist(n.pos, b) }; n.angle = home + angDiff(n.curveFrom.a, home) * (1 - ext); n.tilt = -HM_CURVE_TILT * ext; const goal = HP.neck_rest * (1.3 + 0.035 * Math.sin(S.t * 2.6 + n.baseAngle * 3) * ext), L = lerp(n.curveFrom.L, goal, ext); n.bend = L * 0.2 * ext; n.pos = add(b, mul(fromA(n.angle), L)); } // 今の向きと長さから予兆のあいだになめらかに移る
}
function hmPolyBeam(S, R, pts, w, color, a0, a1, k) { // 折れ線に沿う光の帯。芯が白く、縁へ冷え、流れる明るさの山が先へ走る。先ほど細い
  const pal = FX.ramp(color), L = pts.map(toL); let total = 0; const seg = []; for (let i = 1; i < L.length; i++) { const l = dist(L[i - 1], L[i]); seg.push(l); total += l; }
  let s0 = 0;
  for (let i = 1; i < L.length; i++) { const A = L[i - 1], B = L[i], u = norm(sub(B, A)), nr = orth(u);
    for (let d = 0; d < seg[i - 1]; d += 0.5) { const s = s0 + d, f = s / total; if (f < a0 || f > a1) continue;
      const tp = Math.min(1, (f - a0) / 0.02 + 0.3, (a1 - f) / 0.25 + 0.15), ww = Math.max(0.6, w * 0.5 * tp), x = A.x + u.x * d, y = A.y + u.y * d, flow = 0.75 + 0.25 * Math.sin(s * 0.35 - S.t * 38);
      for (let o = -ww; o <= ww; o += 0.5) { const e = Math.abs(o) / ww, lv = e < 0.28 * flow ? 4 : e < 0.62 ? 3 : 2; if (e > 0.8 && hash(s * 3 + o * 7 + Math.floor(S.t * 30)) > k) continue; R.front.px(x + nr.x * o, y + nr.y * o, pal[lv]); }
      if (Math.floor(s) % 2 === 0) R.front.light(x, y, pal[2], 0.3 * k * R.P.intensity); }
    s0 += seg[i - 1]; }
}
function hmCurveDraw(S, R) {
  const r = S.r, col = HM_COLORS.beam, poses = new Map(S.parts.map(n => { const p = hmPose(S, n, r.curve_delay); if (n.tilt) p.angle += n.tilt; return [n, p]; }));
  if (R.proto && S.age >= 0) for (const n of S.parts) {
    const p = poses.get(n), M = hmMouth(n, p), A = toL(M), B = toL(add(M, mul(fromA(p.angle), r.beam_len ?? 1400))), e = S.mt - r.curve_delay;
    if (e < 0) { const k = clamp(S.age / (r.warning_time + r.curve_delay)); hmEyes(S, R, n, p, k, col); hmGather(S, R, M, k, col, S.parts.indexOf(n) + 21); }
    else if (S.mt < r.curve_time + 0.15) { const from = clamp((S.mt - r.curve_time) / 0.15); FX.beam(R.front, A, B, { w: r.beam_width * 0.5 * WL * R.P.size, source: false, color: col, time: S.t, from, to: clamp(e / 0.07), taper: 6, alpha: 1, intensity: R.P.intensity }); FX.flare(R.front, A, 1.4 * R.P.size, col, S.t, 0.5 * (1 - from), 4); hmEyes(S, R, n, p, 0.6, col); }
  }
  R.blitBack(); hmDrawBody(S, R, poses);
  if (!R.proto && S.mt >= r.curve_delay && S.mt < r.curve_time) for (const n of S.parts) D2.polyline(hmCurvePoints(S, n), rgba('#ff4066', 0.85), r.beam_width);
  drawShip(S.ship);
}
hmRegister('north', ['H16'], { kinds: null, color: HM_COLORS.bite, ship: V(430, 60), facing: 0, front: 3 }, hmNorthTick, hmNorthDraw,
  '予兆：本体を回して前の3本が機体を向き、首を縮めてS字にためる。目が赤く強まり、頭から着地点へ照準の光。狙いが決まると止まって強まる → 3本が同時に伸び、空気の筋と、着地点で牙の鉤・閃光・土ぼこり → 頭は伸びた位置で止まる');
hmRegister('sequence', ['H17'], { kinds: null, color: HM_COLORS.bite, ship: V(430, 60), facing: 0, front: 3 }, hmSeqTick, hmSeqDraw,
  '予兆：前の3本が順に目を光らせ、自分の番の直前に照準の光を出してS字にためて止まる → 0.55秒ずつずれて1本ずつ伸びて噛む（空気の筋・牙・閃光）→ 噛み終えた頭はその場で止まる');
hmRegister('curve', ['H18'], { kinds: null, color: HM_COLORS.beam, ship: V(500, 60), facing: 0 }, hmCurveTick, hmCurveDraw,
  '予兆：全部の首を弓なりに曲げて、頭を左へ35度傾ける。目が光り、口に光が集まる → まっすぐのビームを全部の首から撃つ。本体の回転で風車のように回り、首はゆるく呼吸する → 終わると全部の首が一緒になめらかに戻る');

// ---------- 分離後の蛇（swim.cpp：steer と follow を写す）
function hsSteer(S, n, target, dt, scale = 1) {
  const o = sub(target, n.pos), prior = n.angle; if (len(o) > 1) n.angle += clamp(angDiff(angOf(o), n.angle), -HP.snake_turn * dt, HP.snake_turn * dt);
  const speed = HP.snake_speed * scale * clamp(len(o) / 100) * (0.3 + 0.7 * Math.max(0, Math.cos(angDiff(angOf(o), n.angle))));
  n.vel = lerpV(n.vel, mul(fromA(n.angle), speed), 1 - Math.exp(-HP.snake_accel * dt)); n.pos = add(n.pos, mul(n.vel, dt)); n.turn = angDiff(n.angle, prior) / Math.max(dt, 0.001);
}
function hsFollow(S, n, dt) { // 頭の通った道を胴がたどり、速さに応じてうねる
  const count = HP.neck_segments, head = n.pos;
  if (!n.trail) { n.trail = []; for (let i = 0; i <= count; i++) n.trail.push(sub(head, mul(fromA(n.angle), HP.neck_rest * i / count))); n.w0 = 0; }
  if (dist(head, n.trail[0]) >= 4) n.trail.unshift({ ...head }); if (n.trail.length > 256) n.trail.length = 256;
  n.w0 += (clamp(len(n.vel) / HP.snake_speed) - n.w0) * (1 - Math.exp(-8 * dt));
  const path = [head, ...n.trail], pts = new Array(count + 1); pts[count] = head; let cursor = 1, at = head;
  for (let i = 1; i <= count; i++) { let need = HP.neck_rest / count; while (cursor < path.length && dist(at, path[cursor]) < need) { need -= dist(at, path[cursor]); at = path[cursor++]; }
    const d = cursor < path.length ? norm(sub(path[cursor], at)) : mul(fromA(n.angle), -1); at = add(at, mul(d, need)); const f = i / count, amp = HP.neck_wave_amplitude * (0.3 + 0.7 * n.w0), wave = Math.sin(S.t * HP.neck_wave_speed * 2 - f * TAU * HP.neck_wave_frequency + n.baseAngle) * amp * Math.sin(f * Math.PI);
    pts[count - i] = add(at, mul(orth(d), wave)); }
  n.points = pts;
}
function hsDraw(S, n, pts, index) { // 分離後：尾の細い部品と先端、通常の節。不死の蛇は頭の後ろに羅針盤の首
  const f = H_F(), total = pathLength(pts); if (total < 0.1) return; const imm = n.kind === 'immortal';
  for (const [d, region] of [[10 * f, { x: 104, y: 0, w: 16, h: 32 }], [30 * f, { x: 130, y: 0, w: 28, h: 32 }]]) { const q = pathAt(pts, d); hStamp('neck', region, q.pos, q.angle - Math.PI / 2, f); }
  const end = imm ? Math.max(38 * f, total - 58 * f) : total;
  for (let d = 38 * f, tile = 0; d <= end; d += Math.max(1, 14 * f), tile++) { const q = pathAt(pts, d); hStamp('neck', { x: ((index + tile) % 3) * 32, y: 0, w: 32, h: 32 }, q.pos, q.angle - Math.PI / 2, f); }
  if (imm) { const q = pathAt(pts, Math.max(0, total - 30 * f)); hStamp('undead', { x: 12, y: 3, w: 76, h: 76 }, q.pos, q.angle - Math.PI / 2, f); }
}
function hsSetup(S, id, slots, bearerAt) {
  S.tech = id; S.r = hRule(id); S.B = bossActor('hydra', V(0, 0)); S.age = -999; S.pos0 = 0; S.positioning = true; S.necks = []; S.shots = []; S.ship = shipState(V(0, 0), -Math.PI / 2, 0); S.ship.vel = V(0, 0);
  slots.forEach((slot, i) => { const start = add(mul(slot, 0.55), V((hash(i * 3.1) - 0.5) * 160, (hash(i * 5.7) - 0.5) * 160)), n = { kind: H_KINDS[i % 8], baseAngle: i * 1.3, angle: angOf(sub(slot, start)), pos: start, vel: V(0, 0), slot, hist: [] }; S.necks.push(n); });
  S.bearer = { kind: 'immortal', baseAngle: 9, angle: Math.PI, pos: add(bearerAt, V(120, 60)), vel: V(0, 0), slot: bearerAt, hist: [] };
  for (const n of [...S.necks, S.bearer]) { n.trail = null; hsFollow(S, n, 1 / 60); }
}
function hsStep(S, dt, tick) {
  S.t2 = (S.t2 || 0) + dt;
  if (S.positioning) { let ready = true; for (const n of [...S.necks, S.bearer]) { if (dist(n.pos, n.slot) > 45) { hsSteer(S, n, n.slot, dt, 1.8); ready = false; } else { const v = sub(n.slot, n.pos); n.vel = mul(norm(v), Math.min(100, len(v))); n.pos = add(n.pos, mul(n.vel, dt * 4)); if (dist(n.pos, n.slot) > 6) ready = false; } }
    if (ready || S.t2 > 6) { S.positioning = false; S.age = -0.2; for (const n of S.necks) { n.strike = { ...n.pos }; n.vel = V(0, 0); n.major = true; } } }
  else { S.age += dt; S.mt = S.age - S.r.warning_time; tick(S, dt); }
  for (const n of [...S.necks, S.bearer]) { if (!S.positioning && n !== S.bearer && !n.moving) { n.vel = mul(n.vel, Math.exp(-6 * dt)); } if (n === S.bearer && !S.positioning) n.angle += angDiff(angOf(sub(S.ship.pos, n.pos)), n.angle) * Math.min(1, dt * 2); hsFollow(S, n, dt); n.hist.push({ t: S.t, pos: { ...n.pos }, angle: n.angle }); if (n.hist.length > 48) n.hist.shift(); }
}
function hsPhase(S) { const r = S.r; return S.positioning ? '配置へ泳ぐ' : S.mt < 0 ? '予兆（構え）' : S.age < r.warning_time + r.performance_time ? '攻撃中' : '全体の硬直（攻めどき）'; }
function hsBody(S, R, poses) {
  [...S.necks, S.bearer].forEach((n, i) => { const p = R.proto && poses.get(n); hsDraw(S, n, p ? hmVisNeck(S, n, p) : n.points, i); });
  for (const n of [...S.necks, S.bearer]) { const p = R.proto && poses.get(n); if (p) hDrawHead(n, p.head, p.angle, p.sx, p.sy); else hDrawHead(n, n.pos, n.angle); }
}

// ---------- 格子ビーム（試作：泳ぐ蛇が順番に止まって機体を狙い、撃ったビームが残る）
const HM_GRID = { start: 1.4, gap: 0.7, stop: 0.75, lock: 0.4, dodge: 0.22, leave: 1, hold: 1.9, reach: 380, routeSpeed: 2200 };
function hmGridSlots() { return Array.from({ length: 8 }, (_, i) => { const a = i * Math.PI / 4 + 0.3 + (hash(i * 2.3) - 0.5) * 0.5, r = 430 + hash(i * 4.1) * 130; return V(Math.cos(a) * r * 1.25, Math.sin(a) * r * 0.82); }); }
function hmGridSetup(S) {
  S.positioning = false; S.age = 0; S.mt = 0; S.fired = 0; S.move = null; S.route = null; S.struck = null;
  S.gridEnd = HM_GRID.start + (S.necks.length - 1) * HM_GRID.gap + HM_GRID.hold;
  S.necks.forEach((n, i) => { const side = i % 2 ? 1 : -1; n.pos = { ...n.slot }; n.angle = angOf(n.pos) + Math.PI / 2 * side; n.orbit = { a: angOf(n.pos), r: len(n.pos), w: side * (0.16 + hash(i * 6.7) * 0.1) }; n.trail = null; hsFollow(S, n, 1 / 60); });
  S.bearer.pos = { ...S.bearer.slot }; S.bearer.trail = null; hsFollow(S, S.bearer, 1 / 60);
}
function hmGridPick(S) { // 機体から見て、これまでに撃った蛇と離れた方向にいる蛇を次に選ぶ
  const bearing = n => angOf(sub(n.pos, S.ship.pos)), used = S.necks.filter(n => n.fireAt != null).map(bearing);
  const score = n => used.length ? Math.min(...used.map(a => Math.abs(angDiff(bearing(n), a)))) : -dist(n.pos, S.ship.pos);
  return S.necks.filter(n => n.fireAt == null).reduce((best, n) => score(n) > score(best) ? n : best);
}
function hmGridBeamDist(p, n) { const d = sub(n.end, n.pos), u = clamp(((p.x - n.pos.x) * d.x + (p.y - n.pos.y) * d.y) / (d.x * d.x + d.y * d.y)); return dist(p, add(n.pos, mul(d, u))); }
function hmGridClearance(S, p, skip) { return Math.min(Infinity, ...S.necks.filter(n => n.end && n !== skip).map(n => hmGridBeamDist(p, n))); }
function hmGridDodge(S, n) { // 実演の機体：狙われたら横へよける。残ったビームをまたがず、不死の蛇へ近づく向きを選ぶ
  const from = S.ship.pos, base = n.angle + Math.PI / 2, options = [];
  for (const sign of [0, Math.PI]) for (const lean of [0, 0.6, -0.6]) for (const step of [130, 170, 240, 310]) options.push(add(from, mul(fromA(base + sign + lean), step)));
  const score = p => (hmGridClear(S, from, p, n) ? 4000 : 0) + (Math.abs(p.x) < 620 && Math.abs(p.y) < 400 ? 2000 : 0) + Math.min(hmGridClearance(S, p), 150) * 2 - dist(p, S.bearer.pos) * 0.5, to = options.reduce((best, p) => score(p) > score(best) ? p : best);
  S.move = { from: { ...S.ship.pos }, to, at: S.age, time: 0.2 };
}
function hmGridClear(S, a, b, skip) { const L = dist(a, b); for (let d = 0; d <= L; d += 20) if (hmGridClearance(S, lerpV(a, b, d / Math.max(L, 1)), skip) < 38) return false; return true; }
function hmGridRoute(S) { // 実演の機体：隙間をたどって不死の蛇へ向かう。格子を幅優先で探し、まっすぐ通れる所は1本にまとめる
  const from = { ...S.ship.pos }, to = add(S.bearer.pos, mul(norm(sub(from, S.bearer.pos)), 110)), cell = 40, key = (x, y) => x + ',' + y, cellOf = p => [Math.round(p.x / cell), Math.round(p.y / cell)], [sx, sy] = cellOf(from), [gx, gy] = cellOf(to), back = new Map([[key(sx, sy), null]]), open = [[sx, sy]];
  while (open.length && !back.has(key(gx, gy))) { const [x, y] = open.shift(); for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) { const nx = x + dx, ny = y + dy, id = key(nx, ny); if (back.has(id) || Math.abs(nx) > 24 || Math.abs(ny) > 14 || hmGridClearance(S, V(nx * cell, ny * cell)) < 40) continue; back.set(id, [x, y]); open.push([nx, ny]); } }
  if (!back.has(key(gx, gy))) return [from, to];
  const cells = []; for (let at = [gx, gy]; at; at = back.get(key(at[0], at[1]))) cells.unshift(V(at[0] * cell, at[1] * cell)); cells[0] = from; cells[cells.length - 1] = to;
  const route = [from]; for (let i = 0; i < cells.length - 1;) { let j = cells.length - 1; while (j > i + 1 && !hmGridClear(S, cells[i], cells[j])) j -= 1; route.push(cells[j]); i = j; }
  return route;
}
function hmGridShip(S) {
  const ship = S.ship; let aim = null;
  if (S.move) { const m = S.move, u = clamp((S.age - m.at) / m.time); aim = sub(m.to, m.from); ship.pos = lerpV(m.from, m.to, smooth(0, 1, u)); if (u >= 1) S.move = null; }
  else if (S.routeAt != null && S.age >= S.routeAt && !S.struck) { let left = (S.age - S.routeAt) * HM_GRID.routeSpeed, at = S.route[0]; S.struck = S.age; for (let i = 1; i < S.route.length; i++) { const l = dist(S.route[i - 1], S.route[i]); aim = sub(S.route[i], S.route[i - 1]); if (left < l) { at = lerpV(S.route[i - 1], S.route[i], left / l); S.struck = null; break; } left -= l; at = S.route[i]; } ship.pos = at; }
  ship.speed = aim ? 300 : 0; if (aim) ship.heading = angOf(aim); else ship.heading += angDiff(angOf(sub(S.bearer.pos, ship.pos)), ship.heading) * 0.04;
}
function hmGridTick(S, dt) {
  const G = HM_GRID, total = S.necks.length, last = G.start + (total - 1) * G.gap;
  while (S.fired < total && S.age >= G.start + S.fired * G.gap - G.stop) { const n = hmGridPick(S); n.fireAt = G.start + S.fired * G.gap; n.major = true; n.moving = false; S.fired += 1; }
  for (const n of S.necks) {
    if (n.fireAt == null) { n.orbit.a += n.orbit.w * dt; n.moving = true; hsSteer(S, n, V(Math.cos(n.orbit.a) * n.orbit.r * 1.25 + S.ship.pos.x * 0.3, Math.sin(n.orbit.a) * n.orbit.r * 0.82 + S.ship.pos.y * 0.3), dt, 0.9); continue; }
    if (S.age < n.fireAt - G.lock) n.angle += angDiff(angOf(sub(S.ship.pos, n.pos)), n.angle) * Math.min(1, dt * 10);
    else if (!n.end) { const d = norm(sub(S.ship.pos, n.pos)); n.angle = angOf(d); n.end = add(S.ship.pos, mul(d, G.reach)); }
    if (n.end && !n.dodged && S.age >= n.fireAt - G.dodge) { n.dodged = true; hmGridDodge(S, n); }
  }
  if (!S.route && !S.move && S.age >= last + G.leave - 0.5) { S.route = hmGridRoute(S); S.routeAt = last + G.leave; }
  hmGridShip(S);
}
function hmGridPose(S, n) { if (n.fireAt == null) return { head: n.pos, angle: n.angle, sx: 1, sy: 1 }; const rel = S.age - n.fireAt; return hmPose({ age: HM_GRID.stop + rel, mt: rel, t: S.t, P: S.P, r: { warning_time: HM_GRID.stop } }, n, 0); }
function hmGridPhase(S) { const G = HM_GRID, last = G.start + (S.necks.length - 1) * G.gap; return S.age < last ? '蛇が泳ぎ、順番に止まって撃つ' : S.age < S.gridEnd ? 'ビームが残り、隙間を抜ける' : '全体の硬直（攻めどき）'; }
function hmGridDraw(S, R) {
  const G = HM_GRID, r = S.r, col = HM_COLORS.beam, poses = new Map(S.necks.map(n => [n, hmGridPose(S, n)]));
  if (R.proto) S.necks.forEach((n, i) => {
    if (n.fireAt == null) return; const p = poses.get(n), M = hmMouth(n, p), rel = S.age - n.fireAt;
    if (rel < 0) { const k = clamp(1 + rel / G.stop), end = n.end || add(S.ship.pos, mul(fromA(p.angle), G.reach)); hmEyes(S, R, n, p, k, col); hmGather(S, R, M, k, col, 40 + i); FX.warnRail(R.front, toL(M), toL(end), { color: col, k: n.end ? 1 : 0.35, time: S.t, seed: 50 + i, maxLv: 2, intensity: R.P.intensity }); }
    else if (S.age < S.gridEnd + 0.12) { const from = clamp((S.age - S.gridEnd) / 0.12), A = toL(M); hmPolyBeam(S, R, [M, n.end], r.beam_width * WL * R.P.size, col, from, clamp(rel / 0.07), 1); R.front.glow(A.x, A.y, 4 * R.P.size, FX.ramp(col)[3], 0.4 * (1 - from) * R.P.intensity); hmEyes(S, R, n, p, 0.5, col); }
  });
  if (R.proto) { const k = 0.6 + 0.4 * Math.sin(S.t * 6); hmEyes(S, R, S.bearer, { head: S.bearer.pos, angle: S.bearer.angle, sx: 1, sy: 1 }, 0.4 * k, '#ffe69a'); }
  if (R.proto && S.struck != null) { const k = 1 - clamp((S.age - S.struck) / 0.5), A = toL(S.bearer.pos); if (k > 0) R.front.glow(A.x, A.y, 26 * R.P.size, '#ffffff', 0.7 * k * R.P.intensity); }
  R.blitBack(); hsBody(S, R, poses);
  if (S.route && S.age < S.routeAt) for (let i = 1; i < S.route.length; i++) D2.line(S.route[i - 1], S.route[i], rgba('#ffffff', 0.4), 3);
  if (!R.proto) S.necks.forEach(n => { if (n.fireAt == null) return; const end = n.end || add(S.ship.pos, mul(fromA(n.angle), G.reach)); if (S.age < n.fireAt) D2.line(n.pos, end, rgba('#ff4066', 0.35), 3); else if (S.age < S.gridEnd) D2.roundBeam(n.pos, end, rgba('#ff4066', 0.85), r.beam_width); });
  drawShip(S.ship);
}

// ---------- 多方向からの連続飛びかかり（swarm.cpp）
function hmSwarmTick(S, dt) {
  const r = S.r; if (S.mt < 0) { for (const n of S.necks) n.angle += angDiff(angOf(sub(S.ship.pos, n.pos)), n.angle) * Math.min(1, dt * 4); return; }
  S.necks.forEach((n, i) => { const local = S.mt - i * r.swarm_gap; if (local < 0) return;
    if (!n.target) { const d = norm(sub(S.ship.pos, n.strike)); n.from = { ...n.strike }; n.target = add(n.strike, mul(d, r.swarm_reach)); }
    if (local < r.sequence_charge) { n.angle += angDiff(angOf(sub(n.target, n.from)), n.angle) * Math.min(1, dt * 10); return; }
    n.angle = angOf(sub(n.target, n.from)); n.moving = true; const f = clamp((local - r.sequence_charge) / r.swarm_flight); n.pos = lerpV(n.from, n.target, f); n.vel = mul(fromA(n.angle), f < 1 ? r.swarm_reach / r.swarm_flight : 0); });
}
function hmSwarmDraw(S, R) {
  const r = S.r, col = HM_COLORS.bite, poses = new Map(S.necks.map((n, i) => [n, S.positioning ? { head: n.pos, angle: n.angle, sx: 1, sy: 1 } : hmLungePose(S, n, i * r.swarm_gap + r.sequence_charge, r.swarm_flight)]));
  if (R.proto && !S.positioning) S.necks.forEach((n, i) => {
    const p = poses.get(n), fire = i * r.swarm_gap + r.sequence_charge, k = clamp((S.mt - i * r.swarm_gap + r.warning_time) / (r.warning_time + r.sequence_charge));
    if (S.mt < fire) { hmEyes(S, R, n, p, k, col); if (n.target) FX.warnRail(R.back, toL(hmMouth(n, p)), toL(n.target), { color: col, k: 0.4 + 0.6 * k, time: S.t, seed: 60 + i, maxLv: 2, intensity: R.P.intensity }); }
    else if (S.mt < fire + r.swarm_flight) { const back = hAt(n, S.t - 0.05); hSilhouette(R, n, back.pos, back.angle, FX.ramp(col)[2], 0.2 * R.P.intensity, i * 7); }
    hmBiteFx(S, R, n, n.from, n.target, fire, r.swarm_flight, col, i * 23);
  });
  R.blitBack(); hsBody(S, R, poses);
  if (!R.proto && !S.positioning) S.necks.forEach((n, i) => { const fire = i * r.swarm_gap + r.sequence_charge; if (n.target && S.mt < fire) D2.line(n.from, n.target, rgba('#ffd16c', 0.5), 3); });
  drawShip(S.ship);
}
function hsRegister(id, ids, desc, slotsFn, bearerAt, tick, draw, extra) {
  const r = hRule(id);
  DEMOS.push({ id: 'H-' + id, ids, cat: 'うみへび座（H）', group: 'うみへび座', title: r.display_name, duration: 16, color: id === 'grid' ? HM_COLORS.beam : HM_COLORS.bite,
    params: HM_PARAMS, status: { ...HM_STATUS, '作り': desc, '未決・保留': id === 'grid' ? '作り直しの案。蛇の数の下限、撃つ間隔、ビームの残る時間は試作の値。本番の grid.cpp・hydra.tres は5領域の配置のまま' : '群れの陣形・回避は省略し、配置へ泳ぐ所から再生' }, refs: ['cpp/bosses/hydra/' + id + '.cpp・swim.cpp（steer・follow）', 'data/bosses/hydra.tres（grid_layouts・swarm_*・snake_*）'],
    setup(S) { const sl = slotsFn(); hsSetup(S, id, sl.map(s => s.from || s), bearerAt()); S.necks.forEach((n, i) => { n.end = sl[i].to; }); S.ship.pos = V(0, 0); S.P = P(); if (id === 'grid') hmGridSetup(S); }, step(S, dt) { hsStep(S, dt, tick); }, draw(S, R) { S.P = R.P; draw(S, R); }, phase: id === 'grid' ? hmGridPhase : hsPhase });
}
hsRegister('grid', ['H04', 'H10'], '蛇はばらばらに泳ぎ、順番が来た蛇がその場で止まる。機体から見て前の蛇と離れた方向の蛇を選ぶ → 機体を狙い、撃つ直前に狙いを固定 → 撃ったビームはその場に残り、よけた跡が格子になる → 隙間を抜けて不死の蛇へ → 根元から消えて全体の硬直',
  hmGridSlots, () => V(760, -380), hmGridTick, hmGridDraw);
hsRegister('swarm', ['H19'], '画面のまわりの出発位置へ泳ぐ → 順番に目を光らせ、頭から突進の先まで照準の光、S字にためて止まる → 0.3秒ずつずれて一直線に飛びかかり、胴が道をたどってついてくる。頭の形の光と空気の筋、着いた所で牙の鉤と閃光',
  () => { const rx = (W / Z - 140) * 0.45, ry = (H / Z - 140) * 0.45; return Array.from({ length: 6 }, (_, i) => ({ from: V(Math.cos(TAU * i / 6) * rx, Math.sin(TAU * i / 6) * ry), to: null })); }, () => V(-560, 330), hmSwarmTick, hmSwarmDraw);

// ---------- 分離後の見分けやすさ（比較用の試作）：輪郭・落ち影・頭から尾の明暗・蛇ごとの色み・判定のない胴の暗さを、絵の重ね方だけで変える
function hrFilter(P, index, u) { const light = (1 - P.neckDark) * lerp(1, 1 - P.taperShade, u), hue = (index - 3) * 18 * P.tint, sat = 1 + 0.35 * P.tint; return `brightness(${light}) hue-rotate(${hue}deg) saturate(${sat})`; }
function hrStamps(n, pts) { const f = H_F(), total = pathLength(pts), out = [], imm = n.kind === 'immortal'; if (total < 0.1) return out; const push = (d, region) => { const q = pathAt(pts, d); out.push({ q, region, u: 1 - d / total }); }; push(10 * f, { x: 104, y: 0, w: 16, h: 32 }); push(30 * f, { x: 130, y: 0, w: 28, h: 32 }); const end = imm ? Math.max(38 * f, total - 58 * f) : total; for (let d = 38 * f, tile = 0; d <= end; d += Math.max(1, 14 * f), tile++) push(d, { x: tile % 3 * 32, y: 0, w: 32, h: 32 }); return out; }
function hrSnake(S, n, index, P) {
  const f = H_F(), list = hrStamps(n, n.points), head = (c, a = 1, s = 1) => { g.save(); g.filter = c; g.globalAlpha *= a; hDrawHead(n, n.pos, n.angle, s, s); g.restore(); };
  if (P.shadow > 0) { g.save(); g.translate(10, 14); g.filter = 'brightness(0)'; g.globalAlpha = P.shadow; for (const s of list) hStamp('neck', s.region, s.q.pos, s.q.angle - Math.PI / 2, f); g.restore(); }
  if (P.outline > 0) { const k = 1 + P.outline * 0.09; g.save(); g.filter = P.outlineLight > 0 ? `brightness(0) invert(${P.outlineLight})` : 'brightness(0)'; for (const s of list) hStamp('neck', s.region, s.q.pos, s.q.angle - Math.PI / 2, f * k); g.restore(); head(P.outlineLight > 0 ? `brightness(0) invert(${P.outlineLight})` : 'brightness(0)', 1, 1 + P.outline * 0.05); }
  for (const s of list) { g.save(); g.filter = hrFilter(P, index, s.u); hStamp('neck', s.region, s.q.pos, s.q.angle - Math.PI / 2, f); g.restore(); }
  head(`hue-rotate(${(index - 3) * 18 * P.tint}deg)`);
}
function hrScene(S, P) { [...S.necks, S.bearer].forEach((n, i) => hrSnake(S, n, i, P)); }
const HR_OFF = { outline: 0, outlineLight: 0, shadow: 0, taperShade: 0, tint: 0, neckDark: 0 };
DEMOS.push({ id: 'H-read', ids: ['H04'], cat: 'うみへび座（H）', group: 'うみへび座', title: '分離後の見分け（比較）', duration: 20, color: HM_COLORS.bite,
  params: [{ k: 'split', label: '左半分を現行のまま比較（1で比較）', type: 'range', min: 0, max: 1, step: 1, def: 1 }, { k: 'outline', label: '暗い輪郭の太さ', type: 'range', min: 0, max: 3, step: 0.25, def: 1 }, { k: 'outlineLight', label: '輪郭の明るさ（0で黒）', type: 'range', min: 0, max: 0.5, step: 0.05, def: 0 }, { k: 'shadow', label: '下の蛇へ落ちる影', type: 'range', min: 0, max: 0.8, step: 0.05, def: 0.4 }, { k: 'taperShade', label: '頭から尾へ暗くする', type: 'range', min: 0, max: 0.6, step: 0.05, def: 0.25 }, { k: 'tint', label: '蛇ごとの色みの違い', type: 'range', min: 0, max: 1, step: 0.05, def: 0.3 }, { k: 'neckDark', label: '判定のない胴を暗くする', type: 'range', min: 0, max: 0.5, step: 0.05, def: 0.15 }],
  status: { '状態': '相談用の比較。判定は変えない', '作り': '蛇が交差して泳ぐ場面で、見分けるための手を1つずつ試せる。左半分は現行の見た目' }, refs: ['speed/scripts/bosses/hydra_neck_art.gd（胴の並べ方）'],
  setup(S) { const slots = Array.from({ length: 6 }, (_, i) => V(Math.cos(i * TAU / 6) * 420, Math.sin(i * TAU / 6) * 240)); hsSetup(S, 'swarm', slots, V(200, -120)); S.positioning = false; S.age = 0; S.mt = 0; S.ship.pos = V(0, 0); [...S.necks, S.bearer].forEach((n, i) => { n.orbit = { a: i * 1.1, r: 70 + i * 26, w: (i % 2 ? 1 : -1) * 0.6 }; }); },
  step(S, dt) { S.age += dt; for (const n of [...S.necks, S.bearer]) { n.orbit.a += n.orbit.w * dt; hsSteer(S, n, V(Math.cos(n.orbit.a) * n.orbit.r * 1.5, Math.sin(n.orbit.a) * n.orbit.r * 0.75), dt, 1.1); hsFollow(S, n, dt); n.hist.push({ t: S.t, pos: { ...n.pos }, angle: n.angle }); if (n.hist.length > 48) n.hist.shift(); } },
  draw(S, R) { R.blitBack(); const P = R.P, cx = cam.x; if (P.split >= 1) { g.save(); g.beginPath(); g.rect(cx - 2000, -2000, 2000, 4000); g.clip(); hrScene(S, { ...P, ...HR_OFF }); g.restore(); g.save(); g.beginPath(); g.rect(cx, -2000, 2000, 4000); g.clip(); hrScene(S, P); g.restore(); g.save(); g.fillStyle = 'rgba(255,255,255,0.35)'; g.fillRect(cx - 1, -2000, 2, 4000); g.restore(); } else hrScene(S, P); }, phase() { return '左：現行　右：変更案'; } });
