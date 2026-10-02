import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { buildIntent } from '../src/controls.js';
import { createGame, update } from '../src/world.js';
import { createEnemy } from '../src/enemies.js';

const none = { x: 0, y: 0 };
const OY = -3000;
const idle = { charging: false, aimX: 0, aimY: 0, release: false, keyboard: true, press: false, move: none, snap: null, cursor: null };

function quiet() {
  const game = createGame({ seed: 1, scheme: 'draw' });
  game.spawning = false;
  game.field.planet.gm = 0; game.field.moons.length = 0; game.field.dust.length = 0;
  game.ship.x = 0; game.ship.y = OY; game.ship.vx = 0; game.ship.vy = 0;
  return game;
}

function charge(game, seconds, cursor) {
  for (let t = 0; t < seconds - 1e-9; t += 0.05) update(game, 0.05, { ...idle, charging: true, cursor });
  update(game, 0.02, { ...idle, release: true, cursor });
}
const at = (x, y) => ({ x, y: OY + y });
const pathLength = (pts) => pts.slice(1).reduce((s, p, i) => s + Math.hypot(p.x - pts[i].x, p.y - pts[i].y), 0);

test('draw intent: Space or a click charges; a fresh press is reported for committing', () => {
  const raw = { move: none, snap: null, space: false, pointerDown: true, pressed: true, drag: none, hover: null, cursor: { x: 1, y: 2 }, release: false, releaseSource: null, releaseDrag: none };
  const it = buildIntent(raw, 'draw');
  assert.equal(it.charging, true);
  assert.equal(it.keyboard, true);
  assert.equal(it.press, true);
});

test('releasing a charge freezes the ship and slows the world instead of launching', () => {
  const game = quiet();
  charge(game, 0.8, at(300, 0));
  assert.equal(game.draw?.phase, 'draw');
  assert.ok(game.timeScale < 0.15);
  const x0 = game.ship.x;
  update(game, 0.1, { ...idle, cursor: at(300, 0) });
  assert.ok(Math.abs(game.ship.x - x0) < 1, 'ship waits while the path is drawn');
});

test('enemies crawl while drawing', () => {
  const game = quiet();
  const e = createEnemy('drifter', 1, 600, OY); e.vx = -200;
  game.enemies.push(e);
  charge(game, 0.8, at(100, 0));
  const ex = e.x;
  for (let i = 0; i < 10; i++) update(game, 0.05, { ...idle, cursor: at(100, 0) });
  assert.ok(Math.abs(e.x - ex) < 30, `moved ${Math.abs(e.x - ex)}`);
});

test('the path follows the cursor from the ship and is capped by the charge', () => {
  const short = quiet();
  charge(short, 0.2, at(50, 0));
  const long = quiet();
  charge(long, 0.8, at(50, 0));
  assert.ok(long.draw.budget > short.draw.budget * 2);
  for (const game of [short, long]) {
    const budget = game.draw.budget;
    const start = { ...game.draw.points[0] };
    assert.ok(Math.hypot(start.x - game.ship.x, start.y - game.ship.y) < 1e-9, 'starts at the ship');
    for (let i = 1; i <= 40; i++) update(game, 0.02, { ...idle, cursor: at(50 + i * 60, i * 10) });
    const pts = (game.draw && (game.draw.points || game.draw.path)) || game.lastPath;
    assert.deepEqual(pts[0], start);
    assert.ok(pathLength(pts) <= budget + 1e-6);
  }
});

test('committing runs the ship along the drawn path, then it keeps its momentum', () => {
  const game = quiet();
  charge(game, 0.8, at(0, 0));
  // an L: right 400, then down 300
  for (let i = 1; i <= 8; i++) update(game, 0.02, { ...idle, cursor: at(i * 50, 0) });
  for (let i = 1; i <= 6; i++) update(game, 0.02, { ...idle, cursor: at(400, i * 50) });
  update(game, 0.02, { ...idle, press: true, cursor: at(400, 300) });
  assert.equal(game.draw?.phase, 'run');
  let passedCorner = false;
  for (let i = 0; i < 200 && game.draw; i++) {
    update(game, 0.02, { ...idle, cursor: at(400, 300) });
    if (Math.hypot(game.ship.x - 400, game.ship.y - OY) < 40) passedCorner = true;
  }
  assert.ok(passedCorner, 'went around the corner');
  assert.equal(game.draw, null);
  assert.ok(Math.abs(game.ship.x - 400) < 60 && game.ship.y > OY + 250, 'ended near the end of the path');
  assert.ok(game.ship.vy > 300 && Math.abs(game.ship.vx) < 60, 'leaves along the last segment');
});

test('the run pierces enemies on the path; armor it cannot pierce stops it with a bounce', () => {
  const game = quiet();
  const a = createEnemy('drifter', 1, 200, OY); a.speed = 0;
  game.enemies.push(a);
  const wall = createEnemy('armored', 5, 450, OY); wall.speed = 0; wall.facing = Math.PI; // facing the ship
  game.enemies.push(wall);
  charge(game, 0.8, at(0, 0));
  for (let i = 1; i <= 14; i++) update(game, 0.02, { ...idle, cursor: at(i * 50, 0) });
  update(game, 0.02, { ...idle, press: true, cursor: at(700, 0) });
  const ev = [];
  for (let i = 0; i < 200 && game.draw; i++) { update(game, 0.02, { ...idle, cursor: at(700, 0) }); ev.push(...game.events); game.events.length = 0; }
  assert.ok(a.dead, 'drifter on the path was cut down');
  assert.equal(wall.dead, false);
  assert.ok(ev.some((e) => e.type === 'bounce'));
  assert.ok(game.ship.x < 450, 'stopped at the wall');
});

test('drawing ends by itself when time runs out', () => {
  const game = quiet();
  charge(game, 0.8, at(100, 0));
  for (let t = 0; t < CONFIG.drawTime + 0.3; t += 0.05) update(game, 0.05, { ...idle, cursor: at(100, 0) });
  assert.notEqual(game.draw?.phase, 'draw');
});

test('committing without drawing dashes straight at the cursor', () => {
  const game = quiet();
  charge(game, 0.8, at(0, 500)); // cursor below the ship, never moved
  // the first frame already lays a straight segment toward the cursor; commit at once
  update(game, 0.02, { ...idle, press: true, cursor: at(0, 500) });
  for (let i = 0; i < 100 && game.draw; i++) update(game, 0.02, { ...idle, cursor: at(0, 500) });
  assert.ok(game.ship.y > OY + 300 && Math.abs(game.ship.x) < 5);
});
