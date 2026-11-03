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
  const form = S.form, r = S.r, a = rig.horn, horn = rig.hornTip, /* 槍は角の根元から出す（見た目は変えない） */ axis = rig.hornAxis, tip = add(horn, mul(axis, r.head_length * form)), side = mul(orth(axis), 18 * form);
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
// 角の衝撃波：角は光なので、衝撃も光で見せる。先頭は細く明るい白金の帯（両端はとがり、太さはノイズで揺らぐ）、その後ろに外へ押し出される
// 短い光の筋が長さ・明るさばらばらに並ぶ。消えるときは虫食い状に崩れる。判定の弧の範囲と広がる速さは現行のまま
function monoPressureWave(S, R, wave, radius) {
  const L = toL(wave.center), half = S.r.wave_half_angle, r = radius * WL, fade = 1 - smooth(S.r.wave_max * 0.45, S.r.wave_max, radius), H = MONO_GOLD.map(hexc), p = R.front;
  const a0 = wave.a - half, a1 = wave.a + half, w = Math.max(1.2, S.r.wave_width * WL * 0.45) * R.P.size, n = Math.max(16, Math.round((a1 - a0) * r * 1.5)), gone = 1 - fade;
  for (let i = 0; i <= n; i++) { const u = i / n, an = a0 + (a1 - a0) * u, tp = Math.pow(Math.min(1, Math.min(u, 1 - u) / 0.2), 0.8), nz = 0.6 + 0.4 * Math.sin(an * 17 + wave.t * 5) * Math.sin(an * 7 - S.t * 3), ww = w * tp * nz, c = Math.cos(an), sn = Math.sin(an);
    for (let q = -ww; q <= ww; q += 0.5) { const x = L.x + c * (r + q), y = L.y + sn * (r + q); if (gone > 0 && hash(Math.round(x) * 12.9898 + Math.round(y) * 78.233) < gone * 0.9) continue; const e = q / Math.max(ww, 0.01); p.dot(x, y, e > 0.3 ? H[0] : e > -0.3 ? H[2] : H[4], Math.max(0.15, fade)); }
    if (i % 4 === 0) p.light(L.x + c * r, L.y + sn * r, H[3], 0.35 * fade); }
  for (let i = 0; i < 38; i++) { const an = a0 + (a1 - a0) * (0.08 + 0.84 * hash(i * 3.7 + wave.t)), len = (3 + 9 * hash(i * 5.1)) * R.P.size, back = (2 + 10 * hash(i * 7.3)) * R.P.size, br = hash(i * 9.9); if (hash(i + Math.floor(S.t * 20)) < gone) continue; // 外へ押し出される光の筋
    const c = Math.cos(an), sn = Math.sin(an), r0 = r - back - len, r1 = r - back; p.line(L.x + c * r0, L.y + sn * r0, L.x + c * r1, L.y + sn * r1, (t) => t > 0.7 ? H[br > 0.5 ? 0 : 1] : H[3], (t) => Math.max(0.15, fade * (0.3 + 0.7 * t))); }
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
// 突進専用の予兆：角は光が集まって光る（炎は出さない。角の発光は本番の実装のまま）。前足が地面を蹴って金の火花が後ろへ散り、
// 尾の噴射口の青い炎が脈打って膨らむ。溜めの最後は動きを止めて見せる（姿勢は monoChargePose）
const MONO_GOLD = ['#ffffff', '#fff3c0', '#ffe08a', '#ffc457', '#f2a03a', '#d8782a', '#a8521e', '#6e3214', '#3a1a0c'];
function monoChargeTell(S, R, rig) {
  const duration = S.tech === 'horn_dance' ? S.r.aim_time : S.r.warn, charge = smooth(0, duration * 0.62, S.st), H = MONO_GOLD.map(hexc);
  const B = S.B, u = fromA(S.angle), tip = toL(rig.hornTip), root = toL(rig.horn), back = V(-u.x, -u.y);
  // 角の発光は本番の実装（角の白い発光）のまま。ここでは足さない
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
  const dashing = (S.stage === 'run' && ['charge', 'return_charge', 'horn_dance', 'lance'].includes(S.tech)) || (S.tech === 'sweep' && ['approach', 'stop'].includes(S.stage));
  if (!dashing) { S.jetT = null; return; }
  S.jetT ??= S.t; const B = S.B, u = S.tech === 'sweep' ? fromA(S.stage === 'stop' ? S.base : B.facing) : fromA(S.angle), age = S.t - S.jetT, burst = 1 + 0.5 * (1 - smooth(0, 0.18, age));
  // 移動距離に応じた大きさ：突進は進む距離（S.travel、700 で 1 倍）、踏み込みは今の速さ（最高速で 1 倍）
  const move = S.tech === 'sweep' ? clamp((S.v || 0) / (S.r.approach_speed_max || 1), 0, 1.2) : clamp((S.travel || 700) / 700, 0.4, 2);
  canisJetStream(R, add(B.pos, mul(u, -B.r * 0.95)), S.angle + Math.PI, B.r * 2.6 * burst * move * R.P.size * (R.P.tailJet ?? 1), 1.1 * burst * Math.sqrt(Math.max(0.2, move)) * (R.P.tailJetWidth ?? 1), age + 0.3, Infinity, Math.min(1, R.P.intensity), 77); // 長さ・太さはつまみ
}

// 角の衝撃波の体の動き（絵の姿勢だけ。攻撃の時刻と向きの計算は変えない）：溜めで頭を引いて体を縮め、最後は力んで震えながら止まる（静）→ 振り抜く瞬間に頭と体が前へ突き出る（動）→ 戻る
function monoWavePose(S, edits) {
  if (S.tech !== 'horn_wave') return; const r = S.r, head = MONO.nodes.find(n => n.name === 'Head'), body = MONO.nodes.find(n => n.name === 'Body');
  let pull = 0, thrust = 0, shake = 0;
  if (S.stage === 'windup' || S.stage === 'recharge') { const dur = S.stage === 'windup' ? r.windup : r.recharge, w = smooth(0, dur * 0.7, S.st); pull = w; shake = smooth(dur * 0.7, dur, S.st) * Math.sin(S.t * 70) * 1.6; }
  else if (S.stage === 'swing') { const q = clamp(S.st / r.swing_time); thrust = Math.sin(Math.PI * Math.min(1, q * 1.3)); pull = 1 - smooth(0, 0.25, q); }
  else if (S.stage === 'return') pull = 0;
  edits.Head.position = add(head.position, V(shake, -pull * 16 + thrust * 15));
  edits.Body = { position: add(body.position, V(shake * 0.5, -pull * 8 + thrust * 8)), scale: V(1 + pull * 0.05, 1 - pull * 0.07 + thrust * 0.05) };
}
// 踏み込み薙ぎの斬撃（pixelFX melee/sword-slash.js の、白から冷えていく三日月。dash strike の斬撃部分）：薙ぎ払う角の先の軌跡に沿って出す。色は角の発光の色
function monoSweepSlash(S, R) {
  if (S.tech !== 'sweep' || !S.slashStart) return; const r = S.r, B = S.B, age = S.t - S.slashStart, linger = 0.32 * R.P.timing;
  const a0 = S.base - r.windup_twist, swing = S.stage === 'swing' ? clamp(S.st / r.active) : 1, aNow = a0 + r.arc * swing * swing * (1.6 - 0.6 * swing), endAge = S.stage === 'swing' ? 0 : age - r.active;
  if (endAge > linger) return; const fade = 1 - smooth(0, linger, endAge), reach = monoHornLength(B) * 1.05;
  FXW.crescent(R.front, B.pos, reach, a0, aNow, 1, Math.min(0.85, endAge / linger), 42 * R.P.size, R.P.color, Math.min(1, fade * R.P.intensity));
  if (endAge <= 0) { const tip = add(B.pos, mul(fromA(aNow), reach)); FXW.sparks(R.front, tip, (age % 0.12), Math.floor(age / 0.12) + 7, 4, R.P.color, 35, 0.2, aNow + Math.PI / 2, 0.6); }
}
// 光角の乱舞の燃え跡：通った道に沿って、熱く光ってから煤へ冷えていく、まだらな跡（2.5 秒で消える）
function monoDanceBurn(S, R) {
  if (S.tech !== 'horn_dance' || !S.burn?.length) return; const heat = MONO_GOLD.slice(1).map(hexc), soot = [hexc('#120c08'), hexc('#1f160f')];
  for (const b of S.burn) { const age = S.t - b.t; if (age > 2.5) continue; const L = toL(b.pos), rr = 3.2 * R.P.size, fade = 1 - smooth(1.4, 2.5, age);
    for (let y = -Math.ceil(rr); y <= rr; y++) for (let x = -Math.ceil(rr); x <= rr; x++) { const k = hash((Math.round(L.x) + x) * 12.9898 + (Math.round(L.y) + y) * 78.233), d = Math.hypot(x, y) / rr; if (d > 0.7 + 0.5 * k || k > fade * 0.95) continue;
      const T = Math.pow(clamp(1 - age / 0.9), 1.3) * (1.1 - d) - k * 0.35; if (T > 0.1) R.back.px(L.x + x, L.y + y, heat[Math.min(heat.length - 1, Math.floor((1 - Math.min(1, T)) * (heat.length - 1)))]); else R.back.blend(L.x + x, L.y + y, soot[k < 0.5 ? 0 : 1], 0.7); } }
}
