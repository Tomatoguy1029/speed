// ===== ケンタウルス座：現行のパーツ構成とアニメーションクリップをそのまま再生する =====
// scenes/bosses/centaurus_parts.tscn（ノード・アトラス領域・反転）＋ data/visuals/centaurus_animation.tres（poses/clips/part_pivots）
// ＋ scripts/bosses/centaurus_parts.gd（弓の差分・クリップの選び方・時間の扱い）＋ centaurus_presentation.gd（向き・拡大率・跳躍）。
const CEN = DATA.centaurus;
const BOW_REGIONS = [[300, 110, 116, 18], [317, 148, 98, 18], [340, 176, 76, 18], [375, 203, 41, 18], [462, 225, 9, 52], [484, 226, 10, 68], [300, 61, 116, 10], [301, 82, 114, 12], [407, 225, 9, 22], [424, 225, 9, 28], [443, 225, 9, 38]];
const BOW_GRIPS = [[58, 15], [49, 14], [38, 12], [20, 16], [4, 26], [5, 34], [58, 5], [57, 8], [4, 11], [4, 14], [4, 19]];
const CEN_R = CEN.def.radius * CS;            // boss_system.gd：def.radius × character_scale
function cenPath(n) { const parent = n.parent; return parent === '.' ? n.name : parent && parent !== 'null' ? parent + '/' + n.name : null; }
const CEN_NODES = CEN.nodes.slice(1).map(n => ({ ...n, path: cenPath(n) }));
const CEN_EDIT = CEN_NODES.filter(n => n.label).map(n => n.path);
function clipDuration(clip) { return (CEN.clips[clip] || []).reduce((s, f) => s + Math.max(0.02, f.duration ?? 0.15), 0); }
function samplePose(clip, time) { // boss_part_animation.gd sample
  const frames = CEN.clips[clip] || []; if (!frames.length) return CEN.poses.neutral;
  let rem = Math.max(0, time);
  for (let i = 0; i < frames.length; i++) { const f = frames[i], sec = Math.max(0.02, f.duration ?? 0.15);
    if (rem < sec || i === frames.length - 1) { if (!f.interpolate || i === frames.length - 1) return f.pose; const nx = frames[i + 1].pose, fr = clamp(rem / sec), out = JSON.parse(JSON.stringify(f.pose)); for (const k in out) { if (!nx[k]) continue; for (const fld of ['position', 'scale', 'pivot_origin']) if (f.pose[k][fld] && nx[k][fld]) out[k][fld] = lerpV(f.pose[k][fld], nx[k][fld], fr); out[k].rotation = f.pose[k].rotation + angDiff(nx[k].rotation, f.pose[k].rotation) * fr; } return out; }
    rem -= sec; }
  return frames[frames.length - 1].pose;
}
// 2Dアフィン（Godot Transform2D と同じ並び）
const M = { mk: (rot, sx, sy, x, y) => [Math.cos(rot) * sx, Math.sin(rot) * sx, -Math.sin(rot) * sy, Math.cos(rot) * sy, x, y],
  mul: (a, b) => [a[0] * b[0] + a[2] * b[1], a[1] * b[0] + a[3] * b[1], a[0] * b[2] + a[2] * b[3], a[1] * b[2] + a[3] * b[3], a[0] * b[4] + a[2] * b[5] + a[4], a[1] * b[4] + a[3] * b[5] + a[5]],
  pt: (m, p) => V(m[0] * p.x + m[2] * p.y + m[4], m[1] * p.x + m[3] * p.y + m[5]) };
function partLocal(path, pose) {
  const n = CEN_NODES.find(q => q.path === path), e = pose[path] || CEN.poses.neutral[path] || { position: n.position, rotation: n.rotation, scale: n.scale };
  let pos = e.position; const pv = CEN.part_pivots[path];
  if (pv && e.pivot_origin) { const m = M.mk(e.rotation, e.scale.x, e.scale.y, 0, 0), o = M.pt(m, pv); pos = sub(e.pivot_origin, o); }
  return { m: M.mk(e.rotation, e.scale.x, e.scale.y, pos.x, pos.y), z: e.z_index || 0, visible: e.visible !== false, bow: e.bow ?? -1 };
}
// 姿勢を世界へ：本体位置・向き → parts（-90°回転・r/135 倍）→ 各部位
function cenRig(boss, pose) {
  const scale = (CEN_R / 135) * (boss.scaleMul || 1), off = boss.lift || V(0, 0);
  const root = M.mul(M.mk(boss.facing, 1, 1, boss.pos.x + off.x, boss.pos.y + off.y), M.mk(-Math.PI / 2, scale, scale, 0, 0));
  const world = {}, info = {};
  for (const n of CEN_NODES) { if (!n.label) continue; const parent = n.path.includes('/') ? n.path.slice(0, n.path.lastIndexOf('/')) : null; const L = partLocal(n.path, pose); info[n.path] = L; world[n.path] = M.mul(parent ? world[parent] : root, L.m); }
  return { root, world, info, scale };
}
function drawCentaurus(boss, pose, opts = {}) {
  const cx = opts.ctx || g, rig = cenRig(boss, pose), sprites = [];
  CEN_NODES.forEach((n, idx) => { if (!n.texture) return; const parentPath = n.parent; const W0 = rig.world[parentPath]; if (!W0 || rig.info[parentPath].visible === false) return;
    let region = n.texture.region, tex = n.texture.tex, pos = n.position;
    if (parentPath === 'Bow') { const f = clamp(rig.info.Bow.bow >= 0 ? rig.info.Bow.bow : 0, 0, 10); const r = BOW_REGIONS[f]; region = { x: r[0], y: r[1], w: r[2], h: r[3] }; pos = V(5 - BOW_GRIPS[f][0], 34 - BOW_GRIPS[f][1]); }
    const isBase = n.name === 'Base'; sprites.push({ m: M.mul(W0, M.mk(0, 1, 1, pos.x, pos.y)), region, img: isBase ? 'centaurus/base' : tex === 'bow' ? 'centaurus/bow_lit' : 'centaurus/armor_lit', flip: n.flip_h, z: isBase ? -9999 : rig.info[parentPath].z + (n.z_index || 0), idx }); });
  sprites.sort((a, b) => a.z - b.z || a.idx - b.idx);
  for (const s of sprites) { const im = IMG[s.img]; if (!im) continue; cx.save(); cx.transform(s.m[0], s.m[1], s.m[2], s.m[3], s.m[4], s.m[5]); if (s.flip) { cx.translate(s.region.w, 0); cx.scale(-1, 1); } cx.imageSmoothingEnabled = false; cx.drawImage(im, s.region.x, s.region.y, s.region.w, s.region.h, 0, 0, s.region.w, s.region.h);
    if (opts.white > 0) { cx.globalCompositeOperation = 'lighter'; cx.globalAlpha = opts.white; cx.filter = 'brightness(0) invert(1)'; cx.drawImage(im, s.region.x, s.region.y, s.region.w, s.region.h, 0, 0, s.region.w, s.region.h); cx.filter = 'none'; }
    cx.restore(); }
  return rig;
}
// centaurus_parts.gd set_bow_pose（クリップの選択と時刻）
function bowClip(tech, mode) {
  if (mode === 'leap') return 'leap'; if (mode === 'retreat') return 'run';
  const T = { volley: 'shot', power_shot: 'shot', rain: 'rain', fan_volley: 'fan', sail_run: 'sail', stomp: 'stomp' }[tech];
  if (!T) return 'idle';
  const mm = { windup: '_windup', shooting: '_release', recovery: '_recovery', rain: '', sail: '_run', strike: '' }[mode];
  if (mm == null) return 'idle'; if (T === 'rain' && mode === 'rain') return 'rain'; if (T === 'stomp' && mode === 'strike') return 'stomp'; if (T === 'sail' && mode === 'sail') return 'sail_run';
  if ((T === 'shot' || T === 'fan') && mode === 'shooting') return T + '_release';
  return T + mm;
}
function bowPose(B, dt) {
  const clip = bowClip(B.technique, B.mode); if (clip !== B.clip) { B.clip = clip; B.clipTime = 0; } B.clipTime += dt;
  const L = clipDuration(clip); let time = B.clipTime;
  if (B.mode === 'windup') time = clamp(B.charge) * L; else if (['shot_release', 'fan_release', 'sail_run'].includes(clip)) time = B.clipTime / B.shotInterval * L; else if (['idle', 'rain', 'shower', 'run'].includes(clip) && L > 0) time = B.clipTime % L;
  if (clip === 'stomp' && B.poseTime >= 0) time = B.poseTime;
  B.pose = samplePose(clip, time);
}
function mkBoss(pos, facing) { return { pos: { ...pos }, facing, r: CEN_R, mode: 'idle', technique: '', clock: 0, charge: 0, clip: '', clipTime: 0, shotInterval: 0.4, pose: CEN.poses.neutral, hit: 0, pulse: 0, leapRing: 0, recovery: 0, arrows: [] }; }
const bowMouth = (B) => add(B.pos, mul(fromA(B.facing), B.r * CEN.def.params.bow_reach));
// 現行の矢（light_arrow.gd draw_arrow：light_arrow.svg を #ffe4a1 で着色、芯の線、長さ0なら tail_scale=radius/12）
let ARROW_TINT = null;
function prepArrow() { const im = IMG.light_arrow; if (!im) return; const c = document.createElement('canvas'); c.width = 128; c.height = 48; const x = c.getContext('2d'); x.drawImage(im, 0, 0, 128, 48); const d = x.getImageData(0, 0, 128, 48), t = parseCol('#ffe4a1'); for (let i = 0; i < d.data.length; i += 4) { d.data[i] *= t.r; d.data[i + 1] *= t.g; d.data[i + 2] *= t.b; } x.putImageData(d, 0, 0); ARROW_TINT = c; }
function drawArrow(pos, angle, radius, opacity = 1, length = 0) {
  if (!ARROW_TINT) prepArrow(); const sc = radius / 12, ts = length > 0 ? length / 52 : sc;
  g.save(); g.translate(pos.x, pos.y); g.rotate(angle); g.scale(ts, sc); g.globalAlpha = opacity; g.drawImage(ARROW_TINT, -52, -12, 64, 24);
  g.beginPath(); g.moveTo(-32, 0); g.lineTo(4, 0); g.strokeStyle = `rgba(240,247,255,${opacity})`; g.lineWidth = 1.5; g.stroke(); g.restore();
}
function stepArrows(B, dt) { for (const a of B.arrows) { a.pos = add(a.pos, mul(fromA(a.a), a.speed * dt)); a.d += a.speed * dt; } B.arrows = B.arrows.filter(a => a.d < a.travel); }
function drawArrows(B) { for (const a of B.arrows) drawArrow(a.pos, a.a, a.radius); }
// 現行の本体まわりの表示（centaurus_presentation.gd _draw）：跳躍の着地の輪・硬直中の水色の輪（C02 の候補）・発射の波動（C10 の現行）
function drawCenPresentationCurrent(B) {
  const k = B.r / 90, toW = (q) => add(B.pos, V(Math.cos(B.facing) * q.x - Math.sin(B.facing) * q.y, Math.sin(B.facing) * q.x + Math.cos(B.facing) * q.y));
  if (B.leapRing > 0) D2.arc(B.pos, 30 + (0.3 - B.leapRing) * 160, 0, TAU, rgba('#d8b46a', B.leapRing / 0.3), 3);
  if (B.mode === 'recovery') { const a = 0.45 + Math.sin(B.clock * 14) * 0.25; D2.arc(toW(V(-6 * k, 0)), 96 * k, 0, TAU, rgba('#9fe8ff', a), 3 * 2 * k); }
  if (B.pulse > 0) D2.arc(toW(V(62 * k, 0)), (30 + (0.3 - B.pulse) * 80) * k, 0, TAU, rgba('#f4ecd8', Math.min(1, B.pulse * 2.5)), 3 * k);
}
function bossTick(B, dt) { B.clock += dt; B.pulse = Math.max(0, B.pulse - dt); B.leapRing = Math.max(0, B.leapRing - dt); B.hit = Math.max(0, B.hit - dt); bowPose(B, dt); stepArrows(B, dt); }
const CEN_CAT = 'ケンタウルス座（C）';
const CEN_REFS = ['scenes/bosses/centaurus_parts.tscn・data/visuals/centaurus_animation.tres（全身のパーツ・クリップを再生）', 'scripts/bosses/centaurus_parts.gd・centaurus_presentation.gd・centaurus_boss.gd', 'assets/pixel/centaurus/base.png・armor.png・bow.png（法線照明は向き0で焼き込んだ近似）', 'assets/fx/light_arrow.svg・scripts/render/attacks/light_arrow.gd（矢本体は現行のまま）'];

// ---------- C07 強弓の照準
DEMOS.push({
  id: 'C07-power-shot', ids: ['C07'], cat: CEN_CAT, group: 'ケンタウルス座', title: '強弓の照準（レーザーサイト）', duration: 3.4, color: '#ff3b4f', cam: { x: 120, y: 0 },
  refs: [...CEN_REFS, 'data/bosses/centaurus_moves/power_shot.tres（warn 1.4・alert 0.4・速さ1800・半径30・射程1600・recover 1.5）', 'scripts/bosses/centaurus/technique_visual.gd（現行の照準線と弓の前の四角い光）', 'pixelFX projectiles/laser-bolt.js の白熱芯と赤い帯、marlin_warning.gdshader の光の包み'],
  status: { '状態': '試作のみ', '判定・挙動': '変更なし（警告まで自機を追い、警告後に照準を固定、発射の瞬間に1本）。矢本体は現行 main のまま', '対象外': '矢の絵・矢の雨の予兆（現行採用）、弓の引きのモーション（C01、移行後）' },
  setup(S) { S.B = mkBoss(V(-260, -20), 0); S.ship = shipState(V(420, 60)); S.B.technique = 'power_shot'; S.B.mode = 'windup'; S.B.t0 = 0.2; S.B.mode = 'idle'; },
  step(S, dt) {
    const B = S.B, r = CEN.moves.power_shot, t = S.t - B.t0; S.ship.pos.y = 60 + Math.sin(S.t * 1.4) * 90;
    if (B.mode === 'idle' && t >= 0) { B.mode = 'windup'; B.alerting = false; }
    if (B.mode === 'windup') { B.charge = clamp(t / r.warn); if (!B.alerting) B.facing = angOf(sub(S.ship.pos, B.pos)); else B.facing = B.lockA;
      if (!B.alerting && t >= r.warn - r.alert) { B.alerting = true; B.lockO = bowMouth(B); B.lockA = B.facing; B.pulse = 0.3; }
      if (t >= r.warn) { B.arrows.push({ pos: B.lockO, a: B.lockA, speed: r.speed, radius: r.radius, travel: r.travel, d: 0 }); B.mode = 'shooting'; B.shotInterval = 0.4; B.clipTime = 0; B.pulse = 0.3; B.relT = S.t; } }
    else if (B.mode === 'shooting' && t >= r.warn + 0.05) { B.mode = 'recovery'; B.recovery = r.recover; }
    else if (B.mode === 'recovery') { B.recovery -= dt; if (B.recovery <= 0) B.mode = 'idle', B.technique = ''; }
    bossTick(B, dt);
  },
  phase(S) { const B = S.B; return B.mode === 'windup' ? (B.alerting ? '警告（照準固定）' : PH.WINDUP + '（照準・自機を追う）') : B.mode === 'shooting' ? '発射' : B.mode === 'recovery' ? '硬直（攻めどき）' : PH.MOVE; },
  draw(S, R) {
    const B = S.B, r = CEN.moves.power_shot, P = R.P;
    if (B.mode === 'windup') {
      const mouth = B.alerting ? B.lockO : bowMouth(B), ang = B.alerting ? B.lockA : B.facing;
      let end = add(mouth, mul(fromA(ang), r.travel)); const hit = segCircleT(mouth, end, S.ship.pos, DATA.config.ship_radius); if (hit >= 0) end = lerpV(mouth, end, hit);
      if (!R.proto) { const c = B.alerting ? '#ff667d' : '#f2b567'; D2.line(mouth, end, rgba(c, 0.12), 8); D2.line(mouth, end, rgba(c, B.alerting ? 0.95 : 0.6), 2); D2.line(mouth, end, `rgba(255,${B.alerting ? 191 : 242},153,.8)`, 0.8); }
      else { // レーザーサイト：弓口の照準器から細い光線が伸び、狙いの点（自機上の光点）が揺れながら収束、警告で色と太さが変わり固定
        const k = B.charge, A = toL(mouth), E = toL(end), pal = FX.ramp(B.alerting ? P.color : '#ffb35a');
        FX.warnRail(R.back, A, E, { color: B.alerting ? P.color : '#ffb35a', k: B.alerting ? 1 : 0.35 + 0.45 * k, time: S.t, seed: 77, rail: B.alerting ? 1.6 : 0.9, intensity: P.intensity });
        const jit = B.alerting ? 0 : (1 - k) * 3, dx = Math.sin(S.t * 23) * jit, dy = Math.cos(S.t * 17) * jit;
        if (hit >= 0) { const Q = V(E.x + dx, E.y + dy); R.front.circle(Q.x, Q.y, 1.4 * P.size, pal[4]); R.front.ring(Q.x, Q.y, (B.alerting ? 3 : 5 - 2 * k) * P.size, 1, pal[3], 0.9); R.front.glow(Q.x, Q.y, 9, pal[2], 0.6 * P.intensity); }
        R.front.circle(A.x, A.y, 1.2 + (B.alerting ? 1 : 0), pal[4]); R.front.glow(A.x, A.y, 8 + 6 * k, pal[2], 0.5 * P.intensity);
        if (B.alerting && S.t - (B.relT || 0) > 0 && B.pulse > 0.2) FX.flare(R.front, A, 3 * P.size, P.color, S.t, (B.pulse - 0.2) / 0.1, 4);
      }
    }
    if (R.proto) R.blitBack();
    drawCentaurus(B, B.pose); drawArrows(B); drawShip(S.ship);
    if (!R.proto) { // 現行：弓の前の光（technique_visual.gd の draw_set_transform 以降）と本体まわり
      if (B.mode === 'windup') { const k = B.r / 90, f = B.charge, p0 = V(62 + Math.cos(1.1) * 26 - f * 34, 0), toW = (q) => add(B.pos, V(Math.cos(B.facing) * q.x * k - Math.sin(B.facing) * q.y * k, Math.sin(B.facing) * q.x * k + Math.cos(B.facing) * q.y * k)); D2.line(toW(p0), toW(add(p0, V(70, 0))), B.alerting ? '#ff667d' : '#f2b567', 3 * 3 * k); }
      drawCenPresentationCurrent(B);
    }
  },
});
function segCircleT(a, b, c, r) { const d = sub(b, a), f = sub(a, c), A = d.x * d.x + d.y * d.y, Bq = 2 * (f.x * d.x + f.y * d.y), C = f.x * f.x + f.y * f.y - r * r, disc = Bq * Bq - 4 * A * C; if (disc < 0) return -1; const t = (-Bq - Math.sqrt(disc)) / (2 * A); return t >= 0 && t <= 1 ? t : -1; }

// ---------- C10 矢の発射の瞬間（速射）
DEMOS.push({
  id: 'C10-release', ids: ['C10'], cat: CEN_CAT, group: 'ケンタウルス座', title: '矢の発射の瞬間（速射）', duration: 2.8, color: '#ffd98a', cam: { x: 120, y: 0 },
  refs: [...CEN_REFS, 'data/bosses/centaurus_moves/volley.tres（warn 0.6・5本・間隔0.18・速さ900・半径12・recover 0.8）', 'centaurus_presentation.gd の pulse（released の合図で (62,0) に広がる弧＝現行の「黄色い波動」）', 'pixelFX melee/sword-slash.js の閃き、painter.sparks'],
  status: { '状態': '試作のみ', '対象': '発射の瞬間だけ。矢本体（light_arrow.svg）は現行 main のまま変更なし', '判定・挙動': '変更なし（発射時刻・本数・向き）' },
  setup(S) { S.B = mkBoss(V(-260, -20), 0); S.ship = shipState(V(420, 60)); S.B.technique = 'volley'; S.B.t0 = 0.2; S.rel = []; },
  step(S, dt) {
    const B = S.B, r = CEN.moves.volley, t = S.t - B.t0; S.ship.pos.y = 60 + Math.sin(S.t * 1.2) * 80;
    if (B.mode === 'idle' && t >= 0 && !S.done) { B.mode = 'windup'; B.k = 0; }
    if (B.mode === 'windup' || B.mode === 'shooting') { B.facing = rotToward(B.facing, angOf(sub(S.ship.pos, B.pos)), CEN.def.turn * dt); B.charge = B.mode === 'windup' ? clamp(t / r.warn) : 0;
      while (B.k < r.count && t >= r.warn + r.interval * B.k) { const m = bowMouth(B); B.arrows.push({ pos: m, a: angOf(sub(S.ship.pos, m)), speed: r.speed, radius: r.radius, travel: r.travel, d: 0 }); B.mode = 'shooting'; B.shotInterval = r.interval; B.clipTime = 0; B.pulse = 0.3; S.rel.push({ t: S.t, at: m, a: angOf(sub(S.ship.pos, m)) }); B.k++; }
      if (t >= r.warn + r.interval * (r.count - 1) + 0.05) { B.mode = 'recovery'; B.recovery = r.recover; S.done = 1; } }
    else if (B.mode === 'recovery') { B.recovery -= dt; if (B.recovery <= 0) B.mode = 'idle'; }
    bossTick(B, dt);
  },
  phase(S) { const B = S.B; return B.mode === 'windup' ? PH.WINDUP : B.mode === 'shooting' ? '連射' : B.mode === 'recovery' ? '硬直' : PH.MOVE; },
  draw(S, R) {
    const B = S.B, P = R.P;
    drawCentaurus(B, B.pose); drawArrows(B); drawShip(S.ship);
    if (!R.proto) { if (B.mode === 'windup') { const k = B.r / 90, f = B.charge, p0 = V(62 + Math.cos(1.1) * 26 - f * 34, 0), toW = (q) => add(B.pos, V(Math.cos(B.facing) * q.x * k - Math.sin(B.facing) * q.y * k, Math.sin(B.facing) * q.x * k + Math.cos(B.facing) * q.y * k)); D2.line(toW(p0), toW(add(p0, V(56, 0))), '#f2b567', 3 * 1.5 * k); } drawCenPresentationCurrent(B); return; }
    // 試作：弦が弾ける閃光（前方へ短い光条）＋弓の両端から弦の残像＋金の火花。輪や円は使わない
    for (const e of S.rel) { const t = (S.t - e.t) / P.timing; if (t < 0 || t > 0.32) continue; const A = toL(e.at), pal = FX.ramp(P.color), u = fromA(e.a), n = orth(u);
      const f = 1 - t / 0.32, len0 = (10 + 26 * Math.min(1, t / 0.05)) * P.size;
      for (let i = -2; i <= 2; i++) { const spread = i * 0.16, L1 = len0 * (1 - Math.abs(i) * 0.22), d = fromA(e.a + spread); R.front.line(A.x, A.y, A.x + d.x * L1, A.y + d.y * L1, (uu) => uu < 0.35 ? pal[4] : uu < 0.7 ? pal[3] : pal[2], (uu) => f * (1 - uu * 0.7) * Math.min(1, P.intensity)); }
      if (t < 0.06) { R.front.circle(A.x, A.y, 2.4 * P.size, pal[4], 1); R.front.glow(A.x, A.y, 14 * P.size, pal[3], 0.9 * P.intensity); }
      const tipL = 7 * P.size; for (const s of [-1, 1]) { const T = V(A.x - u.x * 4 + n.x * s * tipL, A.y - u.y * 4 + n.y * s * tipL); R.front.line(T.x, T.y, A.x - u.x * (2 - 4 * f), A.y - u.y * (2 - 4 * f), pal[3], 0.7 * f); }
      FX.sparks(R.front, A, t, e.t * 31, 9, P.color, 55, 0.3, e.a, 0.55);
    }
  },
});

// ---------- C05 バックステップの着地
DEMOS.push({
  id: 'C05-landing', ids: ['C05'], cat: CEN_CAT, group: 'ケンタウルス座', title: 'バックステップの着地', duration: 2.0, color: '#c9b08a', cam: { x: -120, y: 0 }, bg: 'asteroid_a',
  refs: [...CEN_REFS, 'centaurus_boss.gd _begin_leap/_leap_tick（leap_time 0.35・距離320・(1-k)^2 の減速）・presentation の跳躍の拡大と持ち上げ', 'centaurus_presentation.gd leap_ring（着地で金色の輪 30→78）', 'pixelFX explosions・nature 系の土煙（painter.disc の半透明）'],
  status: { '状態': '試作のみ', '判定・挙動': '変更なし（距離・時間・着地後に降り注ぐ矢へ移る流れ）。着地後の技はこのデモでは描かない', 'モーション': '踏み込み→跳躍→着地の動作（C06）は移行後。ここでは現行の楕円的な移動のまま', '青い円について': '着地の輪は金色。水色の輪は硬直（recovery）中に本体へ描く「攻めどき」の輪（centaurus_presentation.gd、open_color #9fe8ff）で、C02 の発生源の候補' },
  setup(S) { S.B = mkBoss(V(80, 0), Math.PI); S.ship = shipState(V(-200, 30)); S.lt = 0.3; },
  step(S, dt) {
    const B = S.B, p = CEN.def.params;
    if (B.mode === 'idle' && S.t >= S.lt && !S.landed) { B.mode = 'leap'; B.leapT = 0; B.facing = angOf(sub(S.ship.pos, B.pos)); B.from = { ...B.pos }; B.to = add(B.from, mul(norm(sub(B.from, S.ship.pos)), p.leap_distance)); }
    if (B.mode === 'leap') { const before = clamp(B.leapT / p.leap_time); B.leapT += dt; const k = clamp(B.leapT / p.leap_time); B.pos = add(B.pos, mul(sub(B.to, B.from), (1 - before) ** 2 - (1 - k) ** 2)); B.facing = rotToward(B.facing, angOf(sub(S.ship.pos, B.pos)), CEN.def.turn * 3 * dt); const h = Math.sin(Math.PI * k); B.scaleMul = 1 + 0.12 * h; B.lift = V(0, -65 * h);
      if (k >= 1) { B.mode = 'idle'; B.leapRing = 0.3; B.scaleMul = 1; B.lift = V(0, 0); S.landed = S.t; S.feet = cenFeet(B); } }
    bossTick(B, dt);
  },
  phase(S) { return S.S?.B?.mode === 'leap' || S.B.mode === 'leap' ? '跳躍' : S.landed ? '着地（このあと降り注ぐ矢へ）' : PH.MOVE; },
  draw(S, R) {
    const B = S.B, P = R.P;
    if (R.proto && S.landed) { const t = (S.t - S.landed) / P.timing;
      for (const [i, f] of (S.feet || []).entries()) { const L = toL(f), pal = FX.ramp(P.color);
        for (let j = 0; j < 7; j++) { const lf = 0.5 + hash(i * 9 + j) * 0.4; if (t > lf) continue; const q = t / lf, a = hash(i * 13 + j * 3) * TAU, d = (3 + 12 * Math.sqrt(q)) * P.size, rr = (1.5 + 3.5 * q) * P.size; R.back.disc(L.x + Math.cos(a) * d, L.y + Math.sin(a) * d * 0.7 - q * 2, rr, pal[q < 0.3 ? 3 : 2], (dd) => 0.45 * (1 - q) * (1 - dd * dd) * P.intensity); }
        if (t < 0.12) R.back.glow(L.x, L.y, 6, pal[3], 0.4 * (1 - t / 0.12)); }
      if (t < 0.45) { const Lc = toL(B.pos), pal = FX.ramp(P.color); for (let j = 0; j < 40; j++) { const a = hash(j) * TAU, d = (B.r * WL * 0.8) * (0.6 + 1.1 * (t / 0.45)) * (0.85 + 0.3 * hash(j + 1)); R.back.dot(Lc.x + Math.cos(a) * d, Lc.y + Math.sin(a) * d * 0.75, pal[2], 0.7 * (1 - t / 0.45)); } }
      R.blitBack();
    }
    if (!R.proto && B.mode === 'leap') D2.circle(B.pos, B.r * 0.6, 'rgba(0,0,0,.0)');
    drawCentaurus(B, B.pose); drawShip(S.ship);
    if (!R.proto) drawCenPresentationCurrent(B);
  },
});
function cenFeet(B) { const rig = cenRig(B, B.pose), out = []; for (const [path, c] of [['FrontLeftLeg', V(11.5, 52)], ['FrontRightLeg', V(7.5, 52)], ['RearLeftLeg', V(11.5, 52)], ['RearRightLeg', V(7.5, 52)]]) out.push(M.pt(rig.world[path], c)); return out; }

// ---------- C13 前脚の踏みつけ
DEMOS.push({
  id: 'C13-stomp', ids: ['C13'], cat: CEN_CAT, group: 'ケンタウルス座', title: '前脚の踏みつけ', duration: 2.4, color: '#e8c48a', cam: { x: 60, y: 0 }, bg: 'asteroid_a',
  params: [{ k: 'showHit', label: '判定の扇を重ねる(0/1)', type: 'range', min: 0, max: 1, step: 1, def: 0 }],
  refs: [...CEN_REFS, 'data/bosses/centaurus_moves/stomp.tres（warn 0.6・active 0.15・半径260・半角50°・recover 1.0）', 'scripts/bosses/centaurus/techniques/stomp.gd contact_center（前脚の接地点の平均＝踏みつけの中心）', 'additional_technique_visual.gd（現行の赤い扇と弧）', 'pixelFX melee/heavy-cleave.js の地割れ・土煙'],
  status: { '状態': '試作のみ（エフェクトだけ）', '判定・挙動': '変更なし（中心・半径・角度・時刻）', 'モーション': '踏みつけのクリップ stomp/stomp_windup は現行で空（中立姿勢のまま）。実際に前足を踏みつける動作は移行後（C13のモーション）', '注意': 'centaurus_animation.tres は中心位置に効くため変更していない' },
  setup(S) { S.B = mkBoss(V(-140, 0), 0); S.ship = shipState(V(120, 30)); S.B.technique = 'stomp'; },
  step(S, dt) {
    const B = S.B, r = CEN.moves.stomp, t = S.t - 0.3;
    if (B.mode === 'idle' && t >= 0 && !S.done) { B.mode = 'windup'; S.t0 = S.t; }
    if (B.mode === 'windup' || B.mode === 'strike') { const el2 = S.t - S.t0; B.charge = clamp(el2 / r.warn); if (el2 >= r.warn && B.mode === 'windup') { B.mode = 'strike'; S.strikeT = S.t; } B.poseTime = B.mode === 'strike' ? el2 - r.warn : 0; if (el2 >= r.warn + r.active) { B.mode = 'recovery'; B.recovery = r.recover; S.done = 1; } }
    else if (B.mode === 'recovery') { B.recovery -= dt; if (B.recovery <= 0) B.mode = 'idle'; }
    bossTick(B, dt); S.center = stompCenter(B);
  },
  phase(S) { const m = S.B.mode; return m === 'windup' ? PH.WINDUP : m === 'strike' ? '踏みつけ（判定 0.15s）' : m === 'recovery' ? '硬直' : PH.MOVE; },
  draw(S, R) {
    const B = S.B, P = R.P, r = CEN.moves.stomp, c = S.center || B.pos, half = r.half_angle * Math.PI / 180, ang = B.facing;
    if (R.proto) { const L = toL(c), rad = r.range_radius * WL, pal = FX.ramp(P.color);
      const inFan = (a, d) => Math.abs(angDiff(a, ang)) <= half && d <= rad;
      if (B.mode === 'windup') { const k = B.charge; // 扇の中だけ地面が震え、小石と塵が跳ねる。前足の接地点に力が溜まる
        for (let i = 0; i < 70; i++) { const a = ang + (hash(i) - 0.5) * 2 * half, d = rad * Math.sqrt(hash(i * 3 + 1)), hop = Math.abs(Math.sin(S.t * (18 + hash(i) * 10) + i)) * 2 * k; R.back.dot(L.x + Math.cos(a) * d, L.y + Math.sin(a) * d - hop, pal[hop > 1 ? 3 : 2], (0.25 + 0.6 * k) * P.intensity); }
        for (const s of [-1, 1]) { const a = ang + s * half; FX.warnRail(R.back, L, V(L.x + Math.cos(a) * rad, L.y + Math.sin(a) * rad), { color: P.color, k: 0.15 + 0.3 * k, time: S.t, seed: 60 + s, rail: 0.6, intensity: 0.6 * P.intensity }); }
        R.front.glow(L.x, L.y, 8 + 10 * k, pal[3], 0.5 * k * P.intensity); }
      if (S.strikeT) { const t = (S.t - S.strikeT) / P.timing;
        if (t < 0.9) { // 地割れ：中心から扇の中へ枝分かれ、熱が冷えていく。土煙の波が扇の端まで走る
          // 地割れ：踏んだ点から扇の内側へ、ぎざぎざに枝分かれして走る。割れ目は熱く光ってから土色へ冷える
          const reach = clamp(t / 0.1), crack = FX.ramp('#ffb070'), dirt = FX.ramp('#8a6a4a');
          for (let q = 0; q < 5; q++) { let a = ang + (q / 4 - 0.5) * 2 * half * 0.85 + (hash(q * 5) - 0.5) * 0.2, x = L.x, y = L.y; const segs = 14, lenq = rad * (0.55 + 0.4 * hash(q + 9)); for (let s = 0; s < segs * reach; s++) { a += (hash(q * 17 + s) - 0.5) * 0.9; const st = lenq / segs, nx = x + Math.cos(a) * st, ny = y + Math.sin(a) * st; if (!inFan(Math.atan2(ny - L.y, nx - L.x), Math.hypot(nx - L.x, ny - L.y))) break; const w = Math.max(1, 2.6 * (1 - s / segs)); R.back.beam(x, y, nx, ny, w, t < 0.18 ? crack[4] : t < 0.45 ? crack[3] : dirt[1]); if (t < 0.5) R.back.light(nx, ny, crack[2], 0.35 * (1 - t / 0.5)); if (s === 5 && hash(q + 33) > 0.4) { let b = a + (hash(q) > 0.5 ? 0.7 : -0.7), bx = nx, by = ny; for (let k2 = 0; k2 < 4; k2++) { const ex = bx + Math.cos(b) * st, ey = by + Math.sin(b) * st; if (!inFan(Math.atan2(ey - L.y, ex - L.x), Math.hypot(ex - L.x, ey - L.y))) break; R.back.line(bx, by, ex, ey, t < 0.3 ? crack[3] : dirt[1]); bx = ex; by = ey; b += (hash(k2 + q * 3) - 0.5) * 0.8; } } x = nx; y = ny; } }
          for (let i = 0; i < 12; i++) { const lf = 0.55, q2 = t / lf; if (q2 > 1) continue; const a = ang + (hash(i * 3.1) - 0.5) * 2 * half, d = rad * 0.5 * q2 * (0.5 + hash(i)), hgt = 10 * Math.sin(Math.PI * q2); R.front.rect(L.x + Math.cos(a) * d - 1, L.y + Math.sin(a) * d - hgt - 1, 2, 2, dirt[2 + (i % 2)]); }
          const wave = rad * clamp(t / 0.22); for (let i = 0; i < 90; i++) { const a = ang + (hash(i * 5) - 0.5) * 2 * half, d = wave * (0.85 + 0.15 * hash(i)); if (d > rad) continue; R.back.disc(L.x + Math.cos(a) * d, L.y + Math.sin(a) * d, 1.2 + 2.5 * t, pal[2], (dd) => 0.4 * (1 - t) * (1 - dd * dd)); }
          if (t < 0.1) { R.front.circle(L.x, L.y, 4 * P.size, pal[4], 1 - t / 0.1); R.front.glow(L.x, L.y, rad * 0.5, pal[3], 0.6 * (1 - t / 0.1)); }
          FX.sparks(R.front, L, t, 88, 16, '#d8c7a8', 70, 0.5, ang, half);
        } }
      if (P.showHit && (B.mode === 'windup' || B.mode === 'strike')) { D2.arc(c, r.range_radius, ang - half, ang + half, 'rgba(120,255,160,.8)', px(1)); D2.line(c, add(c, mul(fromA(ang - half), r.range_radius)), 'rgba(120,255,160,.8)', px(1)); D2.line(c, add(c, mul(fromA(ang + half), r.range_radius)), 'rgba(120,255,160,.8)', px(1)); }
      R.blitBack();
    } else if (B.mode === 'windup' || B.mode === 'strike') { const pts = [c]; for (let j = 0; j < 25; j++) pts.push(add(c, mul(fromA(ang - half + half * 2 * j / 24), r.range_radius))); D2.poly(pts, rgba('#ff667d', B.mode === 'windup' ? 0.12 : 0.28)); if (B.mode === 'strike') D2.arc(c, r.range_radius * clamp((S.t - S.strikeT) / r.active), ang - half, ang + half, '#ff667d', 3); }
    drawCentaurus(B, B.pose); drawShip(S.ship);
    if (!R.proto) drawCenPresentationCurrent(B);
  },
});
function stompCenter(B) { const pose = samplePose('stomp', B.poseTime || 0); let c = V(0, 0); for (const [path, foot] of [['FrontLeftLeg', V(11.5, 52)], ['FrontRightLeg', V(7.5, 52)]]) { const L = partLocal(path, pose); c = add(c, M.pt(L.m, foot)); } c = mul(c, 0.5); const s = CEN_R / 135, a = B.facing - Math.PI / 2; return add(B.pos, V((c.x * Math.cos(a) - c.y * Math.sin(a)) * s, (c.x * Math.sin(a) + c.y * Math.cos(a)) * s)); }

// ---------- C09 矢の雨（現行の予兆を採用。変更なしの再現）
DEMOS.push({
  id: 'C09-rain-current', ids: ['C09'], cat: CEN_CAT, group: 'ケンタウルス座', title: '矢の雨（現行の予兆・矢をそのまま再現）', duration: 7.8, color: '#f2b567', cam: { x: 80, y: 0 },
  refs: [...CEN_REFS, 'data/bosses/centaurus_moves/rain.tres（warn 0.8・トレース4本・長さ900・速さ1200・間隔0.35・矢の間隔44・半径100・drop_delay 0.4・fall 0.3・linger 0.6）', 'technique_visual.gd _draw_rain・additional_technique_visual.gd draw_powder/draw_rain_arrow/fall_origin'],
  status: { '状態': '現行の再現のみ（最新指示により予兆は現行採用・新制作なし）', '試作': 'なし（「試作」表示でも現行と同じ絵）', 'モーション': '上向きに撃ち上げる・攻撃に応じた複数回射撃（C09）は移行後' },
  setup(S) { S.B = mkBoss(V(-300, 0), 0); S.ship = shipState(V(220, 40), 0, 300); S.B.technique = 'rain'; S.traces = []; S.rain = []; S.rng2 = mkRng(11); },
  step(S, dt) {
    const B = S.B, r = CEN.moves.rain, t = S.t - 0.2; S.ship.pos = add(S.ship.pos, mul(V(1, 0.15), 300 * dt)); if (S.ship.pos.x > 520) S.ship.pos.x = -200; S.ship.heading = Math.atan2(0.15, 1);
    if (B.mode === 'idle' && t >= 0 && !S.started) { B.mode = 'windup'; S.started = S.t; }
    if (B.mode === 'windup') { B.charge = clamp((S.t - S.started) / r.warn); B.facing = rotToward(B.facing, angOf(sub(S.ship.pos, B.pos)), CEN.def.turn * dt); if (S.t - S.started >= r.warn) { B.mode = 'rain'; B.left = r.traces; B.nextAt = S.t; } }
    if (B.mode === 'rain') {
      if (B.left > 0 && S.t >= B.nextAt) { const head = V(1, 0.15), start = add(S.ship.pos, mul(norm(head), r.forward)); const tr = { start, dir: norm(sub(S.ship.pos, start)), turn: S.traces.length % 2 ? -1 : 1, t0: S.t, next: 0, landed: 0 }; const R0 = r.trace_length / Math.abs(r.trace_bend), reach = 2 * R0 * Math.asin(Math.min(1, r.forward / (2 * R0))), pr = tracePoint(tr, reach, r); tr.dir = rot(tr.dir, angDiff(angOf(sub(S.ship.pos, start)), angOf(sub(pr, start)))); S.traces.push(tr); B.left--; B.nextAt = S.t + r.trace_length / r.trace_speed + r.trace_gap; }
      let all = true; for (const tr of S.traces) { const run = S.t - tr.t0, head = clamp(run * r.trace_speed, 0, r.trace_length); while (tr.next <= head) { const c = tracePoint(tr, tr.next, r); for (let k = 0; k < r.arrows_per_step; k++) { const a = S.rng2() * TAU, d = Math.sqrt(S.rng2()) * r.circle_radius; S.rain.push({ x: c.x + Math.cos(a) * d, y: c.y + Math.sin(a) * d, z: tr.t0 + tr.next / r.trace_speed + r.drop_delay }); } tr.next += r.arrow_gap; } tr.landed = clamp((run - r.drop_delay - r.fall) * r.trace_speed, 0, r.trace_length); if (tr.landed < r.trace_length) all = false; }
      S.rain = S.rain.filter(a => a.z + r.fall + r.linger + 0.15 >= S.t);
      if (B.left === 0 && all && !S.rain.length) { B.mode = 'recovery'; B.recovery = r.recover; }
    } else if (B.mode === 'recovery') { B.recovery -= dt; if (B.recovery <= 0) B.mode = 'idle'; }
    bossTick(B, dt);
  },
  phase(S) { const m = S.B.mode; return m === 'windup' ? PH.WINDUP : m === 'rain' ? '矢の雨' : m === 'recovery' ? '硬直' : PH.MOVE; },
  draw(S, R) {
    const B = S.B, r = CEN.moves.rain;
    drawCentaurus(B, B.pose); drawShip(S.ship);
    if (B.mode === 'rain' || B.mode === 'recovery') {
      for (const tr of S.traces) { const head = clamp((S.t - tr.t0) * r.trace_speed, 0, r.trace_length); if (head <= tr.landed) continue; const sp = Math.max(70, r.circle_radius); for (let i = Math.ceil(tr.landed / sp); i * sp <= head; i++) { const d = i * sp, age = S.t - tr.t0 - d / r.trace_speed; drawPowder(tracePoint(tr, d, r), r.circle_radius, age, clamp(age / 0.12), tr.t0 + i); } }
      const fan = CEN.moves.fan_volley;
      for (const a of S.rain) { const t = S.t - a.z; if (t < 0) continue; const f = clamp(t / r.fall), target = V(a.x, a.y), origin = fallOrigin(target, r.drop_height), ang = angOf(sub(target, origin)), at = lerpV(origin, target, f * f); let op = clamp(t / Math.max(Math.min(r.fade, 0.05), 0.001)); if (t > r.fall + r.linger) op *= clamp(1 - (t - r.fall - r.linger) / 0.15); drawArrow(at, ang, fan.radius, op, fan.length); if (t >= r.fall) drawPowder(target, 12, t, op * 0.4, a.z); }
    }
    drawCenPresentationCurrent(B);
  },
});
const rot = (v, a) => V(v.x * Math.cos(a) - v.y * Math.sin(a), v.x * Math.sin(a) + v.y * Math.cos(a));
function tracePoint(tr, s, r) { const bend = r.trace_bend; if (Math.abs(bend) < 0.001) return add(tr.start, mul(tr.dir, s)); const rad = r.trace_length / bend, nrm = mul(orth(tr.dir), tr.turn), c = add(tr.start, mul(nrm, rad)); return add(c, rot(sub(tr.start, c), -tr.turn * s / rad)); }
function fallOrigin(target, minH) { const sy = (target.y - cam.y) * Z + H / 2, oy = target.y - (sy + 160) / Z, o = V(target.x, oy), tw = norm(sub(target, o)); return sub(target, mul(tw, Math.max(dist(target, o), minH))); }
function scatter(seed, i) { const a = (((Math.sin(i * 127.1 + seed) * 43758.5453) % 1) + 1) % 1 * TAU, rr = Math.sqrt((((Math.sin(i * 269.5 + seed + 3) * 21563.734) % 1) + 1) % 1); return V(Math.cos(a) * rr, Math.sin(a) * rr); }
function drawPowder(center, radius, age, strength, salt = 0) { // additional_technique_visual.gd draw_powder
  const seed = center.x * 0.019 + center.y * 0.071 + salt, pix = Math.max(1, 1 / Z), fp = (v) => ((v % 1) + 1) % 1;
  for (let j = 0; j < 7; j++) { const q = fp(Math.sin(j * 127.1 + seed) * 43758.5453), u = fp(Math.sin(j * 269.5 + seed + 3) * 21563.734), cyc = fp(age * (0.8 + q * 0.5) + u), vr = fp(Math.sin(j * 91.7 + seed + 8) * 19463.17);
    const blink = Math.max(0, Math.sin(cyc * Math.PI)) ** (2 + vr * 2) * strength, at = sub(add(center, mul(scatter(seed, j), radius * 0.85)), V(0, (1 - cyc) * 26)), L = (5 + q * 10) * pix, wd = (0.65 + u * 0.8) * pix, op = blink * (0.25 + vr * 0.35), tail = sub(at, V((u - 0.5) * 2 * pix, L));
    for (let s = 0; s < 4; s++) { const f = (s + 1) / 4; D2.line(lerpV(tail, at, s / 4), lerpV(tail, at, f), rgba('#f2b567', op * f * f), wd * (0.3 + f * 0.7)); } }
}

// ---------- G10 プレイヤー → ボスの命中フィードバック
// 試作（体当たり）：接触した瞬間に世界ごと短く止め（ヒットストップ）、止まり終わりで機体をボスの反対側へ瞬間移動させる。
// 入った点と抜けた点（進路が本体の絵の縁と交わる点）で火花。間をつなぐ線は描かない。本番のヒットストップ値・機体の移動処理は変えない（試作の中だけの提案）。
// 進路が本体の絵（不透明な画素）に入る点と出る点。絵を別の画面へ描いて、直線に沿って調べる
function cenCut(B, from, dir) {
  const R = B.r * 2, size = Math.ceil(R * 2), cv2 = document.createElement('canvas'); cv2.width = cv2.height = size;
  const c = cv2.getContext('2d'); c.setTransform(1, 0, 0, 1, R - B.pos.x, R - B.pos.y); drawCentaurus(B, B.pose, { ctx: c });
  const px = c.getImageData(0, 0, size, size).data, solid = (q) => { const x = Math.floor(q.x - B.pos.x + R), y = Math.floor(q.y - B.pos.y + R); return x >= 0 && y >= 0 && x < size && y < size && px[(y * size + x) * 4 + 3] > 60; };
  let enter = null, exit = null; const L = dist(from, B.pos) + R;
  for (let d = 0; d <= L * 2; d += 1) { const q = add(from, mul(dir, d)); if (solid(q)) { if (!enter) enter = q; exit = q; } }
  return enter && { enter, exit };
}
DEMOS.push({
  id: 'G10-boss-hit', ids: ['G10'], cat: 'ボスへの命中 G10', group: 'プレイヤー→ボス', title: '体当たり：ヒットストップ→反対側へ抜ける', duration: 2.6, color: '#fff2c8', cam: { x: 0, y: 0 }, defaults: { size: 0.9, intensity: 0.9 },
  params: [{ k: 'hitstop', label: 'ヒットストップ(秒・試作内のみ)', type: 'range', min: 0, max: 0.15, step: 0.005, def: 0.11 }, { k: 'variant', label: '比較用：0=体当たり 1=弾', type: 'range', min: 0, max: 1, step: 1, def: 0 }],
  refs: [...CEN_REFS, 'scripts/bosses/boss_hit_feedback.gd（現行：白0.28を0.12秒・2.5pxの揺れ・0.0035radの傾き）', 'centaurus_presentation.gd hit（明るさ1.6倍を0.18秒）', 'scripts/render/ship_visual.gd（機体：airship.png、原画y=30が位置、×1.3）', 'pixelFX core（painter の火花・光）、explosions 系の火花と破片の飛び方'],
  status: { '状態': '試作のみ（2回目）', '対象': 'プレイヤーからボスへの命中。ボスからの攻撃や予兆ではない', 'ヒットストップ・瞬間移動': '試作の中だけの見せ方の提案。本番のヒットストップ値（G14/G15）と機体の移動・すり抜けの処理は変えていない。採用する場合は移行後に本番の処理として検討', '比較用操作': '体当たり／弾の切り替えは比較のための操作で、承認済みの仕様ではない' },
  setup(S) { S.B = mkBoss(V(0, 0), Math.PI * 0.9); S.ship = shipState(V(-900, 300), 0, 1500); S.hits = []; S.shots = []; S.B.mode = 'idle'; },
  step(S, dt) {
    const B = S.B, v = (PARAMS[demo.id]?.variant ?? 0) | 0, proto = mode === 'proto', hs = PARAMS[demo.id]?.hitstop ?? 0.11, reach = B.r + DATA.config.ship_radius;
    if (!v && proto) { // 試作：接触→ヒットストップ→反対側へ
      const dir = norm(V(1, -0.32)); S.ship.heading = angOf(dir); S.ship.speed = 1500;
      if (S.stopUntil != null && S.t < S.stopUntil) { B.hitPulse = 0.12; return; } // 世界ごと止める（ボスのアニメーションも進めない）
      if (S.stopUntil != null && !S.warped) { S.warped = true; S.ship.pos = { ...S.exitAt }; S.hits.push({ t: S.t, at: { ...S.cut.exit }, a: S.ship.heading, kind: 'out' }); }
      if (S.t > 0.3) { const before = { ...S.ship.pos }, next = add(before, mul(dir, 1500 * dt)), sr = DATA.config.ship_radius;
        if (S.cut === undefined && dist(next, B.pos) <= reach + 300) S.cut = cenCut(B, before, dir); // 当たり判定の円ではなく、見えている絵の縁で触れる
        const touch = S.cut && sub(S.cut.enter, mul(dir, sr)); // 機体の先端が絵の縁に届いたときの機体の中心
        if (S.stopUntil == null && touch && (next.x - touch.x) * dir.x + (next.y - touch.y) * dir.y >= 0) {
          S.ship.pos = touch; S.exitAt = add(S.cut.exit, mul(dir, sr + 4)); S.stopUntil = S.t + hs; B.hit = 0.18; S.hits.push({ t: S.t, at: { ...S.cut.enter }, a: S.ship.heading, kind: 'in' }); return; }
        S.ship.pos = next; }
    } else if (!v) { const dir = norm(V(1, -0.32)), before = { ...S.ship.pos }; if (S.t > 0.3) S.ship.pos = add(S.ship.pos, mul(dir, 1500 * dt)); S.ship.heading = angOf(dir); S.ship.speed = 1500;
      const inNow = dist(S.ship.pos, B.pos) <= reach, wasIn = dist(before, B.pos) <= reach; if (inNow && (S.lastTick == null || S.t - S.lastTick > 0.06)) { S.lastTick = S.t; B.hitPulse = 0.12; B.hit = 0.18; S.hits.push({ t: S.t, at: { ...S.ship.pos }, a: S.ship.heading, kind: 'tick' }); } if (!inNow && wasIn) S.hits.push({ t: S.t, at: { ...S.ship.pos }, a: S.ship.heading, kind: 'out' }); }
    else { S.ship.pos = V(-420, 160); S.ship.heading = angOf(sub(B.pos, S.ship.pos)); S.ship.speed = 0; if (S.t > 0.3 && (S.nextShot == null || S.t >= S.nextShot) && S.t < 2.0) { S.nextShot = S.t + 0.12; S.shots.push({ pos: { ...S.ship.pos }, a: S.ship.heading + (hash(S.t * 9) - 0.5) * 0.1 }); } for (const s of S.shots) { if (s.dead) continue; s.pos = add(s.pos, mul(fromA(s.a), 1400 * dt)); if (dist(s.pos, B.pos) < B.r * 0.85) { s.dead = 1; B.hitPulse = 0.12; B.hit = 0.18; S.hits.push({ t: S.t, at: { ...s.pos }, a: s.a, kind: 'shot' }); } } }
    B.hitPulse = Math.max(0, (B.hitPulse || 0) - dt); bossTick(B, dt);
  },
  phase(S) { if (S.stopUntil != null && S.t < S.stopUntil) return 'ヒットストップ'; const last = S.hits[S.hits.length - 1]; return last && S.t - last.t < 0.3 ? (last.kind === 'out' ? '反対側へ抜けた' : '命中') : S.hits.length ? '通過後' : '接近'; },
  draw(S, R) {
    const B = S.B, P = R.P, strength = (B.hitPulse || 0) / 0.12, ph = B.clock * 86;
    const jitter = R.proto ? V(0, 0) : mul(V(Math.sin(ph), Math.cos(ph * 1.17)), 2.5 * strength * 0.7071 / Z);
    const body = { ...B, pos: add(B.pos, jitter) };
    let white = R.proto ? 0 : 0.28 * strength + (B.hit > 0 ? 0.25 : 0);
    const stopEnd = S.stopUntil ?? Infinity, stopping = S.stopUntil != null && S.t < S.stopUntil;
    if (R.proto) { const hitIn = S.hits.find(h => h.kind === 'in' || h.kind === 'shot'), last = S.hits.filter(h => h.kind === 'shot').slice(-1)[0] || hitIn;
      if (last) { const t = stopping ? 0 : (S.t - Math.max(last.t, last.kind === 'in' ? stopEnd : last.t)) / P.timing; white = (stopping ? 0.7 : t < 0.12 ? 0.45 * (1 - t / 0.12) : 0) * P.intensity; } }
    drawCentaurus(body, B.pose, { white });
    for (const s of S.shots) if (!s.dead) { D2.line(s.pos, sub(s.pos, mul(fromA(s.a), 26)), 'rgba(160,220,255,.9)', 5); }
    drawShip(S.ship);
    if (!R.proto) return;
    const pal = FX.ramp(P.color), hitIn = S.hits.find(h => h.kind === 'in'), hitOut = S.hits.find(h => h.kind === 'out');
    if (hitIn) { const A = toL(hitIn.at);
      if (stopping) { // 止まっている間：接触点の閃光（形は光と短い光条だけ）
        const Lr = 10 * P.size; for (const a of [hitIn.a + Math.PI / 2, hitIn.a - Math.PI / 2, hitIn.a + Math.PI * 0.8, hitIn.a - Math.PI * 0.8]) R.front.line(A.x, A.y, A.x + Math.cos(a) * Lr, A.y + Math.sin(a) * Lr, (u) => u < 0.4 ? pal[4] : pal[3], (u) => 1 - u);
        R.front.glow(A.x, A.y, 22 * P.size, pal[3], P.intensity); R.front.glow(A.x, A.y, 8, pal[4], P.intensity); }
      else { const t = (S.t - stopEnd) / P.timing; // 止まり終わり：入った点から手前側と横へ火花がはじける
        FX.sparks(R.front, A, t, 3, 26, P.color, 85, 0.4, hitIn.a + Math.PI, 1.3); if (t < 0.1) R.front.glow(A.x, A.y, 16 * P.size, pal[3], (1 - t / 0.1) * P.intensity); } }
    if (hitOut) { const t = (S.t - hitOut.t) / P.timing, E = toL(hitOut.at); // 抜けた点：進む向きへ火花と装甲片
      FX.sparks(R.front, E, t, 7, 30, P.color, 110, 0.5, hitOut.a, 0.75);
      for (let i = 0; i < 10; i++) { const q = t / 0.6; if (q > 1) continue; const a = hitOut.a + (hash(i) - 0.5) * 1.4, d = 46 * q * (0.6 + hash(i + 2)), x = E.x + Math.cos(a) * d, y = E.y + Math.sin(a) * d + 16 * q * q; R.front.rect(x - 1, y - 1, 2, 2, hexc('#5a6f93'), 1); R.front.px(x - 1, y - 1, hexc('#c7a24a')); }
      if (t < 0.1) { R.front.glow(E.x, E.y, 24 * P.size, pal[3], (1 - t / 0.1) * P.intensity); R.front.glow(E.x, E.y, 8, pal[4], (1 - t / 0.1) * P.intensity); } }
    for (const h of S.hits) if (h.kind === 'shot') { const t = (S.t - h.t) / P.timing; if (t > 0.3) continue; const A = toL(h.at); FX.sparks(R.front, A, t, h.t * 13, 8, P.color, 50, 0.25, h.a + Math.PI, 1.2); if (t < 0.08) R.front.glow(A.x, A.y, 10, pal[4], 0.8 * P.intensity); }
  },
});
