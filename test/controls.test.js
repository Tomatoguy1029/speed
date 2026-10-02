import { test } from 'node:test';
import assert from 'node:assert/strict';
import { SCHEMES, buildIntent } from '../src/controls.js';
import { createGame, update } from '../src/world.js';
import { CONFIG } from '../src/config.js';

const none = { x: 0, y: 0 };
const UP = { x: 0, y: -1 }, DOWN = { x: 0, y: 1 }, RIGHT = { x: 1, y: 0 }, LEFT = { x: -1, y: 0 };
const raw = (o = {}) => ({ move: none, snap: null, space: false, pointerDown: false, drag: none, hover: null, cursor: null, release: false, releaseSource: null, releaseDrag: none, ...o });
const idle = { charging: false, aimX: 0, aimY: 0, release: false, keyboard: false, move: none, snap: null, cursor: null };

function quiet(scheme) {
  const game = createGame({ seed: 1, scheme });
  game.spawning = false;
  game.field.planet.gm = 0; game.field.moons.length = 0; game.field.dust.length = 0;
  game.ship.x = 0; game.ship.y = -3000; game.ship.vx = 0; game.ship.vy = 0;
  game.ship.hx = 0; game.ship.hy = -1;
  game.stats.maxSpeed = 1000; // scheme behavior should not depend on speed tuning
  return game;
}
const run = (game, intent, seconds, dt = 0.05) => { for (let t = 0; t < seconds - 1e-9; t += dt) update(game, dt, { ...idle, ...intent }); };
const speed = (game) => Math.hypot(game.ship.vx, game.ship.vy);
const travel = (game) => Math.atan2(game.ship.vy, game.ship.vx);
function chargeAndRelease(game, intent = {}) {
  for (let i = 0; i < 8; i++) update(game, 0.1, { ...idle, ...intent, charging: true, keyboard: true });
  update(game, 0.02, { ...idle, ...intent, release: true, keyboard: true });
}

test('every scheme has a name and help text; mouse steering is the default', () => {
  assert.ok(SCHEMES.length >= 7);
  for (const s of SCHEMES) assert.ok(s.id && s.name && s.help, s.id);
  assert.equal(CONFIG.controlScheme, 'mouse');
  assert.equal(createGame({ seed: 1 }).scheme, 'mouse');
});

// ---- intents per scheme ----

test('mouse scheme: Space or a click charges, aim comes from the cursor', () => {
  let i = buildIntent(raw({ space: true }), 'mouse');
  assert.equal(i.charging, true); assert.equal(i.keyboard, true);
  i = buildIntent(raw({ pointerDown: true, drag: { x: 50, y: 0 } }), 'mouse');
  assert.equal(i.charging, true); assert.equal(i.keyboard, true, 'a click is a plain charge, not a drag');
  i = buildIntent(raw({ release: true, releaseSource: 'pointer', releaseDrag: { x: 50, y: 0 } }), 'mouse');
  assert.equal(i.release, true); assert.equal(i.keyboard, true);
});

test('drag scheme: only the pull counts, Space is ignored', () => {
  let i = buildIntent(raw({ space: true }), 'drag');
  assert.equal(i.charging, false);
  i = buildIntent(raw({ pointerDown: true, drag: { x: 30, y: 40 } }), 'drag');
  assert.equal(i.charging, true); assert.equal(i.keyboard, false); assert.equal(i.aimX, 30);
});

test('keyboard schemes: Space charges with the scheme aim, a mouse drag still works', () => {
  for (const id of ['steer', 'relative', 'nudge', 'rotate', 'aim8']) {
    let i = buildIntent(raw({ space: true, move: RIGHT }), id);
    assert.equal(i.charging, true); assert.equal(i.keyboard, true, id);
    i = buildIntent(raw({ pointerDown: true, drag: { x: 0, y: -80 } }), id);
    assert.equal(i.keyboard, false, id); assert.equal(i.aimY, -80, id);
  }
});

// ---- mouse: go where the cursor is ----

test('mouse scheme steers toward the cursor and dashes at it', () => {
  const game = quiet('mouse');
  game.ship.vy = -900; game.ship.boostT = 99;
  const cursor = { x: 2000, y: -3000 }; // far to the right
  run(game, { cursor }, 0.4);
  assert.ok(Math.abs(travel(game)) < 0.2, `heading right, got ${travel(game).toFixed(2)}`);
  assert.ok(Math.abs(speed(game) - 900) < 60);
  const g2 = quiet('mouse');
  chargeAndRelease(g2, { cursor: { x: 0, y: -1000 } }); // straight down the screen
  assert.ok(g2.ship.vy > 600 && Math.abs(g2.ship.vx) < 5);
});

test('mouse scheme ignores a cursor sitting on the ship', () => {
  const game = quiet('mouse');
  game.ship.vx = 500; game.ship.boostT = 99;
  // the cursor is screen-fixed and the camera follows the ship, so it stays on top of the ship
  for (let i = 0; i < 2; i++) update(game, 0.05, { ...idle, cursor: { x: game.ship.x + 3, y: game.ship.y + 3 } });
  assert.ok(Math.abs(game.ship.vy) < 5);
});

// ---- steer: WASD swings the travel direction (screen-absolute) ----

test('steer scheme: a key swings a fast ship toward that screen direction', () => {
  const game = quiet('steer');
  game.ship.vy = -1200; game.ship.boostT = 99;
  run(game, { move: RIGHT }, 0.4);
  assert.ok(Math.abs(travel(game)) < 0.2);
  assert.ok(Math.abs(speed(game) - 1200) < 60);
  const g2 = quiet('steer');
  run(g2, { move: LEFT }, 0.5);
  assert.ok(g2.ship.vx < -100, 'gets moving from rest');
  assert.ok(speed(g2) <= g2.stats.maxSpeed * CONFIG.steerCruise + 1);
});

test('steer scheme: Space boosts along the travel direction', () => {
  const game = quiet('steer');
  game.ship.vx = 300; game.ship.vy = 300;
  const a0 = travel(game);
  chargeAndRelease(game);
  assert.ok(speed(game) > 700 && Math.abs(travel(game) - a0) < 0.05);
});

// ---- relative: W forward, S brake, A/D bend or pivot ----

test('relative scheme: D bends to the ship\'s right whichever way it flies', () => {
  const down = quiet('relative');
  down.ship.vy = 1200; down.ship.hy = 1; down.ship.boostT = 99;
  run(down, { move: RIGHT }, 1);
  assert.ok(down.ship.vx < -300);
});

test('relative scheme: S brakes without reversing; A/D pivot when still', () => {
  const game = quiet('relative');
  game.ship.vy = -600; game.ship.boostT = 99;
  run(game, { move: DOWN }, 1.5);
  assert.ok(game.ship.vy <= 0.001 && speed(game) < 50);
  const still = quiet('relative');
  run(still, { move: RIGHT }, 0.3);
  assert.ok(Math.atan2(still.ship.hy, still.ship.hx) > -Math.PI / 2 + 0.3);
  assert.ok(speed(still) < 5);
});

// ---- nudge: small screen-absolute thrust ----

test('nudge scheme: slight push from rest, no free speed when fast', () => {
  const game = quiet('nudge');
  run(game, { move: RIGHT }, 0.5);
  assert.ok(game.ship.vx > 50 && speed(game) < game.stats.maxSpeed * CONFIG.nudgeMaxSpeed + 1);
  const fast = quiet('nudge');
  fast.ship.vy = -900; fast.ship.boostT = 99;
  run(fast, { move: UP }, 1);
  assert.ok(speed(fast) <= 901);
});

// ---- rotate: A/D turn the aim, W/S snap ----

test('rotate scheme: A/D turn the aim (faster when held), W/S snap, launch follows the aim', () => {
  const game = quiet('rotate');
  game.ship.aimAngle = 0;
  run(game, { move: RIGHT }, 0.05);
  const first = game.ship.aimAngle;
  assert.ok(first > 0);
  run(game, { move: RIGHT }, 0.5);
  const a0 = game.ship.aimAngle;
  run(game, { move: RIGHT }, 0.05);
  assert.ok(game.ship.aimAngle - a0 > first * 1.5, 'accelerates');
  game.ship.vx = -300; game.ship.vy = 0;
  run(game, { snap: 'forward' }, 0.02);
  assert.ok(Math.abs(Math.cos(game.ship.aimAngle) + 1) < 1e-6);
  run(game, { snap: 'back' }, 0.02);
  assert.ok(Math.abs(Math.cos(game.ship.aimAngle) - 1) < 1e-6);
  const g2 = quiet('rotate');
  g2.ship.aimAngle = Math.PI / 2;
  chargeAndRelease(g2);
  assert.ok(g2.ship.vy > 500 && Math.abs(g2.ship.vx) < 1);
});

// ---- aim8: WASD picks one of eight launch directions ----

test('aim8 scheme: launch toward the held key direction, or along travel with none', () => {
  const game = quiet('aim8');
  chargeAndRelease(game, { move: LEFT });
  assert.ok(game.ship.vx < -500 && Math.abs(game.ship.vy) < 1);
  const g2 = quiet('aim8');
  g2.ship.vx = 0; g2.ship.vy = 400;
  chargeAndRelease(g2);
  assert.ok(g2.ship.vy > 600);
});

// ---- drag: classic slingshot ----

test('drag launches opposite the pull in any scheme', () => {
  for (const id of ['drag', 'steer', 'mouse']) {
    const game = quiet(id);
    for (let i = 0; i < 5; i++) update(game, 0.1, { ...idle, charging: true, aimX: 0, aimY: -100 });
    update(game, 0.02, { ...idle, release: true, aimX: 0, aimY: -100 });
    assert.ok(game.ship.vy < -400, id);
  }
});
