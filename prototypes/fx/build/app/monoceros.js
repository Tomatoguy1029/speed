// ===== いっかくじゅう：現行8技の手続き型の動き、パーツ、歩きコマ =====
const MONO = BOSSES.monoceros, MONO_LEGS = ['FrontLeftLeg', 'FrontRightLeg', 'RearLeftLeg', 'RearRightLeg'];
function monoHornLength(B) { return B.r * (B.phase > 1 ? MONO.def.params.horn_length_ratio_p2 : MONO.def.params.horn_length_ratio); }
const monoTip = S => add(S.B.pos, mul(fromA(S.angle), monoHornLength(S.B)));
function monoEnter(S, stage) { S.stage = stage; S.st = 0; S.released = false; }
function monoFinish(S) { S.B.mode = 'recovery'; S.recover = S.r.recover; S.fade = S.glow; monoEnter(S, 'recovery'); }
function monoFrame(time) { const a = MONO.gait.run, total = a.frames.reduce((n, f) => n + f.duration / a.speed, 0); let t = ((time % total) + total) % total; for (let i = 0; i < a.frames.length; i++) { t -= a.frames[i].duration / a.speed; if (t < 0) return i; } return 0; }
function monoEdits(S, R) {
  const B = S.B, k = B.r / 96, edits = {}, moving = len(B.vel) > 5 && !['windup', 'recovery', 'idle'].includes(B.mode), gait = B.gait;
  const hornLight = R.proto ? S.glowVisual * (B.phase > 1 ? R.P.hornBright : 1) : S.glow;
  const bodyAngle = S.bodyAngle ?? B.facing, neckAngle = S.neckAngle ?? S.angle, headAngle = S.headAngle ?? S.angle;
  edits.Head = { rotation: angDiff(neckAngle, bodyAngle) }; edits['Head/Lower'] = { rotation: angDiff(headAngle, neckAngle) };
  const tailTurn = angDiff(S.tailAngle ?? bodyAngle, bodyAngle), tailNode = MONO.nodes.find(n => n.name === 'TailBooster'), pivot = V(0, 26);
  edits.TailBooster = { rotation: tailTurn, position: add(tailNode.position, sub(pivot, rotateV(pivot, tailTurn))) };
  const cycle = MONO.gait.run.frames.reduce((s, f) => s + f.duration / MONO.gait.run.speed, 0);
  MONO_LEGS.forEach((path, i) => { const frame = moving ? monoFrame(gait + (i === 0 || i === 3 ? 0 : cycle * 0.5)) : 3, base = MONO.gait.run.frames[frame].texture, armor = MONO.gait.armor.frames[frame].texture;
    edits[path + '/Foot'] = { position: V(i % 2 === 0 ? -5 : 4, 40) }; edits[path + '/Foot/Sprite'] = { position: V(-Math.floor(base.region.w / 2), -6) }; edits[path + '/Foot/Sprite/Base'] = { texture: base }; edits[path + '/Foot/Sprite/Armor'] = { texture: armor };
  });
  if (S.tech === 'kick') {
    const r = S.r, back = B.mode === 'recovery' ? clamp((S.st - r.hold) / (Math.PI / r.return_speed)) : B.mode === 'idle' ? 1 : 0;
    for (const path of ['RearLeftLeg', 'RearRightLeg']) { const leg = MONO.nodes.find(n => n.name === path), target = sub(rotateV(mul(S.direction, r.reach / k), -bodyAngle + Math.PI / 2), leg.position); let turn = angOf(target) - Math.PI / 2; while (turn > 0) turn -= TAU; while (turn < -TAU) turn += TAU;
      const fold = B.mode === 'windup' ? clamp(S.st / r.warn) : 1, extend = B.mode === 'active' ? clamp(S.st / (r.active * 0.4)) : B.mode === 'recovery' ? 1 : 0;
      edits[path] = { rotation: turn * fold * (1 - back), scale: V(1, lerp(1, Math.max(1, len(target) / 70), extend) * (1 - back) + back) };
      edits[path + '/Foot'].position.y = lerp(lerp(40, 18, fold), 40, Math.max(extend, back));
    }
  }
  const hornNode = MONO.nodes.find(n => n.name === 'Horn'), lengths = hornNode.texture.metadata.core_lengths, frame = B.phase > 1 ? 14 : 0;
  // horn.global_position を同じパーツ変換で求める。絵の根元から現行の判定先まで延ばす。
  const rootRot = bodyAngle - Math.PI / 2, rootOff = mul(rotateV(V(0, 37), rootRot), k), root = M.mul(M.mk(B.facing, 1, 1, B.pos.x, B.pos.y), M.mk(rootRot - B.facing, k, k, rotateV(rootOff, -B.facing).x, rotateV(rootOff, -B.facing).y));
  const mats = {};
  for (let i = 1; i < MONO.nodes.length; i++) { const n = MONO.nodes[i], path = n.parent === '.' ? n.name : n.parent + '/' + n.name, e = edits[path] || {}, pos = e.position || n.position || V(0, 0), sc = e.scale || n.scale || V(1, 1), par = n.parent === '.' ? root : mats[n.parent]; if (!par) continue; mats[path] = M.mul(par, M.mk(e.rotation ?? n.rotation ?? 0, sc.x, sc.y, pos.x, pos.y)); }
  const hmat = mats['Head/Lower/Horn'], localRoot = sub(M.pt(hmat, V(0, 0)), B.pos), axis = norm(sub(M.pt(hmat, V(0, 1)), M.pt(hmat, V(0, 0)))), reach = monoHornLength(B), dot = localRoot.x * axis.x + localRoot.y * axis.y;
  edits['Head/Lower/Horn'] = { frame, scale: V(1, Math.max(1, reach - dot) / (k * lengths[frame])), white: hornLight * 0.65 };
  edits['Head/Lower/Sprite/head_gold_armor'] = { white: hornLight * 0.65 };
  return { edits, root: M.mk(rootRot - B.facing, k, k, rotateV(rootOff, -B.facing).x, rotateV(rootOff, -B.facing).y), horn: M.pt(hmat, V(0, 0)) };
}
function monoSetup(S, id) {
  S.tech = id; S.B = bossActor('monoceros', V(id === 'kick' ? 180 : -430, 0)); S.B.phase = Math.round(P().phase); S.r = bossRule('monoceros', id, S.B.phase); S.ship = shipState(V(id === 'kick' ? 10 : 150, 0), Math.PI / 2, 30); S.shipVel = V(0, 30);
  S.age = -0.4; S.st = 0; S.angle = S.B.facing; S.glow = 0; S.glowVisual = 0; S.direction = fromA(id === 'kick' ? Math.PI : 0); S.bodyAngle = 0; S.neckAngle = 0; S.headAngle = 0; S.tailAngle = 0;
  S.waves = []; S.slashes = []; S.booms = []; S.track = []; S.scorch = []; S.cut = 0; S.side = 1; S.completed = 0; S.traveled = 0; S.target = { ...S.ship.pos }; S.v = S.r.approach_speed_start || 0;
  monoEnter(S, ({ charge: 'aim', return_charge: 'aim', horn_wave: 'windup', sword_flash: 'aim', kick: 'aim', sweep: 'approach', lance: 'gather', horn_dance: 'aim' })[id]);
}
function monoFace(S, rate, dt, lead = 0) { const target = add(S.ship.pos, mul(S.shipVel, lead)); S.B.facing = rotToward(S.B.facing, angOf(sub(target, S.B.pos)), rate * dt); S.target = target; }
function monoLaunch(S) { S.direction = fromA(S.B.facing); S.angle = S.B.facing; S.B.mode = 'active'; S.traveled = 0;
  S.travel = S.tech === 'return_charge' ? Math.min(S.r.distance, dist(S.B.pos, S.ship.pos) + S.r.overshoot) : S.tech === 'horn_dance' ? Math.max(S.r.min_run, dist(S.B.pos, S.ship.pos) + S.r.overshoot) : S.r.distance;
  S.runSpeed = S.tech === 'horn_dance' ? Math.max(S.r.speed, S.v || 0) : S.tech === 'lance' ? S.r.speed : S.r.distance / S.r.active; monoEnter(S, 'run');
}
function monoStep(S, dt) {
  const B = S.B, r = S.r, id = S.tech, before = { ...B.pos }; S.age += dt; if (S.age < 0) return; S.st += dt;
  S.ship.pos.y = Math.sin(S.t * 0.5) * 60; S.shipVel = V(0, 30 * Math.cos(S.t * 0.5)); B.vel = V(0, 0);
  if (S.stage === 'recovery') { S.recover -= dt; S.glow = 0; if (S.recover <= 0) { B.mode = 'idle'; monoEnter(S, 'idle'); } }
  else if (S.stage !== 'idle') {
    const k = clamp(S.st / Math.max(0.001, r.warn || r.windup || 1));
    if (['charge', 'return_charge', 'horn_dance'].includes(id)) {
      if (S.stage === 'aim') { const duration = id === 'horn_dance' ? r.aim_time : r.warn, lock = id === 'horn_dance' ? r.aim_lock : MONO.def.params.lock_lead;
        if (S.st < duration - lock) { monoFace(S, r.aim_turn || MONO.def.turn, dt, MONO.def.params.lock_lead); S.lockedAngle = angOf(sub(S.target, B.pos)); }
        else if (id === 'charge' || id === 'return_charge') B.facing = S.lockedAngle ?? B.facing;
        S.angle = B.facing; S.glow = clamp(S.st / duration); if (S.st >= duration) monoLaunch(S);
      } else if (S.stage === 'run') { const step = Math.min(S.runSpeed * dt, S.travel - S.traveled); B.pos = add(B.pos, mul(S.direction, step)); S.traveled += step; S.glow = 1; S.angle = B.facing;
        if (S.traveled >= S.travel - 0.001) { S.completed++; if (id === 'charge' || S.completed >= r.passes) { if (id === 'horn_dance') { S.v = S.runSpeed; monoEnter(S, 'end'); } else monoFinish(S); } else if (id === 'return_charge') monoEnter(S, 'brake'); else { S.heading = B.facing; S.v = S.runSpeed; monoEnter(S, 'circle'); } }
      } else if (S.stage === 'brake') { const q = clamp(S.st / r.brake_time), speed = r.distance / r.active * r.brake_speed_ratio * (1 - q); B.pos = add(B.pos, mul(S.direction, speed * dt)); S.glow = 0; if (S.st >= r.brake_time) { S.fa = B.facing; monoEnter(S, 'turn'); } }
      else if (S.stage === 'turn') { const target = angOf(sub(S.ship.pos, B.pos)), q = clamp(S.st / (r.turn_time - r.turn_lock)); if (S.st <= r.turn_time - r.turn_lock) B.facing = S.fa + angDiff(target, S.fa) * q * q * (3 - 2 * q); S.angle = B.facing + clamp(angDiff(target, B.facing), -r.head_lead, r.head_lead) * Math.sin(Math.PI * q); if (S.st >= r.turn_time) monoLaunch(S); }
      else if (S.stage === 'circle') { S.heading -= r.circle_turn * dt; const targetSpeed = S.st > r.circle_late_time ? r.circle_speed_late : r.circle_speed; S.v = moveToward(S.v, targetSpeed, (S.v > targetSpeed ? r.circle_decel : r.circle_accel) * dt); B.pos = add(B.pos, mul(fromA(S.heading), S.v * dt)); B.facing = S.heading;
        const target = sub(S.ship.pos, B.pos), off = angDiff(angOf(target), S.heading); S.angle = S.heading + clamp(off, -r.head_lead, r.head_lead); S.glow = Math.max(0, 1 - Math.abs(off) / r.glow_angle);
        if (Math.abs(off) < r.align_angle && len(target) > r.align_min_distance && S.st > r.align_min_time) { B.facing = angOf(target); monoLaunch(S); } else if (S.st > r.circle_max_time) { S.v = S.runSpeed; monoEnter(S, 'end'); }
      } else if (S.stage === 'end') { S.v *= Math.exp(-r.end_decay * dt); B.pos = add(B.pos, mul(S.direction, S.v * dt)); S.angle = B.facing; S.glow = 0.6 * Math.min(1, S.st / 0.3); if (S.st >= r.end_time) monoFinish(S); }
    } else if (id === 'horn_wave') {
      if (S.stage === 'windup') { monoFace(S, r.windup_turn, dt); S.glow = 1 - (1 - k) ** 2; S.angle = B.facing - r.pull * S.glow; if (S.st >= r.windup) { B.mode = 'active'; monoEnter(S, 'swing'); } }
      else if (S.stage === 'swing') { monoFace(S, r.swing_turn, dt); const q = clamp(S.st / r.swing_time), e = q * q * (3 - 2 * q); S.angle = B.facing + S.side * (-r.pull + 2 * r.pull * e); S.glow = 1 - e;
        if (!S.released && e >= (r.pull + r.release_offset) / (2 * r.pull)) { S.released = true; S.waves.push({ center: { ...B.pos }, a: S.angle, t: S.t, tip: monoTip(S) }); }
        if (q >= 1) monoEnter(S, S.side === 1 ? 'recharge' : 'return');
      } else if (S.stage === 'recharge') { S.angle = B.facing + r.pull; S.glow = clamp(S.st / r.recharge); if (S.st >= r.recharge) { S.side = -1; monoEnter(S, 'swing'); } }
      else if (S.stage === 'return') { const q = smooth(0, r.return_time, S.st); S.angle = B.facing - r.pull * (1 - q); S.glow = 0; if (S.st >= r.return_time) monoFinish(S); }
    } else if (id === 'sweep') {
      if (S.stage === 'approach') { S.v = Math.min(r.approach_speed_max, S.v + r.approach_accel * dt); monoFace(S, r.approach_turn, dt); S.direction = fromA(B.facing); B.pos = add(B.pos, mul(S.direction, S.v * dt)); const q = clamp(S.st / r.twist_time); S.angle = B.facing - r.twist * (1 - (1 - q) ** 2); S.glow = q;
        if ((dist(B.pos, S.ship.pos) < r.stop_range && S.st > r.approach_min) || S.st > r.approach_max) { S.base = B.facing; monoEnter(S, 'stop'); }
      } else if (S.stage === 'stop') { S.v = Math.max(0, S.v - r.stop_decel * dt); B.pos = add(B.pos, mul(fromA(S.base), S.v * dt)); S.angle = S.base - lerp(r.twist, r.windup_twist, 1 - (1 - clamp(S.st / r.stop_time)) ** 2); if (S.st >= r.stop_time) { B.mode = 'active'; monoEnter(S, 'swing'); } }
      else if (S.stage === 'swing') { const q = clamp(S.st / r.active); S.angle = S.base - r.windup_twist + r.arc * q * q * (1.6 - 0.6 * q); if (q >= 1) monoEnter(S, 'hold'); }
      else if (S.stage === 'hold') { if (S.st >= r.hold) monoEnter(S, 'return'); }
      else if (S.stage === 'return') { S.angle = lerp(S.base - r.windup_twist + r.arc, S.base, smooth(0, r.return_time, S.st)); if (S.st >= r.return_time) monoFinish(S); }
    } else if (id === 'sword_flash') {
      if (S.stage === 'aim') { const duration = S.cut === 0 ? r.first_windup : r.windup, q = clamp(S.st / duration); if (S.st < duration - r.lock_time) monoFace(S, r.aim_turn, dt); S.glow = 1 - (1 - q) ** 2; S.angle = B.facing - S.side * r.pull * S.glow; if (S.st >= duration) { S.base = B.facing; S.v = r.lunge_speed; B.mode = 'active'; monoEnter(S, 'swing'); } }
      else if (S.stage === 'swing') { const e = smooth(0, r.swing_time, S.st); S.angle = S.base + S.side * (-r.pull + 2 * r.pull * e); S.v *= Math.exp(-r.lunge_decay * dt); B.pos = add(B.pos, mul(fromA(S.base), S.v * dt));
        if (!S.released && e >= 0.5) { S.released = true; S.releaseAt = S.st; const center = add(B.pos, mul(fromA(S.base), clamp(dist(B.pos, S.target), r.slash_min, r.slash_max))), u = mul(fromA(S.base + S.side * r.slash_angle), r.slash_length * 0.5); S.slashes.push({ a: sub(center, u), b: add(center, u), t: S.t }); S.glow = 0; }
        if (e >= 1 && S.released && S.st - S.releaseAt >= r.slash_hit_time) monoEnter(S, S.cut + 1 < r.cuts ? 'gap' : 'return');
      } else if (S.stage === 'gap' && S.st >= r.cut_gap) { S.cut++; S.side = S.cut % 2 ? -1 : 1; B.mode = 'windup'; monoEnter(S, 'aim'); }
      else if (S.stage === 'return') { S.angle = lerp(S.base + S.side * r.pull, B.facing, smooth(0, r.return_time, S.st)); if (S.st >= r.return_time) monoFinish(S); }
    } else if (id === 'lance') {
      if (S.stage === 'gather') { if (S.st < r.warn - r.lock_time) monoFace(S, r.aim_turn, dt); S.direction = fromA(B.facing); B.pos = sub(B.pos, mul(S.direction, r.back_speed * dt)); S.form = 1 - (1 - k) ** 2; S.glow = S.form; S.angle = B.facing; if (S.st >= r.warn) { S.form = 1; monoLaunch(S); } }
      else if (S.stage === 'run') { const step = Math.min(r.speed * dt, r.distance - S.traveled); B.pos = add(B.pos, mul(S.direction, step)); S.traveled += step; S.boomTime = (S.boomTime || 0) + dt; while (S.boomTime >= r.boom_interval) { S.boomTime -= r.boom_interval; S.booms.push({ at: add(B.pos, mul(S.direction, r.boom_ahead)), t: S.t }); } if (S.traveled >= r.distance) { S.v = r.speed; monoEnter(S, 'stop'); } }
      else if (S.stage === 'stop') { S.v *= Math.exp(-r.stop_decay * dt); B.pos = add(B.pos, mul(S.direction, S.v * dt)); if (!S.shattered && S.st >= r.shatter_time) { S.shattered = { at: monoTip(S), t: S.t }; S.form = 0; S.glow = 0; } if (S.st >= r.stop_time) monoFinish(S); }
    } else if (id === 'kick') {
      S.angle = B.facing; S.glow = 0;
      if (S.stage === 'aim') { S.direction = norm(sub(S.ship.pos, B.pos)); if (S.st >= r.warn) { B.mode = 'active'; monoEnter(S, 'strike'); } }
      else if (S.stage === 'strike' && S.st >= r.active) { S.kickAt = S.t; monoFinish(S); S.recover += r.hold + Math.PI / r.return_speed; }
    }
  }
  if (dt > 0) B.vel = mul(sub(B.pos, before), 1 / dt); if (len(B.vel) > 5) B.gait += dt; else B.gait = 0;
  const attacking = B.mode === 'active' || (B.mode === 'windup' && S.st >= (r.warn || 0) - MONO.def.params.lock_lead), follow = 1 - Math.exp(-dt / (0.16 * (attacking ? 0.3 : 1)));
  S.bodyAngle += angDiff(B.facing, S.bodyAngle) * follow; S.bodyAngle = B.facing + clamp(angDiff(S.bodyAngle, B.facing), -24 * Math.PI / 180, 24 * Math.PI / 180);
  S.neckAngle = S.angle; S.headAngle = S.angle; S.tailAngle += angDiff(S.bodyAngle, S.tailAngle) * (1 - Math.exp(-dt / 0.14)); S.tailAngle = S.bodyAngle + clamp(angDiff(S.tailAngle, S.bodyAngle), -Math.PI / 10, Math.PI / 10);
  S.glowVisual = S.glow > S.glowVisual ? S.glow : Math.max(S.glow, S.glowVisual - dt / 0.22);
  if (len(B.vel) > 400) { S.track.push({ ...B.pos }); if (S.track.length > 22) S.track.shift(); if (id === 'horn_dance' && S.stage === 'run') S.scorch.push({ at: { ...B.pos }, t: S.t }); }
  cam.x = (B.pos.x + S.ship.pos.x) * 0.5; cam.y = (B.pos.y + S.ship.pos.y) * 0.5;
}
function monoDraw(S, R) {
  const B = S.B, r = S.r, id = S.tech, P = R.P, u = fromA(S.angle), tip = monoTip(S), pal = FX.ramp(P.color), rig = monoEdits(S, R);
  if (R.proto) {
    bossTrail(R, S.track, ['run', 'circle'].includes(S.stage) ? 0 : S.st);
    if (B.mode === 'windup') { bossGather(R, tip, B.r, S.glow, S.t, 71); if (['charge', 'return_charge', 'horn_dance'].includes(id) && S.stage === 'aim') { const samples = []; for (let i = 0; i < 20; i++) { const d = (i / 20) * (r.distance || r.min_run), q = toL(add(tip, mul(u, d))); R.back.glow(q.x, q.y, (2 + i * 0.1) * P.size, pal[2], S.glow * 0.12 * P.intensity); } } }
    for (const e of S.scorch) { const age = S.t - e.t, fade = 1 - smooth(0.25, 0.9, age); if (fade <= 0) continue; const q = toL(e.at); if (hash(Math.floor(e.t * 60)) < fade) { R.back.px(q.x, q.y, pal[1]); R.back.glow(q.x, q.y, 3, pal[2], fade * 0.15 * P.intensity); } }
  } else if (B.mode === 'windup' && ['charge', 'return_charge', 'kick'].includes(id)) { const dir = id === 'kick' ? S.direction : u, end = add(B.pos, mul(dir, (id === 'kick' ? r.reach : monoHornLength(B) + r.distance))); D2.line(add(B.pos, mul(dir, B.r * 0.65)), end, rgba('#f2b567', 0.3), id === 'kick' ? 30 : 6); }
  for (const w of S.waves) { const age = S.t - w.t, radius = r.wave_start + age * r.wave_speed; if (radius > r.wave_max) continue;
    if (!R.proto) D2.arc(w.center, radius, w.a - r.wave_half_angle, w.a + r.wave_half_angle, rgba('#cfffef', 1 - radius / r.wave_max), r.wave_width);
    else { const count = Math.max(20, Math.ceil(radius * r.wave_half_angle * 2 * WL)); for (let i = 0; i < count; i++) { const q = i / (count - 1), a = w.a + lerp(-r.wave_half_angle, r.wave_half_angle, q), edge = Math.sin(Math.PI * q), noise = Math.sin(i * 0.8 - S.t * 18) * 3, rr = radius + noise, at = add(w.center, mul(fromA(a), rr)); const f = 1 - radius / r.wave_max; if (hash(i * 13) > f && radius > r.wave_max * 0.75) continue; const p = toL(at); R.front.px(p.x, p.y, pal[3]); R.front.glow(p.x, p.y, (1 + r.wave_width * WL * edge * P.size), pal[2], f * 0.15 * P.intensity); } }
  }
  for (const slash of S.slashes) { const age = S.t - slash.t; if (R.proto) bossSlash(R, slash.a, slash.b, r.slash_width, age, 0.6, S.slashes.indexOf(slash) + 1); else if (age < 0.6) { const d = norm(sub(slash.b, slash.a)), n = mul(orth(d), r.slash_width * 0.8 * (1 - age / 0.6)); const mid = lerpV(slash.a, slash.b, 0.5); D2.poly([slash.a, add(mid, n), slash.b, sub(mid, n)], rgba('#c9a6ff', 1 - (age / 0.6) ** 2)); } }
  for (const boom of S.booms) { const age = S.t - boom.t; if (R.proto) bossBreath(R, boom.at, B.facing + Math.PI, age, 83, 0.7, 200); else if (age < 0.4) D2.arc(boom.at, lerp(40, 190, age / 0.4), B.facing + Math.PI - 0.9, B.facing + Math.PI + 0.9, rgba('#9fe8ff', (1 - age / 0.4) * 0.5), 3); }
  // 現行の後部ブースターも尾の向きを使う。試作は流れる青い噴射の密度場。
  const nozzle = add(B.pos, mul(fromA(S.tailAngle + Math.PI), B.r * 0.85)), strength = S.stage === 'run' ? id === 'lance' ? 3.5 : 2.5 : 0.55;
  const jets = []; for (let i = 0; i < 10; i++) jets.push({ pos: add(nozzle, rotateV(V(i * 10 * strength, Math.sin(S.t * 20 - i * 0.7) * i), S.tailAngle + Math.PI)), radius: (12 - i) * (0.5 + strength * 0.3), seed: i });
  bossFire(R.back, jets, S.t, '#61c9ff', 0.65, 1);
  R.blitBack(); drawBossParts(B, rig.edits, { root: rig.root });
  if (id === 'lance' && S.form > 0) { const a = add(B.pos, mul(u, B.r * 0.65)), b = add(tip, mul(u, r.head_length * S.form)); if (R.proto) bossSlash(R, a, b, r.width * S.form, 0.04, 1, 99); else D2.line(a, b, '#fff2b0', 12 + 28 * S.form); }
  if (S.shattered && R.proto) FXW.sparks(R.front, S.shattered.at, (S.t - S.shattered.t) / P.timing, 31, 22, P.color, 55, 0.7);
  if (id === 'kick' && S.kickAt && R.proto) bossBreath(R, add(B.pos, mul(S.direction, r.reach)), angOf(S.direction), S.t - S.kickAt, 39, 0.9, 120);
  drawShip(S.ship);
}
for (const id of Object.keys(MONO.moves)) {
  const ids = id === 'horn_wave' ? ['I02', 'I04'] : id === 'horn_dance' ? ['I01', 'I04', 'I05'] : ['I01', 'I03', 'I04'];
  DEMOS.push({ id: 'I-' + id, ids, cat: 'いっかくじゅう座（I）', group: 'いっかくじゅう座', title: MONO.moves[id].display_name, duration: id === 'horn_dance' ? 16 : id === 'return_charge' ? 10 : 6, color: '#ffd27a',
    params: [{ k: 'phase', label: '形態（1／2）', type: 'range', min: 1, max: 2, step: 1, def: 1 }, { k: 'hornBright', label: '第2形態の角の明るさ', type: 'range', min: 0, max: 1.5, step: 0.01, def: 0.8 }],
    status: { '状態': '独立HTMLの試作（未承認）。本番への組み込みはC++移行後', '現行表示': '現行の8技の段階・時刻・距離、歩きコマ、角の15コマと伸び、首・胴・尾の旋回を移植。照明は焼込みで近似', '試作': '金色の溜めと残光、衝撃波・斬撃・燃え跡。角の消灯は0.22秒で薄れる。第2形態の明るさ0.8はHTML内だけ', '本番との違い': id === 'horn_dance' ? '画面外への移動範囲は不変更。カメラが本体と機体の間を追う。乱舞の自然選択条件は変更せず単独再生する' : '障害物のない比較場面。地形への角刺さり・共通AIの技選択は再現対象外。攻撃の数値・軌道は不変更' },
    refs: ['scenes/bosses/monoceros_parts.tscn・monoceros_presentation.tscn', 'data/visuals/monoceros_gait.tres・assets/pixel/monoceros/horn/horn.tres', 'scripts/bosses/monoceros_presentation.gd・monoceros_parts.gd', 'data/bosses/monoceros_moves/' + id + '.tres・scripts/bosses/monoceros/techniques/' + id + '.gd', 'pixelFX sword-slash.js の速い先端・冷える残光'],
    setup(S) { monoSetup(S, id); }, step: monoStep, draw: monoDraw, phase(S) { return bossPhase(S.B); }
  });
}
