// ===== G12（続き）・G11・参照 =====
// ---------- みなみのかんむり座（corona）
DEMOS.push({
  id: 'G12-corona', ids: ['G12'], cat: G12, group: 'みなみのかんむり座（corona）', title: '渦で捕まえた雑魚を投げる', duration: 4.2, color: '#ff3b3b', cam: { x: -60, y: 0 },
  refs: ['scripts/enemies/corona.gd・corona_vortex.gd（ring 100・spin 4.8・telegraph 0.3・throw_speed 620・throw_life 1.6・throw_effect_scale 1.6・機体の方を向く個体を投げる）', 'corona_vortex.gd draw（渦の弧・選択の脈動・投擲の三角の尾）', 'pixelFX painter.arc・sparks'],
  status: { '状態': '試作のみ（作り直し）', '判定': '変更なし（投擲の頭の半径＝敵半径×1.6、1投1回）', '図形': '円・輪・三角は使わない。渦は流れる粒、選ばれた個体は流れ込む光の粒と絵の明滅', '投げた弾': '絵は進む向きのまま（回さない）。体は輪郭から後ろへ炎がなびいて燃え、pixelFX bullet-tracer の作りで白→金→赤へ冷えて途切れる長い尾・火花・細い煙を引く', '捕まえる敵': '本番で投げる対象のうち今の絵がある、かみつき・分裂の子・猟犬', '簡略': '捕捉の吸い込み・抽選の重みは省略し、渦に保持済みの8体から順に投げる' },
  // 渦の個体は、本番で投げる対象のうち今の絵がある種類（かみつき・分裂の子・猟犬）
  setup(S) { S.e = mkE('corona', V(-260, -30), 0); S.ship = shipState(V(260, 60)); S.m = []; const kinds = ['biter', 'splitling', 'hound']; for (let i = 0; i < 8; i++) { const type = kinds[i % 3]; S.m.push({ a: i * TAU / 8, rad: 100 * (0.85 + 0.3 * hash(i)), type, r: enemyR(type), thrown: false }); } S.sel = null; S.next = 0.3; },
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
    else { const L = toL(e.pos), pal = FX.ramp('#b6a2db'); for (let i = 0; i < 70; i++) { const rr = p.ring * WL * (0.55 + 0.6 * hash(i)), a0 = S.t * p.spin * (0.8 + 0.4 * hash(i + 9)) + hash(i * 3) * TAU; for (let s = 0; s < 4; s++) R.back.dot(L.x + Math.cos(a0 - s * 0.08) * rr, L.y + Math.sin(a0 - s * 0.08) * rr, pal[s < 1 ? 3 : 2], 0.55 - 0.12 * s); } R.blitBack(); } // 渦は流れる粒だけ（輪は描かない）
    drawEnemy(e);
    for (const m of S.m) { if (m.thrown && S.t - m.t0 >= p.throw_life) continue; const r = m.r * p.throw_effect_scale;
      if (!R.proto) { drawEnemy({ type: m.type, pos: m.pos, facing: m.facing, r: m.r });
        if (m.thrown) { const u = norm(m.v), sd = mul(orth(u), r); D2.poly([add(m.pos, sd), sub(m.pos, mul(u, r * 4.5)), sub(m.pos, sd)], 'rgba(255,59,59,.35)'); D2.circle(m.pos, r, 'rgba(255,59,59,.15)'); D2.arc(m.pos, r, 0, TAU, ATT, 3); D2.arc(m.pos, r * 1.08, angOf(u) - 1.2, angOf(u) + 1.2, CORE, 3); }
        else if (S.sel === m) { const pulse = 0.65 + 0.35 * Math.sin(S.t * 18); D2.arc(m.pos, r, 0, TAU, `rgba(255,59,59,${pulse})`, 3); D2.line(e.pos, m.pos, 'rgba(255,59,59,.35)', 2); }
        continue; }
      const pal = FX.ramp(P.color);
      if (m.thrown) { // 投げた弾：絵は進む向きのまま（回さない）。体は燃え、pixelFX bullet-tracer の作りで白→金→赤へ冷える長い尾と火花・細い煙を引く
        const age = S.t - m.t0, u = norm(m.v), fade = 1 - smooth(p.throw_life - 0.25, p.throw_life, age), L = toL(m.pos), F = ['#2a0a0a', '#5a1414', P.color, '#ff7a2e', '#ffb347', '#ffd77a', '#fff1b0', '#ffffff'].map(hexc);
        const Lt = Math.min(age * 620, 260) * WL, fr = Math.floor(S.t * 30), heat = (d) => 1 - Math.pow(d / Math.max(Lt, 1), 0.8) + PX.tileNoise(d * 0.12 - S.t * 40, 3, 0, 0, m.a * 9) * 0.12;
        for (let d = 0; d <= Lt; d += 0.5) { const q = d / Math.max(Lt, 1), h = heat(d), w = (0.6 + 2.6 * Math.pow(1 - Math.min(1, q / 0.35), 1.4)) * (q < 0.35 ? 1 : 0.5), x0 = L.x - u.x * d, y0 = L.y - u.y * d;
          if (q > 0.55 && hash(Math.floor(d / 3) * 7.1 + fr) < (q - 0.55) * 1.6) continue; // 冷えた端は途切れる
          for (let w2 = -w; w2 <= w; w2 += 0.5) { const v = Math.abs(w2) / Math.max(w, 0.01), c = v < 0.38 ? (h > 0.8 ? F[7] : h > 0.6 ? F[6] : h > 0.42 ? F[4] : h > 0.25 ? F[3] : F[2]) : (h > 0.6 ? F[5] : h > 0.35 ? F[3] : F[2]); R.front.dot(x0 - u.y * w2, y0 + u.x * w2, c, fade * (q < 0.85 ? 1 : (1 - q) / 0.15)); } }
        R.front.glowLine(L.x, L.y, L.x - u.x * Lt * 0.45, L.y - u.y * Lt * 0.45, 6, F[4], 0.35 * fade); R.front.glowLine(L.x, L.y, L.x - u.x * Lt * 0.2, L.y - u.y * Lt * 0.2, 3, F[7], 0.3 * fade);
        PX.cycle(age, 0.4, 16, 23 + m.a * 10, (rg) => rg.range(0.1, 0.28), (ag, life, rg) => { const k = ag / life, back = rg.range(4, Lt * 0.5), side = rg.range(-1, 1) * 30 * ag, x = L.x - u.x * (back + 40 * ag * WL) - u.y * side, y = L.y - u.y * (back + 40 * ag * WL) + u.x * side; R.front.line(x + u.x * 2, y + u.y * 2, x, y, (w) => w > 0.5 ? F[7] : F[4], (1 - k) * fade); }); // 尾からこぼれる火花
        for (let d = Lt * 0.4; d < Lt; d += 1) { const x = L.x - u.x * d + Math.sin(d * 0.2 + S.t * 3) * 1.2 * (-u.y), y = L.y - u.y * d + Math.sin(d * 0.2 + S.t * 3) * 1.2 * u.x; R.back.dot(x, y, hexc('#3a2a2e'), 0.35 * fade * (1 - d / Lt)); } // 細い煙
        drawEnemy({ type: m.type, pos: m.pos, facing: m.facing, r: m.r }, { alpha: fade });
        const E = spriteEdges('enemy/' + m.type); if (E) { const d = enemyDef(m.type), ang = d.look.fixed_angle ? d.look.angle : d.look.angle + m.facing, sc = 2 * spriteR(m.type, m.r) / Math.max(E.w, E.h), ca = Math.cos(ang), sa = Math.sin(ang); // 体が燃える：輪郭から後ろへ炎がなびく
          for (let i = 0; i < 26; i++) { const q = new PX.Rng(i * 17 + fr * 3 + 1), e0 = q.pick(E.pts), W0 = toL(V(m.pos.x + (e0[0] * ca - e0[1] * sa) * sc, m.pos.y + (e0[0] * sa + e0[1] * ca) * sc)), lf = q.range(2, 6), k2 = q.next();
            R.front.line(W0.x, W0.y, W0.x - u.x * lf + q.range(-1, 1), W0.y - u.y * lf + q.range(-1, 1), (w) => w < 0.3 ? F[7] : w < 0.6 ? F[5] : F[3], fade * (0.6 + 0.4 * k2)); } }
        R.front.glow(L.x, L.y, m.r * WL * 2, F[4], 0.5 * fade * P.intensity);
      } else if (S.sel === m) { // 選ばれた個体：本体から光の粒が流れ込み、絵そのものが明滅する
        const k = e.charge, A = toL(e.pos), B = toL(m.pos);
        for (let i = 0; i < 14; i++) { const f = ((hash(i * 3.1) + S.t * 2.6) % 1), w = (hash(i * 7.7) - 0.5) * 10 * Math.sin(Math.PI * f), x = lerp(A.x, B.x, f) - (B.y - A.y) / (dist(A, B) || 1) * w, y = lerp(A.y, B.y, f) + (B.x - A.x) / (dist(A, B) || 1) * w; R.front.dot(x, y, f > 0.7 ? pal[4] : pal[3], k * (0.4 + 0.6 * f)); }
        R.front.glow(B.x, B.y, r * WL * 1.4, pal[2], 0.4 * k * P.intensity);
        drawEnemy({ type: m.type, pos: m.pos, facing: m.facing, r: m.r }, { white: k * (0.35 + 0.35 * Math.sin(S.t * 30)) });
      } else drawEnemy({ type: m.type, pos: m.pos, facing: m.facing, r: m.r });
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
// 噛みつく敵（ステージ1の biter）の攻撃エフェクト：口先から長短と向きの違う6本の火花が伸びて消える（shaders/biter_sparks.gdshader と render/enemies/biter.gd の時間）。
// 猟犬・守る雑魚はこれだけを使い、口（顎）は動かさない
const BITE_SPARK = { angles: [-0.05, -0.42, -0.92, 0.37, 0.78, 1.12], lengths: [25, 17, 12, 14, 10, 8], powers: [1, 0.76, 0.68, 0.55, 0.6, 0.53], widths: [1.9, 1.5, 1.2, 1.4, 1.1, 0.9], snap: 0.034, time: 0.11 };
function biteSparks(p, type, b, t) {
  const a = t - BITE_SPARK.snap; if (a < 0 || a >= BITE_SPARK.time) return; const ph = a / BITE_SPARK.time, prm2 = prm(type), r = enemyR(type), sr = spriteR(type, r), sc = sr / 17, u = fromA(b.a);
  const mouth = add(sub(b.pos, mul(u, r + prm2.bite_reach * 0.5)), mul(u, sr * 16 / 17 + 6 * sc)), O = toL(mouth), unit = 0.5 * sc * WL, st = smooth(0, 0.22, ph);
  const orange = PX.mix(hexc('#ff9e29'), hexc('#ff4a09'), ph), yellow = hexc('#ffe070'), white = hexc('#fffbe8');
  BITE_SPARK.angles.forEach((ag, j) => { const an = b.a + ag, ax = Math.cos(an), ay = Math.sin(an), tip = BITE_SPARK.lengths[j] * (0.18 + 0.82 * st), tail = BITE_SPARK.lengths[j] * Math.pow(ph, 1.4) * 0.86, pw = BITE_SPARK.powers[j] * Math.pow(1 - ph, 0.55);
    for (let d = tail; d < tip; d += 0.5) { const w = BITE_SPARK.widths[j] * Math.max(0.08, 1 - d / Math.max(tip, 0.01)), x = O.x + ax * d * unit, y = O.y + ay * d * unit;
      for (let q = -w * 1.2; q <= w * 1.2; q += 0.5) { const aq = Math.abs(q), c = aq < w * 0.4 && ph < 0.6 ? white : aq < w * 1.0 ? yellow : orange; p.dot(x - ay * q * unit, y + ax * q * unit, c, Math.min(1, pw * (aq < w ? 1 : 0.5))); }
      if ((Math.round(d) & 3) === 0) p.light(x, y, orange, 0.3 * pw); } });
}
function biteGlow(R, e) { if (e.charge <= 0) return; const L = toL(add(e.pos, mul(fromA(e.facing), e.r))); R.front.glow(L.x, L.y, 3 + 4 * e.charge, hexc('#ffb347'), 0.5 * e.charge); } // 試作の予兆：口元がほのかに光るだけ（輪は描かない）
function biteMarks(R, e) { // 予備動作：現行は共通の口元の円（enemy_visual.gd draw_marks）
  if (e.charge <= 0) return; const mz = add(e.pos, mul(fromA(e.facing), e.r));
  if (!R.proto) D2.circle(mz, px(3) + e.r * 0.45 * e.charge, `rgba(255,230,153,${0.35 + 0.55 * e.charge})`);
  else { const P = R.P, L = toL(mz), pal = FX.ramp(P.color), k = e.charge; for (const s of [-1, 1]) { const a = e.facing + s * lerp(1.2, 0.5, k); R.front.line(L.x + Math.cos(a) * 3, L.y + Math.sin(a) * 3, L.x + Math.cos(a) * (3 + 3 * k * P.size), L.y + Math.sin(a) * (3 + 3 * k * P.size), pal[4], k); } R.front.glow(L.x, L.y, 4 + 4 * k, pal[2], 0.4 * k * P.intensity); }
}
DEMOS.push({
  id: 'G12-hound', ids: ['G12'], cat: G12, group: '猟犬（hound）', title: '群れの噛みつき', duration: 4.0, color: '#ffe8c0', cam: { x: 0, y: 0 },
  refs: ['scripts/enemies/hound.gd（群れの追跡）→ biter.gd の共通の噛みつき（bite_telegraph 0.3・bite_reach 22・半径26・bite_rest 0.8）', 'render/enemies/enemy_visual.gd draw_marks・render/attacks/zone_bite.gd（現行）', 'pixelFX melee/sword-slash.js の三日月'],
  status: { '状態': '試作：攻撃はステージ1の噛みつく敵（biter）の火花だけ（biter_sparks.gdshader）。口は動かさない。予兆は口元がほのかに光る', '判定': '変更なし（判定の円＝口の前 r+11、半径26、0.25秒）', '簡略': '群れの整列（alignment/cohesion）は省略し、各個体が直接追跡' },
  setup(S) { S.ship = shipState(V(160, 30)); S.bites = []; S.hs = []; for (let k = 0; k < 5; k++) S.hs.push(mkE('hound', V(-200 - 38 * ((k + 1) >> 1), 30 + (k % 2 ? 19 : -19) * (k ? 1 : 0)), 0)); },
  step(S, dt) { for (const e of S.hs) biteStep(S, e, dt, prm('hound'), enemyDef('hound')); },
  phase(S) { return S.hs.some(e => e.mode === 'WINDUP') ? PH.WINDUP : S.bites.length ? PH.DASH + '／' + PH.RECOVER : PH.MOVE; },
  draw(S, R) { for (const e of S.hs) drawEnemy(e); drawShip(S.ship); if (!R.proto) { drawBites(S, R, 'hound'); for (const e of S.hs) biteMarks(R, e); } else { for (const b of S.bites) biteSparks(R.front, 'hound', b, S.t - b.t0); for (const e of S.hs) biteGlow(R, e); } }, // 試作：噛みつく敵の火花だけ（口は動かさない）
});
DEMOS.push({
  id: 'G12-defender', ids: ['G12'], cat: G12, group: '守る雑魚（defender）', title: '列で守る→守る相手がいないと噛みつく', duration: 5.2, color: '#ffe8c0', cam: { x: -300, y: 0 },
  refs: ['scripts/enemies/defender.gd（guard_radius 600 内の強敵と機体を結ぶ線上へ guard_spacing 42 で整列、守る相手がいないと biter.gd の噛みつき）'],
  status: { '状態': '試作：噛みつきはステージ1の噛みつく敵（biter）の火花だけ（biter_sparks.gdshader）。口は動かさない', '判定': '変更なし', '演出': 'デモでは t=1.6s で守る相手（ぼうえんきょう座）を外し、噛みつきへ移る現行の挙動を見せる' },
  setup(S) { S.ship = shipState(V(-120, 40)); S.bites = []; S.tel = mkE('telescope', V(-620, -20), 0); S.ds = []; for (let k = 0; k < 3; k++) S.ds.push(mkE('defender', V(-500, -100 + k * 60), 0)); },
  step(S, dt) {
    const p = prm('defender'), def = enemyDef('defender');
    if (S.t < 1.6) { const fw = norm(sub(S.ship.pos, S.tel.pos)), sd = orth(fw); const off = Math.min(S.tel.r + S.ds[0].r + p.guard_distance, dist(S.ship.pos, S.tel.pos) * 0.5); S.ds.forEach((e, k) => { const goal = add(add(S.tel.pos, mul(fw, off)), mul(sd, (k - 1) * Math.max(p.guard_spacing, e.r * 2))); e.pos = lerpV(e.pos, goal, 1 - Math.exp(-4 * dt)); turnToward(e, angOf(sub(S.ship.pos, e.pos)), def.turn, dt); }); S.tel.facing = angOf(sub(S.ship.pos, S.tel.pos)); }
    else for (const e of S.ds) biteStep(S, e, dt, p, def);
  },
  phase(S) { return S.t < 1.6 ? '整列（守る）' : S.ds.some(e => e.mode === 'WINDUP') ? PH.WINDUP : S.bites.length ? PH.DASH + '／' + PH.RECOVER : PH.MOVE; },
  draw(S, R) { if (S.t < 1.6) drawEnemy(S.tel, { alpha: S.t > 1.3 ? (1.6 - S.t) / 0.3 : 1 }); for (const e of S.ds) drawEnemy(e); drawShip(S.ship); if (!R.proto) { drawBites(S, R, 'defender'); for (const e of S.ds) biteMarks(R, e); } else { for (const b of S.bites) biteSparks(R.front, 'defender', b, S.t - b.t0); for (const e of S.ds) biteGlow(R, e); } }, // 試作：噛みつく敵の火花だけ（口は動かさない）
});

// ---------- ケフェウス座（cepheus・兵 cepheus_soldier）
DEMOS.push({
  id: 'G12-cepheus', ids: ['G12'], cat: G12, group: 'ケフェウス座（cepheus・兵）', title: '召喚の予告→号令の一斉射撃', duration: 4.4, color: '#c9a6ff', cam: { x: -140, y: 0 },
  params: [{ k: 'gold', label: '召喚の金色', type: 'color', def: '#ffd98a' }],
  refs: ['scripts/enemies/cepheus.gd（summon_time 0.9・隊列3体 row_near 120/spacing 120・fire_interval 0.8・VOLLEY_WARNING 0.4）', 'scripts/enemies/soldier.gd（号令で bolt）', 'render/enemies/cepheus.gd（召喚の紋章輪）・render/enemies/soldier.gd（予告線90＋弧）・render/attacks/bolt.gd（紫の光弾）'],
  status: { '状態': '試作のみ', '判定': '変更なし（光弾の速さ640・向きは隊列の向き）', '召喚': '紋章の輪は描かない。本体から金色の粒が流れ、出る場所で散った粒が集まって兵の絵が白く光りながら形になる' },
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
        else if (k > 0.25) drawEnemy(mkE('cepheus_soldier', at, e.facing), { alpha: smooth(0.25, 1, k) * 0.8, white: 1 - 0.6 * smooth(0.6, 1, k) }); // 兵の絵が白く光りながら形になる（光の流れは下でまとめて描く）
      }
      if (!R.proto) { D2.arc(e.pos, e.r * (1.15 + 0.3 * k), 0, TAU, `rgba(255,217,102,${0.35 + 0.5 * k})`, px(3)); D2.circle(sub(e.pos, mul(u, e.r * 0.55)), e.r * (0.15 + 0.2 * k), `rgba(255,235,153,${0.5 + 0.4 * k})`); }
      else FXW.gather(R.front, sub(e.pos, mul(u, e.r * 0.55)), e.r * 1.4, k * P.intensity, P.gold, S.t, 12, 3);
    }
    if (R.proto) { // 召喚の光：本体から兵の場所へ流れる粒は召喚の間だけ出し、出し終えた粒は流れきって兵の場所に集まって消える（急に止めない）
      const sum = p.summon_time, T = 0.45, pal = FX.ramp(P.gold), A = toL(e.pos), sz = enemyR('cepheus_soldier') * WL;
      for (let sl = 0; sl < 3; sl++) { const at = add(add(e.anchor, mul(u, p.row_near)), mul(n, (sl - 1) * p.spacing)), L = toL(at), dx = L.x - A.x, dy = L.y - A.y, dl = Math.hypot(dx, dy) || 1;
        for (let i = 0; i < 40; i++) { const born = (i / 40) * sum * 0.92, f = (S.t - born) / T; if (f < 0 || f > 1) continue; const ee = f * f * (3 - 2 * f), w = (hash(i * 5.1 + sl) - 0.5) * 14 * Math.sin(Math.PI * ee), x = A.x + dx * ee - dy / dl * w, y = A.y + dy * ee + dx / dl * w; R.back.dot(x, y, f > 0.75 ? pal[4] : pal[3], 0.4 + 0.6 * f); }
        const gl = S.t < sum ? clamp(S.t / sum) : 1 - smooth(sum, sum + 0.35, S.t); if (gl > 0) R.back.glow(L.x, L.y, sz * 1.6, pal[2], 0.35 * gl * P.intensity); }
    }
    if (R.proto) R.blitBack();
    drawEnemy(e); for (const s of S.sol) drawEnemy(s); drawShip(S.ship);
    for (const s of S.sol) if (s.charge > 0) { const dir = fromA(s.facing), st = add(s.pos, mul(dir, s.r));
      if (!R.proto) { const glow = `rgba(255,224,122,${0.25 + 0.55 * s.charge})`; D2.line(st, add(st, mul(dir, 90)), glow, px(2)); D2.arc(s.pos, s.r * 1.4, 0, TAU * s.charge, glow, px(2)); }
      else FXW.gather(R.front, st, s.r * 1.3, s.charge * P.intensity, P.color, S.t, 6, s.buds + 3); } // 撃つ前は溜めるだけ（線は出さない）
    for (const b of S.bolts) { const u2 = fromA(b.a);
      if (!R.proto) { D2.line(sub(b.pos, mul(u2, 34)), add(b.pos, mul(u2, 6)), 'rgba(191,153,255,.35)', 14); D2.line(sub(b.pos, mul(u2, 30)), add(b.pos, mul(u2, 4)), 'rgb(217,191,255)', 6); D2.line(sub(b.pos, mul(u2, 24)), add(b.pos, mul(u2, 2)), 'rgba(255,255,255,.95)', 2.5); }
      else { const L = toL(b.pos), pal = FX.ramp(P.color), T = toL(sub(b.pos, mul(u2, 46))); R.front.beam(T.x, T.y, L.x, L.y, 2.6 * P.size, (uu, v) => uu > 0.8 ? pal[4] : v < 0.4 ? pal[3] : pal[2], (uu) => Math.min(1, 0.25 + uu)); R.front.px(L.x, L.y, pal[4]); R.front.px(L.x - Math.cos(b.a), L.y - Math.sin(b.a), pal[4]); R.front.glow(L.x, L.y, 4 * P.size, pal[4], 0.6 * P.intensity); R.front.glowLine(T.x, T.y, L.x, L.y, 4, pal[2], 0.4 * P.intensity); if (S.t - b.t0 < 0.08) FXW.flare(R.front, sub(b.pos, mul(u2, 640 * (S.t - b.t0))), 8, P.color, S.t, 1 - (S.t - b.t0) / 0.08, 4); }
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
// 試作の方針（ユーザー指示）：main の「影→着地→爆発的な炎」の方向を保ち、円や輪郭線などの図形は描かない。
// 影は鳳凰の実際の絵の形を、高さに応じてぼかして落とす。炎は pixelFX の粒子（Particles／Blazes：炎の塊が煙へ冷える）で作る。
const PHX_FIRE = ['#ffffff', '#fff1c4', '#ffd77a', '#ffa24a', '#ff6a3a', '#e8333f', '#b01a45', '#6e1238', '#36091f'];
const PHX_SPARK = ['#fff1c4', '#ffb35a', '#e8333f', '#7a1430'];
const PHX_BASE = '#ff6a3a', PHX_SMOKE = '#3a2230', PHX_POOL = ['#ff8246', '#d24632', '#781428'];
function hsl(hex) { const c = parseCol(hex), mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b), l = (mx + mn) / 2, d = mx - mn; if (!d) return { h: 0, s: 0, l };
  const s = d / (1 - Math.abs(2 * l - 1)), h = mx === c.r ? ((c.g - c.b) / d + 6) % 6 : mx === c.g ? (c.b - c.r) / d + 2 : (c.r - c.g) / d + 4; return { h: h * 60, s, l }; }
function fromHsl({ h, s, l }) { const C = (1 - Math.abs(2 * l - 1)) * s, X = C * (1 - Math.abs(((h / 60) % 2) - 1)), m = l - C / 2, k = Math.floor(((h % 360) + 360) % 360 / 60);
  const [r, g, b] = [[C, X, 0], [X, C, 0], [0, C, X], [0, X, C], [X, 0, C], [C, 0, X]][k]; return toHex({ r: r + m, g: g + m, b: b + m }); }
// 主色のつまみ：基準（#ff6a3a）からの色相と鮮やかさの差を、鳳凰の全部の色へ同じだけ当てる
let PHXC = null;
function phxColors(color) {
  if (PHXC && PHXC.key === color) return PHXC; const a = hsl(PHX_BASE), b = hsl(color || PHX_BASE), dh = b.h - a.h, ks = a.s ? b.s / a.s : 1;
  const t = (hex) => { const c = hsl(hex); return fromHsl({ h: (c.h + dh + 360) % 360, s: clamp(c.s * ks), l: c.l }); }, tt = (list) => list.map(t);
  return (PHXC = { key: color, t, fire: tt(PHX_FIRE), spark: tt(PHX_SPARK), smoke: t(PHX_SMOKE), pool: tt(PHX_POOL), flame: { outer: tt(PHX_FLAME_COLS.outer), inner: tt(PHX_FLAME_COLS.inner), core: tt(PHX_FLAME_COLS.core) } });
}
let PHX_SHADOW = null;
function phxShadowImg() { // 鳳凰の現行スプライトの不透明部分だけを黒くした影の元
  if (PHX_SHADOW || !IMG['enemy/phoenix']) return PHX_SHADOW; const im = IMG['enemy/phoenix'], c = document.createElement('canvas'); c.width = im.width + 40; c.height = im.height + 40; const x = c.getContext('2d');
  x.drawImage(im, 20, 20); x.globalCompositeOperation = 'source-in'; x.fillStyle = '#1a0608'; x.fillRect(0, 0, c.width, c.height); PHX_SHADOW = c; return c;
}
function drawPhxShadow(at, angle, scale, blurPx, alpha) {
  const c = phxShadowImg(); if (!c) return; const im = IMG['enemy/phoenix'], e = DATA.enemies.phoenix, r = enemyR('phoenix'), half = spriteR('phoenix', r) * scale, s = (2 * half) / Math.max(im.width, im.height);
  g.save(); g.translate(at.x, at.y); g.rotate(angle); g.filter = `blur(${blurPx.toFixed(1)}px)`; g.globalAlpha = alpha; g.globalCompositeOperation = 'source-over';
  g.drawImage(c, -c.width * s / 2, -c.height * s / 2, c.width * s, c.height * s); g.restore();
}
// 炎と煙は粒を1つずつ描かない：現行のピクセル炎（scripts/render/fx/pixel_fire.gd＋pixel_fire_density/shape.gdshader）と同じ作りで、
// 粒を外炎・内炎・芯の3つの密度場へ足し込み（芯ほど小さく短命）、場を時間でゆがめて読み、しきい値で切って3色の面で塗る。粒どうしがつながって1つの炎になる。
// 粒の動きは pixelFX の爆発のまま。色はプレイヤーのギアアップの炎（橙〜金）と分けて、鳳凰の紅〜深紅にする。
const PHX_FIELD = { pad: 6, threshold: 0.32, deformation: 1.4, fps: 30 };
const PHX_FLAME_COLS = { outer: ['#e8333f', '#7a1430'], inner: ['#ff7a3a', '#c42340'], core: ['#fff1c4', '#ff9a3a'] };
function phxSplat(field, W, H, ox, oy, x, y, r, ch, w = 1) { // pixel_fire_density.gdshader：exp(-d²×3.2)、縁で0へ
  if (r < 0.3) return; const x0 = Math.max(0, Math.floor(x - r - ox)), x1 = Math.min(W - 1, Math.ceil(x + r - ox)), y0 = Math.max(0, Math.floor(y - r - oy)), y1 = Math.min(H - 1, Math.ceil(y + r - oy));
  for (let j = y0; j <= y1; j++) for (let i = x0; i <= x1; i++) { const dx = (i + ox + 0.5 - x) / r, dy = (j + oy + 0.5 - y) / r, d2 = dx * dx + dy * dy; if (d2 >= 1) continue; const d = Math.sqrt(d2); field[(j * W + i) * 3 + ch] += w * Math.exp(-d2 * 3.2) * (1 - smooth(0.72, 1, d)); }
}
function phxDrawParticles(ps, p, layer, time, burstAge) {
  const own = [], rest = [];
  for (const q of ps.list) (q.k === PX.P.FIRE || q.k === PX.P.SMOKE ? own : rest).push(q);
  const keep = ps.list; ps.list = rest; try { ps.draw(p, layer); } finally { ps.list = keep; }
  const want = layer === 'back' ? PX.P.SMOKE : PX.P.FIRE, list = own.filter(q => q.delay <= 0 && q.k === want); if (!list.length) return;
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const q of list) { const r = q.size * 2; x0 = Math.min(x0, q.x - r); y0 = Math.min(y0, q.y - r); x1 = Math.max(x1, q.x + r); y1 = Math.max(y1, q.y + r); }
  const pad = PHX_FIELD.pad, ox = Math.floor(x0) - pad, oy = Math.floor(y0) - pad, W = Math.ceil(x1) - ox + pad, H = Math.ceil(y1) - oy + pad, field = new Float32Array(W * H * 3);
  for (const q of list) { const age = 1 - q.life / q.max;
    if (want === PX.P.FIRE) { const base = q.size * 1.25 * Math.pow(1 - age, 0.6) * (0.7 + 0.3 * smooth(0, 0.08, age)); // pixel_fire.gd の大きさの変化
      phxSplat(field, W, H, ox, oy, q.x, q.y, base, 0); if (age < 0.62) phxSplat(field, W, H, ox, oy, q.x, q.y - base * 0.1, base * 0.7, 1); if (age < 0.3) phxSplat(field, W, H, ox, oy, q.x, q.y - base * 0.15, base * 0.44, 2); }
    else { const big = q.flag & PX.PF.BIG, r = q.size * (0.65 + Math.min(1, age * 2.5) * 0.45 + age * (big ? 0.5 : 0.4)) * 1.2; phxSplat(field, W, H, ox, oy, q.x, q.y, r, 0, 1); if (age < 0.5) phxSplat(field, W, H, ox, oy, q.x, q.y, r * 0.6, 1, 1); phxSplat(field, W, H, ox, oy, q.x, q.y, r, 2, age); } }
  const clock = Math.floor(time * PHX_FIELD.fps) / PHX_FIELD.fps, def = PHX_FIELD.deformation, th = PHX_FIELD.threshold;
  const read = (i, j, ch) => { i = Math.max(0, Math.min(W - 1, Math.round(i))); j = Math.max(0, Math.min(H - 1, Math.round(j))); return field[(j * W + i) * 3 + ch]; };
  const cool = clamp(burstAge / 1.3);
  const FC = PHXC.flame, cOuter = PX.mix(hexc(FC.outer[0]), hexc(FC.outer[1]), cool), cInner = PX.mix(hexc(FC.inner[0]), hexc(FC.inner[1]), cool), cCore = PX.mix(hexc(FC.core[0]), hexc(FC.core[1]), cool);
  const SR = PX.SMOKE_RAMP;
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    const wx = (i + ox) * LP, wy = (j + oy) * LP; // 画面px でゆがみを計る（pixel_fire_shape.gdshader と同じ式）
    const u = (Math.sin(wy * 0.075 - clock * 4.4) + Math.sin(wx * 0.11 + wy * 0.033 + clock * 2.1)) * def, v = Math.cos(wx * 0.08 + clock * 3.0) * 0.55 * def;
    const r0 = read(i + u, j + v, 0); if (r0 < th) continue;
    const x = i + ox, y = j + oy;
    if (want === PX.P.FIRE) { const g1 = read(i + u, j + v, 1) >= th, b1 = g1 && read(i + u, j + v, 2) >= th; const c = b1 ? cCore : g1 ? cInner : cOuter; p.px(x, y, c); if ((x & 3) === 0 && (y & 3) === 0) p.glow(x, y, 5, c, b1 ? 0.3 : g1 ? 0.18 : 0.08); } // 光はやわらかく間引いて置く（縞にしない）
    else { const young = read(i + u, j + v, 1) >= th, oldness = read(i + u, j + v, 2) / Math.max(1e-4, r0), gone = smooth(0.45, 0.95, oldness); // 煙のディゾルブ
      if (hash(x * 12.9898 + y * 78.233) < gone) continue; p.blend(x, y, young ? SR[1] : SR[Math.min(SR.length - 1, 3)], (young ? 0.55 : 0.4) * (1 - gone * 0.35)); }
  }
}
function withPhxRamp(fn) { const F = PX.FIRE_RAMP, saved = F.slice(); F.splice(0, F.length, ...PHXC.fire.map(hexc)); try { fn(); } finally { F.splice(0, F.length, ...saved); } }
// 落ちてくる火の粉（決定的）：着地点のまわりへ、中心ほど濃い分布で上空から降り、地面で弾けて消える
function phxEmbers(R, center, rad, t0, t, k, density, P) {
  const L = toL(center), r = rad * WL, pal = PHXC.spark.map(hexc);
  for (let i = 0; i < density; i++) {
    const born = t0 + hash(i * 1.37) * 1.3, age = t - born, fall = 0.45 + hash(i * 3.1) * 0.25; if (age < 0) continue;
    const ang = hash(i * 7.7) * TAU, dd = r * Math.min(1, Math.abs((hash(i * 2.3) + hash(i * 5.9) + hash(i * 9.1) - 1.5) / 1.5)) * 1.05, tx = L.x + Math.cos(ang) * dd, ty = L.y + Math.sin(ang) * dd * 0.9;
    if (age < fall) { const q = age / fall, y = ty - (1 - q * q) * 38, len = 2 + 3 * q; R.front.line(tx, y - len, tx, y, (u) => u > 0.6 ? pal[0] : pal[1]); R.front.glow(tx, y, 3, pal[1], 0.35 * P.intensity); }
    else if (age < fall + 0.35) { const q = (age - fall) / 0.35; R.back.px(tx, ty, q < 0.3 ? pal[0] : q < 0.6 ? pal[1] : pal[2]); if (q < 0.5) { R.back.px(tx - 1, ty, pal[2]); R.back.px(tx + 1, ty, pal[2]); } R.back.glow(tx, ty, 5, pal[1], 0.4 * (1 - q) * P.intensity); }
  }
}
// 着地のあとに残る焦げ跡：円で決めず、着地から炎の粒が実際に通った所を写し取った形（mask）にする。
// 熱い所ほど長く赤く光り、冷えるとすすになり、最後はマスごとのノイズで虫食い状に消える（輪郭を丸くしない）
function phxStampScorch(S) {
  const sc = S.scorch; if (!sc) return;
  for (const q of S.fx.ps.list) { if (q.k !== PX.P.FIRE || q.delay > 0) continue; const r = q.size * 0.9, cx = q.x + sc.R, cy = q.y + sc.R;
    for (let y = Math.max(0, Math.floor(cy - r)); y <= Math.min(sc.N - 1, Math.ceil(cy + r)); y++) for (let x = Math.max(0, Math.floor(cx - r)); x <= Math.min(sc.N - 1, Math.ceil(cx + r)); x++) {
      const d2 = ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) / (r * r); if (d2 < 1) sc.m[y * sc.N + x] += (1 - d2) * 0.08; } }
}
function phxScorch(p, sc, t, fade) {
  if (!sc || fade <= 0) return; const heat = PHXC.fire.slice().reverse().map(hexc), SOOT = hexc('#140a0e'), SOOT2 = hexc('#22131a');
  for (let y = 0; y < sc.N; y++) for (let x = 0; x < sc.N; x++) {
    const m = sc.m[y * sc.N + x]; if (m < 0.35) continue; const lx = x - sc.R, ly = y - sc.R, k = hash(lx * 31.7 + ly * 7.3);
    if (k > fade * Math.min(1, (m - 0.35) * 2.5)) continue; // 薄い所・時間がたった所から消える
    const T = Math.pow(clamp(1 - t / 1.4), 1.3) * Math.min(1.2, m * 0.5) - k * 0.4;
    if (T > 0.08) { p.px(lx, ly, heat[Math.min(heat.length - 1, Math.floor((1 - Math.min(1, T)) * (heat.length - 1)))]); if ((lx & 3) === 0 && (ly & 3) === 0) p.glow(lx, ly, 5, heat[5], 0.2 * T * fade); }
    else p.blend(lx, ly, k < 0.5 ? SOOT : SOOT2, 0.7);
  }
}
function phxBurst(fx, rad) { // 着地の爆発：pixelFX Particles に炎・煙・火の粉・燃え残りを入れる（座標は着地点からの論理ピクセル）
  const ps = fx.ps, R = fx.R;
  for (let i = 0; i < 6; i++) ps.spawn(PX.P.FIRE, R.range(-3, 3), R.range(-3, 3), R.range(-20, 20), R.range(-50, -10), R.range(0.22, 0.34), 0, R.range(rad * 0.38, rad * 0.5));
  for (let i = 0; i < 46; i++) { const a = R.range(0, TAU), d = R.range(0, rad * 0.3), sp = R.range(0.35, 1) * rad * 5; ps.spawn(PX.P.FIRE, Math.cos(a) * d, Math.sin(a) * d * 0.9, Math.cos(a) * sp, Math.sin(a) * sp * 0.85 - 30, R.range(0.55, 1.1), 0, R.range(rad * 0.16, rad * 0.32), R.range(0, 0.06), R.chance(0.5) ? PX.PF.SMOKES | PX.PF.BIG : 0); }
  for (let i = 0; i < 8; i++) ps.spawn(PX.P.FIRE, R.range(-rad * 0.3, rad * 0.3), R.range(-rad * 0.2, rad * 0.2), R.range(-10, 10), R.range(-150, -90), R.range(0.8, 1.2), 0, R.range(rad * 0.2, rad * 0.3), R.range(0.05, 0.15), PX.PF.SMOKES | PX.PF.BIG);
  for (let i = 0; i < 90; i++) { const a = R.range(0, TAU), sp = R.range(120, 330); ps.spawn(PX.P.SPARK, 0, 0, Math.cos(a) * sp, Math.sin(a) * sp * 0.85 - 60, R.range(0.2, 0.6)); }
  for (let i = 0; i < 40; i++) { const a = R.range(0, TAU), sp = R.range(30, 140); ps.spawn(PX.P.EMBER, Math.cos(a) * rad * 0.4, Math.sin(a) * rad * 0.36, Math.cos(a) * sp, Math.sin(a) * sp - 60, R.range(1.0, 2.2), PHXC.spark[1]); }
  for (let i = 0; i < 10; i++) { const a = R.range(0, TAU), d = R.range(0.25, 0.85) * rad; fx.blazes.add(Math.cos(a) * d, Math.sin(a) * d * 0.9, R.range(0.9, 1.8), R.range(0.6, 1.0)); }
  for (let i = 0; i < 12; i++) { const a = R.range(0, TAU), d = R.range(0.1, 0.6) * rad; ps.spawn(PX.P.SMOKE, Math.cos(a) * d, Math.sin(a) * d, Math.cos(a) * 25, Math.sin(a) * 18 - 30, R.range(1.6, 2.6), hexc(PHXC.smoke), R.range(rad * 0.22, rad * 0.36), R.range(0.15, 0.45), PX.PF.BIG); }
}
const phxRadius = (e) => Math.max(e.r * 1.1, PARAMS['G11-phoenix']?.radius ?? prm('phoenix').impact_radius); // 比較用の範囲（既定は現行の impact_radius）
DEMOS.push({
  id: 'G11-phoenix', ids: ['G11', 'G12'], cat: '鳳凰 G11', group: 'ほうおう座（phoenix）', title: '影を落として着地→爆発的な炎', duration: 6.4, color: '#ff6a3a', cam: { x: 60, y: -40 },
  params: [{ k: 'playerRef', label: 'プレイヤーの爆発を並べる(0/1)', type: 'range', min: 0, max: 1, step: 1, def: 0 }, { k: 'radius', label: '比較用：着地の範囲(半径・試作内のみ)', type: 'range', min: 150, max: 450, step: 10, def: prm('phoenix').impact_radius }],
  refs: ['scripts/enemies/phoenix.gd（retreat 0.9/700・telegraph 1.4・dive 0.4・impact 半径220/0.6s・recover 1.8）', 'render/enemies/phoenix.gd（影の大きさ r×(0.5+0.5k)・火の粉の専用shader）・render/attacks/zone_phoenix.gd（blast_bursts）', 'data/visuals/phoenix_flames.tres（flame/hot/ember/smoke の色の方向）', 'pixelFX src/core/sim.js の Particles・Blazes（炎の塊が煙へ冷える・火の粉・燃え残り）を本体ごと使用、explosions/small-explosion.js の配合と焦げ跡を上から見た形へ改変', 'assets/pixel/phoenix/*（影は現行スプライトの形から作る）'],
  status: { '状態': '試作のみ（作り直し2回目）', '判定': '変更なし（着地点＝予告開始時の自機位置、半径220、炎0.6秒）。範囲は火の粉と炎の広がりで示し、円は描かない', '比較用操作': '「着地の範囲」は広さを比べるための試作内だけの操作。予告の光だまり・火の粉・炎・焼け跡が一緒に広がる。本番の impact_radius は変えていない', '図形': '円・輪・輪郭線は使っていない（影は実際の絵の形をぼかしたもの）', '炎・爆発': '芯は main と同じ橙〜金、外側を紅〜深紅、煙は紫がかった茶。プレイヤーのエンドブラスト（橙の点が散る）とは形（膨らむ炎の塊・煙・燃え残り）と色で区別。「プレイヤーの爆発を並べる」で比較できる', '近似': '現行（main）表示の火の粉shaderと点の爆発は形・時間を簡略化して再現' },
  setup(S) { S.e = mkE('phoenix', V(-120, -220), 0); S.ship = shipState(V(200, 120)); S.e.timer = 0; const R = new PX.Rng(23); phxColors(P().color); S.fx = { R, ps: new PX.Particles({ rng: R, sparks: PHXC.spark }), trail: new PX.Rng(5) }; S.fx.blazes = new PX.Blazes(S.fx.ps); },
  step(S, dt) {
    const e = S.e, p = prm('phoenix');
    const adv = (target) => { const d = sub(target, e.pos); if (len(d) > 0.01) e.facing = angOf(d); e.pos = lerpV(e.pos, target, clamp(dt / Math.max(0.001, e.timer))); e.timer = Math.max(0, e.timer - dt); };
    if (e.mode === 'MOVE') { if (!e.anchor) { e.anchor = add(e.pos, mul(norm(sub(e.pos, S.ship.pos)), p.retreat_distance)); e.timer = p.retreat_time; } adv(e.anchor); if (e.timer <= 0 && dt > 0) { e.anchor = { ...S.ship.pos }; e.mode = 'WINDUP'; e.timer = p.telegraph; e.facing = angOf(sub(e.anchor, e.pos)); S.tele0 = S.t; } }
    else if (e.mode === 'WINDUP') { e.timer = Math.max(0, e.timer - dt); e.charge = 1 - e.timer / p.telegraph; if (e.timer <= 0) { e.mode = 'DASH'; e.timer = p.dive_time; e.charge = 0; } }
    else if (e.mode === 'DASH') { adv(e.anchor); const L = toLocal(e.pos, e.anchor), R = S.fx.trail; const back = norm(sub(e.anchor, e.pos)); for (let i = 0; i < 7; i++) { const j = R.range(0, 1); S.fx.ps.spawn(PX.P.FIRE, L.x - back.x * j * 6 + R.range(-3, 3), L.y - back.y * j * 6 + R.range(-3, 3), -back.x * R.range(20, 60) + R.range(-15, 15), -back.y * R.range(20, 60) + R.range(-25, 0), R.range(0.12, 0.3), 0, R.range(1.2, 3.4), 0, R.chance(0.25) ? PX.PF.SMOKES : 0); } if (R.chance(0.7)) S.fx.ps.spawn(PX.P.SPARK, L.x, L.y, -back.x * R.range(60, 160) + R.range(-40, 40), -back.y * R.range(60, 160) + R.range(-40, 40), R.range(0.15, 0.35));
      if (e.timer <= 0) { S.flame = { pos: { ...e.anchor }, r: phxRadius(e), t0: S.t, life: p.impact_time }; phxBurst(S.fx, S.flame.r * WL); const RR = Math.ceil(S.flame.r * WL * 1.8); S.scorch = { R: RR, N: RR * 2 + 1, m: new Float32Array((RR * 2 + 1) ** 2) }; e.mode = 'RECOVER'; e.timer = p.recover_time; } }
    else if (e.mode === 'RECOVER') e.timer = Math.max(0, e.timer - dt);
    if (dt > 0) { S.fx.ps.update(dt); S.fx.blazes.update(dt); if (S.flame && S.t - S.flame.t0 < 1.2) phxStampScorch(S); }
    S.ship.pos.x = 200 + Math.sin(S.t * 0.8) * 20;
  },
  phase(S) { const m = S.e.mode; return m === 'MOVE' ? '離脱' : m === 'WINDUP' ? PH.WINDUP + '（影と火の粉）' : m === 'DASH' ? '飛び込み' : S.flame && S.t - S.flame.t0 < S.flame.life ? PH.DASH + '（着地の炎・判定0.6s）' : PH.RECOVER + '（燃え残り）'; },
  draw(S, R) {
    const e = S.e, P = R.P, p = prm('phoenix'), FLAME = '#ff6a2a', rad = phxRadius(e);
    if (!R.proto) { // 現行（main）：render/enemies/phoenix.gd の影・輪＋火の粉、zone_phoenix.gd の点の爆発（近似）
      if (e.mode === 'WINDUP' || e.mode === 'DASH') { const c = e.anchor, k = e.mode === 'WINDUP' ? e.charge : 1; D2.circle(c, rad, rgba(FLAME, 0.025 + 0.035 * k)); D2.arc(c, rad, 0, TAU, rgba(FLAME, 0.3 + 0.5 * k), px(2)); const ss = e.r * (0.5 + 0.5 * k), pts = [[0, -1], [0.28, -0.15], [1.2, 0.4], [0.3, 0.22], [0, 0.9], [-0.3, 0.22], [-1.2, 0.4], [-0.28, -0.15]].map(([x, y]) => { const a = e.facing + Math.PI / 2, q = V(x * ss, y * ss); return add(c, V(q.x * Math.cos(a) - q.y * Math.sin(a), q.x * Math.sin(a) + q.y * Math.cos(a))); }); D2.poly(pts, `rgba(23,9,4,${0.5 + 0.35 * k})`); D2.polyline([...pts, pts[0]], rgba(FLAME, 0.3 + 0.6 * k), px(1.5)); for (let i = 0; i < 24; i++) { const a = hash(i) * TAU, d = rad * Math.sqrt(hash(i + 7)), y = ((hash(i * 3) + S.t * 0.7) % 1); D2.circle(add(c, V(Math.cos(a) * d, Math.sin(a) * d - y * 90 * k)), 3, rgba('#ffb35a', (1 - y) * k)); } }
      if (S.flame) { const t = S.t - S.flame.t0, L = toL(S.flame.pos), r = S.flame.r * WL; if (t < 0.9) { const f = 1 - smooth(0.3, 0.9, t), pal = FX.ramp('#ff9a3c'); for (let i = 0; i < 160; i++) { const a = hash(i) * TAU, d = r * Math.sqrt(hash(i * 3.3)) * clamp(t / 0.15) ** 0.5; R.front.circle(L.x + Math.cos(a) * d, L.y + Math.sin(a) * d, 1.8 * f + 0.5, pal[d / r < 0.35 ? 4 : d / r < 0.7 ? 3 : 2], f); } R.front.glow(L.x, L.y, r * 1.2, pal[3], 0.6 * f); } }
      drawEnemy(e); drawShip(S.ship); return;
    }
    const anchor = e.anchor, L = anchor ? toL(anchor) : null, r = rad * WL, C = phxColors(P.color);
    // 予告：上空の鳳凰の影。高いほど大きくぼけて薄く、降りるほど締まって濃くなる。地面がうっすら熱を帯び、火の粉が降る
    if (anchor && (e.mode === 'WINDUP' || e.mode === 'DASH')) {
      const k = e.mode === 'WINDUP' ? e.charge : 1, dive = e.mode === 'DASH' ? 1 - e.timer / p.dive_time : 0, h = (1 - k) * 0.8 + 0.2 * (1 - dive);
      const ang = DATA.enemies.phoenix.look.angle + e.facing;
      // 上空で燃える鳳凰が地面を照らす暖かい光だまり（ぼかした光。縁は持たない）→ その光を鳳凰の体が遮って影になる
      g.save(); const gr = g.createRadialGradient(anchor.x, anchor.y, 0, anchor.x, anchor.y, rad * (1.0 + 0.3 * h)); gr.addColorStop(0, rgba(C.pool[0], (0.22 + 0.45 * k) * P.intensity)); gr.addColorStop(0.5, rgba(C.pool[1], (0.10 + 0.22 * k) * P.intensity)); gr.addColorStop(1, rgba(C.pool[2], 0)); g.globalCompositeOperation = 'lighter'; g.fillStyle = gr; g.fillRect(anchor.x - rad * 1.4, anchor.y - rad * 1.4, rad * 2.8, rad * 2.8); g.restore();
      drawPhxShadow(anchor, ang, 1.35 + 0.6 * h, (2 + 18 * h) * P.size, (0.25 + 0.35 * (1 - h)) * P.intensity);   // 半影（大きく薄い）
      drawPhxShadow(anchor, ang, (0.55 + 0.45 * k) * (1 + 0.15 * h), (1 + 9 * h) * P.size, Math.min(1, (0.45 + 0.5 * (1 - h)) * P.intensity)); // 本影
      const pal = C.fire.map(hexc); // 光だまりは canvas 側だけ（影を加算光で薄めない）
      for (let i = 0; i < 70 * k; i++) { const a = hash(i * 4.1) * TAU, d = r * Math.sqrt(hash(i * 1.9)) * 0.95, tw = Math.sin(S.t * (6 + hash(i) * 8) + i); if (tw > 0.2) R.back.px(L.x + Math.cos(a) * d, L.y + Math.sin(a) * d * 0.9, tw > 0.8 ? pal[3] : pal[5]); }
      phxEmbers(R, anchor, rad, S.tele0 || S.t, S.t, k, Math.round(90 * P.intensity), P);
    }
    // 着地のあと：焦げ跡と燃え残り（背面）、煙
    if (S.flame) { const t = S.t - S.flame.t0, Lf = toL(S.flame.pos); R.back.place(Lf.x, Lf.y); phxScorch(R.back, S.scorch, t / P.timing, 1 - smooth(1.6, 3.2, t / P.timing)); R.back.place(0, 0); }
    if (S.flame || e.mode === 'DASH') { const Lf = toL(anchor); R.back.place(Lf.x, Lf.y); withPhxRamp(() => { phxDrawParticles(S.fx.ps, R.back, 'back', S.t, S.flame ? S.t - S.flame.t0 : 0); S.fx.blazes.drawBack(R.back); }); R.back.place(0, 0); }
    R.blitBack();
    drawEnemy(e); drawShip(S.ship);
    if (S.flame || e.mode === 'DASH') { const Lf = toL(anchor); R.front.place(Lf.x, Lf.y); withPhxRamp(() => phxDrawParticles(S.fx.ps, R.front, 'front', S.t, S.flame ? S.t - S.flame.t0 : 0));
      if (S.flame) { const t = S.t - S.flame.t0; if (t < 0.12) { R.front.glow(0, 0, r * 1.3, hexc(C.t('#fff1c4')), (1 - t / 0.12) * P.intensity); R.front.glow(0, 0, r * 0.6, hexc('#ffffff'), (1 - t / 0.12) * 0.8 * P.intensity); } if (t < 0.8) R.front.glow(0, 0, r * 1.1, hexc(C.t('#ff6a3a')), 0.35 * (1 - t / 0.8) * P.intensity); }
      R.front.place(0, 0); }
    if (P.playerRef && S.flame) drawPlayerBlastRef(S, R, add(S.flame.pos, V(-460, 40)), S.flame.t0);
  },
});
// ワールド座標 → 着地点を原点とした論理ピクセル
function toLocal(p, origin) { const a = toL(p), o = toL(origin); return V(a.x - o.x, a.y - o.y); }
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
