import { CONFIG } from './config.js';
import { clamp, randRange, TAU } from './math.js';
import { createMeteorField } from './meteor-field.js';

export function createField(rng) {
  const moons = [];
  for (let i = 0; i < CONFIG.moonCount; i++) {
    moons.push({
      orbit: randRange(rng, 1500, CONFIG.fieldRadius - 600),
      a0: (i / CONFIG.moonCount) * TAU + randRange(rng, -0.3, 0.3),
      dir: rng() < 0.5 ? -1 : 1,
      r: randRange(rng, 110, 180),
      gm: CONFIG.moonGM,
      x: 0, y: 0,
    });
  }
  const dust = [];
  for (let i = 0; i < CONFIG.dustCount; i++) {
    const a = rng() * TAU;
    const d = randRange(rng, CONFIG.planetRadius + 600, CONFIG.fieldRadius - 200);
    dust.push({ x: Math.cos(a) * d, y: Math.sin(a) * d, r: randRange(rng, 250, 620) });
  }
  const field = { planet: { x: 0, y: 0, r: CONFIG.planetRadius, gm: CONFIG.planetGM }, moons, dust, meteors: createMeteorField(rng) };
  updateMoons(field, 0);
  return field;
}

export function updateMoons(field, t) {
  for (const m of field.moons) {
    const a = m.a0 + m.dir * CONFIG.moonOrbitSpeed * t;
    m.x = Math.cos(a) * m.orbit;
    m.y = Math.sin(a) * m.orbit;
  }
}

export function zoneOf(r) {
  if (r < CONFIG.zoneInner) return 'inner';
  if (r > CONFIG.zoneOuter) return 'outer';
  return 'mid';
}

// 0 in the middle ring, rising to 1 at the planet surface and at the field edge.
export function dangerAt(r) {
  if (r < CONFIG.zoneInner) return clamp((CONFIG.zoneInner - r) / (CONFIG.zoneInner - CONFIG.planetRadius), 0, 1);
  if (r > CONFIG.zoneOuter) return clamp((r - CONFIG.zoneOuter) / (CONFIG.fieldRadius - CONFIG.zoneOuter), 0, 1);
  return 0;
}

export function dustDragAt(field, x, y) {
  for (const d of field.dust) {
    const dx = x - d.x, dy = y - d.y;
    if (dx * dx + dy * dy < d.r * d.r) return CONFIG.dustDrag;
  }
  return 0;
}
