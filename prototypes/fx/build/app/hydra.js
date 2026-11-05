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
  if (length - distance < 0.001) {
    // 横薙ぎの首は、弓なりから一直線へ急に切り替えず、頭に遅れて伸びる
    const follow = !initial && n === S.actor && S.tech === 'bite_sweep' ? 1 - Math.exp(-HP.neck_response * dt) : 1;
    for (let i = 0; i <= count; i++) points[i] = lerpV(add(points[i], shift), lerpV(root, tip, i / count), i === 0 || i === count ? 1 : follow);
    return;
  }
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
// 型：lunge＝首を縮めて伸ばす、sweep＝弧を振る、spit＝吐いて飛ばす、breath＝吐き続ける・撃ち続ける
const H_TECH = {
  bite_thrust: { kind: 'bite', type: 'lunge', title: '突き噛み', color: '#ff5470', ship: V(250, 70), active: r => r.normal_lunge, aimBase: true, retract: true },
  bite_sweep: { kind: 'bite', type: 'sweep', title: '横薙ぎ', color: '#ff5470', ship: V(110, 130), active: r => r.sweep_time, aimBase: true, aimOff: r => -r.sweep_arc * 0.5 },
  wind_band: { kind: 'vortex', type: 'breath', title: '風の帯', color: '#5fd27a', ship: V(300, 50), active: r => r.wind_time },
  wind_blades: { kind: 'vortex', type: 'sweep', title: '三日月の風刃', color: '#5fd27a', ship: V(640, 80), active: r => 2 * r.blade_interval, aimOff: r => -r.blade_spread * 0.5 },
  rubble_lump: { kind: 'debris', type: 'spit', title: '塊投げ', color: '#a9bccd', ship: V(620, 40), active: () => 0 },
  rubble_fan: { kind: 'debris', type: 'spit', title: '散らし吐き', color: '#a9bccd', ship: V(460, 40), active: () => 0 },
  beam_fixed: { kind: 'beam', type: 'breath', title: '固定照射', color: '#ff6fb4', ship: V(640, 70), active: r => r.beam_time },
  beam_bolt: { kind: 'beam', type: 'spit', title: '光弾', color: '#ff6fb4', ship: V(640, 70), active: () => 0 },
  thunder_headbutt: { kind: 'thunder', type: 'lunge', title: '帯電頭突き', color: '#7fb8ff', ship: V(260, 60), active: r => r.normal_lunge, aimBase: true, retract: true },
  thunder_drop: { kind: 'thunder', type: 'breath', title: '先回り落雷', color: '#7fb8ff', ship: V(520, 120), shipVel: V(0, -170), active: r => r.thunder_flash },
};
function hTech(S) { return H_TECH[S.tech]; }
function hTiming(S) { const r = S.r, d = hTech(S); return { warn: r.normal_charge, active: d.active(r), hold: r.normal_hold }; }
function hIdle(S, n, dt) {
  // body.cpp：待機中の首は、取り付け方向から±0.8の範囲で機体を向き、長さを休みの長さへ戻す。
  const facing = n.baseAngle + S.B.facing, base = hBase(S, n), o = sub(S.ship.pos, base), fw = fromA(facing);
  const local = Math.atan2(o.x * orth(fw).x + o.y * orth(fw).y, Math.max(HP.aim_deadzone, o.x * fw.x + o.y * fw.y));
  hAim(n, facing + clamp(local, -0.8, 0.8) + Math.sin(S.t + n.baseAngle) * 0.06, dt);
  n.length = moveToward(n.length, HP.neck_rest, HP.neck_rest * dt); n.pos = add(base, mul(fromA(n.angle), n.length));
}
function hShipAim(S) { const d = hTech(S); return S.tech === 'thunder_drop' ? add(S.ship.pos, mul(S.ship.vel, S.r.thunder_lead)) : { ...S.ship.pos }; }
function hAttack(S, n, dt) {
  const r = S.r, d = hTech(S), T = hTiming(S), time = S.age, base = hBase(S, n);
  if (time < 0) { hIdle(S, n, dt); return; }
  if (time < T.warn) {
    // 落雷は狙いの固定（warn×0.75）まで機体の先を追い、首は振らない（thunder_drop.cpp）
    if (S.tech !== 'thunder_drop' || time < T.warn * 0.75) n.target = hShipAim(S);
    if (S.tech !== 'thunder_drop') hAim(n, angOf(sub(n.target, d.aimBase ? base : n.pos)) + (d.aimOff ? d.aimOff(r) : 0), dt);
    if (d.retract) n.length += clamp(HP.neck_rest * 0.4 - n.length, -HP.neck_rest * dt * 2, HP.neck_rest * dt * 2);
    // 横薙ぎは発動の位置まで予兆のうちに首を伸ばして振りかぶる（発動で頭が飛ばないように）
    if (S.tech === 'bite_sweep') { n.windFrom ??= n.length; n.length = n.windFrom + (r.sweep_reach - n.windFrom) * smooth(0.1, 0.85, time / T.warn); }
    n.pos = add(base, mul(fromA(n.angle), n.length)); n.glow = time / T.warn; return;
  }
  const e = time - T.warn;
  if (!n.locked) { n.locked = true; n.from = { ...n.pos }; n.fireAngle = n.angle; n.sweep = S.tech === 'bite_sweep' ? angOf(sub(n.target, base)) : S.tech === 'wind_blades' ? angOf(sub(n.target, n.pos)) : n.angle; hFire(S, n); }
  if (time >= T.warn + T.active + T.hold) {
    if (!n.done) { n.done = true; n.angle = angOf(sub(n.pos, base)); n.length = dist(n.pos, base); }
    hIdle(S, n, dt); return;
  }
  n.glow = 0;
  if (S.tech === 'bite_sweep') { if (e < T.active) { const f = clamp(e / T.active); n.angle = n.sweep + r.sweep_arc * (f - 0.5); n.pos = add(base, mul(fromA(n.angle), r.sweep_reach)); } }
  else if (d.type === 'lunge') { if (e < T.active) { n.pos = lerpV(n.from, n.target, clamp(e / T.active)); n.angle = angOf(sub(n.target, n.from)); } else { n.pos = { ...n.target }; if (S.tech === 'thunder_headbutt' && !n.struck) { n.struck = S.t; } } }
  else if (S.tech === 'wind_blades') { while ((n.step || 0) < 3 && e >= (n.step || 0) * r.blade_interval) { const a = n.sweep + ((n.step || 0) * 0.5 - 0.5) * r.blade_spread; n.angle = a; S.shots.push({ kind: 'blade', from: { ...n.pos }, angle: a, t: S.t }); n.step = (n.step || 0) + 1; } }
}
// 発動の瞬間に放つもの（弾と岩は放ったあと独立して進む）
function hFire(S, n) {
  const r = S.r, at = { ...n.pos };
  if (S.tech === 'rubble_lump') S.shots.push({ kind: 'rock', from: at, angle: n.angle, speed: r.lump_speed, radius: r.lump_r, t: S.t, seed: 3 });
  if (S.tech === 'rubble_fan') for (let i = 0; i < r.rubble_count; i++) S.shots.push({ kind: 'rock', from: at, angle: n.angle + r.rubble_spread * (i / (r.rubble_count - 1) - 0.5), speed: r.lump_speed, radius: r.rubble_small_radius, t: S.t, seed: 11 + i });
  if (S.tech === 'beam_bolt') S.shots.push({ kind: 'bolt', from: at, angle: n.angle, t: S.t });
}
function hSetup(S, id) {
  const d = H_TECH[id]; S.tech = id; S.r = hRule(id); S.B = bossActor('hydra', V(-300, 0)); S.age = -0.6; S.necks = []; S.shots = [];
  S.ship = shipState({ ...d.ship }, Math.PI, 0); S.ship.vel = d.shipVel ? { ...d.shipVel } : V(0, 0); if (d.shipVel) { S.ship.heading = angOf(d.shipVel); S.ship.speed = len(d.shipVel); }
  for (let i = 0; i < 5; i++) { const baseAngle = TAU * i / 5, n = { kind: H_KINDS[i], baseAngle, angle: baseAngle, length: HP.neck_rest, aimV: 0, glow: 0, hist: [] }; S.necks.push(n); }
  S.actor = S.necks.find(n => n.kind === d.kind); S.B.facing = -S.actor.baseAngle; // 本体を回して、技を使う首を機体側へ向ける（body.cpp front_body の考え）
  for (const n of S.necks) { n.angle = n.baseAngle + S.B.facing; n.pos = add(hBase(S, n), mul(fromA(n.angle), HP.neck_rest)); hChain(S, n, 0); }
}
function hStep(S, dt) {
  S.age += dt; S.ship.pos = add(S.ship.pos, mul(S.ship.vel, dt));
  for (const n of S.necks) { if (n === S.actor) hAttack(S, n, dt); else hIdle(S, n, dt); hChain(S, n, dt); n.hist.push({ t: S.t, pos: { ...n.pos }, angle: n.angle }); if (n.hist.length > 48) n.hist.shift(); }
}
function hPhase(S) {
  const T = hTiming(S), t = S.age;
  return t < 0 ? '待機' : t < T.warn ? '予兆（構え）' : t < T.warn + Math.max(T.active, 0.05) ? '攻撃中' : t < T.warn + T.active + T.hold ? '停止（反撃の隙）' : '戻り';
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
// 予兆でためて止まり（静）、発動で一気に動く（動）。型ごとにため方と発動後の動きを変える。
// 横薙ぎの見た目の頭（判定の円はそのまま）：ゆっくり→一気に→行き過ぎて戻る緩急、真ん中で外へ突き出す踏み込み、振る先を向く頭
function hSweepVis(S, n, rel, R) {
  const r = S.r, T = hTiming(S), base = hBase(S, n), live = R?.P?.alive ?? 1, f = clamp(rel / T.active), after = Math.max(0, rel - T.active);
  const fe = f < 0.5 ? 4 * f * f * f : 1 - Math.pow(-2 * f + 2, 3) / 2, on = smooth(0, 0.06, rel) * (1 - smooth(T.active + 0.2, T.active + 0.45, rel));
  const over = after > 0 ? Math.sin(Math.min(1, after / 0.1) * Math.PI) * Math.exp(-after / 0.16) : 0, swing = Math.sin(Math.PI * fe);
  const real = n.sweep + r.sweep_arc * (f - 0.5), a = real + ((n.sweep + r.sweep_arc * (fe - 0.5) + r.sweep_arc * 0.13 * over) - real) * on * live
    + angDiff(n.fireAngle, n.sweep - r.sweep_arc * 0.5) * (1 - smooth(0, 0.14, rel)); // 予兆で向き切れなかった分を振り出しでなじませる
  const reach = r.sweep_reach + (70 * swing - 18 * (1 - swing)) * on * live;
  return { pos: add(base, mul(fromA(a), reach)), face: a + (0.5 * swing + 0.25 * over) * on * live };
}
function hPose(S, n, R) {
  const T = hTiming(S), t = S.age, type = hTech(S).type;
  const out = { coil: 0, freeze: 0, rel: -1, head: n.pos, angle: n.angle, sx: 1, sy: 1, T, type };
  if (n !== S.actor || t < 0) return out;
  const u = clamp(t / T.warn);
  if (t < T.warn) { out.coil = smooth(0, 0.62, u); out.freeze = smooth(0.62, 0.8, u); }
  else { out.rel = t - T.warn; out.coil = Math.exp(-out.rel / 0.035); }
  const fw = fromA(n.angle), rel = out.rel;
  if (rel < 0) {
    const back = type === 'lunge' ? 16 : type === 'spit' ? 22 : type === 'breath' ? 12 : 6;
    out.head = add(n.pos, mul(fw, -back * out.coil * R.P.coil)); out.sx = 1 + 0.05 * out.coil; out.sy = 1 - 0.08 * out.coil;
    if (type === 'breath' && S.tech !== 'thunder_drop') out.sx = 1 + 0.1 * out.coil; // 吸い込んで頭がふくらむ
  } else {
    const k = clamp(rel / Math.max(0.001, T.active));
    if (type === 'lunge' && rel < T.active) { out.sy = 1 + 0.16 * Math.sin(Math.PI * k); out.sx = 1 - 0.07 * Math.sin(Math.PI * k); }
    if (type === 'lunge') { const after = rel - T.active; if (after >= 0) { const j = Math.exp(-after / 0.07) * Math.sin(Math.min(1, after / 0.05) * Math.PI); out.head = add(n.pos, mul(fw, 9 * j * R.P.snap)); out.sy = 1 + 0.06 * j; } }
    if (type === 'spit') { const j = Math.exp(-rel / 0.09) * Math.sin(Math.min(1, rel / 0.04) * Math.PI * 0.5 + Math.PI * 0.5 * Math.min(1, rel / 0.04)); out.head = add(n.pos, mul(fw, 20 * Math.exp(-rel / 0.1) * Math.min(1, rel / 0.03) * R.P.snap)); out.sy = 1 + 0.1 * Math.exp(-rel / 0.08); }
    if (type === 'breath' && S.tech !== 'thunder_drop') { const on = rel < T.active ? 1 : Math.exp(-(rel - T.active) / 0.1); out.head = add(add(n.pos, mul(fw, -9 * on * R.P.snap)), mul(orth(fw), Math.sin(S.t * 70) * 1.8 * on)); out.sx = 1 + 0.04 * on; }
    if (S.tech === 'thunder_drop') { const j = Math.exp(-rel / 0.12); out.head = add(n.pos, mul(fw, -10 * j)); }
    if (S.tech === 'wind_blades') { // 投げるたびに首を振り抜いて少し戻る
      const step = Math.min(2, Math.floor(rel / S.r.blade_interval)), since = rel - step * S.r.blade_interval, sign = 1;
      out.angle = n.angle + sign * 0.16 * Math.exp(-since / 0.06) * Math.sin(Math.min(1, since / 0.03) * Math.PI * 0.5) * (rel < T.active + S.r.blade_interval ? 1 : 0);
    }
  }
  if (S.tech === 'bite_sweep' && rel >= 0 && rel < T.active + 0.5) { const v = hSweepVis(S, n, rel, R); out.head = add(v.pos, mul(fromA(v.face), -6 * out.coil * R.P.coil)); out.angle = v.face; }
  if (out.freeze > 0 && rel < 0) out.head = add(out.head, mul(orth(fw), Math.sin(S.t * 95) * 1.6 * out.freeze));
  return out;
}
function hVisualNeck(S, n, pose, R) {
  const pts = n.points; if (n !== S.actor || S.age < 0) return pts;
  const dHead = sub(pose.head, n.pos), N = pts.length - 1, root = pts[0], tip = pts[N], dir = norm(sub(tip, root)), side = orth(dir), type = pose.type, A = (type === 'sweep' ? 30 : type === 'lunge' ? 36 : 18) * R.P.coil;
  return pts.map((p, i) => {
    const u = i / N; let o = 0;
    // ため：伸ばす技はS字、振る技は振りかぶる側へ弓なり、吐く技は少し引いた弓なり
    if (pose.coil > 0) o += (type === 'lunge' ? Math.sin(u * TAU) * Math.sin(u * Math.PI) * 0.5 : -Math.sin(u * Math.PI)) * A * pose.coil;
    if (pose.freeze > 0 && pose.rel < 0) o += Math.sin(S.t * 95 + i * 1.7) * 1.3 * pose.freeze * Math.sin(u * Math.PI);
    if (pose.rel >= 0) {
      if (S.tech === 'bite_sweep' && pose.rel < pose.T.active + 0.25) { // 頭に遅れて首がしなる
        const w = pose.rel < pose.T.active ? 1 : Math.exp(-(pose.rel - pose.T.active) / 0.08); o += -Math.sin(u * Math.PI) * (1 - u * 0.3) * 26 * w * (1 - pose.coil) * R.P.coil;
      }
      // 発動の衝撃の波：頭から根元へ抜けて消える
      const after = pose.rel - (type === 'lunge' ? pose.T.active : 0), s = 1 - u, amp = type === 'lunge' ? 13 : type === 'spit' ? 10 : type === 'sweep' ? 6 : 4;
      if (after > 0) { const front = after * 9; if (s < front) o += Math.sin((front - s) * 9) * amp * Math.exp(-after / 0.22) * (1 - s * 0.5) * R.P.snap; }
    }
    return i === N ? pose.head : add(add(p, mul(side, o)), mul(dHead, u * u));
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
  const T = pose.T, r = S.r, base = hBase(S, n), pal = FX.ramp(R.P.color);
  const maxAge = 0.34 * R.P.timing, half = r.bite_radius * 0.55 * WL * R.P.size, dt = 1 / 300, endT = T.active;
  // 筋の束：頭の通った道に沿って、真ん中の筋ほど長く残り、外の筋ほど短い → 先が太く後ろが細る三日月。光が主で、面で塗りつぶさない
  const at = (q) => toL(hSweepVis(S, n, q, R).pos);
  for (let o = -half; o <= half; o += 0.75) {
    const e = Math.abs(o) / half, lane = Math.round(o / 0.75), life = maxAge * (1 - e ** 1.6) * (0.5 + 0.5 * hash(lane * 3.7 + 1)); if (life <= 0.01) continue;
    for (let age = Math.max(0, pose.rel - endT); age <= life; age += dt) {
      const q = pose.rel - age; if (q < 0) break; const A = at(q), B = at(Math.max(0, q - dt)), tg = norm(sub(A, B)), nr = orth(tg), k = age / life, x = A.x + nr.x * o, y = A.y + nr.y * o;
      if (k > 0.55 && hash(lane * 11 + Math.floor(q * 300) * 5) > (1 - k) * 2.2) continue;
      const speed = dist(A, B) / dt / WL, lv = k < 0.12 && e < 0.35 ? 4 : k < 0.4 ? 3 : 2, al = (1 - k) * (1 - e * 0.7) * smooth(200, 900, speed); // 遅い所（振り始め・振り終わり）では帯を出さない
      if (al < 0.03) continue;
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
// ---------- 渦・瓦礫・ビーム・雷の試作エフェクト
function hMouthAt(n, pose) { return add(pose.head, mul(fromA(pose.angle), hMouthDist(n))); }
// 渦の予兆：前から空気の筋が口へ吸い込まれる（風の帯）／口のまわりを渦を巻いて縮む（風刃）
function hInhale(S, R, n, pose) {
  if (pose.rel >= 0 || S.age < 0) return; const pal = FX.ramp(R.P.color), u = clamp(S.age / pose.T.warn), M = hMouthAt(n, pose), a0 = pose.angle;
  if (S.tech === 'wind_band') for (let i = 0; i < 36; i++) {
    const h = hash(i * 3.3 + 1), ph = (S.age * (1.4 + h) + hash(i * 7.1)) % 1, an = a0 + (hash(i * 5.5) - 0.5) * 1.1, s0 = 70 + 260 * hash(i * 2.9), s = s0 * (1 - ph) ** 1.6, sl = 10 + 16 * (1 - ph);
    for (let d = 0; d <= sl; d += 0.6 / WL) { const q = toL(add(M, mul(fromA(an), s + d))), k = (1 - d / sl) * u * smooth(0, 0.25, ph); if (k > 0.05) R.front.dot(q.x, q.y, pal[k > 0.6 ? 3 : 2], k * 0.8); }
  }
  if (S.tech === 'wind_blades') for (let i = 0; i < 28; i++) {
    const h = hash(i * 4.7 + 2), ph = (S.age * (1.1 + h * 0.8) + h) % 1, rad = (26 + 46 * hash(i * 9.1)) * (1 - ph * 0.85), an = hash(i * 1.7) * TAU + S.age * (7 + 4 * h);
    for (let j = 0; j < 5; j++) { const q = toL(add(M, mul(fromA(an - j * 0.09), rad + j * 1.5))), k = u * (1 - j / 5) * Math.sin(Math.PI * ph); if (k > 0.05) R.front.dot(q.x, q.y, pal[j === 0 && k > 0.5 ? 3 : 2], k); }
  }
}
// 風の帯：pixelFX ice/frost-breath の作りを、上から見た帯の大きさへ写す（Hugo Duprez 由来 MIT）。
// 口元の明るい芯、むらのある半透明の風（本当の半透明で重ねる）、ふくらんで薄れる空気の玉、速い筋、舞う葉の切れ端、帯を走る明るい風の線。
const H_WIND = ['#0b1f1a', '#123d2c', '#1d6b45', '#2fa35e', '#5fd27a', '#a6f0a0', '#dcffd6', '#ffffff'].map(hexc);
function hCycle(e, active, count, life0, life1, seed, fn) { // pixelFX cycle の考え：寿命ごとに生まれ直す粒。攻撃中に生まれたものだけ描く
  for (let i = 0; i < count; i++) { const life = lerp(life0, life1, hash(i * 3.7 + seed)), off = hash(i * 9.1 + seed) * life, c = Math.floor((e + off) / life), age = e + off - c * life, born = e - age;
    if (born < 0 || born > active) continue; fn(age, life, (k) => hash(i * 13.1 + c * 7.3 + k * 1.91 + seed)); }
}
// 風の帯（竜巻）：横倒しの竜巻を上から見た形。口から先へ広がる円錐の中を、ねじれた風の筋がらせんに回り、
// 手前を回る所は明るく太く、奥は暗く細い。輪のような風の弧が回りながら先へ流れ、軸に光の芯、葉がらせんに乗って運ばれる。
function hWindBand(S, R, n, pose) {
  if (S.tech !== 'wind_band' || pose.rel < 0) return; const r = S.r, T = pose.T, e = pose.rel, p = R.front, C = H_WIND;
  const M = hMouthAt(n, pose), dir = fromA(n.sweep), sd = orth(dir), L = R.P.windLen ?? r.wind_length, R0 = (R.P.windR0 ?? 32) * R.P.size, R1 = (R.P.windR1 ?? 115) * R.P.size;
  const end = e > T.active ? clamp(1 - (e - T.active) / (0.45 * R.P.timing)) : 1; if (end <= 0) return;
  const front = Math.min(L * 1.12, e * 2200), tail = e > T.active ? (e - T.active) * 700 : 0, step = 0.5 / WL;
  const rad = (s) => lerp(R0, R1, Math.pow(clamp(s / L), 0.85)), W = (s, y) => toL(add(add(M, mul(dir, s)), mul(sd, y)));
  const far = (s) => 1 - smooth(L * 0.68, L * 1.1, s), fadeS = (s) => clamp((s - tail) / 30) * clamp((front - s) / 30) * far(s) * end; // 先の3割で細く薄くなって消える
  // 軸の光の芯と口元
  const A = W(Math.max(6, tail), 0), B = W(Math.max(tail + 1, L * 0.95), 0); p.glowLine(A.x, A.y, B.x, B.y, 7 * R.P.size, C[4], 0.22 * end * R.P.intensity); p.glow(A.x, A.y, 6 * R.P.size, C[6], 0.45 * end * R.P.intensity);
  // ねじれた風の筋（らせん）
  for (let k = 0; k < 4; k++) { const ph = k * TAU / 4 + hash(k * 3.3) * 0.6;
    for (let s = tail; s <= front; s += step) { const th = s * (0.05 - 0.00004 * s) - e * (13 + 4 * hash(k)) + ph + Math.sin(s * 0.02 + k * 2.1 - e * 3) * 0.5, depth = 0.5 + 0.5 * Math.sin(th);
      const f = fadeS(s) * (0.25 + 0.75 * clamp(s / 40)) * clamp(0.55 + 0.9 * PX.tileFbm(s * 0.03 - e * 6, k * 3.1, 0, 0, 31, 2)); if (f <= 0.04) continue; // 筋ごとに濃さのむら
      const fr = far(s); if (fr < 0.95 && hash(k * 31 + Math.floor(s * WL * 2) * 7 + Math.floor(e * 24)) > fr * 1.25) continue; // 先は虫食いで散る
      const q = W(s, rad(s) * (1 + 0.14 * Math.sin(s * 0.03 + k * 2 - e * 5) + (1 - fr) * 0.25 * Math.sin(s * 0.11 + k)) * Math.cos(th)), w = (0.3 + 1.4 * depth) * (0.6 + 0.4 * Math.min(1, s / L)) * (0.35 + 0.65 * fr) * R.P.size, b = f * (0.3 + 0.7 * depth), nr = orth(dir);
      for (let o = -w; o <= w; o += 0.5) { const x = q.x + nr.x * o, y = q.y + nr.y * o, ee = Math.abs(o) / Math.max(0.5, w);
        if (depth > 0.55 && b > 0.5) p.px(x, y, C[ee < 0.4 && depth > 0.8 ? 7 : 6]); else p.blend(x, y, depth > 0.5 ? C[5] : C[3], Math.min(0.85, b * (1 - ee * 0.5))); }
      if (depth > 0.5) p.light(q.x, q.y, C[5], 0.18 * b * R.P.intensity); } }
  // 輪のような風の弧：回りながら先へ流れる（全周は描かず、先が細る弧）
  hCycle(e, T.active, 10, 0.32, 0.42, 21, (age, life, rnd) => { const k = age / life, s0 = lerp(10, 40, rnd(1)) + age * lerp(650, 850, rnd(2)) * L / 340; if (s0 > L * 1.1) return;
    const rr = rad(s0) * lerp(0.85, 1.05, rnd(3)), rx = rr * 0.26, phi0 = rnd(4) * TAU - e * 14, span = lerp(3.4, 4.4, rnd(5)), fa = Math.sin(Math.PI * k) * fadeS(s0);
    for (let m = 0; m <= 40; m++) { const u = m / 40, phi = phi0 + span * u, depth = 0.5 + 0.5 * Math.sin(phi), q = W(s0 + rx * Math.sin(phi), rr * Math.cos(phi)), b = fa * Math.sin(Math.PI * u) * (0.35 + 0.65 * depth), w = (0.3 + 1.1 * Math.sin(Math.PI * u) * depth) * R.P.size;
      if (b < 0.12) continue; for (let o = -w; o <= w; o += 0.5) { const x = q.x + dir.x * o, y = q.y + dir.y * o; if (b > 0.5 && depth > 0.5) p.px(x, y, C[Math.abs(o) < w * 0.5 ? 7 : 6]); else p.blend(x, y, C[depth > 0.5 ? 5 : 4], Math.min(0.8, b)); }
      if (depth > 0.6) p.light(q.x, q.y, C[5], 0.2 * b * R.P.intensity); } });
  // らせんに乗って運ばれる葉
  hCycle(e, T.active, 14, 0.5, 0.7, 23, (age, life, rnd) => { const s0 = age * lerp(380, 520, rnd(1)); if (s0 > L) return; const th = rnd(2) * TAU + s0 * 0.042 - e * 15, depth = 0.5 + 0.5 * Math.sin(th), q = W(s0, rad(s0) * 0.85 * Math.cos(th)), spin = age * 18 + rnd(3) * 6, f = fadeS(s0);
    if (f < 0.2) return; p.px(q.x, q.y, depth > 0.5 ? C[5] : C[3]); p.px(q.x + Math.round(Math.cos(spin)), q.y + Math.round(Math.sin(spin)), depth > 0.5 ? C[6] : C[4]); });
}
// 三日月の風刃：pixelFX melee の斬撃の作り（Sprite Fusion の slash 由来 MIT）。ふちが一瞬で弧を走って開き、頭の側が太く、尾の側へ長く細く伸びる。
// 本体は白く、後ろ側（内側）は尾のほうへ流れる毛羽立ちになって緑へ溶ける。進行方向には何も出さない。寿命の終わりは尾が頭へ追いついて閉じる。
function hBlades(S, R) {
  const r = S.r, p = R.front, C = H_WIND, STOPS = [[0, PX.WHITE], [0.5, PX.WHITE], [0.72, C[6]], [0.9, C[5]], [1, C[4]]];
  const ramp = (q) => { let i = 0; while (i < STOPS.length - 2 && q > STOPS[i + 1][0]) i++; const [q0, c0] = STOPS[i], [q1, c1] = STOPS[i + 1]; return PX.mix(c0, c1, clamp((q - q0) / (q1 - q0))); };
  for (const b of S.shots) {
    if (b.kind !== 'blade') continue; const age = S.t - b.t, life = r.blade_life; if (age > life) continue;
    const dir = fromA(b.angle), c = add(b.from, mul(dir, r.blade_speed * age)), size = r.blade_size * R.P.size, d = Math.round((b.t - S.shots[0].t) / r.blade_interval) % 2 ? -1 : 1, seed = Math.floor(b.t * 97) % 89;
    // 判定の半楕円の先端と両端を通る円の弧の上に描く
    const Rw = size * 1.133, O = toL(sub(c, mul(dir, Rw - size * 0.6))), Rl = Rw * WL, span = 2.55, a0 = b.angle - d * span / 2;
    const U = span * (1 - Math.pow(2, -10 * age / 0.12)), T = span * smooth(life - 0.5, life, age), W = (R.P.bladeW ?? 46) * WL * R.P.size, FUR = R.P.bladeFur ?? 1, reach = W * (1 + 2.2 * FUR) + 3, shine = (age * 2.2) % 1.5 - 0.25;
    if (U - T < 0.02) continue;
    const profile = (v) => Math.pow(Math.sin(Math.PI * Math.pow(v, 1.7)), 0.8);
    const COUNT = 20, fur = (u, e) => { // 毛羽立ち：尾のほうへ傾いた細い三角が並び、ゆっくり尾へ流れる
      const x = (u + e / Rl * 0.9 + age * 0.5) / span * COUNT, i = Math.floor(x), t = x - i, h = hash(i * 3.7 + seed); return (0.45 + 0.75 * h) * Math.pow(1 - Math.abs(2 * t - 1), 1.3); };
    p.each(O.x - Rl - 3, O.y - Rl - 3, O.x + Rl + 3, O.y + Rl + 3, (x, y, sx, sy) => {
      const dx = x - O.x, dy = y - O.y, rr = Math.hypot(dx, dy), e = Rl - rr; if (e < -1.5 || e > reach) return;
      let u = angDiff(Math.atan2(dy, dx), a0) * d; if (u < -0.5) u += TAU; if (u < T || u > U) return;
      const v = (u - T) / (U - T), w = W * profile(v); if (w < 0.25) return;
      const q = e / w, tailFade = smooth(0, 0.14, v), glint = Math.exp(-Math.pow((v - shine) / 0.16, 2));
      if (e <= 0) { p.blendPx(sx, sy, C[5], tailFade * (1 + e / 1.5) * 0.55); return; } // 外側はやわらかい緑のふちで閉じる
      if (q <= 0.55) { p.blendPx(sx, sy, ramp(clamp(q / 0.55 - 0.3 * glint)), tailFade); return; }
      const len = W * profile(v) * FUR * fur(u, e) * 1.5, over = (e - w * 0.55) / Math.max(0.5, len); if (over > 1) return; const f = clamp(over);
      p.blendPx(sx, sy, PX.mix(C[6], C[4], f), tailFade * Math.pow(1 - f, 0.8) * 0.9);
    });
    for (let m = 0; m < 12; m++) { const v0 = m / 12, v1 = (m + 1) / 12, at = (v) => { const a = a0 + d * lerp(T, U, v), rad = Rl - W * 0.3; return { x: O.x + Math.cos(a) * rad, y: O.y + Math.sin(a) * rad }; }, A = at(v0), B = at(v1); p.glowLine(A.x, A.y, B.x, B.y, 8 * R.P.size + 3, C[4], 0.24 * profile(v0) * R.P.intensity); }
  }
}
// 瓦礫：予兆は首の瓦礫が口へ送られて噛み砕かれ、吐くと土煙と砂利の扇。岩は回りながら飛び、砂ぼこりの尾を引く
function hRubbleWarn(S, R, n, pose, pts) {
  if (hTech(S).kind !== 'debris' || pose.rel >= 0 || S.age < 0) return; const u = clamp(S.age / pose.T.warn), N = pts.length - 1, M = hMouthAt(n, pose);
  for (let j = 0; j < 9; j++) { const ph = (S.age * 1.6 + hash(j * 3.1)) % 1, f = ph * N, i = Math.min(N - 1, Math.floor(f)), at = lerpV(pts[i], pts[i + 1], f - i), q = toL(add(at, mul(orth(norm(sub(pts[i + 1], pts[i]))), (hash(j) - 0.5) * 18))); R.front.px(q.x, q.y, H_STONE[4]); R.front.px(q.x + 1, q.y, H_STONE[3]); }
  const m = toL(M), lump = S.tech === 'rubble_lump', rr = (lump ? 1 + 3 * u : 2.5) * R.P.size;
  for (let k = 0; k < (lump ? 24 : 16); k++) { const an = hash(k * 2.3) * TAU + S.age * (lump ? 2 : 9) * (hash(k) - 0.5), d = rr * Math.sqrt(hash(k * 5.9)), jit = Math.sin(S.age * 60 + k) * 0.6 * u; R.front.px(m.x + Math.cos(an) * d + jit, m.y + Math.sin(an) * d, H_STONE[d > rr * 0.6 ? 2 : 3]); }
}
// 塊投げの尾：pixelFX fire/meteor の彗星の作りを土煙で。岩の後ろから土煙の舌が何本も流れ、うねりが尾へ速く走り、先へ細く薄くなる。
// 尾の先に置き去りの土ぼこりの切れ端が進行方向に伸びて残り、脇を速度線が抜ける。
const H_DUST = ['#9a8f86', '#7a7068', '#c9bfb2'].map(hexc);
function hLumpDust(S, R, b, age, dir) {
  const p = R.back, pos = add(b.from, mul(dir, b.speed * age)), head = toL(pos), rad = b.radius * WL * 1.1 * R.P.size, on = smooth(0, 0.06, age), full = b.speed * 0.42 * WL * R.P.dust, L = Math.min(b.speed * age * WL, full), ux = dir.x, uy = dir.y, TONGUES = 6;
  if (L > 2) { const tongue = (i) => ({ off: (i / (TONGUES - 1) - 0.5) * 1.5, len: lerp(0.55, 1, hash(i * 3.1 + 2)), ph: hash(i * 5.7) * TAU, wid: lerp(0.32, 0.55, hash(i * 2.3 + 7)) }), T = Array.from({ length: TONGUES }, (_, i) => tongue(i));
    p.each(Math.min(head.x, head.x - ux * L) - rad * 1.6, Math.min(head.y, head.y - uy * L) - rad * 1.6, Math.max(head.x, head.x - ux * L) + rad * 1.6, Math.max(head.y, head.y - uy * L) + rad * 1.6, (x, y, sx, sy) => {
      const dx = x - head.x, dy = y - head.y, along = -(dx * ux + dy * uy), lat = dx * -uy + dy * ux, k0 = along / L; if (k0 < -0.04 || k0 > 1) return; let a = 0, k1 = 0;
      for (const t of T) { const k = k0 / t.len; if (k > 1) continue; const c = rad * (t.off * (1 - k * 0.75) + Math.sin(k * 7 - age * 34 + t.ph) * 0.42 * clamp(k * 2.2)), w = rad * t.wid * Math.pow(1 - k, 0.75) * (0.6 + 0.4 * clamp(k * 4)), e = 1 - Math.abs(lat - c) / Math.max(0.4, w); if (e <= 0) continue; const v = smooth(0, 0.5, e) * Math.pow(1 - k, 1.3) * 0.85; if (v > a) { a = v; k1 = k; } }
      if (a > 0.02) p.blendPx(sx, sy, PX.mix(H_DUST[2], H_DUST[1], clamp(k1 * 1.5)), a * on); }); }
  // 置き去りの土ぼこりの切れ端：進行方向に伸びたまま薄れる
  for (let i = Math.max(0, Math.floor((age - 0.45) * 26)); i / 26 <= age; i++) { const born = i / 26, rnd = (k) => hash(i * 7.31 + k * 3.17 + b.seed), life = lerp(0.2, 0.45, rnd(1)), a = age - born, k = 1 - a / life; if (k <= 0) continue;
    const q = toL(add(add(b.from, mul(dir, b.speed * born - b.radius)), mul(orth(dir), (rnd(3) - 0.5) * b.radius * 2.4))), len = lerp(5, 14, rnd(2)) * R.P.size; for (let t = 0; t < len; t += 0.5) { const n = t / len; p.blend(q.x - ux * t, q.y - uy * t, H_DUST[rnd(6) < 0.5 ? 0 : 1], k * k * (1 - n) * 0.6); } }
  // 脇を後ろへ抜ける速度線
  for (let i = 0; i < 4; i++) { const life = 0.14, off = hash(i * 3.3 + b.seed) * life, c = Math.floor((age + off) / life), a = (age + off - c * life) / life, rnd = (k) => hash(i * 9.1 + c * 4.7 + k * 2.3), lat = (rnd(1) < 0.5 ? -1 : 1) * rad * lerp(1.1, 1.8, rnd(2)), start = rad * lerp(-0.6, 0.6, rnd(3)) + L * 0.8 * a, len = rad * lerp(3, 6, rnd(4)), fade = Math.sin(Math.PI * a) * on;
    for (let d = 0; d < len; d += 0.5) { const t = d / len; p.blend(head.x - ux * (start + d) - uy * lat, head.y - uy * (start + d) + ux * lat, H_DUST[2], fade * Math.sin(Math.PI * t) * (1 - t * 0.6) * 0.5); } }
}
function hRocks(S, R, back) {
  for (const b of S.shots) {
    if (b.kind !== 'rock') continue; const age = S.t - b.t; if (age > 6) continue; const dir = fromA(b.angle), pos = add(b.from, mul(dir, b.speed * age));
    if (back && R.proto && S.tech === 'rubble_lump') { hLumpDust(S, R, b, age, dir); continue; }
    if (back && R.proto) { for (let k = 1; k < 16; k++) { const tk = age - k * 0.03; if (tk < 0) break; const a = k * 0.03 / R.P.timing, p = add(b.from, mul(dir, b.speed * tk)), q = toL(p), rr = (1 + a * 7) * (b.radius / 26) * R.P.size * R.P.dust;
        for (let y = -rr; y <= rr; y++) for (let x = -rr; x <= rr; x++) { if (x * x + y * y > rr * rr || hash(b.seed * 31 + k * 7 + x * 3 + y * 11) < a * 1.9) continue; R.back.dot(q.x + x, q.y + y, H_STONE[a < 0.15 ? 3 : 2], (1 - a / 0.5) * 0.5); } } continue; }
    if (back) continue;
    const spin = age * (3 + 3 * hash(b.seed)) * (S.tech === 'rubble_lump' ? 2 : 1) * (hash(b.seed * 3) > 0.5 ? 1 : -1);
    if (S.tech === 'rubble_lump' && R.proto) for (let k = 4; k >= 1; k--) drawImg('meteor_0', sub(pos, mul(dir, b.speed * 0.016 * k)), spin - k * 0.08, b.radius * 1.25, 0.26 - k * 0.05); // 速さでぶれる残像
    drawImg('meteor_0', pos, spin, b.radius * 1.25);
  }
}
function hSpitBurst(S, R, n, pose) { // 吐いた瞬間：口から土煙と砂利の扇
  if (hTech(S).kind !== 'debris' || pose.rel < 0) return; const t = pose.rel, M = n.from ? add(n.from, mul(fromA(n.angle), hMouthDist(n))) : hMouthAt(n, pose), fan = S.tech === 'rubble_fan', spread = fan ? S.r.rubble_spread * 0.6 : 0.35;
  hDust(S, R, M, t, 91, n.angle, fan ? 1.3 : 0.9);
  for (let i = 0; i < (fan ? 26 : 14); i++) { const life = 0.3 + 0.3 * hash(i * 3.7); if (t > life) continue; const an = n.angle + (hash(i * 5.3) - 0.5) * 2 * spread, sp = (300 + 400 * hash(i * 1.9)) * R.P.dust, d = sp * 0.12 * (1 - Math.exp(-t / 0.12)), q = toL(add(M, mul(fromA(an), d))), k = t / life; if (hash(i * 11 + Math.floor(t * 30)) > (1 - k) * 1.8) continue; R.front.px(q.x, q.y, H_STONE[k < 0.4 ? 4 : 3]); }
}
// ビーム：予兆は口から射線いっぱいへ流れる照準の光（白くしない）と、口へ集まる光。照射は先が伸び、終わりは根元から消える
function hBeam(S, R, n, pose) {
  const pal = FX.ramp(R.P.color), r = S.r, T = pose.T, M = hMouthAt(n, pose), A = toL(M);
  if (S.tech === 'beam_fixed') {
    const dir = fromA(pose.rel < 0 ? n.angle : n.sweep), B = toL(add(M, mul(dir, r.beam_len)));
    if (pose.rel < 0 && S.age >= 0) { const u = clamp(S.age / T.warn); FX.warnRail(R.front, A, B, { color: R.P.color, k: u, time: S.t, seed: 3, maxLv: 2, intensity: R.P.intensity }); bossGather(R, M, 46, u, S.t, 5); }
    if (pose.rel >= 0) { const e = pose.rel; if (e > T.active + 0.25) return;
      if (e <= T.active) { const to = clamp(e / 0.07), from = clamp((e - (T.active - 0.1)) / 0.1); FX.beam(R.front, A, B, { w: r.beam_width * WL * R.P.size, color: R.P.color, time: S.t, from, to, taper: 6, alpha: 1, intensity: R.P.intensity }); FX.flare(R.front, A, 3 * R.P.size, R.P.color, S.t, 0.55 * (1 - from), 4);
        for (let i = 0; i < 18; i++) { const ph = (e * (2 + hash(i)) + hash(i * 3)) % 1, s = ph * Math.min(1, to) * r.beam_len * 0.6, side = (hash(i * 5) > 0.5 ? 1 : -1), q = toL(add(add(M, mul(dir, s)), mul(orth(dir), side * (r.beam_width * 0.5 + ph * 40)))); R.front.dot(q.x, q.y, pal[ph < 0.3 ? 3 : 2], (1 - ph) * 0.8); } }
      else { const k = 1 - (e - T.active) / 0.25; R.front.glow(A.x, A.y, 6 * R.P.size, pal[2], 0.4 * k * R.P.intensity); }
    }
  }
  if (S.tech === 'beam_bolt') {
    if (pose.rel < 0 && S.age >= 0) bossGather(R, M, 40, clamp(S.age / T.warn), S.t, 9);
    if (pose.rel >= 0 && pose.rel < 0.12) FX.flare(R.front, toL(add(n.from, mul(fromA(n.angle), hMouthDist(n)))), 6 * R.P.size, R.P.color, S.t, 1 - pose.rel / 0.12, 4);
    for (const b of S.shots) { if (b.kind !== 'bolt') continue; const age = S.t - b.t, life = r.bolt_life; if (age > life) continue;
      const dir = fromA(b.angle), P0 = add(add(b.from, mul(dir, hMouthDist(n))), mul(dir, r.bolt_speed * age)), P1 = add(P0, mul(dir, r.bolt_length)), fade = clamp((life - age) / 0.3);
      for (let k = 1; k < 26; k++) { const q = toL(sub(P0, mul(dir, k * 6))), f = (1 - k / 26) * fade; if (age * r.bolt_speed < k * 6) break; R.front.light(q.x + (hash(k + Math.floor(S.t * 20)) - 0.5) * 2, q.y + (hash(k * 3 + Math.floor(S.t * 20)) - 0.5) * 2, pal[2], f * 0.35 * R.P.intensity); if (hash(k * 7 + Math.floor(S.t * 30)) < f * 0.5) { const q2 = toL(sub(P0, mul(dir, k * 6))); R.front.dot(q2.x, q2.y, pal[3], f); } }
      // 光の棒：両端がとがり、前寄りが一番太い。芯が白く、縁へ冷える
      const A = toL(P0), Lp = r.bolt_length * WL, hw = r.bolt_width * 0.5 * WL * R.P.size, sd = orth(dir);
      for (let d = 0; d <= Lp; d += 0.5) { const k = d / Lp, tp = Math.min(1, k / 0.45, (1 - k) / 0.12) ** 0.7, w = Math.max(0.5, hw * tp), cx = A.x + dir.x * d, cy = A.y + dir.y * d;
        for (let o = -w; o <= w; o += 0.5) { const e = Math.abs(o) / w, lv = e < 0.3 ? 4 : e < 0.65 ? 3 : 2; if (fade > 0.6 || hash(d * 7 + o * 13 + Math.floor(S.t * 30)) < fade * 1.4) R.front.px(cx + sd.x * o, cy + sd.y * o, pal[lv]); }
        if (Math.floor(d) % 2 === 0) R.front.light(cx, cy, pal[2], 0.35 * fade * R.P.intensity); }
      R.front.glow(A.x + dir.x * Lp * 0.7, A.y + dir.y * Lp * 0.7, hw * 2.2, pal[2], 0.35 * fade * R.P.intensity); }
  }
}
// 雷：わしで承認した稲妻（zigzag・voltInk）を使う。予兆は頭の帯電、発動は着弾点の枝分かれ・最初の1コマの白・照らされた地面・冷える割れ目
function hCrackle(S, R, at, rad, k, seed, C) { // 頭のまわりの短い放電（0.06秒ごとに形が変わる）
  const f = Math.floor(S.t / 0.06), c = toL(at), rr = rad * WL;
  for (let i = 0; i < Math.round(1 + 4 * k); i++) { const Rg = new PX.Rng((seed * 97 + f * 13 + i * 7) >>> 0 || 1), a0 = Rg.range(0, TAU), a1 = a0 + Rg.range(0.6, 1.6), r0 = rr * Rg.range(0.5, 1), r1 = rr * Rg.range(0.5, 1.1);
    voltInk(R.front, zigzag(Rg, c.x + Math.cos(a0) * r0, c.y + Math.sin(a0) * r0, c.x + Math.cos(a1) * r1, c.y + Math.sin(a1) * r1, 0.35, 0.15), k * Rg.range(0.5, 1), C, 1, true, 0.3); }
}
function hStrike(S, R, L, rr, a, seed, C, src) {
  const fl = AQ_FLICK[Math.floor(a * 30 + 1e-4)] ?? 0, heat = Math.pow(clamp(1 - a / 1.2), 1.4);
  if (heat > 0) for (const q of aqCracks(seed, rr)) for (let i = 0; i < q.pts.length; i++) { const [x, y] = q.pts[i], h = heat * (1 - 0.5 * i / q.pts.length) - hash(x * 7.1 + y * 3.3) * 0.25; R.back.px(L.x + x, L.y + y, h > 0.6 ? C[6] : h > 0.35 ? C[4] : h > 0.12 ? C[2] : hexc('#141020')); }
  if (fl > 0) { const fr = Math.floor(a * 30), Rg = new PX.Rng((seed * 13 + fr) >>> 0 || 1), paths = [];
    for (let j = 0; j < 6; j++) { const an = j * TAU / 6 + Rg.range(-0.35, 0.35), l = rr * Rg.range(0.7, 0.95); paths.push(...zigzag(Rg, L.x, L.y, L.x + Math.cos(an) * l, L.y + Math.sin(an) * l, 0.22, 0.6)); }
    if (src && a < 0.1) paths.push(...zigzag(Rg, src.x, src.y, L.x, L.y, 0.28, 0.25)); // 頭から着弾点へ走る幹（その場に突然出さない）
    voltInk(R.front, paths, fl, a < 1 / 30 ? C.map((c, i) => C[Math.min(7, i + 2)]) : C, 1.25, false, 0.8); }
  if (a < 0.5) for (let j = 0; j < 16; j++) { const q = new PX.Rng(seed * 7 + j + 1), life = q.range(0.2, 0.45); if (a > life) continue; const an = q.range(0, TAU), d = q.range(25, 60) * a * (1 - a / life * 0.4), x = L.x + Math.cos(an) * d, y = L.y + Math.sin(an) * d, tl = 3 * (1 - a / life); R.front.line(x - Math.cos(an) * tl, y - Math.sin(an) * tl, x, y, C[a < 0.15 ? 7 : 5], 1 - a / life); }
  if (a < 0.3) R.back.glow(L.x, L.y, rr * 1.2, C[4], 0.5 * (1 - a / 0.3) * R.P.intensity);
  if (a < 0.08) { R.front.glow(L.x, L.y, rr * 1.1, C[6], (1 - a / 0.08) * 0.9 * R.P.intensity); R.front.glow(L.x, L.y, rr * 0.4, C[7], (1 - a / 0.08) * R.P.intensity); }
}
function hThunder(S, R, n, pose) {
  if (hTech(S).kind !== 'thunder' || S.age < 0) return; const r = S.r, T = pose.T, C = voltRamp(R.P.color), rr = r.thunder_radius * WL * R.P.size;
  if (pose.rel < 0) hCrackle(S, R, pose.head, 34, clamp(S.age / T.warn) ** 1.2, 3, C);
  if (S.tech === 'thunder_headbutt') {
    if (pose.rel >= 0 && pose.rel < T.active + 0.3 && n.from) { const k = Math.exp(-Math.max(0, pose.rel - T.active) / 0.1), f = Math.floor(S.t / 0.05), Rg = new PX.Rng(f * 7 + 3), A = toL(n.from), B = toL(n.pos); if (dist(n.from, n.pos) > 20) voltInk(R.back, zigzag(Rg, A.x, A.y, B.x, B.y, 0.3, 0.3), 0.7 * k, C, 1, true, 0.4); }
    if (n.struck) hStrike(S, R, toL(n.target), rr, S.t - n.struck, 17, C, null);
  }
  if (S.tech === 'thunder_drop') {
    const L = toL(n.target), M = toL(hMouthAt(n, pose));
    if (pose.rel < 0) { const k = clamp(S.age / T.warn); aqStatic(R.back, L, rr, Math.round(3 + 7 * k), rr * (0.2 + 0.25 * k), S.t, 23, C, 0.45 + 0.5 * k); R.back.glow(L.x, L.y, 6 + 10 * k, C[5], (0.2 + 0.6 * k) * R.P.intensity);
      const f = Math.floor(S.t / 0.12); if (hash(f * 3.1) < k) { const Rg = new PX.Rng(f * 11 + 5), mid = lerpV(M, L, Rg.range(0.25, 0.55)); voltInk(R.front, zigzag(Rg, M.x, M.y, mid.x + Rg.range(-6, 6), mid.y + Rg.range(-6, 6), 0.4, 0.2), 0.6 * k, C, 1, true, 0.3); } }
    else hStrike(S, R, L, rr, pose.rel, 29, C, M);
  }
}
// ---------- 現行表示の近似（render/attacks/hydra_shape.gd：判定の形を種類の色で出す）
function hCurrent(S, n) {
  const T = hTiming(S), t = S.age, r = S.r; if (n !== S.actor || t < 0) return; const e = t - T.warn;
  if (t < T.warn) D2.circle(n.pos, S.B.r * 0.5, rgba('#ffdb80', n.glow * 0.45));
  const kind = hTech(S).kind, col = { bite: '#ff7330', vortex: '#4dd9b8', debris: '#8c7050', beam: '#ff4066', thunder: '#66bfff' }[kind];
  if (hTech(S).type === 'lunge' || S.tech === 'bite_sweep') { if (e >= 0 && e <= T.active) D2.roundBeam(hAt(n, S.t - 1 / 60).pos, n.pos, rgba(col, 0.75), r.bite_radius * 2); }
  if (S.tech === 'wind_band' && e >= 0 && e <= T.active) D2.roundBeam(n.from, add(n.from, mul(fromA(n.sweep), r.wind_length)), rgba(col, 0.35), r.wind_width);
  if (S.tech === 'beam_fixed') { const A = n.pos, B = add(A, mul(fromA(e < 0 ? n.angle : n.sweep), r.beam_len)); if (e < 0) D2.line(A, B, rgba(col, 0.35), 3); else if (e <= T.active) D2.roundBeam(A, B, rgba(col, 0.85), r.beam_width); }
  if (S.tech === 'thunder_drop' && n.target) { if (e < 0) D2.arc(n.target, r.thunder_radius, 0, TAU, rgba(col, 0.6), 3); else if (e <= T.active) D2.circle(n.target, r.thunder_radius, rgba(col, 0.6)); }
  if (S.tech === 'thunder_headbutt' && n.struck && S.t - n.struck < r.thunder_flash) D2.circle(n.target, r.thunder_radius, rgba(col, 0.6));
  for (const b of S.shots) { const age = S.t - b.t, dir = fromA(b.angle);
    if (b.kind === 'blade' && age < r.blade_life) { const c = add(b.from, mul(dir, r.blade_speed * age)), pts = []; for (let i = 0; i <= 12; i++) { const a = -Math.PI / 2 + Math.PI * i / 12; pts.push(add(c, rotateV(V(Math.cos(a) * r.blade_size * 0.6, Math.sin(a) * r.blade_size), b.angle))); } D2.polyline(pts, rgba(col, 0.8), r.blade_width); }
    if (b.kind === 'bolt' && age < r.bolt_life) { const P0 = add(b.from, mul(dir, r.bolt_speed * age)); D2.roundBeam(P0, add(P0, mul(dir, r.bolt_length)), rgba(col, 0.85), r.bolt_width); } }
}
function hDraw(S, R) {
  const actor = S.actor, pose = hPose(S, actor, R), vis = R.proto ? hVisualNeck(S, actor, pose, R) : actor.points;
  // 試作のエフェクトは絵より先に描く（奥の層はこの直後に画面へ出し、手前の層は最後に重なる）
  if (R.proto) {
    hGrit(S, R, actor, vis, pose); hSweepTrail(S, R, actor, pose);
    if (pose.type === 'lunge') hGhosts(S, R, actor, pose);
    hEyes(S, R, actor, pose); hAir(S, R, actor, pose); hSnap(S, R, actor, pose);
    hInhale(S, R, actor, pose); hWindBand(S, R, actor, pose); hBlades(S, R); hRubbleWarn(S, R, actor, pose, vis); hSpitBurst(S, R, actor, pose); hBeam(S, R, actor, pose); hThunder(S, R, actor, pose);
  }
  hRocks(S, R, true);
  R.blitBack();
  S.necks.forEach((n, i) => hDrawNeck(S, n, n === actor ? vis : n.points, i));
  hStamp('body', null, S.B.pos, 0, S.B.r * 2 / IMG['hydra/body'].width);
  for (const n of S.necks) { if (!R.proto || n !== actor) hDrawHead(n, n.pos, n.angle); else hDrawHead(n, pose.head, pose.angle, pose.sx, pose.sy); }
  hRocks(S, R, false);
  if (!R.proto) hCurrent(S, actor);
  drawShip(S.ship);
}

const H_STATUS = {
  '状態': '作り直しの試作（未承認）。本番への組み込みは本人の承認後',
  '動きと判定': '首の点列・待機の狙い・技の時刻と軌道は main の C++（cpp/bosses/hydra/）と .tres の値のまま。試作の姿勢は絵の位置・向き・大きさだけ',
};
const H_DESC = {
  bite_thrust: '予兆：首をS字にためて頭を引き、目が赤く強まり、最後は震えて止まる → 一気に伸びて頭の形の光と両脇の空気の筋、目の光が通り道に残る → 上下の牙の鉤が口先へ寄り、前へ長い閃光と欠片・土ぼこり → 衝撃の波が首を根元へ抜ける',
  bite_sweep: '予兆：振りかぶる側へ首を弓なりにため、目が赤く強まって止まる → ゆっくり振り出し、真ん中で一気に速くなって頭が外へ突き出し、振る先を向いて噛みにいく。三日月の帯（先が白く後ろへ冷えて細る）と外へ削られる小石 → 振り切って少し行き過ぎて戻り、帯は後ろから崩れて消える。緩急と踏み込みは見た目だけで、判定は現行の円のまま',
  wind_band: '予兆：前から空気の筋が口へ吸い込まれ、頭がふくらんで止まる → 横倒しの竜巻を上から見た形：口から先へ広がる円錐の中を、ねじれた風の筋がらせんに回り（手前は明るく太く、奥は暗く細い）、輪のような風の弧が回りながら先へ流れ、軸に光の芯、葉がらせんに乗って運ばれる → 止むと根元から離れて流れ去る。本番との違い：本番の判定は幅180の一定の帯。円錐の太さ（つまみ）に判定を合わせるなら本番の変更が要る',
  wind_blades: '予兆：口のまわりで空気が渦を巻いて縮む → 0.18秒ごとに首を振り抜いて、風の刃を3枚。刃は斬撃で、ふちが一瞬で弧を走って開き、頭の側が太く尾の側へ長く細く伸びる。本体は白く、後ろ側は尾のほうへ流れる毛羽立ちになって緑へ溶ける → 寿命の終わりに尾が頭へ追いついて閉じる',
  rubble_lump: '予兆：首の瓦礫が口へ送られ、口先で塊になる。頭を大きく引いて止まる → 頭を突き出して吐き、土煙と砂利。岩は回りながら飛んで砂ぼこりの尾を引く',
  rubble_fan: '予兆：首の瓦礫が口へ送られ、口で小石が暴れる → 頭を突き出して扇に吐き、広い土煙と砂利。小岩はそれぞれ砂ぼこりの尾',
  beam_fixed: '予兆：口から射線いっぱいへ流れる照準の光（白くしない）と口へ集まる光。頭がふくらんで止まる → 先が伸びる光線、口の閃光、縁からこぼれる光。頭は反動で押されて震える → 根元から消え、口に光が残って消える',
  beam_bolt: '予兆：口へ光が集まる → 頭を突き出して撃ち、口の閃光。両端のとがった短い光の棒が飛び、後ろにちらつく光の粒を引く → 寿命の終わりに薄れて消える',
  thunder_headbutt: '予兆：頭のまわりに短い放電がちらつき、首をS字にためて止まる → 伸びる通り道に稲妻が残る → 到達点で中心から枝分かれする放電、最初の1コマは白、照らされた地面と冷える割れ目、火花',
  thunder_drop: '予兆：頭が帯電し、機体の進む先の範囲で放電が増え、頭から着弾点へ細い放電が伸びかける（円は描かない）→ 頭から着弾点へ幹が走り、中心から枝分かれ、最初の1コマは白、冷える割れ目',
};
const H_REFS = ['cpp/bosses/hydra/body.cpp（chain・待機の狙い）', 'cpp/bosses/hydra/ の各技（bite_thrust・bite_sweep・wind_band・wind_blades・rubble_lump・beam_fixed・beam_bolt・thunder_drop）', 'data/bosses/hydra.tres・hydra_moves/*.tres', 'scripts/render/attacks/hydra_shape.gd（現行表示の近似）', 'pixelFX の作り方を下敷き（impacts/hit-spark・melee/sword-slash・わしの稲妻 zigzag・voltInk）'];
const H_PARAMS = [
  { k: 'windLen', label: '風の帯（竜巻）の長さ（見た目、判定は340）', type: 'range', min: 200, max: 600, step: 10, def: 340 },
  { k: 'windR0', label: '風の帯（竜巻）の口元の太さ（半径）', type: 'range', min: 10, max: 90, step: 1, def: 32 },
  { k: 'windR1', label: '風の帯（竜巻）の先の太さ（半径）', type: 'range', min: 60, max: 200, step: 1, def: 115 },
  { k: 'bladeW', label: '三日月の風刃の太さ（見た目）', type: 'range', min: 8, max: 90, step: 1, def: 46 },
  { k: 'bladeFur', label: '三日月の風刃の毛羽立ちの長さ', type: 'range', min: 0, max: 2, step: 0.05, def: 1 },
  { k: 'alive', label: '横薙ぎの緩急と踏み込み', type: 'range', min: 0, max: 2, step: 0.05, def: 1 },
  { k: 'coil', label: 'ための首の曲がり', type: 'range', min: 0, max: 2, step: 0.05, def: 1 },
  { k: 'snap', label: '発動の勢い（反動・衝撃）', type: 'range', min: 0, max: 2, step: 0.05, def: 1 },
  { k: 'dust', label: '小石・土ぼこりの量', type: 'range', min: 0, max: 2, step: 0.05, def: 1 },
];
const H_LEDGER = { bite_thrust: ['H04'], bite_sweep: ['H04'], wind_band: ['H04', 'H06'], wind_blades: ['H04', 'H07'], rubble_lump: ['H04', 'H08'], rubble_fan: ['H04', 'H08'], beam_fixed: ['H04', 'H10'], beam_bolt: ['H04', 'H10'], thunder_headbutt: ['H04', 'H11'], thunder_drop: ['H04', 'H12'] };
for (const id of Object.keys(H_TECH)) {
  const d = H_TECH[id], r = hRule(id), T = r.normal_charge + d.active(r) + r.normal_hold;
  DEMOS.push({ id: 'H-' + id, ids: H_LEDGER[id], cat: 'うみへび座（H）', group: 'うみへび座', title: d.title, duration: T + (['wind_blades', 'rubble_lump', 'beam_bolt'].includes(id) ? 2.2 : 1.4), color: d.color,
    params: H_PARAMS, status: { ...H_STATUS, '作り': H_DESC[id] }, refs: H_REFS, setup(S) { hSetup(S, id); }, step: hStep, draw: hDraw, phase: hPhase });
}
