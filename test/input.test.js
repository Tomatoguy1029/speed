import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createInput, moveVector } from '../src/input.js';
import { createGame, update } from '../src/world.js';
import { CONFIG } from '../src/config.js';

function fakeTarget() {
  const h = {};
  return {
    addEventListener: (type, fn) => { (h[type] ||= []).push(fn); },
    fire: (type, props = {}) => { for (const fn of h[type] || []) fn({ preventDefault() {}, ...props }); },
  };
}

const press = (win, code, key) => win.fire('keydown', { code, key });
const lift = (win, code, key) => win.fire('keyup', { code, key });

test('WASD and arrows make a unit move vector; opposite keys cancel', () => {
  assert.deepEqual(moveVector(new Set(['KeyW'])), { x: 0, y: -1 });
  assert.deepEqual(moveVector(new Set(['ArrowRight'])), { x: 1, y: 0 });
  const d = moveVector(new Set(['KeyS', 'KeyA']));
  assert.ok(d.x < 0 && d.y > 0 && Math.abs(Math.hypot(d.x, d.y) - 1) < 1e-9);
  assert.deepEqual(moveVector(new Set(['KeyA', 'KeyD'])), { x: 0, y: 0 });
});

test('held keys show up in read(); Space charges and releases as a keyboard launch', () => {
  const win = fakeTarget();
  const input = createInput(fakeTarget(), win);
  press(win, 'KeyD', 'd');
  assert.deepEqual(input.read().move, { x: 1, y: 0 });
  press(win, 'Space', ' ');
  let r = input.read();
  assert.equal(r.charging, true);
  assert.equal(r.keyboard, true);
  win.fire('keydown', { code: 'Space', key: ' ', repeat: true });
  assert.equal(input.read().charging, true);
  lift(win, 'Space', ' ');
  r = input.read();
  assert.equal(r.release, true);
  assert.equal(r.keyboard, true);
  assert.equal(input.read().release, false, 'release is consumed once');
  lift(win, 'KeyD', 'd');
  assert.deepEqual(input.read().move, { x: 0, y: 0 });
});

test('reset drops a held Space so no stray launch happens after a menu', () => {
  const win = fakeTarget();
  const input = createInput(fakeTarget(), win);
  press(win, 'Space', ' ');
  input.reset();
  lift(win, 'Space', ' ');
  const r = input.read();
  assert.equal(r.charging, false);
  assert.equal(r.release, false);
});

// ---- ship-relative WASD in the world ----

const none = { x: 0, y: 0 };
const W = { x: 0, y: -1 }, S = { x: 0, y: 1 }, A = { x: -1, y: 0 }, D = { x: 1, y: 0 };
const idle = { charging: false, aimX: 0, aimY: 0, release: false, keyboard: false, move: none };

function quiet() {
  const game = createGame({ seed: 1 });
  game.spawning = false;
  game.field.planet.gm = 0; game.field.moons.length = 0; game.field.dust.length = 0;
  game.ship.x = 0; game.ship.y = -3000; game.ship.vx = 0; game.ship.vy = 0;
  game.ship.hx = 0; game.ship.hy = -1; // facing up the screen
  return game;
}

const run = (game, move, n = 10, dt = 0.1) => { for (let i = 0; i < n; i++) update(game, dt, { ...idle, move }); };
const heading = (game) => Math.atan2(game.ship.hy, game.ship.hx);

test('W pushes the ship forward a little from rest', () => {
  const game = quiet();
  run(game, W, 5);
  assert.ok(game.ship.vy < -50, 'moved forward (up)');
  assert.ok(Math.hypot(game.ship.vx, game.ship.vy) < game.stats.maxSpeed * CONFIG.nudgeMaxSpeed + 1, 'only slightly');
});

test('D bends toward the ship\'s right, whichever way it is flying', () => {
  const up = quiet();
  up.ship.vy = -1200; up.ship.boostT = 99;
  run(up, D);
  assert.ok(up.ship.vx > 300, 'flying up, right is +x');
  const down = quiet();
  down.ship.vy = 1200; down.ship.hy = 1; down.ship.boostT = 99;
  run(down, D);
  assert.ok(down.ship.vx < -300, 'flying down, right is -x');
  assert.ok(Math.hypot(down.ship.vx, down.ship.vy) < 1250, 'bending does not speed up');
});

test('W at speed gives no free acceleration', () => {
  const game = quiet();
  game.ship.vy = -900; game.ship.boostT = 99;
  run(game, W);
  assert.ok(Math.hypot(game.ship.vx, game.ship.vy) <= 901);
});

test('S brakes but never reverses', () => {
  const game = quiet();
  game.ship.vy = -600; game.ship.boostT = 99;
  run(game, S, 30);
  assert.ok(game.ship.vy <= 0.001, 'did not go backwards');
  assert.ok(Math.hypot(game.ship.vx, game.ship.vy) < 50, 'came to a stop');
  assert.ok(Math.abs(heading(game) + Math.PI / 2) < 1e-6, 'still facing up');
});

test('when nearly still, A/D turn the ship in place', () => {
  const game = quiet();
  run(game, D, 3);
  assert.ok(heading(game) > -Math.PI / 2 + 0.3, 'turned clockwise (right)');
  assert.ok(Math.hypot(game.ship.vx, game.ship.vy) < 5, 'stayed put');
});

test('a keyboard launch boosts along the current travel direction', () => {
  const game = quiet();
  game.ship.vx = 300; game.ship.vy = 300;
  for (let i = 0; i < 8; i++) update(game, 0.1, { ...idle, charging: true, keyboard: true });
  const ang0 = Math.atan2(game.ship.vy, game.ship.vx);
  update(game, 0.02, { ...idle, release: true, keyboard: true });
  const sp = Math.hypot(game.ship.vx, game.ship.vy);
  assert.ok(sp > 700);
  assert.ok(Math.abs(Math.atan2(game.ship.vy, game.ship.vx) - ang0) < 0.05);
});

test('from a standstill a keyboard launch goes where the ship was turned', () => {
  const game = quiet();
  run(game, D, 2, 0.1);
  const h = heading(game);
  for (let i = 0; i < 5; i++) update(game, 0.1, { ...idle, charging: true, keyboard: true });
  update(game, 0.02, { ...idle, release: true, keyboard: true });
  assert.ok(Math.abs(Math.atan2(game.ship.vy, game.ship.vx) - h) < 0.05);
  assert.ok(Math.hypot(game.ship.vx, game.ship.vy) > 300);
});
