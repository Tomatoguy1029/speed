// ===== おおいぬ：techniques/*.gd・hound.gd の技進行を独立再生 =====
const CANIS_IDS = { pounce: ['O02'], command: ['O03', 'O04'], stream: ['O03', 'O04', 'O08'], sirius: ['O05'], sirius_flame: ['O05', 'O06'], howl: ['O07'], bay: ['O09'], blaze: ['O10'], relay: ['O11'], hunt: ['O12'], hunt_pounce: ['O02', 'O04'], nova: ['O13', 'O14'] };
const moveToward = (a, b, step) => a + clamp(b - a, -step, step);
const canisMouth = B => add(B.pos, mul(fromA(B.facing), B.r * 0.84));
function canisPose(B, t, opts = {}) {
  const edits = {}, moving = len(B.vel) > 5;
  ['RearLeftLeg', 'RearRightLeg', 'FrontLeftLeg', 'FrontRightLeg'].forEach((path, i) => edits[path] = { rotation: Math.sin(B.gait + (i === 0 || i === 3 ? 0 : Math.PI)) * (moving ? 0.16 : 0.015) });
  if (opts.proto) {
    const phases = [0, 0.5, 0.25, 0.75];
    ['RearLeftLeg', 'RearRightLeg', 'FrontLeftLeg', 'FrontRightLeg'].forEach((path, i) => { const node = BOSSES.canis_major.nodes.find(n => n.name === path), phase = ((B.walkPhase || 0) / TAU + phases[i]) % 1, stance = phase < 0.72, stroke = stance ? 1 - 2 * phase / 0.72 : -1 + 2 * smooth(0.72, 1, phase); edits[path] = { rotation: moving ? stroke * 0.11 : 0, position: V(node.position.x, node.position.y + (moving ? stroke * 4 : 0)), scale: V(1, moving && !stance ? 1 - Math.sin((phase - 0.72) / 0.28 * Math.PI) * 0.13 : 1) }; });
  }
  edits.Tail = { rotation: Math.sin(B.gait * 0.4) * 0.07 };
  edits.Head = { rotation: B.pose.howl ? -0.45 * smooth(0, 0.65, B.charge) : 0 };
  if (opts.proto) {
    // 見た目の部位だけで、静かな構えから咆哮の反動へ移す。役者の位置・方向は保つ。
    const charge = B.mode === 'windup' ? B.charge : 0, release = opts.releaseAge >= 0 ? Math.max(0, 1 - opts.releaseAge / 0.22) : 0;
    if (opts.orderRoar) {
      const age = opts.releaseAge, inhale = age >= 0 ? 0 : clamp(charge * 2);
      const push = age >= 0 ? smooth(0, 0.035, age) * (1 - smooth(0.09, 0.24, age)) : 0;
      // 横へ首を振るのでなく、体を縮めて踏ん張り、頭と胸を前へ押し出して戻す。
      edits.Head = { rotation: -0.045 * inhale, position: V(0, 42 - inhale * 9 + push * 13), scale: V(1 + push * 0.035, 1 + push * 0.09) };
      edits.Body = { position: V(0, -inhale * 4 - push * 3), scale: V(1 + inhale * 0.025 - push * 0.02, 1 - inhale * 0.055 + push * 0.04) };
    } else if (B.pose.shout || B.pose.gather || B.pose.bay || release > 0) { edits.Head.rotation += -0.12 * charge + Math.sin(release * Math.PI) * 0.11; edits.Head.position = V(0, 42 - charge * 3 + release * 4); edits.Body = { position: V(0, -charge * 2 + release * 2) }; }
    if (B.pose.flame && B.mode === 'active') { edits.Head.rotation += Math.sin(t * 23) * 0.018; edits.Head.position = V(0, 42 + Math.sin(t * 16) * 1.2); }
  }
  return edits;
}
function drawCanis(B, t, opts = {}) {
  const c = B.pose.crouch || 0, k = B.r / 100;
  const rig = drawBossParts(B, canisPose(B, t, opts), { ...opts, root: M.mk(-Math.PI / 2, k * (1 + c * 0.15), k * (B.pose.stretch || 1), 0, 0) });
  if (opts.shadow || !rig['Head/Sirius']) return;
  const at = M.pt(rig['Head/Sirius'], V(0, 0)); B.visualMouth = { ...at }; const q = IMG['canis_major/star'];
  const charge = opts.proto && opts.orderRoar && !B.pose.glow ? 0 : Math.max(B.charge, B.pose.glow || 0), large = IMG['canis_major/large_star'];
  g.save(); g.translate(at.x, at.y); g.rotate(B.facing + Math.sin(t * 2.1) * 0.04); g.scale(k, k);
  if (large) { g.globalAlpha = Math.floor(clamp((B.phase > 1 ? 0.75 : 0) + charge * 0.7, 0, 0.95) * 4) / 4; g.drawImage(large, -large.width / 2, 1 - large.height / 2); }
  g.globalAlpha = 1; if (q) g.drawImage(q, -q.width / 2 + 0.5, -q.height / 2 - 0.5); g.restore();
}
function canisSetup(S, id) {
  S.tech = id; S.B = bossActor('canis_major', V(-500, 0)); S.B.phase = Math.round(P().phase); S.r = bossRule('canis_major', id, S.B.phase);
  S.age = -0.4; S.stageAge = 0; S.stage = 'start'; S.ship = shipState(V(130, 0), Math.PI / 2, 35); S.shipVel = V(0, 35);
  S.pack = []; S.jetVisuals = []; S.jets = []; S.flames = []; S.trails = []; S.shouts = []; S.transfers = []; S.bursts = []; S.shadows = [];
  if (mode === 'proto' && CANIS_ROARS.has(id)) roarScreen ||= makeRoarScreen();
  const count = id === 'nova' && mode === 'current' ? 8 : Math.round(P().pack), B = S.B;
  for (let i = 0, row = 1, column = 0; i < count; i++) {
    const q = mkE('hound', add(B.pos, V(B.r + 20 + row * 50, (column - row * 0.5) * 55)), 0, { idx: i, vel: V(0, 0), trail: [], warning: -1, dead: false }); S.pack.push(q);
    column++; if (column > row) { row++; column = 0; }
  }
  S.order = S.pack.slice(); for (let i = S.order.length - 1; i > 0; i--) { const j = Math.floor(S.rng() * (i + 1)); [S.order[i], S.order[j]] = [S.order[j], S.order[i]]; }
}
function canisFace(S, dt, rate = BOSSES.canis_major.def.turn, lead = 0) { S.B.facing = rotToward(S.B.facing, angOf(sub(add(S.ship.pos, mul(S.shipVel, lead)), S.B.pos)), rate * dt); }
function canisShout(S, at = canisMouth(S.B), facing = S.B.facing, small = false) { S.shouts.push({ small, at: { ...at }, a: facing, t: S.t, seed: S.shouts.length * 9 + 1 }); }
function canisFinish(S, recover = S.r.recover || 0.6) { if (S.B.mode === 'recovery' || S.B.mode === 'idle') return; S.B.mode = 'recovery'; S.recover = recover; S.B.vel = V(0, 0); S.B.charge = 0; S.B.pose = {}; S.stage = 'done'; }
function canisLaunchHound(S, q, speed, duration) { q.launch = S.t; q.until = S.t + duration; q.warning = -1; q.vel = mul(norm(sub(S.ship.pos, q.pos)), speed); q.facing = angOf(q.vel); }
function canisSteer(q, goal, face, cfg, dt) {
  const d = dist(goal, q.pos), to = angOf(sub(goal, q.pos)); let speed = len(q.vel);
  if (d < cfg.arrive) { speed = moveToward(speed, 0, cfg.decel * dt); if (speed < 80) q.facing = rotToward(q.facing, angOf(sub(face, q.pos)), cfg.face_turn * dt); }
  else { q.facing = rotToward(q.facing, to, (speed >= cfg.turn_switch ? cfg.turn_slow : cfg.turn_fast) * dt); const target = Math.min(cfg.max_speed, d * 2.2) * Math.max(0.25, Math.cos(q.facing - to)); speed = moveToward(speed, target, (target > speed ? cfg.accel : cfg.decel) * dt); }
  q.vel = mul(fromA(q.facing), speed); q.pos = add(q.pos, mul(q.vel, dt));
}
function canisJump(S, dt, rule, start = false) {
  const B = S.B;
  if (start) { S.jump = { t: 0, warn: rule.warn, left: S.pack.length < rule.alone_hounds ? rule.chain : 1, rule, locked: false, active: false }; B.mode = 'windup'; }
  const j = S.jump; if (!j) return false;
  if (!j.active) {
    if (!j.locked) { S.aim = add(S.ship.pos, mul(S.shipVel, Math.max(0, j.warn - j.t) + rule.lead_extra)); B.facing = rotToward(B.facing, angOf(sub(S.aim, B.pos)), BOSSES.canis_major.def.turn * dt); }
    j.t += dt;
    if (!j.locked && j.t >= j.warn - rule.lock) { j.locked = true; j.dir = norm(sub(S.aim, B.pos)); S.aim = add(S.aim, mul(j.dir, rule.overshoot)); }
    B.charge = clamp(j.t / j.warn); B.pose = { crouch: B.charge, stretch: 1 - B.charge * 0.15 }; B.vel = V(0, 0);
    if (j.t >= j.warn) { j.active = true; j.t = 0; B.mode = 'active'; S.jumpFrom = { ...B.pos }; }
    return false;
  }
  B.vel = mul(sub(S.aim, B.pos), 1 / Math.max(rule.active - j.t, dt)); B.pos = add(B.pos, mul(B.vel, dt)); B.facing = angOf(j.dir); B.charge = 0; B.pose = { stretch: 1.15 }; j.t += dt;
  if (j.t < rule.active) return false;
  S.land = { at: { ...B.pos }, t: S.t }; j.left--; if (j.left <= 0) return true;
  j.t = 0; j.warn = rule.chain_warn; j.locked = false; j.active = false; B.mode = 'windup'; return false;
}
function canisStartJet(S, at, angle, length, width, duration, trail = false, owner = 'boss') {
  const jet = { at: { ...at }, a: angle, length, width, duration, age: 0, emit: 0, life: S.r.beam_particle_life ?? 0.65, trail: null };
  if (trail) { jet.trail = { at: { ...at }, a: angle, length: 0, maximum: length, t: S.t, life: S.r.trail_time, width: S.r.trail_width }; S.trails.push(jet.trail); }
  S.jets.push(jet); S.jetVisuals.push({ ...jet, owner, t: S.t }); return jet;
}
function canisFlameAim(S, dt, cfg) {
  const B = S.B;
  if (!S.flameAim) { S.flameAim = { age: 0, fired: false, locked: false, cfg }; B.mode = 'windup'; }
  const a = S.flameAim;
  if (!a.fired) {
    if (!a.locked) { canisFace(S, dt, cfg.turn, cfg.remaining ? Math.max(0, cfg.warn - a.age) : cfg.lead || 0); if (a.age >= cfg.warn - cfg.lock) a.locked = true; }
    a.age += dt; B.charge = clamp(a.age / cfg.warn); S.warning = { at: canisMouth(B), a: B.facing, length: cfg.length, width: cfg.width, k: B.charge, locked: a.locked };
    if (a.age >= cfg.warn) { canisStartJet(S, canisMouth(B), B.facing, cfg.length, cfg.width, cfg.time, cfg.trail); a.fired = true; a.age = 0; B.mode = 'active'; S.warning = null; }
    return false;
  }
  a.age += dt; B.charge = 0; return a.age >= cfg.time;
}
function canisSequence(S, dt, r, startAt, order = S.order, prefix = '') {
  let last = startAt;
  order.forEach((q, i) => { const mark = startAt + i * (r.interval ?? r.seq_interval), launch = mark + (r.each_warn ?? r.seq_warn); last = launch;
    if (S.age >= mark && q.seq !== prefix) { q.seq = prefix; q.warning = S.t + Math.max(0, launch - S.age); }
    if (S.age >= launch && q.sent !== prefix) { q.sent = prefix; canisLaunchHound(S, q, r.lunge_speed, r.lunge_time); }
  });
  return last;
}
function canisStep(S, dt) {
  S.age += dt; const B = S.B, r = S.r, id = S.tech, age = S.age, was = { ...B.pos };
  S.ship.pos = id === 'nova' && mode === 'proto' ? V(P().playerX, P().playerY) : V(130, Math.sin(S.t * 0.5) * 70); S.shipVel = V(0, Math.cos(S.t * 0.5) * 35);
  if (age < 0) return;
  canisOrderCue(S);
  B.gait += dt * (B.mode === 'active' ? 18 : 9);
  if (B.mode === 'recovery') { S.recover -= dt; if (S.recover <= 0) B.mode = 'idle'; }
  if (!['recovery', 'idle'].includes(B.mode)) {
    B.charge = clamp(age / (r.warn || 1)); B.pose = {}; B.vel = V(0, 0);
    if (S.stage === 'start') { S.stage = 'run'; if (id === 'pounce') canisJump(S, 0, r, true); }
    if (id === 'pounce') { if (canisJump(S, dt, r)) canisFinish(S); }
    else if (['command', 'stream', 'hunt', 'hunt_pounce'].includes(id)) {
      const sr = ['hunt', 'hunt_pounce'].includes(id) ? bossRule('canis_major', 'stream', B.phase) : r;
      if (age < sr.warn) { canisFace(S, dt); B.pose = { shout: true }; if (id === 'command') for (const q of S.pack) q.warning = 0.4 + sr.warn; }
      else {
        if (!S.orderStarted) { S.orderStarted = true; B.mode = 'active'; }
        let last;
        if (id === 'command') { for (const q of S.pack) if (q.sent !== 'command') { q.sent = 'command'; canisLaunchHound(S, q, r.lunge_speed, r.lunge_time); } last = sr.warn; }
        else last = canisSequence(S, dt, sr, sr.warn, S.order, 'stream');
        if (['command', 'stream'].includes(id) && age >= last + sr.lunge_time + (id === 'command' ? 0.05 : 0)) canisFinish(S);
        if (id === 'hunt' && age >= last + r.gap) { if (canisFlameAim(S, dt, { warn: r.aim_warn, lock: r.aim_lock, lead: r.aim_lead, turn: r.aim_turn, length: r.beam_length, width: r.beam_width, time: r.beam_time })) canisFinish(S); B.pose = { glow: B.charge }; }
        if (id === 'hunt_pounce' && age >= last + r.gap) { const jr = { ...bossRule('canis_major', 'pounce', B.phase), alone_hounds: 0 }; if (!S.jump) canisJump(S, 0, jr, true); if (canisJump(S, dt, jr)) canisFinish(S, jr.recover); }
      }
    } else if (id === 'sirius') {
      if (S.gap > 0) { S.gap -= dt; }
      else if (canisFlameAim(S, dt, { warn: r.warn, lock: r.lock, lead: r.lead, turn: r.aim_turn, length: r.beam_length, width: r.beam_width, time: r.beam_time, trail: true })) { S.shot = (S.shot || 0) + 1; if (S.shot >= r.shots) canisFinish(S); else { S.gap = r.shot_gap; S.flameAim = null; } }
      B.pose = { gather: B.mode === 'windup', glow: B.charge };
    } else if (id === 'sirius_flame') {
      canisFace(S, dt, age < r.warn ? BOSSES.canis_major.def.turn : r.turn);
      if (age >= r.warn && age < r.warn + r.duration) {
        B.mode = 'active'; B.charge = 1;
        if (dist(B.pos, S.ship.pos) > r.advance_until) B.pos = add(B.pos, mul(fromA(B.facing), r.advance * dt));
        S.emit = (S.emit || 0) + dt * r.emit_rate;
        while (S.emit >= 1) { S.emit--; const a = B.facing + (S.rng() - 0.5) * r.spread * Math.PI / 180; S.flames.push({ pos: canisMouth(B), vel: mul(fromA(a), r.particle_speed * lerp(0.9, 1.1, S.rng())), age: 0, life: r.life, r0: r.r_start, r1: r.r_end, drag: r.drag, seed: S.rng() * 100 }); }
      } else if (age >= r.warn + r.duration) canisFinish(S);
      B.pose = { glow: B.charge, flame: true };
    } else if (id === 'blaze') {
      if (age < r.warn) canisFace(S, dt);
      const chosen = S.pack.slice().sort((a, b) => dist(a.pos, S.ship.pos) - dist(b.pos, S.ship.pos)).slice(0, r.count);
      if (!S.chosen) S.chosen = chosen;
      S.chosen.forEach((q, i) => { const at = r.ignite_at + i * r.ignite_step;
        if (!q.transfer && age >= at - r.ignite_step) { q.transfer = true; S.transfers.push({ from: canisMouth(B), q, t: S.t, life: r.ignite_step }); }
        if (!q.burn && age >= at) q.burn = { at: S.t, blink: -1 };
      });
      if (age >= Math.max(r.warn, r.ignite_at + Math.max(0, S.chosen.length - 1) * r.ignite_step)) canisFinish(S);
    } else if (id === 'relay') {
      if (age < r.warn) { canisFace(S, dt); B.pose = { shout: true }; }
      S.order.forEach((q, i) => { const mark = r.warn + i * r.interval, at = mark + r.each_warn;
        if (age >= mark && !q.relay) { q.relay = { from: { ...q.pos }, a: angOf(sub(S.ship.pos, q.pos)) }; q.warning = 0.4 + at; q.facing = q.relay.a; }
        if (age >= at && !q.relayFired) { q.relayFired = true; canisStartJet(S, add(q.pos, mul(fromA(q.relay.a), q.r)), q.relay.a, r.hound_beam_length, r.hound_beam_width, r.hound_beam_time, false, 'hound'); }
      });
      const finalAt = r.warn + Math.max(0, S.order.length - 1) * r.interval + r.each_warn + r.interval + 0.3;
      if (age >= finalAt) { if (canisFlameAim(S, dt, { warn: r.final_warn, lock: r.final_lock, turn: r.final_turn, remaining: true, length: r.final_length, width: r.final_width, time: r.final_time })) canisFinish(S); B.pose = { glow: B.charge }; }
    } else if (id === 'howl') {
      if (age < r.warn) { canisFace(S, dt); B.pose = { howl: true }; }
      else {
        B.mode = 'active';
        if (!S.ringCenter) { S.ringCenter = { ...S.ship.pos }; const total = r.ring_count + r.gaps * r.gap_slots, angles = []; for (let slot = 0; slot < total; slot++) if (slot % (total / r.gaps) >= r.gap_slots) angles.push(slot * TAU / total + 0.3);
          for (let i = 0; i < angles.length; i++) { let q = S.pack[i]; if (!q) { q = mkE('hound', add(S.ringCenter, mul(fromA(angles[i]), r.ring_radius + r.spawn_out)), angles[i] + Math.PI, { idx: i, trail: [], vel: V(0, 0), warning: -1 }); S.pack.push(q); } q.ringA = angles[i]; }
          S.order = S.pack.slice().sort((a, b) => a.ringA - b.ringA);
        }
        if (age < r.warn + r.follow_time) S.ringCenter = lerpV(S.ringCenter, S.ship.pos, 1 - Math.exp(-r.follow_rate * dt));
        const rr = lerp(r.ring_radius, r.ring_close, clamp((age - r.warn - r.gather_time) / r.close_time));
        for (const q of S.pack) if (!q.sent) { q.goal = add(S.ringCenter, mul(fromA(q.ringA), rr)); q.followScale = r.catch_up; }
        const last = canisSequence(S, dt, r, r.warn + r.follow_time, S.order, 'howl'); if (age >= last + r.tail) canisFinish(S);
      }
    } else if (id === 'bay') {
      if (age < r.warn) { canisFace(S, dt); B.pose = { bay: true, shout: true }; }
      else {
        B.mode = S.jump ? B.mode : 'bay'; B.pose = { bay: true };
        if (!S.jump && age < r.warn + r.pounce_at && dist(B.pos, S.ship.pos) > r.approach_stop) { canisFace(S, dt); B.pos = add(B.pos, mul(fromA(B.facing), BOSSES.canis_major.def.speed * dt)); }
        if (age >= r.warn + r.pounce_at) { const jr = { ...bossRule('canis_major', 'pounce', B.phase), alone_hounds: 0 }; if (!S.jump) canisJump(S, 0, jr, true); if (canisJump(S, dt, jr)) canisFinish(S, jr.recover); }
        S.pack.forEach((q, i) => { if (!q.bay) q.bay = { angle: TAU * i / S.pack.length + (S.rng() - 0.5) * 0.3, phase: S.rng() * TAU, cool: lerp(0.6, 1.4, S.rng()), bark: S.rng(), nipping: false }; const m = q.bay; m.angle += r.orbit * dt; m.cool -= dt; m.bark -= dt;
          const rel = Math.abs(angDiff(m.angle, Math.PI / 2)), front = rel < r.front_angle * Math.PI / 180, back = rel > r.back_angle * Math.PI / 180;
          if (q.until > S.t) return;
          if (q.warning > 0 && S.t >= q.warning) { canisLaunchHound(S, q, r.nip_speed, r.nip_time); m.cool = r.nip_cd; return; }
          if (back && m.cool <= 0 && S.pack.filter(q => q.warning > S.t || q.until > S.t).length < r.nip_max) { q.warning = S.t + r.nip_warn; m.cool = r.nip_cd; }
          if (front && m.bark <= 0) { m.bark = lerp(r.bark_min, r.bark_max, S.rng()); canisShout(S, q.pos, angOf(sub(S.ship.pos, q.pos)), true); }
          const rad = front ? r.r_front : back ? r.r_back : r.r_side, wobble = mul(V(Math.sin(S.t * 2 + m.phase), Math.cos(S.t * 1.7 + m.phase)), r.wobble);
          q.steer = { goal: add(add(S.ship.pos, mul(fromA(m.angle), rad)), wobble), face: S.ship.pos, cfg: r };
        });
      }
    } else if (id === 'nova' && mode === 'proto') {
      canisWallStep(S); B.pose = { glow: age < r.warn ? age / r.warn : Math.max(0, 1 - (age - r.warn) / r.after) }; if (age >= r.warn) B.mode = 'active'; if (age >= r.warn + r.after) canisFinish(S);
    } else if (id === 'nova') {
      if (!S.pairs) { S.pairs = S.order.slice(0, r.count).map((q, i) => ({ q, group: Math.floor(i / 2), angle: Math.PI / 3 + Math.floor(i / 2) * TAU / 3, side: i % 2 ? -1 : 1 })); }
      const source = canisMouth(B), cfg = { ...bossRule('canis_major', 'bay'), max_speed: r.gather_speed };
      for (const m of S.pairs) { const u = fromA(m.angle), off = add(sub(source, B.pos), mul(orth(u), r.pair_side * m.side)), clearance = B.r + m.q.r + cfg.arrive + 4, along = off.x * u.x + off.y * u.y, ex = -along + Math.sqrt(Math.max(0, along * along + clearance ** 2 - len(off) ** 2));
        let goal = add(add(source, mul(u, Math.max(r.pair_dist, ex))), mul(orth(u), r.pair_side * m.side));
        if (age < r.warn + r.after) { const at = m.q.pos, line = sub(goal, at), k = clamp(((B.pos.x - at.x) * line.x + (B.pos.y - at.y) * line.y) / Math.max(1, len(line) ** 2)); if (dist(add(at, mul(line, k)), B.pos) < B.r + m.q.r + 6) goal = add(B.pos, mul(fromA(angOf(sub(at, B.pos)) + clamp(angDiff(angOf(sub(goal, B.pos)), angOf(sub(at, B.pos))), -0.6, 0.6)), clearance + 16)); m.q.steer = { goal, face: add(source, mul(u, 1000)), cfg }; }
      }
      S.shadows = [];
      for (let group = 0; group < 3; group++) { const members = S.pairs.filter(m => m.group === group); if (!members.length) continue; const ref = angOf(sub(members[0].q.pos, source)); let lo = Infinity, hi = -Infinity, near = Infinity;
        for (const m of members) { const to = sub(m.q.pos, source), d = len(to), half = Math.asin(Math.min(1, r.body_radius / Math.max(r.body_radius + 1, d))), angle = angDiff(angOf(to), ref); lo = Math.min(lo, angle - half); hi = Math.max(hi, angle + half); near = Math.min(near, d); }
        S.shadows.push({ a: ref + (lo + hi) / 2, half: (hi - lo) / 2, near });
      }
      B.pose = { glow: age < r.warn ? age / r.warn : Math.max(0, 1 - (age - r.warn) / r.after) }; if (age >= r.warn) B.mode = 'active'; if (age >= r.warn + r.after) canisFinish(S);
    }
  }
  if (dt > 0) { B.vel = mul(sub(B.pos, was), 1 / dt); B.walkPhase = (B.walkPhase || 0) + dist(B.pos, was) / (B.r * 0.95) * TAU; }
  for (const q of S.pack) {
    if (q.dead) continue;
    if (q.burn) { const c = bossRule('canis_major', 'blaze'), cfg = { ...bossRule('canis_major', 'bay'), max_speed: c.run_speed };
      if (q.burn.blink < 0 && (dist(q.pos, S.ship.pos) < c.stop_dist || S.t - q.burn.at >= c.max_run)) q.burn.blink = S.t;
      canisSteer(q, q.burn.blink >= 0 ? q.pos : S.ship.pos, S.ship.pos, cfg, dt);
      if (q.burn.blink >= 0 && S.t - q.burn.blink >= c.blink) { q.dead = true; const burst = { at: { ...q.pos }, t: S.t, radius: c.explode_radius }; S.bursts.push(burst); canisBurstStart(S, burst); }
    } else if (q.until > S.t) { q.pos = add(q.pos, mul(q.vel, dt)); q.trail.push({ ...q.pos }); if (q.trail.length > 14) q.trail.shift(); }
    else if (q.steer) { canisSteer(q, q.steer.goal, q.steer.face, q.steer.cfg, dt); q.steer = null; }
    else if (q.goal) { const to = sub(q.goal, q.pos), speed = Math.min(enemyDef('hound').speed * (q.followScale || 1), len(to) / 0.25); q.vel = lerpV(q.vel, mul(norm(to), speed), clamp(enemyDef('hound').accel * dt)); q.pos = add(q.pos, mul(q.vel, dt)); q.facing = angOf(q.vel); }
    else if (!(q.relay && !q.relayFired)) { q.vel = mul(q.vel, Math.exp(-8 * dt)); q.pos = add(q.pos, mul(q.vel, dt)); }
  }
  for (const jet of S.jets) { jet.age += dt; jet.emit += Math.min(dt, Math.max(0, jet.duration - jet.age + dt)) * 100;
    while (jet.emit >= 1) { jet.emit--; const drag = 0.7, speed = jet.length * drag / (1 - Math.exp(-drag * jet.life)), spread = Math.atan2(jet.width * 1.4, jet.length) * 2, a = jet.a + (S.rng() - 0.5) * spread;
      S.flames.push({ pos: { ...jet.at }, origin: jet.at, range: jet.length, vel: mul(fromA(a), speed * lerp(0.9, 1.1, S.rng())), age: 0, life: jet.life, r0: jet.width * 0.5, r1: jet.width * 1.6, drag, seed: S.rng() * 100, trail: jet.trail }); }
  }
  S.jets = S.jets.filter(j => j.age < j.duration);
  for (const f of S.flames) { f.age += dt; f.vel = mul(f.vel, Math.exp(-f.drag * dt)); f.pos = add(f.pos, mul(f.vel, dt)); if (f.range && dist(f.pos, f.origin) >= f.range) f.age = f.life; if (f.trail) f.trail.length = Math.min(f.trail.maximum, Math.max(f.trail.length, dist(f.pos, f.origin))); }
  S.flames = S.flames.filter(f => f.age < f.life);
  for (const b of S.bursts) if (b.fx && S.t - b.t < 2.8 && dt > 0) { b.fx.ps.update(dt); b.fx.blazes.update(dt); }
}
function canisDraw(S, R) {
  R = bossView(R, '#80c8ff');
  const B = S.B, r = S.r, t = S.t, id = S.tech, P = R.P, mouth = canisMouth(B), pal = FX.ramp(P.color);
  if (R.proto) {
    for (const q of S.pack) bossTrail(R, q.trail, q.until > t ? 0 : Math.max(0, t - (q.until || 0)));
    if (S.jump && !S.jump.active && S.aim) { const shadow = { ...B, pos: S.aim, pose: {}, vel: V(0, 0) }; g.save(); g.filter = 'brightness(0) blur(5px)'; g.globalAlpha = 0.28 * B.charge; drawCanis(shadow, t, { shadow: true }); g.restore(); }
    if (S.land) bossBreath(R, S.land.at, B.facing, t - S.land.t, 91, Math.PI, 120);
    if (S.warning) { const w = S.warning; bossGather(R, w.at, B.r, w.k, t); const A = toL(w.at), u = fromA(w.a), n = orth(u);
      for (let i = 0; i < 65; i++) { const phase = (hash(i * 7) + t * 0.4) % 1, d = phase * w.length * WL, width = w.width * WL * (0.5 + hash(i + 1)), q = add(add(A, mul(u, d)), mul(n, (hash(i + 8) - 0.5) * width)); R.back.glow(q.x, q.y, 1.5 + hash(i) * 2, pal[2], (0.06 + w.k * 0.12) * P.intensity); }
    }
  } else {
    if (S.jump && !S.jump.active && S.aim) { D2.line(add(B.pos, mul(fromA(B.facing), B.r)), S.aim, rgba(S.jump.locked ? '#ff667d' : '#f2b567', 0.35 + B.charge * 0.4), S.jump.locked ? 6 : 3); D2.arc(S.aim, B.r * 0.5, 0, TAU, rgba('#ff667d', 0.6), 3); }
    if (B.mode === 'recovery') D2.arc(B.pos, 106 * B.r / 100, 0, TAU, rgba('#9fe8ff', 0.45 + Math.sin(t * 14) * 0.25), 6);
    if (S.warning) { const w = S.warning; D2.line(w.at, add(w.at, mul(fromA(w.a), w.length)), rgba(w.locked ? '#ff667d' : '#cfefff', w.locked ? 0.35 : lerp(0.12, 0.45, w.k)), w.locked ? w.width : lerp(1, 3, w.k)); }
    if (['command', 'stream', 'hunt_pounce'].includes(id) && B.mode === 'windup') for (let i = 0; i < 2; i++) { const p = (t * 2.5 + i * 0.5) % 1; D2.arc(mouth, (20 + p * 90) * CS, 0, TAU, rgba('#f2b567', 1 - p), 3); }
  }
  if (id === 'nova') canisNovaDraw(S, R);
  // 現行の炎も同じ粒の位置・半径で描く。密度場の焼込み描画はHTML側での再現。
  const fireSamples = S.flames.map(f => ({ pos: f.pos, radius: lerp(f.r0, f.r1, f.age / f.life), age: f.age, life: f.life, seed: f.seed }));
  if (R.proto && !['sirius_flame', 'sirius', 'relay', 'hunt'].includes(id)) canisFire(R, fireSamples, t, 'flame'); if (!R.proto) bossFire(R.front, fireSamples, t, '#8acbff');
  if (R.proto) for (const b of S.bursts) canisBurstDraw(S, R, b, 'back');
  for (const q of S.pack) if (!q.dead) {
    if (q.burn) { const samples = []; for (let i = 0; i < 12; i++) samples.push({ pos: add(q.pos, rotateV(V(-i * q.r * 0.3, Math.sin(i * 2 + t * 18) * q.r * 0.4), q.facing)), radius: q.r * (1.4 - i * 0.08), seed: i }); if (R.proto) canisFire(R, samples, t, 'hound'); else bossFire(R.back, samples, t, '#8acbff', P.intensity, P.size); }
    if (q.warning > t) { const glow = clamp(1 - (q.warning - t) / (r.each_warn || r.nip_warn || r.warn || 0.3)); if (!R.proto) D2.circle(q.pos, q.r * 1.5, rgba('#fff', glow * 0.5)); }
    if (!R.proto && id === 'command' && q.until > t) { for (let i = 1; i < q.trail.length; i++) D2.line(q.trail[i - 1], q.trail[i], rgba('#ff667d', i / q.trail.length * 0.7), q.r); D2.circle(q.pos, q.r * 1.9, rgba('#ff667d', 0.22)); }
  }
  R.blitBack();
  if (R.proto) canisTrailPictures(S, R);
  const mainShout = S.shouts.findLast(e => !e.small);
  drawCanis(B, t, { proto: R.proto, orderRoar: CANIS_ROARS.has(id) && !S.jump && !S.flameAim, releaseAge: mainShout ? t - mainShout.t : -1, white: R.proto && id === 'nova' ? canisFlash(S) * 0.5 : R.proto && B.pose.glow ? B.pose.glow * 0.15 : 0 });
  for (const q of S.pack) if (!q.dead) { drawEnemy(q); if (R.proto && q.warning > t) canisHoundWarning(q, clamp(1 - (q.warning - t) / 0.6)); }
  if (R.proto) {
    for (const tr of S.transfers) { const age = t - tr.t; if (age < 0 || age > tr.life + 0.25) continue; const u = clamp(age / tr.life), at = lerpV(tr.from, tr.q.pos, u); canisFire(R, [{ pos: at, radius: 16 * (1 - smooth(tr.life, tr.life + 0.25, age)) }], t, 'ignite'); }
    if (!CANIS_ROARS.has(id) && B.charge > 0 && B.mode === 'windup' && !S.jump) bossGather(R, mouth, B.r * 1.2, B.charge, t);
  }
  if (R.proto) for (const b of S.bursts) canisBurstDraw(S, R, b, 'front');
  else {
  for (const b of S.bursts) { const age = (t - b.t) / P.timing; if (age < 0 || age > 0.65) continue; const samples = []; for (let i = 0; i < 18; i++) samples.push({ pos: add(b.at, mul(fromA(hash(i * 9) * TAU), Math.sqrt(age) * b.radius * hash(i + 3))), radius: b.radius * (0.3 + hash(i) * 0.2) * (1 - age / 0.65), seed: i }); bossFire(R.front, samples, t, P.color, P.intensity, P.size); }
  }
  drawShip(S.ship);
  if (R.proto) canisJetPictures(S, R);
}
function canisNovaDraw(S, R) {
  const r = S.r, age = S.age, source = canisMouth(S.B), A = toL(source), P = R.P, pal = FX.ramp(P.color), shadowAt = (point) => { const to = sub(point, source), d = len(to); return S.shadows.some(s => d > s.near && Math.abs(angDiff(angOf(to), s.a)) <= s.half); };
  const light = age < r.warn ? clamp(age / r.warn) : Math.max(0, 1 - (age - r.warn) / r.after);
  if (R.proto) {
    canisNovaLight(S, R);
  } else {
    for (const s of S.shadows) { const pts = []; for (let j = 0; j <= 12; j++) pts.push(add(source, mul(fromA(s.a + lerp(-s.half, s.half, j / 12)), s.near))); for (let j = 12; j >= 0; j--) pts.push(add(source, mul(fromA(s.a + lerp(-s.half, s.half, j / 12)), r.ring_end))); D2.poly(pts, rgba('#000104', light * 0.9)); }
    for (let k = 0; k < r.rings; k++) { const e = age - r.warn - k * r.ring_gap, radius = 30 + r.ring_speed * e; if (e < 0 || radius > r.ring_end) continue; for (let i = 0; i < 256; i++) { const a = i / 256 * TAU, b = (i + 1) / 256 * TAU; if (shadowAt(add(source, mul(fromA((a + b) / 2), radius)))) continue; D2.line(add(source, mul(fromA(a), radius)), add(source, mul(fromA(b), radius)), '#65baff', r.ring_band * 2); } }
  }
}
const tFix = t => Math.floor(t * 30) / 30;
for (const id of Object.keys(CANIS_IDS)) {
  const r = bossRule('canis_major', id);
  DEMOS.push({ id: 'O-' + id, ids: CANIS_IDS[id], cat: 'おおいぬ座（O）', group: 'おおいぬ座', title: r.display_name, duration: id === 'howl' ? 9 : id === 'blaze' ? 7.5 : ['bay', 'relay', 'sirius', 'hunt', 'hunt_pounce', 'nova'].includes(id) ? 8.5 : 5.5, color: '#80c8ff',
    params: [{ k: 'phase', label: '形態（1／2）', type: 'range', min: 1, max: 2, step: 1, def: 1 }, { k: 'pack', label: '開始時の猟犬数', type: 'range', min: 0, max: id === 'nova' ? 18 : 8, step: 1, def: id === 'nova' ? 12 : 8 }, ...(id === 'nova' ? [{ k: 'playerX', label: '機体の位置（横）', type: 'range', min: -850, max: 850, step: 5, def: 130 }, { k: 'playerY', label: '機体の位置（縦）', type: 'range', min: -450, max: 450, step: 5, def: 0 }] : []), ...(CANIS_ROARS.has(id) ? [{ k: 'roarLevel', label: '咆哮の段階', type: 'select', options: [{ value: 1, label: '小：通常の号令（短く、弱く）' }, { value: 2, label: '中：強い号令（周囲にブラー）' }, { value: 3, label: '大：大技（広く、強いブラー）' }], def: id === 'howl' ? 2 : 1 }, { k: 'roarPost', label: '咆哮のブラーの強さ', type: 'range', min: 0, max: 2, step: 0.01, def: 1 }] : [])],
    status: { ...(CANIS_ROARS.has(id) ? { '咆哮': '小・中・大の3段階。本体と口元をぼかさず、周囲だけにラディアルブラーをかける。通常の号令は短い小、遠吠えは中。白い空気・集まる粒子・画面全体の揺れは出さない' } : {}), '状態': '独立HTMLの試作（未承認）。本番への組み込みはC++移行後', ...(CANIS_ROARS.has(id) ? { '号令の順序': '構える→予告中に咆哮→猟犬が動き始める。攻撃の開始時刻は現行どおり' } : {}), '技の再生': '現行の技データとRunnerを移植。障害物のない比較場面で再生。猟犬の初期配置と機体の移動は比較用', '現行表示': '本体のパーツ・歩き・頭の構えを移植。炎の密度場・照明はHTMLでの近似再現', '未決': id === 'nova' ? '試作では個体の実画像に沿う影と、前後をずらした3つの壁へ変更。表示と安全確認は同じ影の場を使用。波動ではなく瞬間的な閃光へ変更。本番の波動判定と、2体の間までまとめる遮蔽は移行後に変更が要る' : id === 'stream' ? 'O08の予告時間の延長は本番の挙動変更なので保留。現行の時刻を維持' : '本番の攻撃数値・軌道・範囲は変更していない' },
    refs: ['scenes/bosses/canis_major_parts.tscn・scripts/bosses/canis_major_presentation.gd（全身）', 'data/bosses/canis_major_moves/' + id + '.tres', 'scripts/bosses/canis_major/techniques/' + id + '.gd・technique_runner.gd', 'scripts/bosses/canis_major/sirius_effects.gd・scripts/enemies/hound.gd', 'pixelFX原本 fire/fire-breath・fire/fireball・fire/spirit-flame の青い出力、鳳凰と共通のpixel_fire密度場・爆発粒子', ...(CANIS_ROARS.has(id) ? ['G2 Studios「軽くて綺麗なラディアルブラーを作ろう！」https://note.com/g2studios/n/n7b7a0c068a1c（サンプリング位置のディザ）'] : [])],
    setup(S) { canisSetup(S, id); }, step: canisStep, draw: canisDraw, post: postCanisRoar, phase(S) { if (S.tech === 'nova' && mode === 'proto') return (canisFlash(S) > 0.6 ? '閃光発動／' : '') + (S.novaSafe ? '機体全体が影の中（安全）' : '光が届く（危険）'); const e = S.shouts.findLast(e => !e.small); return mode === 'proto' && e && S.t - e.t < 0.25 ? '咆哮（号令）' : bossPhase(S.B); }
  });
}
