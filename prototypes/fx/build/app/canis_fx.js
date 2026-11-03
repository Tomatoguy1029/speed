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
// pixelFX 原本 fire/fire-breath の45コマを再生する。形は作り直さず、口元と現行の粒の範囲へ合わせる（りゅうの試作が使う）。
function canisJetImage(at, angle, reach, width, time, alpha = 1) {
  if (reach < 8 || alpha <= 0) return;
  const sheet = DATA.canis_breath_sheet, frame = sheet.frames[Math.floor(time * 30) % sheet.frames.length].frame, im = IMG['canis_breath'];
  g.save(); g.translate(at.x, at.y); g.rotate(angle); g.globalAlpha = alpha; g.imageSmoothingEnabled = false;
  g.scale(reach / 133, Math.max(0.45, width / 62)); g.drawImage(im, frame.x, frame.y, frame.w, frame.h, -12, -72, frame.w, frame.h); g.restore();
}
// 噴射（pixelFX fire/flamethrower.js の作りを上から見た形へ）：口元の白い芯から先へ広がって青へ冷える帯、走る膨らみ、ねじれる熱い筋、
// 両脇から後ろへなびく炎の舌（flameBlade）、先端で巻いて煙になる炎の塊（firePuff・smokePuff）、両脇へこぼれる火の粒。
// age：噴き始めからの時間、duration：噴き続ける時間（止まると後ろ端が口から離れて先へ抜ける）
const SIRIUS_H = ['#ffffff', '#f2fbff', '#d8f1ff', '#a9dcff', '#6fb8f2', '#3f8ce0', '#2a66c4', '#1d479b', '#13306a'];
function canisJetStream(R, at, angle, length, width, age, duration, alpha, seed) {
  if (alpha <= 0 || length < 4) return; const fire = PIXELFX.fx['src/fx/fire/_lib.js'], p = R.front, H = SIRIUS_H.map(hexc), NL = fire.noiseFor(0), N = (rate, n = 0, off = 0) => NL(age, rate, n + seed, off);
  const O = toL(at), ux = Math.cos(angle), uy = Math.sin(angle), L = length * WL, V = L / 0.22, W0 = Math.max(0.8, L * 0.014 * width); // width：太さの倍率（先端の半幅は長さの約1割）
  const front = Math.min(L, age * V), back = age > duration ? Math.min(L, (age - duration) * V) : 0; if (front <= back + 1) return;
  const flow = (te) => 1 - 0.35 * Math.exp(-(((((te % 1.6) + 1.6) % 1.6 - 0.55) / 0.05) ** 2)); // ときどき咳き込むように細る
  const cy = (x) => N(1.2, 9, x * 0.02) * 2.2 * (x / L) ** 1.5 * W0, wid = (x) => (2.1 + 5 * Math.pow(x / L, 0.7)) * W0 * flow(age - x / V);
  const P2 = (x, y) => [O.x + ux * x - uy * y, O.y + uy * x + ux * y];
  p.fade = alpha;
  for (let x = back; x <= front; x += 0.5) { // 帯：白い芯→青の肌、走る膨らみで明るさが一段上がる
    const c = cy(x), tipK = Math.sqrt(Math.max(0, smooth(front + 1, front - 7 * W0 * (0.8 + 0.4 * fire.pnoise(age * 9, 9, seed + 2)), x))), w = wid(x) * (1 + 0.15 * fire.pnoise(x * 0.4 - age * 15, 24, seed + 4)) * smooth(back, back + 6, x) * tipK; if (w < 0.4) continue; // 先端は丸く細る（直角に切らない）
    const surge = ((x * 0.035 - age * 3) % 1 + 1) % 1 < 0.12 ? 1 : 0;
    for (let y = -w - 1; y <= w + 1; y += 0.5) { const q = Math.abs(y) / w; if (q > 1.15) continue;
      let lv = (q < 0.18 ? 0 : q < 0.42 ? 2 : q < 0.68 ? 3 : q < 0.9 ? 5 : 7) + Math.floor((x / L) * 2.2) * (q < 0.9 ? 1 : 0); // 芯は細く、先へ行くほど青へ冷える lv = Math.max(0, Math.min(7, lv - surge));
      if (lv >= 7 && fire.pnoise(x * 0.5 + y * 7.3 - age * 25, 40, seed + 6) < 0) continue; const [px, py] = P2(x, c + y); p.px(px, py, H[lv]); }
    for (const ph of [0, Math.PI]) { const a = x * 0.22 - age * 56 + ph, sy = c + Math.sin(a) * w * 0.55; if (Math.cos(a) > -0.1 && w > 1.2) { const [px, py] = P2(x, sy); p.px(px, py, Math.cos(a) > 0.55 ? H[0] : H[1]); } } // ねじれる熱い筋
    if (Math.round(x * 2) % 6 === 0) { const [px, py] = P2(x, c); p.light(px, py, H[4], 0.35 * alpha); }
  }
  const spikes = R.P.jetSpikes ?? 1; if (spikes > 0) for (let i = 0; i < 14; i++) { // 両脇から後ろへなびく炎の舌（大きさはつまみ。0で無し）
    const ph = ((i * 0.618 + age / 1.6) % 1), x = back + 8 + ph * (front - back - 12); if (x > front - 4) continue; const sd = i % 2 ? 1 : -1, w = wid(x), h = (3 + 12 * (x / L)) * (0.55 + 0.6 * (0.5 + 0.5 * N(5, i * 19 + 1))) * Math.min(1, (1 - ph) * 6) * W0 / 1.5 * spikes;
    const [px, py] = P2(x, cy(x) + sd * w * 0.7), bx = -ux * 0.55 - uy * sd * 0.8, by = -uy * 0.55 + ux * sd * 0.8, bl = Math.hypot(bx, by);
    fire.flameBlade(p, px, py, bx / bl, by / bl, h, 1.1 + 1.6 * (x / L), N(3, i) * 0.6, N, seed + i * 19, H, fire.LAYERS);
  }
  for (let i = 0; i < 10; i++) { // 両脇へこぼれる火の粒
    const q = new PX.Rng(seed * 7 + i + 1), life = q.range(0.3, 0.55), born = (i / 10) * 1.6, ag = ((age - born) % 1.6 + 1.6) % 1.6; if (ag > life || age < born) continue;
    const d = q.range(0.2, 0.9) * L; if (d < back || d > front) continue; const sd = q.chance(0.5) ? 1 : -1, k = ag / life, x = d + ag * V * 0.25, y = cy(d) + sd * (wid(d) + ag * q.range(20, 45) * W0);
    const [px, py] = P2(x, y); p.px(px, py, k < 0.4 ? H[1] : k < 0.7 ? H[3] : H[5]); p.glow(px, py, 3, H[4], 0.35 * (1 - k) * alpha);
  }
  if (back <= 0) { const [px, py] = P2(1, 0); p.glow(px, py, 6 * W0, H[2], 0.7 * alpha); p.px(px, py, H[0]); } // 口元の点火の光
  p.fade = 1;
}
// おおいぬ専用の火炎放射。GIFの形状計算と本番pixel_fire_density／shapeの式をHTMLでも使う。
// pixelFX fire/_lib.js由来のノイズ・炎の舌：MIT License, Copyright (c) 2026 Hugo Duprez。
// 一角獣の尾は別の形・動きなので、従来のcanisJetStreamから切り離しておく。
function canisPixelFireStream(R, at, angle, length, width, age, duration, alpha, seed) {
  if (alpha <= 0 || length < 4) return;
  const fire = PIXELFX.fx['src/fx/fire/_lib.js'], NL = fire.noiseFor(0), N = (rate, n = 0, off = 0) => NL(age, rate, n + seed, off);
  const L = length * WL, speed = L / 0.22, front = Math.min(L, age * speed), back = age > duration ? Math.min(L, (age - duration) * speed) : 0;
  if (front <= back + 1) return;
  const W0 = Math.max(0.04, L * 0.014 * width), samples = [];
  const flow = te => 1 - 0.35 * Math.exp(-Math.pow(((((te % 1.6) + 1.6) % 1.6) - 0.55) / 0.05, 2));
  const cy = x => N(1.2, 9, x * 0.02) * 2.2 * Math.pow(x / L, 1.5) * W0;
  const wid = x => (2.1 + 5 * Math.pow(x / L, 0.7)) * W0 * flow(age - x / speed);
  for (let x = back + 0.2; x < front; x += 0.8) {
    const taper = Math.pow(clamp((front - x) / Math.max(12, L * 0.11)), 1.1);
    const w = wid(x) * (1 + 0.15 * fire.pnoise(x * 0.4 - age * 15, 24, seed + 4)) * smooth(back, back + 6, x) * taper;
    if (w < 0.25) continue;
    const y = cy(x), surge = ((x * 0.035 - age * 3) % 1 + 1) % 1 < 0.12 ? 1.15 : 1;
    const inner = 0.66 + 0.08 * fire.pnoise(x * 0.35 - age * 20, 24, seed + 12), core = 0.16 + 0.05 * fire.pnoise(x * 0.4 - age * 26, 24, seed + 13);
    samples.push([x, y, w * 1.28, 0, 1.5], [x, y, w * inner * surge * 1.28, 1, 1.5], [x, y, w * core * surge * 1.28, 2, 1.5]);
    for (const ph of [0, Math.PI]) {
      const a = x * 0.22 - age * 56 + ph;
      if (Math.cos(a) > -0.1 && w > 1.2) {
        const sy = y + Math.sin(a) * w * 0.55;
        samples.push([x, sy, 1.3, 1, 1.5]);
        if (Math.cos(a) > 0.55) samples.push([x, sy, 0.9, 2, 1.5]);
      }
    }
  }
  const spikes = R.P.jetSpikes ?? 1;
  if (spikes > 0) for (let i = 0; i < 14; i++) {
    const ph = (i * 0.618 + age / 1.6) % 1, x = back + 8 + ph * (front - back - 12);
    if (x > front - 4) continue;
    const sd = i % 2 ? 1 : -1, w = wid(x), h = (3 + 12 * x / L) * (0.55 + 0.6 * (0.5 + 0.5 * N(5, i * 19 + 1))) * Math.min(1, (1 - ph) * 6) * W0 / 1.5 * spikes;
    const bx = -0.55, by = sd * 0.8, norm = Math.hypot(bx, by);
    for (const [lw, lh, layer] of [[1, 1, 0], [0.7, 0.86, 1], [0.3, 0.42, 2]]) for (let r = 0; r < h * lh; r += 0.65) {
      const u = r / (h * lh), bend = N(3, i) * 0.6, off = bend * u * u * lh + N(4, seed + i * 19 + 7, r * 0.2) * u * 1.1;
      const xx = x + bx / norm * r - by / norm * off, yy = cy(x) + sd * w * 0.7 + by / norm * r + bx / norm * off;
      if (xx < back || xx > front) continue;
      const half = (1.1 + 1.6 * x / L) * lw * Math.pow(1 - u, 0.85) * Math.min(1, (r + 1.5) / 3.5) + N(9, seed + i * 19, r * 0.45) * 0.5;
      if (half >= 0.3) samples.push([xx, yy, half * 1.4, layer, 1.2, Math.atan2(by, bx)]);
    }
  }
  canisPixelFireField(R, at, angle, age, alpha, samples);
}
function canisPixelFireField(R, at, angle, clock, alpha, samples) {
  if (!samples.length) return;
  let minX = Infinity, maxX = -Infinity, side = 0;
  for (const [x, y, width, , axial] of samples) {
    const pad = Math.max(width, axial);
    minX = Math.min(minX, x - pad); maxX = Math.max(maxX, x + pad); side = Math.max(side, Math.abs(y) + pad);
  }
  const fw = Math.max(192, Math.ceil(side * 2 + 16)), fh = Math.max(512, Math.ceil(maxX + 80)), ox = fw * 0.5, oy = fh - 40;
  const count = fw * fh * 3;
  let field = canisPixelFireField.buffer;
  if (!field || field.length < count) field = canisPixelFireField.buffer = new Float32Array(count);
  field.fill(0, 0, count);
  // pixel_fire_density.gdshaderの加算密度。細長い粒で帯と舌をつなぎ、画像の伸縮はしない。
  for (const [x, y, width, channel, axial, a = 0] of samples) {
    const cx = ox + y, cy = oy - x, c = Math.cos(a), s = Math.sin(a), rx = Math.abs(c * width) + Math.abs(s * axial), ry = Math.abs(s * width) + Math.abs(c * axial);
    const x0 = Math.max(0, Math.floor(cx - rx)), x1 = Math.min(fw - 1, Math.ceil(cx + rx)), y0 = Math.max(0, Math.floor(cy - ry)), y1 = Math.min(fh - 1, Math.ceil(cy + ry));
    for (let j = y0; j <= y1; j++) for (let i = x0; i <= x1; i++) {
      const dx = i + 0.5 - cx, dy = j + 0.5 - cy, u = (dx * c + dy * s) / width, v = (-dx * s + dy * c) / axial, d2 = u * u + v * v;
      if (d2 < 1) field[(j * fw + i) * 3 + channel] += Math.exp(-d2 * 3.2) * (1 - smooth(0.72, 1, Math.sqrt(d2)));
    }
  }
  const origin = toL(at), c = Math.cos(angle), s = Math.sin(angle), corners = [[minX, -side], [minX, side], [maxX, -side], [maxX, side]].map(([x, y]) => [origin.x + c * x - s * y, origin.y + s * x + c * y]);
  const x0 = Math.max(0, Math.floor(Math.min(...corners.map(q => q[0])) - 3)), x1 = Math.min(LW - 1, Math.ceil(Math.max(...corners.map(q => q[0])) + 3));
  const y0 = Math.max(0, Math.floor(Math.min(...corners.map(q => q[1])) - 3)), y1 = Math.min(LH - 1, Math.ceil(Math.max(...corners.map(q => q[1])) + 3));
  const color = R.P.color || '#80c8ff';
  if (canisPixelFireField.color !== color) {
    const base = hsl('#80c8ff'), tint = hsl(color);
    canisPixelFireField.color = color;
    canisPixelFireField.colors = ['#2a66c4', '#a9dcff', '#ffffff'].map(hex => {
      const v = hsl(hex);
      return hexc(fromHsl({ h: (v.h + tint.h - base.h + 360) % 360, s: clamp(v.s * tint.s / base.s), l: v.l }));
    });
  }
  const cols = canisPixelFireField.colors, p = R.front, fade = p.fade;
  p.fade *= alpha;
  try {
    for (let j = y0; j <= y1; j++) for (let i = x0; i <= x1; i++) {
      const dx = i + 0.5 - origin.x, dy = j + 0.5 - origin.y;
      const wx = Math.floor(ox - s * dx + c * dy) + 0.5, wy = Math.floor(oy - c * dx - s * dy) + 0.5;
      const u = (Math.sin(wy * 0.075 - clock * 4.4) + Math.sin(wx * 0.11 + wy * 0.033 + clock * 2.1)) * 1.2, v = Math.cos(wx * 0.08 + clock * 3) * 0.55 * 1.2;
      const xx = Math.floor(wx + u), yy = Math.floor(wy + v);
      if (xx < 0 || xx >= fw || yy < 0 || yy >= fh) continue;
      const k = (yy * fw + xx) * 3;
      // pixel_fire_shape.gdshaderのthreshold 0.32＋edge_softness 0.04の中点。
      if (field[k] < 0.34) continue;
      const inner = field[k + 1] >= 0.34, core = inner && field[k + 2] >= 0.34, col = cols[core ? 2 : inner ? 1 : 0];
      p.px(i, j, col);
      if ((i & 3) === 0 && (j & 3) === 0) p.glow(i, j, 2, col, core ? 0.10 : inner ? 0.05 : 0.02);
    }
  } finally { p.fade = fade; }
}

function canisJetPictures(S, R) {
  const B = S.B, P = R.P, Wm = P.jetWidth ?? 1, Wh = P.houndJetWidth ?? 1; // 長さは判定と同じ値（canisStartJet で掛け済み）
  if (S.tech === 'sirius_flame' && S.flames.length) { // シリウスの光：歩きながら口から噴き続ける
    const mouth = B.visualMouth || canisMouth(B), u = fromA(B.facing), n = orth(u); let reach = 0, width = 0;
    for (const f of S.flames) { const rel = sub(f.pos, mouth), radius = lerp(f.r0, f.r1, f.age / f.life); reach = Math.max(reach, rel.x * u.x + rel.y * u.y + radius); width = Math.max(width, Math.abs(rel.x * n.x + rel.y * n.y) * 2 + radius); }
    S.jetStart ??= S.t; canisPixelFireStream(R, mouth, B.facing, reach * P.size, P.size * Wm, S.t - S.jetStart, Infinity, Math.min(1, P.intensity), 11);
  } else S.jetStart = null;
  for (const jet of S.jetVisuals) { const age = S.t - jet.t, source = jet.owner === 'boss' && age <= jet.duration ? (B.visualMouth || jet.at) : jet.at;
    canisPixelFireStream(R, source, jet.a, jet.length * P.size, P.size * (jet.owner === 'hound' ? Wh : Wm), age, jet.duration, Math.min(1, P.intensity), 5 + jet.id * 13); }
}

// 残り火：噴射開始から共通の待ち時間で出す。噴射中は保持し、火が消えた時点から冷えて消える。粒を密度の場へ足し込み、
// 鳳凰と同じく、ゆがめてしきい値で切った外炎・内炎・芯の面で塗る（シリウスの青）。燃えた跡にはまだらなすすが残って薄れる
function canisEmbers(S, R) {
  const P = R.P, frame = canisEmbers.frame ||= PX.createFrame(LW, LH); PX.clearFrame(frame); const p = new PX.Painter(frame), H = SIRIUS_H.map(hexc), sp = [];
  const soot = [hexc('#0c1420'), hexc('#142238')], cell = 45 * WL, wMul = (P.jetWidth ?? 1) * P.size; // 残り火の太さは噴射の太さと同じつまみ
  for (const tr of S.trails) for (const d of tr.deposits || []) {
    const wait = clamp(P.emberDelay ?? 0.2, 0, tr.jetDuration ?? 1.1), bornAge = S.t - tr.t - wait, a = Math.max(0, S.t - (tr.fireEndAt ?? tr.t)), life = 1.0 + hash(d.seed + 5) * 1.8; if (bornAge < 0 || a > life + 0.8) continue; const L = toL(d.pos);
    for (let j = 0; j < 7; j++) { const sx = L.x + (hash(d.seed + j * 7) - 0.5) * cell * 1.2, sy = L.y + (hash(d.seed + j * 11) - 0.5) * cell * 1.2, hs = hash(d.seed + j * 13 + 1); if (hs < 0.35) continue; // すすは燃えた所にまだらに残る
      p.blend(sx, sy, soot[j % 2], 0.6 * (1 - smooth(life * 0.5, life + 0.8, a))); }
    for (let j = 0; j < 4; j++) { const hj = hash(d.seed + j * 17 + 3); if (hj < 0.3) continue; // 燃えない所もある
      const lf = life * (0.45 + 0.55 * hash(d.seed + j * 29)); if (a > lf) continue; const k = 1 - a / lf, flick = 0.75 + 0.25 * Math.sin(S.t * (9 + hj * 7) + j * 2);
      sp.push({ x: L.x + (hash(d.seed + j * 7 + 50) - 0.5) * cell * 1.1, y: L.y + (hash(d.seed + j * 11 + 50) - 0.5) * cell * 1.1, r: (2.4 + 3.4 * hj) * Math.pow(k, 0.6) * flick * wMul * smooth(0, 0.1, bornAge), age: 1 - k }); }
  }
  if (sp.length) { let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity; for (const q of sp) { x0 = Math.min(x0, q.x - q.r * 2); y0 = Math.min(y0, q.y - q.r * 2); x1 = Math.max(x1, q.x + q.r * 2); y1 = Math.max(y1, q.y + q.r * 2); }
    const ox = Math.max(0, Math.floor(x0)), oy = Math.max(0, Math.floor(y0)), Wd = Math.min(LW, Math.ceil(x1)) - ox + 1, Hd = Math.min(LH, Math.ceil(y1)) - oy + 1;
    if (Wd > 0 && Hd > 0) { const field = new Float32Array(Wd * Hd * 3);
      for (const q of sp) { phxSplat(field, Wd, Hd, ox, oy, q.x, q.y, q.r * 1.25, 0); if (q.age < 0.55) phxSplat(field, Wd, Hd, ox, oy, q.x, q.y - q.r * 0.15, q.r * 0.8, 1); if (q.age < 0.25) phxSplat(field, Wd, Hd, ox, oy, q.x, q.y - q.r * 0.2, q.r * 0.5, 2); }
      const clock = Math.floor(S.t * 30) / 30, th = 0.32, read = (i, j, ch) => { i = Math.max(0, Math.min(Wd - 1, Math.round(i))); j = Math.max(0, Math.min(Hd - 1, Math.round(j))); return field[(j * Wd + i) * 3 + ch]; };
      for (let j = 0; j < Hd; j++) for (let i = 0; i < Wd; i++) { const wx = (i + ox) * LP, wy = (j + oy) * LP, u2 = (Math.sin(wy * 0.075 - clock * 4.4) + Math.sin(wx * 0.11 + wy * 0.033 + clock * 2.1)) * 1.2, v2 = Math.cos(wx * 0.08 + clock * 3) * 0.66;
        if (read(i + u2, j + v2, 0) < th) continue; const g1 = read(i + u2, j + v2, 1) >= th, b1 = g1 && read(i + u2, j + v2, 2) >= th, c = b1 ? H[1] : g1 ? H[4] : H[6]; p.px(i + ox, j + oy, c); if (((i + ox) & 3) === 0 && ((j + oy) & 3) === 0) p.glow(i + ox, j + oy, 4, c, 0.18 * P.intensity); } } }
  g.save(); blitFrame(frame); g.restore(); worldTransform();
}
function canisSpriteFX(name, point, time, scaleX, scaleY, angle = 0, alpha = 1) {
  const sheet = DATA[name + '_sheet'], frames = sheet.frames, meta = sheet.meta.pixelfx, frame = frames[((Math.floor(time * meta.fps) % frames.length) + frames.length) % frames.length].frame, image = IMG[name];
  g.save(); g.translate(point.x, point.y); g.rotate(angle); g.scale(scaleX, scaleY); g.globalAlpha = alpha; g.imageSmoothingEnabled = false;
  g.drawImage(image, frame.x, frame.y, frame.w, frame.h, -meta.pivot[0], -meta.pivot[1], frame.w, frame.h); g.restore();
}
function canisTrailPictures(S, R) {
  for (const q of S.pack) if (q.burn && !q.dead) canisSpriteFX('canis_fireball', q.pos, S.t + q.idx * 0.13, q.r * 7 / 100, q.r * 3.2 / 18, q.facing, 0.88);
  if (!['sirius', 'sirius_flame'].includes(S.tech)) return;
  canisEmbers(S, R); return; // 残り火は canisEmbers（密度の場）で描く
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

// 猟犬の攻撃（飛びかかり）：燃える青い弾。pixelFX projectiles/plasma-shot.js の作り（熱い芯・肌の上の揺らぎ・尾が細ってちぎれる雫が冷えて消える）から
// プラズマを抜き、シリウスの青い炎にした。体の輪郭から後ろへ炎がなびき、通った跡に燃える雫が残って冷えて消える
function canisHoundBurn(R, q, t) {
  const live = q.until > t, k = live ? 1 : 1 - clamp((t - (q.until || 0)) / 0.4); if (k <= 0 || !q.trail?.length) return;
  const fire = PIXELFX.fx['src/fx/fire/_lib.js'], H = SIRIUS_H.map(hexc), u = fromA(q.facing), n = q.trail.length;
  for (let i = 0; i < n; i++) { const f = (i + 1) / n, P0 = toL(q.trail[i]), drop = (i % 3) === 0 ? 1 : 0.55, jx = (hash(i * 3.1 + (q.idx || 0)) - 0.5) * 2, jy = (hash(i * 5.7 + (q.idx || 0)) - 0.5) * 2; // 雫：古いほど小さく冷える
    fire.firePuff(R.back, P0.x + jx, P0.y + jy, Math.max(0.05, f * k), (0.8 + 2.6 * f) * drop * q.r * WL * 0.22, hash(i + (q.idx || 0) * 7), H, 0.14); }
  if (!live) return; const E = spriteEdges('enemy/hound'); if (!E) return;
  const d = enemyDef('hound'), ang = d.look.angle + q.facing, sc = 2 * spriteR('hound', q.r) / Math.max(E.w, E.h), ca = Math.cos(ang), sa = Math.sin(ang), fr = Math.floor(t * 30);
  for (let i = 0; i < 18; i++) { const rg = new PX.Rng(i * 17 + fr * 3 + (q.idx || 0) * 101 + 1), e0 = rg.pick(E.pts), W0 = toL(V(q.pos.x + (e0[0] * ca - e0[1] * sa) * sc, q.pos.y + (e0[0] * sa + e0[1] * ca) * sc)), lf = rg.range(2, 6); // 体の輪郭から後ろへなびく炎
    R.front.line(W0.x, W0.y, W0.x - u.x * lf + rg.range(-1, 1), W0.y - u.y * lf + rg.range(-1, 1), (w) => w < 0.3 ? H[1] : w < 0.6 ? H[3] : H[5]); }
  const head = toL(add(q.pos, mul(u, q.r * 0.6))); R.front.glow(head.x, head.y, q.r * WL * 1.6, H[4], 0.45); R.front.glow(head.x, head.y, q.r * WL * 0.6, H[1], 0.4); // 熱い芯
}
// 光を継ぐ群れの猟犬の予兆：ボスの噴射の予兆と同じく、口元に光が集まって光る
function canisRelayTell(R, q, k, t) {
  const m = add(q.pos, mul(fromA(q.facing), q.r)), L = toL(m); bossGather(R, m, q.r * 1.2, k, t, (q.idx || 0) + 3);
  R.front.glow(L.x, L.y, 2 + 5 * k, hexc('#a9dcff'), 0.3 + 0.5 * k); R.front.glow(L.x, L.y, 1 + 2 * k, hexc('#ffffff'), 0.5 * k);
}
