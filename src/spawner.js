import { createEnemy } from './enemies.js';
import { TAU } from './math.js';
import { CONFIG } from './config.js';

// Temporary population keeper (replaced by the phase table in Task 6).
export function updateSpawner(game, dt) {
  if (!game.spawning) return;
  const want = 30;
  if (game.enemies.length >= want) return;
  const sh = game.ship;
  const a = game.rng() * TAU;
  const d = game.viewRadius + 150 + game.rng() * 300;
  const x = sh.x + Math.cos(a) * d, y = sh.y + Math.sin(a) * d;
  if (Math.hypot(x, y) > CONFIG.fieldRadius || Math.hypot(x, y) < CONFIG.planetRadius + 100) return;
  const type = game.rng() < 0.15 ? 'armored' : 'drifter';
  game.enemies.push(createEnemy(type, 1, x, y, { facing: a + Math.PI }));
}
