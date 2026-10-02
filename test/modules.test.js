import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MODULES, SLOTS, computeStats, rollModule, moduleDef } from '../src/modules.js';
import { baseStats } from '../src/ship.js';
import { makeRng } from '../src/math.js';
import { createGame, update, addXp, resolveOffer } from '../src/world.js';

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

test('leveling up pauses for an offer; equipping replaces the slot', () => {
  const game = createGame({ seed: 1 });
  game.spawning = false;
  addXp(game, 1000);
  update(game, 0.02, idle);
  assert.equal(game.state, 'offer');
  const first = game.currentOffer;
  assert.ok(first);
  resolveOffer(game, true);
  const pick = (m) => ({ id: m.id, slot: m.slot, r: m.r });
  assert.deepEqual(game.loadout[first.slot], pick(first));
  // drain remaining offers by discarding
  while (game.state === 'offer') resolveOffer(game, false);
  assert.equal(game.state, 'play');
  assert.deepEqual(game.loadout[first.slot], pick(first));
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
