// ===== うみへび：首のFABRIK・分離後の経路追従・現行18技 =====
const HYDRA = BOSSES.hydra, HP = HYDRA.def.params;
const H_KINDS = ['bite', 'vortex', 'debris', 'beam', 'thunder', 'bite', 'beam', 'vortex'];
const H_IDS = { bite_thrust: ['H04'], bite_sweep: ['H04'], wind_band: ['H04', 'H06'], wind_blades: ['H04', 'H07'], rubble_lump: ['H04', 'H08'], rubble_fan: ['H04', 'H08'], beam_fixed: ['H04', 'H10'], beam_bolt: ['H04', 'H10'], thunder_headbutt: ['H04', 'H11'], thunder_drop: ['H04', 'H12'], tornado: ['H04', 'H08', 'H13'], debris_shatter: ['H04', 'H08', 'H14'], beam_pincer: ['H04', 'H10', 'H15'], north: ['H04', 'H16'], sequence: ['H04', 'H17'], curve: ['H04', 'H10', 'H18'], swarm: ['H04', 'H19'], grid: ['H04', 'H10'] };
function hRule(id) { return { ...HP, ...bossRule('hydra', id) }; }
function hBase(S, n) { return S.separated ? sub(n.pos, mul(fromA(n.angle), HP.neck_rest)) : add(S.B.pos, mul(fromA(n.baseAngle + S.B.facing), S.B.r)); }
function hAim(n, angle, dt, separated) {
  if (dt <= 0) return;
  if (separated) { n.angle = rotToward(n.angle, angle, HP.squad.look_player_turn * dt); return; }
  const off = angDiff(angle, n.angle), speed = Math.min(HP.aim_turn, Math.sqrt(2 * HP.aim_accel * Math.abs(off))); n.aimV = moveToward(n.aimV || 0, Math.sign(off) * speed, HP.aim_accel * dt); let step = n.aimV * dt; if (Math.sign(step) === Math.sign(off) && Math.abs(step) > Math.abs(off)) step = off; n.angle += step; n.aimV = step / dt;
}
function hChain(S, n, dt) {
  const count = HP.neck_segments, base = hBase(S, n), head = n.pos, delta = sub(head, base), distance = len(delta), dir = norm(delta), side = orth(dir), rest = Math.max(distance, HP.neck_rest * HP.neck_slack), seglen = rest / count;
  if (S.separated) {
    if (!n.trail) n.trail = Array.from({ length: count + 1 }, (_, i) => sub(head, mul(fromA(n.angle), HP.neck_rest * i / count)));
    if (dist(head, n.trail[0]) >= 4) n.trail.unshift({ ...head }); if (n.trail.length > 256) n.trail.pop();
    const path = [head, ...n.trail], samples = [head]; let cursor = 1, at = head;
    for (let i = 1; i <= count; i++) { let needed = HP.neck_rest / count; while (cursor < path.length && dist(at, path[cursor]) < needed) { needed -= dist(at, path[cursor]); at = path[cursor++]; } const d = cursor < path.length ? norm(sub(path[cursor], at)) : mul(fromA(n.angle), -1); at = add(at, mul(d, needed)); const f = i / count, swim = clamp(len(n.vel) / HP.snake_speed), wave = Math.sin(S.t * HP.neck_wave_speed * 2 - f * TAU * HP.neck_wave_frequency + n.baseAngle) * HP.neck_wave_amplitude * (0.3 + 0.7 * swim) * Math.sin(f * Math.PI); samples.push(add(at, mul(orth(d), wave))); }
    n.points = samples.reverse(); return;
  }
  if (rest - distance < 0.001) { n.points = Array.from({ length: count + 1 }, (_, i) => lerpV(base, head, i / count)); return; }
  const initialize = !n.points || n.points.length !== count + 1, shift = initialize ? V(0, 0) : sub(base, n.points[0]), bend = Math.sqrt(Math.max(0, rest ** 2 - distance ** 2)) * 0.45, phase = n.baseAngle * 2.4, sign = Math.sin(phase) >= 0 ? 1 : -1, amplitude = Math.min(HP.neck_wave_amplitude, bend * 0.6), weight = initialize ? 1 : 1 - Math.exp(-HP.neck_response * dt);
  if (initialize) n.points = Array.from({ length: count + 1 }, () => V(0, 0)); const points = n.points; points[0] = base; points[count] = head;
  for (let i = 1; i < count; i++) { const f = i / count, wave = Math.sin(S.t * HP.neck_wave_speed + phase + f * HP.neck_wave_frequency * TAU) * amplitude, guide = add(lerpV(base, head, f), mul(side, Math.sin(f * Math.PI) * (bend * sign + wave))); points[i] = initialize ? guide : lerpV(add(points[i], shift), guide, weight); }
  for (let pass = 0; pass < HP.neck_iterations; pass++) { points[count] = head; let prev = head;
    for (let i = count - 1; i >= 0; i--) { prev = add(prev, mul(len(sub(points[i], prev)) > 0.001 ? norm(sub(points[i], prev)) : mul(dir, -1), seglen)); points[i] = prev; }
    points[0] = base; prev = base;
    for (let i = 1; i <= count; i++) { prev = add(prev, mul(len(sub(points[i], prev)) > 0.001 ? norm(sub(points[i], prev)) : dir, seglen)); points[i] = prev; } if (dist(points[count], head) < 0.01) break;
  }
  points[count] = head; const radial = sub(points[0], S.B.pos); if ((points[1].x - points[0].x) * radial.x + (points[1].y - points[0].y) * radial.y < 0) points[1] = add(points[0], mul(norm(radial), Math.max(4, dist(points[1], points[0]))));
  for (let i = 1; i < count; i++) if (dist(points[i], S.B.pos) < S.B.r + 12) points[i] = add(S.B.pos, mul(norm(sub(points[i], S.B.pos)), S.B.r + 12));
}
function pathLength(points) { let total = 0; for (let i = 1; i < points.length; i++) total += dist(points[i - 1], points[i]); return total; }
function pathAt(points, distance) { for (let i = 1; i < points.length; i++) { const span = dist(points[i - 1], points[i]); if (distance <= span || i === points.length - 1) return { pos: lerpV(points[i - 1], points[i], clamp(distance / Math.max(0.001, span))), angle: angOf(sub(points[i], points[i - 1])) }; distance -= span; } return { pos: points[0], angle: 0 }; }
const H_TINTED = new Map();
function hStamp(key, region, pos, angle, factor, brightness = 1, alpha = 1) {
  let im = IMG['hydra/' + key]; if (!im) return;
  // 比較つまみで変わる画像は値ごとに一度だけ用意し、全節で共有する。
  if (brightness !== 1) { const cacheKey = key + '/' + brightness; if (!H_TINTED.has(cacheKey)) { const c = document.createElement('canvas'); c.width = im.width; c.height = im.height; const ctx = c.getContext('2d'); ctx.filter = `brightness(${brightness})`; ctx.drawImage(im, 0, 0); H_TINTED.set(cacheKey, c); } im = H_TINTED.get(cacheKey); }
  const r = region || { x: 0, y: 0, w: im.width, h: im.height };
  g.save(); g.translate(pos.x, pos.y); g.rotate(angle); g.scale(factor, factor); g.globalAlpha *= alpha; g.drawImage(im, r.x, r.y, r.w, r.h, -r.w / 2, -r.h / 2, r.w, r.h); g.restore();
}
// 姿勢は描画だけで作り、技の点列・時刻・速度へ戻さない。
function hHeadKey(n) { return n.kind === 'bite' ? 'head0' : ['debris', 'beam'].includes(n.kind) ? 'head2' : 'head1'; }
function hMouthOffset(S, n) { return mul(fromA(n.angle), ((hHeadKey(n) === 'head2' ? 41 : 36) - 24.5) * S.B.r * 2 / HYDRA.body_source_width); }
function hMouth(S, n) { return add(n.pos, hMouthOffset(S, n)); }
function hSchedule(S, n) {
  const r = S.r, id = S.tech, i = S.participants.indexOf(n);
  if (i < 0 || ['destroy', 'visibility'].includes(id) || S.positioning) return null;
  let start = 0, fire = r.normal_charge || r.warning_time || 0.6, end;
  if (S.combo) {
    fire = r.warning_time;
    if (['sequence', 'swarm'].includes(id)) { start = r.warning_time + i * (id === 'sequence' ? r.sequence_gap : r.swarm_gap); fire = start + r.sequence_charge; }
    if (id === 'beam_pincer') fire += r.pincer_delay;
    if (id === 'curve') fire += r.curve_delay;
    if (id === 'grid') fire += r.normal_charge;
    if (id === 'tornado') fire += r.tornado_charge;
    if (id === 'debris_shatter' && n.kind === 'beam') fire += r.shatter_deploy;
    end = r.warning_time + Math.max(r.performance_time, r.north_flight || 0);
  } else {
    const duration = id === 'beam_fixed' ? r.beam_time : id === 'wind_band' ? r.wind_time : id === 'bite_sweep' ? r.sweep_time : ['bite_thrust', 'thunder_headbutt'].includes(id) ? r.normal_lunge : id === 'wind_blades' ? 2 * r.blade_interval : id === 'thunder_drop' ? r.thunder_flash : 0;
    end = fire + duration;
  }
  return { start, fire, end };
}
function hPose(S, n) {
  const timing = hSchedule(S, n); if (!timing || S.age < timing.start) return { prepare: 0, kick: 0, charge: 0, release: -1 };
  const u = clamp((S.age - timing.start) / Math.max(0.01, timing.fire - timing.start)), release = S.age - timing.fire;
  const prepare = release < 0 ? smooth(0.08, 0.72, u) : Math.exp(-release / 0.055);
  const kick = release < 0 ? 0 : (1 - Math.exp(-release / 0.012)) * Math.exp(-release / 0.13);
  return { prepare, kick, charge: release < 0 ? u : 0, release, timing };
}
function hHeadPose(S, n, proto) {
  const pose = proto ? hPose(S, n) : { prepare: 0, kick: 0 }, f = S.B.r * 2 / HYDRA.body_source_width;
  const sy = 1 - pose.prepare * 0.09 + pose.kick * 0.10, sx = 1 + pose.prepare * 0.06 - pose.kick * 0.03;
  // 口を支点にするので、頭を縮めても噴出口は動かない。
  const mouth = hMouth(S, n), center = sub(mouth, mul(hMouthOffset(S, n), sy));
  return { ...pose, sx, sy, center, mouth, f };
}
function hVisualNeck(S, n, proto) {
  if (!proto) return n.points;
  const pose = hHeadPose(S, n, true), dir = fromA(n.angle), side = orth(dir), sign = Math.sin(n.baseAngle * 2.4) >= 0 ? 1 : -1;
  return n.points.map((p, i, a) => {
    const u = i / (a.length - 1), w = 6.75 * u * u * (1 - u);
    let basePoint = p;
    if (n.visualBrace) {
      const braced = n.visualBrace, rootShift = sub(n.points[0], braced[0]), headShift = sub(n.pos, braced[braced.length - 1]);
      const held = add(braced[i], lerpV(rootShift, headShift, u)), hold = pose.release < 0 ? smooth(0.55, 0.75, pose.charge) : Math.exp(-pose.release / 0.07);
      basePoint = lerpV(p, held, hold);
    }
    let at = add(basePoint, add(mul(dir, (-28 * pose.prepare + 19 * pose.kick) * w), mul(side, sign * (22 * pose.prepare - 13 * pose.kick) * w)));
    if (i === a.length - 1) at = pose.center;
    return at;
  });
}
function hDrawHead(S, n, proto) {
  const key = hHeadKey(n), im = IMG['hydra/' + key]; if (!im) return;
  const pose = hHeadPose(S, n, proto);
  g.save(); g.translate(pose.center.x, pose.center.y); g.rotate(n.angle - Math.PI / 2); g.scale(pose.f * pose.sx, pose.f * pose.sy);
  g.drawImage(im, -im.width / 2, -im.height / 2); g.restore();
}
// 原本 ice/frost-breath を配色だけ変更して30fpsで書き出したatlas。
function hWindAtlas(S, R, at, direction, length, width, age, life, alpha = 1, bodyOnly = false) {
  const im = IMG.hydra_wind; if (!im || age < 0 || age >= life) return;
  const sheet = DATA.hydra_wind_sheet, meta = sheet.meta.pixelfx, frame = Math.floor(age * meta.fps) % meta.frames, cell = sheet.frames[frame].frame, pivot = meta.pivot, fade = Math.min(1, age / 0.04 + 0.22) * clamp((life - age) / 0.16) * alpha;
  g.save(); g.translate(at.x, at.y); g.rotate(direction); g.globalAlpha *= fade;
  g.beginPath(); g.rect(-3, -width * 0.5, length + 3, width); g.clip();
  const crop = bodyOnly ? 34 : 0;
  g.scale(length / 170, width / 88); g.drawImage(im, cell.x + crop, cell.y, cell.w - crop, cell.h, crop - pivot[0], -pivot[1], cell.w - crop, cell.h); g.restore();
}
function hDrawCharge(S, R, n) {
  const pose = hPose(S, n); if (!pose.charge) return;
  const mouth = hMouth(S, n), radius = lerp(46, 14, smooth(0.35, 1, pose.charge));
  bossGather(R, mouth, radius, pose.charge, S.t, S.necks.indexOf(n) + 17);
}
function hPhase(S) {
  if (S.positioning) return '配置中（現行の準備段階）';
  if (['destroy', 'visibility'].includes(S.tech) || S.finished) return bossPhase(S.B);
  const poses = S.participants.map(n => hPose(S, n));
  if (poses.every(p => p.timing && S.age >= p.timing.end)) return '終了・硬直';
  if (poses.every(p => p.release < 0)) return poses.some(p => p.charge >= 0.75) ? '構えを止める（発動直前）' : '溜める';
  return poses.some(p => p.release >= 0 && p.release < 0.16) ? '解放・反動' : '攻撃中';
}
function hDrawBody(S, R) {
  const factor = S.B.r * 2 / HYDRA.body_source_width;
  for (let index = 0; index < S.necks.length; index++) { const n = S.necks[index], points = hVisualNeck(S, n, R.proto), total = pathLength(points); if (total < 0.1) continue; let tailLength = 0;
    const brightness = R.proto ? R.P.neckDark : 1;
    if (S.separated) { const f = Math.min(factor, total / 64); for (const [distance, region] of [[10 * f, { x: 104, y: 0, w: 16, h: 32 }], [30 * f, { x: 130, y: 0, w: 28, h: 32 }]]) { const q = pathAt(points, distance); hStamp('neck', region, q.pos, q.angle - Math.PI / 2, f, brightness); } tailLength = 38 * f; }
    let tile = 0; const end = n.kind === 'immortal' ? Math.max(tailLength, total - 58 * factor) : total;
    for (let d = tailLength; d <= end; d += Math.max(1, 14 * factor), tile++) { const q = pathAt(points, d); hStamp('neck', { x: ((index + tile) % 3) * 32, y: 0, w: 32, h: 32 }, q.pos, q.angle - Math.PI / 2, factor, brightness); }
    if (n.kind === 'immortal') { const q = pathAt(points, Math.max(0, total - 30 * factor)); hStamp('undead', { x: 12, y: 3, w: 76, h: 76 }, q.pos, q.angle - Math.PI / 2, factor); }
  }
  if (!S.separated) { const im = IMG['hydra/body']; hStamp('body', null, S.B.pos, 0, S.B.r * 2 / im.width); }
  for (const n of S.necks) {
    if (n.dead) continue; hDrawHead(S, n, R.proto);
    if (!R.proto) { if (n.glow > 0) D2.circle(n.pos, S.B.r * 0.5, rgba('#ffdb80', n.glow * 0.45));
      if (n.active) for (let i = 0; i < 4; i++) { const d = V(i % 2 ? 1 : -1, i < 2 ? -1 : 1), at = add(n.pos, mul(d, 42)); D2.polyline([sub(at, V(d.x * 12, 0)), at, sub(at, V(0, d.y * 12))], '#ffd16c', 3); }
    }
  }
}
function hSetup(S, id) {
  S.tech = id; S.r = hRule(id); S.B = bossActor('hydra', V(-260, 0)); S.B.mode = 'windup'; S.separated = ['grid', 'swarm', 'visibility'].includes(id) || P().separated >= 1;
  S.ship = shipState(V(230, 0), Math.PI / 2, 35); S.age = -0.5; S.effects = []; S.projectiles = []; S.necks = []; S.bursts = []; S.combo = !S.r.head_kind && !['destroy', 'visibility'].includes(id);
  const count = S.combo || S.separated || id === 'visibility' ? 8 : 5;
  for (let i = 0; i < count; i++) { const baseAngle = TAU * i / count, base = add(S.B.pos, mul(fromA(baseAngle), S.B.r)), angle = baseAngle, pos = add(base, mul(fromA(angle), HP.neck_rest)); S.necks.push({ kind: H_KINDS[i], baseAngle, angle, pos, length: HP.neck_rest, vel: V(0, 0), glow: 0, target: { ...S.ship.pos }, phase: i * 0.9, active: false, t: 0, step: 0 }); }
  if (S.r.head_kind) S.participants = [S.necks.find(n => n.kind === S.r.head_kind)];
  else if (['north', 'sequence'].includes(id)) S.participants = S.necks.slice().sort((a, b) => Math.abs(angDiff(a.baseAngle, 0)) - Math.abs(angDiff(b.baseAngle, 0))).slice(0, 3);
  else if (id === 'tornado') S.participants = [S.necks[1], S.necks[2]];
  else if (id === 'debris_shatter') S.participants = [S.necks[2], S.necks[3]];
  else if (id === 'beam_pincer') S.participants = [S.necks[3], S.necks[6]];
  else S.participants = S.necks.slice();
  for (const n of S.participants) { n.active = true; n.from = { ...n.pos }; n.target = { ...S.ship.pos }; }
  if (id === 'thunder_drop') S.participants[0].target.y += 35 * S.r.thunder_lead;
  if (S.separated) {
    const bearer = { kind: 'immortal', baseAngle: Math.PI, angle: 0, pos: V(-520, 220), vel: V(0, 0), points: [], glow: 0 }; S.necks.push(bearer); S.bearer = bearer;
    if (['grid', 'swarm'].includes(id)) { S.positioning = true; S.gridOrigin = { ...S.ship.pos }; S.slots = S.participants.map((_, i) => id === 'grid' ? add(S.gridOrigin, HP.grid_layouts.provisional.slots[i].from) : V(Math.cos(TAU * i / 8) * (W / Z - 140) * 0.45, Math.sin(TAU * i / 8) * (H / Z - 140) * 0.45)); }
  }
  for (const n of S.necks) hChain(S, n, 0);
}
function hEffect(S, kind, points, width, delay, life, vel = V(0, 0)) { const e = { kind, points: points.map(q => ({ ...q })), width, delay, life, vel, t: S.t, seed: S.effects.length + 1 }; const source = S.participants?.reduce((best, n) => !best || dist(n.pos, points[0]) < dist(best.pos, points[0]) ? n : best, null); if (source) { e.source = S.necks.indexOf(source); e.mouthOffset = hMouthOffset(S, source); } S.effects.push(e); return e; }
function hShot(S, n, angle, radius) { const r = S.r; S.projectiles.push({ pos: { ...n.pos }, vel: mul(fromA(angle), r.lump_speed), radius, t: S.t, life: 6, kind: 'rubble', mouthOffset: hMouthOffset(S, n), seed: S.projectiles.length }); }
function hSnakeSteer(n, target, dt, scale = 1) {
  const offset = sub(target, n.pos), old = n.angle; if (len(offset) > 1) n.angle = rotToward(n.angle, angOf(offset), HP.snake_turn * dt);
  let speed = HP.snake_speed * scale * clamp(len(offset) / 100); speed *= 0.3 + 0.7 * Math.max(0, Math.cos(angDiff(n.angle, angOf(offset)))); n.vel = lerpV(n.vel, mul(fromA(n.angle), speed), 1 - Math.exp(-HP.snake_accel * dt)); n.pos = add(n.pos, mul(n.vel, dt)); n.turn = angDiff(n.angle, old) / Math.max(dt, 0.001);
}
function hNormal(S, n, dt) {
  const r = S.r, t = S.age, charge = r.normal_charge, elapsed = t - charge, id = S.tech, separated = S.separated, base = hBase(S, n), before = { ...n.pos };
  n.glow = t < charge ? clamp(t / charge) : 0;
  if (t < charge) {
    hAim(n, angOf(sub(n.target, ['bite_thrust', 'thunder_headbutt', 'bite_sweep'].includes(id) ? base : n.pos)) - (id === 'bite_sweep' ? r.sweep_arc * 0.5 : id === 'wind_blades' ? r.blade_spread * 0.5 : 0), dt, separated);
    if (['bite_thrust', 'thunder_headbutt'].includes(id) && !separated) n.length = moveToward(n.length, r.neck_rest * 0.4, r.neck_rest * dt * 2);
    if (!separated) n.pos = add(base, mul(fromA(n.angle), n.length));
    if (id === 'beam_fixed') { if (!n.effect) n.effect = hEffect(S, 'beam', [n.pos, add(n.pos, mul(fromA(n.angle), r.beam_len))], r.beam_width, charge - t, r.beam_time); else n.effect.points = [n.pos, add(n.pos, mul(fromA(n.angle), r.beam_len))]; }
    if (id === 'thunder_drop' && !n.effect) n.effect = hEffect(S, 'lightning', [n.target, n.target], r.thunder_radius * 2, charge - t, r.thunder_flash);
    return;
  }
  if (!n.locked) { n.locked = true; n.from = { ...n.pos }; n.sweep = angOf(sub(n.target, ['bite_sweep'].includes(id) && !separated ? base : n.pos));
    if (id === 'beam_bolt') hEffect(S, 'bolt', [n.pos, add(n.pos, mul(fromA(n.angle), r.bolt_length))], r.bolt_width, 0, r.bolt_life, mul(fromA(n.angle), r.bolt_speed));
    if (['rubble_lump', 'rubble_fan'].includes(id)) { const count = id === 'rubble_lump' ? 1 : r.rubble_count; for (let i = 0; i < count; i++) hShot(S, n, n.angle + (count > 1 ? r.rubble_spread * (i / (count - 1) - 0.5) : 0), count > 1 ? r.rubble_small_radius : r.lump_r); }
    if (id === 'wind_band') n.effect = hEffect(S, 'wind', [n.pos, add(n.pos, mul(fromA(n.angle), r.wind_length))], r.wind_width, 0, r.wind_time);
  }
  let duration = 0;
  if (['bite_thrust', 'thunder_headbutt', 'bite_sweep'].includes(id)) {
    const flight = id === 'bite_sweep' ? r.sweep_time : r.normal_lunge, f = clamp(elapsed / flight);
    if (id === 'bite_sweep') { n.angle = n.sweep + r.sweep_arc * (f - 0.5); n.pos = add(separated ? n.from : base, mul(fromA(n.angle), r.sweep_reach)); }
    else { n.pos = lerpV(n.from, n.target, f); n.angle = angOf(sub(n.target, n.from)); }
    if (elapsed < flight) hEffect(S, 'bite', [before, n.pos], r.bite_radius, 0, 0.1);
    if (id === 'thunder_headbutt' && f >= 1 && !n.thunder) { n.thunder = true; hEffect(S, 'lightning', [n.pos, n.pos], r.thunder_radius * 2, 0, r.thunder_flash); }
    duration = flight + (separated && id === 'thunder_headbutt' ? r.thunder_flash : 0);
  } else if (id === 'wind_blades') {
    while (n.step < 3 && elapsed >= n.step * r.blade_interval) { const a = n.sweep + (n.step * 0.5 - 0.5) * r.blade_spread, points = []; for (let i = 0; i <= 12; i++) { const angle = -Math.PI / 2 + Math.PI * i / 12; points.push(add(n.from, rotateV(V(Math.cos(angle) * r.blade_size * 0.6, Math.sin(angle) * r.blade_size), a))); } hEffect(S, 'wind_blade', points, r.blade_width, 0, r.blade_life, mul(fromA(a), r.blade_speed)); n.angle = a; n.step++; } duration = 2 * r.blade_interval;
  } else if (id === 'beam_fixed') duration = r.beam_time;
  else if (id === 'wind_band') duration = r.wind_time;
  else if (id === 'thunder_drop') duration = r.thunder_flash;
  if (separated && n.effect && ['beam_fixed', 'wind_band'].includes(id)) { const length = id === 'beam_fixed' ? r.beam_len : r.wind_length; n.effect.points = [n.pos, add(n.pos, mul(fromA(n.angle), length))]; }
  if (elapsed >= duration + r.normal_hold) { n.active = false; S.B.mode = 'recovery'; if (!S.finished) S.finished = S.t; }
}
function hCombo(S, dt) {
  const r = S.r, id = S.tech, t = S.age - r.warning_time, parts = S.participants;
  for (const n of parts) n.glow = S.age < r.warning_time ? clamp(S.age / r.warning_time) : 0;
  if (id === 'north') {
    if (S.age < r.north_lock_time) { const dir = norm(sub(S.ship.pos, S.B.pos)), side = orth(dir), center = add(S.B.pos, mul(dir, Math.max(dist(S.ship.pos, S.B.pos), S.B.r + HP.neck_rest))), sorted = parts.slice().sort((a, b) => hBase(S, a).x * side.x + hBase(S, a).y * side.y - hBase(S, b).x * side.x - hBase(S, b).y * side.y); sorted.forEach((n, i) => n.target = add(center, mul(side, r.north_spread * (i - 1)))); }
    if (t >= 0) for (const n of parts) { if (!n.locked) { n.locked = true; n.from = { ...n.pos }; n.angle = angOf(sub(n.target, n.from)); } const before = n.pos; n.pos = lerpV(n.from, n.target, clamp(t / r.north_flight)); if (t < r.north_flight) hEffect(S, 'bite', [before, n.pos], r.bite_radius * 2, 0, dt + 0.001); }
  }
  if (t < 0) return;
  S.B.mode = 'active';
  if (['sequence', 'swarm'].includes(id)) parts.forEach((n, i) => { const local = t - i * (id === 'sequence' ? r.sequence_gap : r.swarm_gap); if (local < 0) return; if (!n.locked && id === 'sequence') n.target = { ...S.ship.pos }; n.glow = clamp(local / r.sequence_charge);
    if (local >= r.sequence_charge) { if (!n.locked) { n.locked = true; n.from = { ...n.pos }; n.angle = angOf(sub(n.target, n.pos)); } const f = clamp((local - r.sequence_charge) / (id === 'sequence' ? r.normal_lunge : r.swarm_flight)), before = n.pos; n.pos = lerpV(n.from, n.target, f); if (f < 1) hEffect(S, 'bite', [before, n.pos], r.bite_radius * (id === 'sequence' ? 2 : 1), 0, dt + 0.001); }
  });
  if (id === 'beam_pincer') parts.forEach((n, i) => { if (n.aim == null) n.aim = angOf(sub(S.ship.pos, n.pos)); n.angle = n.aim + (i === 0 ? 1 : -1) * lerp(r.pincer_open_angle, r.pincer_close_angle, clamp((t - r.pincer_delay) / r.pincer_time)); const points = [n.pos, add(n.pos, mul(fromA(n.angle), r.beam_len))]; if (!n.effect) n.effect = hEffect(S, 'beam', points, r.beam_width, r.pincer_delay, r.pincer_time); else n.effect.points = points; });
  if (id === 'curve') { S.B.facing += r.curve_turn * dt; for (const n of parts) { n.angle = n.baseAngle + S.B.facing; n.pos = add(hBase(S, n), mul(fromA(n.angle), r.neck_rest)); const points = [n.pos]; let at = n.pos; for (let j = 1; j <= 24; j++) { at = add(at, mul(fromA(n.angle - j / 24 * r.curve_lag), r.beam_len / 24)); points.push(at); } if (!n.effect) n.effect = hEffect(S, 'beam', points, r.beam_width, r.curve_delay, r.curve_time); else n.effect.points = points; if (t >= r.curve_time) n.effect.life = 0; } }
  if (id === 'grid') parts.forEach((n, i) => { const target = add(S.gridOrigin, HP.grid_layouts.provisional.slots[i].to); n.angle = angOf(sub(target, n.pos)); if (!n.effect) n.effect = hEffect(S, 'beam', [n.pos, target], r.beam_width, r.normal_charge, r.grid_time); });
  if (id === 'tornado') {
    const wind = parts[0], debris = parts[1];
    if (!S.vortex) { const dir = norm(sub(S.ship.pos, wind.pos)); S.vortex = { center: add(wind.pos, mul(dir, 120)), dir }; wind.angle = angOf(dir); debris.angle = angOf(sub(S.vortex.center, debris.pos)); }
    const v = S.vortex;
    if (t < r.tornado_charge) { v.feed = []; const side = orth(norm(sub(v.center, debris.from))); for (let j = 0; j < 3; j++) { const progress = clamp((t - r.tornado_charge * (0.25 + j * 0.12) / 1.2) / (r.tornado_charge * 0.65 / 1.2)); v.feed.push({ pos: add(lerpV(debris.from, v.center, progress), mul(side, Math.sin(progress * Math.PI) * (60 + j * 35))), radius: (26 + j * 6) * (1 - progress * 0.7) }); } }
    else { v.feed = []; if (!v.effect) v.effect = hEffect(S, 'tornado', [sub(v.center, mul(v.dir, 45)), add(v.center, mul(v.dir, 45))], r.tornado_width, 0, r.tornado_life, mul(v.dir, r.tornado_speed)); }
  }
  if (id === 'debris_shatter') {
    const debris = parts[0], beam = parts[1]; if (!S.rocks) { S.rocks = []; S.shatterAim = angOf(sub(S.ship.pos, beam.pos)); for (let j = 0; j < r.rubble_count; j++) S.rocks.push({ from: { ...debris.pos }, to: add(beam.pos, mul(fromA(S.shatterAim + (j / Math.max(1, r.rubble_count - 1) - 0.5) * 1.4), 420)), radius: 22, seed: j }); }
    for (const q of S.rocks) q.pos = lerpV(q.from, q.to, clamp(t / r.shatter_deploy));
    if (t >= r.shatter_deploy && t < r.shatter_deploy + r.shatter_time) { beam.angle = S.shatterAim - r.shatter_arc * 0.5 + r.shatter_arc * clamp((t - r.shatter_deploy) / r.shatter_time); const points = [beam.pos, add(beam.pos, mul(fromA(beam.angle), r.beam_len))]; if (!beam.effect) beam.effect = hEffect(S, 'beam', points, r.beam_width, 0, r.shatter_time); else beam.effect.points = points;
      for (const q of S.rocks) { const v = sub(points[1], points[0]), f = clamp(((q.pos.x - points[0].x) * v.x + (q.pos.y - points[0].y) * v.y) / Math.max(1, len(v) ** 2)); if (!q.dead && dist(q.pos, add(points[0], mul(v, f))) <= q.radius + r.beam_width * 0.5) { q.dead = true; const a = angOf(sub(q.pos, beam.pos)); for (let k = 0; k < 6; k++) S.projectiles.push({ pos: { ...q.pos }, vel: mul(fromA(a + (k - 2.5) * 0.45), r.shard_speed), radius: 5, t: S.t, life: 3, kind: 'shard', seed: k }); } }
    }
  }
  if (S.age >= r.warning_time + Math.max(r.performance_time, r.north_flight || 0)) { S.B.mode = 'recovery'; if (!S.finished) { S.finished = S.t; for (const n of parts) n.active = false; } }
}
function hStep(S, dt) {
  const r = S.r, id = S.tech;
  S.ship.pos.y = Math.sin(S.t * 0.5) * 70;
  if (S.positioning) { let ready = true; S.participants.forEach((n, i) => { const goal = S.slots[i]; hSnakeSteer(n, goal, dt, 1.8); if (dist(n.pos, goal) > (id === 'grid' ? HP.grid_tolerance : HP.formation_tolerance)) ready = false; hChain(S, n, dt); });
    if (ready) { S.positioning = false; S.age = -0.5; for (const n of S.participants) { n.from = { ...n.pos }; n.target = add(n.pos, mul(norm(sub(S.ship.pos, n.pos)), r.swarm_reach)); } } return;
  }
  S.age += dt; if (S.age < 0) return;
  if (id === 'visibility') { S.B.mode = 'active'; for (let i = 0; i < S.necks.length; i++) { const n = S.necks[i], target = add(S.ship.pos, rotateV(V(280 + i * 10, Math.sin(S.t + i) * 40), i * TAU / 8 + S.t * 0.15)); hSnakeSteer(n, target, dt, 0.8); } }
  else if (id === 'destroy') { const n = S.necks[0]; if (S.age >= 0.8 && !S.destroyed) { S.destroyed = { at: { ...n.pos }, t: S.t, angle: n.angle }; n.dead = true; S.B.mode = 'recovery'; } }
  else if (S.combo && !S.finished) hCombo(S, dt);
  else if (!S.combo && !S.finished) hNormal(S, S.participants[0], dt);
  for (const n of S.necks) {
    if (!n.active && !S.separated && !n.dead) { const base = hBase(S, n), facing = n.baseAngle + S.B.facing, offset = sub(S.ship.pos, base), f = fromA(facing), local = Math.atan2(offset.x * -f.y + offset.y * f.x, Math.max(HP.aim_deadzone, offset.x * f.x + offset.y * f.y)); hAim(n, facing + clamp(local, -0.8, 0.8) + Math.sin(S.t + n.baseAngle) * 0.06, dt, false); n.length = moveToward(n.length, HP.neck_rest, HP.neck_rest * dt); n.pos = add(base, mul(fromA(n.angle), n.length)); }
    hChain(S, n, dt);
    // 溜め終盤だけ描画用の節を保持する。攻撃の状態・首の計算には使わない。
    const visualPhase = hPose(S, n);
    if (visualPhase.charge >= 0.55 && !n.visualBrace) n.visualBrace = n.points.map(p => ({ ...p }));
  }
  for (const e of S.effects) if (S.t - e.t >= e.delay) e.points = e.points.map(p => add(p, mul(e.vel, dt)));
  S.effects = S.effects.filter(e => S.t - e.t < e.delay + e.life);
  for (const q of S.projectiles) q.pos = add(q.pos, mul(q.vel, dt)); S.projectiles = S.projectiles.filter(q => S.t - q.t < q.life);
  if (S.finished && S.t > S.finished + (r.tech_recovery || 0.9)) S.B.mode = 'idle';
}
function hEnergyCurrent(R, e, warning, time) {
  const tint = ({ beam: '#ff4066', bolt: '#ff4066', wind: '#40e6bf', wind_blade: '#4dffcc', bite: '#ff732e', rubble: '#8c704c' })[e.kind] || '#77bbff', color = parseCol(tint);
  for (let s = 1; s < e.points.length; s++) { const A = toL(e.points[s - 1]), B = toL(e.points[s]), u = norm(sub(B, A)), side = orth(u), L = dist(A, B), width = Math.max(1, e.width * WL), span = Math.max(1, dist(e.points[s - 1], e.points[s]));
    for (let d = 0; d <= L; d++) { const center = add(A, mul(u, d)); if (center.x < -width || center.x > LW + width || center.y < -width || center.y > LH + width) continue;
      for (let q = -width * 0.5; q <= width * 0.5; q++) { const uvx = d / Math.max(1, L), uvy = q / width + 0.5, edge = Math.abs(uvy - 0.5) * 2, grain = hash(Math.floor(d) * 13 + Math.floor(q) * 41 + Math.floor(time * 14)), flow = Math.sin(uvx * 45 - time * 10 + uvy * 4) * 0.5 + 0.5; if (edge > 0.95 - grain * 0.1) continue;
        let c = color, alpha = 0.45, light = 0.7 + flow * 0.6, core = edge <= 0.22 + flow * 0.14;
        if (warning) { const mark = (uvx * span / 28 - time * 1.5) % 1 > 0.45; alpha = edge >= 0.65 ? 0.26 + (mark ? 0.4 : 0) : 0.08; c = lighten(color, 0.5); light = 1; core = false; }
        else if (e.kind.startsWith('wind')) { const streak = Math.max(0, Math.sin(uvx * span / 45 - time * 13 + Math.sin(uvy * 16) * 2)) ** 10; alpha = 0.16 + streak * 0.7; light = 0.7 + streak * 1.4; core = streak > 0.7; }
        else alpha = core ? 1 : 0.45;
        const at = add(center, mul(side, q)), ink = hexc(toHex({ r: c.r * light + (core ? 1.2 : 0), g: c.g * light + (core ? 1.2 : 0), b: c.b * light + (core ? 1.2 : 0) })); R.front.blend(at.x, at.y, ink, alpha);
      }
    }
  }
}
function hLightning(S, R, e, warning) {
  const center = e.points[0], A = toL(center), radius = e.width * 0.5, C = voltRamp(R.P.color), age = S.t - e.t - e.delay, tick = Math.floor(S.t * 24);
  if (!R.proto) { const rr = radius * WL, c = parseCol('#66bfff'); for (let y = -rr; y <= rr; y++) for (let x = -rr; x <= rr; x++) { const r = Math.hypot(x, y) / rr; if (r > 1) continue; const a = Math.atan2(y, x), stagger = hash(Math.floor(r * 14) + tick) * 0.8, branch = Math.abs(Math.cos(a * 5 + stagger)) ** 28, halo = Math.abs(Math.cos(a * 5 + stagger)) ** 8, ring = r > 0.9; const alpha = warning ? 0.06 + (ring ? 0.6 : 0) : 0.06 + halo * 0.2 + branch * 0.75 + (r < 0.14 ? 0.8 : 0) + (ring ? 0.3 : 0); R.front.blend(A.x + x, A.y + y, hexc(branch > 0.5 ? '#fff' : '#66bfff'), alpha); } return; }
  const paths = [];
  for (let i = 0; i < (warning ? 4 : 11); i++) { const a = hash(i * 17 + tick * 3) * TAU, end = add(A, mul(fromA(a), radius * WL * (0.5 + hash(i + tick) * 0.5))); if (warning) { const from = lerpV(A, end, 0.65); paths.push(...zigzag(new PX.Rng(i * 31 + tick + 1), from.x, from.y, end.x, end.y, 0.3, 0.15, 0.5)); } else paths.push(...zigzag(new PX.Rng(i * 31 + tick + 1), A.x, A.y, end.x, end.y, 0.3, 0.5)); }
  voltInk(R.front, paths, warning ? 0.35 : 1 - clamp(age / e.life) * 0.5, C, R.P.size, warning, R.P.intensity * 0.4);
}
function hReleaseParticles(R, mouth, direction, age, seed, power = 1) {
  if (age < 0 || age > 0.3) return;
  const random = new PX.Rng(seed), ps = new PX.Particles({ rng: random, ground: () => 10000 }), pal = FX.ramp(R.P.color);
  for (let i = 0; i < 9; i++) {
    const a = random.range(-0.36, 0.36), speed = random.range(30, 68) * power;
    ps.spawn(PX.P.MOTE, 0, 0, Math.cos(a) * speed, Math.sin(a) * speed, random.range(0.12, 0.26), pal[2 + i % 2], random.range(0.6, 1.1));
  }
  let t = 0; while (t < age) { const dt = Math.min(1 / 60, age - t); ps.update(dt); t += dt; }
  const p = new PX.Painter(FR.front), at = toL(mouth); p.place(at.x, at.y, false, direction); p.lightK = R.P.intensity * 0.4; ps.draw(p);
}
function hDrawEffect(S, R, e) {
  const age = S.t - e.t, warning = age < e.delay, on = age - e.delay, P = R.P;
  if (e.kind === 'lightning') return hLightning(S, R, e, warning);
  if (!R.proto && e.kind !== 'tornado') return hEnergyCurrent(R, e, warning, S.t);
  if (e.kind === 'tornado') {
    const center = lerpV(e.points[0], e.points[1], 0.5), L = toL(center), rad = e.width * 0.5, pal = FX.ramp(R.proto ? P.color : '#4dd9b8');
    if (R.proto) {
      const fade = clamp(on / 0.07 + 0.2) * clamp((e.life - on) / 0.23);
      // 原本の風の塊をそのまま重ねる。細切れに曲げて輪郭の輪を作らない。
      g.save(); g.globalCompositeOperation = 'screen'; g.filter = 'brightness(2.1) saturate(1.5)';
      for (let i = 0; i < 3; i++) {
        const a = i * 2.3 - on * 6, at = add(center, V(Math.cos(a) * rad * 0.26, Math.sin(a) * rad * 0.18));
        const direction = a + Math.PI * 0.62, start = sub(at, mul(fromA(direction), rad * 0.5));
        hWindAtlas(S, R, start, direction, e.width * 0.82, e.width * 1.12, Math.max(0, on), e.life, fade, true);
      }
      g.restore();
    } else {
      for (let i = 0; i < 100; i++) { const phase = (S.t * (0.8 + hash(i) * 0.6) + hash(i * 7)) % 1, a = S.t * 12 + i * 2.4, r = rad * WL * (0.2 + phase * 0.8), x = L.x + Math.cos(a) * r, y = L.y + Math.sin(a) * r * 0.7 - phase * rad * WL; R.front.glow(x, y, 1.5, pal[2], (1 - phase) * 0.15 * P.intensity); if (i % 4 === 0) R.front.px(x, y, pal[2]); }
    }
    for (let i = 0; i < 4; i++) { const a = S.t * 8 + i * 2.4, at = add(center, V(Math.cos(a) * e.width * 0.25, Math.sin(a) * e.width * 0.15)); drawImg('meteor_0', at, a, 13 + i * 2); } return;
  }

  const source = S.necks[e.source], points = e.points.map(p => ({ ...p }));
  if (e.kind === 'bolt' || e.kind === 'wind_blade') for (const p of points) { p.x += e.mouthOffset?.x || 0; p.y += e.mouthOffset?.y || 0; }
  else if (source && ['beam', 'wind'].includes(e.kind)) points[0] = hMouth(S, source);
  if (warning) return; // 予告は頭ごとの段階に合わせ、一度だけ口へ集める。
  if (['beam', 'bolt'].includes(e.kind)) {
    const fade = clamp(1 - smooth(Math.max(0, e.life - 0.12), e.life, on)), burst = Math.exp(-on / 0.075);
    for (let i = 1; i < points.length; i++) FXW.beam(R.front, points[i - 1], points[i], { w: e.width * (0.42 + 0.12 * burst) * P.size, color: P.color, time: S.t, alpha: fade, intensity: P.intensity, taper: i === points.length - 1 ? Math.min(5, dist(points[i - 1], points[i]) * WL * 0.3) : 0, source: false });

  } else if (e.kind === 'bite') {
    // 噛みつきは首が主役。毎フレーム新しい息を重ねず、口の短い粒だけにする。
    return;
  } else if (e.kind === 'wind_blade') {
    const melee = PIXELFX.fx['src/fx/melee/_lib.js'], center = lerpV(points[0], points[points.length - 1], 0.5), front = points[Math.floor(points.length / 2)];
    const A = toL(center), radius = dist(points[0], points[points.length - 1]) * WL * 0.5, broad = dist(center, front) * WL;
    const p = new PX.Painter(FR.front), pal = FX.ramp(P.color);
    // 原本slashに一続きの楕円弧を渡し、区間ごとの継ぎ目と明滅をなくす。
    const swing = melee.swing({ cx: A.x, cy: A.y, R: radius, sy: broad / Math.max(0.1, radius), rot: angOf(sub(front, center)) + Math.PI / 2, a0: -Math.PI, dir: 1, span: Math.PI,
      W: e.width * WL * P.size * 1.25, t0: -0.06, sweep: 0.06, hold: Math.max(0.01, e.life - 0.24), trail: 0.24, ramp: pal, lens: true, hot: Math.exp(-on / 0.08) * 0.35 });
    p.lightK = P.intensity * 0.55; melee.slash(p, swing, on);
    // 原本のshavingsで刃から不揃いの切れ端を飛ばす。弾や判定は増やさない。
    const random = new PX.Rng(e.seed + 61), dust = new PX.Particles({ rng: random, ground: () => 10000 });
    melee.shavings(dust, random, swing, 13, [pal[1], pal[2], pal[3]]);
    let elapsed = 0; while (elapsed < on) { const dt = Math.min(1 / 60, on - elapsed); dust.update(dt); elapsed += dt; }
    dust.draw(p);
  } else if (e.kind === 'wind') {
    const mouth = points[0], end = points[points.length - 1], direction = angOf(sub(end, mouth));
    hWindAtlas(S, R, mouth, direction, dist(mouth, end), e.width * 1.2 * P.size, on, e.life, Math.min(1, 0.75 + P.intensity * 0.25));
  }

}
function hDraw(S, R) {
  R = bossView(R, '#80baff');
  const P = R.P;
  for (const e of S.effects) if (!R.proto || e.kind !== 'tornado') hDrawEffect(S, R, e);
  if (S.vortex?.feed) for (const q of S.vortex.feed) { if (R.proto) { const debris = S.participants[1], fraction = clamp(dist(q.pos, S.vortex.center) / Math.max(1, dist(debris.from, S.vortex.center))), at = add(q.pos, mul(hMouthOffset(S, debris), fraction)); drawImg('meteor_0', at, S.t * 2, q.radius); } else D2.circle(q.pos, q.radius, '#8c704c'); }
  if (S.rocks) for (const q of S.rocks) if (!q.dead) { if (R.proto) { const fraction = 1 - clamp((S.age - S.r.warning_time) / S.r.shatter_deploy), at = add(q.pos, mul(hMouthOffset(S, S.participants[0]), fraction)); drawImg('meteor_0', at, q.seed, q.radius); } else D2.circle(q.pos, q.radius, '#8c704c'); }
  for (const q of S.projectiles) { if (R.proto) { const visualPos = add(q.pos, q.mouthOffset || V(0, 0)), tail = [sub(visualPos, mul(norm(q.vel), 55)), visualPos]; bossTrail(R, tail); drawImg('meteor_0', visualPos, q.seed + S.t * (q.kind === 'shard' ? 5 : 1), q.radius); } else D2.circle(q.pos, q.radius, q.kind === 'shard' ? '#ffd16c' : '#8c704c'); }
  R.blitBack(); hDrawBody(S, R);
  if (R.proto && S.vortex && S.tech === 'tornado') {
    const local = S.age - S.r.warning_time, wind = S.participants[0], mouth = hMouth(S, wind);
    if (local >= 0 && local < S.r.tornado_charge) {
      g.save(); g.globalCompositeOperation = 'screen'; g.filter = 'brightness(1.8) saturate(1.5)';
      hWindAtlas(S, R, mouth, angOf(sub(S.vortex.center, mouth)), dist(mouth, S.vortex.center), 94, local, S.r.tornado_charge, 1);
      g.restore();
    }
    for (const e of S.effects) if (e.kind === 'tornado') hDrawEffect(S, R, e);
  }
  if (R.proto) for (const n of S.participants) { hDrawCharge(S, R, n); const pose = hPose(S, n); if (pose.release >= 0 && pose.release < 0.3) hReleaseParticles(R, hMouth(S, n), n.angle, pose.release, S.necks.indexOf(n) + 73, n.kind === 'bite' ? 0.45 : 0.8); }
  if (S.destroyed) { const e = S.destroyed, age = (S.t - e.t) / P.timing;
    if (R.proto && age < 0.55) {
      // 元の頭の絵を、その場でマスごとに消す。破片や別の絵へ置き換えない。
      const im = IMG['hydra/head0'], factor = S.B.r * 2 / HYDRA.body_source_width, step = 6, halfW = im.width * factor * 0.5, halfH = im.height * factor * 0.5;
      g.save(); g.translate(e.at.x, e.at.y); g.rotate(e.angle - Math.PI / 2); g.beginPath();
      for (let y = -halfH; y < halfH; y += step) for (let x = -halfW; x < halfW; x += step) if (hash(Math.floor(x / step) * 17 + Math.floor(y / step) * 71) > age / 0.55) g.rect(x, y, step, step);
      g.clip(); g.drawImage(im, -halfW, -halfH, halfW * 2, halfH * 2); g.restore();
    }
    if (R.proto && age < 0.65) { const pal = FX.ramp(P.color), A = toL(e.at); for (let i = 0; i < 40; i++) { const a = hash(i * 13) * TAU, d = Math.sqrt(Math.max(0, age)) * (3 + hash(i) * 12) * P.size, q = add(A, mul(fromA(a), d)); if (hash(i * 7) > age / 0.65) { R.front.px(q.x, q.y, pal[age < 0.08 ? 4 : 1]); R.front.glow(q.x, q.y, 3, pal[2], (1 - age / 0.65) * 0.2 * P.intensity); } } }
    else if (!R.proto && age < 0.3) { D2.circle(e.at, age * 140, rgba('#ffd16c', 1 - age / 0.3)); }
  }
  drawShip(S.ship);
}
for (const id of [...Object.keys(H_IDS), 'destroy', 'visibility']) {
  const r = hRule(id === 'destroy' || id === 'visibility' ? 'bite_thrust' : id);
  DEMOS.push({ id: 'H-' + id, ids: H_IDS[id] || (id === 'destroy' ? ['H03'] : ['H02', 'H20']), cat: 'うみへび座（H）', group: 'うみへび座', title: id === 'destroy' ? '首の撃破' : id === 'visibility' ? '分離後の首・胴・頭の見え方' : r.display_name, duration: ['grid', 'swarm'].includes(id) ? 16 : id === 'visibility' ? 7 : Math.max(5, (r.warning_time || 0) + (r.performance_time || 0) + 2.5), color: r.head_kind === 'thunder' ? '#80baff' : r.head_kind === 'vortex' || id === 'tornado' ? '#70dfce' : '#ef78ad',
    params: [{ k: 'separated', label: '分離後の体（0／1）', type: 'range', min: 0, max: 1, step: 1, def: 0 }, { k: 'neckDark', label: '首の明るさ', type: 'range', min: 0.35, max: 1.2, step: 0.01, def: 0.72 }],
    status: { '状態': '独立HTMLの試作（未承認）。本番への組み込みはC++移行後', '全身': '現行の頭・胴・首の節を使用。つながった首のFABRIKと分離後の経路追従を移植。照明・現行shaderはHTMLで近似', '判定・動作': '技の時刻・速度・軌道・範囲は現行値。障害物のない単独比較場面。群れのAIによる自然選択・回避・地形干渉は対象外', '未決・保留': id === 'grid' ? '現行の仮格子配置を使用。正式な5配置は未決のまま' : id === 'visibility' ? '分離後の見えにくさの原因は断定しない。首の明るさだけを比較する。群れの戦い方・配置仕様は変更しない' : 'H22のULTは対象未特定。H05の実験場不具合、H09・H21等の本番ロジック変更は保留' },
    refs: ['scenes/bosses/hydra_boss.tscn・hydra_neck_art.tscn（現行の画像）', 'scripts/bosses/hydra_neck.gd・hydra_snake_motion.gd・hydra_neck_art.gd（首と全身）', 'data/bosses/hydra_moves/' + (id === 'destroy' || id === 'visibility' ? 'bite_thrust' : id) + '.tres', 'scripts/bosses/hydra/techniques/*.gd・normal_swim.gd・hydra_boss.gd（技進行）', 'shaders/hydra_energy.gdshader・hydra_area.gdshader（現行表示の近似）', 'pixelFX ice/frost-breath の原本atlas（配色だけ変更）、melee/_lib.js の連続斬撃、lightning のzigzag・voltInk、現行meteor画像を使用'],
    setup(S) { hSetup(S, id); }, step: hStep, draw: hDraw, phase: hPhase
  });
}
