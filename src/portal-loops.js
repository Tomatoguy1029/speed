import { CONFIG } from './config.js';
import { attackPower } from './combat.js';
import { damageEnemy, explode, addRing, addText, burst } from './hits.js';

function portalLoopCross(a, b, c, d) {
  const rx = b.x - a.x, ry = b.y - a.y, sx = d.x - c.x, sy = d.y - c.y;
  const cross = rx * sy - ry * sx;
  if (Math.abs(cross) < 1e-9) return null; // retracing a line encloses no area
  const dx = c.x - a.x, dy = c.y - a.y;
  const t = (dx * sy - dy * sx) / cross, u = (dx * ry - dy * rx) / cross;
  if (t <= 1e-6 || t > 1 + 1e-6 || u < -1e-6 || u > 1 + 1e-6) return null;
  return { x: a.x + rx * t, y: a.y + ry * t, t };
}

function portalLoopArea(points) {
  let twice = 0;
  for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
    twice += points[j].x * points[i].y - points[i].x * points[j].y;
  }
  return Math.abs(twice) / 2;
}

function portalLoopContains(points, x, y) {
  let inside = false;
  for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
    const a = points[j], b = points[i];
    const cross = (b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x);
    if (Math.abs(cross) < 1e-6 && x >= Math.min(a.x, b.x) && x <= Math.max(a.x, b.x)
      && y >= Math.min(a.y, b.y) && y <= Math.max(a.y, b.y)) return true;
    if ((a.y > y) !== (b.y > y) && x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) inside = !inside;
  }
  return inside;
}

function portalLoopExplode(game, dash, points, area) {
  const effect = game.stats.loopBurst;
  const dmg = attackPower(dash.speed, game.stats) * effect.mult;
  const color = effect.splash ? '#ffb340' : '#c46bff';
  const center = points.reduce((c, p) => ({ x: c.x + p.x / points.length, y: c.y + p.y / points.length }), { x: 0, y: 0 });
  // Snapshot the enclosed targets: secondary blasts cannot recursively create more blasts.
  const targets = game.enemies.filter((e) => !e.dead && portalLoopContains(points, e.x, e.y));
  for (const e of targets) {
    const dx = e.x - center.x, dy = e.y - center.y, dist = Math.hypot(dx, dy) || 1;
    damageEnemy(game, e, dmg, { cause: 'portalLoop', dirX: dx / dist, dirY: dy / dist, knock: 500 });
    addRing(game, e.x, e.y, e.r + 28, color, 0.4);
    burst(game, e.x, e.y, color, 12, 0, 0, 360);
  }
  if (effect.splash) for (const e of targets) explode(game, e.x, e.y, CONFIG.portalLoopSplashRadius,
    dmg * CONFIG.portalLoopSplashDamage, { cause: 'portalLoopSplash', color, knock: 350, life: 0.4 });
  game.fx.loops.push({ points, color, life: 0.6, max: 0.6 });
  addText(game, center.x, center.y, `包囲炸裂 ${targets.length}`, color, 24);
  game.events.push({ type: 'explode', x: center.x, y: center.y, radius: Math.sqrt(area / Math.PI), cause: 'portalLoop', enclosed: targets.length });
}

// Test only traveled movement. Closing across an old segment works before reaching a portal.
export function tracePortalLoop(game, dash, x0, y0, x1, y1) {
  if (!game.stats.loopBurst || dash.loopPath.length < 3) return;
  let start = { x: x0, y: y0 }, end = { x: x1, y: y1 };
  let attempts = dash.loopPath.length;
  while (attempts-- > 0) {
    const path = dash.loopPath;
    let first = null;
    for (let i = 0; i < path.length - 1; i++) {
      const hit = portalLoopCross(start, end, path[i], path[i + 1]);
      if (!hit || (first && hit.t >= first.hit.t)) continue;
      const points = [{ x: hit.x, y: hit.y }, ...path.slice(i + 1)];
      const area = portalLoopArea(points);
      if (area >= CONFIG.portalLoopMinArea) first = { hit, points, area, i };
    }
    if (!first) return;
    portalLoopExplode(game, dash, first.points, first.area);
    const hit = { x: first.hit.x, y: first.hit.y };
    // Consume the closed portion while retaining the earlier open prefix and the live tail.
    dash.loopPath = path.slice(0, first.i + 1);
    const last = dash.loopPath[dash.loopPath.length - 1];
    if (Math.hypot(last.x - hit.x, last.y - hit.y) > 1e-6) dash.loopPath.push(hit);
    start = hit;
  }
}
