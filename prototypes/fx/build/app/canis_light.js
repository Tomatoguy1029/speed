// O14/O15：猟犬の実画像から各個体の影を作り、同じ影の場を表示と安全確認に使う。
function canisHull(points) {
  const p = points.slice().sort((a, b) => a.x - b.x || a.y - b.y), cross = (a, b, c) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  const half = list => { const out = []; for (const v of list) { while (out.length > 1 && cross(out[out.length - 2], out[out.length - 1], v) <= 0) out.pop(); out.push(v); } out.pop(); return out; };
  return [...half(p), ...half(p.slice().reverse())];
}
let CANIS_HOUND_HULL = null;
function canisHoundShape(q) {
  const im = IMG['enemy/hound'];
  if (!CANIS_HOUND_HULL) {
    const c = document.createElement('canvas'); c.width = im.width; c.height = im.height; const ctx = c.getContext('2d'); ctx.drawImage(im, 0, 0); const pixels = ctx.getImageData(0, 0, im.width, im.height).data, points = [];
    for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) if (pixels[(y * im.width + x) * 4 + 3] >= 128) { points.push(V(x - im.width / 2, y - im.height / 2), V(x + 1 - im.width / 2, y + 1 - im.height / 2)); }
    CANIS_HOUND_HULL = canisHull(points);
  }
  const scale = spriteR('hound', q.r) * 2 / Math.max(im.width, im.height), angle = enemyDef('hound').look.angle + q.facing;
  return CANIS_HOUND_HULL.map(p => add(q.pos, rotateV(mul(p, scale), angle)));
}
const canisNovaOrigin = S => S.B.visualMouth || add(S.B.pos, mul(fromA(S.B.facing), S.B.r * 1.01));
function canisFlash(S) {
  const t = S.age - S.r.warn;
  return smooth(0, 0.09, t) * (1 - smooth(0.22, 0.98, t));
}
function canisWallLayout(S) {
  const source = canisNovaOrigin(S), groups = Math.min(3, Math.floor(S.pack.length / 2)); S.wall = [];
  if (!groups) return;
  for (let group = 0; group < groups; group++) {
    const members = S.order.filter((_, i) => i % groups === group), angle = group * TAU / groups;
    const spans = members.map((q, i) => {
      const clone = { ...q, pos: V(0, 0), facing: angle + Math.PI / 2 }, axis = orth(fromA(angle)), points = canisHoundShape(clone), lateral = points.map(p => p.x * axis.x + p.y * axis.y);
      const depth = Math.max(S.B.r * 1.5, S.r.pair_dist) + (i % 2 ? q.r * 1.5 : 0) + q.r * (hash(i + group * 9) - 0.5) * 0.3;
      return { q, depth, width: Math.max(...lateral) - Math.min(...lateral) };
    });
    const angular = spans.map(m => Math.atan2(m.width * 0.5, m.depth)), positions = [0];
    for (let i = 1; i < spans.length; i++) positions.push(positions[i - 1] + (angular[i - 1] + angular[i]) * 0.5);
    const center = (positions[0] + positions[positions.length - 1]) * 0.5;
    spans.forEach((m, i) => S.wall.push({ ...m, angle: angle + positions[i] - center }));
  }
}
function canisWallStep(S) {
  if (!S.wall) canisWallLayout(S);
  const source = canisNovaOrigin(S), cfg = { ...bossRule('canis_major', 'bay'), max_speed: S.r.gather_speed, arrive: 2, face_turn: 8 };
  for (const m of S.wall) {
    const u = fromA(m.angle), goal = add(source, mul(u, m.depth));
    if (S.age < S.r.warn + S.r.after) m.q.steer = { goal, face: add(goal, mul(orth(u), 1000)), cfg };
  }
}
function canisNovaField(S) {
  const frame = Math.floor(S.t * 24); if (S.lightField?.frame === frame) return S.lightField;
  if (!S.lightField) {
    const make = () => { const c = document.createElement('canvas'); c.width = LW; c.height = LH; return c; }, plane = make(), sum = make();
    S.lightField = { plane, planeG: plane.getContext('2d'), sum, sumG: sum.getContext('2d', { willReadFrequently: true }) };
  }
  const f = S.lightField, source = canisNovaOrigin(S), lights = [V(0, 0), ...Array.from({ length: 8 }, (_, i) => mul(fromA(i * 2.399963), 9 * Math.sqrt((i + 0.5) / 8)))], shapes = S.pack.filter(q => !q.dead).map(canisHoundShape);
  f.sumG.clearRect(0, 0, LW, LH); f.sumG.globalCompositeOperation = 'lighter'; f.sumG.globalAlpha = 1 / lights.length; f.sumG.filter = 'blur(0.8px)';
  for (const offset of lights) {
    const light = add(source, offset), ctx = f.planeG; ctx.clearRect(0, 0, LW, LH); ctx.fillStyle = '#fff';
    for (const shape of shapes) {
      const projected = shape.map(point => add(light, mul(norm(sub(point, light)), S.r.ring_end * 1.5))), polygon = canisHull([...shape, ...projected]);
      ctx.beginPath(); polygon.forEach((p, i) => { const v = toL(p); if (i) ctx.lineTo(v.x, v.y); else ctx.moveTo(v.x, v.y); }); ctx.closePath(); ctx.fill();
    }
    f.sumG.drawImage(f.plane, 0, 0);
  }
  f.pixels = f.sumG.getImageData(0, 0, LW, LH).data; f.frame = frame; return f;
}
function canisNovaSafe(S, point, radius = DATA.config.ship_radius) {
  if (dist(point, canisNovaOrigin(S)) - radius > S.r.ring_end) return true;
  const pixels = canisNovaField(S).pixels, p = toL(point), r = radius * WL;
  // 機体の円と交わる全セルを確認し、小さい光の隙間も安全扱いにしない。
  for (let y = Math.floor(p.y - r); y <= Math.ceil(p.y + r); y++) for (let x = Math.floor(p.x - r); x <= Math.ceil(p.x + r); x++) {
    const dx = p.x - clamp(p.x, x, x + 1), dy = p.y - clamp(p.y, y, y + 1);
    if (dx * dx + dy * dy > r * r) continue;
    if (x < 0 || x >= LW || y < 0 || y >= LH || pixels[(y * LW + x) * 4 + 3] < 250) return false;
  }
  return true;
}
// 光源のまわりの露光を低解像度の固定テクスチャに焼く。ひと続きの発光面を一度だけ開く。
const NOVA_EMISSION = (() => {
  const side = 192, data = new Float32Array(side * side);
  for (let y = 0; y < side; y++) for (let x = 0; x < side; x++) {
    const u = (x + 0.5) / 96 - 1, v = (y + 0.5) / 96 - 1, radius = Math.hypot(u, v);
    const warp = Math.sin(6 * v + 2.1 * Math.sin(4 * u));
    const grain = Math.sin(13 * u + 9 * v + 3 * warp) * Math.sin(8 * v - 2 * u);
    const heat = Math.max(0, 1 - radius * (1.2 + 0.24 * warp));
    data[y * side + x] = heat ** 3 * (0.70 + 0.30 * grain);

  }
  return data;
})();
function canisNovaLight(S, R) {
  const field = canisNovaField(S), origin = canisNovaOrigin(S), source = toL(origin), p = R.P, charge = S.age < S.r.warn ? smooth(0, S.r.warn, S.age) : 0, flash = canisFlash(S);
  const t = S.age - S.r.warn;
  const tell = t < 0 ? charge : 1 - smooth(0.22, 0.98, t);
  const tint = hexc('#9caec0');
  const gain = Math.min(p.intensity, 1);
  const hot = hexc('#fff0cc'), corona = hexc('#6a9bca');
  const aperture = S.B.r * WL * (t < 0 ? 0.18 + 0.28 * tell * (1 - 0.65 * smooth(0.83, 1, tell)) : 0.24 + 2.65 * smooth(0, 0.115, t));
  if (tell || flash) for (let y = 0; y < LH; y++) for (let x = 0; x < LW; x++) {
    const dx = x - source.x, dy = y - source.y, distance = Math.hypot(dx, dy) / WL;
    const visible = 1 - field.pixels[(y * LW + x) * 4 + 3] / 255;
    if (visible < 0.01 || distance > S.r.ring_end) continue;
    const falloff = (1 - smooth(S.r.ring_end * 0.8, S.r.ring_end, distance)) / (1 + (distance / 760) ** 2);
    const strength = visible * gain * falloff;
    R.back.light(x, y, tint, strength * (tell * 0.10 + flash * 0.25));
    const stretch = t < 0 ? 1 : 1 + 0.45 * flash;
    const tx = Math.floor(96 + dx * 96 / (aperture * stretch)), ty = Math.floor(96 + dy * 96 / aperture);
    if (tx >= 0 && tx < 192 && ty >= 0 && ty < 192) {
      const flux = NOVA_EMISSION[ty * 192 + tx] * visible * gain;
      const exposure = t < 0 ? tell * 0.65 : flash * (1.35 - 0.65 * smooth(0.12, 0.56, t));
      R.front.light(x, y, corona, flux * exposure * 0.8);
      R.front.light(x, y, hot, flux * flux * exposure);
    }
  }
  R.front.glow(source.x, source.y, 4 + tell * 6 + flash * 9, hexc('#bedbe8'), gain * (tell * 0.12 + flash * 0.25));
  S.novaSafe = canisNovaSafe(S, S.ship.pos);
  S.novaHit = t >= 0.09 && t < 0.42 && !S.novaSafe;
  if (S.novaHit) {
    const target = toL(S.ship.pos), direction = angOf(sub(S.ship.pos, origin));
    FX.sparks(R.front, target, t - 0.09, 81, 19, '#ffe7bd', 78, 0.34, direction, 1.4);
    R.front.glow(target.x, target.y, 8, hexc('#ffe7bd'), flash * gain * 0.48);
  }
}
function canisNovaFlare(S, R) {
  const power = canisFlash(S), t = S.age - S.r.warn;
  if (power <= 0) return;
  const origin = canisNovaOrigin(S), gain = Math.min(1, R.P.intensity);
  // シリウス自身の星の絵を開き、光源の近くへ発光を集中させる。
  drawImg('canis_major/large_star', origin, S.B.facing, S.B.r * (0.18 + power * 0.55), power * gain, false, 0.28 * power * gain);

}
