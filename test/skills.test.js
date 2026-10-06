import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { classifyPath } from '../src/skills.js';
import { createGame, update } from '../src/world.js';
import { createEnemy } from '../src/enemies.js';

const OY = -3000;
const idle = { charging: false, release: false, press: false, cursor: null };
const at = (x, y) => ({ x, y: OY + y });

function quiet() {
  const game = createGame({ seed: 3, scheme: 'draw' });
  game.spawning = false;
  game.field.moons.length = 0; game.field.dust.length = 0;
  Object.assign(game.ship, { x: 0, y: OY, vx: 0, vy: 0 });
  game.dashMeter = 1;
  return game;
}

// Click at `pts[0]`, move through the rest, click again to commit.
function drawPath(game, pts) {
  update(game, 0.02, { ...idle, drawClick: true, press: true, cursor: pts[0], clickCursor: pts[0] });
  for (const p of pts.slice(1)) update(game, 0.02, { ...idle, cursor: p });
  const events = [...game.events];
  update(game, 0.02, { ...idle, press: true, cursor: pts[pts.length - 1] });
  events.push(...game.events);
  return events;
}

const spiral = (cx, cy, r0, turns) => {
  const pts = [];
  for (let t = 0; t <= turns * 2 * Math.PI; t += 0.15) {
    const r = r0 * (1 - t / (turns * 2 * Math.PI * 1.1));
    pts.push({ x: cx + Math.cos(t) * r, y: cy + Math.sin(t) * r });
  }
  return pts;
};
const zigzag = (n, w, h) => Array.from({ length: n + 1 }, (_, i) => ({ x: i * w, y: i % 2 ? h : 0 }));

test('path shapes pick skills: straight, zigzag, inward spiral, otherwise none', () => {
  assert.equal(classifyPath([{ x: 0, y: 0 }, { x: 200, y: 20 }, { x: 400, y: 41 }]), 'blink');
  assert.equal(classifyPath(zigzag(6, 50, 80)), 'lightning');
  assert.equal(classifyPath(spiral(0, 0, 220, 2)), 'blast');
  assert.equal(classifyPath(spiral(0, 0, 220, 2).reverse()), null, 'an outward spiral is not a Blast');
  assert.equal(classifyPath([{ x: 0, y: 0 }, { x: 300, y: 0 }, { x: 300, y: 300 }]), null, 'an L is a plain trace');
  assert.equal(classifyPath([{ x: 0, y: 0 }, { x: 60, y: 0 }]), null, 'too short');
});

test('a path can only start near the ship', () => {
  const game = quiet();
  update(game, 0.02, { ...idle, drawClick: true, press: true, cursor: at(2000, 0), clickCursor: at(2000, 0) });
  const p = (game.draw?.points || game.lastPath)[0];
  assert.ok(Math.abs(Math.hypot(p.x, p.y - OY) - CONFIG.drawStartRange) < 1e-6);
});

test('Blink: a straight line moves the ship to its end at once and cuts armor it could not pierce', () => {
  const game = quiet();
  const wall = createEnemy('armored', 8, 300, OY, { facing: Math.PI }); wall.speed = 0;
  game.enemies.push(wall);
  update(game, 0.02, idle);
  const hp = wall.hp;
  const ev = drawPath(game, [at(0, 0), at(200, 0), at(400, 0), at(600, 0)]);
  assert.equal(game.draw, null, 'no tracing phase');
  assert.ok(game.ship.x >= 590, 'already at the end');
  assert.ok(wall.dead || wall.hp < hp, 'armor ignored');
  assert.ok(ev.some((e) => e.type === 'skill' && e.skill === 'blink'));
});

test('Lightning: a zigzag traces faster and stuns what it touches', () => {
  const game = quiet();
  const e = createEnemy('armored', 3, 150, OY + 40); e.speed = 0; e.hp = e.maxHp = 1e6;
  game.enemies.push(e);
  update(game, 0.02, idle);
  const ev = drawPath(game, zigzag(6, 50, 80).map((p) => at(p.x, p.y)));
  assert.equal(game.draw?.skill, 'lightning');
  assert.ok(ev.some((x) => x.type === 'skill' && x.skill === 'lightning'));
  for (let i = 0; i < 100 && game.draw; i++) update(game, 0.01, idle);
  assert.ok(e.stunT > 0);
});

test('Blast: an inward spiral explodes at its end and throws every enemy far, even heavy ones', () => {
  const game = quiet();
  const big = createEnemy('titan', 5, 0, OY - 260); big.speed = 0; big.hp = big.maxHp = 1e6;
  game.enemies.push(big);
  update(game, 0.02, idle);
  drawPath(game, spiral(0, OY, 130, 2));
  assert.equal(game.draw?.skill, 'blast');
  game.events.length = 0;
  const blasts = [];
  for (let i = 0; i < 200 && game.draw; i++) { update(game, 0.01, idle); blasts.push(...game.events.filter((x) => x.type === 'blast')); game.events.length = 0; }
  assert.equal(blasts.length, 1);
  assert.ok(Math.hypot(big.vx, big.vy) > 800, 'knocked back regardless of mass');
  assert.ok(big.stunT > 0);
});
