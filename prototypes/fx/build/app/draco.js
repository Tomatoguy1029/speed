// ===== りゅう：現行の背骨・装甲・四肢と13技を独立再生 =====
// りゅうの作り直しまでの仮：旧うみへびの技の帯を借りていた所。記録だけして描かない。
function hEffect(S, kind, points, width, delay, life) { const e = { kind, points, width, delay, life, t: S.t, vel: V(0, 0) }; (S.effects ||= []).push(e); return e; }
function hDrawEffect() {}
const DRACO = BOSSES.draco, DP = DRACO.def.params, DCOUNT = DP.body_segments;
// 動きの緩急：等速で動かさない。ためから一気に出て、止まる前に勢いを殺す／だんだん速くなって叩きつける
const dBurst = x => 1 - (1 - clamp(x)) ** 3;
const dSlam = x => clamp(x) ** 3;
const dTaper = t => lerp(1, 0.23, clamp((t - 0.55) / 0.45) ** 1.35);
function dNeutral(head, angle, time, length = DP.body_length) {
  const points = [head]; for (let i = 1; i <= DCOUNT; i++) { const t = i / DCOUNT, wave = Math.sin(t * TAU * 1.25 - time * 0.75) * DP.body_wave * Math.sin(t * Math.PI * 0.8); points.push(add(head, rotateV(V(-t * length, wave), angle))); }
  const total = pathLength(points); return points.map(p => add(head, mul(sub(p, head), length / Math.max(0.001, total))));
}
function dFit(desired, reference, anchorTip = false) {
  if (desired.length < 2 || reference.length !== desired.length) return desired;
  const lengths = reference.slice(1).map((p, i) => dist(reference[i], p)), total = lengths.reduce((a, b) => a + b, 0), points = desired.map(p => ({ ...p })), head = points[0], tip = points[points.length - 1], both = anchorTip && dist(head, tip) < total - 1;
  for (let iteration = 0; iteration < (both ? 24 : 1); iteration++) { if (both) { points[points.length - 1] = tip; for (let i = points.length - 2; i >= 0; i--) points[i] = add(points[i + 1], mul(len(sub(points[i], points[i + 1])) < 0.001 ? V(-1, 0) : norm(sub(points[i], points[i + 1])), lengths[i])); }
    points[0] = head; for (let i = 1; i < points.length; i++) points[i] = add(points[i - 1], mul(len(sub(points[i], points[i - 1])) < 0.001 ? V(-1, 0) : norm(sub(points[i], points[i - 1])), lengths[i - 1])); }
  return points;
}
function dFollow(trail, head, length = DP.body_length) {
  if (trail.length < 2) trail = [head, add(head, V(-length, 0))]; else trail = trail.slice();
  const prev = trail[0], distance = dist(prev, head); if (distance > 0.01) { const steps = Math.max(1, Math.ceil(distance / 24)); for (let i = 1; i <= steps; i++) trail.unshift(lerpV(prev, head, i / steps)); } else trail[0] = head;
  const path = [head]; let remaining = length;
  for (let i = 1; i < trail.length; i++) { const span = dist(path[path.length - 1], trail[i]); if (span < 0.001) continue; if (span >= remaining) { path.push(lerpV(path[path.length - 1], trail[i], remaining / span)); remaining = 0; break; } path.push(trail[i]); remaining -= span; }
  if (remaining > 0.001) path.push(add(path[path.length - 1], mul(path.length > 1 ? norm(sub(path[path.length - 1], path[path.length - 2])) : V(-1, 0), remaining)));
  const points = Array.from({ length: DCOUNT + 1 }, (_, i) => pathAt(path, i / DCOUNT * length).pos); return { trail: path, points };
}
function dSetFollow(S, head, length = DP.body_length) { const followed = dFollow(S.trail, head, length); S.trail = followed.trail; S.points = followed.points; S.B.pos = S.points[0]; S.B.facing = angOf(sub(S.points[0], S.points[1])); }
function dNeckPose(S, base, head) { const off = sub(head, base[0]), pts = base.map((p, i) => add(p, mul(off, 1 - smooth(0, 0.4, i / (base.length - 1))))); S.B.pos = head; S.override = dFit(pts, base); }
function dBlend(S, from, to, k) { S.override = dFit(from.map((p, i) => lerpV(p, to[Math.round(i * (to.length - 1) / (from.length - 1))], smooth(0, 1, k))), to); S.B.pos = S.override[0]; }
// 戻り：大きくずれた所ほど遅れて戻り、減っていくうねりを残す。真っ直ぐな棒のまま一度に戻らない
function dSettle(S, from, to, k) {
  const N = from.length - 1, goal = i => to[Math.round(i * (to.length - 1) / N)], far = Math.max(1, ...from.map((p, i) => dist(p, goal(i))));
  S.override = dFit(from.map((p, i) => { const q = goal(i), d = dist(p, q) / far, w = smooth(0, 1, clamp(k * 1.4 - d * 0.4)), side = orth(norm(sub(from[Math.max(0, i - 1)], from[Math.min(N, i + 1)]))), wave = Math.sin(i / N * 9 - k * 9) * Math.sin(Math.PI * k) * Math.min(46, dist(p, q) * 0.14); return add(lerpV(p, q, w), mul(side, wave)); }), to);
  S.B.pos = S.override[0];
}
// 隕石：頭を突き出して1個ずつ吐き、速いまま飛んで、着いた所で勢いが止まる（なめらかに滑らせない）
const DR_FLIGHT = 0.24, DR_ORDER = [1, 0, 2];
function dRockAge(S, i) { if (S.B.mode !== 'windup') return S.r.warn + S.elapsed; return S.elapsed - S.r.warn * (0.2 + 0.24 * DR_ORDER[i % 3]); }
function dPart(key, pos, angle, scale, offset = null, alpha = 1, flip = false) {
  const im = IMG['draco/' + key]; if (!im) return; g.save(); g.translate(pos.x, pos.y); g.rotate(angle); g.scale(scale * (flip ? -1 : 1), scale); g.globalAlpha *= alpha; g.drawImage(im, offset ? offset.x : -im.width / 2, offset ? offset.y : -im.height / 2); g.restore();
}
function dArmFrame(points, width, total, index, turn = 0) {
  const d = index < 2 ? Math.min(total, width * 0.9) : total * 0.66, at = pathAt(points, d), next = pathAt(points, Math.min(total, d + 2)), tangent = norm(sub(next.pos, at.pos)), normal = orth(tangent), unit = width * dTaper(d / Math.max(1, total)) / 57, side = index % 2 === 0 ? -1 : 1, direction = norm(sub(mul(normal, side), mul(tangent, 0.3))), wrist = V(16 * -side, 28), angle = angOf(direction) - angOf(wrist) + turn, pos = add(at.pos, mul(normal, side * width * dTaper(d / total) * 0.32));
  return { pos, angle, unit, side, claw: add(pos, mul(rotateV(wrist, angle), unit)) };
}
function drawDraco(points, facing, alpha = 1, width = DP.body_width, armTurns = []) {
  if (points.length < 2 || alpha <= 0) return;
  const total = pathLength(points), bodyEnd = Math.max(0, total - width * 0.7), distances = []; let cursor = Math.min(bodyEnd, width * 0.43);
  while (cursor < bodyEnd) { distances.push(cursor); cursor += Math.max(1, width * 0.43 * dTaper(cursor / Math.max(1, total))); }
  if (!distances.length || bodyEnd - distances[distances.length - 1] > width * 0.08) distances.push(bodyEnd);
  distances.push(Math.max(bodyEnd, total - width * 0.42), total);
  // 腕の根元と爪先は現行のARM_ROOT・ARM_WRISTと背骨上の距離から求める。
  for (let i = 0; i < 4; i++) { const arm = dArmFrame(points, width, total, i, armTurns[i] || 0);
    dPart('arm', arm.pos, arm.angle, arm.unit, V(-11, -5), alpha, arm.side > 0); dPart('claw', arm.claw, arm.angle, arm.unit, V(-13, -16), alpha, arm.side > 0); }
  let previous = points[0];
  distances.forEach((distance, i) => { const at = pathAt(points, distance), last = i === distances.length - 1, key = last ? 'tail_tip' : i === distances.length - 2 ? 'tail_joint' : ['body_e', 'body_c', 'body_b', 'body_a', 'body_d'][Math.min(4, Math.floor(i * 5 / Math.max(1, distances.length - 2)))], im = IMG['draco/' + key], angle = angOf(sub(at.pos, previous)) + (last ? Math.PI / 2 : -Math.PI / 2), scale = width * dTaper(distance / Math.max(1, total)) / im.width;
    dPart(key, at.pos, angle, scale, last ? V(-im.width / 2, 0) : null, alpha); previous = at.pos; });
  const im = IMG['draco/head']; dPart('head', points[0], facing - Math.PI / 2, DP.head_scale * 2, V(-im.width / 2, -im.height / 2 + 14), alpha);
}
const dMouth = S => add(S.B.pos, mul(fromA(S.B.facing), 120 * DP.head_scale));
// 戦闘用の背骨と時計は保ち、見た目だけに溜め・静止・解放・反動を加える。
function dPresentation(S) {
  const B = S.B, r = S.r, windup = B.mode === 'windup', active = B.mode === 'active', releasing = active || B.mode === 'recovery', releaseTime = active ? S.elapsed : r.active + S.elapsed, ready = !S.staging || S.staging.phase === 'ready', k = windup && ready ? smooth(0.05, Math.max(0.06, r.warn * 0.82), S.elapsed) : 0;
  const recoil = t => (1 - smooth(0, 0.1, t)) - 0.46 * smooth(0.025, 0.075, t) * (1 - smooth(0.075, 0.26, t));
  let facing = B.facing, points = S.points, charge = windup ? k : releasing ? recoil(releaseTime) : 0;
  if (S.staging && ready && windup) { const entryFacing = S.staging.side < 0 ? 0 : Math.PI; facing = entryFacing + angDiff(B.facing, entryFacing) * smooth(0, r.warn * 0.6, S.elapsed); }
  if (S.tech === 'breath' && windup) facing = S.axis - r.sweep * smooth(r.warn * 0.35, r.warn * 0.9, S.elapsed);
  if (S.tech === 'breath' && active && !S.fan) facing = S.axis - r.sweep;
  const still = ['breath', 'meteor', 'star_fan'].includes(S.tech);
  if (still) points = S.base.map(p => add(p, sub(B.pos, S.base[0])));
  if (ready && !['spiral', 'clones'].includes(S.tech)) {
    const head = points[0], originalAngle = angOf(sub(head, points[1])), turn = angDiff(facing, originalAngle), u = fromA(facing), side = orth(u), bodyWeight = ['bite', 'tail_sweep', 'tail_slam'].includes(S.tech) ? 0.3 : 1;
    const desired = points.map((p, i) => { const s = i / (points.length - 1), neck = 1 - smooth(0.04, 0.37, s), bend = smooth(0.02, 0.16, s) * (1 - smooth(0.3, 0.73, s));
      const strength = releasing ? recoil(Math.max(0, releaseTime - s * 0.13)) : charge;
      return add(add(head, rotateV(sub(p, head), turn * neck)), add(mul(u, 44 * bend * strength * bodyWeight), mul(side, 64 * bend * strength * bodyWeight))); });
    points = dFit(desired, points, ['tail_sweep', 'tail_slam'].includes(S.tech));
  }
  const total = pathLength(points), arms = Array.from({ length: 4 }, (_, i) => (i % 2 ? 1 : -1) * charge * (i < 2 ? 0.42 : 0.16));
  if (S.tech === 'rifts' && ready && (windup || active)) for (let i = 0; i < 2; i++) {
    const arm = dArmFrame(points, DP.body_width, total, i), side = arm.side, baseAngle = angOf(sub(arm.claw, arm.pos)), folded = facing + Math.PI - side * 0.3, strike = S.axis - side * r.claw_angle, local = active ? S.elapsed - i * r.interval : -1;
    const reach = active ? smooth(0, r.scratch_time, local) : 0, settle = active ? smooth(r.scratch_time + 0.06, r.scratch_time + 0.48, local) : 0;
    const desired = folded + angDiff(strike, folded) * reach;
    arms[i] = angDiff(desired, baseAngle) * (windup ? k : 1 - settle);
  }
  const claws = arms.map((turn, i) => dArmFrame(points, DP.body_width, total, i, turn).claw);
  return { points, facing, charge, arms, claws, mouth: add(points[0], mul(fromA(facing), 120 * DP.head_scale)), chest: pathAt(points, Math.min(total, DP.body_width * 0.9)).pos };
}
// 光は部位から部位へ運ぶ。等間隔の線や、全技で同じ口の円を置かない。
function dSupply(R, from, to, strength, time, seed = 1, bend = 0) {
  if (strength <= 0) return;
  const pal = FX.ramp(R.P.color), u = norm(sub(to, from)), n = orth(u), control = add(lerpV(from, to, 0.5), mul(n, bend));
  for (let i = 0; i < 9; i++) { if (hash(seed + i * 13) > strength) continue; const phase = (time * 1.65 + hash(seed + i * 17)) % 1, at = lerpV(lerpV(from, control, phase), lerpV(control, to, phase), phase), q = toL(at), bright = strength * (0.25 + phase * 0.6);
    R.front.glow(q.x, q.y, 1.2 + phase, pal[2], bright * R.P.intensity * 0.17); if (phase > 0.28) R.front.px(q.x, q.y, pal[phase > 0.82 ? 3 : 1]); }
}
function dJetPicture(S, R) {
  if (!S.fan || S.B.mode !== 'active' || !R.proto) return;
  g.save(); g.beginPath(); S.fan.forEach((p, i) => i ? g.lineTo(p.x, p.y) : g.moveTo(p.x, p.y)); g.closePath(); g.clip();
  canisJetImage(S.fan[0], S.fanAngle, S.r.reach * R.P.size, S.r.reach * Math.tan(S.r.half_angle) * R.P.size, S.elapsed, Math.min(1, R.P.intensity));
  g.restore();
}
function dPredict(S, seconds, cap = DP.aim_lead_cap) { const lead = mul(S.shipVel, Math.max(0, seconds)), l = len(lead); return add(S.ship.pos, l > cap ? mul(lead, cap / l) : lead); }
function dTailPose(S, offset) { const r = S.r, bow = orth(fromA(S.axis)), points = Array.from({ length: DCOUNT + 1 }, (_, i) => { const t = i / DCOUNT; return add(add(S.origin, mul(fromA(S.axis + Math.PI + offset * t * t), r.reach * t)), mul(bow, 240 * Math.sin(Math.PI * t))); }); return dFit(points, S.base, true); } // 胴の余りを同じ側へ逃がし、振りの途中で折れ方が裏返らないようにする
function dTailCurve(S, tip) { const back = mul(fromA(S.axis), -1), side = orth(back), c1 = add(S.origin, mul(back, DP.body_length * 0.7)), c2 = add(add(tip, mul(back, 220)), mul(side, DP.body_length * 0.35)); return dFit(Array.from({ length: DCOUNT + 1 }, (_, i) => { const t = i / DCOUNT; return add(add(mul(S.origin, (1 - t) ** 3), mul(c1, 3 * (1 - t) ** 2 * t)), add(mul(c2, 3 * (1 - t) * t * t), mul(tip, t ** 3))); }), S.base, true); }
function dSetup(S, id) {
  S.tech = id; S.r = bossRule('draco', id); S.B = bossActor('draco', ['breath', 'meteor'].includes(id) ? V(-140, -90) : V(470, -80)); S.B.r = DRACO.def.radius * DP.head_scale; S.ship = shipState(V(720, 90), Math.PI / 2, 25); S.shipVel = V(0, 25); S.age = -0.5; S.elapsed = 0; S.origin = { ...S.B.pos }; S.axis = 0; S.direction = V(1, 0); S.points = dNeutral(S.B.pos, 0, 0); S.base = S.points; S.trail = S.points; S.tell = []; S.shots = []; S.rocks = []; S.impacts = []; S.rifts = []; S.effects = []; S.projectiles = []; S.units = []; S.shot = 0; S.target = dPredict(S, S.r.warn || 0);
  if (['charge', 'leap', 'rifts', 'inhale'].includes(id)) S.staging = { phase: 'exit', side: S.rng() < 0.5 ? -1 : 1, enter: id !== 'charge', height: id === 'leap' ? -0.3 : 0, age: 0, exitAngle: angOf(sub(S.points[0], S.points[1])), awayAngle: angOf(sub(S.B.pos, S.ship.pos)) };
  else { S.axis = id === 'tail_sweep' ? 0 : angOf(sub(S.ship.pos, S.B.pos)); S.B.facing = S.axis; S.direction = fromA(S.axis); S.base = dNeutral(S.B.pos, S.axis, S.t); S.trail = S.base; S.points = S.base; }
  if (id === 'bite') { S.target = dPredict(S, S.r.warn + S.r.active * 0.55, S.r.lead_cap); S.direction = norm(sub(S.target, S.origin)); S.axis = angOf(S.direction); S.B.facing = S.axis; S.base = dNeutral(S.origin, S.axis, S.t); S.retracted = sub(S.origin, mul(S.direction, S.r.retract)); S.destination = add(S.origin, mul(S.direction, S.r.reach)); }
  if (['breath', 'meteor'].includes(id)) { S.mouth = dMouth(S); const r = S.r; for (let i = 0; i < r.rocks; i++) { const to = add(add(S.mouth, mul(S.direction, r.rock_distance)), mul(orth(S.direction), (i - (r.rocks - 1) * 0.5) * r.rock_spacing)); S.rocks.push({ from: S.mouth, to, pos: S.mouth, radius: r.rock_radius, seed: i }); } }
  if (id === 'picaro_wall') { const r = S.r, center = lerpV(S.B.pos, S.ship.pos, 0.45); S.picaro = Array.from({ length: r.count }, (_, i) => mkE(r.wall_candidates[i % r.wall_candidates.length], add(center, mul(orth(S.direction), (i - (r.count - 1) * 0.5) * 180)), S.axis)); }
  if (id === 'clones') { const choices = ['bite_thrust', 'wind_band', 'rubble_fan', 'beam_fixed', 'thunder_drop']; for (let i = choices.length - 1; i > 0; i--) { const j = Math.floor(S.rng() * (i + 1)); [choices[i], choices[j]] = [choices[j], choices[i]]; }
    S.center = { ...S.ship.pos }; for (let i = 0; i < 3; i++) { const pos = i === 0 ? { ...S.B.pos } : add(S.center, mul(fromA(i * TAU / 3), 650)), angle = angOf(sub(S.center, pos)); S.units.push({ pos, origin: { ...pos }, angle, face: angle, mode: choices[i], t: 0, index: i, target: { ...S.center }, glow: 0, locked: false, length: 100, step: 0, points: dNeutral(pos, angle, 0), turn: i % 2 ? 1 : -1 }); }
  }
  if (id === 'spiral') dSpiralBegin(S);
}
function dOffscreen(S) { const half = V(W / Z / cam.zoom / 2, H / Z / cam.zoom / 2); return S.points.every((p, i) => { const r = i === 0 ? S.B.r : DP.body_width * 0.5 * dTaper(i / (S.points.length - 1)); return Math.abs(p.x - cam.x) > half.x + r || Math.abs(p.y - cam.y) > half.y + r; }); }
function dStaging(S, dt) {
  const st = S.staging; if (!st || st.phase === 'ready') return true; S.elapsed = 0; st.age += dt; S.override = null;
  const half = V(W / Z / cam.zoom / 2, H / Z / cam.zoom / 2);
  if (st.phase === 'exit') { const angle = st.exitAngle + angDiff(st.awayAngle, st.exitAngle) * smooth(0, 0.45, st.age), speed = Math.max((DP.body_length + len(half) * 2 + DP.body_width * 2) / 1.65, len(S.shipVel) + 1000); dSetFollow(S, add(S.B.pos, mul(fromA(angle), speed * dt)));
    if (!dOffscreen(S)) return false;
    st.from = V(cam.x + st.side * (half.x + S.B.r + 120), cam.y + half.y * st.height); st.to = V(cam.x + st.side * Math.min(700, half.x * 0.68), st.from.y); S.B.pos = st.from; S.B.facing = st.side < 0 ? 0 : Math.PI;
    S.trail = Array.from({ length: DCOUNT + 1 }, (_, i) => add(st.from, V(st.side * DP.body_length * i / DCOUNT, 0))); S.points = S.trail; st.age = 0; st.phase = st.enter ? 'enter' : 'ready';
  } else { dSetFollow(S, lerpV(st.from, st.to, smooth(0, 0.42, st.age))); if (st.age >= 0.42) st.phase = 'ready'; }
  if (st.phase !== 'ready') return false; S.origin = { ...S.B.pos }; S.base = dNeutral(S.origin, S.B.facing, S.t); return true;
}
function dLock(S) {
  const r = S.r, id = S.tech, B = S.B;
  if (id === 'charge') { let predicted = S.ship.pos; for (let i = 0; i < 3; i++) { const d = dist(S.origin, predicted), fraction = clamp((d - 105 * DP.head_scale) / Math.max(1, d + r.overshoot)); predicted = dPredict(S, Math.max(0, r.warn - S.elapsed) + r.active * fraction, r.lead_cap); } S.target = predicted; S.direction = norm(sub(S.target, S.origin)); S.destination = add(S.target, mul(S.direction, r.overshoot)); }
  else if (id === 'leap') { S.target = dPredict(S, Math.max(0, r.warn - S.elapsed) + r.active, r.lead_cap); S.direction = norm(sub(S.target, S.origin)); S.takeoff = sub(S.origin, mul(S.direction, 70)); S.destination = sub(S.target, mul(S.direction, 105 * DP.head_scale)); }
  else if (id === 'rifts') { S.center = { ...S.ship.pos }; S.direction = norm(sub(S.center, B.pos)); const forward = S.direction, side = orth(forward), start = 125 * DP.head_scale, length = Math.min(r.reach, dist(S.center, B.pos) + r.claw_overshoot - start); S.paths = [];
    for (const hand of [-1, 1]) for (let j = 0; j < r.claw_count; j++) { const stripe = hand * r.claw_offset + (j - (r.claw_count - 1) * 0.5) * r.claw_gap, a = add(add(B.pos, mul(forward, start)), mul(side, stripe)), b = add(a, mul(rotateV(forward, -hand * r.claw_angle), Math.max(1, length))); S.paths.push([a, b]); }
  }
  else if (id === 'inhale') S.direction = norm(sub(S.ship.pos, B.pos));
  S.axis = angOf(S.direction); B.facing = S.axis;
}
function dWindup(S, dt) {
  const r = S.r, id = S.tech, B = S.B, k = smooth(0, r.warn, S.elapsed);
  if (S.staging) { if (!dStaging(S, dt)) return; if (!S.locked) { dLock(S); S.locked = id === 'rifts' || S.elapsed >= Math.min(0.2, r.warn * 0.3); } }
  if (id === 'bite') { dNeckPose(S, S.base, lerpV(S.origin, S.retracted, k)); S.tell = [[S.origin, add(S.destination, mul(S.direction, 105 * DP.head_scale))]]; }
  else if (id === 'charge') S.tell = [[add(S.origin, mul(S.direction, 105 * DP.head_scale)), add(S.destination, mul(S.direction, 105 * DP.head_scale))]];
  else if (id === 'leap') { const setup = Math.min(0.2, r.warn * 0.3), head = S.elapsed < setup ? S.origin : lerpV(S.origin, S.takeoff, smooth(setup, r.warn, S.elapsed)); dNeckPose(S, S.base, head); S.tell = [[add(S.takeoff, mul(S.direction, 105 * DP.head_scale)), S.target]]; }
  else if (id === 'rifts') S.tell = S.paths || [];
  else if (id === 'tail_sweep') { dBlend(S, S.base, dTailPose(S, -r.half_angle), S.elapsed / r.warn); S.tell = [Array.from({ length: 33 }, (_, i) => add(S.origin, mul(fromA(S.axis + Math.PI - r.half_angle + r.half_angle * 2 * i / 32), r.reach)))]; }
  else if (id === 'tail_slam') { if (!S.locked) { S.target = dPredict(S, Math.max(0, r.warn - S.elapsed) + r.active * 0.65, r.lead_cap); if (dist(S.target, S.origin) > r.reach) S.target = add(S.origin, mul(norm(sub(S.target, S.origin)), r.reach)); S.lifted = dTailCurve(S, add(S.target, V(0, -180))); S.locked = S.elapsed >= Math.min(0.25, r.warn * 0.35); } dBlend(S, S.base, S.lifted, S.elapsed / r.warn); }
  else if (['breath', 'meteor'].includes(id)) S.rocks.forEach((q, i) => { q.pos = lerpV(q.from, q.to, clamp(dRockAge(S, i) / DR_FLIGHT)); });
  else if (id === 'star_fan') { if (!S.locked) { let predicted = S.ship.pos; for (let i = 0; i < 8; i++) predicted = dPredict(S, Math.max(0, r.warn - S.elapsed) + Math.max(0, dist(B.pos, predicted) - r.radius) / r.speed, r.lead_cap); S.direction = norm(sub(predicted, B.pos)); B.facing = angOf(S.direction); S.starPositions = []; for (let i = 0; i < r.count; i++) { const a = B.facing + lerp(-r.arc, r.arc, i / Math.max(1, r.count - 1)); S.starPositions.push({ pos: add(B.pos, mul(fromA(a), r.radius)), a }); } S.locked = S.elapsed >= Math.min(0.25, r.warn * 0.35); } }
  else if (id === 'spiral') dSpiralWindup(S, dt);
}
function dActive(S, dt) {
  const r = S.r, id = S.tech, B = S.B, t = S.elapsed; S.tell = [];
  if (id === 'bite') dNeckPose(S, S.base, lerpV(S.retracted, S.destination, dBurst(t / r.active)));
  else if (id === 'charge') B.pos = lerpV(S.origin, S.destination, dBurst(t / r.active));
  else if (id === 'leap') B.pos = lerpV(S.takeoff, S.destination, dBurst(t / r.active));
  else if (id === 'tail_sweep') S.override = dTailPose(S, lerp(-r.half_angle, r.half_angle, smooth(0.04, 0.92, t / r.active)));
  else if (id === 'tail_slam') { const drop = dSlam(t / (r.active * 0.65)); S.override = dTailCurve(S, lerpV(add(S.target, V(0, -180)), S.target, drop)); if (drop >= 1 && !S.landed) { S.landed = true; S.impacts.push({ at: S.target, t: S.t, radius: r.radius }); } }
  else if (id === 'breath') { S.fanAngle = S.axis + lerp(-r.sweep, r.sweep, smooth(0, 1, t / r.active)); B.facing = S.fanAngle; S.override = S.base; S.fan = [dMouth(S)];
    for (let j = 0; j <= 64; j++) { const a = S.fanAngle - r.half_angle + r.half_angle * 2 * j / 64, u = fromA(a), origin = dMouth(S); let reach = r.reach;
      for (const rock of S.rocks) { const off = sub(rock.pos, origin), projection = off.x * u.x + off.y * u.y, perp2 = len(off) ** 2 - projection ** 2; if (projection > 0 && perp2 < rock.radius ** 2) reach = Math.min(reach, Math.max(0, projection - Math.sqrt(rock.radius ** 2 - perp2))); } S.fan.push(add(origin, mul(u, reach))); }
  } else if (id === 'star_fan' && !S.fired) { S.fired = true; for (const q of S.starPositions) S.shots.push({ pos: { ...q.pos }, a: q.a, speed: r.speed, t: S.t, radius: r.width, life: 4, kind: 'star' }); }
  else if (id === 'rifts') { for (let i = 0; i < (S.paths || []).length; i++) { const hand = Math.floor(i / r.claw_count), local = t - hand * r.interval; if (local < 0) { S.tell.push(S.paths[i]); continue; } const path = S.paths[i], tip = lerpV(path[0], path[1], clamp(local / r.scratch_time)); S.rifts[i] = { a: path[0], b: tip, age: local, seed: i }; } }
  else if (id === 'inhale') dInhale(S, dt);
  else if (id === 'clones') dClones(S, dt);
  else if (id === 'picaro_wall') {
    if (S.shot < r.arrows && t >= S.shot * r.interval) { const from = add(B.pos, mul(fromA(B.facing), 100 * DP.head_scale)), leave = Math.max(0, from.y - (cam.y - H / Z / 2) + 80) / 900; S.shots.push({ pos: from, a: -Math.PI / 2, speed: 900, t: S.t, radius: 12, life: 3, kind: 'arrow' }); S.arrowImpacts ||= []; S.arrowImpacts.push({ t: S.t, wait: Math.max(r.flight, leave + 0.15), warn: r.impact_warn }); S.shot++; }
    for (const q of S.arrowImpacts || []) { const age = S.t - q.t; if (!q.at && age >= q.wait) q.at = { ...S.ship.pos }; if (!q.hit && age >= q.wait + q.warn) { q.hit = true; S.impacts.push({ at: q.at, t: S.t, radius: r.radius }); } }
  } else if (id === 'spiral') dSpiralActive(S, dt);
}
function dInhale(S, dt) {
  const r = S.r, B = S.B, t = S.elapsed;
  S.inhaleBody ||= S.points.map(p => ({ ...p })); S.override = S.inhaleBody;
  if (t < r.inhale_time) { if (!S.caught) { B.facing = rotToward(B.facing, angOf(sub(S.ship.pos, B.pos)), 1.2 * dt); S.direction = fromA(B.facing); const mouth = dMouth(S), toward = sub(mouth, S.ship.pos); if (len(toward) < r.pull_range) { S.ship.pos = add(S.ship.pos, mul(norm(toward), Math.min(len(toward), r.pull_speed * dt))); if (len(toward) < r.mouth_radius + DATA.config.ship_radius) { S.caught = true; S.releaseAt = S.t + 0.8; S.ship.pos = add(mouth, mul(S.direction, DP.head_scale * 100)); S.shipVel = mul(S.direction, 1000); } } } else if (S.t < S.releaseAt) S.ship.pos = add(S.ship.pos, mul(S.shipVel, dt)); return; }
  if (!S.exhale) { S.direction = norm(sub(S.ship.pos, B.pos)); B.facing = angOf(S.direction); S.exhale = { at: dMouth(S), a: B.facing, t: S.t }; let remaining = Math.min(r.comet_cap, Math.round(P().stars) * r.comets_per_star);
    const arcs = (r.arcs || []).map(ref => ({ radius: 180, ...r.subresources[ref.id] }));
    arcs.forEach((arc, index) => { const quota = Math.min(arc.count, Math.ceil(remaining / (arcs.length - index))); for (let j = 0; j < quota; j++) { const angle = B.facing + (arc.angle_degrees + lerp(-arc.spread_degrees, arc.spread_degrees, j / Math.max(1, quota - 1))) * Math.PI / 180, origin = add(add(dMouth(S), rotateV(arc.offset || V(0, 0), B.facing)), mul(fromA(angle), arc.radius)); S.shots.push({ pos: origin, a: angle, speed: r.comet_speed, t: S.t, radius: 12, life: 5, kind: 'comet' }); } remaining -= quota; });
  }
}
const DC_BACK = 1.25; // 全身複製：飛び込み0.5秒のあと、回り込んで持ち場へ戻り終える時刻
function dClones(S, dt) {
  for (const unit of S.units) { const t = S.elapsed - unit.index * 0.7, forward = fromA(unit.angle), landing = sub(S.center, mul(forward, 120 * DP.head_scale)); if (t < 0) continue; if (t >= DC_BACK) unit.face = unit.angle;
    if (t < 0.5) unit.pos = lerpV(unit.origin, landing, dBurst(t / 0.5));
    else if (t < DC_BACK) { const before = unit.pos, k = smooth(0, 1, (t - 0.5) / (DC_BACK - 0.5)), bend = add(lerpV(landing, unit.origin, 0.5), mul(orth(forward), unit.turn * 340)); unit.pos = lerpV(lerpV(landing, bend, k), lerpV(bend, unit.origin, k), k); const way = angOf(sub(unit.pos, before)); unit.face = k < 0.7 ? way : way + angDiff(unit.angle, way) * smooth(0.7, 1, k); }
    else if (!unit.done) { unit.t += dt; const r = hRule(unit.mode), elapsed = unit.t - r.normal_charge; unit.glow = clamp(unit.t / r.normal_charge); if (elapsed >= 0 && !unit.locked) { unit.locked = true; unit.from = { ...unit.pos }; unit.sweep = angOf(sub(unit.target, unit.pos));
        if (unit.mode === 'beam_fixed') hEffect(S, 'beam', [unit.pos, add(unit.pos, mul(fromA(unit.angle), r.beam_len))], r.beam_width, 0, r.beam_time);
        if (unit.mode === 'wind_band') hEffect(S, 'wind', [unit.pos, add(unit.pos, mul(fromA(unit.angle), r.wind_length))], r.wind_width, 0, r.wind_time);
        if (unit.mode === 'thunder_drop') hEffect(S, 'lightning', [unit.target, unit.target], r.thunder_radius * 2, 0, r.thunder_flash);
        if (unit.mode === 'rubble_fan') for (let j = 0; j < r.rubble_count; j++) S.projectiles.push({ pos: { ...unit.pos }, vel: mul(fromA(unit.angle + r.rubble_spread * (j / (r.rubble_count - 1) - 0.5)), r.lump_speed), radius: r.rubble_small_radius, t: S.t, life: 6, seed: j });
      }
      if (unit.mode === 'bite_thrust' && elapsed >= 0) { const before = unit.pos; unit.pos = lerpV(unit.from, unit.target, dBurst(elapsed / r.normal_lunge)); if (elapsed < r.normal_lunge) hEffect(S, 'bite', [before, unit.pos], r.bite_radius, 0, 0.1); }
      const duration = unit.mode === 'beam_fixed' ? r.beam_time : unit.mode === 'wind_band' ? r.wind_time : unit.mode === 'bite_thrust' ? r.normal_lunge : unit.mode === 'thunder_drop' ? r.thunder_flash : 0;
      if (elapsed >= duration + r.normal_hold) unit.done = true;
    }
    if (S.elapsed > S.r.active - 1 && unit.index > 0) unit.pos = lerpV(unit.pos, S.units[0].pos, Math.min(1, dt * 5)); { const followed = dFollow(unit.trail || unit.points, unit.pos); unit.trail = followed.trail; unit.points = followed.points; }
  }
  S.B.pos = S.units[0].pos; S.B.facing = S.units[0].angle; S.override = S.units[0].points;
}
function dSpiralBegin(S) {
  // 試作のつまみ：胴（しっぽ）の長さと、円になってから飛び出すまでの待ち。待ちを延ばした分だけ攻撃の時間も延ばす
  { const q = P(), r0 = S.r; r0.spiral_length *= q.spiralTail ?? 0.85; r0.pause = q.spiralWait ?? 2.8; r0.active = r0.coil_time + r0.pause + r0.shrink_time + 1.2; }
  const r = S.r, width = DP.body_width, half = V(W / Z / 2 / 0.82, H / Z / 2 / 0.82), broad = Math.max(half.x, half.y) * clamp(r.radius_factor, 0.5, 1.5), clearance = S.B.r + width * 0.5 + DATA.config.ship_radius * 2 + 40, extent = Math.max(width * 4, broad, width * 3 + clearance) * (P().spiralScale ?? 1.3), /* 外周を広げて周回の間を空ける（内周は頭の余白で決まる） */ smallest = Math.min(1, clearance / extent), largest = Math.max(smallest, 1 - width * 3 / extent), inner = clamp(r.inner_radius_factor / r.radius_factor, smallest, largest), shrink = clamp(r.shrink_time, 0.3, Math.max(0.3, r.active * 0.5)), coil = clamp(r.coil_time, 0.5, Math.min(3, Math.max(0.5, r.active - shrink - 0.8))), pause = clamp(r.pause, 0.8, Math.min(5, Math.max(0.8, r.active - shrink - coil - 0.15))), headClearance = S.B.r + DATA.config.ship_radius + 60, headOffset = clamp(r.head_offset, headClearance, Math.max(headClearance, extent * (1 + inner) * 0.5 * 0.8));
  S.spiral = { center: { ...S.ship.pos }, extent, horizontal: extent, inner, shrink, coil, pause, first: coil * 0.35, second: coil * 0.45, bendTime: coil * 0.2, bendRadius: Math.max(40, extent * inner * 0.35), headOffset, phase: 'exit', depart: 0, exitAngle: angOf(sub(S.points[0], S.points[1])) }; cam.zoom = 1;
}
function dSpiralWindup(S, dt) {
  const sp = S.spiral; dSpiralCamera(S, dt); const half = V(W / Z / cam.zoom / 2, H / Z / cam.zoom / 2);
  if (sp.phase === 'exit') { sp.depart += dt; const angle = sp.exitAngle + angDiff(-Math.PI / 2, sp.exitAngle) * smooth(0, 0.55, sp.depart), speed = Math.max((DP.body_length + half.y * 2 + DP.body_width * 2) / clamp(S.r.exit_duration, 0.6, 3), 1100); dSetFollow(S, add(S.B.pos, mul(fromA(angle), speed * dt))); S.elapsed = Math.min(S.elapsed, S.r.warn - 1.01);
    if (dOffscreen(S)) { sp.phase = 'entry'; sp.center = { ...S.ship.pos }; const margin = S.B.r + DP.body_width + 100; sp.outside = V(Math.max(sp.center.x + sp.horizontal + margin, cam.x + half.x + margin), Math.min(sp.center.y - sp.extent - margin, cam.y - half.y - margin)); sp.control = add(sp.center, V(sp.horizontal * 0.52, -sp.extent)); sp.inside = add(sp.center, V(0, -sp.extent)); S.trail = Array.from({ length: DCOUNT + 1 }, (_, i) => add(sp.outside, V(S.r.spiral_length * i / DCOUNT, 0))); S.points = S.trail; S.B.pos = sp.outside; S.elapsed = S.r.warn - 1; } return;
  }
  const shift0 = mul(sub(S.ship.pos, sp.center), 1 - Math.exp(-1.4 * dt)), shift = len(shift0) > 350 * dt ? mul(norm(shift0), 350 * dt) : shift0; sp.center = add(sp.center, shift); for (const key of ['outside', 'control', 'inside']) sp[key] = add(sp[key], shift); S.trail = S.trail.map(p => add(p, shift));
  const k = clamp(S.elapsed - (S.r.warn - 1)), head = lerpV(lerpV(sp.outside, sp.control, k), lerpV(sp.control, sp.inside, k), k); dSetFollow(S, head, S.r.spiral_length);
}
// 渦：中心へ行くほど半径が小さくなる螺旋（外周→内周を2周で一定に縮め、隣の周回との間に逃げ道を残す）。中心は巻き始めの自機の位置で固定し、ずらさない。
function dSpiralHead(S, turns) {
  const sp = S.spiral, angle = -Math.PI / 2 - turns * TAU, radius = lerp(sp.extent, sp.extent * sp.inner, turns / 2);
  return add(sp.center, V(Math.cos(angle) * radius, Math.sin(angle) * radius));
}
// 直進：頭が真下へ抜け、残りの胴は紐を結ぶように、引かれた分だけ渦ごと中心へ締まっていく
function dSpiralPull(S, pulled) {
  const sp = S.spiral, L = S.r.spiral_length, d = V(0, 1), coil = sp.coilPoints, total = pathLength(coil), tight = smooth(0, L * 0.7, pulled);
  S.points = Array.from({ length: DCOUNT + 1 }, (_, i) => { const s = i / DCOUNT * L; if (s <= pulled) return add(sp.pullFrom, mul(d, pulled - s));
    const rest = s - pulled, at = pathAt(coil, Math.min(total, rest)).pos, k = lerp(1, 1 - 0.8 * tight, smooth(0, 260, rest)); return add(sp.center, mul(sub(at, sp.center), k)); });
  dRound(S.points, Math.round(pulled / L * DCOUNT), 6, 14);
  S.trail = S.points; S.B.pos = S.points[0]; S.B.facing = angOf(sub(S.points[0], S.points[1]));
}
// 折れた所をならす：at の前後 span 個の点を、隣の点の真ん中へ少しずつ寄せる（頭と尾の端は動かさない）
function dRound(points, at, span, passes) {
  const a = Math.max(1, at - span), b = Math.min(points.length - 2, at + span); if (b <= a) return;
  for (let k = 0; k < passes; k++) for (let i = a; i <= b; i++) { const w = 0.5 * (1 - Math.abs(i - at) / (span + 1)); points[i] = lerpV(points[i], lerpV(points[i - 1], points[i + 1], 0.5), w); }
}
function dSpiralActive(S, dt) {
  const sp = S.spiral, t = S.elapsed, shrinkAt = sp.coil + sp.pause; dSpiralCamera(S, dt);
  if (!sp.held) sp.held = { ...S.ship.pos };
  if (t < sp.coil) S.ship.pos = { ...sp.held };
  if (t < shrinkAt) {
    let turns = t < sp.first ? t / sp.first : 1 + (t - sp.first) / sp.second; turns = clamp(turns, 0, 2); turns = clamp(turns + 0.035 * Math.sin(turns * TAU * 2.5) * Math.sin(turns * Math.PI / 2), 0, 2); // 押し出すような速さの緩急（進みは戻らない）
    let head = dSpiralHead(S, turns);
    // 巻き終わり：自機の真上で曲げて頭を画面の下へ向ける。曲げた分だけ最後の4分の1周で寄せて、真下への直進が中心を通るようにする
    const bend = clamp((t - sp.first - sp.second) / sp.bendTime) * Math.PI / 2; head = add(head, V(-sp.bendRadius * Math.sin(bend) + sp.bendRadius * smooth(1.75, 2, turns), sp.bendRadius * (1 - Math.cos(bend))));
    dSetFollow(S, head, S.r.spiral_length); if (t > sp.first + sp.second) { S.points = S.points.map(q => ({ ...q })); dRound(S.points, 4, 4, 10);
      // 頭と首の付け根を真下へそろえる（曲げ終わるほど強く）
      const w = smooth(0, 1, bend / (Math.PI / 2)), seg = S.r.spiral_length / DCOUNT; for (let i = 1; i <= 3; i++) S.points[i] = lerpV(S.points[i], sub(S.points[0], V(0, seg * i)), w * (1 - (i - 1) / 3)); S.B.facing = S.B.facing + angDiff(Math.PI / 2, S.B.facing) * w; } if (t >= sp.coil) S.tell = [[S.B.pos, add(S.B.pos, V(0, sp.extent * 2))]];
    return;
  }
  if (!sp.coilPoints) { sp.coilPoints = S.points.map(p => ({ ...p })); sp.pullFrom = { ...S.points[0] }; }
  dSpiralPull(S, (t - shrinkAt) * (sp.extent * 2 + S.r.spiral_length) / sp.shrink);
}
function dSpiralCamera(S, dt) { cam.zoom = lerp(cam.zoom, 0.82, 1 - Math.exp(-3 * dt)); cam.x = lerp(cam.x, S.ship.pos.x, 1 - Math.exp(-5 * dt)); cam.y = lerp(cam.y, S.ship.pos.y, 1 - Math.exp(-5 * dt)); }
function dEnd(S) {
  S.landedPoints = (S.override || S.points).map(p => ({ ...p })); S.settled = { ...S.B.pos }; S.tell = []; S.fan = null;
  if (S.tech === 'breath') { for (const q of S.rocks) S.impacts.push({ at: q.pos, t: S.t, radius: q.radius }); S.rocks = []; }
  S.exhale = null; S.B.mode = 'recovery'; S.elapsed = 0;
}
function dRecover(S) {
  const r = S.r, id = S.tech, k = S.elapsed / r.recover;
  if (['bite', 'tail_sweep', 'tail_slam'].includes(id)) dSettle(S, S.landedPoints, dNeutral(S.origin, S.axis, S.t), k);
  else if (id === 'charge') S.B.pos = add(S.settled, mul(S.direction, 45 * smooth(0, 1, k)));
  else if (id === 'leap') S.B.pos = add(S.settled, mul(S.direction, 30 * smooth(0, 1, k)));
  else if (id === 'breath') { S.B.facing = lerp(S.axis + r.sweep, S.axis, smooth(0, 1, k)); dSettle(S, S.landedPoints, dNeutral(S.B.pos, S.axis, S.t), k); }
  else if (id === 'inhale') S.override = S.inhaleBody;
  else if (id === 'spiral') { const sp = S.spiral, speed = (sp.extent * 2 + r.spiral_length) / sp.shrink; if (sp.coilPoints) dSpiralPull(S, (S.r.active - sp.coil - sp.pause + S.elapsed) * speed); }
}
function dStep(S, dt) {
  S.age += dt; if (S.age < 0) return;
  if (S.tech !== 'inhale' && !(S.tech === 'spiral' && S.B.mode === 'active' && S.elapsed < S.spiral.coil)) { S.ship.pos.y = 90 + Math.sin(S.t * 0.5) * 50; S.shipVel = V(0, Math.cos(S.t * 0.5) * 25); }
  S.elapsed += dt; const B = S.B, r = S.r, before = { ...B.pos }; S.override = null;
  if (B.mode === 'windup') { dWindup(S, dt); if (S.elapsed >= r.warn) { B.mode = 'active'; S.elapsed = 0; S.tell = []; } }
  else if (B.mode === 'active') { dActive(S, dt); if (S.elapsed >= r.active) dEnd(S); }
  else if (B.mode === 'recovery') { dRecover(S); if (S.elapsed >= r.recover) { B.mode = 'idle'; S.elapsed = 0; S.tell = []; } }
  if (S.override) { S.points = S.override; S.trail = S.points; }
  else if (!S.staging || S.staging.phase === 'ready') { if (S.tech !== 'spiral' || B.mode === 'idle') { const followed = dFollow(S.trail, B.pos); S.trail = followed.trail; S.points = followed.points; } }
  B.vel = dt > 0 ? mul(sub(B.pos, before), 1 / dt) : V(0, 0);
  for (const shot of S.shots) shot.pos = add(shot.pos, mul(fromA(shot.a), shot.speed * dt)); S.shots = S.shots.filter(q => S.t - q.t <= q.life);
  for (const q of S.projectiles) q.pos = add(q.pos, mul(q.vel, dt)); S.projectiles = S.projectiles.filter(q => S.t - q.t < q.life);
  for (const e of S.effects) if (S.t - e.t >= e.delay) e.points = e.points.map(p => add(p, mul(e.vel, dt))); S.effects = S.effects.filter(e => S.t - e.t < e.delay + e.life);
}
function dTellDraw(S, R, pose) {
  const k = clamp(S.elapsed / Math.max(0.01, S.r.warn));
  for (const path of S.tell) {
    if (!R.proto) { D2.polyline(path, rgba('#f8b05b', 0.42 + k * 0.4), 3); continue; }
    // 経路は図形の線で囲まず、幅の中にゆらぐ光を流す。
    const total = pathLength(path), samples = Math.min(70, Math.ceil(total / 24)), pal = FX.ramp(R.P.color);
    for (let i = 0; i < samples; i++) { const q = pathAt(path, total * i / Math.max(1, samples - 1)), lateral = (hash(i * 7) - 0.5) * (S.r.width || 45), at = toL(add(q.pos, mul(orth(fromA(q.angle)), lateral))); R.back.glow(at.x, at.y, 2 + Math.sin(i + S.t * 8) * 0.4, pal[2], (0.08 + k * 0.15) * R.P.intensity); }
  }
  if (S.B.mode === 'windup' && R.proto && (!S.staging || S.staging.phase === 'ready')) {
    const id = S.tech;
    if (id === 'rifts') for (let i = 0; i < 2; i++) { bossGather(R, pose.claws[i], 66, k, S.t, 191 + i); dSupply(R, pose.chest, pose.claws[i], k, S.t, 211 + i, i ? 32 : -32); }
    else if (['tail_sweep', 'tail_slam'].includes(id)) { const end = pose.points[pose.points.length - 1]; bossGather(R, end, 100, k, S.t, 193); dSupply(R, pathAt(pose.points, pathLength(pose.points) * 0.72).pos, end, k, S.t, 213); }
    else if (['charge', 'leap', 'spiral', 'clones'].includes(id)) bossGather(R, pose.chest, 100, k, S.t, 194);
    else { bossGather(R, pose.mouth, 85, k, S.t, 191); dSupply(R, pose.chest, pose.mouth, k, S.t, 215, 30); }
  }
  if (S.tech === 'tail_slam' && S.B.mode === 'windup' && S.target) { if (R.proto) bossGather(R, S.target, S.r.radius * 1.2, k, S.t, 121); else D2.arc(S.target, S.r.radius, 0, TAU, '#f8b05b', 3); }
  if (S.tech === 'star_fan' && S.B.mode === 'windup') for (const [i, q] of (S.starPositions || []).entries()) { if (R.proto) { dSupply(R, pose.mouth, q.pos, smooth(0.15, 0.8, k), S.t, 230 + i, (i - S.starPositions.length * 0.5) * 7); bossGather(R, q.pos, 28, k, S.t, Math.floor(q.a * 100) + 123); } else D2.circle(q.pos, 8 + k * 4, '#ffca7a'); }
}
function dDraw(S, R) {
  R = bossView(R, '#ab9cff');
  const r = S.r, B = S.B, P = R.P, id = S.tech, t = S.t, pose = R.proto ? dPresentation(S) : null; dTellDraw(S, R, pose);
  if (S.fan && B.mode === 'active' && !R.proto) { D2.poly(S.fan, rgba('#5775ff', 0.5)); D2.polyline(S.fan, '#addbff', 4); }
  if (id === 'inhale' && B.mode === 'active' && S.elapsed < r.inhale_time && R.proto) { const mouth = dMouth(S), A = toL(mouth), pal = FX.ramp(P.color); for (let i = 0; i < 80; i++) { const phase = (hash(i * 17) + t * (0.5 + hash(i))) % 1, angle = hash(i * 31) * TAU, rad = r.pull_range * (1 - phase), world = add(mouth, mul(fromA(angle), rad)); const q = toL(world); R.back.glow(q.x, q.y, 1.5, pal[2], phase * 0.20 * P.intensity); if (phase > 0.6) R.back.px(q.x, q.y, pal[2]); } }
  if (S.exhale && B.mode === 'active') { const e = S.exhale, age = t - e.t, end = add(e.at, mul(fromA(e.a), r.reach));
    if (age < r.beam_warn) { if (R.proto) bossGather(R, e.at, 150, clamp(age / r.beam_warn), t, 21); else D2.line(e.at, end, rgba('#d4bbff', 0.35), 4); }
    else { const length = r.reach * clamp((age - r.beam_warn) / r.beam_extend), tip = add(e.at, mul(fromA(e.a), length)); if (R.proto) FXW.beam(R.front, e.at, tip, { color: P.color, w: r.width * 0.5 * P.size, time: t, intensity: P.intensity, taper: 6, source: false }); else D2.line(e.at, tip, '#d4bbff', r.width); }
  }
  for (const e of S.effects) hDrawEffect(S, R, e);
  for (const q of S.projectiles) { if (R.proto) drawImg('meteor_0', q.pos, q.seed + t, q.radius); else D2.circle(q.pos, q.radius, '#8c704c'); }
  for (const rock of S.rocks) drawImg('meteor_0', rock.pos, rock.seed * 1.7, rock.radius);
  for (const q of S.rifts) { if (!q) continue; if (R.proto) { if (q.age < r.scratch_time + 0.4) bossSlash(R, q.a, q.b, r.scratch_width, Math.max(0, q.age - r.scratch_time * 0.5), 0.7, q.seed); const pal = FX.ramp(P.color), length = dist(q.a, q.b), u = norm(sub(q.b, q.a)), side = orth(u); for (let d = 0; d < length; d += 6) { const at = toL(add(add(q.a, mul(u, d)), mul(side, Math.sin(d * 0.12) * 2))); R.back.px(at.x, at.y, pal[0]); R.back.glow(at.x, at.y, 2, pal[2], 0.08 * P.intensity); } } else D2.line(q.a, q.b, '#34224d', r.width); }
  R.blitBack();
  if (id === 'clones' && B.mode === 'active') { for (const unit of S.units) drawDraco(unit.points, unit.angle, unit.index > 0 ? 0.85 : 1); }
  else if (R.proto) drawDraco(pose.points, pose.facing, 1, DP.body_width, pose.arms);
  else drawDraco(S.points, B.facing);
  dJetPicture(S, R);
  if (id === 'rifts' && B.mode === 'active' && R.proto) for (let hand = 0; hand < 2; hand++) { const local = S.elapsed - hand * r.interval, path = S.paths?.[hand * r.claw_count]; if (path && local >= 0 && local < 0.18) dSupply(R, pose.claws[hand], path[0], 1 - local / 0.18, t * 3, 311 + hand, hand ? 22 : -22); }
  if (S.picaro) for (const q of S.picaro) drawEnemy(q, { white: clamp(1 - S.age) * 0.6 });
  const chest = toL(R.proto ? pose.chest : sub(B.pos, mul(fromA(B.facing), 110 * DP.head_scale))); R.front.glow(chest.x, chest.y, 10, hexc('#8dbdff'), 0.35 + (R.proto ? Math.max(0, pose.charge) * 0.25 : 0));
  for (const q of S.shots) {
    if (R.proto) { bossTrail(R, [sub(q.pos, mul(fromA(q.a), q.kind === 'comet' ? 90 : 45)), q.pos], 0, P.color); const A = toL(q.pos); R.front.glow(A.x, A.y, q.radius * WL * 2 + 2, hexc(P.color), 0.65 * P.intensity); R.front.px(A.x, A.y, hexc('#ffffff')); }
    else if (q.kind === 'arrow') drawArrow(q.pos, q.a, q.radius); else { const u = fromA(q.a), side = orth(u), points = [add(q.pos, mul(u, q.radius * 1.5)), add(q.pos, mul(side, q.radius)), sub(q.pos, mul(u, q.radius * 1.5)), sub(q.pos, mul(side, q.radius))]; D2.poly(points, '#d4bbff'); }
  }
  for (const impact of S.arrowImpacts || []) if (impact.at && !impact.hit) { if (R.proto) bossGather(R, impact.at, r.radius, clamp((t - impact.t - impact.wait) / impact.warn), t, 171); else D2.arc(impact.at, r.radius, 0, TAU, '#b7a3ff', 3); }
  for (const impact of S.impacts) { const age = t - impact.t; if (R.proto) { bossBreath(R, impact.at, 0, age, 231, Math.PI, impact.radius * 1.4); FXW.sparks(R.front, impact.at, age / P.timing, 83, 18, P.color, 50, 0.6); } else if (age < 0.65) D2.arc(impact.at, impact.radius * (0.35 + age / 0.65 * 1.4), 0, TAU, rgba('#9fbaff', 1 - age / 0.65), 6); }
  drawShip(S.ship);
}
for (const id of Object.keys(DRACO.moves)) {
  const r = bossRule('draco', id);
  DEMOS.push({ id: 'D-' + id, ids: id === 'inhale' ? ['D03', 'D04'] : ['D04'], cat: 'りゅう座（D）', group: 'りゅう座', title: r.display_name, duration: id === 'spiral' ? 17 : ['charge', 'leap', 'rifts', 'inhale'].includes(id) ? r.warn + r.active + r.recover + 6 : r.warn + r.active + r.recover + 1.2, color: '#ab9cff',
    params: id === 'inhale' ? [{ k: 'stars', label: '実験場：吸い込んだ星の数', type: 'range', min: 0, max: 12, step: 1, def: 12 }] : [],
    status: { '状態': '独立HTMLの試作（未承認）。本番への組み込みはC++移行後', '全身': '現行画像と節長を保ち、胸と首を縮めて溜め、発動で解放する。腕と爪は一緒に振り、頭と首の向きをつなぐ', '動作': '技の時刻・射数・範囲・速度は現行値。退場と再登場を含めて再生。単独の比較場面で共通AIの自然選択は省略', '未決・保留': id === 'spiral' ? 'D01の新しい挙動案は入れず、現行の2周・収縮・退出を再現。カメラも現行の0.82倍まで引く' : id === 'inhale' ? '本番のactiveは6秒。吸引3秒→予告1秒のあと、残りの攻撃時間内だけ照射する現行の時間関係を維持。D02の移動仕様変更は保留' : id === 'clones' ? '現行の3体と各技を独立再生。D05のGodot実験場エラーは、このHTMLの再生成功で解決扱いにしない' : 'D01・D02の本番の移動仕様、D05の実験場不具合は未変更。ピカロの通常AIと地形への干渉は比較対象外' },
    refs: ['scripts/bosses/draco_parts.gd・draco_form.gd（全身のパーツと経路追従）', 'scripts/bosses/draco_attack_motion.gd・draco_screen_staging.gd（首・尾・退場）', 'data/bosses/draco_moves/' + id + '.tres・scripts/bosses/draco/techniques/' + id + '.gd', 'scripts/bosses/draco/technique_visual.gd（現行の予告・着弾）', 'pixelFX原本 fire/fire-breath の青いスプライト、冷える斬撃・光粒の手法、SPEEDの現行画像'],
    setup(S) { dSetup(S, id); }, step: dStep, draw: dDraw, phase(S) { return S.staging && S.staging.phase !== 'ready' ? '全身の退場・再登場' : S.spiral && S.B.mode === 'windup' ? '全身の退場・巻く位置へ入る' : bossPhase(S.B); }
  });
}
