import { test } from 'node:test';
import assert from 'node:assert/strict';
import { targetZoom } from '../src/render.js';
import { createGame } from '../src/world.js';

test('camera zoom follows max speed, not the current speed', () => {
  const game = createGame({ seed: 1 });
  game.ship.vx = 0; game.ship.vy = 0;
  const still = targetZoom(game, 1200, 800);
  game.ship.vx = 2000;
  assert.equal(targetZoom(game, 1200, 800), still);
  game.stats.maxSpeed *= 2;
  assert.ok(targetZoom(game, 1200, 800) < still, 'pulls back as max speed grows');
});
