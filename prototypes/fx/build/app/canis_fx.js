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
        const budget = Math.max(1, Math.floor(cap / Math.max(1, count) / 3));
        const births = Math.min(budget, Math.max(1, Math.min(5, Math.ceil(settings.birth_rate / 28 * rates[layer]))));
        for (let k = 0; k < births; k++) {
          const phase = seed * 2.39996 + k * 1.7 + layer, cycle = ((time * settings.rise_speed / 108 + phase) % 1 + 1) % 1;
          const age = 0.1 + cycle * 0.35 + (sample.age ?? 0) / Math.max(0.001, sample.life ?? 1) * 0.2;
          const jitter = V(Math.sin(phase + time * 2) * settings.sway * 0.12, Math.cos(phase + time) * settings.source_size.y * 0.12);
          const point = toL(add(sample.pos, jitter)), radius = sample.radius * settings.particle_size / 27 * sizes[layer] * Math.pow(1 - age, 0.6) * (0.7 + 0.3 * smooth(0, 0.08, age)) * WL * P.size;
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
function canisHoundWarning(q, strength) {
  if (strength <= 0) return;
  const key = 'enemy/hound', im = IMG[key], color = '#039cff';
  if (!CANIS_TINTS.has(color)) { const canvas = document.createElement('canvas'); canvas.width = im.width; canvas.height = im.height; const ctx = canvas.getContext('2d'); ctx.drawImage(im, 0, 0); ctx.globalCompositeOperation = 'source-in'; ctx.fillStyle = color; ctx.fillRect(0, 0, im.width, im.height); CANIS_TINTS.set(color, canvas); }
  const tint = CANIS_TINTS.get(color), def = enemyDef('hound'), angle = def.look.angle + q.facing, scale = spriteR('hound', q.r) * 2 / Math.max(im.width, im.height);
  g.save(); g.translate(q.pos.x, q.pos.y); g.rotate(angle); g.globalAlpha = strength * 0.82; g.drawImage(tint, -im.width * scale / 2, -im.height * scale / 2, im.width * scale, im.height * scale); g.restore();
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
    canisJetImage(mouth, B.facing, reach * P.size, width * P.size, S.t, Math.min(1, P.intensity));
  }
  for (const jet of S.jetVisuals) {
    const age = S.t - jet.t, tail = Math.max(0, age - jet.duration) / jet.life; if (tail >= 1) continue;
    const source = jet.owner === 'boss' ? (B.visualMouth || jet.at) : jet.at;
    const shift = jet.length * tail, at = add(source, mul(fromA(jet.a), shift)), reach = Math.min(jet.length - shift, age / jet.life * jet.length);
    canisJetImage(at, jet.a, reach * P.size, jet.width * P.size, age, Math.min(1, P.intensity) * (1 - tail));
  }
}

function canisSpriteFX(name, point, time, scaleX, scaleY, angle = 0, alpha = 1) {
  const sheet = DATA[name + '_sheet'], frames = sheet.frames, meta = sheet.meta.pixelfx, frame = frames[((Math.floor(time * meta.fps) % frames.length) + frames.length) % frames.length].frame, image = IMG[name];
  g.save(); g.translate(point.x, point.y); g.rotate(angle); g.scale(scaleX, scaleY); g.globalAlpha = alpha; g.imageSmoothingEnabled = false;
  g.drawImage(image, frame.x, frame.y, frame.w, frame.h, -meta.pivot[0], -meta.pivot[1], frame.w, frame.h); g.restore();
}
function canisTrailPictures(S, R) {
  for (const trail of S.trails) {
    const age = S.t - trail.t, fade = 1 - smooth(trail.life * 0.6, trail.life, age); if (fade <= 0) continue;
    let index = 0;
    for (let d = 12; d < trail.length; d += (18 + hash(index + 81) * 21)) {
      const off = Math.sin(index * 2.3) * trail.width * 0.24, pos = add(trail.at, rotateV(V(d, off), trail.a)), width = trail.width * (0.8 + hash(index) * 0.5);
      canisSpriteFX('canis_trail', pos, S.t + index * 0.17, width / 10, width / 16, (hash(index + 15) - 0.5) * 0.35, fade * 0.8); index++;
    }
  }
  for (const q of S.pack) if (q.burn && !q.dead) canisSpriteFX('canis_fireball', q.pos, S.t + q.idx * 0.13, q.r * 7 / 100, q.r * 3.2 / 18, q.facing, 0.88);
}
