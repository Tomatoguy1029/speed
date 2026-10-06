import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createGame, update, refreshStats } from '../src/world.js';
import { createEnemy } from '../src/enemies.js';
import { killEnemy } from '../src/hits.js';
import { rollModule } from '../src/modules.js';
import { makeRng } from '../src/math.js';
import { updateSpawner } from '../src/spawner.js';
import { CONFIG } from '../src/config.js';

test('draw drops use independent probability rolls without a time gate or pity timer', () => {
  const g = createGame({ scheme: 'draw', seed: 5 });
  g.rng = () => 0.99;
  g.t = 300;
  killEnemy(g, createEnemy('drifter', 1, 0, -3000));
  assert.equal(g.capsules.length, 0, 'elapsed time does not guarantee a drop');
  g.rng = () => 0;
  killEnemy(g, createEnemy('drifter', 1, 0, -3000));
  killEnemy(g, createEnemy('drifter', 1, 0, -3000));
  assert.equal(g.capsules.length, 2, 'two kills at the same time can both drop modules');
});

test('draw module rolls replace obsolete prediction and charge effects with route attacks', () => {
  const rng = makeRng(71), seen = new Set();
  for (const scheme of ['draw', 'draw-wasd']) {
    const g = createGame({ scheme });
    for (let i = 0; i < 3000; i++) {
      const m = rollModule(rng, { scheme, t: 500, source: 'capsule', danger: 1, loadout: g.loadout });
      assert.ok(!['scope', 'bounceScope', 'chargeWave'].includes(m.id)); seen.add(m.id);
    }
  }
  assert.ok(seen.has('finishPulse') && seen.has('impactPulse'));
});

test('end-point explosion and on-pierce wave damage enemies outside the drawn line', () => {
  for (const id of ['finishPulse', 'impactPulse']) {
    const g = createGame({ scheme: 'draw-wasd', seed: 5 });
    g.spawning = false; g.field.moons = []; g.field.dust = [];
    g.loadout.radar = { id, slot: 'radar', r: 2 };
    refreshStats(g);
    Object.assign(g.ship, { x: 0, y: -3000, vx: 0, vy: 0 });
    const direct = createEnemy('drifter', 1, 150, -3000);
    const side = createEnemy('drifter', 1, id === 'finishPulse' ? 300 : 140, -2920);
    direct.speed = side.speed = 0;
    g.enemies = [direct, side];
    update(g, 0.01, { drawClick: true, clickCursor: { x: 0, y: -3000 }, cursor: { x: 0, y: -3000 } });
    update(g, 0.01, { cursor: { x: 300, y: -3000 } });
    update(g, 0.01, { press: true });
    for (let i = 0; i < 100 && g.draw; i++) update(g, 0.01, {});
    assert.ok(side.hp < side.maxHp, id);
    assert.ok(g.events.some(e => e.cause === (id === 'finishPulse' ? 'traceEnd' : 'pierceWave')), id);
  }
});

test('far enemies recycle outside actual screen edges without healing or despawning the boss', () => {
  for (const [halfW, halfH] of [[900, 350], [300, 800]]) {
    const g = createGame({ seed: 9 });
    Object.assign(g.ship, { x: 0, y: -3000, vx: 500, vy: 0 });
    g.spawnView = { x: 0, y: -3000, halfW, halfH };
    for (let i = 0; i < 20; i++) updateSpawner(g, 0.1);
    const e = g.enemies.find(e => e.type !== 'meteor');
    e.hp *= 0.5;
    const hp = e.hp, kills = g.kills;
    const boss = createEnemy('boss', 1, 0, -3000);
    g.boss = boss; g.bossSpawned = true; g.enemies.push(boss);
    g.ship.x = 3500; g.spawnView.x = 3500;
    updateSpawner(g, 0.1);
    assert.equal(e.hp, hp); assert.equal(g.kills, kills);
    assert.equal(boss.x, 0); assert.ok(g.enemies.includes(boss));
    assert.ok(Math.abs(e.x - 3500) > halfW || Math.abs(e.y + 3000) > halfH, 'recycled enemies stay outside the visible rectangle');
    const nearby = g.enemies.filter(e => e.type !== 'boss' && Math.abs(e.x - 3500) < halfW * CONFIG.spawnRecycleScale + 200 && Math.abs(e.y + 3000) < halfH * CONFIG.spawnRecycleScale + 200);
    assert.ok(nearby.length >= 60, `${halfW}x${halfH}: ${nearby.length}`);
  }
});

test('the existing burst head explodes once at the route end, without repeating when retained boost expires', () => {
  const g = createGame({ scheme: 'draw-wasd', seed: 8 });
  g.spawning = false; g.field.moons = []; g.field.dust = [];
  g.loadout.bow = { id: 'burstHead', slot: 'bow', r: 3 };
  refreshStats(g);
  Object.assign(g.ship, { x: 0, y: -3000, vx: 0, vy: 0 });
  g.enemies = [50, 150, 250].map(x => { const e = createEnemy('drifter', 1, x, -3000); e.speed = 0; return e; });
  update(g, 0.01, { drawClick: true, clickCursor: { x: 0, y: -3000 }, cursor: { x: 0, y: -3000 } });
  update(g, 0.01, { cursor: { x: 300, y: -3000 } });
  update(g, 0.01, { press: true });
  for (let i = 0; i < 300; i++) update(g, 0.01, {});
  assert.equal(g.events.filter(e => e.type === 'explode' && e.cause === 'endBlast').length, 1);
});
