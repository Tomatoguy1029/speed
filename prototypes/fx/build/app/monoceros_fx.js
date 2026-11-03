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
// 後ろ蹴り：溜めで体重を前へかけて頭を下げ、後ろ脚を体の下へ引き込んで止まる（静）→ 後ろ脚を体の外まで後ろへ一気に突き出し、
// 反動で体が前へ押し出され頭が上がる（動）→ ゆっくり戻る。脚は回転・引き伸ばしせず、位置だけを動かす
function monoKickPose(S, edits) {
  const active = S.B.mode === 'active', recover = S.B.mode === 'recovery', wait = S.B.mode === 'windup';
  const fold = wait ? smooth(0.05, S.r.warn * 0.55, S.st) : 0, kick = active ? smooth(0, S.r.active * 0.25, S.st) : recover ? 1 - smooth(S.r.hold, S.r.hold + 0.45, S.st) : 0;
  for (const [i, path] of ['RearLeftLeg', 'RearRightLeg'].entries()) {
    const foot = MONO.nodes.find(n => n.name === 'Foot' && n.parent === path), rest = foot.position, sd = i ? 1 : -1;
    edits[path] = { rotation: 0, scale: V(1, 1) };
    edits[path + '/Foot'] = { position: V(rest.x + sd * (kick * 7 - fold * 3), rest.y + fold * 14 - kick * 125), rotation: 0 };
  }
  const head = MONO.nodes.find(n => n.name === 'Head');
  edits.Body = { position: V(0, -37 + fold * 6 + kick * 5) };
  if (edits.Head) edits.Head.position = add(head.position, V(0, fold * 4 - kick * 3));
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
// 突進専用の予兆：角は光が集まって光る（炎は出さない）。光の粒がまわりから角へ集まり、溜まるほど角が強く光る。前足が地面を蹴って金の火花が後ろへ散り、
// 尾の噴射口の青い炎が脈打って膨らむ。溜めの最後は動きを止めて見せる（姿勢は monoChargePose）
const MONO_GOLD = ['#ffffff', '#fff3c0', '#ffe08a', '#ffc457', '#f2a03a', '#d8782a', '#a8521e', '#6e3214', '#3a1a0c'];
function monoChargeTell(S, R, rig) {
  const duration = S.tech === 'horn_dance' ? S.r.aim_time : S.r.warn, charge = smooth(0, duration * 0.62, S.st), H = MONO_GOLD.map(hexc);
  const B = S.B, u = fromA(S.angle), tip = toL(rig.hornTip), root = toL(rig.horn), back = V(-u.x, -u.y);
  for (let i = 0; i < 22; i++) { const f = (hash(i * 3.1) + S.t * (0.9 + hash(i) * 0.6)) % 1, a = hash(i * 7.7) * TAU, d = (1 - f) * (14 + 10 * hash(i * 5.3)), on = lerpV(root, tip, hash(i * 2.9)); // 光の粒が角へ集まる
    const x = on.x + Math.cos(a) * d, y = on.y + Math.sin(a) * d; R.front.dot(x, y, f > 0.7 ? H[0] : H[2], charge * (0.3 + 0.7 * f)); }
  for (let s = 0; s <= 1; s += 0.08) { const q = lerpV(root, tip, s); R.front.glow(q.x, q.y, 1.2 + 1.6 * charge, H[2], (0.05 + 0.12 * charge) * (0.6 + 0.4 * s)); } // 角そのものが光る（塊にしない）
  R.front.glow(tip.x, tip.y, 4 + charge * 6, H[3], 0.25 + charge * 0.45);
  for (const path of ['FrontLeftLeg/Foot', 'FrontRightLeg/Foot']) { const mat = rig.mats[path]; if (!mat) continue; const f = toL(M.pt(mat, V(0, 0))); // 前足が地面を蹴る火花
    R.back.glow(f.x, f.y, 3, H[4], charge * 0.35);
    for (let j = 0; j < 5; j++) { const q = new PX.Rng(Math.floor(S.t * 12) * 13 + j + (path.length * 7)), ag = ((S.t * 12) % 1) / 12 + j * 0.02, d = q.range(4, 14) * charge, a = Math.atan2(back.y, back.x) + q.range(-0.6, 0.6), x = f.x + Math.cos(a) * d, y = f.y + Math.sin(a) * d; if (charge > 0.15) R.back.line(x - Math.cos(a) * 2, y - Math.sin(a) * 2, x, y, (w) => w > 0.5 ? H[1] : H[4], charge * (1 - ag * 4)); } }
  const tail = toL(add(B.pos, mul(u, -B.r * 0.95))), pulse = 0.6 + 0.4 * Math.sin(S.t * (12 + 20 * charge)); // 尾の噴射口が脈打って膨らむ
  R.front.glow(tail.x, tail.y, 5 + 9 * charge * pulse, hexc('#6fc4ff'), (0.3 + 0.5 * charge) * pulse); R.front.glow(tail.x, tail.y, 2 + 3 * charge, hexc('#e4f6ff'), 0.6 * charge);
}
let MONO_SCORCH = null;
function monoBurntTrail(S, R) {
  if (S.tech !== 'horn_dance' || !S.scorch.length) return;
  if (!MONO_SCORCH) { const R = 5, N = 11, m = new Float32Array(N * N); for (let y = -R; y <= R; y++) for (let x = -R; x <= R; x++) { const q = (x * x / 25 + y * y / 6); if (q < 1 + hash(x * 11 + y * 31) * 0.6) m[(y + R) * N + x + R] = Math.max(0, 1.2 - q) * (0.6 + hash(x * 17 + y) * 0.4); } MONO_SCORCH = { R, N, m }; }
  const before = PHXC; phxColors('#d18a35');
  try { for (const e of S.scorch) { const age = S.t - e.t; if (age > 2.2) continue; const q = toL(e.at); R.back.place(q.x, q.y); phxScorch(R.back, MONO_SCORCH, age, 1 - smooth(1, 2.2, age)); } } finally { R.back.place(0, 0); PHXC = before; }
}

// 突進中の尾のジェット：予兆で脈打った尾の噴射口から、飛び出す瞬間に強い青い炎を噴く（おおいぬの噴射と同じ作り canisJetStream を使う）
function monoTailJet(S, R) {
  if (S.stage !== 'run' || !['charge', 'return_charge', 'horn_dance', 'lance'].includes(S.tech)) { S.jetT = null; return; }
  S.jetT ??= S.t; const B = S.B, u = fromA(S.angle), age = S.t - S.jetT, burst = 1 + 0.5 * (1 - smooth(0, 0.18, age));
  canisJetStream(R, add(B.pos, mul(u, -B.r * 0.95)), S.angle + Math.PI, B.r * 2.6 * burst * R.P.size, 1.1 * burst, age + 0.3, Infinity, Math.min(1, R.P.intensity), 77);
}
