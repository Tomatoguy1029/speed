import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createGame, update, separateEnemies } from '../src/world.js';
import { createEnemy } from '../src/enemies.js';
import { updateSpawner, phaseTarget } from '../src/spawner.js';
import { damageEnemy } from '../src/hits.js';
import { CONFIG } from '../src/config.js';

test('one boss appears on time, stays when left off screen, and its defeat clears the run', () => {
  const game = createGame({ seed: 18, scheme: 'hyper' });
  game.t = CONFIG.bossTime - 1;
  updateSpawner(game, 0.02);
  assert.equal(game.boss, null);
  game.t = CONFIG.bossTime;
  updateSpawner(game, 0.02);
  const boss = game.boss;
  assert.ok(boss && boss.hp === CONFIG.bossHp);
  for (let i = 0; i < 20; i++) updateSpawner(game, 0.1);
  assert.equal(game.enemies.filter((e) => e.type === 'boss').length, 1);
  assert.ok(game.enemies.length > 1, 'ordinary enemies continue spawning');
  boss.x = 20000;
  updateSpawner(game, 0.1);
  assert.ok(!boss.dead && game.enemies.includes(boss));
  damageEnemy(game, boss, boss.hp, { cause: 'wave' });
  game.spawning = false;
  update(game, 0.02, { charging: false });
  assert.equal(game.state, 'finishing');
  for (let i = 0; i < 100 && game.state === 'finishing'; i++) update(game, 0.05, {});
  assert.equal(game.state, 'won');
  assert.equal(game.endReason, 'boss');
});

test('population and replenishment both scale to five times the old density', () => {
  assert.equal(CONFIG.densityMult, 5);
  const game = createGame({ seed: 12 });
  assert.equal(phaseTarget(0).pop, 70);
  for (let i = 0; i < 20; i++) updateSpawner(game, 0.1);
  assert.ok(game.enemies.filter((e) => e.type !== 'meteor').length >= 55);
  game.t = 330;
  for (let i = 0; i < 300; i++) updateSpawner(game, 0.1);
  assert.ok(game.enemies.filter((e) => e.type !== 'meteor').length <= Math.ceil(phaseTarget(330).pop));
});

test('coincident enemies and large neighboring bodies separate instead of remaining stacked', () => {
  const game = createGame({ seed: 12 });
  for (let i = 0; i < 30; i++) game.enemies.push(createEnemy('drifter', 1, 0, -3000));
  for (let i = 0; i < 100; i++) separateEnemies(game);
  let minDistance = Infinity;
  for (let i = 0; i < game.enemies.length; i++) {
    const a = game.enemies[i];
    assert.ok(Number.isFinite(a.x) && Number.isFinite(a.y));
    for (let j = i + 1; j < game.enemies.length; j++) {
      const b = game.enemies[j];
      minDistance = Math.min(minDistance, Math.hypot(a.x - b.x, a.y - b.y));
    }
  }
  assert.ok(minDistance >= 28, `minimum distance ${minDistance}`);
  const small = createEnemy('drifter', 1, 0, -3000);
  const large = createEnemy('boss', 1, 140, -3000);
  game.enemies = [small, large];
  separateEnemies(game);
  assert.ok(Math.hypot(small.x - large.x, small.y - large.y) >= small.r + large.r + CONFIG.enemySpacing - 0.01);
});

test('rear ranks cannot keep driving into enemies after their bodies are separated', () => {
  const game = createGame({ seed: 12 });
  const a = createEnemy('armored', 1, 0, -3000);
  const b = createEnemy('armored', 1, 45, -3000);
  a.vx = 70; b.vx = -70;
  a.vy = b.vy = 25;
  game.enemies = [a, b];
  separateEnemies(game);
  assert.ok(b.vx - a.vx >= -1e-6, 'closing velocity is removed rather than restored next step');
  assert.equal(a.vy, 25, 'sideways movement remains available');
  assert.equal(b.vy, 25);
});

test('splitter offspring cannot flood the field beyond the population allowance', () => {
  const game = createGame({ seed: 12 });
  game.spawning = false;
  game.debug.invincible = true;
  game.ship.vx = game.ship.vy = 0;
  const count = Math.floor(phaseTarget(0).pop);
  for (let i = 0; i < count; i++) {
    const e = createEnemy('splitter', 1, -3000 + (i % 10) * 100, 500 + Math.floor(i / 10) * 100);
    e.budT = e.T.budInterval;
    game.enemies.push(e);
  }
  update(game, 0.02, {});
  assert.equal(game.enemies.length, Math.ceil(phaseTarget(game.t).pop * (1 + CONFIG.enemySplitOverflow)));
  assert.ok(game.enemies.some(e => e.type === 'splitling'), 'ordinary splitting still produces offspring');
});
