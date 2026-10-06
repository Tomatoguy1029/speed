import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ENEMY_TYPES, BEHAVIORS, createEnemy } from '../src/enemies.js';
import { createGame, update } from '../src/world.js';
import { killEnemy } from '../src/hits.js';

const idle = { charging: false, aimX: 0, aimY: 0, release: false };
const OY = -3000;

function quietGame() {
  const game = createGame({ seed: 9 });
  game.field.moons.length = 0;
  game.field.dust.length = 0;
  game.field.planet.gm = 0;
  game.spawning = false;
  game.ship.x = 0; game.ship.y = OY; game.ship.vx = 0; game.ship.vy = 0;
  return game;
}

function run(game, seconds) {
  for (let t = 0; t < seconds; t += 0.05) { update(game, 0.05, idle); game.events.length = 0; }
}

test('every enemy type has a behavior and can be created', () => {
  for (const type of Object.keys(ENEMY_TYPES)) {
    assert.ok(BEHAVIORS[ENEMY_TYPES[type].behavior], type);
    const e = createEnemy(type, 2, 0, 0, { size: 40 });
    assert.ok(e.hp > 0 && e.armor > 0 && e.r > 0, type);
  }
});

test('higher level enemies are tougher', () => {
  const a = createEnemy('armored', 1, 0, 0), b = createEnemy('armored', 3, 0, 0);
  assert.ok(b.hp > a.hp && b.armor > a.armor);
});

test('splitters bud over time and split on death', () => {
  const game = quietGame();
  const e = createEnemy('splitter', 1, 900, OY);
  game.enemies.push(e);
  run(game, ENEMY_TYPES.splitter.budInterval + 0.5);
  const buds = game.enemies.filter((x) => x.type === 'splitling').length;
  assert.ok(buds >= 1, 'budded');
  killEnemy(game, e);
  run(game, 0.1);
  assert.ok(game.enemies.filter((x) => x.type === 'splitling').length >= buds + 2, 'split on death');
});

test('leech aura drains speed', () => {
  const mk = (withLeech) => {
    const game = quietGame();
    game.ship.vx = 600; game.ship.boostT = 99;
    if (withLeech) { const e = createEnemy('leech', 1, 100, OY + 120); e.speed = 0; game.enemies.push(e); }
    run(game, 0.5);
    return Math.hypot(game.ship.vx, game.ship.vy);
  };
  assert.ok(mk(true) < mk(false) - 30);
});

test('gunners shoot at the ship and bullets hurt and slow', () => {
  const game = quietGame();
  const e = createEnemy('gunner', 1, 500, OY);
  e.speed = 0;
  game.enemies.push(e);
  game.ship.vx = 0;
  run(game, ENEMY_TYPES.gunner.fireInterval + 2.5);
  assert.ok(game.ship.hp < game.stats.maxHp, 'took a bullet');
});

test('missiles home in on the ship', () => {
  const game = quietGame();
  game.ebullets.push({ kind: 'missile', x: 600, y: OY - 600, vx: 520, vy: 0, r: 8, dmg: 10, slow: 0.1, life: 6, speed: 520, turn: 2.4 });
  run(game, 0.6);
  const m = game.ebullets[0];
  assert.ok(m && m.vy > 100, 'turned toward the ship below');
});

test('darters wind up then dash faster than they cruise', () => {
  const game = quietGame();
  const e = createEnemy('darter', 1, 400, OY);
  game.enemies.push(e);
  let maxSp = 0, sawWindup = false;
  for (let t = 0; t < 3; t += 0.05) {
    update(game, 0.05, idle);
    if (e.state === 'windup') sawWindup = true;
    maxSp = Math.max(maxSp, Math.hypot(e.vx, e.vy));
  }
  assert.ok(sawWindup);
  assert.ok(maxSp > ENEMY_TYPES.darter.speed * 3);
});

test('meteors have no weak spot and scale with size', () => {
  const small = createEnemy('meteor', 1, 0, 0, { size: 24 });
  const big = createEnemy('meteor', 1, 0, 0, { size: 70 });
  assert.equal(small.weakArc, 0);
  assert.ok(big.armor > small.armor && big.hp > small.hp);
});
