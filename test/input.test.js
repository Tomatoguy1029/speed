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

// ---- absolute WASD steering in the world ----

const none = { x: 0, y: 0 };
const UP = { x: 0, y: -1 }, DOWN = { x: 0, y: 1 }, RIGHT = { x: 1, y: 0 }, LEFT = { x: -1, y: 0 };
const idle = { charging: false, aimX: 0, aimY: 0, release: false, keyboard: false, move: none };

function quiet() {
  const game = createGame({ seed: 1 });
  game.spawning = false;
  game.field.planet.gm = 0; game.field.moons.length = 0; game.field.dust.length = 0;
  game.ship.x = 0; game.ship.y = -3000; game.ship.vx = 0; game.ship.vy = 0;
  return game;
}

const run = (game, move, seconds, dt = 0.05) => { for (let t = 0; t < seconds - 1e-9; t += dt) update(game, dt, { ...idle, move }); };
const speed = (game) => Math.hypot(game.ship.vx, game.ship.vy);

test('from rest, a direction key gets the ship moving that way (screen-absolute)', () => {
  const game = quiet();
  run(game, RIGHT, 0.5);
  assert.ok(game.ship.vx > 100 && Math.abs(game.ship.vy) < 1);
  assert.ok(speed(game) <= game.stats.maxSpeed * CONFIG.steerCruise + 1, 'keys alone only reach cruise speed');
});

test('holding a direction swings a fast ship toward it quickly, keeping its speed', () => {
  const game = quiet();
  game.ship.vy = -1200; game.ship.boostT = 99;
  run(game, RIGHT, 0.4);
  const ang = Math.atan2(game.ship.vx, -game.ship.vy); // 0 = up, PI/2 = right
  assert.ok(ang > 1.4, `turned ${ang.toFixed(2)} rad`);
  assert.ok(Math.abs(speed(game) - 1200) < 60, `speed ${speed(game)}`);
});

test('holding the opposite direction turns the ship around', () => {
  const game = quiet();
  game.ship.vy = -1000; game.ship.boostT = 99;
  run(game, DOWN, 1);
  assert.ok(game.ship.vy > 900, `vy ${game.ship.vy}`);
});

test('the same key means the same screen direction whichever way the ship flies', () => {
  const a = quiet(); a.ship.vy = -800; a.ship.boostT = 99;
  const b = quiet(); b.ship.vy = 800; b.ship.boostT = 99;
  run(a, LEFT, 1); run(b, LEFT, 1);
  assert.ok(a.ship.vx < -700 && b.ship.vx < -700);
});

test('no keys, no steering', () => {
  const game = quiet();
  game.ship.vx = 500; game.ship.boostT = 99;
  run(game, none, 0.5);
  assert.ok(Math.abs(game.ship.vy) < 1 && Math.abs(game.ship.vx - 500) < 1);
});

test('a keyboard launch boosts along the current travel direction', () => {
  const game = quiet();
  game.ship.vx = 300; game.ship.vy = 300;
  for (let i = 0; i < 8; i++) update(game, 0.1, { ...idle, charging: true, keyboard: true });
  const ang0 = Math.atan2(game.ship.vy, game.ship.vx);
  update(game, 0.02, { ...idle, release: true, keyboard: true });
  assert.ok(speed(game) > 700);
  assert.ok(Math.abs(Math.atan2(game.ship.vy, game.ship.vx) - ang0) < 0.05);
});

test('from a standstill a keyboard launch goes the way the keys last pointed', () => {
  const game = quiet();
  update(game, 0.02, { ...idle, move: LEFT });
  game.ship.vx = 0; game.ship.vy = 0;
  for (let i = 0; i < 5; i++) update(game, 0.1, { ...idle, charging: true, keyboard: true });
  update(game, 0.02, { ...idle, release: true, keyboard: true });
  assert.ok(game.ship.vx < -300 && Math.abs(game.ship.vy) < 1);
});
