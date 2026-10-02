import { test } from 'node:test';
import assert from 'node:assert/strict';
import { baseStats, createShip, computeGauge, launchVelocity, stepShip } from '../src/ship.js';
import { aimFromDrag } from '../src/input.js';
import { createGame, update } from '../src/world.js';

const stats = baseStats();

test('gauge grows with hold time and caps at gaugeMax', () => {
  const g1 = computeGauge(stats.chargeTime * 0.5, stats);
  const g2 = computeGauge(stats.chargeTime, stats);
  const g3 = computeGauge(stats.chargeTime * 5, stats);
  assert.ok(g1 > 0.4 && g1 < 0.6);
  assert.ok(Math.abs(g2 - 1) < 1e-9);
  assert.equal(g3, stats.gaugeMax);
});

test('launch goes opposite to the drag', () => {
  const aim = aimFromDrag(100, 100, 60, 130); // dragged left-down
  assert.ok(aim.x > 0 && aim.y < 0);
});

test('chained launches in the same direction stack up to max speed', () => {
  let v = launchVelocity(0, 0, 1, 0, 1, stats);
  const first = Math.hypot(v.vx, v.vy);
  assert.ok(first < stats.maxSpeed);
  v = launchVelocity(v.vx, v.vy, 1, 0, 1, stats);
  const second = Math.hypot(v.vx, v.vy);
  assert.ok(second > first);
  v = launchVelocity(v.vx, v.vy, 1, 0, 1, stats);
  assert.ok(Math.hypot(v.vx, v.vy) <= stats.maxSpeed + 1e-6);
});

test('reversing direction does not carry momentum', () => {
  const v = launchVelocity(800, 0, -1, 0, 1, stats);
  assert.ok(v.vx < 0);
  assert.ok(Math.abs(Math.hypot(v.vx, v.vy) - stats.maxSpeed * stats.launchRatio) < 1e-6);
});

test('ship keeps drifting by inertia', () => {
  const ship = createShip(stats, 0, 0);
  ship.vx = 300;
  stepShip(ship, stats, 0.1, 0, 0, 0);
  assert.ok(ship.x > 25);
});

test('after boost ends, cruise drag slows slightly but not below floor', () => {
  const ship = createShip(stats, 0, 0);
  ship.vx = stats.maxSpeed;
  ship.boostT = 0;
  for (let i = 0; i < 1200; i++) stepShip(ship, stats, 1 / 120, 0, 0, 0);
  const sp = Math.hypot(ship.vx, ship.vy);
  assert.ok(sp < stats.maxSpeed * 0.9);
  assert.ok(sp >= stats.maxSpeed * stats.cruiseFloor - 1);
});

test('speed above cap decays toward cap', () => {
  const ship = createShip(stats, 0, 0);
  ship.vx = stats.maxSpeed * 1.5;
  ship.boostT = 10;
  for (let i = 0; i < 240; i++) stepShip(ship, stats, 1 / 120, 0, 0, 0);
  const sp = Math.hypot(ship.vx, ship.vy);
  assert.ok(sp < stats.maxSpeed * 1.5 && sp > stats.maxSpeed);
});

test('world: holding then releasing launches the ship and keeps moving while charging', () => {
  const game = createGame({ seed: 1 });
  const s = game.ship;
  s.vx = 200; s.vy = 0;
  const x0 = s.x;
  for (let i = 0; i < 3; i++) update(game, 0.1, { charging: true, aimX: 0, aimY: -100, release: false });
  assert.ok(s.charging);
  assert.ok(s.x > x0 + 30, 'moved while charging');
  update(game, 0.02, { charging: false, aimX: 0, aimY: -100, release: true });
  assert.ok(!s.charging);
  assert.ok(s.vy < -100, 'launched upward');
});
