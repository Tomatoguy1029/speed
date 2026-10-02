import { test } from 'node:test';
import assert from 'node:assert/strict';
import { META_UPGRADES, metaCost, buyUpgrade, defaultSave, loadSave, writeSave, applyRunResult } from '../src/progression.js';
import { createGame, update } from '../src/world.js';
import { createEnemy } from '../src/enemies.js';
import { killEnemy } from '../src/hits.js';

function memStorage(init = {}) {
  const m = new Map(Object.entries(init));
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)) };
}

test('upgrade cost rises per level and stops at max', () => {
  const u = META_UPGRADES[0];
  assert.ok(metaCost(u.id, 1) > metaCost(u.id, 0));
  assert.equal(metaCost(u.id, u.max), null);
});

test('buying spends coins and raises the level', () => {
  const save = defaultSave();
  const id = META_UPGRADES[0].id;
  assert.equal(buyUpgrade(save, id), false);
  save.coins = 1000;
  assert.equal(buyUpgrade(save, id), true);
  assert.equal(save.meta[id], 1);
  assert.equal(save.coins, 1000 - metaCost(id, 0));
});

test('corrupt saves fall back to defaults; good saves round-trip', () => {
  assert.deepEqual(loadSave(memStorage({ 'speed-save-v1': '{not json' })), defaultSave());
  assert.deepEqual(loadSave(memStorage()), defaultSave());
  const st = memStorage();
  const save = defaultSave();
  save.coins = 42; save.meta.speed = 2;
  writeSave(st, save);
  assert.deepEqual(loadSave(st), save);
});

test('run results bank coins and records, win or lose', () => {
  const save = defaultSave();
  applyRunResult(save, { coins: 30, peakSpeed: 1500, state: 'lost', t: 600 });
  assert.equal(save.coins, 30);
  assert.equal(save.best.runs, 1);
  applyRunResult(save, { coins: 10, peakSpeed: 2500, state: 'won', t: 540 });
  assert.ok(save.coins >= 40);
  assert.equal(save.best.escapes, 1);
  assert.equal(save.best.escapeTime, 540);
  assert.equal(save.best.topSpeed, 2500);
});

test("meta upgrades raise the next run's base stats", () => {
  const plain = createGame({ seed: 1 });
  const up = createGame({ seed: 1, meta: { hp: 2, speed: 3 } });
  assert.ok(up.stats.maxHp > plain.stats.maxHp);
  assert.ok(up.stats.maxSpeed > plain.stats.maxSpeed);
});

test('meteors drop coins that get collected', () => {
  const game = createGame({ seed: 1 });
  game.spawning = false;
  for (let i = 0; i < 20; i++) {
    const m = createEnemy('meteor', 1, game.ship.x + 10, game.ship.y, { size: 50 });
    game.enemies.push(m);
    killEnemy(game, m);
  }
  for (let i = 0; i < 20; i++) update(game, 0.05, { charging: false, aimX: 0, aimY: 0, release: false });
  assert.ok(game.coins > 0);
});
