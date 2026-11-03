// 角とブースター・槍は現行の描き方を保存し、位置の接続だけを合わせる。
function monoOriginalBooster(S, rig) {
  const B = S.B, k = B.r / 96, mat = rig.mats['TailBooster/Sprite/booster']; if (!mat) return;
  const world = M.pt(mat, V(37, 0)), anchor = mul(rotateV(sub(world, B.pos), -B.facing), 1 / k);
  const strength = S.stage === 'gather' && S.tech === 'lance' ? 0.55 + 0.45 * S.form : S.stage === 'run' ? S.tech === 'lance' ? 3.5 : 2.5 : S.stage === 'stop' && S.tech === 'lance' ? 1 : 0.55;
  const length = (50 + Math.sin(S.t * 27) * 9) * strength, rootAngle = S.tailAngle - B.facing + Math.PI, tipAngle = (S.flameAngle ?? S.tailAngle) - B.facing + Math.PI;
  g.save(); g.translate(B.pos.x, B.pos.y); g.rotate(B.facing); g.scale(k, k);
  for (let layer = 0; layer < 3; layer++) { const factor = 1 - layer * 0.24; let center = { ...anchor }; g.fillStyle = ['#245c96', '#61c9ff', '#e0fbff'][layer];
    for (let j = 0; j < 12; j++) { const t = j / 12, height = Math.max(3, (24 - t * 22) * factor), direction = fromA(rootAngle + angDiff(tipAngle, rootAngle) * t * t), next = add(center, mul(direction, length * factor / 12)), side = orth(direction), wobble = mul(side, Math.sin(S.t * 20 - t * 8) * 7 * t * factor), thickness = V(Math.abs(side.x) * height, Math.abs(side.y) * height);
      const at = add(V(Math.min(center.x, next.x), Math.min(center.y, next.y)), sub(wobble, mul(thickness, 0.5))), size = add(V(Math.abs(next.x - center.x), Math.abs(next.y - center.y)), thickness);
      g.fillRect(Math.round(at.x / 3) * 3, Math.round(at.y / 3) * 3, Math.max(3, Math.round(size.x / 3) * 3), Math.max(3, Math.round(size.y / 3) * 3)); center = next;
    }
  } g.restore();
}
function monoOriginalLance(S, rig) {
  const form = S.form, r = S.r, a = add(S.B.pos, mul(rig.hornAxis, S.B.r * 0.65)), horn = rig.hornTip, axis = rig.hornAxis, tip = add(horn, mul(axis, r.head_length * form)), side = mul(orth(axis), 18 * form);
  D2.line(a, horn, '#f2b567', 12 + 28 * form); D2.line(a, horn, '#fff', 7 + 5 * form);
  D2.poly([tip, add(horn, side), sub(horn, mul(axis, r.head_length * form * 0.35)), sub(horn, side)], '#fff7df');
}
function monoKickPose(S, edits) {
  const active = S.B.mode === 'active', recover = S.B.mode === 'recovery', wait = S.B.mode === 'windup';
  const fold = wait ? smooth(0.1, S.r.warn * 0.65, S.st) : active || recover ? 1 : 0;
  const kick = active ? smooth(0, S.r.active * 0.32, S.st) : recover ? 1 - smooth(S.r.hold, S.r.hold + 0.32, S.st) : 0;
  const settle = recover ? 1 - smooth(S.r.hold, S.r.hold + 0.32, S.st) : 1;
  for (const [i, path] of ['RearLeftLeg', 'RearRightLeg'].entries()) {
    const foot = MONO.nodes.find(n => n.name === 'Foot' && n.parent === path), rest = foot.position;
    // 足先は後方へまっすぐ押し出す。元絵を回転・引き伸ばしして振り回さない。
    edits[path] = { rotation: (i ? 1 : -1) * fold * settle * 0.045, scale: V(1, 1) };
    edits[path + '/Foot'] = { position: V(rest.x, rest.y - fold * settle * 12 - kick * 50), rotation: 0 };
  }
  edits.Body = { position: V(0, -37 + fold * settle * 2 - kick * 4) };
}
function monoChargePose(S, edits) {
  if (!['charge', 'return_charge', 'horn_dance'].includes(S.tech)) return;
  const duration = S.tech === 'horn_dance' ? S.r.aim_time : S.r.warn;
  const prepare = S.B.mode === 'windup' && S.stage === 'aim' ? smooth(0, duration * 0.62, S.st) : 0;
  const release = S.stage === 'run' ? (1 - smooth(0.035, 0.14, S.st)) : 0;
  if (prepare <= 0 && release <= 0) return;
  const head = MONO.nodes.find(n => n.name === 'Head'), body = MONO.nodes.find(n => n.name === 'Body');
  edits.Head.position = add(head.position, V(0, -prepare * 5 + release * 3));
  edits.Body = { position: add(body.position, V(0, -prepare * 2 + release * 2)) };
  for (const path of ['FrontLeftLeg', 'FrontRightLeg']) {
    const foot = MONO.nodes.find(n => n.name === 'Foot' && n.parent === path);
    edits[path + '/Foot'].position = add(foot.position, V(0, -prepare * 7 + release * 3));
  }
}
function monoPressureWave(S, R, wave, radius) {
  const center = toL(wave.center), half = S.r.wave_half_angle, r = radius * WL;
  const fade = 1 - smooth(S.r.wave_max * 0.45, S.r.wave_max, radius), width = Math.max(2.2, S.r.wave_width * WL * 1.05) * R.P.size;
  const p = R.front, dust = PIXELFX.fx['src/fx/impacts/_lib.js'].dustRing;
  p.place(center.x, center.y, false, wave.a);
  // pixelFX の柔らかい圧力環を前方だけに使う。面の内側を透かし、両端は空気へほどく。
  const pressure = { blend(x, y, color, alpha) {
    const edge = 1 - smooth(half * 0.55, half, Math.abs(Math.atan2(y, x)));
    if (edge > 0) p.blend(x, y, color, alpha * edge);
  } };
  const phase = wave.t * 7.3 + (S.t - wave.t) * 2.1;
  dust(pressure, 0, 0, Math.max(1, r - width * 1.8), width * 2.1, fade * 0.17, hexc('#b7b9a6'), { ph: phase + 1.3, brk: 0.38, lit: 0.1 });
  dust(pressure, 0, 0, r, width, fade * 0.78, hexc('#e9dfbc'), { ph: phase, brk: (1 - fade) * 0.3, lit: 0.22 });
  p.place(0, 0);
  if (wave.air) { p.place(LW / 2 - cam.x * WL, LH / 2 - cam.y * WL); wave.air.draw(p); p.place(0, 0); }
}
function monoWaveAir(S, dt) {
  if (mode !== 'proto' || S.tech !== 'horn_wave' || dt <= 0) return;
  for (const [index, wave] of S.waves.entries()) {
    if (!wave.air) { const rng = new PX.Rng(817 + index); wave.air = new PX.Particles({ rng }); wave.airEmit = 0; }
    const radius = S.r.wave_start + (S.t - wave.t) * S.r.wave_speed;
    if (radius < S.r.wave_max * 0.82) {
      wave.airEmit += dt * 36;
      while (wave.airEmit >= 1) { wave.airEmit--; const rng = wave.air.R, angle = wave.a + rng.range(-S.r.wave_half_angle, S.r.wave_half_angle), point = add(wave.center, mul(fromA(angle), radius)), velocity = mul(fromA(angle), S.r.wave_speed * rng.range(0.08, 0.2) * WL); wave.air.spawn(PX.P.VAPOUR, point.x * WL, point.y * WL, velocity.x, velocity.y, rng.range(0.16, 0.3), hexc('#c6ccbf'), rng.range(1.5, 3.3)); }
    }
    wave.air.update(dt);
  }
}
function monoChargeTell(S, R, rig) {
  const duration = S.tech === 'horn_dance' ? S.r.aim_time : S.r.warn, charge = smooth(0, duration * 0.62, S.st);
  // 本体を複製しない。踏ん張った足の接地と角先へ光を絞り、最後は止めて見せる。
  for (const path of ['FrontLeftLeg/Foot', 'FrontRightLeg/Foot']) {
    const mat = rig.mats[path]; if (!mat) continue; const point = toL(M.pt(mat, V(0, 0)));
    R.back.glow(point.x, point.y, 2.5, hexc('#d8ae6c'), charge * 0.13);
  }
  const point = toL(rig.hornTip); R.front.glow(point.x, point.y, 3 + charge * 2, hexc('#f4c47a'), charge * 0.18);
}
let MONO_SCORCH = null;
function monoBurntTrail(S, R) {
  if (S.tech !== 'horn_dance' || !S.scorch.length) return;
  if (!MONO_SCORCH) { const R = 5, N = 11, m = new Float32Array(N * N); for (let y = -R; y <= R; y++) for (let x = -R; x <= R; x++) { const q = (x * x / 25 + y * y / 6); if (q < 1 + hash(x * 11 + y * 31) * 0.6) m[(y + R) * N + x + R] = Math.max(0, 1.2 - q) * (0.6 + hash(x * 17 + y) * 0.4); } MONO_SCORCH = { R, N, m }; }
  const before = PHXC; phxColors('#d18a35');
  try { for (const e of S.scorch) { const age = S.t - e.t; if (age > 2.2) continue; const q = toL(e.at); R.back.place(q.x, q.y); phxScorch(R.back, MONO_SCORCH, age, 1 - smooth(1, 2.2, age)); } } finally { R.back.place(0, 0); PHXC = before; }
}
