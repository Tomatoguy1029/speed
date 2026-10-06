import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { createGame, update, collideEnemies } from '../src/world.js';
import { createEnemy } from '../src/enemies.js';
import { buildGrid } from '../src/grid.js';

function pointGame() {
  const g = createGame({ scheme: 'draw-wasd', seed: 9 });
  g.spawning = false; g.field.moons = []; g.field.dust = [];
  Object.assign(g.ship, { x: 0, y: -3000, vx: 0, vy: 0 });
  return g;
}

test('point input only records clicks and executes the confirmed polyline, without adding the hovered point', () => {
  const previous = CONFIG.drawInput;
  try {
    CONFIG.drawInput = 'points';
    const g = pointGame();
    const a = { x: 0, y: -3000 }, b = { x: 300, y: -3000 }, c = { x: 300, y: -2800 };
    const click = p => update(g, 0.02, { drawClick: true, press: true, clickCursor: p, cursor: p });
    click(a);
    update(g, 0.02, { cursor: b });
    assert.deepEqual(g.draw.points, [a]);
    click(b); click(c);
    assert.equal(g.draw.phase, 'draw');
    assert.deepEqual(g.draw.points, [a, b, c]);
    assert.equal(g.draw.used, 500);
    update(g, 0.02, { confirm: true, cursor: { x: 800, y: -2400 } });
    assert.equal(g.draw.phase, 'run');
    assert.deepEqual(g.lastPath, [a, b, c]);
    for (let i = 0; i < 100 && g.draw; i++) update(g, 0.01, {});
    assert.ok(g.ship.glide);
    assert.ok(g.ship.vy > 0 && Math.abs(g.ship.vx) < 1e-6);
  } finally { CONFIG.drawInput = previous; }
});

test('point input clips to the length budget and obstacles, and Space confirms without adding a segment', () => {
  const previous = CONFIG.drawInput;
  try {
    CONFIG.drawInput = 'points';
    for (const finish of ['length', 'obstacle', 'space']) {
      const g = pointGame(), a = { x: 0, y: -3000 };
      update(g, 0.01, { drawClick: true, clickCursor: a, cursor: a });
      const budget = g.draw.budget;
      if (finish === 'obstacle') g.field.moons.push({ x: 200, y: -3000, r: 40, gm: 0, orbit: false });
      const b = { x: finish === 'length' ? budget + 400 : 300, y: -3000 };
      update(g, 0.01, { drawClick: true, press: true, clickCursor: b, cursor: b });
      if (finish === 'space') {
        assert.equal(g.draw.phase, 'draw');
        update(g, 0.01, { dash: true, press: true, cursor: { x: 300, y: -2500 } });
      }
      assert.equal(g.draw.phase, 'run');
      assert.equal(g.lastPath.length, 2);
      assert.equal(g.lastPath[1].y, a.y);
      if (finish === 'length') assert.equal(g.lastPath[1].x, budget);
      if (finish === 'obstacle') assert.ok(g.lastPath[1].x < 160);
    }
  } finally { CONFIG.drawInput = previous; }
});

test('failed armor contact lights the blocker, while a successful weak-side pass emits heat at the contact', () => {
  for (const weak of [false, true]) {
    const g = pointGame();
    const e = createEnemy('armored', 1, 100, -3000, { facing: weak ? 0 : Math.PI });
    Object.assign(g.ship, { x: 160, vx: 400, vy: 0 });
    g.enemies = [e]; g.grid = buildGrid(g.enemies, 160);
    const stopped = collideEnemies(g, 0, -3000);
    assert.equal(stopped, !weak);
    const impact = g.fx.impacts[0];
    assert.equal(impact.kind, weak ? 'weak' : 'block');
    assert.equal(impact.enemy, e);
    assert.ok(Number.isFinite(impact.x) && impact.x < e.x);
    assert.ok(g.fx.particles.some(p => p.kind === (weak ? 'flame' : 'spark')));
  }
});
