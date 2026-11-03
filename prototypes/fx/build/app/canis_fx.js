// おおいぬの炎は、承認済みの鳳凰と同じ pixel_fire_density / shape の移植描画を共用する。
// 粒の大きさ・3層・色は現行 canis_fire_*.tres、配置は pixel_fire_display.gd の cloud に従う。
function withCanisFire(P, kind, draw) {
  const before = PHXC, s = BOSSES.canis_major.fire[kind];
  phxColors(P.color === '#80c8ff' ? '#2683ee' : P.color);
  const colors = PHXC, col = key => toHex(s[key]);
  PHXC = { ...colors, flame: { outer: [col('outer_color'), col('outer_color')], inner: [col('inner_color'), col('inner_color')], core: [col('core_color'), col('core_color')] } };
  try { return draw(s); } finally { PHXC = before; }
}
function canisFire(R, samples, time, kind = 'flame', fade = 1) {
  if (!samples.length || R.P.intensity <= 0 || fade <= 0) return;
  const P = R.P;
  withCanisFire(P, kind, settings => {
    const list = [], cap = settings.capacity || 384;
    const sizes = settings.layer_sizes?.args || [1, 0.7, 0.44], lives = settings.layer_lifetimes?.args || [1, 0.62, 0.3], rates = settings.layer_rates?.args || [1, 0.85, 0.7];
    const count = Math.min(samples.length, Math.floor(cap / 3));
    for (let slot = 0; slot < count; slot++) {
      const sample = samples[Math.round(slot / Math.max(1, count - 1) * (samples.length - 1))], seed = sample.seed ?? slot;
      for (let layer = 0; layer < 3; layer++) {
        if (sample.heat != null && ((layer === 2 && sample.heat < 0.82) || (layer === 1 && sample.heat < 0.44))) continue;
        const budget = Math.max(1, Math.floor(cap / Math.max(1, count) / 3));
        const births = Math.min(budget, Math.max(1, Math.min(5, Math.ceil(settings.birth_rate / 28 * rates[layer]))));
        for (let k = 0; k < births; k++) {
          const phase = seed * 2.39996 + k * 1.7 + layer, cycle = ((time * settings.rise_speed / 108 + phase) % 1 + 1) % 1;
          const age = 0.1 + cycle * 0.35 + (sample.age ?? 0) / Math.max(0.001, sample.life ?? 1) * 0.2;
          const jitter = V(Math.sin(phase + time * 2) * settings.sway * 0.12, Math.cos(phase + time) * settings.source_size.y * 0.12);
          const point = toL(add(sample.pos, jitter)), radius = sample.radius * settings.particle_size / 27 * sizes[layer] * (sample.layerScale?.[layer] ?? 1) * Math.pow(1 - age, 0.6) * (0.7 + 0.3 * smooth(0, 0.08, age)) * WL * P.size;
          list.push({ k: PX.P.FIRE, x: point.x, y: point.y, size: radius, channel: layer, max: 1, life: 1 - age, delay: 0 });
        }
      }
    }
    const painter = R.front, oldFade = painter.fade; painter.fade *= fade;
    try { phxDrawParticles({ list, draw() {} }, painter, 'front', time, 0, settings); } finally { painter.fade = oldFade; }
  });
}
function canisBurstStart(S, burst) {
  const rng = new PX.Rng(451 + S.bursts.length), ps = new PX.Particles({ rng, sparks: ['#d4f8ff', '#37a6ff', '#1471e8', '#163976'] });
  burst.fx = { R: rng, ps }; burst.fx.blazes = new PX.Blazes(ps);
  withCanisFire(P(), 'burst', () => phxBurst(burst.fx, burst.radius * WL));
}
function canisBurstDraw(S, R, burst, layer) {
  if (!burst.fx || S.t - burst.t > 2.8) return;
  const point = toL(burst.at), painter = layer === 'back' ? R.back : R.front;
  withCanisFire(R.P, 'burst', () => {
    painter.place(point.x, point.y);
    try { withPhxRamp(() => phxDrawParticles(burst.fx.ps, painter, layer, S.t, S.t - burst.t)); } finally { painter.place(0, 0); }
  });
}
const CANIS_TINTS = new Map();
function canisHoundWarning(q, strength, direction = q.facing) {
  const im = IMG['enemy/hound']; if (!im) { drawEnemy(q); return; }
  const def = enemyDef('hound'), scale = spriteR('hound', q.r) * 2 / Math.max(im.width, im.height);
  const u = clamp(strength), brace = smooth(0.02, 0.72, u), pull = brace * 2.2;
  // 元画像の足先だけを分けて踏ん張る。全身の色や明るさは変えない。
  let feet = CANIS_TINTS.get('hound-paw-regions');
  if (!feet) { feet = [{ x: 2, y: 11, w: 5, h: 10, side: -1, front: true }, { x: 13, y: 11, w: 5, h: 10, side: 1, front: true }, { x: 1, y: 21, w: 6, h: 10, side: -1, front: false }, { x: 13, y: 21, w: 6, h: 10, side: 1, front: false }]; CANIS_TINTS.set('hound-paw-regions', feet); }
  g.save(); g.translate(q.pos.x, q.pos.y); g.rotate(def.look.angle + direction); g.scale(scale, scale);
  g.save(); g.translate(0, pull); g.scale(1 + brace * 0.025, 1 - brace * 0.045); g.translate(-im.width / 2, -im.height / 2);
  g.beginPath(); g.rect(0, 0, im.width, im.height); for (const f of feet) g.rect(f.x, f.y, f.w, f.h); g.clip('evenodd'); g.drawImage(im, 0, 0); g.restore();
  for (const f of feet) {
    const spread = f.side * brace * (f.front ? 0.7 : 1.0), back = brace * (f.front ? -0.7 : 1.2);
    g.drawImage(im, f.x, f.y, f.w, f.h, f.x - im.width / 2 + spread, f.y - im.height / 2 + back, f.w, f.h);
  }
  // 前足の爪先が引っ掛かる短い擦れ。色は足先の外だけに置く。
  if (u > 0.25) for (const side of [-1, 1]) {
    const x = side * (7 + brace * 0.7), y = -3;
    g.globalAlpha = smooth(0.25, 0.75, u) * 0.85;
    g.fillStyle = '#9a604f'; g.fillRect(Math.round(x), y, 1, 2 + Math.round(brace * 2));
    g.fillStyle = '#f0bb7f'; g.fillRect(Math.round(x), y, 1, 1);
  }
  g.restore();
}
// pixelFX 原本 fire/fire-breath の45コマを再生する。形は作り直さず、口元と現行の粒の範囲へ合わせる。
function canisJetImage(at, angle, reach, width, time, alpha = 1) {
  if (reach < 8 || alpha <= 0) return;
  const sheet = DATA.canis_breath_sheet, frame = sheet.frames[Math.floor(time * 30) % sheet.frames.length].frame, im = IMG['canis_breath'];
  g.save(); g.translate(at.x, at.y); g.rotate(angle); g.globalAlpha = alpha; g.imageSmoothingEnabled = false;
  g.scale(reach / 133, Math.max(0.45, width / 62)); g.drawImage(im, frame.x, frame.y, frame.w, frame.h, -12, -72, frame.w, frame.h); g.restore();
}
function canisJetPictures(S, R) {
  const B = S.B, P = R.P;
  if (S.tech === 'sirius_flame' && S.flames.length) {
    const mouth = B.visualMouth || canisMouth(B), u = fromA(B.facing), n = orth(u); let reach = 0, width = 0;
    for (const f of S.flames) { const rel = sub(f.pos, mouth), radius = lerp(f.r0, f.r1, f.age / f.life); reach = Math.max(reach, rel.x * u.x + rel.y * u.y + radius); width = Math.max(width, Math.abs(rel.x * n.x + rel.y * n.y) * 2 + radius); }
    canisJetImage(mouth, B.facing, reach * P.size * (P.jetLength ?? 1), width * P.size * (P.jetWidth ?? 1), S.t, Math.min(1, P.intensity));
  }
  for (const jet of S.jetVisuals) {
    const age = S.t - jet.t, tail = Math.max(0, age - jet.duration) / jet.life; if (tail >= 1) continue;
    const source = jet.owner === 'boss' ? (B.visualMouth || jet.at) : jet.at;
    const shift = jet.length * tail, at = add(source, mul(fromA(jet.a), shift)), reach = Math.min(jet.length - shift, age / jet.life * jet.length);
    canisJetImage(at, jet.a, reach * P.size * (P.jetLength ?? 1), jet.width * P.size * (P.jetWidth ?? 1), age, Math.min(1, P.intensity) * (1 - tail));
  }
}

function canisSpriteFX(name, point, time, scaleX, scaleY, angle = 0, alpha = 1) {
  const sheet = DATA[name + '_sheet'], frames = sheet.frames, meta = sheet.meta.pixelfx, frame = frames[((Math.floor(time * meta.fps) % frames.length) + frames.length) % frames.length].frame, image = IMG[name];
  g.save(); g.translate(point.x, point.y); g.rotate(angle); g.scale(scaleX, scaleY); g.globalAlpha = alpha; g.imageSmoothingEnabled = false;
  g.drawImage(image, frame.x, frame.y, frame.w, frame.h, -meta.pivot[0], -meta.pivot[1], frame.w, frame.h); g.restore();
}
function canisTrailPictures(S, R) {
  const P = R.P, lengthScale = P.trailLength ?? 1, widthScale = P.trailWidth ?? 1;
  for (let ti = 0; ti < S.trails.length; ti++) {
    const trail = S.trails[ti], age = S.t - trail.t;
    if (age >= trail.life || age < 0) continue;
    const samples = [], embers = [], length = trail.length * lengthScale, width = trail.width * 2.2 * widthScale;
    const noise = (distance, span, seed) => { const cell = Math.floor(distance / span), f = smooth(0, 1, distance / span - cell); return lerp(hash(cell * 17 + seed), hash((cell + 1) * 17 + seed), f); };
    // 粒を密に重ねて1枚の燃え面へ合成する。等間隔の炎画像は並べない。
    const step = Math.max(5, width * 0.42), flight = S.r.beam_particle_life || 0.65;
    for (let d = 0; d <= length; d += step) {
      const laid = clamp(d / Math.max(1, length)) * flight, localAge = age - laid - (S.r.trail_delay || 0);
      if (localAge <= 0) continue;
      const rough = noise(d, 110, ti * 41 + 7), small = noise(d, 37, ti * 13 + 97);
      const coolAt = trail.life * (0.25 + rough * 0.60), cooling = 1 - smooth(coolAt, Math.min(trail.life, coolAt + 0.65), localAge);
      const fuel = smooth(0, 0.18, localAge) * cooling * (1 - smooth(trail.life * 0.74, trail.life, age));
      const taper = Math.min(1, (d + width) / (width * 2), (length - d + width * 0.3) / width);
      const side = (noise(d, 83, ti * 31 + 127) - 0.5) * width * 0.6, pos = add(trail.at, rotateV(V(d, side), trail.a));
      if (cooling < 0.8 && localAge > 0.4) embers.push({ pos, radius: width * (0.35 + rough * 0.28) * taper, age: localAge, life: trail.life, heat: 0, seed: ti * 71 + d * 0.23 });
      if (fuel < 0.05) continue;
      const heat = (0.24 + small * 0.53 + rough * 0.13) * Math.pow(fuel, 0.25);
      samples.push({ pos, radius: width * (0.35 + rough * 0.85 + small * 0.30) * Math.sqrt(fuel) * taper, age: localAge, life: trail.life, heat, layerScale: [1, 0.80, 0.25], seed: ti * 53 + d * 0.17 });
    }
    // 冷えた場所は暗い青の小さな熾火へ縮め、熱い面との間に切れ目を残す。
    canisFire(R, embers, S.t, 'trail', 0.28 * (1 - smooth(trail.life * 0.8, trail.life, age)));
    canisFire(R, samples, S.t, 'trail');
  }
  for (const q of S.pack) if (q.burn && !q.dead) canisSpriteFX('canis_fireball', q.pos, S.t + q.idx * 0.13, q.r * 7 / 100, q.r * 3.2 / 18, q.facing, 0.88);
}
