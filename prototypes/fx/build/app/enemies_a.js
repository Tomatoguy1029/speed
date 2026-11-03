// ===== G12：ステージ1に出ない敵の固有攻撃（前半） =====
// 各デモは現行の行動スクリプトの状態遷移・数値（data/enemies/*.tres の params）をそのまま進め、
// 「現行」は render/enemies/*.gd・render/attacks/*.gd の描画命令を移植、「試作」は見た目だけを差し替える。
function mkE(type, pos, facing, extra = {}) { return { type, pos: { ...pos }, facing, r: enemyR(type), mode: 'MOVE', timer: 0, charge: 0, fire_t: 0, buds: 0, vel: V(0, 0), flash: 0, ...extra }; }
const prm = (type) => enemyDef(type).params;
const ecol = (type, k = 0) => lighten(enemyColor(type), k);
function shipState(pos, heading = -Math.PI / 2, speed = 0) { return { pos, heading, speed }; }
function turnToward(e, ang, rate, dt) { e.facing = rotToward(e.facing, ang, rate * dt); }
const G12 = '敵（ステージ1以外）G12';
const LASER = '#ff4a3d';
function phaseLabel(e, map) { return map[e.mode] || ''; }
const PH = { MOVE: '移動／待機', WINDUP: '予備動作（予告）', DASH: '攻撃中', RECOVER: '終了・硬直' };

// ---------- ビームの敵（beamer）
DEMOS.push({
  id: 'G12-beamer', ids: ['G12'], cat: G12, group: 'ビームの敵（beamer）', title: '砲口の溜め→ビーム', duration: 3.2, color: LASER, cam: { x: -60, y: 30 },
  refs: ['scripts/enemies/beamer.gd（溜め・発射の時刻）', 'scripts/render/enemies/beamer.gd・render/attacks/beam_guide.gd・beam.gd（現行の描画）', 'data/enemies/beamer.tres params（telegraph 0.9 / beam_time 0.35 / 幅22 / 長さ2200）', 'pixelFX arcane-beam.js の帯分け・発射元フレア、shaders/marlin_warning.gdshader の芯＋平行光＋光の包み'],
  params: [{ k: 'travel', label: '発射：先端が届くまで(秒)', type: 'range', min: 0, max: 0.3, step: 0.01, def: 0.1 }],
  status: { '状態': '試作のみ（本番未変更）', '判定': '変更なし。ビーム本体の帯（白〜主色）は幅22の判定幅に合わせ、外側は光（加算）だけ', '照準': '機体と交わったらそこで止まる。溜めの終わりでも白くならない（主色まで）', '発射': '先端が砲口から伸び（時間はつまみで調整）、終わりは砲口の側から消える。両端はとがらせる。判定の時刻と長さは変えていない' },
  setup(S) { S.e = mkE('beamer', V(-420, -40), 0, { fire_t: 0.5 }); S.ship = shipState(V(280, 110)); S.e.facing = angOf(sub(S.ship.pos, S.e.pos)); },
  step(S, dt) {
    const e = S.e, p = prm('beamer'); S.ship.pos.y = 110 + Math.sin(S.t * 1.3) * 30;
    if (e.mode === 'MOVE') { e.fire_t -= dt; if (e.fire_t <= 0) { const a = angOf(sub(S.ship.pos, e.pos)); e.facing = a; e.mode = 'WINDUP'; e.timer = p.telegraph + p.beam_time; S.hz = [{ p: add(e.pos, mul(fromA(a), e.r)), a, len: p.beam_len, w: p.beam_width, delay: p.telegraph, active: p.beam_time, t0: S.t }]; } return; }
    e.timer -= dt; e.charge = clamp(1 - (e.timer - p.beam_time) / p.telegraph);
    if (e.timer <= 0) { e.mode = 'MOVE'; e.fire_t = 99; e.charge = 0; S.endAt = S.t; }
  },
  phase(S) { const e = S.e; if (e.mode === 'WINDUP') return e.charge < 1 ? PH.WINDUP : PH.DASH; return S.endAt ? PH.RECOVER : PH.MOVE; },
  draw(S, R) {
    const e = S.e, P = R.P, col = ecol('beamer', 0.3);
    for (const h of S.hz) {
      const t = S.t - h.t0, k = clamp(t / h.delay), b = add(h.p, mul(fromA(h.a), h.len)), on = t >= h.delay && t <= h.delay + h.active;
      if (!R.proto) {
        if (t < h.delay) { D2.line(h.p, b, rgba(col, 0.2 + 0.5 * k), px(1.5)); D2.circle(h.p, px(4) + 10 * k, rgba(col, 0.25 + 0.5 * k)); }
        else if (on) { const f = 1 - clamp((t - h.delay) / h.active) * 0.6; D2.line(h.p, b, rgba(col, 0.35 * f), h.w * 1.6); D2.line(h.p, b, rgba(col, 0.9 * f), h.w); D2.line(h.p, b, rgba('#fff', 0.85 * f), Math.max(px(2), h.w * 0.3)); }
      } else {
        const tt = t * P.timing;
        const hitT = segCircleT(h.p, b, S.ship.pos, DATA.config.ship_radius), aimEnd = hitT >= 0 ? lerpV(h.p, b, hitT) : b; // 照準は機体で止まる
        const travel = Math.max(0.001, (P.travel ?? 0.1) * P.timing);
        if (t < h.delay) { FXW.warnRail(R.back, h.p, aimEnd, { color: P.color, k, time: S.t, seed: 3, intensity: P.intensity, maxLv: 2 }); FXW.gather(R.front, h.p, e.r * 2.2 * P.size, k * P.intensity, P.color, S.t, 16, 5); }
        else if (on) { const tf = t - h.delay, u = tf / h.active, left = h.active - tf, head = Math.min(1, smooth(0, travel, tf) * 1.0001), tail = left < travel ? smooth(travel, 0, left) : 0; // 先端が伸び、終わりは根元から消える
          if (head > tail) FXW.beam(R.front, h.p, b, { color: P.color, w: h.w / 2, time: S.t, alpha: Math.min(1, P.intensity), from: tail, to: head, taper: 10 * P.size, source: tail <= 0 });
          if (tf < travel * 1.5) FXW.flare(R.front, h.p, 12 * P.size, P.color, S.t, 1 - tf / (travel * 1.5), 6); }
        else if (t > h.delay + h.active && t < h.delay + h.active + 0.3 * P.timing) FXW.sparks(R.front, h.p, t - h.delay - h.active, 4, 8, P.color, 30, 0.3);
      }
    }
    if (R.proto) R.blitBack();
    drawEnemy(e); drawShip(S.ship);
    if (!R.proto && e.mode === 'WINDUP') { // render/enemies/beamer.gd draw_marks
      const r = e.r, mz = add(e.pos, mul(fromA(e.facing), r * 0.9)), k = e.charge, c2 = ecol('beamer', 0.35);
      if (k < 1) { for (let n = 0; n < 8; n++) { const f = (k * 2.5 + n / 8) % 1; D2.circle(add(mz, mul(fromA(n * TAU / 8 + k * 3), r * (1.8 - 1.6 * f))), Math.max(px(1.5), r * 0.08), rgba(c2, f)); } D2.circle(mz, px(2) + r * 0.45 * k, rgba(c2, 0.25 + 0.5 * k)); D2.circle(mz, px(1.5) + r * 0.2 * k, rgba('#fff', 0.5 + 0.5 * k)); }
      else { D2.circle(mz, r * 0.7, rgba('#fff', 0.55)); D2.circle(mz, r * 0.45, rgba(c2, 0.9)); }
    }
  },
});

// ---------- かに座（crab）：ユーザー指示「範囲を実攻撃に合わせて狭める・後ろからすぐ消さず少し残す・予兆をハサミ固有に」
DEMOS.push({
  id: 'G12-crab', ids: ['G12'], cat: G12, group: 'かに座（crab）', title: 'ハサミの薙ぎ', duration: 3.4, color: '#ff8a4a', cam: { x: 40, y: 0 }, bg: 'asteroid_a',
  params: [{ k: 'linger', label: '斬撃の残る時間(秒)', type: 'range', min: 0.15, max: 1.0, step: 0.01, def: 0.45 }, { k: 'showHit', label: '判定円を重ねる(0/1)', type: 'range', min: 0, max: 1, step: 1, def: 0 },
    { k: 'reachR', label: '試作：斬撃の半径(×体の半径・本体中心から)', type: 'range', min: 1.0, max: 3.0, step: 0.05, def: 1.5 }, { k: 'hitR', label: '試作：判定円の半径(×体の半径)', type: 'range', min: 0.5, max: 3.0, step: 0.05, def: 1.0 }],
  refs: ['scripts/enemies/crab.gd（横歩き・approach・telegraph 0.6・fire_zone(sweep_center, reach×0.6)・open_time 1.4）', 'scripts/render/enemies/crab.gd（現行の予告円・ハサミの丸・振りの弧）', 'render/attacks/zone.gd（判定の閃き ZONE_FLASH 0.25s）', 'pixelFX melee/sword-slash.js（白→色へ冷える三日月）、painter.js'],
  status: { '状態': '試作のみ（作り直し2回目）', '位置と判定': '斬撃はハサミのある前側・体の近くに出す。試作の判定円（前側、半径はつまみ）もそこに置く。本番の判定は歩く向きの横（sweep_center、半径180）なので、合わせるには移行後に行動の処理の変更が要る', '予兆': '開く→途中で止める→もう一度振りかぶる→一気に閉じる。予告0.6秒と攻撃全体の時間は変えない', '前回指摘への対応': '斬撃は後端から消さず全体を残光でフェード（残る時間は調整値）／予兆はハサミの開きと爪先の光で示す' },
  setup(S) { const p = prm('crab'); S.e = mkE('crab', V(-520, 40), -Math.PI / 2, { buds: 1 }); S.ship = shipState(V(180, 40 - S.e.r * (P().reachR ?? 1.5))); },
  step(S, dt) {
    const e = S.e, p = prm('crab'), walk = mul(fromA(e.facing + Math.PI / 2), e.buds < 0 ? -1 : 1), PP = P();
    const center = add(e.pos, mul(walk, e.r + p.reach * 0.5)), rad = p.reach * 0.6; S.sweep = { center, rad, walk };
    S.front = { center: add(e.pos, mul(fromA(e.facing), e.r * PP.reachR)), rad: e.r * PP.hitR }; // 試作：ハサミの前・体の近く
    const zone = mode === 'proto' ? S.front : S.sweep;
    if (e.mode === 'MOVE') {
      if (dist(zone.center, S.ship.pos) <= zone.rad && dist(e.pos, S.ship.pos) <= p.approach) { e.mode = 'WINDUP'; e.timer = p.telegraph; e.charge = 0; }
      else e.pos = add(e.pos, mul(walk, enemyDef('crab').speed * dt));
    } else if (e.mode === 'WINDUP') { e.timer = Math.max(0, e.timer - dt); e.charge = clamp(1 - e.timer / p.telegraph); if (e.timer <= 0) { S.zone = { ...zone, t0: S.t }; e.mode = 'RECOVER'; e.timer = p.open_time; e.charge = 0; } }
    else if (e.mode === 'RECOVER') { e.timer -= dt; if (e.timer <= 0) { e.mode = 'MOVE'; e.pos = add(e.pos, V(0, 0)); S.done = 1; } }
  },
  phase(S) { return S.done ? PH.RECOVER : PH[S.e.mode]; },
  draw(S, R) {
    const e = S.e, P = R.P, p = prm('crab'), col = ecol('crab', 0.3), sw = S.sweep;
    const toward = angOf(sw.walk);
    if (R.proto) {
      // ハサミの軌跡：体の前（向き e.facing）で、外側 ±OPEN から中央 ±0.03 へ閉じる。爪先の角度 claw(k) は
      // 開く（0〜0.45）→止める（〜0.7）→もう一度振りかぶる（〜1.0）→ 予告の終わりで一気に閉じる
      const k = e.charge, R0 = e.r * P.reachR * P.size, OPEN = 1.25, HOLD = 0.6, BACK = 0.9, fwd = e.facing;
      const claw = (k) => k < 0.45 ? lerp(OPEN, HOLD, smooth(0, 0.45, k)) : k < 0.7 ? HOLD : lerp(HOLD, BACK, smooth(0.7, 1, k));
      const headOf = (ang) => (OPEN - ang) / (OPEN - 0.03);
      if (e.mode === 'WINDUP') {
        const ang = claw(k);
        for (const s of [-1, 1]) {
          const tip = add(e.pos, mul(fromA(fwd + s * ang), R0));
          FXW.gather(R.front, tip, e.r * 0.7, k * P.intensity, P.color, S.t + s, 7, 11 + s);
          FXW.crescent(R.back, e.pos, R0, fwd + s * OPEN, fwd + s * 0.03, headOf(ang), 0, 4, P.color, 0.3 + 0.4 * k * P.intensity);
        }
      }
      if (S.zone) {
        const t = S.t - S.zone.t0, sweepT = 0.12, linger = P.linger * P.timing;
        if (t < sweepT + linger) {
          const h0 = headOf(BACK), head = lerp(h0, 1, smooth(0, sweepT, t)), fade = t < sweepT ? 1 : 1 - smooth(0, 1, (t - sweepT) / linger), tail = t < sweepT ? 0 : 0.25 * (t - sweepT) / linger; // 振りかぶった所から続けて閉じる
          for (const s of [-1, 1]) FXW.crescent(R.front, e.pos, R0, fwd + s * OPEN, fwd + s * 0.03, head, tail, 22 * P.size, P.color, fade * Math.min(1, P.intensity));
          if (t < 0.4) FXW.sparks(R.front, add(e.pos, mul(fromA(fwd), R0)), t - 0.08, 21, 14, '#ffe2b0', 60, 0.35, fwd, 1.2);
        }
      }
      if (P.showHit && (e.mode === 'WINDUP' || S.zone && S.t - S.zone.t0 < 0.25)) { D2.arc(S.front.center, S.front.rad, 0, TAU, 'rgba(120,255,160,.8)', px(1)); }
      R.blitBack();
    }
    drawEnemy(e); drawShip(S.ship);
    if (!R.proto) { // render/enemies/crab.gd draw_marks
      if (e.mode === 'WINDUP') { const k = e.charge; D2.circle(sw.center, sw.rad, rgba(col, 0.04 + 0.08 * k)); D2.arc(sw.center, sw.rad, 0, TAU, rgba(col, 0.35 + 0.4 * k), px(1.5)); for (const s of [-1, 1]) D2.circle(add(e.pos, mul(fromA(toward + s * 0.7), e.r)), e.r * (0.12 + 0.3 * k), rgba(col, 0.3 + 0.5 * k)); }
      else if (e.mode === 'RECOVER') { const el2 = p.open_time - e.timer, k = clamp(el2 / 0.25); if (k < 1) for (const s of [-1, 1]) { const a = toward + s * lerp(1.5, 0.1, k); D2.arc(sw.center, sw.rad * 0.9, a - 0.35, a + 0.35, rgba(col, 1 - k), px(4)); } }
      if (S.zone && S.t - S.zone.t0 < 0.25) { const f = 1 - (S.t - S.zone.t0) / 0.25; D2.circle(S.zone.center, S.zone.rad, rgba(col, 0.45 * f)); D2.arc(S.zone.center, S.zone.rad, 0, TAU, rgba('#fff', 0.8 * f), px(3)); }
    }
  },
});

// ---------- やまねこ座（lynx）
const SLASH = { TALL: 0.48, STEP: 0.15, STRETCH: 0.22, INNER: 0.12, THICK: 0.07, FROM: -100 * Math.PI / 180, RISE: 16 * Math.PI / 180, N: 16 };
function slashPts(pos, ang, size, side, k) { // scripts/attacks/slash.gd slash_local / slash_points
  const a = 1 + SLASH.STEP * k, b = SLASH.TALL + (SLASH.STEP + SLASH.STRETCH) * k, c = V(SLASH.INNER, SLASH.TALL + SLASH.STRETCH * k);
  const u = fromA(ang), across = mul(orth(u), side), out = [];
  for (let n = 0; n <= SLASH.N; n++) { const phi = lerp(SLASH.FROM, SLASH.RISE * k, n / SLASH.N); const l = V(c.x + a * Math.cos(phi), c.y + b * Math.sin(phi)); out.push(add(pos, mul(sub(mul(across, l.x), mul(u, l.y)), size))); }
  return out;
}
function drawClawsCur(pos, travel, size, side, a) { // render/attacks/slash.gd draw_claws
  const th = SLASH.THICK * size;
  for (let k = 0; k < 3; k++) { const pts = slashPts(pos, travel, size, side, k); D2.polyline(pts, `rgba(255,115,38,${0.28 * a})`, th * 2.2); D2.polyline(pts, `rgba(255,140,56,${0.95 * a})`, th); D2.polyline(pts.slice(1, -1), `rgba(255,242,217,${a})`, Math.max(px(1.5), th * 0.3)); }
}
// 試作の爪痕：3本の平行な刃。両端がとがり中央が太い三日月を、楕円の弧（slash.gd と同じ中心と半径の比）に沿って塗る。
// 弧は進む向きの先端から片側（side）へ span だけ回り込む。白い芯→主色の縁。scale で大きさ、reveal で先端から描かれる割合
function lynxBlade(p, pos, travel, size, side, k, span, reveal, pal, a, dim = 0) {
  const u = fromA(travel), across = mul(orth(u), side), ax = 1 + SLASH.STEP * k, ay = SLASH.TALL + (SLASH.STEP + SLASH.STRETCH) * k;
  const C = add(pos, mul(sub(mul(across, SLASH.INNER), mul(u, SLASH.TALL + SLASH.STRETCH * k)), size)), sp = span + 0.2 * k, n = Math.max(12, Math.round(sp * ax * size * WL * 0.9));
  const th = SLASH.THICK * size * WL * 1.15, pt = (f) => { const phi = -Math.PI / 2 + sp * f; return toL(add(C, mul(add(mul(across, ax * Math.cos(phi)), mul(u, -ay * Math.sin(phi))), size))); };
  for (let i = 0; i < n * reveal; i++) {
    const f = i / n, A = pt(f), B = pt(Math.min(reveal, (i + 1) / n)), w = th * Math.pow(Math.sin(Math.PI * Math.min(1, f + 0.5 / n)), 0.7), nx = -(B.y - A.y), ny = B.x - A.x, nl = Math.hypot(nx, ny) || 1;
    for (let q = -w; q <= w; q += 0.5) { const e = Math.abs(q) / Math.max(w, 0.01), lv = Math.max(0, (e < 0.35 ? 4 : e < 0.7 ? 3 : 2) - dim); p.dot(A.x + nx / nl * q, A.y + ny / nl * q, pal[lv], a); }
    if (i % 3 === 0 && !dim) p.light(A.x, A.y, pal[2], 0.3 * a);
  }
}
function drawClawsProto(R, pos, travel, size, side, a, P, span, reveal = 1, trail = 0) {
  const pal = FX.ramp(P.color);
  for (let s = trail; s >= 1; s--) for (let k = 0; k < 3; k++) lynxBlade(R.front, sub(pos, mul(fromA(travel), size * 0.09 * s)), travel, size, side, k, span, reveal, pal, a * (0.45 - 0.12 * s), 2); // 後ろへ流れる残像
  for (let k = 0; k < 3; k++) lynxBlade(R.front, pos, travel, size, side, k, span, reveal, pal, a);
}
DEMOS.push({
  id: 'G12-lynx', ids: ['G12'], cat: G12, group: 'やまねこ座（lynx）', title: '爪痕の斬撃（左右交互）', duration: 4.6, color: '#ff8a38', cam: { x: -40, y: 0 },
  refs: ['scripts/enemies/lynx.gd・enemy_motion.gd _gun_timer（fire_interval 0.9、telegraph 0.35 で charge）', 'scripts/attacks/slash.gd（爪痕の形・太さ＝判定）', 'scripts/render/attacks/slash.gd・render/enemies/lynx.gd（現行描画）', 'pixelFX painter.beam・melee/dagger-flurry.js の白い芯と火花'],
  params: [{ k: 'span', label: '試作：1本の弧の角度(度)', type: 'range', min: 60, max: 180, step: 1, def: 110 }, { k: 'grow', label: '試作：最大の大きさまでの時間(秒)', type: 'range', min: 0.05, max: 1.2, step: 0.01, def: 0.35 }, { k: 'start', label: '試作：発射時の大きさ(倍)', type: 'range', min: 0.15, max: 1, step: 0.01, def: 0.3 }],
  status: { '状態': '試作のみ（作り直し）', '形': '3本の平行な刃（両端がとがった三日月、白い芯→主色）。進む向きの先端から片側へ回り込む弧で、左右交互。弧の角度はつまみ', '大きさ': '手元の小さな大きさで発射し、最大まで段階的に大きくなる（時間はつまみ）。本番の判定は発射の瞬間から最大なので、合わせるには移行後に判定の処理の変更が要る', '判定': '速さ380・直進・追尾なしは変えていない' },
  setup(S) { S.e = mkE('lynx', V(-520, -60), 0, { fire_t: 0.6 }); S.ship = shipState(V(260, 90)); S.shots = []; },
  step(S, dt) {
    const e = S.e, p = prm('lynx'); S.ship.pos.y = 90 + Math.sin(S.t * 0.9) * 60;
    turnToward(e, angOf(sub(S.ship.pos, e.pos)), enemyDef('lynx').turn, dt);
    e.fire_t -= dt; e.charge = e.fire_t < p.telegraph ? 1 - Math.max(0, e.fire_t) / p.telegraph : 0;
    if (e.fire_t <= 0 && S.t < 3.2) { e.fire_t = p.fire_interval; const side = e.buds % 2 === 0 ? 1 : -1; e.buds++; const a = angOf(sub(S.ship.pos, e.pos)); S.shots.push({ pos: add(e.pos, mul(fromA(a), e.r)), a, side, t0: S.t }); }
    else if (S.t >= 3.2) e.charge = 0;
    for (const s of S.shots) s.pos = add(s.pos, mul(fromA(s.a), p.slash_speed * dt));
  },
  phase(S) { return S.e.charge > 0 ? PH.WINDUP : S.shots.length ? PH.DASH : PH.MOVE; },
  draw(S, R) {
    const e = S.e, P = R.P, p = prm('lynx'), side = e.buds % 2 === 0 ? 1 : -1;
    drawEnemy(e); drawShip(S.ship);
    const span = (P.span ?? 110) * Math.PI / 180, g0 = P.start ?? 0.3, grow = Math.max(0.01, (P.grow ?? 0.35) * P.timing);
    for (const s of S.shots) { const age = S.t - s.t0; if (R.proto) drawClawsProto(R, s.pos, s.a, p.slash_size * P.size * lerp(g0, 1, smooth(0, grow, age)), s.side, Math.min(1, P.intensity), P, span, smooth(0, 0.08 * P.timing, age) * 0.999 + 0.001, 3); else drawClawsCur(s.pos, s.a, p.slash_size, s.side, 1); }
    const k = e.charge; if (k <= 0) return;
    const u = fromA(e.facing), paw = add(add(e.pos, mul(u, e.r * 0.55)), mul(orth(u), side * e.r * 0.6));
    if (!R.proto) { D2.circle(paw, e.r * (0.25 + 0.35 * k), `rgba(255,140,51,${0.25 * k})`); drawClawsCur(paw, e.facing, e.r * (0.5 + 0.5 * k), side, 0.3 + 0.7 * k); }
    else { const mouth = add(e.pos, mul(u, e.r)); drawClawsProto(R, mouth, e.facing, p.slash_size * P.size * g0 * (0.6 + 0.4 * k), side, 0.25 + 0.6 * k, P, span, 0.15 + 0.85 * k); FXW.sparks(R.front, mouth, (S.t * 3) % 0.3, 31 + e.buds, 5, P.color, 25, 0.3); } // 発射する位置で、発射時の大きさまで爪を溜める
  },
});

// ---------- みなみじゅうじ座（cross）
DEMOS.push({
  id: 'G12-cross', ids: ['G12'], cat: G12, group: 'みなみじゅうじ座（cross）', title: '十字レーザー', duration: 2.6, color: '#ffd27a', cam: { x: 0, y: -160 },
  refs: ['scripts/enemies/cross.gd（整列→telegraph 0.8→照射 0.5→rest 0.5、線は常に縦横）', 'scripts/attacks/cross.gd（4本の fire_beam）', 'render/enemies/cross.gd（現行は点線の予告）・render/attacks/beam.gd', 'marlin_warning.gdshader、pixelFX arcane-beam.js'],
  status: { '状態': '試作のみ', '判定': '変更なし（幅26・長さ1600の4本）。予告は点線を使わず途切れない光線' },
  setup(S) { S.e = mkE('cross', V(0, -380), 0, { fire_t: 0.3 }); S.ship = shipState(V(0, 0)); },
  step(S, dt) {
    const e = S.e, p = prm('cross');
    if (e.mode === 'MOVE') { e.facing += dt * 1.5; e.fire_t -= dt; if (e.fire_t <= 0) { e.mode = 'WINDUP'; e.timer = p.telegraph; e.facing = 0; S.beam = { t0: S.t, delay: p.telegraph, active: p.beam_time }; } }
    else if (e.mode === 'WINDUP') { e.timer -= dt; e.charge = 1 - Math.max(0, e.timer) / p.telegraph; if (e.timer <= 0) { e.charge = 0; e.mode = 'RECOVER'; e.timer = p.beam_time + p.rest; } }
    else if (e.mode === 'RECOVER') { e.timer -= dt; if (e.timer <= 0) { e.mode = 'MOVE'; e.fire_t = 99; S.done = 1; } }
  },
  phase(S) { const e = S.e; return e.mode === 'RECOVER' ? (S.t - S.beam.t0 < S.beam.delay + S.beam.active ? PH.DASH : PH.RECOVER) : (S.done ? PH.RECOVER : PH[e.mode]); },
  draw(S, R) {
    const e = S.e, P = R.P, p = prm('cross'), col = ecol('cross', 0.2), bcol = ecol('cross', 0.3);
    if (R.proto) {
      if (e.mode === 'WINDUP') { const k = e.charge, L = p.beam_len * (0.25 + 0.75 * k); for (let q = 0; q < 4; q++) FXW.warnRail(R.back, e.pos, add(e.pos, mul(fromA(q * Math.PI / 2), L)), { color: P.color, k, time: S.t, seed: q + 1, intensity: P.intensity }); FXW.gather(R.front, e.pos, e.r * 2.4 * P.size, k * P.intensity, P.color, S.t, 18, 3); }
      if (S.beam) { const t = S.t - S.beam.t0; if (t >= S.beam.delay && t <= S.beam.delay + S.beam.active) { const u = (t - S.beam.delay) / S.beam.active, a = (1 - smooth(0.75, 1, u)) * P.intensity; for (let q = 0; q < 4; q++) FXW.beam(R.front, e.pos, add(e.pos, mul(fromA(q * Math.PI / 2), p.beam_len)), { color: P.color, w: p.beam_width / 2, time: S.t + q, alpha: Math.min(1, a), source: false }); FXW.flare(R.front, e.pos, 16 * P.size, P.color, S.t, Math.min(1, a), 4); } else if (t > S.beam.delay + S.beam.active && t < S.beam.delay + S.beam.active + 0.25 * P.timing) { const f = 1 - (t - S.beam.delay - S.beam.active) / (0.25 * P.timing); for (let q = 0; q < 4; q++) FXW.warnRail(R.back, e.pos, add(e.pos, mul(fromA(q * Math.PI / 2), p.beam_len * 0.6)), { color: P.color, k: 0.2, time: S.t, seed: 7 + q, intensity: f * P.intensity, rail: 1 }); } }
      R.blitBack();
    } else if (S.beam) { // render/attacks/beam.gd（照射）
      const t = S.t - S.beam.t0;
      if (t < S.beam.delay) D2.circle(e.pos, px(4) + 10 * clamp(t / S.beam.delay), rgba(bcol, 0.25 + 0.5 * clamp(t / S.beam.delay)));
      else if (t <= S.beam.delay + S.beam.active) { const f = 1 - clamp((t - S.beam.delay) / S.beam.active) * 0.6; for (let q = 0; q < 4; q++) { const b = add(e.pos, mul(fromA(q * Math.PI / 2), p.beam_len)); D2.line(e.pos, b, rgba(bcol, 0.35 * f), p.beam_width * 1.6); D2.line(e.pos, b, rgba(bcol, 0.9 * f), p.beam_width); D2.line(e.pos, b, rgba('#fff', 0.85 * f), Math.max(px(2), p.beam_width * 0.3)); } }
    }
    drawEnemy(e); drawShip(S.ship);
    if (!R.proto && e.mode === 'WINDUP') { const k = e.charge, L = p.beam_len * (0.25 + 0.75 * k); for (let q = 0; q < 4; q++) { const u = fromA(q * Math.PI / 2); for (let s = 0; s < L; s += 36) D2.line(add(e.pos, mul(u, s)), add(e.pos, mul(u, Math.min(s + 20, L))), rgba(col, 0.2 + 0.5 * k), Math.max(px(1.5), 2 + 3 * k)); } D2.circle(e.pos, e.r * (0.4 + 0.5 * k), `rgba(255,255,230,${0.35 + 0.5 * k})`); }
  },
});

// ---------- いるか座（dolphin）
// 波動の帯：弧に沿って塗り、両端は細くとがらせる（丸を付けない）。外側（進む側）の縁だけ明るく、内側は暗く
function waveBand(p, L, r, a0, a1, w, cols, alpha) {
  if (r <= 0 || w <= 0) return; const n = Math.max(8, Math.round((a1 - a0) * r * 2));
  for (let i = 0; i <= n; i++) {
    const u = i / n, an = a0 + (a1 - a0) * u, tp = Math.pow(Math.min(1, Math.min(u, 1 - u) / 0.22), 0.75), ww = w * tp; if (ww < 0.3) continue;
    const c = Math.cos(an), sn = Math.sin(an);
    for (let q = -ww; q <= ww; q += 0.5) { const e = q / ww; p.dot(L.x + c * (r + q), L.y + sn * (r + q), e > 0.55 ? cols.edge : e > -0.45 ? cols.body : cols.inner, alpha); }
  }
}
function waveArc(R, pos, rad, a0, a1, w, color, alpha, t) { // 現行（wave.gd RIPPLE）と同じ並び：当たる先頭の帯＋後ろの薄い波紋3本
  const pal = FX.ramp(color), L = toL(pos), r = rad * WL, ww = w * WL, edge = PX.mix(pal[2], hexc('#fff4e0'), 0.35);
  waveBand(R.front, L, r, a0, a1, Math.min(ww * 0.5, r * 0.3), { edge, body: pal[2], inner: pal[1] }, alpha); // 出たばかりで半径が小さいうちは細く（塊にしない）
  for (let n = 1; n < 4; n++) { const rr = r - n * ww * 1.6; waveBand(R.front, L, rr, a0 + 0.03 * n, a1 - 0.03 * n, ww * 0.22, { edge: pal[2], body: pal[1], inner: pal[0] }, alpha * (0.7 - n * 0.15)); }
  for (let an = a0 + 0.1; an <= a1 - 0.1 + 1e-6; an += 0.12) R.front.glow(L.x + Math.cos(an) * r, L.y + Math.sin(an) * r, ww * 0.9 + 3, pal[2], 0.16 * alpha); // 弧の範囲だけ光らせる
}
DEMOS.push({
  id: 'G12-dolphin', ids: ['G12'], cat: G12, group: 'いるか座（dolphin）', title: '扇の波動', duration: 3.4, color: '#ff4f42', cam: { x: -80, y: 20 },
  params: [],
  refs: ['scripts/enemies/dolphin.gd（telegraph 1.0 の間 aim_turn 2.0 で向き直り、fire_wave、recover 0.6）', 'render/enemies/dolphin.gd・render/attacks/wave.gd RIPPLE（現行）', 'data/enemies/dolphin.tres（wave_arc 0.7 / 半径430 / 速さ300 / 幅50）', 'pixelFX painter.arc/glowRing'],
  status: { '状態': '試作のみ', '判定': '変更なし。当たる先頭の弧（幅50）を最も明るい帯に、後ろの層は見た目だけ', '形': '現行と同じ帯＋後ろの波紋3本。両端は丸めずにとがらせ、色は主色の赤（外側の縁だけ明るく）' },
  setup(S) { S.e = mkE('dolphin', V(-420, -20), 0, { fire_t: 0.3 }); S.ship = shipState(V(200, 80)); },
  step(S, dt) {
    const e = S.e, p = prm('dolphin'); S.ship.pos.y = 80 + Math.sin(S.t) * 40;
    if (e.mode === 'MOVE' && !S.wave) { e.fire_t -= dt; if (e.fire_t <= 0) { e.mode = 'WINDUP'; e.timer = p.telegraph; } }
    else if (e.mode === 'WINDUP') { turnToward(e, angOf(sub(S.ship.pos, e.pos)), p.aim_turn, dt); e.timer -= dt; e.charge = 1 - Math.max(0, e.timer) / p.telegraph; if (e.timer <= 0) { S.wave = { pos: add(e.pos, mul(fromA(e.facing), e.r)), a: e.facing, t0: S.t }; e.charge = 0; e.mode = 'RECOVER'; e.timer = 0.6; } }
    else if (e.mode === 'RECOVER') { e.timer -= dt; if (e.timer <= 0) e.mode = 'MOVE'; }
  },
  phase(S) { if (S.wave && (S.t - S.wave.t0) * prm('dolphin').wave_speed < prm('dolphin').wave_radius) return PH.DASH; return S.wave ? PH.RECOVER : PH[S.e.mode]; },
  draw(S, R) {
    const e = S.e, P = R.P, p = prm('dolphin'), col = { r: 1, g: 0.3, b: 0.25, a: 1 };
    drawEnemy(e); drawShip(S.ship);
    if (e.mode === 'WINDUP') {
      const k = e.charge, f = e.facing, arc = p.wave_arc;
      if (!R.proto) { for (const s of [-1, 1]) D2.line(e.pos, add(e.pos, mul(fromA(f + s * arc), e.r * (2 + 4 * k))), rgba(col, 0.25 + 0.4 * k), px(2)); for (let n = 0; n < 3; n++) { const fr = (k * 2 + n / 3) % 1; D2.roundArc(e.pos, e.r * (1.2 + 3.5 * fr), f - arc, f + arc, rgba(col, (1 - fr) * (0.3 + 0.5 * k)), px(3)); } D2.circle(add(e.pos, mul(fromA(f), e.r)), e.r * (0.2 + 0.25 * k), rgba('#fff', 0.5 + 0.4 * k)); }
      else {
        const mouth = add(e.pos, mul(fromA(f), e.r)), L = toL(mouth), pal = FX.ramp(P.color);
        // 口の前に音波の殻が収束し、撃つ向きの扇の内側にだけ空気のゆらぎ（ディザ）を流す
        for (let n = 0; n < 3; n++) { const fr = 1 - ((k * 1.6 + n / 3) % 1); R.front.arc(L.x, L.y, (e.r * (0.6 + 2.6 * fr)) * WL * P.size, 1, f - arc * 0.8, f + arc * 0.8, pal[3], (1 - fr) * k * P.intensity); }
        for (let i = 0; i < 26; i++) { const an = f + (hash(i * 3.3) - 0.5) * 2 * arc, d = ((hash(i) + S.t * 0.9) % 1) * 160 * k; R.back.dot(L.x + Math.cos(an) * d * WL, L.y + Math.sin(an) * d * WL, pal[2], 0.5 * k * (1 - d / 160)); }
        FXW.gather(R.front, mouth, e.r * 1.4, k * P.intensity, P.color, S.t, 10, 13);
      }
    }
    if (S.wave) {
      const t = S.t - S.wave.t0, rad = Math.min(p.wave_radius, t * p.wave_speed), fade = 1 - 0.5 * clamp(rad / p.wave_radius), w = p.wave_width;
      if (rad > 0 && rad < p.wave_radius) {
        if (!R.proto) { D2.roundArc(S.wave.pos, rad, S.wave.a - p.wave_arc, S.wave.a + p.wave_arc, rgba(col, 0.3 * fade), w * 2); D2.roundArc(S.wave.pos, rad, S.wave.a - p.wave_arc, S.wave.a + p.wave_arc, rgba(lighten(col, 0.3), 0.95 * fade), w); for (let n = 1; n < 4; n++) { const b = rad - n * w * 1.6; if (b > 0) D2.roundArc(S.wave.pos, b, S.wave.a - p.wave_arc, S.wave.a + p.wave_arc, rgba(col, 0.28 * fade / n), w * 0.45); } }
        else waveArc(R, S.wave.pos, rad, S.wave.a - p.wave_arc, S.wave.a + p.wave_arc, w, P.color, fade * Math.min(1, P.intensity), t);
      } else if (R.proto && rad >= p.wave_radius && t < p.wave_radius / p.wave_speed + 0.25 * P.timing) { const f = 1 - (t - p.wave_radius / p.wave_speed) / (0.25 * P.timing); waveArc(R, S.wave.pos, p.wave_radius + (t - p.wave_radius / p.wave_speed) * 60, S.wave.a - p.wave_arc, S.wave.a + p.wave_arc, w * f * 0.6, P.color, 0.5 * f, t); }
    }
  },
});
