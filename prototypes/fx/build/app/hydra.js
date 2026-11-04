// ===== うみへび（作り直し）=====
// 動き・時刻・判定は本番 main の C++ を写す（cpp/bosses/hydra/body.cpp の chain・首の待機と狙い、bite_thrust.cpp、bite_sweep.cpp）。
// 試作の表示は、その上に絵の位置・向き・大きさの見た目だけを重ね、技の点列・時刻・速さへは戻さない。
const HYDRA = BOSSES.hydra, HP = HYDRA.def.params;
// 首の増える順（仕様書3章）：噛みつき・渦・瓦礫 → ビーム・雷 → 噛みつき・ビーム・渦
const H_KINDS = ['bite', 'vortex', 'debris', 'beam', 'thunder', 'bite', 'beam', 'vortex'];
function hRule(id) { return { ...HP, ...bossRule('hydra', id) }; }
function hBase(S, n) { return add(S.B.pos, mul(fromA(n.baseAngle + S.B.facing), S.B.r)); }
// body.cpp：狙いの角速度は加減速つきで、行き過ぎない。
function hAim(n, angle, dt) {
  if (dt <= 0) return;
  const off = angDiff(angle, n.angle), speed = Math.min(HP.aim_turn, Math.sqrt(2 * HP.aim_accel * Math.abs(off)));
  n.aimV = (n.aimV || 0) + clamp(Math.sign(off) * speed - (n.aimV || 0), -HP.aim_accel * dt, HP.aim_accel * dt);
  let step = n.aimV * dt; if (step * off >= 0 && Math.abs(step) > Math.abs(off)) step = off; n.angle += step; n.aimV = step / dt;
}
// body.cpp chain：根元と頭の間を、弧の案内と往復の長さ合わせで点列にする。
function hChain(S, n, dt) {
  const count = HP.neck_segments, root = hBase(S, n), tip = n.pos, delta = sub(tip, root), distance = len(delta), dir = distance > 0.001 ? mul(delta, 1 / distance) : V(1, 0), side = orth(dir);
  const length = Math.max(distance, HP.neck_rest * Math.max(1, HP.neck_slack)), seg = length / count, initial = !n.points || n.points.length !== count + 1, shift = initial ? V(0, 0) : sub(root, n.points[0]);
  if (initial) n.points = Array.from({ length: count + 1 }, () => V(0, 0));
  const points = n.points;
  if (length - distance < 0.001) { for (let i = 0; i <= count; i++) points[i] = lerpV(root, tip, i / count); return; }
  const phase = n.baseAngle * 2.4, bend = Math.sqrt(Math.max(0, length * length - distance * distance)) * 0.45, sign = Math.sin(phase) >= 0 ? 1 : -1, amp = Math.min(HP.neck_wave_amplitude, bend * 0.6), weight = initial ? 1 : 1 - Math.exp(-HP.neck_response * dt);
  points[0] = root; points[count] = tip;
  for (let i = 1; i < count; i++) { const f = i / count, wave = Math.sin(S.t * HP.neck_wave_speed + phase + f * HP.neck_wave_frequency * TAU) * amp, guide = add(lerpV(root, tip, f), mul(side, Math.sin(f * Math.PI) * (bend * sign + wave))); points[i] = initial ? guide : lerpV(add(points[i], shift), guide, weight); }
  for (let pass = 0; pass < HP.neck_iterations; pass++) {
    points[count] = tip; let prev = tip;
    for (let i = count - 1; i >= 0; i--) { const o = sub(points[i], prev), l = len(o); prev = add(prev, l > 0.001 ? mul(o, seg / l) : mul(dir, -seg)); points[i] = prev; }
    points[0] = root; prev = root;
    for (let i = 1; i <= count; i++) { const o = sub(points[i], prev), l = len(o); prev = add(prev, l > 0.001 ? mul(o, seg / l) : mul(dir, seg)); points[i] = prev; }
    if (dist(points[count], tip) < 0.01) break;
  }
  points[count] = tip; const out = sub(points[0], S.B.pos);
  if ((points[1].x - points[0].x) * out.x + (points[1].y - points[0].y) * out.y < 0) points[1] = add(points[0], mul(norm(out), Math.max(4, dist(points[1], points[0]))));
  for (let i = 1; i < count; i++) if (dist(points[i], S.B.pos) < S.B.r + 12) points[i] = add(S.B.pos, mul(norm(sub(points[i], S.B.pos)), S.B.r + 12));
}
function pathLength(points) { let total = 0; for (let i = 1; i < points.length; i++) total += dist(points[i - 1], points[i]); return total; }
function pathAt(points, d) { for (let i = 1; i < points.length; i++) { const span = dist(points[i - 1], points[i]); if (d <= span || i === points.length - 1) return { pos: lerpV(points[i - 1], points[i], clamp(d / Math.max(0.001, span))), angle: angOf(sub(points[i], points[i - 1])) }; d -= span; } return { pos: points[0], angle: 0 }; }

// ---------- 技の進行（本番の値と順番）
function hTiming(S) { const r = S.r; return S.tech === 'bite_sweep' ? { warn: r.normal_charge, active: r.sweep_time, hold: r.normal_hold } : { warn: r.normal_charge, active: r.normal_lunge, hold: r.normal_hold }; }
function hIdle(S, n, dt) {
  // body.cpp：待機中の首は、取り付け方向から±0.8の範囲で機体を向き、長さを休みの長さへ戻す。
  const facing = n.baseAngle + S.B.facing, base = hBase(S, n), o = sub(S.ship.pos, base), fw = fromA(facing);
  const local = Math.atan2(o.x * orth(fw).x + o.y * orth(fw).y, Math.max(HP.aim_deadzone, o.x * fw.x + o.y * fw.y));
  hAim(n, facing + clamp(local, -0.8, 0.8) + Math.sin(S.t + n.baseAngle) * 0.06, dt);
  n.length = moveToward(n.length, HP.neck_rest, HP.neck_rest * dt); n.pos = add(base, mul(fromA(n.angle), n.length));
}
function hAttack(S, n, dt) {
  const r = S.r, T = hTiming(S), time = S.age, base = hBase(S, n);
  if (time < 0) { hIdle(S, n, dt); return; }
  if (time < T.warn) {
    n.target = { ...S.ship.pos };
    if (S.tech === 'bite_sweep') hAim(n, angOf(sub(n.target, base)) - r.sweep_arc * 0.5, dt);
    else { hAim(n, angOf(sub(n.target, base)), dt); n.length += clamp(HP.neck_rest * 0.4 - n.length, -HP.neck_rest * dt * 2, HP.neck_rest * dt * 2); }
    n.pos = add(base, mul(fromA(n.angle), n.length)); n.glow = time / T.warn; return;
  }
  const e = time - T.warn;
  if (!n.locked) { n.locked = true; n.from = { ...n.pos }; n.sweep = angOf(sub(n.target, base)); }
  if (time >= T.warn + T.active + T.hold) {
    if (!n.done) { n.done = true; n.angle = angOf(sub(n.pos, base)); n.length = dist(n.pos, base); }
    hIdle(S, n, dt); return;
  }
  n.glow = 0;
  if (S.tech === 'bite_sweep') { if (e < T.active) { const f = clamp(e / T.active); n.angle = n.sweep + r.sweep_arc * (f - 0.5); n.pos = add(base, mul(fromA(n.angle), r.sweep_reach)); } }
  else if (e < T.active) { n.pos = lerpV(n.from, n.target, clamp(e / T.active)); n.angle = angOf(sub(n.target, n.from)); }
  else n.pos = { ...n.target };
}
function hSetup(S, id) {
  S.tech = id; S.r = hRule(id); S.B = bossActor('hydra', V(-300, 0)); S.age = -0.6; S.necks = [];
  S.ship = shipState(id === 'bite_sweep' ? V(110, 130) : V(250, 70), Math.PI, 0);
  for (let i = 0; i < 5; i++) { const baseAngle = TAU * i / 5, n = { kind: H_KINDS[i], baseAngle, angle: baseAngle, length: HP.neck_rest, aimV: 0, glow: 0, hist: [] }; n.pos = add(hBase(S, n), mul(fromA(baseAngle), HP.neck_rest)); S.necks.push(n); }
  S.actor = S.necks[0];
  for (const n of S.necks) hChain(S, n, 0);
}
function hStep(S, dt) {
  S.age += dt;
  for (const n of S.necks) { if (n === S.actor) hAttack(S, n, dt); else hIdle(S, n, dt); hChain(S, n, dt); n.hist.push({ t: S.t, pos: { ...n.pos }, angle: n.angle }); if (n.hist.length > 48) n.hist.shift(); }
}
function hPhase(S) {
  const T = hTiming(S), t = S.age;
  return t < 0 ? '待機' : t < T.warn ? '予兆（構え）' : t < T.warn + T.active ? '攻撃中' : t < T.warn + T.active + T.hold ? '停止（反撃の隙）' : '戻り';
}

// ---------- 絵
const H_F = () => S.B.r * 2 / HYDRA.body_source_width;   // 本体・首・頭で共通の画像倍率
function hStamp(key, region, pos, angle, factor, alpha = 1, white = 0) {
  const im = IMG['hydra/' + key]; if (!im) return; const r = region || { x: 0, y: 0, w: im.width, h: im.height };
  g.save(); g.translate(pos.x, pos.y); g.rotate(angle); g.scale(factor, factor); g.globalAlpha *= alpha; g.drawImage(im, r.x, r.y, r.w, r.h, -r.w / 2, -r.h / 2, r.w, r.h);
  if (white > 0) { g.globalCompositeOperation = 'lighter'; g.globalAlpha = alpha * white; g.drawImage(bossWhiteImage('hydra/' + key), r.x, r.y, r.w, r.h, -r.w / 2, -r.h / 2, r.w, r.h); }
  g.restore();
}
function hHeadKey(n) { return n.kind === 'bite' ? 'head0' : ['debris', 'beam'].includes(n.kind) ? 'head2' : 'head1'; }
// 頭の絵は下（+y）が口。口は中心から前へ（36−24.5）画素（頭3は41）。
function hMouthDist(n) { return ((hHeadKey(n) === 'head2' ? 41 : 36) - 24.5) * H_F(); }
// 頭の中の位置（絵の画素、中心基準。+y が前）をワールドへ。
function hLocal(center, angle, x, y, sx = 1, sy = 1) { return add(center, rotateV(V(x * H_F() * sx, y * H_F() * sy), angle - Math.PI / 2)); }
function hDrawNeck(S, n, points, index) {
  const f = H_F(), total = pathLength(points); if (total < 0.1) return;
  for (let d = 0, tile = 0; d <= total; d += Math.max(1, 14 * f), tile++) { const q = pathAt(points, d); hStamp('neck', { x: ((index + tile) % 3) * 32, y: 0, w: 32, h: 32 }, q.pos, q.angle - Math.PI / 2, f); }
}
function hDrawHead(n, center, angle, sx = 1, sy = 1, alpha = 1, white = 0) {
  const im = IMG['hydra/' + hHeadKey(n)]; if (!im) return;
  g.save(); g.translate(center.x, center.y); g.rotate(angle - Math.PI / 2); g.scale(H_F() * sx, H_F() * sy); g.globalAlpha *= alpha;
  g.drawImage(im, -im.width / 2, -im.height / 2);
  if (white > 0) { g.globalCompositeOperation = 'lighter'; g.globalAlpha = alpha * white; g.drawImage(bossWhiteImage('hydra/' + hHeadKey(n)), -im.width / 2, -im.height / 2); }
  g.restore();
}
function hAt(n, t) { // 過去の頭の位置（残像・通り道に使う）
  const h = n.hist; if (!h.length) return { pos: n.pos, angle: n.angle };
  for (let i = h.length - 1; i > 0; i--) if (h[i - 1].t <= t) { const a = h[i - 1], b = h[i], k = clamp((t - a.t) / Math.max(1e-6, b.t - a.t)); return { pos: lerpV(a.pos, b.pos, k), angle: a.angle + angDiff(b.angle, a.angle) * k }; }
  return h[0];
}

// ---------- 試作の姿勢（見た目だけ）
// 予兆：首をS字にためて頭を引き、最後は力んで震えて止まる（静）→ 発動：一気に伸び、首の波が根元へ抜ける（動）。
function hPose(S, n, R) {
  const T = hTiming(S), t = S.age, sweep = S.tech === 'bite_sweep';
  const out = { coil: 0, freeze: 0, rel: -1, head: n.pos, angle: n.angle, sx: 1, sy: 1, T };
  if (n !== S.actor || t < 0) return out;
  const u = clamp(t / T.warn);
  if (t < T.warn) { out.coil = smooth(0, 0.62, u); out.freeze = smooth(0.62, 0.8, u); }
  else { out.rel = t - T.warn; out.coil = Math.exp(-out.rel / 0.035); }
  const fw = fromA(n.angle);
  if (out.rel < 0) { out.head = add(n.pos, mul(fw, -16 * out.coil * R.P.coil)); out.sx = 1 + 0.05 * out.coil; out.sy = 1 - 0.08 * out.coil; }
  else {
    const k = clamp(out.rel / T.active);
    if (!sweep && out.rel < T.active) { out.sy = 1 + 0.16 * Math.sin(Math.PI * k); out.sx = 1 - 0.07 * Math.sin(Math.PI * k); }
    // 噛んだ瞬間に前へ食い込み、跳ね返って止まる
    const after = out.rel - T.active; if (after >= 0) { const j = Math.exp(-after / 0.07) * Math.sin(Math.min(1, after / 0.05) * Math.PI); out.head = add(n.pos, mul(fw, 9 * j * R.P.snap)); out.sy = 1 + 0.06 * j; }
  }
  if (out.freeze > 0 && out.rel < 0) out.head = add(out.head, mul(orth(fw), Math.sin(S.t * 95) * 1.6 * out.freeze));
  return out;
}
function hVisualNeck(S, n, pose, R) {
  const pts = n.points; if (n !== S.actor || S.age < 0) return pts;
  const N = pts.length - 1, root = pts[0], tip = pts[N], dir = norm(sub(tip, root)), side = orth(dir), sweep = S.tech === 'bite_sweep', A = (sweep ? 30 : 36) * R.P.coil;
  return pts.map((p, i) => {
    const u = i / N; let o = 0;
    // とぐろ：噛みつきはS字、薙ぎ払いは振りかぶる側へ弓なり
    if (pose.coil > 0) o += (sweep ? -Math.sin(u * Math.PI) : Math.sin(u * TAU) * Math.sin(u * Math.PI) * 0.5) * A * pose.coil;
    if (pose.freeze > 0 && pose.rel < 0) o += Math.sin(S.t * 95 + i * 1.7) * 1.3 * pose.freeze * Math.sin(u * Math.PI);
    if (pose.rel >= 0) {
      if (sweep && pose.rel < pose.T.active + 0.25) { // 頭に遅れて首がしなる
        const w = pose.rel < pose.T.active ? 1 : Math.exp(-(pose.rel - pose.T.active) / 0.08); o += -Math.sin(u * Math.PI) * (1 - u * 0.3) * 26 * w * R.P.coil;
      }
      // 噛んだ衝撃の波：頭から根元へ抜けて消える
      const after = pose.rel - pose.T.active, s = 1 - u;
      if (after > 0) { const front = after * 9; if (s < front) o += Math.sin((front - s) * 9) * 13 * Math.exp(-after / 0.22) * (1 - s * 0.5) * R.P.snap; }
    }
    return i === N ? pose.head : add(p, mul(side, o));
  });
}

// ---------- 試作のエフェクト（論理ピクセルに描く）
const H_STONE = ['#1b2430', '#2f3c4a', '#4b5a68', '#6f7f8d', '#a3b0ba'].map(hexc);
function hEyes(S, R, n, pose) { // 予兆：赤い目が強まり、溜めの終わりに横へ光が走る
  if (n !== S.actor || S.age < 0) return;
  const pal = FX.ramp(R.P.color), T = pose.T, t = S.age;
  let k = t < T.warn ? clamp(t / T.warn) ** 1.4 : Math.exp(-(t - T.warn) / 0.25); if (k <= 0.01) return;
  for (const sx of [-8.5, 8.5]) {
    const e = toL(hLocal(pose.head, pose.angle, sx, -9.5, pose.sx, pose.sy));
    R.front.glow(e.x, e.y, 1.6 + 3.2 * k * R.P.size, pal[3], (0.22 + 0.55 * k) * R.P.intensity);
    if (k > 0.35) R.front.px(e.x, e.y, pal[k > 0.75 ? 4 : 3]);
    if (pose.freeze > 0 && pose.rel < 0) { const sd = orth(fromA(pose.angle)), L = (1 + 2.5 * pose.freeze) * R.P.size; for (let d = -L; d <= L; d += 0.5) { const a = (1 - Math.abs(d) / L) ** 2; R.front.light(e.x + sd.x * d, e.y + sd.y * d, pal[3], a * 0.4 * pose.freeze * R.P.intensity); } }
  }
  // 発動後：目の光が通り道に赤く残る
  if (pose.rel >= 0 && pose.rel < 0.3) for (let j = 1; j <= 14; j++) {
    const back = hAt(n, S.t - j * 0.008), fade = (1 - j / 15) * Math.exp(-pose.rel / 0.12);
    for (const sx of [-8.5, 8.5]) { const e = toL(hLocal(back.pos, back.angle, sx, -9.5)); R.front.light(e.x, e.y, pal[3], fade * 0.5 * R.P.intensity); }
  }
}
function hGrit(S, R, n, pts, pose) { // ためるとき、首の瓦礫がきしんで小石と粉がこぼれる
  if (n !== S.actor || S.age < 0) return; const T = pose.T, N = pts.length - 1;
  for (let j = 0; j < 26; j++) {
    const born = T.warn * (0.1 + 0.75 * hash(j * 3.1 + 2)), age = (S.age - born) / R.P.timing, life = 0.45 + 0.4 * hash(j * 5.7); if (age < 0 || age > life) continue;
    const i = 2 + Math.floor(hash(j * 7.3) * (N - 3)), at = pts[i], an = hash(j * 1.9) * TAU, sp = (18 + 40 * hash(j * 4.4)) * R.P.dust, d = sp * life * 0.4 * (1 - Math.exp(-age / (life * 0.4)));
    const q = toL(add(at, mul(fromA(an), 14 + d))), fade = 1 - age / life; if (hash(j * 13 + Math.floor(age * 30)) > fade * 1.6) continue;
    R.front.px(q.x, q.y, H_STONE[fade > 0.5 ? 3 : 2]); if (hash(j) > 0.6) R.back.dot(q.x + 1, q.y, H_STONE[1], fade * 0.6);
  }
}
function hAir(S, R, n, pose) { // 突き噛みの空気の筋：頭の両脇からはがれて後ろへ残る
  if (S.tech !== 'bite_thrust' || pose.rel < 0 || pose.rel > pose.T.active + 0.2) return;
  const pal = FX.ramp(R.P.color), from = n.from, to = n.target, L = dist(from, to), d = norm(sub(to, from)), sd = orth(d), speed = L / pose.T.active, head = Math.min(L, pose.rel * speed);
  // 両脇に2本ずつ。筋ごとに長さを変え、途中で切らずに後ろへ細って消える（点線にしない）
  for (const side of [-1, 1]) for (let j = 0; j < 2; j++) {
    const id = side * 7 + j * 3, life = (0.05 + 0.07 * hash(id + 4)) * R.P.timing, base = (22 + 9 * j + 6 * hash(id)) * R.P.size;
    for (let s = 0; s < head; s += 0.5 / WL) {
      const age = (head - s) / speed + Math.max(0, pose.rel - pose.T.active), k = age / life; if (k >= 1) continue;
      const q = toL(add(add(from, mul(d, s)), mul(sd, side * (base + age * 160 + Math.sin(s * 0.045 + id) * 3))));
      R.front.dot(q.x, q.y, pal[k < 0.3 ? 3 : 2], (1 - k) * 0.75); R.front.light(q.x, q.y, pal[2], (1 - k) * 0.15 * R.P.intensity);
    }
  }
}
function hSnap(S, R, n, pose) { // 噛む衝撃：上下の牙の軌跡が口先で閉じ、ひしゃげた閃光と欠片が前へ散る
  if (S.tech !== 'bite_thrust' || pose.rel < 0) return;
  const t = (pose.rel - pose.T.active + 0.03) / R.P.timing; if (t < 0 || t > 0.6) return;
  const pal = FX.ramp(R.P.color), fw = fromA(n.angle), sd = orth(fw), mouth = add(n.pos, mul(fw, hMouthDist(n))), Rr = S.r.bite_radius * R.P.size * R.P.snap;
  const p = clamp(t / 0.05), out = clamp((t - 0.05) / 0.16);
  // 上下の牙：両脇から口先へ鋭く曲がる2本の鉤。先は閉じきらずに隙間を残す（一続きの弧にしない）。細い芯が白く、根元から消える
  for (const side of [-1, 1]) {
    const P0 = add(add(mouth, mul(sd, side * Rr * 0.8)), mul(fw, 0.1 * Rr)), C = add(add(mouth, mul(sd, side * Rr * 0.72)), mul(fw, 0.72 * Rr)), P1 = add(add(mouth, mul(fw, 0.92 * Rr)), mul(sd, side * Rr * 0.14));
    const steps = Math.ceil(Rr * 2.2 * WL);
    for (let i = 0; i <= steps; i++) {
      const u = i / steps; if (u > p || u < out) continue;
      const q = toL(add(add(mul(P0, (1 - u) ** 2), mul(C, 2 * u * (1 - u))), mul(P1, u * u))), lead = p - u, w = (0.3 + 1.3 * Math.sin(Math.PI * u) ** 0.7) * R.P.size * (1 - out * 0.6);
      if (out > 0.3 && hash(i * 7 + side * 3 + Math.floor(t * 40)) > (1 - out) * 1.6) continue;
      for (let o = -w; o <= w; o += 0.5) { const e = Math.abs(o) / Math.max(0.3, w); R.front.px(q.x + sd.x * o * side, q.y + sd.y * o * side, pal[(lead < 0.25 || e < 0.35) && out < 0.5 ? 4 : e < 0.7 ? 3 : 2]); }
      if (i % 2 === 0) R.front.light(q.x, q.y, pal[2], 0.45 * (1 - out) * R.P.intensity);
    }
  }
  const hit = toL(add(mouth, mul(fw, 0.45 * Rr))), fl = Math.exp(-Math.max(0, t - 0.04) / 0.06);
  if (t > 0.03 && fl > 0.05) { // 向きの偏った十字の閃光（前へ長い）
    const L = [[fw, 13], [mul(fw, -1), 4], [sd, 6], [mul(sd, -1), 5]];
    for (const [u, l] of L) for (let d = 0; d <= l * R.P.size * fl; d += 0.5) { const a = 1 - d / (l * R.P.size * fl + 0.01); R.front.light(hit.x + u.x * d, hit.y + u.y * d, pal[a > 0.6 ? 4 : 3], a * 0.9 * R.P.intensity); }
    R.front.px(hit.x, hit.y, pal[4]); R.front.px(hit.x + 1, hit.y, pal[4]); R.front.px(hit.x, hit.y + 1, pal[4]);
    R.front.glow(hit.x, hit.y, 7 * R.P.size * fl, pal[2], 0.5 * fl * R.P.intensity);
  }
  if (t > 0.04) for (let i = 0; i < 16; i++) { // 歯と岩の欠片：前の扇へ散って減速し、冷えて止まる
    const a = t - 0.04, life = 0.25 + 0.3 * hash(i * 3.3); if (a > life) continue;
    const an = n.angle + (hash(i * 5.1) - 0.5) * 2.0, sp = (180 + 320 * hash(i * 2.7)) * R.P.size, d = sp * 0.11 * (1 - Math.exp(-a / 0.11)), q = toL(add(hit ? add(mouth, mul(fw, 0.45 * Rr)) : mouth, mul(fromA(an), d))), k = a / life, stone = hash(i * 9.9) > 0.45;
    const tl = Math.max(0, 3 * Math.exp(-a / 0.05)); const u = fromA(an);
    for (let s = 0; s <= tl; s += 0.5) R.front.px(q.x - u.x * s, q.y - u.y * s, stone ? H_STONE[k < 0.5 ? 4 : 3] : pal[k < 0.3 ? 4 : k < 0.6 ? 3 : 2]);
    if (!stone) R.front.light(q.x, q.y, pal[2], (1 - k) * 0.35 * R.P.intensity);
  }
  hDust(S, R, add(mouth, mul(fw, 0.3 * Rr)), t - 0.05, 41, n.angle, 1.0);
}
function hDust(S, R, at, t, seed, dirA, power) { // 土ぼこり：ふくらみながら前から崩れて消える
  if (t < 0) return; const life = 0.55 * R.P.timing; if (t > life) return;
  const c = toL(at), k = t / life;
  for (let i = 0; i < 26; i++) {
    const an = dirA + (hash(seed + i * 3.7) - 0.5) * 2.6, sp = (60 + 110 * hash(seed + i * 1.3)) * power * R.P.dust * R.P.size, d = sp * 0.18 * (1 - Math.exp(-t / 0.18)) * WL, r = (1.2 + 2.6 * hash(seed + i * 5.9)) * (0.6 + k) * R.P.size;
    const q = add(c, mul(fromA(an), d));
    for (let y = -r; y <= r; y += 1) for (let x = -r; x <= r; x += 1) { if (x * x + y * y > r * r) continue; if (hash(seed + i * 17 + Math.floor(x) * 3 + Math.floor(y) * 7) < k * 1.25) continue; R.back.dot(q.x + x, q.y + y, H_STONE[k < 0.3 ? 3 : 2], (1 - k) * 0.55); }
  }
}
function hSweepTrail(S, R, n, pose) { // 薙ぎ払い：頭の通った弧に、先が白く後ろへ冷えて細る三日月の帯。後ろから虫食いで消える
  if (S.tech !== 'bite_sweep' || pose.rel < 0) return;
  const T = pose.T, r = S.r, base = hBase(S, n), pal = FX.ramp(R.P.color), w = r.sweep_arc / T.active;
  const cur = Math.min(pose.rel, T.active), aHead = n.sweep + r.sweep_arc * (cur / T.active - 0.5), aStart = n.sweep - r.sweep_arc * 0.5, maxAge = 0.34 * R.P.timing, after = Math.max(0, pose.rel - T.active);
  // 筋の束：真ん中（頭の通り道）の筋ほど長く残り、外の筋ほど短い → 先が太く後ろが細る三日月。光が主で、面で塗りつぶさない
  const Rr = r.sweep_reach * WL, half = r.bite_radius * 0.55 * WL * R.P.size, C = toL(base), stepA = 0.5 / Math.max(1, Rr);
  for (let o = -half; o <= half; o += 0.75) {
    const e = Math.abs(o) / half, lane = Math.round(o / 0.75), life = maxAge * (1 - e ** 1.6) * (0.5 + 0.5 * hash(lane * 3.7 + 1)); if (life <= 0.01) continue;
    for (let a = aHead; a >= aStart; a -= stepA) {
      const age = (aHead - a) / w + after; if (age > life) break;
      const k = age / life, x = C.x + Math.cos(a) * (Rr + o), y = C.y + Math.sin(a) * (Rr + o);
      if (k > 0.55 && hash(lane * 11 + Math.floor(a * Rr / 1.5) * 5) > (1 - k) * 2.2) continue;
      const lv = k < 0.12 && e < 0.35 ? 4 : k < 0.4 ? 3 : 2, al = (1 - k) * (1 - e * 0.7);
      if (al > 0.6 && e < 0.25) R.front.px(x, y, pal[lv]); else if (al * (1 - e) > 0.18) R.front.dot(x, y, pal[Math.max(1, lv - 1)], al * (1 - e) * 0.9);
      R.front.light(x, y, pal[2], al * (1 - e) * 0.1 * R.P.intensity);
    }
  }
  // 外側へ削られて飛ぶ小石
  for (let i = 0; i < 30; i++) {
    const born = T.active * hash(i * 2.3 + 5), a = pose.rel - born, life = 0.35 + 0.3 * hash(i * 4.1); if (a < 0 || a > life) continue;
    const an0 = n.sweep + r.sweep_arc * (born / T.active - 0.5), from = add(base, mul(fromA(an0), r.sweep_reach + (hash(i * 6.7) - 0.3) * r.bite_radius)), vdir = norm(add(mul(orth(fromA(an0)), 1), mul(fromA(an0), 0.4 + 0.5 * hash(i)))), sp = (160 + 260 * hash(i * 8.1)) * R.P.dust;
    const q = toL(add(from, mul(vdir, sp * 0.12 * (1 - Math.exp(-a / 0.12))))), k = a / life; if (hash(i * 19 + Math.floor(a * 25)) > (1 - k) * 1.8) continue;
    R.front.px(q.x, q.y, H_STONE[k < 0.4 ? 4 : 3]); if (k < 0.3) R.front.px(q.x - vdir.x, q.y - vdir.y, H_STONE[2]);
  }
  if (pose.rel >= T.active) hDust(S, R, n.pos, pose.rel - T.active, 77, n.angle + Math.PI / 2, 0.8);
}

// 頭の絵の不透明な画素（論理ピクセルへ写す残像用。絵ごとに一度だけ作る）
const H_MASK = {};
function hMask(key) {
  if (H_MASK[key]) return H_MASK[key]; const im = IMG['hydra/' + key], c = document.createElement('canvas'); c.width = im.width; c.height = im.height;
  const x = c.getContext('2d'); x.drawImage(im, 0, 0); const d = x.getImageData(0, 0, im.width, im.height).data, m = new Uint8Array(im.width * im.height);
  for (let i = 0; i < m.length; i++) m[i] = d[i * 4 + 3] > 100 ? 1 : 0; return (H_MASK[key] = { w: im.width, h: im.height, m });
}
function hSilhouette(R, n, center, angle, color, a, seed = 1) {
  const k = hMask(hHeadKey(n)), f = H_F(), c = toL(center), r = Math.ceil(Math.max(k.w, k.h) * f * WL * 0.75);
  for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) {
    const l = rotateV(V(x / WL, y / WL), -(angle - Math.PI / 2)), ix = Math.floor(l.x / f + k.w / 2), iy = Math.floor(l.y / f + k.h / 2);
    if (ix < 0 || iy < 0 || ix >= k.w || iy >= k.h || !k.m[iy * k.w + ix]) continue; if (hash(seed + x * 7 + y * 13) > a * 1.6) continue;
    R.front.light(c.x + x, c.y + y, color, a);
  }
}
function hGhosts(S, R, n, pose) { // 伸びる間：頭の形の光が通り道に2つ残る（灰色に重ねない）
  if (pose.rel < 0 || pose.rel > pose.T.active + 0.06) return; const pal = FX.ramp(R.P.color);
  [[0.05, 0.14], [0.025, 0.26]].forEach(([lag, a], j) => { const b = hAt(n, S.t - lag); if (dist(b.pos, n.pos) < 45) return; hSilhouette(R, n, b.pos, b.angle, pal[2], a * R.P.intensity * Math.exp(-Math.max(0, pose.rel - pose.T.active) / 0.03), j * 31 + 5); });
}
// ---------- 現行表示の近似（render/attacks/hydra_shape.gd：判定の線を帯の色で出す）
function hCurrent(S, n) {
  const T = hTiming(S), t = S.age; if (n !== S.actor || t < 0) return;
  if (t < T.warn) D2.circle(n.pos, S.B.r * 0.5, rgba('#ffdb80', n.glow * 0.45));
  const e = t - T.warn; if (e < 0 || e > T.active) return;
  const prev = hAt(n, S.t - 1 / 60).pos; D2.roundBeam(prev, n.pos, rgba('#ff7330', 0.75), S.r.bite_radius * 2);
}

function hDraw(S, R) {
  const actor = S.actor, pose = hPose(S, actor, R);
  if (R.proto) for (const n of S.necks) if (n === actor) hGrit(S, R, n, hVisualNeck(S, n, pose, R), pose);
  if (R.proto) hSweepTrail(S, R, actor, pose);
  R.blitBack();
  S.necks.forEach((n, i) => hDrawNeck(S, n, R.proto ? hVisualNeck(S, n, n === actor ? pose : hPose(S, n, R), R) : n.points, i));
  hStamp('body', null, S.B.pos, 0, S.B.r * 2 / IMG['hydra/body'].width);
  for (const n of S.necks) {
    if (!R.proto || n !== actor) { hDrawHead(n, n.pos, n.angle); if (!R.proto) hCurrent(S, n); continue; }
    hDrawHead(n, pose.head, pose.angle, pose.sx, pose.sy, 1, 0);
  }
  if (R.proto) { hGhosts(S, R, actor, pose); hEyes(S, R, actor, pose); hAir(S, R, actor, pose); hSnap(S, R, actor, pose); }
  drawShip(S.ship);
}

const H_STATUS = {
  '状態': '作り直しの試作（未承認）。本番への組み込みは本人の承認後',
  '動きと判定': '首の点列・待機の狙い・技の時刻と軌道は main の C++（body.cpp・bite_thrust.cpp・bite_sweep.cpp）と .tres の値のまま。試作の姿勢は絵の位置・向き・大きさだけ',
};
const H_REFS = ['cpp/bosses/hydra/body.cpp（chain・待機の狙い）', 'cpp/bosses/hydra/bite_thrust.cpp・bite_sweep.cpp', 'data/bosses/hydra.tres（normal_charge・normal_lunge・normal_hold・sweep_*・bite_radius）', 'scripts/render/attacks/hydra_shape.gd（現行表示の近似）', 'pixelFX impacts/hit-spark・melee/sword-slash の作り方を下敷き'];
const H_PARAMS = [
  { k: 'coil', label: 'ための首の曲がり', type: 'range', min: 0, max: 2, step: 0.05, def: 1 },
  { k: 'snap', label: '噛む衝撃の大きさ', type: 'range', min: 0, max: 2, step: 0.05, def: 1 },
  { k: 'dust', label: '小石・土ぼこりの量', type: 'range', min: 0, max: 2, step: 0.05, def: 1 },
];
for (const id of ['bite_thrust', 'bite_sweep']) {
  const r = hRule(id), T = id === 'bite_sweep' ? r.normal_charge + r.sweep_time + r.normal_hold : r.normal_charge + r.normal_lunge + r.normal_hold;
  DEMOS.push({ id: 'H-' + id, ids: ['H04'], cat: 'うみへび座（H）', group: 'うみへび座', title: id === 'bite_sweep' ? '横薙ぎ' : '突き噛み', duration: T + 1.4, color: '#ff5470',
    params: H_PARAMS, status: { ...H_STATUS, '作り': id === 'bite_sweep' ? '予兆：首を振りかぶる側へ弓なりにため、目が赤く強まり、最後は震えて止まる → 頭の通った弧に先が白く冷えて細る帯（判定の幅）と外へ削られる小石 → 振り切って止まり、帯は後ろから崩れて消える' : '予兆：首をS字にためて頭を引き、目が赤く強まり、最後は震えて止まる → 一気に伸びて頭の残像と両脇の空気の筋、目の光が通り道に残る → 上下の牙の軌跡が口先で閉じ、前へ長い閃光と欠片・土ぼこり → 衝撃の波が首を根元へ抜ける' },
    refs: H_REFS, setup(S) { hSetup(S, id); }, step: hStep, draw: hDraw, phase: hPhase });
}
