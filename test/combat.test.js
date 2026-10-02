import { test } from 'node:test';
import assert from 'node:assert/strict';
import { attackPower, isWeakHit, resolveRam } from '../src/combat.js';
import { baseStats } from '../src/ship.js';
import { createEnemy } from '../src/enemies.js';
import { createGame, update } from '../src/world.js';
import { CONFIG } from '../src/config.js';

const stats = baseStats();
const idle = { charging: false, aimX: 0, aimY: 0, release: false };

function quietGame() {
  const game = createGame({ seed: 5 });
  game.field.moons.length = 0;
  game.field.dust.length = 0;
  game.field.planet.gm = 0;
  game.spawning = false;
  game.ship.y = OY;
  return game;
}
const OY = -3000; // keep scenes away from the planet at the origin

test('attack power scales with speed and multiplier', () => {
  assert.ok(Math.abs(attackPower(1000, stats) - 10 * CONFIG.atkScale) < 1e-9);
  assert.ok(Math.abs(attackPower(1000, { ...stats, atkMult: 2 }) - 20 * CONFIG.atkScale) < 1e-9);
});

test('a full-gauge dash from rest one-shots basic fodder', () => {
  const sp = stats.maxSpeed * stats.launchRatio;
  const e = createEnemy('drifter', 1, 0, 0);
  assert.ok(attackPower(sp, stats) >= e.hp);
});

test('enough attack pierces, too little bounces and hurts the ship', () => {
  const e = createEnemy('armored', 1, 0, 0);
  const strong = resolveRam(e.armor + 1, e, false, stats);
  assert.equal(strong.pierce, true);
  assert.ok(strong.damage > 0);
  const weak = resolveRam(e.armor - 1, e, false, stats);
  assert.equal(weak.pierce, false);
  assert.ok(weak.shipDamage > 0);
});

test('weak spot follows the enemy facing', () => {
  const e = createEnemy('drifter', 1, 0, 0);
  e.facing = 0; // looking +x, weak spot on the back (-x)
  assert.equal(isWeakHit(e, -e.r, 0, 1), true);
  assert.equal(isWeakHit(e, e.r, 0, 1), false);
  e.facing = Math.PI; // turned around
  assert.equal(isWeakHit(e, e.r, 0, 1), true);
});

test('critical hits get through armor that would otherwise stop the ship', () => {
  const e = createEnemy('armored', 1, 0, 0);
  const atk = e.armor * 0.7;
  assert.equal(resolveRam(atk, e, false, stats).pierce, false);
  const crit = resolveRam(atk, e, true, stats);
  assert.equal(crit.pierce, true);
  assert.ok(crit.damage > atk * 2);
});

test('a fast dash pierces a whole line of enemies without tunneling', () => {
  const game = quietGame();
  const sh = game.ship;
  sh.x = 0; sh.y = OY; sh.vx = 2150; sh.vy = 0; sh.boostT = 5;
  game.stats.maxSpeed = 2150;
  for (let i = 0; i < 6; i++) {
    const e = createEnemy('drifter', 1, 200 + i * 60, OY);
    e.facing = Math.PI / 2;
    game.enemies.push(e);
  }
  for (let i = 0; i < 25; i++) update(game, 0.02, idle);
  assert.equal(game.enemies.filter((e) => !e.dead).length, 0);
  assert.ok(game.kills >= 6);
  assert.ok(sh.vx > 1400, "kept most of the speed");
});

test('ramming armor too slowly bounces back and costs HP', () => {
  const game = quietGame();
  const sh = game.ship;
  sh.x = 0; sh.y = OY; sh.vx = 300; sh.vy = 0;
  const e = createEnemy('armored', 1, 120, OY);
  e.facing = Math.PI; // facing the ship, weak spot away
  e.speed = 0;
  game.enemies.push(e);
  for (let i = 0; i < 30; i++) update(game, 0.02, idle);
  assert.ok(sh.hp < game.stats.maxHp);
  assert.ok(sh.vx < 0, 'bounced');
  assert.equal(e.dead, false);
});

test('hitting the weak spot reports a critical', () => {
  const game = quietGame();
  const sh = game.ship;
  sh.x = 0; sh.y = OY; sh.vx = 900; sh.vy = 0; sh.boostT = 5;
  const e = createEnemy('armored', 1, 150, OY);
  e.facing = 0; // back faces the ship
  e.speed = 0;
  game.enemies.push(e);
  const events = [];
  for (let i = 0; i < 15; i++) { update(game, 0.02, idle); events.push(...game.events); game.events.length = 0; }
  assert.ok(events.some((ev) => ev.type === 'hit' && ev.crit));
});
