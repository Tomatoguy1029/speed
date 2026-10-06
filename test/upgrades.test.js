import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createGame, update, addXp, resolveLevelup, hyperMaxCharges } from '../src/world.js';
import { rollLevelChoices, GUN_LEVELS, PERK_MAX } from '../src/upgrades.js';
import { createEnemy } from '../src/enemies.js';
import { CONFIG } from '../src/config.js';

const idle = { charging: false, release: false, cursor: null };
function quietGame() {
  const game = createGame({ seed: 4, scheme: 'hyper' });
  game.spawning = false;
  game.field.moons.length = 0;
  game.field.dust.length = 0;
  Object.assign(game.ship, { x: 0, y: -3000, vx: 0, vy: 0, hx: 1, hy: 0 });
  return game;
}

test('every level-up opens a pick of three; several level-ups are picked one after another', () => {
  const game = quietGame();
  addXp(game, 200);
  const levels = game.level;
  assert.ok(levels >= 2);
  update(game, 0.02, idle);
  assert.equal(game.state, 'levelup');
  assert.equal(game.levelChoices.length, 3);
  assert.equal(new Set(game.levelChoices.map((c) => c.kind + c.id)).size, 3, 'no duplicates');
  for (let i = 0; i < levels; i++) resolveLevelup(game, 0);
  assert.equal(game.state, 'play');
  assert.equal(game.pendingLevelups, 0);
});

test('level-ups wait until hyperdrive is closed', () => {
  const game = quietGame();
  update(game, 0.01, { ...idle, hyperToggle: true });
  addXp(game, 30);
  for (let i = 0; i < 20; i++) update(game, 0.05, idle);
  assert.notEqual(game.state, 'levelup');
  update(game, 0.01, { ...idle, hyperToggle: true });
  for (let i = 0; i < 5; i++) update(game, 0.02, idle);
  assert.equal(game.state, 'levelup');
});

test('the blaster fires along the heading, keeps the last direction when stopped, and not during a jump', () => {
  const game = quietGame();
  for (let i = 0; i < 30; i++) update(game, 0.02, idle);
  const shots = game.fbullets.filter((b) => b.kind === 'gun');
  assert.ok(shots.length >= 1);
  assert.ok(shots[0].vx > 0 && Math.abs(shots[0].vy) < 1, 'fires the way the ship last faced');
  assert.equal(shots[0].dmg, CONFIG.gunDamage * game.stats.atkMult, 'damage from stats, not speed');
  game.fbullets.length = 0;
  update(game, 0.01, { ...idle, hyperToggle: true });
  update(game, 0.01, { ...idle, jumpClicks: [{ x: 400, y: -3000 }] });
  game.gunT = 99;
  update(game, 0.01, idle);
  assert.ok(game.jump);
  assert.equal(game.fbullets.filter((b) => b.kind === 'gun').length, 0);
});

test('weapon levels add shots; perks stack up to the cap and leave the pool when maxed', () => {
  const game = quietGame();
  game.weapons.gun = 3;
  game.gunT = 99;
  update(game, 0.02, idle);
  assert.equal(game.fbullets.filter((b) => b.kind === 'gun').length, GUN_LEVELS[2].shots);
  game.weapons.gun = GUN_LEVELS.length;
  game.perks.extraCell = PERK_MAX;
  assert.equal(hyperMaxCharges(game), CONFIG.hyperMaxCharges + PERK_MAX);
  for (let i = 0; i < 50; i++) for (const c of rollLevelChoices(game)) {
    assert.notEqual(c.kind, 'weapon'); assert.notEqual(c.id, 'extraCell');
  }
});

test('chain blast: the third jump in a row explodes where it lands', () => {
  const game = quietGame();
  game.perks.chainBlast = 1;
  const e = createEnemy('armored', 1, 450, -2940);
  game.enemies.push(e);
  update(game, 0.02, idle);
  update(game, 0.01, { ...idle, hyperToggle: true });
  const hp = e.hp;
  for (const x of [150, 300, 450]) {
    update(game, 0.01, { ...idle, jumpClicks: [{ x, y: -3000 }] });
    for (let i = 0; i < 50 && game.jump; i++) update(game, 0.01, idle);
    if (x < 450) assert.equal(e.hp, hp, 'no blast before the third jump');
  }
  assert.ok(e.hp < hp);
});

test('full charge: a jump from a full stock pierces armor that would stop a normal jump', () => {
  const run = (perk) => {
    const game = quietGame();
    if (perk) game.perks.fullCharge = 1;
    const e = createEnemy('armored', 1, 200, -3000);
    e.armor = 50; // too hard for a normal jump even through the weak spot
    game.enemies.push(e);
    update(game, 0.02, idle);
    update(game, 0.01, { ...idle, hyperToggle: true });
    update(game, 0.01, { ...idle, jumpClicks: [{ x: 400, y: -3000 }] });
    for (let i = 0; i < 50 && game.jump; i++) update(game, 0.01, idle);
    return game.ship.x;
  };
  assert.ok(run(false) < 200, 'bounced');
  assert.ok(run(true) > 390, 'went through');
});
