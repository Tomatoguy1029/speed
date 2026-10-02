import { CONFIG } from './config.js';

// Enemy bullets and missiles. Returns hits on the ship via the callback.
export function updateEnemyBullets(game, dt, onHit) {
  const sh = game.ship;
  const R = CONFIG.shipRadius;
  const p = game.field.planet;
  for (const b of game.ebullets) {
    if (b.kind === 'missile') {
      const want = Math.atan2(sh.y - b.y, sh.x - b.x);
      const cur = Math.atan2(b.vy, b.vx);
      let d = want - cur;
      d = Math.atan2(Math.sin(d), Math.cos(d));
      const a = cur + Math.max(-b.turn * dt, Math.min(b.turn * dt, d));
      b.vx = Math.cos(a) * b.speed; b.vy = Math.sin(a) * b.speed;
    }
    b.x += b.vx * dt; b.y += b.vy * dt;
    b.life -= dt;
    const dx = b.x - sh.x, dy = b.y - sh.y;
    if (dx * dx + dy * dy < (b.r + R) * (b.r + R)) { onHit(b); b.life = 0; }
    if (Math.hypot(b.x - p.x, b.y - p.y) < p.r) b.life = 0;
  }
  if (game.ebullets.some((b) => b.life <= 0)) game.ebullets = game.ebullets.filter((b) => b.life > 0);
}
