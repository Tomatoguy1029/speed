import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { createGame, update, addXp, refreshStats } from '../src/world.js';
import { tracePortalLoop } from '../src/portal-loops.js';
import { createEnemy } from '../src/enemies.js';
import { buildIntent } from '../src/controls.js';
import { placePortal, dropPortal, portalReach, portalChoices, checkPortalEntry } from '../src/portals.js';

const portalIdle = { move: { x: 0, y: 0 }, charging: false, release: false, snap: null };
const portalRight = { x: 1, y: 0 }, portalLeft = { x: -1, y: 0 }, portalDown = { x: 0, y: 1 };
function portalQuiet() {
  const g = createGame({ seed: 1, scheme: 'portal' });
  g.spawning = false; g.field.moons = []; g.field.dust = [];
  g.ship.x = 0; g.ship.y = -3000; g.ship.vx = 0; g.ship.vy = 0;
  g.debug.autoOffer = 'better';
  return g;
}
function portalFrame(g, input = {}, dt = 0.02) { update(g, dt, { ...portalIdle, ...input }); }
function portalAnchor(g, x, dy = 0) { g.ship.x = x; g.ship.y = -3000 + dy; return placePortal(g); }
function portalTap(g) { portalFrame(g, buildIntent({ dash: true, space: false, release: true, releaseSource: 'space', move: portalIdle.move }, 'portal')); }
function portalMount(g) { g.portalTouch = null; g.portalEntryT = 0; checkPortalEntry(g, g.ship.x - 90, g.ship.y); }
function portalStart(g) { portalMount(g); portalTap(g); }
function portalPick(g, target) {
  const count = portalChoices(g).length;
  for (let i = 0; i < count && g.portalDash.next !== target; i++) portalFrame(g, { portalCycle: 1 }, 0);
  assert.equal(g.portalDash.next, target);
}
function portalArrive(g, direction) {
  if (g.portalDash?.phase === 'choose' && direction) {
    const target = portalChoices(g).map((c) => c.portal).sort((a, b) => {
      const score = (p) => (direction.x * (p.x - g.ship.x) + direction.y * (p.y - g.ship.y)) / Math.hypot(p.x - g.ship.x, p.y - g.ship.y);
      return score(b) - score(a);
    })[0];
    portalPick(g, target); portalTap(g);
  }
  for (let i = 0; i < 300 && (g.portalDash?.phase === 'hop' || g.hitstop > 0); i++) portalFrame(g);
}

test('portal drops are disabled by default; enabling them preserves spacing and refill limits', () => {
  const g = portalQuiet(); g.rng = () => 0;
  dropPortal(g, 600, -3000);
  assert.equal(g.portals.length, 0);
  const previousChance = CONFIG.portalDropChance;
  try {
    CONFIG.portalDropChance = 0.18;
    dropPortal(g, 600, -3000);
    const p = g.portals[0]; p.uses = 1; g.t = CONFIG.portalRefillInterval + 0.1;
    for (let i = 0; i < 100; i++) dropPortal(g, 600 + i % 30, -3000);
    assert.equal(g.portals.length, 1); assert.equal(p.uses, 2);
    dropPortal(g, 600 + CONFIG.portalSpacing + 10, -3000);
    assert.equal(g.portals.length, 2);
    CONFIG.portalDropChance = 0; g.t += CONFIG.portalRefillInterval;
    dropPortal(g, p.x, p.y);
    assert.equal(p.uses, 2, 'disabled drops do not replenish existing portals');
  } finally { CONFIG.portalDropChance = previousChance; }
});

test('portal traversal attacks the path and arrival; selection changes do not depart; waiting allows enemy fire', () => {
  const g = portalQuiet(); portalAnchor(g, 0); portalAnchor(g, 600); const next = portalAnchor(g, 600, 600);
  g.ship.x = 0; g.ship.y = -3000;
  const body = createEnemy('drifter', 1, 300, -3000), nearby = createEnemy('swarm', 1, 620, -2900);
  g.enemies.push(body, nearby); portalStart(g);
  assert.ok(g.ship.x > 0 && g.ship.x < 600);
  portalArrive(g); assert.ok(body.dead); assert.ok(nearby.dead);
  assert.equal(g.portalDash.phase, 'choose'); assert.equal(g.portalDash.next, next);
  const chaser = createEnemy('swarm', 1, 1100, -3000); g.enemies.push(chaser);
  const bullet = { kind: 'bullet', x: 680, y: -3000, vx: -100, vy: 0, r: 3, dmg: 7, slow: 0, life: 5 };
  g.ebullets.push(bullet); const hp = g.ship.hp;
  for (let i = 0; i < 40; i++) portalFrame(g, { portalCycle: i === 0 ? 1 : 0 }, 0.1);
  assert.equal(g.portalDash.phase, 'choose', 'there is no timed automatic departure');
  assert.equal(g.timeScale, 1); assert.ok(g.ship.hp < hp && chaser.x < 1100);
  portalTap(g); assert.equal(g.portalDash.phase, 'hop'); assert.equal(g.portalDash.target, next);
});

test('entry mounts without a gauge or automatic departure; placement under the ship does not activate', () => {
  const g = portalQuiet(); portalAnchor(g, 0); portalAnchor(g, 600);
  g.ship.x = -90; g.ship.vx = 200; g.portalTouch = null;
  for (let i = 0; i < 30 && !g.portalDash; i++) portalFrame(g);
  assert.equal(g.portalDash.phase, 'choose'); assert.equal(g.ship.x, 0);
  const placed = portalQuiet(); portalAnchor(placed, 600); placed.ship.x = 0;
  portalFrame(placed, buildIntent({ place: true, move: portalIdle.move }, 'portal'));
  assert.equal(placed.portals.length, 2); assert.equal(placed.portalDash, null);
});

test('A/D cycles all reachable portals clockwise and back, including collinear and ninth candidates', () => {
  const g = portalQuiet(); portalAnchor(g, 0);
  for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2; portalAnchor(g, 650 * Math.sin(a), -650 * Math.cos(a)); }
  g.portals.push({ id: ++g.portalSerial, manual: true, uses: Infinity, x: 0, y: -3350 });
  g.ship.x = 0; g.ship.y = -3000; portalMount(g);
  const choices = portalChoices(g); assert.equal(choices.length, 11);
  const seen = new Set([g.portalDash.next]);
  for (let i = 0; i < choices.length; i++) { portalFrame(g, { portalCycle: 1 }); seen.add(g.portalDash.next); }
  assert.equal(seen.size, 11); assert.equal(g.portalDash.phase, 'choose');
  const original = g.portalDash.next;
  portalFrame(g, { portalCycle: -1 }); portalFrame(g, { portalCycle: 1 }); assert.equal(g.portalDash.next, original);
  g.field.moons = [{ x: 0, y: -3200, r: 80, gm: 0 }];
  assert.ok(!portalChoices(g).some((c) => c.portal.y < -3000 && c.portal.x === 0), 'blocked edges are not selectable');
});

test('undirected edges close a triangle, survive auto-exit, and unlock only after ten real play seconds', () => {
  const g = portalQuiet(), a = portalAnchor(g, 0), b = portalAnchor(g, 600), c = portalAnchor(g, 300, 500);
  g.ship.x = 0; g.ship.y = -3000; portalMount(g); portalPick(g, b); portalTap(g); portalArrive(g);
  assert.ok(!portalChoices(g).some((choice) => choice.portal === a));
  portalPick(g, c); portalTap(g); portalArrive(g);
  const attack = g.portalDash;
  portalPick(g, a); portalTap(g); portalArrive(g);
  assert.equal(attack.usedEdges.size, 3); assert.equal(attack.hops, 3);
  assert.equal(g.portalDash, null, 'the closed triangle exhausts every edge and leaves automatically');
  g.ship.x = a.x; g.ship.y = a.y; portalTap(g);
  assert.equal(g.portalDash, null, 'leaving does not reset cooled-down edges');
  const expiry = Math.max(...g.portalCooldowns.values()), clock = g.portalClock;
  g.state = 'paused'; portalFrame(g, {}, 0.1);
  assert.equal(g.portalClock, clock, 'pause does not advance cooldowns');
  g.state = 'play'; g.hitstop = 20;
  while (g.portalClock < expiry - 0.001) portalFrame(g, {}, Math.min(0.1, expiry - 0.001 - g.portalClock));
  assert.ok(!portalChoices(g).some((choice) => choice.portal === c), 'the last edge stays blocked until ten seconds after arrival');
  portalFrame(g, {}, 0.002); assert.equal(g.portalCooldowns.size, 0);
  g.ship.x = a.x; g.ship.y = a.y; portalTap(g); assert.equal(g.portalDash.target, c);
});

test('manual exit and re-entry near a portal cannot bypass an edge cooldown; a different edge remains usable', () => {
  const g = portalQuiet(), a = portalAnchor(g, 0), b = portalAnchor(g, 600), c = portalAnchor(g, 600, 600);
  g.ship.x = a.x; g.ship.y = a.y; portalStart(g); portalArrive(g);
  portalFrame(g, { portalPressed: true, portalHolding: true, portalHeldTime: 0.5 });
  assert.equal(g.portalDash, null);
  g.ship.x = b.x + 12; g.ship.y = b.y;
  // Even a recreated portal at the same coordinates shares the original cooldown.
  g.portals = g.portals.filter((p) => p !== a);
  const replacement = portalAnchor(g, a.x);
  g.ship.x = b.x + 12; g.ship.y = b.y; portalTap(g);
  assert.equal(g.portalDash.target, c);
  assert.ok(!portalChoices(g, b).some((choice) => choice.portal === replacement));
  const waiting = portalQuiet(), origin = portalAnchor(waiting, 0), target = portalAnchor(waiting, 600);
  const next = portalAnchor(waiting, 600, 600);
  waiting.ship.x = origin.x; waiting.ship.y = origin.y; portalStart(waiting); portalArrive(waiting);
  waiting.hitstop = 20;
  for (let i = 0; i < 101; i++) portalFrame(waiting, {}, 0.1);
  assert.equal(waiting.portalCooldowns.size, 0, 'hitstop and world slowdown do not stretch the real-time cooldown');
  assert.equal(waiting.portalDash.currentPortal, target.id);
  assert.ok(!portalChoices(waiting).some((choice) => choice.portal === origin), 'expiry still cannot reuse an edge in the same attack');
  assert.ok(portalChoices(waiting).some((choice) => choice.portal === next));
});

test('an exhausted connection finishes its hop and arrival wave before auto-exit; held Space cannot re-enter', () => {
  const g = portalQuiet(); portalAnchor(g, 0); const b = portalAnchor(g, 600);
  g.ship.x = 0; portalStart(g);
  assert.equal(g.portalDash.phase, 'hop', 'an empty next-route list does not interrupt the current hop');
  assert.equal(g.portalDash.next, null);
  const nearby = createEnemy('swarm', 1, 620, -2900); g.enemies.push(nearby);
  const attack = g.portalDash;
  portalFrame(g, { portalPressed: true, portalHolding: true }, 0.01);
  for (let i = 0; i < 300 && (g.portalDash?.phase === 'hop' || g.hitstop > 0); i++) portalFrame(g, { portalHolding: true });
  assert.equal(attack.hops, 1); assert.ok(nearby.dead, 'the final arrival still attacks');
  assert.equal(g.portalDash, null); assert.ok(g.ship.x >= b.x);
  assert.ok(g.ship.vx > 0); assert.equal(g.portalPreview, null);
  assert.ok(g.portalEntryT > g.t);
  assert.equal(g.portalSpace.consumed, true);
  portalFrame(g, { portalReleased: true, portalHeldTime: 0.35 });
  assert.equal(g.portalDash, null);
  // A route becoming unavailable during selection also leaves without waiting for a hop.
  const waiting = portalQuiet(); portalAnchor(waiting, 0); const next = portalAnchor(waiting, 600);
  waiting.ship.x = 0; portalMount(waiting);
  portalFrame(waiting, { portalPressed: true, portalHolding: true }, 0.01);
  waiting.portals = waiting.portals.filter((p) => p !== next);
  portalFrame(waiting, { portalHolding: true }, 0.01);
  assert.equal(waiting.portalDash, null); assert.equal(waiting.portalSpace.consumed, true);
  portalFrame(waiting, { portalReleased: true, portalHeldTime: 0.03 });
  assert.equal(waiting.portalDash, null);
});

test('Space distinguishes tap from 0.5-second hold and release after leaving cannot launch again', () => {
  const g = portalQuiet(); portalAnchor(g, 0); portalAnchor(g, 600); g.ship.x = 0; portalMount(g);
  portalFrame(g, { portalPressed: true, portalHolding: true }, 0.01);
  portalFrame(g, { portalHolding: true, portalHeldTime: 0.49 }, 0.01);
  assert.equal(g.portalDash.phase, 'choose', 'a held Space does not prematurely hop');
  portalFrame(g, { portalHolding: true, portalHeldTime: 0.5 }, 0.01);
  assert.equal(g.portalDash, null);
  portalFrame(g, { portalReleased: true, portalHeldTime: 0.51 }); assert.equal(g.portalDash, null);
  // A complete long press between physics frames must also be recognized on release.
  const released = portalQuiet(); portalAnchor(released, 0); portalAnchor(released, 600); released.ship.x = 0; portalMount(released);
  released.hitstop = 2;
  portalFrame(released, { portalPressed: true, portalReleased: true, portalHeldTime: 0.6 });
  assert.equal(released.portalDash, null);
});

test('selection and a Space tap during flight buffer the chosen next edge; holding exits during flight', () => {
  const g = portalQuiet(); portalAnchor(g, 0); const b = portalAnchor(g, 600), c = portalAnchor(g, 600, 600);
  const other = portalAnchor(g, 600, -600); g.ship.x = 0; g.ship.y = -3000;
  portalMount(g); portalPick(g, b); portalTap(g);
  portalPick(g, other); portalFrame(g, { portalCycle: 1 }); assert.equal(g.portalDash.next, c);
  portalTap(g);
  for (let i = 0; i < 100 && g.portalDash.hops < 1; i++) portalFrame(g);
  assert.equal(g.portalDash.phase, 'hop'); assert.equal(g.portalDash.target, c);
  const pos = g.ship.y;
  portalFrame(g, { portalPressed: true, portalHolding: true, portalHeldTime: 0.5 }, 0.001);
  assert.equal(g.portalDash, null); assert.ok(g.ship.y < -2400 && g.ship.y >= pos);
});

test('Space taps reach the nearest small portal with an empty gauge; blocked routes and growth remain respected', () => {
  const g = portalQuiet(), small = portalAnchor(g, 80); g.ship.x = 0;
  portalTap(g); assert.equal(g.portalDash.target, small);
  const blocked = portalQuiet(); portalAnchor(blocked, 300); const clear = portalAnchor(blocked, 0, 600); blocked.ship.y = -3000;
  blocked.field.planet = { x: 150, y: -3000, r: 30, gm: 0 };
  portalTap(blocked); assert.equal(blocked.portalDash.target, clear);
  const initial = portalReach(blocked); blocked.stats.maxSpeed *= 2; assert.equal(portalReach(blocked), initial * 2);
});

test('armored enemies still interrupt portal travel with immediate damage', () => {
  const g = portalQuiet(); portalAnchor(g, 0); portalAnchor(g, 600); g.ship.x = 0;
  const e = createEnemy('armored', 1, 300, -3000); e.armor = 100; e.hp = e.maxHp = 1000; e.weakArc = 0;
  g.enemies.push(e); portalStart(g); portalArrive(g);
  assert.equal(g.portalDash, null); assert.ok(g.ship.x < 600 && g.ship.hp < g.stats.maxHp);
  assert.ok(g.events.some((ev) => ev.type === 'bounce'));
});

function portalLoopEnemy(g, x, y) {
  const e = createEnemy('swarm', 1, x, y);
  e.speed = 0; e.vx = 0; e.vy = 0;
  g.enemies.push(e);
  return e;
}

function portalLoopEquip(g, rarity) {
  g.loadout.gun = { id: 'loopBurst', r: rarity };
  refreshStats(g);
}

test('an equipped enclosure module explodes only after the actual four-hop path closes', () => {
  const g = portalQuiet(); portalLoopEquip(g, 2);
  portalAnchor(g, 0); portalAnchor(g, 600); portalAnchor(g, 600, 600); portalAnchor(g, 0, 600);
  g.ship.x = 0; g.ship.y = -3000;
  const inside = portalLoopEnemy(g, 300, -2700), outside = portalLoopEnemy(g, 900, -2700);
  portalStart(g); portalArrive(g);
  portalArrive(g, portalDown); portalArrive(g, portalLeft);
  assert.ok(!inside.dead, 'a planned or open route does not explode');
  portalArrive(g, { x: 0, y: -1 });
  assert.ok(inside.dead); assert.ok(!outside.dead);
  assert.ok(g.events.some((ev) => ev.type === 'kill' && ev.cause === 'portalLoop'));
  assert.equal(g.events.filter((ev) => ev.cause === 'portalLoop' && ev.type === 'explode').length, 1);
  assert.ok(g.fx.loops.length > 0, 'closed-area feedback survives the end of the chain');
});

test('legendary enclosure splashes outside; epic does not; a consumed loop cannot repeat its blast', () => {
  for (const rarity of [2, 3]) {
    const g = portalQuiet(); portalLoopEquip(g, rarity);
    const d = { speed: 1000, loopPath: [
      { x: 0, y: -3000 }, { x: 600, y: -3000 }, { x: 600, y: -2400 }, { x: 0, y: -2400 },
    ] };
    const inside = portalLoopEnemy(g, 50, -2700), nearby = portalLoopEnemy(g, -20, -2700);
    const far = portalLoopEnemy(g, -200, -2700);
    tracePortalLoop(g, d, 0, -2400, 0, -3000);
    assert.ok(inside.dead); assert.equal(nearby.dead, rarity === 3); assert.ok(!far.dead);
    tracePortalLoop(g, d, 0, -2400, 0, -3000);
    assert.equal(g.events.filter((ev) => ev.cause === 'portalLoop' && ev.type === 'explode').length, 1);
  }
});

test('crossing an old segment closes the actual polygon mid-hop; retracing and unequipped routes do nothing', () => {
  const g = portalQuiet(); portalLoopEquip(g, 2);
  const d = { speed: 1000, loopPath: [{ x: 0, y: -3000 }, { x: 600, y: -3000 }, { x: 600, y: -2400 }] };
  const inside = portalLoopEnemy(g, 550, -2850), outside = portalLoopEnemy(g, 300, -2850);
  tracePortalLoop(g, d, 600, -2400, 300, -3300);
  assert.ok(inside.dead); assert.ok(!outside.dead);
  assert.deepEqual(d.loopPath, [{ x: 0, y: -3000 }, { x: 400, y: -3000 }]);
  const count = g.fx.loops.length;
  tracePortalLoop(g, d, 400, -3000, 0, -3000);
  assert.equal(g.fx.loops.length, count);
  const plain = portalQuiet();
  tracePortalLoop(plain, { speed: 1000, loopPath: [{ x: 0, y: -3000 }, { x: 600, y: -3000 }, { x: 600, y: -2400 }] }, 600, -2400, 0, -3000);
  assert.equal(plain.fx.loops.length, 0);
});
