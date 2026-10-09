import { CONFIG } from './config.js';
import { TAU, randRange } from './math.js';
import { createEnemy } from './enemies.js';

// World positions and trajectories are fixed for the run, independent of the ship.
export function createMeteorField(rng) {
  const rocks = [];
  function rock(x, y, kind, vx = 0, vy = 0) {
    if (Math.hypot(x, y) < CONFIG.planetRadius + 200 || Math.hypot(x, y) > CONFIG.fieldRadius - 100) return;
    rocks.push({ x, y, kind, vx, vy, size: randRange(rng, 24, 65),
      facing: rng() * TAU, spin: randRange(rng, -0.5, 0.5), destroyed: false, entity: null });
  }
  for (let i = 0; i < Math.round(CONFIG.meteorCount * 0.45); i++) {
    const a = rng() * TAU, d = randRange(rng, 1100, CONFIG.fieldRadius - 650);
    const cx = Math.cos(a) * d, cy = Math.sin(a) * d;
    for (let j = 0; j < 8; j++) {
      const angle = rng() * TAU, radius = Math.sqrt(rng()) * 380;
      rock(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius, 'belt');
    }
  }
  for (let i = 0; i < Math.round(CONFIG.meteorCount * 2.5); i++) {
    const a = rng() * TAU, d = Math.sqrt(randRange(rng, 800 ** 2, (CONFIG.fieldRadius - 300) ** 2));
    const heading = rng() * TAU, speed = randRange(rng, 15, 35);
    rock(Math.cos(a) * d, Math.sin(a) * d, 'drift', Math.cos(heading) * speed, Math.sin(heading) * speed);
  }
  if (CONFIG.meteorCount > 0) for (let i = 0; i < 3; i++) {
    const angle = rng() * TAU;
    rocks.push({ kind: 'comet', angle, offset: randRange(rng, 1200, 4500) * (rng() < 0.5 ? -1 : 1),
      period: randRange(rng, 42, 65), phase: rng() * 40, size: randRange(rng, 35, 55),
      facing: angle, spin: 0.4, destroyed: false, entity: null });
  }
  for (const m of rocks) if (rng() < CONFIG.rareMeteorChance) m.rareWeapon = rng() < 0.5 ? 'massTow' : 'bipolar';
  return rocks;
}

function meteorWorldPosition(m, t) {
  if (m.kind === 'comet') {
    const along = ((t + m.phase) % m.period) * 950 - CONFIG.fieldRadius - 500;
    const ux = Math.cos(m.angle), uy = Math.sin(m.angle);
    return { x: ux * along - uy * m.offset, y: uy * along + ux * m.offset, vx: ux * 950, vy: uy * 950 };
  }
  const diameter = CONFIG.fieldRadius * 2;
  const wrap = v => ((v + CONFIG.fieldRadius) % diameter + diameter) % diameter - CONFIG.fieldRadius;
  return { x: wrap(m.x + m.vx * t), y: wrap(m.y + m.vy * t), vx: m.vx, vy: m.vy };
}

export function updateMeteorField(game, dt) {
  const time = game.meteorClock ?? game.t;
  const view = game.spawnView || { x: game.ship.x, y: game.ship.y,
    halfW: game.viewRadius * 0.707, halfH: game.viewRadius * 0.707 };
  const near = (p, extra) => Math.abs(p.x - view.x) < view.halfW + extra &&
    Math.abs(p.y - view.y) < view.halfH + extra &&
    Math.hypot(p.x, p.y) > CONFIG.planetRadius + 100 && Math.hypot(p.x, p.y) < CONFIG.fieldRadius + 100;
  let unload = false, changed = false;
  for (const e of game.enemies) {
    const m = e.worldMeteor;
    if (!m || e.dead) continue;
    const p = meteorWorldPosition(m, time);
    if (e.x !== p.x || e.y !== p.y) changed = true;
    e.x = p.x; e.y = p.y; e.vx = p.vx; e.vy = p.vy;
    e.facing = m.facing + m.spin * time;
    if (!near(p, 650)) { m.active = false; unload = true; }
  }
  if (unload) {
    game.enemies = game.enemies.filter(e => !e.worldMeteor || e.worldMeteor.active || e.dead);
    changed = true;
  }
  if (!game.spawning) return changed;
  game.meteorStreamT = (game.meteorStreamT || 0) - dt;
  if (game.meteorStreamT > 0) return changed;
  game.meteorStreamT = 0.2;
  for (const m of game.field.meteors) {
    if (m.destroyed || m.active) continue;
    const p = meteorWorldPosition(m, time);
    if (!near(p, 300)) continue;
    const e = m.entity || (m.entity = createEnemy('meteor', 1, p.x, p.y,
      { size: m.size, facing: m.facing, spin: m.spin }));
    e.worldMeteor = m; m.active = true;
    e.x = p.x; e.y = p.y; e.vx = p.vx; e.vy = p.vy; e.facing = m.facing + m.spin * time;
    game.enemies.push(e); changed = true;
  }
  return changed;
}
