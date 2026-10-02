import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { TUNABLES, applyTunable, skipTime, jumpToPhase, resetConfig } from '../src/debug.js';
import { createGame } from '../src/world.js';

test('tunables point at real config keys with sane ranges', () => {
  for (const t of TUNABLES) {
    assert.ok(t.key in CONFIG, t.key);
    assert.ok(t.min < t.max, t.key);
    assert.ok(CONFIG[t.key] >= t.min && CONFIG[t.key] <= t.max, t.key);
  }
});

test('changing base max speed applies to the running game immediately', () => {
  const game = createGame({ seed: 1 });
  applyTunable(game, 'baseMaxSpeed', 1500);
  assert.equal(game.stats.maxSpeed, 1500);
  applyTunable(game, 'planetGM', 1e8);
  assert.equal(game.field.planet.gm, 1e8);
  resetConfig(game);
  assert.equal(CONFIG.baseMaxSpeed, 500);
  assert.equal(game.stats.maxSpeed, 500);
});

test('time skip and phase jump move the run clock', () => {
  const game = createGame({ seed: 1 });
  skipTime(game, 60);
  assert.ok(game.t >= 60);
  jumpToPhase(game, 'rampage');
  assert.equal(Math.floor(game.t), 300);
});
