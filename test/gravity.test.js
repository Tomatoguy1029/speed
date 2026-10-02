import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { createField, dangerAt, zoneOf } from '../src/field.js';
import { gravityAt } from '../src/gravity.js';
import { createGame, update, predictPath } from '../src/world.js';

const idle = { charging: false, aimX: 0, aimY: 0, release: false };

test('planet gravity points to center and grows closer in', () => {
  const field = createField(() => 0.5);
  field.moons.length = 0;
  field.planet.gm = CONFIG.gravityTestGM;
  const far = gravityAt(field, 0, 3000, 0);
  const near = gravityAt(field, 0, 1000, 0);
  assert.ok(far.ax < 0 && Math.abs(far.ay) < 1e-6);
  assert.ok(Math.abs(near.ax) > Math.abs(far.ax) * 5);
});

test('a ship left alone falls toward the planet', () => {
  const game = createGame({ seed: 3 });
  game.spawning = false;
  game.field.moons.length = 0;
  game.field.planet.gm = CONFIG.gravityTestGM;
  game.ship.vx = 0; game.ship.vy = 0; // left alone = not moving
  const r0 = Math.hypot(game.ship.x, game.ship.y);
  for (let i = 0; i < 30; i++) update(game, 0.1, idle);
  assert.ok(Math.hypot(game.ship.x, game.ship.y) < r0 - 50);
});

test('skimming the planet pushes speed above the max speed', () => {
  const game = createGame({ seed: 3 });
  game.spawning = false;
  game.field.moons.length = 0;
  game.field.planet.gm = CONFIG.gravityTestGM;
  game.field.dust.length = 0;
  game.ship.x = -3000; game.ship.y = 0;
  game.ship.vx = 800; game.ship.vy = 230; // dives in, swings past ~550 from the center
  let peak = 0;
  for (let i = 0; i < 90; i++) {
    update(game, 0.05, idle);
    peak = Math.max(peak, Math.hypot(game.ship.vx, game.ship.vy));
  }
  assert.ok(peak > game.stats.maxSpeed * 1.15, `peak ${peak}`);
});

test('the field boundary pushes the ship back', () => {
  const game = createGame({ seed: 3 });
  game.spawning = false;
  game.field.moons.length = 0;
  game.ship.x = CONFIG.fieldRadius + 200; game.ship.y = 0;
  game.ship.vx = 600; game.ship.vy = 0; game.ship.boostT = 5;
  for (let i = 0; i < 40; i++) update(game, 0.1, idle);
  assert.ok(Math.hypot(game.ship.x, game.ship.y) < CONFIG.fieldRadius + 600);
  assert.ok(game.ship.vx < 0);
});

test('crashing into the planet bounces and hurts', () => {
  const game = createGame({ seed: 3 });
  game.spawning = false;
  game.field.moons.length = 0;
  game.ship.x = -CONFIG.planetRadius - 60; game.ship.y = 0;
  game.ship.vx = 1200; game.ship.vy = 0;
  const hp0 = game.ship.hp;
  for (let i = 0; i < 3; i++) update(game, 0.05, idle);
  assert.ok(Math.hypot(game.ship.x, game.ship.y) >= CONFIG.planetRadius);
  assert.ok(game.ship.hp < hp0);
});

test('danger is zero in the middle zone and rises toward center and edge', () => {
  assert.equal(dangerAt(CONFIG.startRadius), 0);
  assert.equal(zoneOf(CONFIG.startRadius), 'mid');
  assert.ok(dangerAt(CONFIG.planetRadius + 100) > 0.8);
  assert.ok(dangerAt(CONFIG.fieldRadius - 50) > 0.8);
  assert.equal(zoneOf(800), 'inner');
  assert.equal(zoneOf(5000), 'outer');
});

test('predictPath bends under gravity', () => {
  const game = createGame({ seed: 3 });
  game.spawning = false;
  game.field.moons.length = 0;
  game.field.planet.gm = CONFIG.gravityTestGM;
  const pts = predictPath(game, 0, -1, 1, 1.0);
  assert.ok(pts.length > 10);
  const last = pts[pts.length - 1];
  assert.ok(last.y < game.ship.y - 200, 'moves along launch direction');
  assert.ok(last.x > game.ship.x + 5, 'bent toward the planet');
});

test('by default there is no gravity: a ship left alone stays put', () => {
  const game = createGame({ seed: 3 });
  game.spawning = false;
  game.ship.vx = 0; game.ship.vy = 0;
  const x0 = game.ship.x, y0 = game.ship.y;
  for (let i = 0; i < 30; i++) update(game, 0.1, idle);
  assert.ok(Math.hypot(game.ship.x - x0, game.ship.y - y0) < 1);
});
