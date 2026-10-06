import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { createGame, update } from '../src/world.js';
import { killEnemy } from '../src/hits.js';
import { createEnemy } from '../src/enemies.js';

const idle = { charging: false, aimX: 0, aimY: 0, release: false };

test('running out of time loses the run', () => {
  const game = createGame({ seed: 2 });
  game.spawning = false;
  game.debug.invincible = true;
  game.t = CONFIG.runTime - 0.05;
  update(game, 0.1, idle);
  assert.equal(game.state, 'lost');
  assert.equal(game.endReason, 'time');
});

test('losing all HP loses the run', () => {
  const game = createGame({ seed: 2 });
  game.ship.hp = 0.1;
  game.ship.y = -3000; game.ship.x = 0;
  const e = createEnemy('armored', 3, 40, -3000);
  game.enemies.push(e);
  for (let i = 0; i < 20 && game.state === 'play'; i++) update(game, 0.05, idle);
  assert.equal(game.state, 'lost');
  assert.equal(game.endReason, 'hp');
});

test('reaching the old escape speed no longer clears the game', () => {
  const game = createGame({ seed: 2 });
  game.spawning = false;
  game.ship.vx = CONFIG.escapeSpeed + 10;
  update(game, 0.02, idle);
  assert.equal(game.state, 'play');
});

test('kills drop xp that is collected and levels up', () => {
  const game = createGame({ seed: 2 });
  game.spawning = false;
  for (let i = 0; i < 30; i++) {
    const e = createEnemy('drifter', 1, game.ship.x + 20, game.ship.y);
    game.enemies.push(e);
    killEnemy(game, e);
  }
  for (let i = 0; i < 20; i++) update(game, 0.05, idle);
  assert.ok(game.level >= 1, `level ${game.level}`);
  assert.ok(game.events.length >= 0);
});

test('a full 10 minute run simulates without errors or NaN', () => {
  const game = createGame({ seed: 11 });
  game.debug.invincible = true;
  game.debug.autoOffer = 'discard';
  let maxEnemies = 0, t = 0;
  while (game.state === 'play' && t < CONFIG.runTime + 5) {
    const k = Math.floor(t / 0.8);
    const charging = t % 0.8 < 0.7;
    const a = k * 2.399;
    update(game, 0.1, { charging, aimX: Math.cos(a) * 100, aimY: Math.sin(a) * 100, release: !charging && (t % 0.8) < 0.8 - 0.05 });
    if (game.state === 'offer') game.state = 'play';
    game.events.length = 0;
    maxEnemies = Math.max(maxEnemies, game.enemies.length);
    t += 0.1;
  }
  assert.ok(Number.isFinite(game.ship.x) && Number.isFinite(game.ship.y));
  assert.ok(maxEnemies < 450 * CONFIG.densityMult, `max enemies ${maxEnemies}`);
  assert.ok(game.kills > 50, `kills ${game.kills}`);
});
