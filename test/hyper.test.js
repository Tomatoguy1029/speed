import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createGame, update, hyperReach, hyperChargeTime, addHyperCharge } from '../src/world.js';
import { buildIntent } from '../src/controls.js';
import { createEnemy } from '../src/enemies.js';
import { CONFIG } from '../src/config.js';

const idle = { charging: false, release: false, cursor: null };
function hyperGame() {
  const game = createGame({ seed: 3, scheme: 'hyper' });
  game.spawning = false;
  game.field.moons.length = 0;
  game.field.dust.length = 0;
  Object.assign(game.ship, { x: 0, y: -3000, vx: 0, vy: 0 });
  return game;
}
const toggle = (game) => update(game, 0.01, { ...idle, hyperToggle: true });
const click = (game, x, y) => update(game, 0.01, { ...idle, jumpClicks: [{ x, y }] });
function finishJump(game) { for (let i = 0; i < 100 && game.jump; i++) update(game, 0.01, idle); }

test('starts with full charges; Space opens hyperdrive and slows the world, Space again closes it', () => {
  const game = hyperGame();
  assert.equal(game.hyper.charges, CONFIG.hyperMaxCharges);
  toggle(game);
  assert.equal(game.hyper.focus, true);
  update(game, 0.01, idle);
  assert.ok(game.timeScale <= CONFIG.hyperFocusScale + 1e-9);
  toggle(game);
  assert.equal(game.hyper.focus, false);
  update(game, 0.01, idle);
  assert.equal(game.timeScale, 1);
});

test('clicks only jump inside hyperdrive; a jump goes straight to the point, clamped to the reach circle', () => {
  const game = hyperGame();
  click(game, 200, -3000);
  assert.equal(game.jump, null);
  assert.equal(game.hyper.charges, CONFIG.hyperMaxCharges);
  toggle(game);
  click(game, 200, -3000);
  assert.ok(game.jump);
  assert.equal(game.hyper.charges, CONFIG.hyperMaxCharges - 1);
  finishJump(game);
  assert.ok(Math.abs(game.ship.x - 200) < 1 && Math.abs(game.ship.y + 3000) < 1, `${game.ship.x},${game.ship.y}`);
  const far = hyperGame();
  toggle(far);
  click(far, 0, -3000 - 99999);
  finishJump(far);
  assert.ok(Math.abs(far.ship.y - (-3000 - hyperReach(far))) < 1, 'stops at the edge of the circle');
});

test('the ship keeps part of the jump speed, then slows down over time', () => {
  const game = hyperGame();
  toggle(game);
  click(game, 400, -3000);
  const jumpSpeed = game.jump.speed;
  finishJump(game);
  toggle(game);
  const after = Math.hypot(game.ship.vx, game.ship.vy);
  assert.ok(Math.abs(after - jumpSpeed * CONFIG.hyperKeep) < 1, `${after} vs ${jumpSpeed}`);
  for (let i = 0; i < 300; i++) update(game, 0.01, idle);
  assert.ok(Math.hypot(game.ship.vx, game.ship.vy) < after * 0.8);
});

test('jumps chain while charges last, then hyperdrive closes; charges refill over time up to the cap', () => {
  const game = hyperGame();
  toggle(game);
  for (let i = 0; i < CONFIG.hyperMaxCharges; i++) {
    click(game, game.ship.x + 150, game.ship.y);
    finishJump(game);
  }
  assert.equal(game.hyper.charges, 0);
  update(game, 0.01, idle);
  assert.equal(game.hyper.focus, false);
  toggle(game);
  assert.equal(game.hyper.focus, false, 'cannot open with no charges');
  const per = hyperChargeTime(game);
  for (let t = 0; t < per * 1.5; t += 0.05) update(game, 0.05, idle);
  assert.equal(game.hyper.charges, 1);
  for (let t = 0; t < per * 10; t += 0.05) update(game, 0.05, idle);
  assert.equal(game.hyper.charges, CONFIG.hyperMaxCharges);
});

test('clicks made during a jump or in the same frame are not lost; they run in order', () => {
  const game = hyperGame();
  toggle(game);
  update(game, 0.001, { ...idle, jumpClicks: [{ x: 200, y: -3000 }, { x: 200, y: -2800 }] });
  assert.equal(game.hyper.queue.length, 1);
  finishJump(game);
  update(game, 0.01, idle); // the queued jump starts on the next frame
  finishJump(game);
  assert.ok(Math.abs(game.ship.x - 200) < 1 && Math.abs(game.ship.y + 2800) < 1, `${game.ship.x},${game.ship.y}`);
  assert.equal(game.hyper.charges, CONFIG.hyperMaxCharges - 2);
});

test('aiming time is limited: hyperdrive closes by itself and keeps the unused charges', () => {
  const game = hyperGame();
  toggle(game);
  for (let t = 0; t < CONFIG.hyperFocusMax + 0.2; t += 0.05) update(game, 0.05, idle);
  assert.equal(game.hyper.focus, false);
  assert.equal(game.hyper.charges, CONFIG.hyperMaxCharges);
});

test('a jump pierces weak enemies on the line', () => {
  const game = hyperGame();
  const e = createEnemy('drifter', 1, 200, -3000);
  game.enemies.push(e);
  update(game, 0.02, idle); // the spatial grid is rebuilt on a world step
  toggle(game);
  click(game, 400, -3000);
  finishJump(game);
  assert.ok(e.dead);
});

test('controls: Space toggles, a click is a jump target, right click leaves', () => {
  const base = { move: { x: 0, y: 0 }, pointerDown: false, drag: { x: 0, y: 0 }, cursor: null };
  assert.equal(buildIntent({ ...base, dash: true, pressed: true }, 'hyper').hyperToggle, true);
  const c = buildIntent({ ...base, pressed: true, clickCursors: [{ x: 1, y: 2 }, { x: 3, y: 4 }] }, 'hyper');
  assert.deepEqual(c.jumpClicks, [{ x: 1, y: 2 }, { x: 3, y: 4 }]);
  assert.equal(buildIntent({ ...base, confirm: true }, 'hyper').hyperExit, true);
});

test('slipstream: jumps in the same direction speed up step by step (capped); turning resets', () => {
  const game = hyperGame();
  game.stats.streakBoost = 0.15;
  toggle(game);
  const speeds = [];
  for (let i = 0; i < 5; i++) {
    click(game, game.ship.x + 150, game.ship.y);
    speeds.push(game.jump.speed);
    finishJump(game);
  }
  for (let i = 1; i < 5; i++) assert.ok(speeds[i] > speeds[i - 1], speeds.join(','));
  const top = game.stats.maxSpeed * (1 + 0.15 * CONFIG.streakMax);
  assert.ok(speeds[4] <= top + 1e-6, 'never above the cap');
  addHyperCharge(game, 1);
  click(game, game.ship.x, game.ship.y - 150);
  assert.ok(game.jump.speed < speeds[1], 'a new direction starts over');
});

test('hits do not refill jumps in hyperdrive (no endless dashing)', () => {
  const game = hyperGame();
  game.stats.regenGauge = 1;
  for (let i = 0; i < 6; i++) game.enemies.push(createEnemy('drifter', 1, 60 + i * 50, -3000));
  update(game, 0.02, idle);
  toggle(game);
  click(game, 400, -3000);
  finishJump(game);
  assert.ok(game.kills > 0);
  assert.ok(game.hyper.charges < CONFIG.hyperMaxCharges - 0.9 + 0.05, `${game.hyper.charges} ${game.hyper.progress}`);
  assert.ok(game.hyper.progress < 0.05);
});
