import { segCircleT } from './math.js';
import { addRing } from './hits.js';

// Sweep against the small fixed set of world bodies, never against the enemy population.
export function firstBodyHit(field, x0, y0, x1, y1, radius = 0) {
  let found = null, earliest = Infinity;
  function check(body) {
    const r = body.r + radius;
    if (Math.max(x0, x1) < body.x - r || Math.min(x0, x1) > body.x + r ||
        Math.max(y0, y1) < body.y - r || Math.min(y0, y1) > body.y + r) return;
    const t = segCircleT(x0, y0, x1, y1, body.x, body.y, r);
    if (t >= 0 && t < earliest) {
      earliest = t; found = { body, t, x: x0 + (x1 - x0) * t, y: y0 + (y1 - y0) * t };
    }
  }
  check(field.planet);
  for (const moon of field.moons) check(moon);
  return found;
}

export function collideEnemyBodies(e, field, x0, y0) {
  const hit = firstBodyHit(field, x0, y0, e.x, e.y, e.r);
  if (!hit) return;
  const body = hit.body;
  let dx = hit.x - body.x, dy = hit.y - body.y;
  let d = Math.hypot(dx, dy);
  if (d < 1e-6) { dx = x0 - body.x || -e.vx || 1; dy = y0 - body.y || -e.vy; d = Math.hypot(dx, dy); }
  const nx = dx / d, ny = dy / d, clearance = body.r + e.r + 0.01;
  e.x = body.x + nx * clearance; e.y = body.y + ny * clearance;
  const vn = e.vx * nx + e.vy * ny;
  if (vn < 0) { e.vx -= vn * nx; e.vy -= vn * ny; }
  if (e.shove) { e.shove.vx = e.vx; e.shove.vy = e.vy; }
}

export function clipProjectileToBody(game, projectile, x0, y0) {
  const hit = firstBodyHit(game.field, x0, y0, projectile.x, projectile.y, projectile.r || 10);
  if (!hit) return null;
  projectile.x = hit.x; projectile.y = hit.y;
  if (game.fx.rings.length < 240) addRing(game, hit.x, hit.y, 22, '#ffd19a', 0.18);
  return hit;
}
