// ===== G12（続き）・G11・参照 =====
// ---------- みなみのかんむり座（corona）
DEMOS.push({
  id: 'G12-corona', ids: ['G12'], cat: G12, group: 'みなみのかんむり座（corona）', title: '渦で捕まえた雑魚を投げる', duration: 4.2, color: '#ff3b3b', cam: { x: -60, y: 0 },
  refs: ['scripts/enemies/corona.gd・corona_vortex.gd（ring 100・spin 4.8・telegraph 0.3・throw_speed 620・throw_life 1.6・throw_effect_scale 1.6・機体の方を向く個体を投げる）', 'corona_vortex.gd draw（渦の弧・選択の脈動・投擲の三角の尾）', 'pixelFX painter.arc・sparks'],
  status: { '状態': '試作のみ', '判定': '変更なし（投擲の頭の半径＝敵半径×1.6、1投1回）', '簡略': '捕捉の吸い込み・抽選の重みは省略し、渦に保持済みの8体（swarm）から順に投げる' },
  setup(S) { S.e = mkE('corona', V(-260, -30), 0); S.ship = shipState(V(260, 60)); S.m = []; for (let i = 0; i < 8; i++) S.m.push({ a: i * TAU / 8, rad: 100 * (0.85 + 0.3 * hash(i)), type: 'swarm', r: enemyR('swarm'), thrown: false }); S.sel = null; S.next = 0.3; },
  step(S, dt) {
    const e = S.e, p = prm('corona'); e.pos = add(e.pos, mul(norm(sub(S.ship.pos, e.pos)), enemyDef('corona').speed * dt));
    for (const m of S.m) if (!m.thrown) { m.a += p.spin * dt; m.pos = add(e.pos, mul(fromA(m.a), m.rad)); m.facing = m.a + Math.PI / 2; m.vel = mul(fromA(m.a + Math.PI / 2), p.spin * m.rad); }
    if (!S.sel && S.t >= S.next && S.m.some(m => !m.thrown)) { const cand = S.m.filter(m => !m.thrown); S.sel = cand[Math.floor(hash(S.t * 7) * cand.length)]; S.sel.selT = S.t; e.mode = 'WINDUP'; }
    if (S.sel) { e.charge = clamp((S.t - S.sel.selT) / p.telegraph); const m = S.sel; if (S.t - m.selT >= p.telegraph && Math.abs(angDiff(angOf(m.vel), angOf(sub(S.ship.pos, m.pos)))) < p.align_angle * 3) { m.thrown = true; m.t0 = S.t; m.v = mul(fromA(angOf(m.vel)), p.throw_speed); S.sel = null; e.mode = 'MOVE'; e.charge = 0; S.next = S.t + p.fire_interval + 0.6; } }
    for (const m of S.m) if (m.thrown && S.t - m.t0 < p.throw_life) { m.pos = add(m.pos, mul(m.v, dt)); m.facing = angOf(m.v); }
  },
  phase(S) { return S.sel ? PH.WINDUP + '（投げる個体を予告）' : S.m.some(m => m.thrown && S.t - m.t0 < 1.6) ? PH.DASH + '（投擲）' : PH.MOVE; },
  draw(S, R) {
    const e = S.e, P = R.P, p = prm('corona'), ATT = '#ff3b3b', CORE = '#ffb36b';
    if (!R.proto) { for (let k = 0; k < 3; k++) { const a = S.t * p.spin + k * TAU / 3; D2.arc(e.pos, p.ring * (0.72 + k * 0.14), a, a + 1.8, 'rgba(182,162,219,.3)', 3); } if (S.sel) D2.arc(e.pos, e.r * 1.2, -Math.PI / 2, -Math.PI / 2 + Math.max(0.02, e.charge) * TAU, ATT, 4); }
    else { const L = toL(e.pos), pal = FX.ramp('#b6a2db'); for (let i = 0; i < 70; i++) { const rr = p.ring * WL * (0.55 + 0.6 * hash(i)), a0 = S.t * p.spin * (0.8 + 0.4 * hash(i + 9)) + hash(i * 3) * TAU; for (let s = 0; s < 4; s++) R.back.dot(L.x + Math.cos(a0 - s * 0.08) * rr, L.y + Math.sin(a0 - s * 0.08) * rr, pal[s < 1 ? 3 : 2], 0.55 - 0.12 * s); } if (S.sel) R.back.arc(L.x, L.y, e.r * WL * 1.25, 1, -Math.PI / 2, -Math.PI / 2 + e.charge * TAU, hexc(P.color), 0.9); R.blitBack(); }
    drawEnemy(e);
    for (const m of S.m) { if (m.thrown && S.t - m.t0 >= p.throw_life) continue; drawEnemy({ type: 'swarm', pos: m.pos, facing: m.facing, r: m.r });
      const r = m.r * p.throw_effect_scale;
      if (m.thrown) { const u = norm(m.v), sd = mul(orth(u), r);
        if (!R.proto) { D2.poly([add(m.pos, sd), sub(m.pos, mul(u, r * 4.5)), sub(m.pos, sd)], 'rgba(255,59,59,.35)'); D2.circle(m.pos, r, 'rgba(255,59,59,.15)'); D2.arc(m.pos, r, 0, TAU, ATT, 3); D2.arc(m.pos, r * 1.08, angOf(u) - 1.2, angOf(u) + 1.2, CORE, 3); }
        else { const L = toL(m.pos), pal = FX.ramp(P.color); for (let s = 0; s < 18; s++) { const q = sub(m.pos, mul(u, s * r * 0.3)), Q = toL(q), w = r * WL * (1 - s / 18); for (let j = -w; j <= w; j += 0.7) R.front.dot(Q.x - u.y * j, Q.y + u.x * j, pal[s < 3 ? 4 : s < 8 ? 3 : 2], (1 - s / 18) * Math.min(1, P.intensity)); } R.front.arc(L.x, L.y, r * WL * 1.05, 1.5, angOf(u) - 1.3, angOf(u) + 1.3, pal[4], 1); R.front.glow(L.x, L.y, r * WL * 2, pal[2], 0.5 * P.intensity); FXW.sparks(R.front, m.pos, (S.t - m.t0) % 0.25, Math.floor((S.t - m.t0) / 0.25) + m.a, 4, P.color, 30, 0.25, angOf(u) + Math.PI, 0.6); }
      } else if (S.sel === m) { const pulse = 0.65 + 0.35 * Math.sin(S.t * 18);
        if (!R.proto) { D2.arc(m.pos, r, 0, TAU, `rgba(255,59,59,${pulse})`, 3); D2.line(e.pos, m.pos, 'rgba(255,59,59,.35)', 2); }
        else { const L = toL(m.pos), pal = FX.ramp(P.color), k = e.charge; R.front.ring(L.x, L.y, r * WL * (1.6 - 0.6 * k), 1, pal[3], 0.5 + 0.5 * k); for (let q = 0; q < 4; q++) { const a = q * Math.PI / 2 + S.t * 3; R.front.dot(L.x + Math.cos(a) * r * WL * (1.6 - 0.6 * k), L.y + Math.sin(a) * r * WL * (1.6 - 0.6 * k), pal[4]); } R.front.glow(L.x, L.y, r * WL * 1.5, pal[2], 0.35 * k * P.intensity); }
      }
    }
    drawShip(S.ship);
  },
});

// ---------- 噛みつき（猟犬・守る雑魚。scripts/enemies/biter.gd の共通の噛みつき）
function biteStep(S, e, dt, p, def) {
  const ship = S.ship.pos;
  if (e.mode === 'WINDUP') { turnToward(e, angOf(sub(ship, e.pos)), def.turn * 2, dt); e.timer -= dt; e.charge = 1 - Math.max(0, e.timer) / p.bite_telegraph; if (e.timer <= 0) { S.bites.push({ pos: add(e.pos, mul(fromA(e.facing), e.r + p.bite_reach * 0.5)), r: p.bite_radius, t0: S.t, a: e.facing }); e.charge = 0; e.mode = 'RECOVER'; e.timer = p.bite_rest; } return; }
  const d = sub(ship, e.pos); e.facing = rotToward(e.facing, angOf(d), def.turn * dt);
  if (len(d) > e.r + p.bite_reach + DATA.config.ship_radius) e.pos = add(e.pos, mul(fromA(e.facing), def.speed * dt));
  if (e.mode === 'RECOVER') { e.timer -= dt; if (e.timer <= 0) e.mode = 'MOVE'; }
  else if (len(d) <= e.r + p.bite_reach + DATA.config.ship_radius) { e.mode = 'WINDUP'; e.timer = p.bite_telegraph; e.flash = 0.1; }
  e.flash = Math.max(0, e.flash - dt);
}
function drawBites(S, R, type) {
  const P = R.P, col = ecol(type, 0.4);
  for (const b of S.bites) { const t = S.t - b.t0;
    if (!R.proto) { if (t < 0.25) { const f = 1 - t / 0.25, shut = 1 - f; for (const s of [-1, 1]) { const a0 = Math.PI / 2 * s * (1 - shut * 0.8); D2.arc(b.pos, b.r * 0.75, a0 - 0.9, a0 + 0.9, `rgba(255,255,255,${f})`, px(3)); } D2.circle(b.pos, b.r * 0.4, rgba(col, 0.35 * f)); } }
    else { const tt = t / P.timing; if (tt < 0.35) { const close = clamp(tt / 0.08), f = tt < 0.08 ? 1 : 1 - (tt - 0.08) / 0.27; for (const s of [-1, 1]) { const a0 = b.a + s * lerp(1.5, 0.35, close); FXW.crescent(R.front, add(b.pos, mul(fromA(b.a), -b.r * 0.2)), b.r * 0.85 * P.size, a0, b.a + s * 0.05 + (s > 0 ? 0 : 0), 1, 0, 3.2, P.color, f * Math.min(1, P.intensity)); } if (tt > 0.06) FXW.sparks(R.front, b.pos, tt - 0.06, b.t0 * 9, 6, '#ffffff', 25, 0.2); } }
  }
}
function biteMarks(R, e) { // 予備動作：現行は共通の口元の円（enemy_visual.gd draw_marks）
  if (e.charge <= 0) return; const mz = add(e.pos, mul(fromA(e.facing), e.r));
  if (!R.proto) D2.circle(mz, px(3) + e.r * 0.45 * e.charge, `rgba(255,230,153,${0.35 + 0.55 * e.charge})`);
  else { const P = R.P, L = toL(mz), pal = FX.ramp(P.color), k = e.charge; for (const s of [-1, 1]) { const a = e.facing + s * lerp(1.2, 0.5, k); R.front.line(L.x + Math.cos(a) * 3, L.y + Math.sin(a) * 3, L.x + Math.cos(a) * (3 + 3 * k * P.size), L.y + Math.sin(a) * (3 + 3 * k * P.size), pal[4], k); } R.front.glow(L.x, L.y, 4 + 4 * k, pal[2], 0.4 * k * P.intensity); }
}
DEMOS.push({
  id: 'G12-hound', ids: ['G12'], cat: G12, group: '猟犬（hound）', title: '群れの噛みつき', duration: 4.0, color: '#ffe8c0', cam: { x: 0, y: 0 },
  refs: ['scripts/enemies/hound.gd（群れの追跡）→ biter.gd の共通の噛みつき（bite_telegraph 0.3・bite_reach 22・半径26・bite_rest 0.8）', 'render/enemies/enemy_visual.gd draw_marks・render/attacks/zone_bite.gd（現行）', 'pixelFX melee/sword-slash.js の三日月'],
  status: { '状態': '試作のみ', '判定': '変更なし（判定の円＝口の前 r+11、半径26、0.25秒）', '簡略': '群れの整列（alignment/cohesion）は省略し、各個体が直接追跡' },
  setup(S) { S.ship = shipState(V(160, 30)); S.bites = []; S.hs = []; for (let k = 0; k < 5; k++) S.hs.push(mkE('hound', V(-200 - 38 * ((k + 1) >> 1), 30 + (k % 2 ? 19 : -19) * (k ? 1 : 0)), 0)); },
  step(S, dt) { for (const e of S.hs) biteStep(S, e, dt, prm('hound'), enemyDef('hound')); },
  phase(S) { return S.hs.some(e => e.mode === 'WINDUP') ? PH.WINDUP : S.bites.length ? PH.DASH + '／' + PH.RECOVER : PH.MOVE; },
  draw(S, R) { for (const e of S.hs) drawEnemy(e); drawShip(S.ship); drawBites(S, R, 'hound'); for (const e of S.hs) biteMarks(R, e); },
});
DEMOS.push({
  id: 'G12-defender', ids: ['G12'], cat: G12, group: '守る雑魚（defender）', title: '列で守る→守る相手がいないと噛みつく', duration: 5.2, color: '#ffe8c0', cam: { x: -300, y: 0 },
  refs: ['scripts/enemies/defender.gd（guard_radius 600 内の強敵と機体を結ぶ線上へ guard_spacing 42 で整列、守る相手がいないと biter.gd の噛みつき）'],
  status: { '状態': '試作のみ', '判定': '変更なし', '演出': 'デモでは t=1.6s で守る相手（ぼうえんきょう座）を外し、噛みつきへ移る現行の挙動を見せる' },
  setup(S) { S.ship = shipState(V(-120, 40)); S.bites = []; S.tel = mkE('telescope', V(-620, -20), 0); S.ds = []; for (let k = 0; k < 3; k++) S.ds.push(mkE('defender', V(-500, -100 + k * 60), 0)); },
  step(S, dt) {
    const p = prm('defender'), def = enemyDef('defender');
    if (S.t < 1.6) { const fw = norm(sub(S.ship.pos, S.tel.pos)), sd = orth(fw); const off = Math.min(S.tel.r + S.ds[0].r + p.guard_distance, dist(S.ship.pos, S.tel.pos) * 0.5); S.ds.forEach((e, k) => { const goal = add(add(S.tel.pos, mul(fw, off)), mul(sd, (k - 1) * Math.max(p.guard_spacing, e.r * 2))); e.pos = lerpV(e.pos, goal, 1 - Math.exp(-4 * dt)); turnToward(e, angOf(sub(S.ship.pos, e.pos)), def.turn, dt); }); S.tel.facing = angOf(sub(S.ship.pos, S.tel.pos)); }
    else for (const e of S.ds) biteStep(S, e, dt, p, def);
  },
  phase(S) { return S.t < 1.6 ? '整列（守る）' : S.ds.some(e => e.mode === 'WINDUP') ? PH.WINDUP : S.bites.length ? PH.DASH + '／' + PH.RECOVER : PH.MOVE; },
  draw(S, R) { if (S.t < 1.6) drawEnemy(S.tel, { alpha: S.t > 1.3 ? (1.6 - S.t) / 0.3 : 1 }); for (const e of S.ds) drawEnemy(e); drawShip(S.ship); drawBites(S, R, 'defender'); for (const e of S.ds) biteMarks(R, e); },
});

// ---------- ケフェウス座（cepheus・兵 cepheus_soldier）
DEMOS.push({
  id: 'G12-cepheus', ids: ['G12'], cat: G12, group: 'ケフェウス座（cepheus・兵）', title: '召喚の予告→号令の一斉射撃', duration: 4.4, color: '#c9a6ff', cam: { x: -140, y: 0 },
  params: [{ k: 'gold', label: '召喚の金色', type: 'color', def: '#ffd98a' }],
  refs: ['scripts/enemies/cepheus.gd（summon_time 0.9・隊列3体 row_near 120/spacing 120・fire_interval 0.8・VOLLEY_WARNING 0.4）', 'scripts/enemies/soldier.gd（号令で bolt）', 'render/enemies/cepheus.gd（召喚の紋章輪）・render/enemies/soldier.gd（予告線90＋弧）・render/attacks/bolt.gd（紫の光弾）'],
  status: { '状態': '試作のみ', '判定': '変更なし（光弾の速さ640・向きは隊列の向き）' },
  setup(S) { S.e = mkE('cepheus', V(-520, -20), 0); S.ship = shipState(V(220, 40)); S.e.facing = angOf(sub(S.ship.pos, S.e.pos)); S.e.anchor = { ...S.e.pos }; S.e.mode = 'WINDUP'; S.e.timer = prm('cepheus').summon_time; S.sol = []; S.bolts = []; S.vol = 0; },
  step(S, dt) {
    const e = S.e, p = prm('cepheus'), u = fromA(e.facing), n = orth(u);
    const slot = (k) => add(add(e.anchor, mul(u, p.row_near)), mul(n, (k - 1) * p.spacing));
    if (e.mode === 'WINDUP') { e.timer -= dt; e.charge = 1 - clamp(e.timer / p.summon_time); if (e.timer <= 0) { for (let k = 0; k < 3; k++) S.sol.push(mkE('cepheus_soldier', slot(k), e.facing, { buds: k, charge: 0 })); e.mode = 'MOVE'; e.charge = 0; e.timer = p.fire_interval; } return; }
    e.timer -= dt;
    for (const s of S.sol) s.charge = e.timer <= 0.4 && S.vol < 3 ? Math.min(1, s.charge + Math.min(dt, 0.05) / 0.4) : 0;
    if (e.timer <= 0 && S.vol < 3) { S.vol++; for (const s of S.sol) { if (s.charge >= 0.99) S.bolts.push({ pos: add(s.pos, mul(fromA(s.facing), s.r)), a: s.facing, t0: S.t }); s.charge = 0; } e.timer = p.fire_interval; }
    for (const b of S.bolts) b.pos = add(b.pos, mul(fromA(b.a), prm('cepheus_soldier').bolt_speed * dt));
  },
  phase(S) { return S.e.mode === 'WINDUP' ? '召喚の予告' : S.sol.some(s => s.charge > 0) ? PH.WINDUP + '（射撃予告）' : S.vol < 3 ? PH.DASH : PH.RECOVER; },
  draw(S, R) {
    const e = S.e, P = R.P, p = prm('cepheus'), u = fromA(e.facing), n = orth(u);
    if (e.mode === 'WINDUP') { const k = e.charge;
      for (let s = 0; s < 3; s++) { const at = add(add(e.anchor, mul(u, p.row_near)), mul(n, (s - 1) * p.spacing));
        if (!R.proto) { D2.line(e.pos, at, `rgba(255,217,115,${0.25 + 0.35 * k})`, px(2)); D2.arc(at, 30 * (1.6 - 0.6 * k), 0, TAU, rgba(lighten(enemyColor('cepheus'), 0.35), 0.4 + 0.5 * k), px(2.5)); for (let q = 0; q < 5; q++) { const a = S.t * 2 + q * TAU / 5; D2.line(add(at, mul(fromA(a), 18)), add(at, mul(fromA(a), 26 + 10 * (1 - k))), `rgba(255,217,115,${0.6 * k})`, px(2)); } D2.circle(at, 6 + 8 * k, `rgba(255,242,191,${0.3 + 0.5 * k})`); }
        else { const L = toL(at), pal = FX.ramp(P.gold), r = 30 * WL * (1.4 - 0.4 * k) * P.size; R.back.ring(L.x, L.y, r, 1, pal[3], 0.5 + 0.5 * k); R.back.ring(L.x, L.y, r * 0.62, 1, pal[2], 0.6 * k); for (let q = 0; q < 6; q++) { const a = S.t * 1.6 + q * TAU / 6; R.back.dot(L.x + Math.cos(a) * r * 0.81, L.y + Math.sin(a) * r * 0.81, pal[4], k); R.back.dot(L.x + Math.cos(a) * r * 0.81 + 0.7, L.y + Math.sin(a) * r * 0.81, pal[3], k * 0.7); } R.back.glow(L.x, L.y, r * 1.4, pal[2], 0.3 * k * P.intensity); for (let yy = 0; yy < 18 * k; yy += 0.7) R.front.dot(L.x + (hash(yy * 3 + s) - 0.5) * 2, L.y - yy, pal[yy < 4 ? 4 : 3], (1 - yy / 18) * k); FXW.warnRail(R.back, e.pos, at, { color: P.gold, k: 0.3 + 0.4 * k, time: S.t, seed: s + 40, rail: 0.8, intensity: 0.7 * P.intensity }); }
      }
      if (!R.proto) { D2.arc(e.pos, e.r * (1.15 + 0.3 * k), 0, TAU, `rgba(255,217,102,${0.35 + 0.5 * k})`, px(3)); D2.circle(sub(e.pos, mul(u, e.r * 0.55)), e.r * (0.15 + 0.2 * k), `rgba(255,235,153,${0.5 + 0.4 * k})`); }
      else FXW.gather(R.front, sub(e.pos, mul(u, e.r * 0.55)), e.r * 1.4, k * P.intensity, P.gold, S.t, 12, 3);
    }
    if (R.proto) R.blitBack();
    drawEnemy(e); for (const s of S.sol) drawEnemy(s); drawShip(S.ship);
    for (const s of S.sol) if (s.charge > 0) { const dir = fromA(s.facing), st = add(s.pos, mul(dir, s.r));
      if (!R.proto) { const glow = `rgba(255,224,122,${0.25 + 0.55 * s.charge})`; D2.line(st, add(st, mul(dir, 90)), glow, px(2)); D2.arc(s.pos, s.r * 1.4, 0, TAU * s.charge, glow, px(2)); }
      else { FXW.warnRail(R.front, st, add(st, mul(dir, 260)), { color: P.color, k: s.charge, time: S.t, seed: s.buds + 50, rail: 1, intensity: P.intensity, reveal: s.charge }); FXW.gather(R.front, st, s.r * 1.3, s.charge * P.intensity, P.color, S.t, 6, s.buds + 3); } }
    for (const b of S.bolts) { const u2 = fromA(b.a);
      if (!R.proto) { D2.line(sub(b.pos, mul(u2, 34)), add(b.pos, mul(u2, 6)), 'rgba(191,153,255,.35)', 14); D2.line(sub(b.pos, mul(u2, 30)), add(b.pos, mul(u2, 4)), 'rgb(217,191,255)', 6); D2.line(sub(b.pos, mul(u2, 24)), add(b.pos, mul(u2, 2)), 'rgba(255,255,255,.95)', 2.5); }
      else { const L = toL(b.pos), pal = FX.ramp(P.color), T = toL(sub(b.pos, mul(u2, 46))); R.front.beam(T.x, T.y, L.x, L.y, 2.6 * P.size, (uu, v) => uu > 0.8 ? pal[4] : v < 0.4 ? pal[3] : pal[2], (uu) => Math.min(1, 0.25 + uu)); R.front.circle(L.x, L.y, 1.6 * P.size, pal[4]); R.front.glowLine(T.x, T.y, L.x, L.y, 4, pal[2], 0.4 * P.intensity); if (S.t - b.t0 < 0.08) FXW.flare(R.front, sub(b.pos, mul(u2, 640 * (S.t - b.t0))), 8, P.color, S.t, 1 - (S.t - b.t0) / 0.08, 4); }
    }
  },
});

// ---------- プレイヤーの爆発（比較用の参照：エンドブラストの近似）
function drawPlayerBlastRef(S, R, at, t0) {
  const t = S.t - t0; if (t < 0 || t > 0.7) return;
  const L = toL(at), pal = FX.ramp('#ffb347'), r = 150 * WL * clamp(t / 0.12) ** 0.5, f = 1 - smooth(0.25, 0.7, t);
  for (let i = 0; i < 90; i++) { const a = hash(i) * TAU, d = r * Math.sqrt(hash(i * 3.3)), x = L.x + Math.cos(a) * d, y = L.y + Math.sin(a) * d; R.front.circle(x, y, 1.6 * f + 0.5, pal[d / r < 0.4 ? 4 : d / r < 0.7 ? 3 : 2], f); }
  R.front.glow(L.x, L.y, r * 1.3, pal[3], 0.6 * f);
  g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.font = '12px system-ui'; g.fillStyle = '#ffd27a'; const sp = (toL(at)); g.fillText('参照：プレイヤーのエンドブラスト（近似）', sp.x * LP - 90, sp.y * LP + 70); g.restore(); worldTransform();
}
// ---------- ほうおう座（phoenix）：G11 鳳凰の攻撃エフェクト（ステージ3の敵なので G12 の内訳も兼ねる）
DEMOS.push({
  id: 'G11-phoenix', ids: ['G11', 'G12'], cat: '鳳凰 G11', group: 'ほうおう座（phoenix）', title: '離脱→着地点の予告→飛び込みと炎', duration: 5.2, color: '#ff3d6e', cam: { x: 60, y: -40 },
  params: [{ k: 'core', label: '炎の芯の色', type: 'color', def: '#ffd0f0' }, { k: 'playerRef', label: 'プレイヤーの爆発を並べる(0/1)', type: 'range', min: 0, max: 1, step: 1, def: 1 }],
  refs: ['scripts/enemies/phoenix.gd（retreat 0.9/700・telegraph 1.4・dive 0.4・impact 半径220/0.6s・recover 1.8）', 'render/enemies/phoenix.gd（影・輪・火の粉の専用shader）・render/attacks/zone_phoenix.gd（blast_bursts の点の爆発）', 'shaders/phoenix_flames.gdshader・blast_burst.gdshader（現行。ここでは近似）', 'pixelFX fire/explosions の段階色・painter.disc/glow', 'プレイヤーのエンドブラスト（W29、blast_bursts 共用）との比較'],
  status: { '状態': '試作のみ', '判定': '変更なし（着地点＝予告開始時の自機位置、半径220、炎0.6秒）', '炎・爆発': '現行の着地の炎はプレイヤーのエンドブラストと同じ blast_bursts（橙の点の爆発）を使っており見た目が重なる。試作は紅〜紫の羽根形の炎が放射する形にし、色と形の両方で区別', '近似': '現行の予告の火の粉（phoenix_flames.gdshader）と着地の点の爆発は形・時間を簡略化して再現' },
  setup(S) { S.e = mkE('phoenix', V(-120, -220), 0); S.ship = shipState(V(200, 120)); S.e.timer = 0; },
  step(S, dt) {
    const e = S.e, p = prm('phoenix');
    const adv = (target) => { const d = sub(target, e.pos); if (len(d) > 0.01) e.facing = angOf(d); e.pos = lerpV(e.pos, target, clamp(dt / Math.max(0.001, e.timer))); e.timer = Math.max(0, e.timer - dt); };
    if (e.mode === 'MOVE') { if (!e.anchor) { e.anchor = add(e.pos, mul(norm(sub(e.pos, S.ship.pos)), p.retreat_distance)); e.timer = p.retreat_time; } adv(e.anchor); if (e.timer <= 0) { e.anchor = { ...S.ship.pos }; e.mode = 'WINDUP'; e.timer = p.telegraph; e.facing = angOf(sub(e.anchor, e.pos)); } }
    else if (e.mode === 'WINDUP') { e.timer = Math.max(0, e.timer - dt); e.charge = 1 - e.timer / p.telegraph; if (e.timer <= 0) { e.mode = 'DASH'; e.timer = p.dive_time; e.charge = 0; } }
    else if (e.mode === 'DASH') { adv(e.anchor); if (e.timer <= 0) { S.flame = { pos: { ...e.anchor }, r: Math.max(e.r * 1.1, p.impact_radius), t0: S.t, life: p.impact_time }; e.mode = 'RECOVER'; e.timer = p.recover_time; } }
    else if (e.mode === 'RECOVER') e.timer = Math.max(0, e.timer - dt);
    S.ship.pos.x = 200 + Math.sin(S.t * 0.8) * 20;
  },
  phase(S) { const m = S.e.mode; return m === 'MOVE' ? '離脱' : m === 'WINDUP' ? PH.WINDUP + '（着地点）' : m === 'DASH' ? '飛び込み' : S.flame && S.t - S.flame.t0 < S.flame.life ? PH.DASH + '（着地の炎）' : PH.RECOVER; },
  draw(S, R) {
    const e = S.e, P = R.P, p = prm('phoenix'), FLAME = '#ff6a2a';
    if (e.mode === 'WINDUP' || e.mode === 'DASH') { const c = e.anchor, rad = Math.max(e.r * 1.1, p.impact_radius), k = e.mode === 'WINDUP' ? e.charge : 1;
      if (!R.proto) { D2.circle(c, rad, rgba(FLAME, 0.025 + 0.035 * k)); D2.arc(c, rad, 0, TAU, rgba(FLAME, 0.3 + 0.5 * k), px(2)); const ss = e.r * (0.5 + 0.5 * k), pts = [[0, -1], [0.28, -0.15], [1.2, 0.4], [0.3, 0.22], [0, 0.9], [-0.3, 0.22], [-1.2, 0.4], [-0.28, -0.15]].map(([x, y]) => { const a = e.facing + Math.PI / 2, q = V(x * ss, y * ss); return add(c, V(q.x * Math.cos(a) - q.y * Math.sin(a), q.x * Math.sin(a) + q.y * Math.cos(a))); }); D2.poly(pts, `rgba(23,9,4,${0.5 + 0.35 * k})`); D2.polyline([...pts, pts[0]], rgba(FLAME, 0.3 + 0.6 * k), px(1.5)); for (let i = 0; i < 24; i++) { const a = hash(i) * TAU, d = rad * Math.sqrt(hash(i + 7)), y = ((hash(i * 3) + S.t * 0.7) % 1); D2.circle(add(c, V(Math.cos(a) * d, Math.sin(a) * d - y * 90 * k)), 3, rgba('#ffb35a', (1 - y) * k)); } }
      else { const L = toL(c), pal = FX.ramp(P.color), r = rad * WL;
        // 鳳凰の紋：8枚の羽根形の炎の芽が円周から中心へ向けて灯り、内側に翼の影
        for (let q = 0; q < 8; q++) { const a = q * TAU / 8 + S.t * 0.3, grow = clamp(k * 1.3 - q * 0.04); const bx = L.x + Math.cos(a) * r, by = L.y + Math.sin(a) * r; for (let s = 0; s < 6 * grow; s += 0.5) { const w = (1 - s / 6) * 1.6; for (let j = -w; j <= w; j += 0.5) R.back.dot(bx - Math.cos(a) * s - Math.sin(a) * j, by - Math.sin(a) * s + Math.cos(a) * j, pal[s < 1.5 ? 4 : s < 3.5 ? 3 : 2], grow); } R.back.glow(bx, by, 5, pal[2], 0.4 * grow * P.intensity); }
        R.back.ring(L.x, L.y, r, 1, pal[2], 0.35 + 0.4 * k);
        const ss = e.r * (0.5 + 0.5 * k) * WL; R.back.disc(L.x, L.y, ss * 1.1, hexc('#170904'), (dd) => (0.35 + 0.35 * k) * (1 - dd * dd));
        for (let i = 0; i < 40; i++) { const a = hash(i) * TAU, d = r * Math.sqrt(hash(i + 7)), y = ((hash(i * 3) + S.t * (0.5 + hash(i))) % 1); R.front.dot(L.x + Math.cos(a) * d, L.y + Math.sin(a) * d + (1 - y) * -14 * k, pal[y < 0.3 ? 4 : 3], (1 - y) * k); }
        if (e.mode === 'DASH') { const T = toL(e.pos), u = fromA(e.facing); for (let s = 0; s < 30; s++) { const w = 3 * (1 - s / 30); for (let j = -w; j <= w; j += 0.6) R.front.dot(T.x - u.x * s * 1.5 - u.y * j, T.y - u.y * s * 1.5 + u.x * j, pal[s < 5 ? 4 : s < 14 ? 3 : 2], 1 - s / 30); } R.front.glow(T.x, T.y, 16, pal[3], 0.6); }
        R.blitBack();
      }
    }
    if (S.flame) { const t = S.t - S.flame.t0, L = toL(S.flame.pos), r = S.flame.r * WL;
      if (!R.proto) { // blast_bursts の点の爆発（近似）：橙の粒が判定半径まで広がって消える
        if (t < 0.9) { const f = 1 - smooth(0.3, 0.9, t), pal = FX.ramp('#ff9a3c'); for (let i = 0; i < 160; i++) { const a = hash(i) * TAU, d = r * Math.sqrt(hash(i * 3.3)) * clamp(t / 0.15) ** 0.5; R.front.circle(L.x + Math.cos(a) * d, L.y + Math.sin(a) * d, 1.8 * f + 0.5, pal[d / r < 0.35 ? 4 : d / r < 0.7 ? 3 : 2], f); } R.front.glow(L.x, L.y, r * 1.2, pal[3], 0.6 * f); }
      } else { const life = S.flame.life * P.timing, pal = FX.ramp(P.color), core = FX.ramp(P.core);
        if (t < 0.08) { R.front.circle(L.x, L.y, r * 0.35 * (1 + t / 0.08), core[4], 1 - t / 0.08); R.front.glow(L.x, L.y, r * 1.3, core[3], 1); }
        if (t < life + 0.4) { const g1 = clamp(t / 0.14), f = 1 - smooth(life * 0.5, life + 0.4, t);
          for (let q = 0; q < 12; q++) { const a = q * TAU / 12 + hash(q) * 0.3, reach = r * (0.75 + 0.25 * hash(q + 4)) * g1 * P.size; // 羽根形の炎：中心から外へ、先端が反る
            for (let s = 0; s < reach; s += 0.6) { const u = s / reach, wob = Math.sin(u * 3 + t * 9 + q) * 1.2 * u, w = (1 - u) * 3.2 * (0.6 + 0.4 * Math.sin(t * 20 + q * 2 + s * 0.3)); const cx = L.x + Math.cos(a) * s - Math.sin(a) * wob, cy = L.y + Math.sin(a) * s + Math.cos(a) * wob; for (let j = -w; j <= w; j += 0.6) { const e2 = Math.abs(j) / Math.max(w, 0.01); R.front.dot(cx - Math.sin(a) * j, cy + Math.cos(a) * j, e2 < 0.3 && u < 0.6 ? core[4] : e2 < 0.6 ? pal[3] : pal[2], f * (u > 0.85 ? 0.5 : 1)); } if (s % 3 < 0.6) R.front.light(cx, cy, pal[2], 0.25 * f * P.intensity); } }
          FX.shock(R.front, V(L.x, L.y), r * (0.85 + 0.2 * g1), 1.5, P.color, 0.8 * f * g1); R.front.glow(L.x, L.y, r * 1.1, pal[2], 0.45 * f * P.intensity);
          for (let i = 0; i < 30; i++) { const lf = 0.5 + hash(i) * 0.5, tt = t - hash(i * 7) * 0.2; if (tt < 0 || tt > lf) continue; const a = hash(i * 3) * TAU, d = r * 0.5 * hash(i + 2) + 10 * tt, y = -tt * 30; R.front.dot(L.x + Math.cos(a) * d, L.y + Math.sin(a) * d + y, core[tt / lf < 0.4 ? 4 : 3], 1 - tt / lf); }
        }
      }
    }
    drawEnemy(e, { alpha: 1 }); drawShip(S.ship);
    if (R.proto && P.playerRef && S.flame) { const at = add(S.flame.pos, V(-460, 40)); drawPlayerBlastRef(S, R, at, S.flame.t0); }
  },
});

// ---------- 参照：ステージ1 かじき座の現行予兆（marlin_warning.gdshader の移植。G12 の予兆作り直しの基準）
DEMOS.push({
  id: 'REF-marlin', ids: ['参照'], cat: '参照（ステージ1）', group: 'かじき座（marlin）', title: '現行の予兆ビーム（参照）', duration: 2.6, color: '#ff4a3d', cam: { x: 0, y: 0 },
  refs: ['shaders/marlin_warning.gdshader（11の光の包み・芯・中間・光・左右の平行光・envelope）', 'scripts/render/enemies/marlin.gd（WARNING_HALF_HEIGHT 7、REFERENCE_HEIGHT 225、beam_length＝距離÷論理ピクセル）', 'scripts/enemies/marlin.gd（telegraph 0.8、dash 1300×0.9）'],
  status: { '状態': '現行の再現（参照用。変更なし）' },
  setup(S) { S.e = mkE('marlin', V(-480, -120), 0, { mode: 'WINDUP', timer: 0.8 }); S.ship = shipState(V(240, 110)); S.e.facing = angOf(sub(S.ship.pos, S.e.pos)); },
  step(S, dt) { const e = S.e, p = prm('marlin'); if (e.mode === 'WINDUP') { e.timer -= dt; e.charge = clamp(1 - e.timer / p.telegraph, 0.01, 1); if (e.timer <= 0) { e.mode = 'DASH'; e.timer = p.dash_time; } } else if (e.mode === 'DASH') { e.pos = add(e.pos, mul(fromA(e.facing), p.dash_speed * dt)); e.timer -= dt; if (e.timer <= 0) e.mode = 'RECOVER'; } },
  phase(S) { return PH[S.e.mode]; },
  draw(S, R) {
    const e = S.e, p = prm('marlin');
    if (e.mode === 'WINDUP') { // 1論理ピクセルごとにshaderの式で光を足す
      const from = add(e.pos, mul(fromA(e.facing), e.r)), to = add(e.pos, mul(fromA(e.facing), p.dash_speed * p.dash_time)), A = toL(from), B = toL(to), L = dist(A, B), u = V((B.x - A.x) / L, (B.y - A.y) / L), n = orth(u), pk = FX.packets(e.id || 1, (S.t % 4) / 4), pf = R.front;
      for (let a = 0; a <= L; a += 1) { const env = smooth(0, 11, a) * smooth(0, 36, L - a), fl = FX.flow(pk, a / L), width = (0.63 + 0.23 * fl) * Math.sqrt(env);
        for (let b = -7; b <= 7; b++) { const core = Math.exp(-((b / (width + 0.02)) ** 2)) * env, mid = Math.exp(-((b / 1.22) ** 2)) * env, glow = Math.exp(-((b / 2.25) ** 2)) * env, off = 2.2 * Math.sqrt(env), lf = Math.exp(-(((b - off) / 0.39) ** 2)) * env, rt = Math.exp(-(((b + off) / 0.39) ** 2)) * env;
          const k = (0.7 + 0.3 * e.charge) / 255, r = Math.min(255, (glow * 24 * (0.8 + 0.2 * fl) + mid * 115 * (0.88 + 0.12 * fl) + core * 173 * (0.9 + 0.1 * fl) + lf * 72 * (0.75 + 0.25 * fl) + rt * 55 * (0.78 + 0.22 * fl)) * k * 255), gg = Math.min(255, (glow * 3 + mid * 18 + core * 122 + lf * 14 + rt * 10) * k * 255), bb = Math.min(255, (glow * 5 + mid * 20 + core * 85 + lf * 18 + rt * 15) * k * 255);
          if (r + gg + bb > 2) pf.light(A.x + u.x * a + n.x * b, A.y + u.y * a + n.y * b, (255 << 24) | (bb << 16) | (gg << 8) | r, 1); } }
    }
    drawEnemy(e); drawShip(S.ship);
  },
});
