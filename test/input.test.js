import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createInput } from '../src/input.js';
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

test('A/D and arrows report a turn direction; both cancel', () => {
  const win = fakeTarget();
  const input = createInput(fakeTarget(), win);
  press(win, 'KeyA', 'a');
  assert.equal(input.read().turn, -1);
  press(win, 'KeyD', 'd');
  assert.equal(input.read().turn, 0);
  lift(win, 'KeyA', 'a');
  assert.equal(input.read().turn, 1);
  lift(win, 'KeyD', 'd');
  press(win, 'ArrowLeft', 'ArrowLeft');
  assert.equal(input.read().turn, -1);
});

test('W and S request a snap once per press', () => {
  const win = fakeTarget();
  const input = createInput(fakeTarget(), win);
  press(win, 'KeyW', 'w');
  assert.equal(input.read().snap, 'forward');
  assert.equal(input.read().snap, null);
  press(win, 'KeyS', 's');
  assert.equal(input.read().snap, 'back');
});

test('Space charges and releases as a keyboard launch', () => {
  const win = fakeTarget();
  const input = createInput(fakeTarget(), win);
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

// ---- aim rotation in the world ----

const idle = { charging: false, aimX: 0, aimY: 0, release: false, keyboard: false, turn: 0, snap: null };

function quiet() {
  const game = createGame({ seed: 1 });
  game.spawning = false;
  game.field.planet.gm = 0; game.field.moons.length = 0; game.field.dust.length = 0;
  game.ship.x = 0; game.ship.y = -3000; game.ship.vx = 0; game.ship.vy = 0;
  game.ship.aimAngle = 0;
  return game;
}

test('holding a turn key rotates the aim, faster the longer it is held', () => {
  const game = quiet();
  update(game, 0.05, { ...idle, turn: 1 });
  const first = game.ship.aimAngle;
  assert.ok(first > 0);
  for (let i = 0; i < 10; i++) update(game, 0.05, { ...idle, turn: 1 });
  const a0 = game.ship.aimAngle;
  update(game, 0.05, { ...idle, turn: 1 });
  assert.ok(game.ship.aimAngle - a0 > first * 1.5, 'accelerated');
  const b = game.ship.aimAngle;
  update(game, 0.05, { ...idle, turn: -1 });
  assert.ok(game.ship.aimAngle < b, 'turns back');
});

test('keyboard launch goes along the aim angle', () => {
  const game = quiet();
  game.ship.aimAngle = Math.PI / 2; // down the screen
  for (let i = 0; i < 8; i++) update(game, 0.1, { ...idle, charging: true, keyboard: true });
  assert.ok(game.ship.charging);
  update(game, 0.02, { ...idle, release: true, keyboard: true });
  assert.ok(game.ship.vy > CONFIG.baseMaxSpeed * 0.5);
  assert.ok(Math.abs(game.ship.vx) < 1);
});

test('snap forward aligns the aim with the travel direction; back flips it', () => {
  const game = quiet();
  game.ship.vx = -300; game.ship.vy = 0;
  update(game, 0.02, { ...idle, snap: 'forward' });
  assert.ok(Math.abs(Math.cos(game.ship.aimAngle) + 1) < 1e-6);
  update(game, 0.02, { ...idle, snap: 'back' });
  assert.ok(Math.abs(Math.cos(game.ship.aimAngle) - 1) < 1e-6);
});

test('a mouse launch also points the keyboard aim that way', () => {
  const game = quiet();
  for (let i = 0; i < 5; i++) update(game, 0.1, { ...idle, charging: true, aimX: 0, aimY: -100 });
  update(game, 0.02, { ...idle, release: true, aimX: 0, aimY: -100 });
  assert.ok(Math.abs(Math.sin(game.ship.aimAngle) + 1) < 1e-6);
});
