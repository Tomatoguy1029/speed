import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { buildIntent } from '../src/controls.js';
import { createGame, update, addXp } from '../src/world.js';
import { createEnemy } from '../src/enemies.js';

// plain tracing only: path-shape skills and the start range are covered in skills.test.js
CONFIG.skillMinLength = Infinity;
CONFIG.drawStartRange = Infinity;

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

// Fire the (full) dash gauge, click at the ship to start the path there, then aim at `cursor`.
function charge(game, _seconds, cursor) {
  const here = { x: game.ship.x, y: game.ship.y };
  game.dashMeter = 1;
  update(game, 0.02, { ...idle, dash: true, cursor: here });
  update(game, 0.02, { ...idle, press: true, cursor: here }); // click to start drawing
  update(game, 0.02, { ...idle, cursor });
}
const at = (x, y) => ({ x, y: OY + y });
const pathLength = (pts) => pts.slice(1).reduce((s, p, i) => s + Math.hypot(p.x - pts[i].x, p.y - pts[i].y), 0);

test('draw intent: Space fires the dash; a held touch is a stick, the mouse cursor steers (offset from the press point)', () => {
  const raw = { move: none, snap: null, space: false, pointerDown: true, pressed: true, drag: { x: -30, y: 40 }, hover: null, cursor: { x: 1, y: 2 }, release: false, releaseSource: null, releaseDrag: none };
  let it = buildIntent(raw, 'draw');
  assert.equal(it.stick, undefined, 'a mouse press does not steer (the cursor does)');
  it = buildIntent({ ...raw, pointerType: 'touch' }, 'draw');
  assert.equal(it.charging, false);
  assert.deepEqual(it.stick, { x: 30, y: -40 });
  assert.equal(it.press, true);
  assert.equal(it.drawClick, false, 'a touch-stick press must not fire a ready attack');
  it = buildIntent({ ...raw, pointerDown: false, dash: true }, 'draw');
  assert.equal(it.dash, true);
  assert.equal(it.charging, false);
});

test('starting a draw holds the ship and applies the configured world speed instead of launching', () => {
  const game = quiet();
  charge(game, 0.8, at(300, 0));
  assert.equal(game.draw?.phase, 'draw');
  assert.equal(game.timeScale, CONFIG.drawTimeScale);
  const x0 = game.ship.x;
  update(game, 0.1, { ...idle, cursor: at(300, 0) });
  assert.ok(Math.abs(game.ship.x - x0) < 1, 'ship waits while the path is drawn');
});

test('drawing world speed can stop, slow or run enemies normally', () => {
  const saved = CONFIG.drawTimeScale;
  const distances = [];
  try {
    for (const scale of [0, 0.5, 1]) {
      CONFIG.drawTimeScale = scale;
      const game = quiet();
      const e = createEnemy('drifter', 1, 600, OY); e.vx = -200;
      game.enemies.push(e);
      charge(game, 0.8, at(100, 0));
      const ex = e.x;
      for (let i = 0; i < 10; i++) update(game, 0.05, { ...idle, cursor: at(100, 0) });
      assert.equal(game.timeScale, scale);
      distances.push(Math.abs(e.x - ex));
    }
  } finally { CONFIG.drawTimeScale = saved; }
  assert.equal(distances[0], 0);
  assert.ok(distances[1] > 0 && distances[1] < distances[2]);
  assert.ok(distances[2] > 30);
});

test('the dash needs a full gauge; the path starts where you click and the ship warps there', () => {
  const game = quiet();
  game.dashMeter = 0.5;
  update(game, 0.02, { ...idle, dash: true });
  assert.equal(game.draw, null, 'not ready');
  game.dashMeter = 1;
  update(game, 0.02, { ...idle, dash: true, cursor: at(0, 0) });
  assert.equal(game.draw?.phase, 'draw');
  assert.equal(game.dashMeter, 0);
  const budget = game.draw.budget;
  update(game, 0.02, { ...idle, press: true, cursor: at(600, 200) });
  assert.deepEqual(game.draw.points[0], at(600, 200));
  for (let i = 1; i <= 40; i++) update(game, 0.02, { ...idle, cursor: at(600 + i * 60, 200 + i * 10) });
  const pts = (game.draw && (game.draw.points || game.draw.path)) || game.lastPath;
  assert.ok(pathLength(pts) <= budget + 1e-6);
  assert.ok(game.events.some((e) => e.type === 'warp'), 'warped to the start');
});

test('XP fills the dash gauge', () => {
  const game = quiet();
  game.dashMeter = 0;
  addXp(game, 1);
  assert.ok(game.dashMeter > 0 && game.dashMeter < 1);
  addXp(game, 100);
  assert.equal(game.dashMeter, 1);
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

test('drawing waits for a click or exhausted length instead of a time limit', () => {
  const game = quiet();
  charge(game, 0.8, at(100, 0));
  for (let t = 0; t < 6; t += 0.05) update(game, 0.05, { ...idle, cursor: at(100, 0) });
  assert.equal(game.draw?.phase, 'draw');
  const budget = game.draw.budget;
  update(game, 0.02, { ...idle, cursor: at(budget + 100, 0) });
  assert.equal(game.draw?.phase, 'run');
  assert.equal(pathLength(game.lastPath), budget);
});

test('a ready mouse click starts drawing directly, mouse release keeps drawing, and the next click launches', () => {
  for (const scheme of ['draw', 'draw-wasd']) {
    const game = quiet(); game.scheme = scheme;
    const mouse = (cursor, pressed = false, clickCursor = null) => buildIntent({ move: none, cursor, pressed, clickCursor,
      pointerType: 'mouse', pointerDown: false, dash: false }, scheme);
    game.dashMeter = 0.5;
    update(game, 0.02, mouse(at(0, 0), true));
    assert.equal(game.draw, null);
    game.dashMeter = 1;
    update(game, 0.02, mouse(at(100, 0), true, at(50, 0)));
    assert.equal(game.draw?.phase, 'draw');
    assert.ok(game.draw.started);
    assert.deepEqual(game.draw.points, [at(50, 0), at(100, 0)], 'drawing starts at the press even if the cursor already moved');
    assert.equal(game.dashMeter, 0);
    update(game, 0.02, mouse(at(250, 0)));
    assert.equal(game.draw.used, 200, 'mouse movement draws without holding a button');
    update(game, 0.02, mouse(at(250, 0), true));
    assert.equal(game.draw?.phase, 'run');
  }
});

test('committing without drawing dashes straight at the cursor', () => {
  const game = quiet();
  charge(game, 0.8, at(0, 500)); // cursor below the ship, never moved
  // the first frame already lays a straight segment toward the cursor; commit at once
  update(game, 0.02, { ...idle, press: true, cursor: at(0, 500) });
  for (let i = 0; i < 100 && game.draw; i++) update(game, 0.02, { ...idle, cursor: at(0, 500) });
  assert.ok(game.ship.y > OY + 300 && Math.abs(game.ship.x) < 5);
});

test('a path that crosses the same enemy twice hits it twice', () => {
  const game = quiet();
  const tank = createEnemy('armored', 1, 300, OY); tank.speed = 0; tank.facing = 0; // weak spot faces away (+x)
  tank.hp = tank.maxHp = 1000; tank.armor = 1; // pierceable, survives both passes
  game.enemies.push(tank);
  charge(game, 0.8, at(0, 0));
  // through it, out the far side, swing around, and back through
  const route = [[150, 0], [300, 0], [450, 0], [450, 150], [300, 150], [300, 0], [300, -150]];
  for (const [x, y] of route) update(game, 0.02, { ...idle, cursor: at(x, y) });
  update(game, 0.02, { ...idle, press: true, cursor: at(300, -150) });
  const hits = [];
  for (let i = 0; i < 200 && game.draw; i++) { update(game, 0.02, { ...idle, cursor: at(300, -150) }); hits.push(...game.events.filter((e) => e.type === 'hit')); game.events.length = 0; }
  assert.ok(hits.length >= 2, `hits ${hits.length}`);
});
