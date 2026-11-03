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
  // 見やすい予兆：水色や体の塗りではなく、目が橙色に光って攻撃が近いほど速く強く明滅し、頭のまわりに橙の光がにじむ。後ろ足から蹴る火の粉が後ろへ散る
  const uu = fromA(direction), side = orth(uu), head = add(q.pos, mul(uu, q.r * 0.55)), blink = 0.55 + 0.45 * Math.sin(S_now() * (10 + 30 * u)), k = smooth(0.05, 0.6, u) * (0.7 + 0.3 * blink);
  g.save(); g.globalCompositeOperation = 'lighter';
  const gr = g.createRadialGradient(head.x, head.y, 0, head.x, head.y, q.r * 1.3); gr.addColorStop(0, `rgba(255,150,40,${0.55 * k})`); gr.addColorStop(1, 'rgba(255,90,20,0)'); g.fillStyle = gr; g.fillRect(head.x - q.r * 1.3, head.y - q.r * 1.3, q.r * 2.6, q.r * 2.6);
  for (const sd of [-1, 1]) { const ey = add(head, mul(side, sd * q.r * 0.22)), er = Math.max(1.6, q.r * 0.12); const g2 = g.createRadialGradient(ey.x, ey.y, 0, ey.x, ey.y, er * 2.4); g2.addColorStop(0, `rgba(255,240,200,${k})`); g2.addColorStop(0.35, `rgba(255,170,50,${k})`); g2.addColorStop(1, 'rgba(255,90,20,0)'); g.fillStyle = g2; g.fillRect(ey.x - er * 2.4, ey.y - er * 2.4, er * 4.8, er * 4.8); }
  if (u > 0.35) for (let i = 0; i < 6; i++) { const ph = ((S_now() * 3 + i / 6) % 1), base = add(q.pos, mul(uu, -q.r * 0.6)), p0 = add(add(base, mul(uu, -ph * q.r * 1.6)), mul(side, (hash(i * 3.7) - 0.5) * q.r * 1.2)); g.fillStyle = `rgba(255,${180 - ph * 80 | 0},80,${(1 - ph) * smooth(0.35, 0.8, u)})`; g.fillRect(p0.x - 1, p0.y - 1, 2, 2); }
  g.restore();
}
const S_now = () => (typeof S !== 'undefined' && S ? S.t : 0);
// pixelFX 原本 fire/fire-breath の45コマを再生する。形は作り直さず、口元と現行の粒の範囲へ合わせる。
function canisJetImage(at, angle, reach, width, time, alpha = 1) {
  if (reach < 8 || alpha <= 0) return;
  const sheet = DATA.canis_breath_sheet, frame = sheet.frames[Math.floor(time * 30) % sheet.frames.length].frame, im = IMG['canis_breath'];
  g.save(); g.translate(at.x, at.y); g.rotate(angle); g.globalAlpha = alpha; g.imageSmoothingEnabled = false;
  g.scale(reach / 133, Math.max(0.45, width / 62)); g.drawImage(im, frame.x, frame.y, frame.w, frame.h, -12, -72, frame.w, frame.h); g.restore();
}
// 焼き焦がす光：原本flamethrowerを固定の大きさで流し、実粒の到達で前後を開く。
// 光の切り口を作らないよう、原本1枚を柔らかな透明マスクで表示する。
function canisSiriusJet(S, R, jet) {
  const flames = S.flames.filter(f => f.jetId === jet.id); if (!flames.length) return;
  const u = fromA(jet.a), P = R.P, sheet = DATA.canis_flamethrower_sheet, meta = sheet.meta.pixelfx, image = IMG.canis_flamethrower;
  const age = Math.max(0, S.t - jet.t), cycle = Math.floor(age * meta.fps) % 32, frame = sheet.frames[cycle < 17 ? cycle : cycle + 16].frame;
  let front = 0, back = Infinity;
  for (const flame of flames) { const rel = sub(flame.pos, jet.at), d = rel.x * u.x + rel.y * u.y, radius = lerp(flame.r0, flame.r1, flame.age / flame.life); front = Math.max(front, d + radius); back = Math.min(back, d - radius); }
  const emitting = age <= jet.duration + 1 / 60;
  front = Math.min(jet.length, front); back = emitting ? 0 : Math.max(0, back); if (front <= back) return;
  // 横は実射程で固定。共通サイズは太さと火の大きさへだけ使う。
  const sx = jet.length / 240, sy = Math.max(jet.width * 1.2, jet.length * 0.025) / 4.2 * (P.jetWidth ?? 1) * P.size;
  const fade = 1 - smooth(jet.duration + jet.life * 0.65, jet.duration + jet.life, age), alpha = Math.min(1, P.intensity) * fade;
  if (alpha <= 0) return;
  let surface = canisSiriusJet.surface;
  if (!surface) { const canvas = document.createElement('canvas'); canvas.width = frame.w; canvas.height = frame.h; const mask = document.createElement('canvas'); mask.width = frame.w; mask.height = frame.h; const maskG = mask.getContext('2d'); surface = canisSiriusJet.surface = { canvas, ctx: canvas.getContext('2d'), mask, maskG, pixels: maskG.createImageData(frame.w, frame.h) }; }
  const ctx = surface.ctx, left = meta.pivot[0] + (emitting ? -7 : back / sx), right = meta.pivot[0] + front / sx, edge = Math.min(9, Math.max(1, (right - left) * 0.24));
  ctx.clearRect(0, 0, frame.w, frame.h); ctx.globalCompositeOperation = 'source-over'; ctx.drawImage(image, frame.x, frame.y, frame.w, frame.h, 0, 0, frame.w, frame.h);
  // 芯の先より外側の光を先に消す、丸みのある切り口。縦一直線に光を切らない。
  const pixels = surface.pixels.data;
  for (let y = 0; y < frame.h; y++) for (let x = 0; x < frame.w; x++) { const dy = y - meta.pivot[1] - 5 * ((x - meta.pivot[0]) / 224) ** 2, index = (y * frame.w + x) * 4;
    const a = smooth(0, edge, x - left - dy * dy / 55) * smooth(0, edge * 1.5, right - x - dy * dy / 70);
    pixels[index] = pixels[index + 1] = pixels[index + 2] = 255; pixels[index + 3] = Math.round(a * 255); }
  surface.maskG.putImageData(surface.pixels, 0, 0); ctx.globalCompositeOperation = 'destination-in'; ctx.drawImage(surface.mask, 0, 0);
  const mouth = emitting && S.B.visualMouth ? S.B.visualMouth : jet.at;
  g.save(); g.translate(mouth.x, mouth.y); g.rotate(jet.a); g.imageSmoothingEnabled = false; g.globalAlpha = alpha;
  g.drawImage(surface.canvas, -meta.pivot[0] * sx, -meta.pivot[1] * sy, frame.w * sx, frame.h * sy);
  g.restore();
}
function canisJetPictures(S, R) {
  const B = S.B, P = R.P;
  if (S.tech === 'sirius_flame' && S.flames.length) {
    const mouth = B.visualMouth || canisMouth(B), u = fromA(B.facing), n = orth(u); let reach = 0, width = 0;
    for (const f of S.flames) { const rel = sub(f.pos, mouth), radius = lerp(f.r0, f.r1, f.age / f.life); reach = Math.max(reach, rel.x * u.x + rel.y * u.y + radius); width = Math.max(width, Math.abs(rel.x * n.x + rel.y * n.y) * 2 + radius); }
    canisJetImage(mouth, B.facing, reach * P.size * (P.jetLength ?? 1), width * P.size * (P.jetWidth ?? 1), S.t, Math.min(1, P.intensity));
  }
  for (const jet of S.jetVisuals) {
    if (S.tech === 'sirius') { canisSiriusJet(S, R, jet); continue; }
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
  for (const q of S.pack) if (q.burn && !q.dead) canisSpriteFX('canis_fireball', q.pos, S.t + q.idx * 0.13, q.r * 7 / 100, q.r * 3.2 / 18, q.facing, 0.88);
  if (S.tech !== 'sirius') return;
  const fire = PIXELFX.fx['src/fx/fire/_lib.js'], P = R.P;
  const frame = canisTrailPictures.floorFrame ||= PX.createFrame(LW, LH);
  PX.clearFrame(frame);
  const p = new PX.Painter(frame), NL = fire.noiseFor(0);
  const H = ['#cceafa', '#a8d9ef', '#72bbdf', '#4293c2', '#2874aa', '#20568c', '#193d69', '#132a49', '#0b1c31'].map(hexc);
  const dark = [hexc('#0b1421'), hexc('#132237'), hexc('#1d3047')], emberColors = ['#edbc82', '#c57c48', '#84432b', '#412b28'].map(hexc);
  for (const trail of S.trails) {
    const maximum = trail.maximum * (P.trailLength ?? 1), spread = P.trailWidth ?? 1;
    for (const d of trail.deposits || []) {
      if (dist(d.pos, trail.at) > maximum) continue;
      const seed = d.seed, elapsed = S.t - d.t, wait = 0.14 + hash(seed + 21) * 0.16, age = elapsed - wait;
      if (age < 0) continue; // その場所を炎が吹き抜けたあとだけ火床を見せる。
      const life = Math.min(trail.life, 1.25 + hash(seed + 5) * 1.8), grow = smooth(0, 0.12 + hash(seed + 9) * 0.16, age), collapse = 1 - smooth(life * (0.42 + hash(seed + 17) * 0.18), life, age);
      const remain = 1 - smooth(life, life + 0.45, age); if (remain <= 0) continue;
      const at = toL(d.pos), radius = (1.8 + hash(seed + 31) * 2.4) * spread * P.size;
      p.place(at.x, at.y); p.fade = remain; p.lightK = P.intensity * 0.32;
      // 原本fire-ringの焦げと同じく、欠けた煤と冷える粒を小さい範囲へ置く。
      for (let y = -Math.ceil(radius * 0.56); y <= radius * 0.56; y++) for (let x = -Math.ceil(radius); x <= radius; x++) {
        const dist2 = (x / radius) ** 2 + (y / (radius * 0.56)) ** 2, grain = hash(seed + x * 41 + y * 137);
        if (dist2 > 0.7 + grain * 0.3 || grain < 0.24 || (Math.abs(x) < radius * 0.18 && grain > 0.66)) continue;
        p.blend(x, y, dark[Math.floor(grain * 3) % 3], grow * (0.40 + grain * 0.35));
      }
      const kind = hash(seed + 47), flame = grow * collapse;
      if (kind > 0.48 && flame > 0.02) {
        const h = (1.8 + hash(seed + 53) * 8.0) * Math.pow(flame, 0.8) * P.size, w = (0.65 + hash(seed + 59) * 1.0) * spread * Math.sqrt(flame);
        const N = (rate, n = 0, off = 0) => NL(age, rate, n + seed, off);
        const layers = age < life * 0.30 && kind > 0.76 ? fire.BACK_LAYERS : [[1, 1, 7], [0.70, 0.76, 5], [0.33, 0.44, 3]];
        // 原本の舌・火の塊を場所ごとに別の寿命で育て、線として結ばない。
        if (kind < 0.72) fire.firePuff(p, hash(seed + 62) - 0.5, -h * 0.3, 0.65 * collapse, Math.max(0.7, h * 0.35), kind, H, 0.08);
        else fire.flameTongue(p, 0, 0, h, w, N(2.2, 40) * (0.6 + h * 0.1), N, seed, H, layers, 0.35, 0.65);
      }
      for (let j = 0; j < 3; j++) {
        const mark = hash(seed + j * 67 + 101); if (mark < 0.42) continue;
        const x = (hash(seed + j * 13 + 111) - 0.5) * radius * 1.7, y = (hash(seed + j * 23 + 127) - 0.5) * radius * 0.8;
        const heat = Math.max(0, 0.85 - age / (life + 0.4)) * grow;
        if (heat > 0.04) fire.ember(p, x, y, heat, 1, emberColors, age * 29 + seed + j);
      }
    }
  }
  // 専用の床レイヤーを今ここで合成する。噴射や本体より奥で、R.frontには残さない。
  blitFrame(frame); worldTransform();
}
