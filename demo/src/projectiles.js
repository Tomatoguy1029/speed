import { CONFIG } from './config.js';
import { segCircleT } from './math.js';
import { clipProjectileToBody } from './body-collision.js';

// Enemy bullets and missiles. Returns hits on the ship via the callback.
export function updateEnemyBullets(game, dt, onHit) {
  const sh = game.ship;
  const R = CONFIG.shipRadius;
  for (const b of game.ebullets) {
    if (b.life <= 0) continue;
    if (b.kind === 'missile') {
      const t = game.enemyAim || sh; // home on where enemies think the ship is
      const want = Math.atan2(t.y - b.y, t.x - b.x);
      const cur = Math.atan2(b.vy, b.vx);
      let d = want - cur;
      d = Math.atan2(Math.sin(d), Math.cos(d));
      const a = cur + Math.max(-b.turn * dt, Math.min(b.turn * dt, d));
      b.vx = Math.cos(a) * b.speed; b.vy = Math.sin(a) * b.speed;
    }
    const x0 = b.x, y0 = b.y;
    b.x += b.vx * dt; b.y += b.vy * dt;
    b.life -= dt;
    const bodyHit = clipProjectileToBody(game, b, x0, y0);
    const shipHit = segCircleT(x0, y0, b.x, b.y, sh.x, sh.y, b.r + R);
    if (shipHit >= 0 && (!bodyHit || shipHit < 1)) { onHit(b); b.life = 0; }
    if (bodyHit) b.life = 0;
  }
  if (game.ebullets.some((b) => b.life <= 0)) game.ebullets = game.ebullets.filter((b) => b.life > 0);
}
