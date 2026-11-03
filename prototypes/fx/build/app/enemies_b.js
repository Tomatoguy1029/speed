// ===== G12：ステージ1に出ない敵の固有攻撃（後半） =====
// サーチライトの光の円錐：幅を少しずつ狭めた扇を加算で重ね、中心ほど明るく縁をやわらかくする。明るさはレンズから先へ薄れる。
// 光の中だけで見える塵と、照らされた機体のまわりの明るみ（seenAt）を足す
function teleCone(R, lens, f, half, len, col, a0, time, seenAt) {
  const layers = 6; g.save(); g.globalCompositeOperation = 'lighter';
  for (let n = 0; n < layers; n++) { const hh = half * (1 - n / layers), gr = g.createRadialGradient(lens.x, lens.y, 0, lens.x, lens.y, len);
    gr.addColorStop(0, rgba(col, a0 / layers * 1.6)); gr.addColorStop(0.35, rgba(col, a0 / layers)); gr.addColorStop(1, rgba(col, 0));
    g.fillStyle = gr; g.beginPath(); g.moveTo(lens.x, lens.y); g.arc(lens.x, lens.y, len, f - hh, f + hh); g.closePath(); g.fill(); }
  if (seenAt) { const gr = g.createRadialGradient(seenAt.x, seenAt.y, 0, seenAt.x, seenAt.y, 70); gr.addColorStop(0, rgba(col, a0 * 0.9)); gr.addColorStop(1, rgba(col, 0)); g.fillStyle = gr; g.fillRect(seenAt.x - 70, seenAt.y - 70, 140, 140); }
  g.restore();
  const L = toL(lens), pal = FX.ramp(toHex(col));
  for (let i = 0; i < 46; i++) { const dd = ((hash(i) + time * 0.06 * (0.5 + hash(i + 3))) % 1) * len * WL, an = f + (hash(i * 7) - 0.5) * 2 * half * 0.9, tw = 0.5 + 0.5 * Math.sin(time * (2 + hash(i) * 3) + i); R.back.dot(L.x + Math.cos(an) * dd, L.y + Math.sin(an) * dd, pal[3], 0.6 * tw * (1 - dd / (len * WL))); }
}
// ---------- ぼうえんきょう座（telescope）
DEMOS.push({
  id: 'G12-telescope', ids: ['G12'], cat: G12, group: 'ぼうえんきょう座（telescope）', title: 'サーチライト→照準→レーザー', duration: 3.8, color: LASER, cam: { x: -120, y: 0 }, bg: 'station_a',
  refs: ['scripts/enemies/sniper.gd（探索の揺れ・lock_fill 0.9・帯 0.36→0.09・laser_charge 0.5・delay 0.04・照射0.18・cooldown 1.4）', 'render/enemies/sniper.gd（帯の多角形・照準線・輪）', 'render/attacks/beam.gd TELESCOPE（丸い先端のビーム）', 'marlin_warning.gdshader、pixelFX arcane-beam.js・painter.glow'],
  status: { '状態': '試作のみ（作り直し）', '判定': '変更なし（帯の角度・長さ1000・レーザー幅30）。探索・照準・溜め・発射の流れは現行（sniper.gd・render/enemies/sniper.gd）のまま', 'サーチライト': 'レンズから広がるなめらかな光の円錐。中心ほど明るく縁はやわらか、光の中だけ塵が見える。機体が光の中にいる間は明るい。溜まるほど水色→赤', '溜め→発射': '帯は切り替えずに連続してすぼまり、赤い照準線が脈打つ。発射はレンズから先端が伸びる', '備考': '小隕石による遮蔽はこのデモでは置いていない（光線48本は全長）' },
  setup(S) { S.e = mkE('telescope', V(-560, -40), 0); S.ship = shipState(V(240, 70)); S.e.facing = angOf(sub(S.ship.pos, S.e.pos)) + 0.45; },
  step(S, dt) {
    const e = S.e, p = prm('telescope'); const lens = () => add(e.pos, mul(fromA(e.facing), e.r * 0.9));
    const half = lerp(p.band_width, p.band_narrow, e.charge); S.half = half; S.lens = lens();
    if (e.mode === 'RECOVER') { e.timer -= dt; const sway = Math.sin(e.age = (e.age || 0) + dt) * p.search_sway; turnToward(e, angOf(sub(S.ship.pos, e.pos)) + sway, p.search_turn, dt); if (e.timer <= 0) e.mode = 'MOVE'; return; }
    const d = sub(S.ship.pos, S.lens), seen = S.seen = Math.abs(angDiff(angOf(d), e.facing)) <= half + Math.atan(DATA.config.ship_radius / len(d)) && len(d) <= p.band_len;
    if (!seen) { e.charge = 0; turnToward(e, angOf(sub(S.ship.pos, e.pos)) + Math.sin(S.t * TAU / p.search_period) * p.search_sway, p.search_turn, dt); return; }
    turnToward(e, angOf(sub(S.ship.pos, e.pos)), p.track_turn, dt);
    if (e.mode === 'WINDUP') { e.timer -= dt; if (e.timer <= 0) { S.beam = { p: S.lens, a: e.facing, len: p.band_len, w: p.laser_width, delay: p.laser_delay, active: p.laser_time, t0: S.t }; e.charge = 0; e.mode = 'RECOVER'; e.timer = p.cooldown; } return; }
    e.charge = Math.min(1, e.charge + dt / p.lock_fill); if (e.charge >= 1) { e.mode = 'WINDUP'; e.timer = p.laser_charge; }
  },
  phase(S) { const e = S.e; if (e.mode === 'WINDUP') return PH.WINDUP + '（レーザー溜め）'; if (S.beam && S.t - S.beam.t0 < S.beam.delay + S.beam.active) return PH.DASH; if (e.mode === 'RECOVER') return PH.RECOVER; return e.charge > 0 ? '照準の溜め（帯が細る）' : '探索'; },
  draw(S, R) {
    const e = S.e, P = R.P, p = prm('telescope'), k = e.charge, lens = S.lens || e.pos, half = S.half || p.band_width, f = e.facing;
    const aiming = e.charge > 0 || e.mode === 'WINDUP';
    const col = { r: lerp(0.62, 1, k), g: lerp(0.9, 0.22, k), b: lerp(1, 0.2, k), a: 1 };
    if (aiming && e.mode !== 'WINDUP') {
      const pts = []; for (let n = 0; n < 48; n++) pts.push(add(lens, mul(fromA(f - half + 2 * half * n / 47), p.band_len)));
      const a0 = 0.16 + 0.22 * k + 0.08;
      if (!R.proto) { D2.fan(lens, pts, rgba(col, a0), rgba(col, 0)); D2.line(lens, pts[0], rgba(col, a0 * 1.6), px(1.5)); D2.line(lens, pts[47], rgba(col, a0 * 1.6), px(1.5)); }
      else teleCone(R, lens, f, half, p.band_len, col, (0.16 + 0.22 * k + (S.seen ? 0.08 : 0)) * P.intensity, S.t, S.seen ? S.ship.pos : null);
    }
    if (e.mode === 'WINDUP') {
      const w = 1 - clamp(e.timer / p.laser_charge), tip = add(lens, mul(fromA(f), p.band_len)), pulse = 0.5 + 0.5 * Math.sin(S.t * (30 + 40 * w));
      if (!R.proto) { D2.line(lens, tip, `rgba(255,64,51,${0.25 + 0.35 * pulse})`, Math.max(px(2), 4 + 10 * w)); D2.line(lens, tip, `rgba(255,217,204,${0.5 + 0.4 * pulse})`, Math.max(px(1), 1.5 + 2 * w)); for (let n = 0; n < 10; n++) { const fr = (w * 3 + n / 10) % 1; D2.circle(add(lens, mul(fromA(n * TAU / 10 + w * 4), e.r * (2.4 - 2.2 * fr))), Math.max(px(1.5), e.r * 0.07), `rgba(255,115,77,${fr})`); } D2.circle(lens, e.r * (0.35 + 0.6 * w), `rgba(255,77,56,${0.35 + 0.3 * pulse})`); D2.circle(lens, e.r * (0.18 + 0.3 * w), 'rgba(255,235,217,.9)'); }
      else { // 本番どおり帯がすぼまって赤い照準線になる。切り替えずに、帯の幅を溜めの前半で連続して0へ
        const shrink = 1 - smooth(0, 0.45, w), hc = p.band_narrow * shrink; if (hc > 0.002) teleCone(R, lens, f, hc, p.band_len, { r: 1, g: 0.22, b: 0.2, a: 1 }, 0.38 * shrink * P.intensity, S.t, null);
        FXW.warnRail(R.back, lens, tip, { color: P.color, k: (0.3 + 0.7 * w) * (0.75 + 0.25 * pulse), time: S.t, seed: 2, intensity: P.intensity, maxLv: 3 }); FXW.gather(R.front, lens, e.r * 2.4 * P.size, (0.4 + 0.6 * w) * P.intensity, P.color, S.t, 16, 8); }
    }
    if (S.beam) { const h = S.beam, t = S.t - h.t0, b = add(h.p, mul(fromA(h.a), h.len));
      if (t >= h.delay && t <= h.delay + h.active) { const rem = h.delay + h.active - t; let fade = (1 - clamp((t - h.delay) / h.active) * 0.6) * smooth(0, Math.min(0.08, h.active), rem);
        if (!R.proto) { D2.roundBeam(h.p, b, `rgba(255,77,64,${0.35 * fade})`, h.w * 1.6); D2.roundBeam(h.p, b, `rgba(255,77,64,${0.9 * fade})`, h.w); D2.roundBeam(h.p, b, `rgba(255,255,255,${0.85 * fade})`, Math.max(px(2), h.w * 0.3)); }
        else { const tf = t - h.delay, head = Math.min(1, smooth(0, 0.06 * P.timing, tf)) * 0.999 + 0.001; FXW.beam(R.front, h.p, b, { color: P.color, w: h.w / 2, time: S.t, alpha: Math.min(1, fade * 1.3 * P.intensity), to: head, taper: 10 * P.size }); if (tf < 0.08) FXW.flare(R.front, h.p, 16 * P.size, P.color, S.t, 1 - tf / 0.08, 6); } // 先端がレンズから伸びる
      } else if (R.proto && t > h.delay + h.active && t < h.delay + h.active + 0.3 * P.timing) { const u = (t - h.delay - h.active) / (0.3 * P.timing); FXW.warnRail(R.back, h.p, b, { color: P.color, k: 0.2, time: S.t, seed: 6, rail: 1, intensity: (1 - u) * P.intensity }); FXW.sparks(R.front, h.p, t - h.delay - h.active, 9, 8, P.color, 35, 0.3, h.a, 0.6); }
    }
    if (R.proto) R.blitBack();
    drawEnemy(e); drawShip(S.ship);
    if (!R.proto && aiming && e.mode !== 'WINDUP') { D2.circle(lens, px(2) + e.r * (0.2 + 0.2 * k), rgba(col, 0.5 + 0.4 * k)); if (k > 0) D2.arc(e.pos, e.r * 1.35, -Math.PI / 2, -Math.PI / 2 + TAU * k, rgba(col, 0.9), Math.max(px(2), e.r * 0.12)); }
    if (R.proto && aiming && e.mode !== 'WINDUP') { const L = toL(lens), pal = FX.ramp(toHex(col)); R.front.px(L.x, L.y, pal[4]); R.front.glow(L.x, L.y, 3 + 4 * k * P.size, pal[4], 0.6); R.front.glow(L.x, L.y, 8 + 10 * k, pal[2], 0.5); } // レンズは光だけ（丸は描かない）
  },
});

// ---------- レチクル座（reticle）
DEMOS.push({
  id: 'G12-reticle', ids: ['G12'], cat: G12, group: 'レチクル座（reticle）', title: '遮る小隕石の破壊（支援）', duration: 2.4, color: '#7fe6ff', cam: { x: -200, y: 0 },
  refs: ['scripts/enemies/reticle.gd（follow_gap 150・aim_time 0.8・beam 幅10/0.25s・rock_break）', 'render/enemies/reticle.gd（四隅の照準＋点線）', 'pixelFX painter.arc/sparks、marlin_warning.gdshader'],
  status: { '状態': '試作のみ', '判定': '機体への攻撃はなし（岩だけを撃つ）。支援の対象・時間は変更なし', '近似': '岩の破片（rock_break）と細いビームの現行描画は簡略移植' },
  setup(S) { S.tel = mkE('telescope', V(-560, -20), 0); S.ship = shipState(V(240, 60)); S.tel.facing = angOf(sub(S.ship.pos, S.tel.pos)); S.e = mkE('reticle', add(S.tel.pos, V(60, -150)), 0); S.rock = { pos: V(-170, 20), r: 46, alive: true }; },
  step(S, dt) {
    const e = S.e, p = prm('reticle');
    if (e.mode === 'MOVE' && S.t > 0.3 && S.rock.alive && !S.broke) { e.mode = 'WINDUP'; e.timer = p.aim_time; }
    else if (e.mode === 'WINDUP') { turnToward(e, angOf(sub(S.rock.pos, e.pos)), enemyDef('reticle').turn * 3, dt); e.timer -= dt; e.charge = 1 - Math.max(0, e.timer) / p.aim_time; if (e.timer <= 0) { S.shot = { from: add(e.pos, mul(fromA(e.facing), e.r)), to: { ...S.rock.pos }, t0: S.t }; S.rock.alive = false; S.broke = S.t; e.mode = 'MOVE'; e.charge = 0; } }
    else turnToward(e, S.tel.facing, enemyDef('reticle').turn, dt);
  },
  phase(S) { return S.e.mode === 'WINDUP' ? PH.WINDUP : S.broke ? (S.t - S.broke < 0.3 ? PH.DASH : PH.RECOVER) : PH.MOVE; },
  draw(S, R) {
    const e = S.e, P = R.P, col = ecol('reticle', 0.2), lens = add(e.pos, mul(fromA(e.facing), e.r));
    if (S.rock.alive) drawImg('meteor_0', S.rock.pos, 0.3, S.rock.r * 1.1);
    drawEnemy(S.tel); drawEnemy(e); drawShip(S.ship);
    if (e.mode === 'WINDUP') {
      const k = e.charge, at = S.rock.pos, size = S.rock.r * (1.6 - 0.5 * k), spin = Math.PI / 4 * (1 - k);
      if (!R.proto) {
        for (let q = 0; q < 4; q++) { const a = spin + q * Math.PI / 2, c = add(at, mul(fromA(a), size * 1.41)); D2.line(c, add(c, mul(fromA(a + Math.PI * 0.75), size * 0.5)), rgba(col, 0.5 + 0.5 * k), Math.max(px(2), 3)); D2.line(c, add(c, mul(fromA(a - Math.PI * 0.75), size * 0.5)), rgba(col, 0.5 + 0.5 * k), Math.max(px(2), 3)); }
        D2.line(sub(at, V(size * 0.3, 0)), add(at, V(size * 0.3, 0)), rgba(col, 0.6 * k), px(1.5)); D2.line(sub(at, V(0, size * 0.3)), add(at, V(0, size * 0.3)), rgba(col, 0.6 * k), px(1.5));
        const gap = sub(at, lens), steps = Math.floor(len(gap) / 18); for (let n = 0; n < steps; n += 2) D2.line(add(lens, mul(gap, n / steps)), add(lens, mul(gap, (n + 1) / steps)), rgba(col, 0.25 + 0.5 * k), px(1.5));
      } else {
        const L = toL(at), pal = FX.ramp(P.color), sz = size * WL * P.size;
        for (let q = 0; q < 4; q++) { const a = spin + q * Math.PI / 2, cx = L.x + Math.cos(a) * sz * 1.2, cy = L.y + Math.sin(a) * sz * 1.2; R.front.arc(cx - Math.cos(a) * sz * 0.4, cy - Math.sin(a) * sz * 0.4, sz * 0.4, 1, a - 0.6, a + 0.6, pal[3], 0.6 + 0.4 * k); R.front.dot(cx, cy, pal[4], k); }
        R.front.ring(L.x, L.y, sz * (0.5 + 0.5 * (1 - k)), 1, pal[2], 0.4 * k); R.front.glow(L.x, L.y, sz, pal[2], 0.25 * k * P.intensity);
        FXW.warnRail(R.front, lens, at, { color: P.color, k, time: S.t, seed: 5, rail: 1.2, intensity: P.intensity });
      }
    }
    if (S.shot) { const t = S.t - S.shot.t0;
      if (!R.proto) { if (t < 0.25) D2.line(S.shot.from, S.shot.to, rgba(col, 1 - t / 0.25), 10); if (t < 0.6) for (let i = 0; i < 8; i++) { const a = hash(i) * TAU, d = 120 * t * (0.5 + hash(i + 1)); D2.circle(add(S.shot.to, mul(fromA(a), d)), 7 * (1 - t / 0.6), 'rgba(160,138,120,.9)'); } }
      else { if (t < 0.22 * P.timing) FXW.beam(R.front, S.shot.from, S.shot.to, { color: P.color, w: 5, time: S.t, alpha: 1 - t / (0.22 * P.timing), source: true }); FXW.sparks(R.front, S.shot.to, t, 51, 18, '#ffd9a8', 70, 0.5); if (t < 0.6) for (let i = 0; i < 10; i++) { const a = hash(i * 2.1) * TAU, d = 130 * t * (0.4 + hash(i + 5)), q = toL(add(S.shot.to, mul(fromA(a), d))); R.front.circle(q.x, q.y, 1.5 * (1 - t / 0.6) + 0.6, hexc('#7d6a5c')); R.front.dot(q.x - 0.5, q.y - 0.5, hexc('#b39b86')); } if (t < 0.12) FXW.flare(R.front, S.shot.to, 14, '#ffffff', S.t, 1 - t / 0.12, 5); }
    }
  },
});

// ---------- じょうぎ座（ruler）
DEMOS.push({
  id: 'G12-ruler', ids: ['G12'], cat: G12, group: 'じょうぎ座（ruler）', title: '分離→挟み込み→光の壁', duration: 7.4, color: '#ffd27a', cam: { x: 0, y: -160 },
  refs: ['scripts/enemies/ruler.gd（split_delay 0.4・deploy 0.5・telegraph 0.6・壁 beam_time 5.0・beam_start_gap 80・half_gap 190・emit_back 520）', 'render/enemies/ruler.gd（点線の予告）・render/attacks/wall.gd RAY（光の柱）', 'assets/pixel/ruler/ruler_top_*・ruler_bottom_*（上下の現行画像）', 'marlin_warning.gdshader、pixelFX arcane-beam.js'],
  params: [{ k: 'muzzle', label: '試作：ビームの根元(発射口からの距離)', type: 'range', min: 0, max: 120, step: 2, def: 0 }],
  status: { '状態': '試作のみ', '判定': '変更なし（幅26・長さ2600、壁は機体の移動を止める）', '発射口': '溜めの光とビームの根元を、上下それぞれの絵の発射口の中心に合わせた（そこからの距離はつまみ）。本番の当たりは beam_start_gap（80）だけ先から始まるので、見た目に合わせるには移行後に数値の変更が要る', '色': '南十字と同じ黄色' },
  setup(S) { S.ship = shipState(V(0, 60)); S.a = mkE('ruler', V(-80, -420), Math.PI / 2); S.b = null; },
  step(S, dt) {
    const p = prm('ruler');
    if (!S.b && S.t >= p.split_delay) { const d = V(0, 1); S.a.facing = Math.PI / 2; S.b = { ...S.a, pos: { ...S.a.pos } }; S.a.buds = 1; S.b.buds = -1; for (const h of [S.a, S.b]) { h.mode = 'DASH'; h.timer = p.deploy_time; } }
    if (!S.b) return;
    for (const h of [S.a, S.b]) {
      const d = fromA(h.facing), n = V(-d.y, d.x); h.timer -= dt;
      if (h.mode === 'DASH') { const goal = sub(add(S.ship.pos, mul(n, h.buds * p.half_gap)), mul(d, p.emit_back)); h.pos = lerpV(h.pos, goal, 1 - Math.exp(-6 * dt)); if (h.timer <= 0) { h.mode = 'WINDUP'; h.timer = p.telegraph; } }
      else if (h.mode === 'WINDUP') { h.charge = 1 - Math.max(0, h.timer) / p.telegraph; if (h.timer <= 0) { h.charge = 0; h.mode = 'RECOVER'; h.timer = p.beam_time; h.t0 = S.t; } }
      else if (h.mode === 'RECOVER') { if (h.timer <= 0) { h.mode = 'END'; h.tEnd = S.t; } }
    }
  },
  phase(S) { if (!S.b) return '出現（分離前）'; const m = S.a.mode; return m === 'DASH' ? '展開（挟む位置へ）' : m === 'WINDUP' ? PH.WINDUP : m === 'RECOVER' ? PH.DASH + '（光の壁）' : PH.RECOVER; },
  draw(S, R) {
    const P = R.P, p = prm('ruler'), d0 = enemyDef('ruler').look;
    // 試作は絵の発射口の中心から出す：上下の絵は 58×46 の共通の画面の上半分・下半分で、発射口（右端の括弧形）は x≈27.5、中心線から上 −10.5・下 +10.5（画素）
    const origin = (h) => { const u = fromA(h.facing); if (!R.proto) return add(h.pos, mul(u, h.r + p.beam_width * 0.5 + p.beam_start_gap));
      const sc = 2 * spriteR('ruler', h.r) / 58, lx = 27.5 * sc, ly = (h.buds === -1 ? -10.5 : 10.5) * sc; return add(add(h.pos, mul(u, lx + (P.muzzle ?? 0))), mul(orth(u), ly)); };
    const hs = S.b ? [S.a, S.b] : [];
    for (const h of hs) {
      const o = origin(h), u = fromA(h.facing), b = add(o, mul(u, p.beam_len)), col = ecol('ruler', 0.2), c0 = ecol('ruler');
      if (h.mode === 'RECOVER' || h.mode === 'END') {
        const t = S.t - h.t0, left = p.beam_time - t, f = clamp(left / 0.3) * clamp(t / 0.12), flick = 0.85 + 0.15 * Math.sin(t * 50 + h.buds);
        if (!R.proto) { if (f > 0) { D2.line(o, b, rgba(c0, 0.22 * f), p.beam_width * 2.6 * flick); D2.line(o, b, rgba(lighten(c0, 0.2), 0.9 * f), p.beam_width); D2.line(o, b, rgba('#fff', 0.9 * f), Math.max(px(2), p.beam_width * 0.35)); D2.circle(o, p.beam_width * (0.9 + 0.2 * flick), rgba('#fff', 0.8 * f)); } }
        else { const fin = clamp(t / (0.12 * P.timing)), fout = clamp(left / (0.3 * P.timing)); if (fin * fout > 0) { FXW.beam(R.front, o, b, { color: P.color, w: p.beam_width / 2 * (0.4 + 0.6 * fout), time: S.t + h.buds, alpha: Math.min(1, fin * (0.5 + 0.5 * fout) * P.intensity) }); for (const s of [-1, 1]) FXW.warnRail(R.back, add(o, mul(orth(u), s * p.beam_width * 1.1)), add(b, mul(orth(u), s * p.beam_width * 1.1)), { color: P.color, k: 0.35 * fout, time: S.t * 2, seed: 20 + s + h.buds, rail: 0.8, intensity: fin * fout * P.intensity }); } if (left < 0.3 * P.timing && left > -0.3) FXW.sparks(R.front, o, 0.3 * P.timing - left, 40 + h.buds, 10, P.color, 40, 0.35, h.facing, 0.5); }
      } else if (h.mode === 'WINDUP') {
        const k = h.charge;
        if (!R.proto) { for (let s = 0; s < p.beam_len; s += 36) D2.line(add(o, mul(u, s)), add(o, mul(u, Math.min(s + 36 * 0.55, p.beam_len))), rgba(col, 0.25 + 0.6 * k), Math.max(px(2), 3 + 4 * k)); D2.circle(o, h.r * (0.2 + 0.4 * k), rgba('#fff', 0.4 + 0.5 * k)); }
        else { FXW.warnRail(R.back, o, b, { color: P.color, k, time: S.t, seed: 30 + h.buds, intensity: P.intensity, reveal: clamp(0.35 + 0.65 * k * 1.4) }); FXW.gather(R.front, o, h.r * 1.8 * P.size, k * P.intensity, P.color, S.t, 12, 7 + h.buds); }
      } else if (h.mode === 'DASH' && !R.proto) D2.circle(o, h.r * 0.18, rgba(col, 0.6));
    }
    if (R.proto) R.blitBack();
    if (!S.b) { drawEnemy({ ...S.a, facing: S.a.facing }, { key: 'enemy/ruler/upper' }); drawImg('enemy/ruler/lower', S.a.pos, S.a.facing + d0.split_other.angle, spriteR('ruler', S.a.r)); }
    else for (const h of hs) drawImg(h.buds === -1 ? 'enemy/ruler/upper' : 'enemy/ruler/lower', h.pos, h.facing + (h.buds === -1 ? d0.angle : d0.split_other.angle), spriteR('ruler', h.r));
    drawShip(S.ship);
  },
});

// ---------- みずがめ座（aquarius）：shaders/water_flood.gdshader を論理ピクセルで CPU 移植
const WATER = { data: null, w: 512, h: 512 };
function waterNoise(x, y, ch) { // texture(noise_tex, p*0.125) の近似（最近傍・繰り返し）
  const d = WATER.data; if (!d) return 0.5; const u = ((Math.floor(x * 0.125 * 512) % 512) + 512) % 512, v = ((Math.floor(y * 0.125 * 512) % 512) + 512) % 512; return d[(v * 512 + u) * 4 + ch] / 255;
}
function waterDots(px_, py_, density, radius) { const ix = Math.floor(px_), iy = Math.floor(py_), fx = px_ - ix, fy = py_ - iy; const cx = (((ix * 37 + iy * 13) % 512) + 512) % 512, cy = (((iy * 61 + ix * 7) % 512) + 512) % 512; const d = WATER.data; if (!d) return 0; const j = (cy * 512 + cx) * 4; if (d[j + 2] / 255 > density) return 0; const c0 = d[j] / 255 * 0.5 + 0.25, c1 = d[j + 1] / 255 * 0.5 + 0.25; return smooth(radius, radius * 0.35, Math.hypot(fx - c0, fy - c1)); }
const waterCanvas = document.createElement('canvas'); waterCanvas.width = LW; waterCanvas.height = LH; const wg = waterCanvas.getContext('2d'); const wImg = wg.createImageData(LW, LH);
function drawWater(strips, t, quant, P) {
  const o = wImg.data; o.fill(0);
  for (let y = 0; y < LH; y++) for (let x = 0; x < LW; x++) {
    const wx = (x + 0.5 - LW / 2) * LP / Z + cam.x, wy = (y + 0.5 - LH / 2) * LP / Z + cam.y;
    let R0 = 0, G0 = 0, B0 = 0, A0 = 0;
    for (const s of strips) {
      const dx = wx - s.p.x, dy = wy - s.p.y, along = dx * s.ux + dy * s.uy; if (along < 0 || along > s.len) continue;
      const lat = -dx * s.uy + dy * s.ux, half = Math.max(s.half0 + along * s.slope, 1), across = lat / half, side = Math.abs(across); if (side > 1.12) continue;
      const cw = across * half, fade = s.a * (1 - smooth(0.7, 1, along / s.len)); let c;
      if (s.mode === 0) { // ripples
        const k = s.g, inside = 1 - smooth(0.97, 1, side), sheet = waterNoise(along * 0.003 - t * (0.4 + 1.4 * k), cw * 0.004 + s.seed, 0);
        const sp = lerp(1.4, 5.5, k * k), warp = waterNoise(along * 0.003, cw * 0.006 + s.seed, 1) * 5, wave = 0.5 + 0.5 * Math.sin(along * lerp(0.018, 0.03, k) - t * sp * 3 + warp);
        const crest = smooth(0.9, 1, wave) * smooth(0.3, 0.6, waterNoise(along * 0.005 - t * sp * 0.3, cw * 0.01 + s.seed, 2));
        const line = smooth(0.94, 0.985, side) * (1 - smooth(0.995, 1.025, side)), drops = waterDots(along / 18 - t * lerp(14, 45, k), (side - 1) * half / 10 + s.seed, 0.55, 0.38) * smooth(0.9, 0.98, side) * smooth(1.1, 1, side);
        let a = inside * ((0.025 + 0.035 * k) * (0.6 + sheet) + crest * (0.14 + 0.3 * k)) + line * (0.22 + 0.33 * k) + drops * (0.45 + 0.4 * k);
        if (quant) a += line * 0.25 * k + crest * 0.15; // 試作：縁と波頭をやや強め、照射が近いほど読みやすく
        const m = clamp(line + drops); c = [lerp(lerp(0.2, 0.55, crest), 0.7, m), lerp(lerp(0.55, 0.88, crest), 0.95, m), lerp(lerp(0.95, 1.05, crest), 1.15, m), clamp(a)];
      } else if (s.mode === 1) { // rushing
        const g2 = s.g, ls = waterNoise(along * 0.0012 - t * 11, cw * 0.01 + s.seed, 0), fs = waterNoise(along * 0.0035 - t * 26, cw * 0.045 + s.seed * 1.7, 1), fl = ls * 0.55 + fs * 0.45;
        const wob = (waterNoise(along * 0.02 - t * 40, s.seed, 2) - 0.5) * 0.05, body = 1 - smooth(g2 * 0.92, g2 * 0.99, side + wob), br = smooth(0.75 - 0.62 * g2, 0.85 - 0.62 * g2, fl);
        const spray = waterDots(along / 22 - t * 120, (side - 0.9) * half / 12 + s.seed, 0.45, 0.3) * smooth(0.88 * g2, 0.97 * g2, side) * smooth(1.12, 1, side);
        const I = 2 + 1.6 * smooth(0.35, 0.8, fl) + 1.5 * fs ** 3; let col = [I, I, I]; const ed = smooth(0.7, 0.99, side) * 0.6; col = col.map((v, i) => lerp(v, [0.75, 1, 1.25][i] * 1.8, ed));
        const a = body * br + spray; col = col.map((v, i) => lerp(v, [0.9, 1.05, 1.25][i] * 2.2, clamp(spray) * (1 - body)));
        c = [col[0], col[1], col[2], clamp(a)];
      } else { // mist
        const mm = waterNoise(along * 0.003 - t * 0.35, cw * 0.004 + s.seed, 0), cloud = smooth(0.42, 0.78, mm) * (1 - smooth(0.7, 1.1, side)), drops = waterDots(along / 26 - t * 2, cw / 26 + s.seed, 0.3, 0.22);
        c = [lerp(0.3, 0.8, drops), lerp(0.6, 0.98, drops), lerp(0.9, 1.1, drops), clamp((cloud * 0.24 + drops * 0.65) * s.g)];
      }
      const a = c[3] * fade; if (a <= 0) continue;
      let r = c[0], gg = c[1], b = c[2];
      if (quant) { const lum = (r + gg + b) / 3, ramp = WATER_RAMP(P.color), i = lum > 3.1 ? 4 : lum > 2.3 ? 3 : lum > 1.2 ? 2 : lum > 0.6 ? 1 : 0; r = ramp[i][0]; gg = ramp[i][1]; b = ramp[i][2]; } // 試作：明るさを主色の5段へ（白は筋の頂だけ）
      R0 = R0 * (1 - a) + r * a; G0 = G0 * (1 - a) + gg * a; B0 = B0 * (1 - a) + b * a; A0 = A0 + a * (1 - A0);
    }
    if (A0 > 0.003) { const j = (y * LW + x) * 4; o[j] = Math.min(255, R0 / Math.max(A0, 0.001) * 255 * 0.85); o[j + 1] = Math.min(255, G0 / Math.max(A0, 0.001) * 255 * 0.85); o[j + 2] = Math.min(255, B0 / Math.max(A0, 0.001) * 255 * 0.85); o[j + 3] = Math.min(255, A0 * 255); }
  }
  wg.putImageData(wImg, 0, 0); g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.imageSmoothingEnabled = false; g.drawImage(waterCanvas, 0, 0, LW * LP, LH * LP); g.restore(); worldTransform();
}
const WATER_RAMP = (h) => { const c = parseCol(h); return [[c.r * 0.25, c.g * 0.35, c.b * 0.55], [c.r * 0.5, c.g * 0.65, c.b * 0.85], [c.r * 0.85, c.g * 0.95, c.b], [lerp(c.r, 1, 0.55), lerp(c.g, 1, 0.55), lerp(c.b, 1, 0.55)], [1, 1, 1]]; };
const hexMulR = (h) => 0.6 + 0.4 * parseCol(h).r / 0.5, hexMulG = (h) => 0.6 + 0.4 * parseCol(h).g / 0.85, hexMulB = (h) => 0.6 + 0.4 * parseCol(h).b;
// 試作の照射中の水流：pixelFX water/water-jet.js の作り（白い芯→外ほど深い色の帯、流れに沿って走る筋、通り抜ける膨らみ、
// 先ほど荒れる縁、ちぎれる先端、側面から飛ぶ尾つきの水滴、先端の霧、吹き出し口の光）を、上から見た広がる水流へ当てはめる
function aquaRamp(hex) { const b = hexc(hex), W = PX.WHITE, K = hexc('#04101e'); return [PX.mix(K, b, 0.12), PX.mix(K, b, 0.25), PX.mix(K, b, 0.45), PX.mix(K, b, 0.7), b, PX.mix(b, W, 0.35), PX.mix(b, W, 0.7), W]; }
function aquaJet(p, origin, a, len, half0, slope, t, g, seed, C, alpha) {
  const O = toL(origin), ux = Math.cos(a), uy = Math.sin(a), Lend = len * WL, view = Math.hypot(LW, LH), Dmax = Math.min(Lend, view * 1.2);
  const N = Math.ceil(Dmax) + 1, UP = new Float32Array(N), DN = new Float32Array(N); // 列（流れの向きの距離）ごとの上下の縁
  for (let d = 0; d < N; d++) { const u = d / Lend, rough = smooth(0.1, 1, u), sd = ((((d - t * 520) % 150) + 150) % 150) - 75; // 通り抜ける膨らみ
    const h0 = Math.max(1.2, (half0 + d / WL * slope) * WL) * (0.55 + 0.45 * g) * (1 + Math.exp(-(sd * sd) / 160) * 0.12 * (1 - u * 0.5));
    UP[d] = h0 * (1 + PX.tileNoise(d * 0.09 - t * 30, 9, 0, 0, seed + 1) * 0.16 * rough); DN[d] = h0 * (1 + PX.tileNoise(d * 0.09 - t * 30, 3, 0, 0, seed + 1) * 0.16 * rough); }
  const ends = [O, V(O.x + ux * Dmax - uy * UP[N - 1], O.y + uy * Dmax + ux * UP[N - 1]), V(O.x + ux * Dmax + uy * DN[N - 1], O.y + uy * Dmax - ux * DN[N - 1])];
  const bx0 = Math.max(0, Math.min(...ends.map(e => e.x)) - 2), bx1 = Math.min(LW, Math.max(...ends.map(e => e.x)) + 2), by0 = Math.max(0, Math.min(...ends.map(e => e.y)) - 2), by1 = Math.min(LH, Math.max(...ends.map(e => e.y)) + 2);
  for (let y = Math.floor(by0); y < by1; y++) for (let x = Math.floor(bx0); x < bx1; x++) { // 画面のマスごとに流れの座標へ戻して塗る（穴を空けない）
    const rx = x + 0.5 - O.x, ry = y + 0.5 - O.y, d = rx * ux + ry * uy; if (d < 1 || d >= Dmax) continue;
    const q = -rx * uy + ry * ux, di = Math.floor(d), edge = q < 0 ? DN[di] : UP[di], aq = Math.abs(q) / Math.max(0.8, edge); if (aq > 1) continue;
    const u = d / Lend; if (u > 0.5 && PX.tileNoise(d * 0.1 - t * 25, q * 0.18, 0, 0, seed + 2) < -0.95 + 1.7 * smooth(0.5, 1, u) + (1 - g) * 0.8) continue; // 先がちぎれる
    const streak = PX.tileNoise(d * 0.045 - t * 46, q * 0.55, 0, 0, seed), body = PX.tileNoise(d * 0.02 - t * 12, q * 0.06, 0, 0, seed + 5);
    let lv = aq > 0.9 ? 2 : aq > 0.72 ? 3 : body > 0.2 ? 5 : 4; // 本体は主色、縁ほど深い色
    if (aq < 0.07 + 0.05 * (1 - u)) lv = 7; else if (streak > 0.42) lv = Math.min(7, lv + 2); else if (streak > 0.25) lv = Math.min(6, lv + 1); // 芯と走る筋だけ白い
    p.dot(x, y, C[lv], alpha * (aq > 0.9 ? 0.75 : 1)); if (lv === 7 && (x & 3) === 0 && (y & 3) === 0) p.light(x, y, C[5], 0.12 * alpha);
  }
  PX.cycle(t, 0.6, 46, seed + 3, (r) => r.range(0.25, 0.5), (age, life, r) => { // 側面と先端から飛ぶ水滴
    const f = Math.sqrt(r.next()), d0 = Lend * (0.15 + 0.85 * f), side = r.next() < 0.5 ? -1 : 1, h = (half0 + d0 / WL * slope) * WL * (0.55 + 0.45 * g);
    const vA = r.range(160, 300), vS = side * r.range(20, 110) * (0.4 + f), x0 = O.x + ux * d0 - uy * side * h, y0 = O.y + uy * d0 + ux * side * h;
    const k = age / life, vx = ux * vA - uy * vS, vy = uy * vA + ux * vS, x = x0 + vx * age * 0.25, y = y0 + vy * age * 0.25; if (k > 0.8 && r.next() < (k - 0.8) * 5) return;
    const sp = Math.hypot(vx, vy), tl = Math.min(4, sp * 0.012); p.line(x - vx / sp * tl, y - vy / sp * tl, x, y, (w) => w < 0.5 ? C[4] : C[6], alpha); p.dot(x, y, k < 0.4 ? C[7] : C[6], alpha);
  });
  PX.cycle(t, 1.2, 10, seed + 4, (r) => r.range(0.8, 1.2), (age, life, r) => { // 先端の霧
    const k = age / life, d = Lend * r.range(0.75, 1) + age * 30, q = r.range(-1, 1) * (half0 + d / WL * slope) * WL * 0.8, rad = r.range(4, 7) + k * 8;
    p.disc(O.x + ux * d - uy * q, O.y + uy * d + ux * q, rad, C[6], (dd) => 0.16 * alpha * Math.min(1, k / 0.15) * Math.pow(1 - k, 1.5) * (1 - dd * dd));
  });
  for (let d = 0; d < Math.min(Lend, view); d += 12) p.glow(O.x + ux * d, O.y + uy * d, 10 + d * 0.06, C[4], 0.18 * alpha * (1 - d / Lend * 0.6)); // 芯の光
}
DEMOS.push({
  id: 'G12-aquarius', ids: ['G12'], cat: G12, group: 'みずがめ座（aquarius）', title: '全方位の極太水流', duration: 9.0, color: '#7fd8ff', cam: { x: -120, y: 0 },
  refs: ['scripts/enemies/aquarius.gd（approach 380・telegraph 4.0・beam_time 3.0・6本・広がり0.32・rest 1.2）', 'scripts/render/attacks/flood.gd・shaders/water_flood.gdshader（ripples・rushing・mist を論理ピクセルでCPU移植）', 'assets/fx/water_noise.png（焼き込み済みノイズ）'],
  status: { '消え方': '現行のまま（現行shaderの移植：水流が崩れて霧になる）', '照射中の水': 'pixelFX water-jet の作り（白い芯→深い色の帯・走る筋・通り抜ける膨らみ・荒れる縁・ちぎれる先端・尾つきの水滴・霧）。予告の波紋と終わりの霧は現行shaderのまま', '状態': '試作のみ（現行shaderを基に段階化）', '判定': '変更なし（幅は half0+along×tan(0.32)）', '近似': '照射時の画面揺れ・衝撃の粒（rm._burst）・波紋（pipeline.add_wave）は未再現。現行の色はHDRの白を0.85倍で表示' },
  setup(S) { S.e = mkE('aquarius', V(-320, -40), 0, { fire_t: 0.2 }); S.ship = shipState(V(130, 90)); S.e.facing = angOf(sub(S.ship.pos, S.e.pos)); },
  step(S, dt) {
    const e = S.e, p = prm('aquarius');
    if (e.mode === 'MOVE' && !S.fl) { e.fire_t -= dt; if (e.fire_t <= 0) { const a = angOf(sub(S.ship.pos, e.pos)); S.fl = { a, t0: S.t, delay: p.telegraph, active: p.beam_time }; e.mode = 'WINDUP'; e.timer = p.telegraph + p.beam_time; } }
    else if (e.mode === 'WINDUP') { if (e.timer > p.beam_time) turnToward(e, angOf(sub(S.ship.pos, e.pos)), 2, dt); e.timer -= dt; e.charge = clamp(1 - (e.timer - p.beam_time) / p.telegraph); if (e.timer <= 0) { e.charge = 0; e.mode = 'RECOVER'; e.timer = p.rest; } }
    else if (e.mode === 'RECOVER') { e.timer -= dt; if (e.timer <= 0) e.mode = 'MOVE'; }
  },
  phase(S) { if (!S.fl) return PH.MOVE; const t = S.t - S.fl.t0; return t < S.fl.delay ? PH.WINDUP + '（水の流れで予告）' : t < S.fl.delay + S.fl.active ? PH.DASH : PH.RECOVER + '（崩れて霧）'; },
  draw(S, R) {
    const e = S.e, p = prm('aquarius'), P = R.P;
    if (S.fl) {
      const t = S.t - S.fl.t0, strips = [], jets = [], n = p.beams;
      for (let k = 0; k < n; k++) {
        const a = S.fl.a + k * TAU / n, base = { p: e.pos, ux: Math.cos(a), uy: Math.sin(a), len: p.beam_len, half0: p.beam_width * 0.5 * (R.proto ? P.size : 1), slope: Math.tan(p.beam_spread), seed: ((k * 7) % 17) / 17 * 97, a: R.proto ? Math.min(1, P.intensity) : 1 };
        if (t < S.fl.delay) strips.push({ ...base, mode: 0, g: clamp(t / S.fl.delay) });
        else if (t < S.fl.delay + S.fl.active) (R.proto ? jets : strips).push({ ...base, mode: 1, g: 1, k });
        else { const age = t - S.fl.delay - S.fl.active, coll = clamp(1 - age / (0.35 * (R.proto ? P.timing : 1))), life = clamp(1 - age / (1.4 * (R.proto ? P.timing : 1)));
          if (coll > 0) strips.push({ ...base, mode: 1, g: coll, k }); // 消え方は現行のまま（水流が崩れて霧になる）
          if (life > 0) strips.push({ ...base, mode: 2, g: life * (1 - coll * 0.6) }); }
      }
      drawWater(strips, S.t, R.proto, R.proto ? P : null);
      if (jets.length) { const C = aquaRamp(P.color); for (const j of jets) aquaJet(R.front, j.p, Math.atan2(j.uy, j.ux), j.len, j.half0, j.slope, S.t, j.g, 7 + j.k * 13, C, j.a); }
      if (R.proto && t < S.fl.delay) FXW.gather(R.front, e.pos, e.r * 1.6 * P.size, clamp(t / S.fl.delay) * P.intensity, P.color, S.t, 14, 4);
      if (R.proto && t >= S.fl.delay && t < S.fl.delay + 0.2) { const L = toL(e.pos), f = 1 - (t - S.fl.delay) / 0.2, C2 = aquaRamp(P.color); R.front.glow(L.x, L.y, e.r * WL * 3, C2[6], 0.8 * f * P.intensity); } // 吹き出しの瞬間は光だけ（衝撃の輪は描かない）
    }
    drawEnemy(e); drawShip(S.ship);
  },
});

// ---------- わし座（aquila）
// 試作の稲妻：pixelFX lightning/_lib.js の作り（中点をずらして刻むジグザグ、細りながら枝分かれ、外側の暗い光→明るい本体→白い芯の3段で塗る）を移植。
// 稲妻の作りと塗り方は Sprite Fusion のオープンソースの稲妻（MIT License, Copyright (c) 2026 Hugo Duprez）由来
const VOLT = ['#120a33', '#2a1b78', '#4630c0', '#5a62f0', '#58a6ff', '#9ed8ff', '#e4f6ff', '#ffffff'];
const AQ_FLICK = [1, 0.72, 0.3, 0.95, 0.5, 0.8, 0.22]; // lightning-strike.js のちらつき（30fps のコマごと）
function voltRamp(color) { const a = hsl('#58a6ff'), b = hsl(color), dh = b.s > 0.05 ? b.h - a.h : 0; return VOLT.map((h) => { const c = hsl(h); return hexc(fromHsl({ h: (c.h + dh + 360) % 360, s: c.s, l: c.l })); }); }
function zigzag(Rg, x0, y0, x1, y1, jag = 0.32, forks = 0.35, w = 1, depth = 0) {
  const out = [], L = Math.hypot(x1 - x0, y1 - y0); let pts = [[x0, y0], [x1, y1]], off = L * jag;
  while (pts.length < 2 + L / 3) { const nxt = [pts[0]];
    for (let i = 0; i < pts.length - 1; i++) { const [ax, ay] = pts[i], [bx, by] = pts[i + 1], l = Math.hypot(bx - ax, by - ay) || 1, o = Rg.range(-off, off); nxt.push([(ax + bx) / 2 + (-(by - ay) / l) * o, (ay + by) / 2 + ((bx - ax) / l) * o], [bx, by]); }
    pts = nxt; off *= 0.52; }
  out.push({ pts, w });
  if (depth < 2) for (let i = 2; i < pts.length - 3; i++) if (Rg.chance(forks / (1 + depth) / Math.max(4, pts.length / 6))) {
    const [ax, ay] = pts[i], [bx, by] = pts[Math.min(pts.length - 1, i + 3)], an = Math.atan2(by - ay, bx - ax) + Rg.sign() * Rg.range(0.35, 0.9), l = (L - (i / pts.length) * L) * Rg.range(0.25, 0.55);
    out.push(...zigzag(Rg, ax, ay, ax + Math.cos(an) * l, ay + Math.sin(an) * l, jag * 1.1, forks, w * 0.55, depth + 1)); }
  return out;
}
// 塗り：画素ごとに一番高い段だけを残して1回ずつ塗る（枝の外光が幹の本体を覆わない）
function voltInk(p, paths, k, C, s = 1, thin = false, glowK = 0.5) {
  if (k <= 0.02) return; const grid = new Map(), mark = (x, y, lv) => { const key = Math.floor(x) + ',' + Math.floor(y); if ((grid.get(key) || 0) < lv) grid.set(key, lv); };
  const stamp = (x, y, r, lv) => { if (r <= 0.5) return mark(x, y, lv); for (let py = Math.floor(y - r); py <= Math.ceil(y + r); py++) for (let px2 = Math.floor(x - r); px2 <= Math.ceil(x + r); px2++) if ((px2 + 0.5 - x) ** 2 + (py + 0.5 - y) ** 2 <= r * r) mark(px2, py, lv); };
  for (const q of paths) { const trunk = q.w >= 1; if (!trunk && k < 0.5) continue;
    const rh = thin ? (trunk && k > 0.45 ? 1.2 : 0) : (trunk ? (k > 0.6 ? 2.1 : 1.6) : 1.1) * s, rb = thin ? 0.5 : (trunk ? (k > 0.6 ? 1.3 : 0.8) : 0.5) * s;
    for (let i = 0; i < q.pts.length - 1; i++) { const [ax, ay] = q.pts[i], [bx, by] = q.pts[i + 1], l = Math.max(1, Math.hypot(bx - ax, by - ay));
      for (let d = 0; d <= l; d += 0.5) { const x = ax + (bx - ax) * d / l, y = ay + (by - ay) * d / l; if (rh > 0) stamp(x, y, rh, 1); stamp(x, y, rb, trunk ? 3 : 2); if (trunk && k > 0.3) mark(x, y, 4); } }
    for (let i = 0; i < q.pts.length - 1; i += 3) p.glow(q.pts[i][0], q.pts[i][1], (trunk ? (thin ? 8 : 14) : 6) * s, C[4], glowK * k * q.w); }
  const cols = [C[2], C[4], C[5], C[7]]; for (const [key, lv] of grid) { const [x, y] = key.split(',').map(Number); p.px(x, y, cols[lv - 1]); }
}
// 範囲の中でちらつく短い放電（円は描かない）：count 本、0.06 秒ごとに形と場所が変わる
function aqStatic(p, L, r, count, len, time, seed, C, k) {
  const fr = Math.floor(time / 0.06); for (let i = 0; i < count; i++) { const Rg = new PX.Rng((seed * 97 + i * 13 + fr * 7) >>> 0 || 1); if (!Rg.chance(0.7)) continue;
    const a = Rg.range(0, TAU), d = r * Math.sqrt(Rg.next()) * 0.92, x = L.x + Math.cos(a) * d, y = L.y + Math.sin(a) * d, b = Rg.range(0, TAU), l = len * Rg.range(0.5, 1);
    voltInk(p, zigzag(Rg, x, y, x + Math.cos(b) * l, y + Math.sin(b) * l, 0.35, 0.2), k * Rg.range(0.5, 1), C, 1, true, 0.3); }
}
// 地面に残る放電の跡：中心から枝分かれして伸びる割れ目（着弾ごとに決まった形）
function aqCracks(seed, r) {
  const Rg = new PX.Rng(seed), out = [];
  const grow = (x, y, a, len, w, depth) => { const pts = [[x, y]]; for (let s2 = 0; s2 < len; s2 += 1.5) { a += Rg.range(-0.35, 0.35); x += Math.cos(a) * 1.5; y += Math.sin(a) * 1.5; pts.push([x, y]); if (depth < 2 && s2 > 3 && Rg.chance(0.08)) grow(x, y, a + Rg.sign() * Rg.range(0.5, 1.1), (len - s2) * Rg.range(0.3, 0.6), w * 0.6, depth + 1); } out.push({ pts, w }); };
  for (let i = 0; i < 7; i++) grow(0, 0, i * TAU / 7 + Rg.range(-0.3, 0.3), r * Rg.range(0.55, 0.95), 1, 0);
  return out;
}
// 絵の輪郭の画素（画像の中心から見た画素座標）。帯電の放電を輪郭の上に這わせるのに使う
const EDGE_CACHE = {};
function spriteEdges(key) {
  if (EDGE_CACHE[key]) return EDGE_CACHE[key]; const im = IMG[key]; if (!im) return null; const c = document.createElement('canvas'); c.width = im.width; c.height = im.height; const x = c.getContext('2d'); x.drawImage(im, 0, 0);
  const d = x.getImageData(0, 0, im.width, im.height).data, on = (i, j) => i >= 0 && j >= 0 && i < im.width && j < im.height && d[(j * im.width + i) * 4 + 3] > 80, out = [];
  for (let j = 0; j < im.height; j++) for (let i = 0; i < im.width; i++) if (on(i, j) && (!on(i - 1, j) || !on(i + 1, j) || !on(i, j - 1) || !on(i, j + 1))) out.push([i + 0.5 - im.width / 2, j + 0.5 - im.height / 2]);
  return (EDGE_CACHE[key] = { pts: out, w: im.width, h: im.height });
}
// 帯電（pixelFX lightning/electrified.js の作り）：輪郭の近い2点の間を放電が跳び（1コマおきに打ち直す）、ときどき体全体が電気色に光って火花が散る
function aqElectrify(R, e, time, C, k) {
  const E = spriteEdges('enemy/' + e.type); if (!E || !E.pts.length) return;
  const d = enemyDef(e.type), ang = d.look.fixed_angle ? d.look.angle : d.look.angle + e.facing, sc = 2 * spriteR(e.type, e.r) / Math.max(E.w, E.h), ca = Math.cos(ang), sa = Math.sin(ang);
  const W = (q) => toL(V(e.pos.x + (q[0] * ca - q[1] * sa) * sc, e.pos.y + (q[0] * sa + q[1] * ca) * sc)), f = Math.floor(time * 30), Rg = new PX.Rng((f >> 1) * 7 + 3), jolt = (f % 20) < 3, L0 = toL(e.pos);
  if (jolt) drawEnemy(e, { white: (0.7 - (f % 20) * 0.2) * k }); // 体が電気色に光る
  const n = Math.round((2 + (jolt ? 3 : Rg.int(0, 1))) * k);
  for (let i = 0; i < n; i++) {
    const A = W(Rg.pick(E.pts)); let B = null;
    for (let t2 = 0; t2 < 12; t2++) { const c = W(Rg.pick(E.pts)), dd = Math.hypot(c.x - A.x, c.y - A.y); if (dd > 2 && dd < 9) { B = c; break; } }
    if (!B) continue;
    voltInk(R.front, zigzag(new PX.Rng(f * 13 + i + 1), A.x, A.y, B.x, B.y, 0.42, 0.35), (f & 1 ? 0.75 : 0.95) * k, C, 1, true, 0.4); R.front.px(A.x, A.y, C[5]); R.front.px(B.x, B.y, C[5]);
  }
  if (jolt) for (let i = 0; i < 8; i++) { // 光ったときに輪郭から火花が散る
    const q = new PX.Rng(Math.floor(f / 20) * 31 + i + 1), A = W(q.pick(E.pts)), an = Math.atan2(A.y - L0.y, A.x - L0.x) + q.range(-0.6, 0.6), age = (f % 20) / 30, dd = q.range(20, 50) * age, x = A.x + Math.cos(an) * dd, y = A.y + Math.sin(an) * dd;
    R.front.line(x - Math.cos(an) * 2, y - Math.sin(an) * 2, x, y, (w) => w > 0.5 ? C[7] : C[5], k);
  }
  R.front.glow(L0.x, L0.y, e.r * WL * 2.2, C[4], (jolt ? 0.45 : 0.15) * k);
}
// 後ろの航跡（pixelFX lightning/ball-lightning.js の航跡を下敷き）：通った跡が細りながら冷え、光の粒がこぼれて漂い、筋の上を放電が跳ねる
function aqWake(R, hist, time, C, k) {
  if (hist.length < 2 || k <= 0) return; const f = Math.floor(time * 30);
  for (let i = 1; i < hist.length; i++) {
    const A = toL(hist[i - 1].p), B = toL(hist[i].p), u = clamp((time - hist[i].t) / 0.45); if (u >= 1) continue;
    const w = (1 - u) * 2.2 * k, dx = B.x - A.x, dy = B.y - A.y, l = Math.hypot(dx, dy) || 1;
    for (let d = 0; d <= l; d += 0.5) { const x = A.x + dx * d / l, y = A.y + dy * d / l; for (let q = -w; q <= w; q += 0.5) { const e2 = Math.abs(q) / Math.max(w, 0.01); R.back.px(x - dy / l * q, y + dx / l * q, C[e2 < 0.35 && u < 0.4 ? 6 : u < 0.5 ? 5 : u < 0.75 ? 4 : 3]); } }
    if (i % 3 === 0) R.back.glow(B.x, B.y, 6 * (1 - u) + 2, C[4], 0.3 * (1 - u) * k);
  }
  PX.cycle(time, 0.8, 30, 77, (g) => g.range(0.35, 0.7), (age, life, q) => {
    const h = hist[Math.floor(q.next() * hist.length)]; if (!h || time - h.t > 0.45 || age > time - h.t) return;
    const P0 = toL(h.p), a = q.range(0, TAU), sp = q.range(6, 20), kk = 1 - age / life, x = P0.x + Math.cos(a) * sp * age, y = P0.y + Math.sin(a) * sp * age;
    R.back.px(x, y, kk > 0.6 ? C[6] : kk > 0.3 ? C[4] : C[3]); R.back.glow(x, y, 3, C[4], 0.3 * kk * k);
  });
  if (hist.length > 4 && (f & 1)) { const Rg = new PX.Rng(f + 5), i0 = Rg.int(0, hist.length - 4), A = toL(hist[i0].p), B = toL(hist[Math.min(hist.length - 1, i0 + 3)].p); if (time - hist[i0].t < 0.4) voltInk(R.back, zigzag(Rg, A.x, A.y, B.x, B.y, 0.45, 0.3), 0.6 * k, C, 1, true, 0.3); }
}
DEMOS.push({
  id: 'G12-aquila', ids: ['G12'], cat: G12, group: 'わし座（aquila）', title: '進路固定→突進と落雷', duration: 3.6, color: '#9ed8ff', cam: { x: -160, y: -60 },
  refs: ['scripts/enemies/aquila.gd（aim 0.4・lock 0.45・突進900×0.55・drop_step 0.13・blast 半径220/遅延0.4・recover 0.9）', 'render/enemies/aquila.gd（進路線＋着弾円）・render/attacks/zone_aquila.gd/zone_reticle.gd（閉じる輪・放電）', 'pixelFX lightning/_lib.js（zigzag・stroke の稲妻の作りと塗り）・lightning-strike.js（ちらつき・割れ目・焦げ）'],
  status: { '状態': '試作のみ（作り直し）', '判定': '変更なし（着弾の半径220・発生時刻）', '予兆': '線や円は使わない。進路は着弾点から着弾点へ跳び移る細い放電で示し、着弾点の範囲の中で短い放電がちらつく（溜まるほど増える）', '落雷': 'pixelFX の稲妻（枝分かれ・3段の塗り・ちらつき）が中心から範囲いっぱいへ走る。最初の1コマは全体が白く光り、火花がはじけ、地面が照らされる。割れ目の跡が残って冷える', '本体': 'pixelFX electrified の作りで帯電：輪郭の上を放電が這い、ときどき体全体が電気色に光って火花が散る', '航跡': 'pixelFX ball-lightning の航跡を下敷きに、通った跡が細りながら冷え、光の粒がこぼれ、筋の上を放電が跳ねる' },
  setup(S) { S.e = mkE('aquila', V(-640, -260), 0, { fire_t: 0.15 }); S.ship = shipState(V(180, 120)); S.zones = []; S.e.facing = angOf(sub(S.ship.pos, S.e.pos)); },
  step(S, dt) {
    const e = S.e, p = prm('aquila');
    if (e.mode === 'MOVE' && !S.used) { e.fire_t -= dt; if (e.fire_t <= 0) { e.mode = 'WINDUP'; e.timer = p.aim_time + p.lock_time; S.used = 1; } }
    else if (e.mode === 'WINDUP') { if (e.timer > p.lock_time) { turnToward(e, angOf(sub(S.ship.pos, e.pos)), 2.8, dt); e.charge = 0; } e.timer -= dt;
      if (e.timer <= p.lock_time && e.charge === 0) { const to = sub(S.ship.pos, e.pos); e.facing = angOf(to); const gap = e.r + DATA.config.ship_radius + 12, adv = Math.min(p.dash_speed * p.dash_time, Math.max(0, len(to) - gap)); e.anchor = add(e.pos, mul(fromA(e.facing), adv)); e.charge = 0.01; }
      if (e.timer <= 0) { e.mode = 'DASH'; e.timer = p.dash_time; e.bud_t = 0; e.charge = 0; } else e.charge = Math.max(e.charge, 1 - e.timer / p.lock_time); }
    else if (e.mode === 'DASH') { const dir = fromA(e.facing), rem = Math.max(0, (e.anchor.x - e.pos.x) * dir.x + (e.anchor.y - e.pos.y) * dir.y), trav = Math.min(rem, p.dash_speed * Math.min(dt, e.timer)), el2 = trav / p.dash_speed; let nd = e.bud_t;
      while (nd <= el2 + 1e-5) { S.zones.push({ pos: add(e.pos, mul(dir, p.dash_speed * nd)), t0: S.t + nd, r: p.blast_radius, delay: p.blast_delay, active: 0.25, seed: S.zones.length * 31 + 7 }); nd += p.drop_step; } e.bud_t = nd - el2; e.pos = add(e.pos, mul(dir, trav)); e.timer -= dt;
      if (e.timer <= 0 || rem <= trav + 0.001) { if (p.drop_step - e.bud_t > p.drop_step * 0.25) S.zones.push({ pos: { ...e.pos }, t0: S.t, r: p.blast_radius, delay: p.blast_delay, active: 0.25, seed: S.zones.length * 31 + 7 }); e.mode = 'RECOVER'; e.timer = p.recover; } }
    else if (e.mode === 'RECOVER') { e.timer -= dt; if (e.timer <= 0) e.mode = 'MOVE'; }
    (S.hist ||= []).push({ p: { ...e.pos }, t: S.t }); while (S.hist.length && S.t - S.hist[0].t > 0.5) S.hist.shift(); // 航跡のための位置の履歴
  },
  phase(S) { const e = S.e; return e.mode === 'WINDUP' ? (e.charge > 0 ? '進路固定（予告）' : PH.WINDUP + '（狙い）') : e.mode === 'DASH' ? PH.DASH : S.used ? PH.RECOVER : PH.MOVE; },
  draw(S, R) {
    const e = S.e, P = R.P, p = prm('aquila'), C0 = { r: 0.88, g: 0.97, b: 1, a: 1 }, C = voltRamp(P.color), rr = p.blast_radius * WL;
    if (e.mode === 'WINDUP' && e.charge > 0) {
      const dir = norm(sub(e.anchor, e.pos)), sp = p.dash_speed * p.drop_step, total = dist(e.pos, e.anchor), cs = [];
      for (let d = 0; d <= total + 1e-3; d += sp) cs.push(add(e.pos, mul(dir, d))); if (total - Math.floor(total / sp) * sp > sp * 0.25) cs.push(e.anchor);
      if (!R.proto) { D2.line(e.pos, e.anchor, rgba(C0, 0.65 + 0.3 * e.charge), px(4)); D2.circle(e.pos, px(4), '#fff1cc'); for (const c of cs) D2.arc(c, p.blast_radius, 0, TAU, rgba(C0, 0.35 + 0.4 * e.charge), px(2)); }
      else { // 進路：着弾点から着弾点へ跳び移る細い放電（溜まるほど先まで届く）。着弾点の範囲の中で短い放電がちらつく
        const k = e.charge, reach = Math.ceil(cs.length * Math.min(1, k * 1.4)), fr = Math.floor(S.t / 0.06);
        for (let i = 0; i < reach - 1; i++) { const A = toL(cs[i]), B = toL(cs[i + 1]), Rg = new PX.Rng((i * 53 + fr * 11) >>> 0 || 1); voltInk(R.back, zigzag(Rg, A.x, A.y, B.x, B.y, 0.25, 0.3), 0.35 + 0.35 * k, C, 1, true, 0.35); }
        cs.forEach((c, i) => { if (i < reach) aqStatic(R.back, toL(c), rr, Math.round(1 + 4 * k), rr * 0.3, S.t, i + 3, C, 0.4 + 0.4 * k); }); }
      if (!R.proto) D2.arc(e.pos, e.r * 1.18, 0, TAU * Math.max(0.12, e.charge), `rgba(225,247,255,${0.55 + 0.4 * e.charge})`, px(3));
    }
    for (const z of S.zones) { const t = S.t - z.t0; if (t < 0) continue; const L = toL(z.pos);
      if (!R.proto) { if (t < z.delay) { const k = clamp(t / z.delay), a = 0.25 + 0.55 * k; D2.arc(z.pos, z.r, 0, TAU, rgba(C0, a), px(2)); D2.arc(z.pos, z.r * (1 - 0.7 * k), 0, TAU, rgba(C0, a), px(1.5)); for (let q = 0; q < 4; q++) { const u = fromA(q * Math.PI / 2 + Math.PI / 4); D2.line(add(z.pos, mul(u, z.r * 0.55)), add(z.pos, mul(u, z.r * 1.15)), rgba(C0, a), px(2)); } }
        else if (t < z.delay + z.active) { const f = 1 - (t - z.delay) / z.active; D2.circle(z.pos, z.r, rgba(C0, 0.16 * f)); D2.arc(z.pos, z.r, 0, TAU, rgba(C0, 0.75 * f), px(3)); for (let a = 0; a < 5; a++) { const sh = Math.floor((t - z.delay) / 0.06); let prev = z.pos; const end = add(z.pos, mul(fromA(a * TAU / 5), z.r * 0.65)); for (let s2 = 1; s2 <= 5; s2++) { const q = add(lerpV(z.pos, end, s2 / 5), mul(orth(fromA(a * TAU / 5)), s2 < 5 ? (hash(a * 13 + s2 + sh * 7) - 0.5) * 30 : 0)); D2.line(prev, q, rgba(C0, f), px(2)); prev = q; } } }
        continue; }
      if (t < z.delay) { const k = clamp(t / z.delay); aqStatic(R.back, L, rr, Math.round(3 + 7 * k), rr * (0.2 + 0.25 * k), S.t, z.seed, C, 0.45 + 0.5 * k); R.back.glow(L.x, L.y, 6 + 10 * k, C[5], (0.2 + 0.6 * k) * P.intensity); } // 溜め：範囲の中の放電が増え、中心が光り始める
      else { const a = t - z.delay, fl = AQ_FLICK[Math.floor(a * 30 + 1e-4)] ?? 0, cr = aqCracks(z.seed, rr).map(q => ({ w: q.w, pts: q.pts.map(([x, y]) => [L.x + x, L.y + y]) }));
        const heat = Math.pow(clamp(1 - a / 1.2), 1.4); // 割れ目の跡：熱い色からすすへ冷える
        if (heat > 0) for (const q of cr) for (let i = 0; i < q.pts.length; i++) { const [x, y] = q.pts[i], h = heat * (1 - 0.5 * i / q.pts.length) - hash(x * 7.1 + y * 3.3) * 0.25; R.back.px(x, y, h > 0.6 ? C[6] : h > 0.35 ? C[4] : h > 0.12 ? C[2] : hexc('#141020')); }
        if (fl > 0) { const fr = Math.floor(a * 30), Rg = new PX.Rng((z.seed * 13 + fr) >>> 0 || 1), paths = [];
          for (let j = 0; j < 6; j++) { const an = j * TAU / 6 + Rg.range(-0.35, 0.35), l = rr * Rg.range(0.7, 0.95); paths.push(...zigzag(Rg, L.x, L.y, L.x + Math.cos(an) * l, L.y + Math.sin(an) * l, 0.22, 0.6)); }
          voltInk(R.front, paths, fl, a < 1 / 30 ? C.map((c, i) => C[Math.min(7, i + 2)]) : C, 1.25, false, 0.8); } // 最初の1コマは稲妻全体が白く光る
        if (a < 0.5) for (let j = 0; j < 16; j++) { const q = new PX.Rng(z.seed * 7 + j + 1), life = q.range(0.2, 0.45); if (a > life) continue; const an = q.range(0, TAU), d2 = q.range(25, 60) * a * (1 - a / life * 0.4), x = L.x + Math.cos(an) * d2, y = L.y + Math.sin(an) * d2, tl = 3 * (1 - a / life); R.front.line(x - Math.cos(an) * tl, y - Math.sin(an) * tl, x, y, (w) => w > 0.5 ? C[7] : C[5], 1 - a / life); } // 着地点からはじける火花
        if (a < 0.3) R.back.glow(L.x, L.y, rr * 1.2, C[4], 0.5 * (1 - a / 0.3) * P.intensity); // 地面が照らされる
        if (a < 0.08) { R.front.glow(L.x, L.y, rr * 1.1, C[6], (1 - a / 0.08) * 0.9 * P.intensity); R.front.glow(L.x, L.y, rr * 0.4, C[7], (1 - a / 0.08) * P.intensity); } // 落ちた瞬間の閃光
        if (a > z.active && a < z.active + 0.35) aqStatic(R.back, L, rr * 0.7, 3, rr * 0.18, S.t, z.seed + 5, C, 0.5 * (1 - (a - z.active) / 0.35)); } // 残りの放電
    }
    if (R.proto) { aqWake(R, S.hist || [], S.t, C, e.mode === 'DASH' || e.mode === 'RECOVER' ? 1 : 0.5); R.blitBack(); }
    drawEnemy(e); if (R.proto) aqElectrify(R, e, S.t, C, e.mode === 'WINDUP' ? 0.6 + 0.4 * e.charge : 1); drawShip(S.ship);
  },
});

// 試作の轍：左右それぞれ、区間をつないだ1本の線として途切れずに塗る。揺らぎは轍に沿った距離のなめらかなノイズで、区間をまたいでもつながる。
// 両端は細くとがらせ、明るさは区間ごとの寿命（燃え始め・燃え尽き）を距離に沿って補間する
function aurigaTrail(p, walls, time, P) {
  const pal = FX.ramp(P.color), pts = [];
  for (const w of walls) { const t = time - w.t0, left = w.life - t; if (left <= 0) continue; const k = Math.min(1, clamp(t / 0.12) * (0.3 + 0.7 * clamp(left / (0.6 * P.timing)))) * Math.min(1, P.intensity);
    if (!pts.length) pts.push({ p: toL(w.from), k }); pts.push({ p: toL(add(w.from, mul(fromA(w.a), w.len))), k }); }
  if (pts.length < 2) return; let total = 0; for (let i = 1; i < pts.length; i++) total += Math.hypot(pts[i].p.x - pts[i - 1].p.x, pts[i].p.y - pts[i - 1].p.y);
  const W = walls[0].w * 0.5 * WL * P.size; let cum = 0;
  for (let i = 1; i < pts.length; i++) { const A = pts[i - 1], B = pts[i], dx = B.p.x - A.p.x, dy = B.p.y - A.p.y, L = Math.hypot(dx, dy); if (L < 0.01) continue; const ux = dx / L, uy = dy / L, nx = -uy, ny = ux;
    for (let d = 0; d < L; d += 0.5) { const c = cum + d, k = lerp(A.k, B.k, d / L); if (k <= 0.01) continue;
      const taper = Math.pow(Math.min(1, c / 10, (total - c) / 6), 0.7), n1 = PX.tileNoise(c * 0.22, time * 9, 0, 0, 3) * 0.5 + 0.5, h = W * (0.7 + 0.9 * n1) * k * taper; if (h < 0.3) continue;
      const x0 = A.p.x + ux * d, y0 = A.p.y + uy * d;
      for (let q = -h; q <= h; q += 0.5) { const e = Math.abs(q) / h, lv = e < 0.25 ? 4 : e < 0.5 ? 3 : e < 0.8 ? 2 : 1; p.dot(x0 + nx * q, y0 + ny * q, pal[lv], k * (e > 0.8 ? 0.6 : 1)); }
      if ((Math.round(c * 2) & 3) === 0) p.light(x0, y0, pal[2], 0.22 * k); }
    cum += L; }
}
// ---------- ぎょしゃ座（auriga）
DEMOS.push({
  id: 'G12-auriga', ids: ['G12'], cat: G12, group: 'ぎょしゃ座（auriga）', title: '戦車の燃える轍', duration: 6.6, color: '#ffc46b', cam: { x: 0, y: 0 },
  refs: ['scripts/enemies/auriga.gd・enemy_motion.gd _drive（速さ420で自機へ旋回しながら走行、trail_step 0.12 ごとに左右の轍 fire_wall 幅16・3.5秒）', 'render/attacks/wall.gd（現行の線）', 'pixelFX fire 系の段階色・painter.glow'],
  status: { '状態': '試作のみ', '判定': '変更なし（轍の位置・幅16・寿命3.5秒）', '轍の形': '左右それぞれを区間をつないだ1本の線で途切れずに描き、揺らぎは轍に沿った距離で続く。両端は細くとがる', '比較': 'プレイヤーの爆発（橙の点の爆発）とは形が帯で、白金の色にして区別' },
  setup(S) { S.e = mkE('auriga', V(-520, 200), -0.3); S.ship = shipState(V(60, -20)); S.walls = []; S.e.fire_t = 0; },
  step(S, dt) {
    const e = S.e, p = prm('auriga'), d = enemyDef('auriga');
    if (S.t < 3.0) { turnToward(e, angOf(sub(S.ship.pos, e.pos)), d.turn, dt); e.vel = mul(fromA(e.facing), d.speed); e.pos = add(e.pos, mul(e.vel, dt)); e.fire_t -= dt; if (e.fire_t <= 0) { e.fire_t = p.trail_step; const seg = mul(e.vel, p.trail_step), side = mul(fromA(e.facing + Math.PI / 2), p.wheel_gap); for (const s of [-1, 1]) S.walls.push({ from: add(sub(e.pos, seg), mul(side, s)), a: angOf(seg), len: len(seg), w: p.trail_width, life: p.trail_time, t0: S.t, s }); } }
    else { e.pos = add(e.pos, mul(fromA(e.facing), d.speed * dt)); }
  },
  phase(S) { return S.t < 3 ? PH.DASH + '（走行しながら轍）' : PH.RECOVER + '（轍が燃え尽きる）'; },
  draw(S, R) {
    const P = R.P;
    for (const w of S.walls) { const t = S.t - w.t0, left = w.life - t; if (left <= 0) continue; const b = add(w.from, mul(fromA(w.a), w.len));
      if (!R.proto) { const f = clamp(left / 0.4); D2.line(w.from, b, `rgba(255,138,60,${0.35 * f})`, w.w * 1.5); D2.line(w.from, b, `rgba(255,138,60,${0.9 * f})`, w.w); }
      else { const f = clamp(left / (0.6 * P.timing)); if (f < 1) FXW.sparks(R.front, add(w.from, mul(fromA(w.a), w.len * 0.5)), (0.6 * P.timing - left) % 0.4, w.t0 * 7, 2, '#ffe6b0', 20, 0.4, -Math.PI / 2, 0.8); }
    }
    if (R.proto) for (const sd of [-1, 1]) aurigaTrail(R.back, S.walls.filter(w => w.s === sd), S.t, P); // 区切りの見えない1本の轍
    if (R.proto) R.blitBack();
    drawEnemy(S.e); drawShip(S.ship);
  },
});
