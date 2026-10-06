import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { createEnemy } from '../src/enemies.js';
import { createGame, update, refreshStats, damageShip } from '../src/world.js';

const idle = { charging: false, aimX: 0, aimY: 0, release: false };
const OY = -3000;

function setup(mods) {
  const game = createGame({ seed: 21 });
  game.field.moons.length = 0;
  game.field.dust.length = 0;
  game.field.planet.gm = 0;
  game.spawning = false;
  game.capsules.length = 0;
  Object.assign(game.loadout, mods);
  refreshStats(game);
  game.ship.x = 0; game.ship.y = OY; game.ship.vx = 0; game.ship.vy = 0;
  return game;
}

function run(game, seconds, input = idle, sink) {
  for (let t = 0; t < seconds; t += 0.02) {
    update(game, 0.02, input);
    if (sink) sink.push(...game.events);
    game.events.length = 0;
  }
}

function still(type, x, y, level = 1) {
  const e = createEnemy(type, level, x, y);
  e.speed = 0; e.facing = Math.PI / 2;
  return e;
}

test('burst head: piercing enough enemies blows up at the end of the dash', () => {
  const game = setup({ bow: { id: 'burstHead', slot: 'bow', r: 3 } });
  const sh = game.ship;
  sh.vx = 900; sh.boostT = 0.5;
  for (let i = 0; i < 3; i++) game.enemies.push(still('drifter', 100 + i * 50, OY));
  const bystander = still('armored', 520, OY + 120);
  game.enemies.push(bystander);
  const ev = [];
  run(game, 1, idle, ev);
  assert.ok(ev.some((e) => e.type === 'explode' && e.cause === 'endBlast'));
  assert.ok(bystander.hp < bystander.maxHp || bystander.dead);
});

test('flinger: rammed kills fly on and hit enemies behind', () => {
  const game = setup({ bow: { id: 'flinger', slot: 'bow', r: 3 } });
  const sh = game.ship;
  sh.vx = 1000; sh.boostT = 1;
  game.enemies.push(still('drifter', 120, OY));
  const behind = still('armored', 300, OY + 60);
  game.enemies.push(behind);
  run(game, 0.6);
  assert.ok(behind.hp < behind.maxHp || behind.dead);
});

test('trail burst: the dash path explodes after a delay', () => {
  const game = setup({ gun: { id: 'trailBurst', slot: 'gun', r: 3 } });
  const sh = game.ship;
  sh.vx = 900; sh.boostT = 0.6;
  run(game, 0.4);
  const e = still('armored', 150, OY + 30); // lands on the path after the ship passed
  game.enemies.push(e);
  run(game, 1.2);
  assert.ok(e.hp < e.maxHp || e.dead);
});

test('charge wave: charging hurts nearby enemies', () => {
  const game = setup({ gun: { id: 'chargeWave', slot: 'gun', r: 2 } });
  const e = still('drifter', 120, OY);
  game.enemies.push(e);
  run(game, 1.2, { charging: true, aimX: 0, aimY: 100, release: false });
  assert.ok(e.dead);
});

test('turret shoots the nearest enemy', () => {
  const game = setup({ gun: { id: 'turret', slot: 'gun', r: 2 } });
  const e = still('armored', 400, OY);
  game.enemies.push(e);
  run(game, 2);
  assert.ok(e.hp < e.maxHp);
});

test('sonic boom fires when crossing 92% of max speed', () => {
  const game = setup({ gen: { id: 'sonicL', slot: 'gen', r: 3 } });
  const sh = game.ship;
  const cap = game.stats.maxSpeed;
  sh.vx = cap * 0.85; sh.boostT = 2;
  const e = still('armored', 0, OY + 600);
  game.enemies.push(e);
  const ev = [];
  run(game, 0.1, idle, ev);
  sh.vx = cap * 0.97;
  run(game, 0.3, idle, ev);
  assert.ok(ev.some((x) => x.type === 'sonic'));
  assert.ok(e.dead);
});

test('regen generator banks gauge when piercing', () => {
  const game = setup({ gen: { id: 'regenGen', slot: 'gen', r: 2 } });
  const sh = game.ship;
  sh.vx = 900; sh.boostT = 1;
  game.enemies.push(still('drifter', 100, OY));
  run(game, 0.3);
  assert.ok(sh.gaugeBank > 0);
});

test('reactive armor bursts when hit', () => {
  const game = setup({ armor: { id: 'reactive', slot: 'armor', r: 2 } });
  const e = still('drifter', 150, OY);
  game.enemies.push(e);
  damageShip(game, 5, 0);
  run(game, 0.1);
  assert.ok(e.dead);
});

test('picking up a capsule offers its module', () => {
  const game = setup({});
  game.capsules.push({ kind: 'capsule', x: 40, y: OY, mod: { id: 'ram', slot: 'bow', r: 2 }, age: 0 });
  run(game, 0.2);
  assert.equal(game.state, 'offer');
  assert.equal(game.currentOffer.id, 'ram');
  assert.equal(game.currentOffer.source, 'capsule');
});

test('capsules appear on the field over time', () => {
  const game = createGame({ seed: 4 });
  game.debug.invincible = true;
  game.debug.autoOffer = 'discard';
  run(game, 3);
  assert.ok(game.capsules.length >= CONFIG.hyperCapsuleCount);
});

test('power cores appear near the planet in the escape phase', () => {
  const game = createGame({ seed: 4 });
  game.debug.invincible = true;
  game.debug.autoOffer = 'discard';
  game.t = 512;
  run(game, 1);
  const cores = game.capsules.filter((c) => c.kind === 'core');
  assert.ok(cores.length >= 1);
  for (const c of cores) assert.ok(Math.hypot(c.x, c.y) < CONFIG.zoneInner);
});

test('a power core raises max speed on the spot without pausing', () => {
  const game = setup({});
  const before = game.stats.maxSpeed;
  game.capsules.push({ kind: 'core', src: 'core', x: 40, y: OY, mod: { id: 'limiter', slot: 'booster', r: 3 }, age: 0 });
  run(game, 0.2);
  assert.equal(game.state, 'play');
  assert.ok(game.stats.maxSpeed > before * 1.1);
  assert.equal(game.cores, 1);
});

test('leveling up restores a little HP', () => {
  const game = setup({});
  game.ship.hp = 50;
  game.debug.autoOffer = 'discard';
  game.xp = 1e3;
  run(game, 0.05);
  game.gems.push({ x: game.ship.x, y: game.ship.y, v: 1, age: 0 });
  run(game, 0.1);
  assert.ok(game.ship.hp > 50);
});
