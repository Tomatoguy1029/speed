import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createGame, update } from '../src/world.js';
import { createEnemy } from '../src/enemies.js';
import { updateSpawner, phaseTarget } from '../src/spawner.js';
import { damageEnemy } from '../src/hits.js';
import { CONFIG } from '../src/config.js';

test('one boss appears on time, stays when left off screen, and its defeat clears the run', () => {
  const game = createGame({ seed: 18, scheme: 'draw' });
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
