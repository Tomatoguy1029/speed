import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MODULES, SLOTS, computeStats, rollModule, moduleDef } from '../src/modules.js';
import { baseStats } from '../src/ship.js';
import { makeRng } from '../src/math.js';
import { createGame, update, addXp, resolveOffer } from '../src/world.js';
import { CONFIG } from '../src/config.js';

const idle = { charging: false, aimX: 0, aimY: 0, release: false };
const emptyLoadout = () => Object.fromEntries(SLOTS.map((s) => [s.id, null]));

test('every module belongs to a known slot and describes itself at every rarity', () => {
  const ids = new Set(SLOTS.map((s) => s.id));
  for (const m of MODULES) {
    assert.ok(ids.has(m.slot), m.id);
    for (const r of m.rarities) assert.ok(m.desc(r).length > 0, m.id);
  }
  for (const s of SLOTS) assert.ok(MODULES.filter((m) => m.slot === s.id).length >= 3, s.id);
});

test('a thruster raises max speed, more at higher rarity', () => {
  const base = baseStats();
  const lo = computeStats({}, { ...emptyLoadout(), booster: { id: 'thruster', r: 0 } });
  const hi = computeStats({}, { ...emptyLoadout(), booster: { id: 'thruster', r: 3 } });
  assert.ok(lo.maxSpeed > base.maxSpeed);
  assert.ok(hi.maxSpeed > lo.maxSpeed);
});

test('rolls respect minimum time', () => {
  const rng = makeRng(4);
  for (let i = 0; i < 400; i++) {
    const m = rollModule(rng, { t: 60, loadout: emptyLoadout(), source: 'xp' });
    const def = moduleDef(m.id);
    assert.ok((def.minTime || 0) <= 60, m.id);
    assert.ok(def.rarities.includes(m.r), m.id);
  }
});

test('empty slots are offered more often', () => {
  const rng = makeRng(8);
  const loadout = emptyLoadout();
  for (const s of SLOTS) if (s.id !== 'radar') loadout[s.id] = { id: MODULES.find((m) => m.slot === s.id).id, r: 3 };
  const count = {};
  for (let i = 0; i < 600; i++) { const m = rollModule(rng, { t: 100, loadout, source: 'xp' }); count[m.slot] = (count[m.slot] || 0) + 1; }
  for (const s of SLOTS) if (s.id !== 'radar') assert.ok(count.radar > count[s.id], s.id);
});

test('capsules near the planet are rarer than mid-zone ones', () => {
  const rng = makeRng(5);
  const avg = (danger) => {
    let sum = 0;
    for (let i = 0; i < 500; i++) sum += rollModule(rng, { t: 60, loadout: emptyLoadout(), source: 'capsule', danger }).r;
    return sum / 500;
  };
  assert.ok(avg(1) > avg(0) + 0.8);
});

test('power cores always give a speed-limit module for the booster', () => {
  const rng = makeRng(6);
  for (let i = 0; i < 50; i++) {
    const m = rollModule(rng, { t: 520, loadout: emptyLoadout(), source: 'core' });
    assert.equal(m.slot, 'booster');
    assert.equal(m.id, 'limiter');
  }
});

test('leveling up raises base stats and asks for a level-up pick (not a module)', () => {
  const game = createGame({ seed: 1 });
  game.spawning = false;
  const atk0 = game.stats.atkMult, hp0 = game.stats.maxHp;
  addXp(game, 1000);
  update(game, 0.02, idle);
  assert.equal(game.state, 'levelup');
  assert.equal(game.currentOffer, null);
  assert.ok(game.level > 3);
  assert.ok(game.stats.atkMult > atk0 && game.stats.maxHp > hp0);
});

test('a picked-up module can be equipped; the same one again upgrades it without asking', () => {
  const game = createGame({ seed: 1 });
  game.spawning = false;
  game.offerQueue.push({ id: 'ram', slot: 'bow', r: 1, source: 'drop' });
  update(game, 0.02, idle);
  assert.equal(game.state, 'offer');
  resolveOffer(game, true);
  assert.equal(game.state, 'play');
  const atk1 = game.stats.atkMult;
  game.offerQueue.push({ id: 'ram', slot: 'bow', r: 0, source: 'drop' });
  update(game, 0.02, idle);
  assert.equal(game.state, 'play', 'no prompt for a duplicate');
  assert.equal(game.loadout.bow.plus, 1);
  assert.equal(game.loadout.bow.r, 1, 'keeps the higher rarity');
  assert.ok(game.stats.atkMult > atk1);
});

test('more max HP also raises current HP', () => {
  const game = createGame({ seed: 1 });
  game.spawning = false;
  const hp0 = game.ship.hp;
  game.offerQueue.push({ id: 'plating', slot: 'armor', r: 2 });
  update(game, 0.02, idle);
  resolveOffer(game, true);
  assert.ok(game.ship.hp > hp0);
  assert.ok(game.stats.maxHp > hp0);
});

test('max speed grows a little with every level', () => {
  const game = createGame({ seed: 1 });
  game.spawning = false;
  const base = game.stats.maxSpeed;
  game.debug.autoOffer = 'discard';
  addXp(game, 1e4);
  update(game, 0.02, idle);
  assert.ok(game.level >= 5);
  const expected = base * (1 + CONFIG.levelSpeedGrowth * game.level);
  assert.ok(Math.abs(game.stats.maxSpeed - expected) < 1e-6, `${game.stats.maxSpeed} vs ${expected}`);
});

test('enclosure blasts are epic/legendary portal drops; obsolete charge modules stay out of portal rolls', () => {
  assert.deepEqual(moduleDef('loopBurst').rarities, [2, 3]);
  const epic = computeStats({}, { ...emptyLoadout(), gun: { id: 'loopBurst', r: 2 } }).loopBurst;
  const legend = computeStats({}, { ...emptyLoadout(), gun: { id: 'loopBurst', r: 3 } }).loopBurst;
  assert.ok(legend.mult > epic.mult); assert.equal(epic.splash, false); assert.equal(legend.splash, true);
  const rng = makeRng(24), seen = new Set();
  for (const scheme of ['portal', 'hyper']) for (let i = 0; i < 1000; i++) {
    const m = rollModule(rng, { t: 500, loadout: emptyLoadout(), source: 'capsule', danger: 1, scheme });
    if (scheme === 'portal') {
      seen.add(m.id);
      assert.ok(!['chargeWave', 'quickCharge', 'regenGen'].includes(m.id));
    } else assert.notEqual(m.id, 'loopBurst');
  }
  assert.ok(seen.has('loopBurst'), 'the new module is obtainable through normal loot');
});
