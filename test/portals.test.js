import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { createGame, update, addXp, refreshStats } from '../src/world.js';
import { tracePortalLoop } from '../src/portal-loops.js';
import { createEnemy } from '../src/enemies.js';
import { buildIntent } from '../src/controls.js';
import { placePortal, dropPortal, portalTarget, portalReach, portalChoices, portalSectors, checkPortalEntry } from '../src/portals.js';

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
function portalStart(g) {
  g.portalTouch = null; g.portalEntryT = 0;
  checkPortalEntry(g, g.ship.x - 90, g.ship.y);
}
function portalArrive(g, direction) {
  if (g.portalDash?.phase === 'choose') {
    portalFrame(g, { portalSelect: direction });
  }
  for (let i = 0; i < 300 && (g.portalDash?.directionInput || g.portalDash?.phase === 'hop' || g.hitstop > 0); i++) portalFrame(g);
}

test('portal drops stay separated and nearby crowd kills replenish only once per interval', () => {
  const g = portalQuiet(); g.rng = () => 0;
  dropPortal(g, 600, -3000);
  const p = g.portals[0]; p.uses = 1;
  g.t = CONFIG.portalRefillInterval + 0.1;
  for (let i = 0; i < 100; i++) dropPortal(g, 600 + i % 30, -3000);
  assert.equal(g.portals.length, 1);
  assert.equal(p.uses, 2);
  dropPortal(g, 600 + CONFIG.portalSpacing + 10, -3000);
  assert.equal(g.portals.length, 2);
  assert.ok(Math.hypot(g.portals[0].x - g.portals[1].x, g.portals[0].y - g.portals[1].y) >= CONFIG.portalSpacing);
});

test('portal dash attacks the path and arrival; waiting keeps enemies and bullets moving and can hurt the ship', () => {
  const g = portalQuiet(); portalAnchor(g, 0); portalAnchor(g, 600); g.ship.x = 0;
  const body = createEnemy('drifter', 1, 300, -3000);
  const nearby = createEnemy('swarm', 1, 620, -2900);
  g.enemies.push(body, nearby);
  portalStart(g);
  assert.equal(g.dashMeter, 1, 'portal travel does not consume the gauge');
  portalFrame(g);
  assert.ok(g.ship.x > 0 && g.ship.x < 600, 'moves through space, not a teleport');
  for (let i = 0; i < 300 && (g.portalDash?.phase === 'hop' || g.hitstop > 0); i++) portalFrame(g);
  assert.ok(body.dead, 'path destroys enemies');
  assert.ok(nearby.dead, 'arrival wave destroys enemies outside the path');
  assert.equal(g.portalDash?.phase, 'choose');
  assert.ok(Math.abs(g.ship.x - 600) < 1e-6);
  portalFrame(g);
  assert.equal(g.timeScale, 1);
  assert.equal(g.portals.find((p) => p.manual && p.x === 600).uses, Infinity);
  const chaser = createEnemy('swarm', 1, g.ship.x + 500, g.ship.y);
  g.enemies.push(chaser);
  const bullet = { kind: 'bullet', x: g.ship.x + 80, y: g.ship.y, vx: -100, vy: 0, r: 3, dmg: 7, slow: 0, life: 5 };
  g.ebullets.push(bullet);
  const hp = g.ship.hp, bx = bullet.x, ex = chaser.x;
  portalFrame(g, {}, 0.1);
  assert.ok(bx - bullet.x > 9, 'bullet advances at normal speed during the selection window');
  assert.ok(chaser.x < ex, 'enemy keeps chasing');
  for (let i = 0; i < 12; i++) portalFrame(g, {}, 0.05);
  assert.equal(g.portalDash?.phase, 'choose');
  assert.ok(g.ship.hp < hp, 'waiting at the portal gives no immunity to incoming fire');
  portalFrame(g, buildIntent({ portalSelect: portalLeft, move: portalLeft }, 'portal'));
  for (let i = 0; i < 5 && g.portalDash?.directionInput; i++) portalFrame(g);
  assert.equal(g.portalDash?.phase, 'hop', 'a direction press alone departs after the short chord window');
  assert.equal(g.portalDash.target.x, 0);
});

test('a dropped destination loses one use per arrival and disappears after three; anchors remain', () => {
  const g = portalQuiet(); portalAnchor(g, 0); g.rng = () => 0;
  dropPortal(g, 600, -3000); const p = g.portals.find((n) => !n.manual);
  for (let i = 0; i < CONFIG.portalDropUses; i++) {
    g.ship.x = 0; g.ship.y = -3000; g.ship.vx = 0; g.ship.vy = 0;
    g.portalDash = null; g.dashMeter = 1;
    portalStart(g); portalArrive(g, portalRight);
    assert.equal(p.uses, CONFIG.portalDropUses - i - 1);
  }
  assert.ok(!g.portals.includes(p));
  assert.equal(g.portals.filter((n) => n.manual).length, 1);
});

test('buffered direction is resolved from the arrival point and the distance budget bounds permanent loops', () => {
  const g = portalQuiet(); portalAnchor(g, 0); portalAnchor(g, 600); portalAnchor(g, 600, 600);
  g.ship.x = 0; g.ship.y = -3000;
  portalStart(g);
  portalFrame(g, { portalSelect: portalDown });
  for (let i = 0; i < 200 && (g.portalDash?.hops || 0) < 2; i++) portalFrame(g);
  assert.equal(g.portalDash?.hops, 2);
  const path = g.portalDash.path.map((p) => ({ ...p }));
  assert.deepEqual(path, [{ x: 0, y: -3000 }, { x: 600, y: -3000 }, { x: 600, y: -2400 }]);
  g.ship.trail = []; // ordinary trail history can expire without losing any completed segment
  portalFrame(g);
  assert.deepEqual(g.portalDash.path, path);
  assert.ok(Math.abs(g.ship.x - 600) < 1e-6 && Math.abs(g.ship.y + 2400) < 1e-6);
  portalFrame(g, { cancelDash: true }); // voluntarily exit before testing the permanent loop
  g.ship.x = 0; g.ship.y = -3000; g.ship.vx = 0; g.ship.vy = 0; g.dashMeter = 1;
  g.portals = g.portals.filter((p) => p.y === -3000);
  portalStart(g);
  for (let i = 0; i < 5 && g.portalDash; i++) portalArrive(g, i % 2 ? portalLeft : portalRight);
  assert.equal(g.portalDash, null, 'permanent nodes do not permit infinite attacks');
});

test('no route leaves the gauge intact; waiting automatically departs; growth extends reach', () => {
  const g = portalQuiet(); portalFrame(g, { nearestPortal: true });
  assert.equal(g.dashMeter, 1); assert.equal(g.portalDash, null);
  portalAnchor(g, 0); portalAnchor(g, 600); g.ship.x = 0;
  portalStart(g); portalArrive(g, portalRight);
  for (let i = 0; i < 70 && g.portalDash?.phase === 'choose'; i++) portalFrame(g, {}, 0.05);
  assert.equal(g.portalDash?.phase, 'hop');
  portalFrame(g, { cancelDash: true });
  assert.equal(g.portalDash, null);
  g.dashMeter = 0; addXp(g, 2); assert.equal(g.dashMeter, 0, 'portal XP does not refill an unused gauge');
  const initial = portalReach(g); g.stats.maxSpeed *= 2;
  assert.equal(portalReach(g), initial * 2);
});

test('obstacles exclude a route and armored enemies interrupt it with immediate damage', () => {
  const g = portalQuiet(); portalAnchor(g, 0); portalAnchor(g, 600); g.ship.x = 0;
  g.field.planet = { x: 300, y: -3000, r: 100, gm: 0 };
  assert.equal(portalTarget(g, portalRight), null);
  g.field.planet = { x: 0, y: 0, r: 100, gm: 0 };
  const e = createEnemy('armored', 1, 300, -3000);
  e.armor = 100; e.hp = e.maxHp = 1000; e.weakArc = 0;
  g.enemies.push(e);
  portalStart(g); portalArrive(g, portalRight);
  assert.equal(g.portalDash, null);
  assert.ok(g.ship.x < 600 && g.ship.hp < g.stats.maxHp);
  assert.ok(g.events.some((ev) => ev.type === 'bounce'));
});


test('entering a portal automatically launches; placement and staying inside do not retrigger', () => {
  const g = portalQuiet();
  portalAnchor(g, 0); portalAnchor(g, 600);
  g.ship.x = -90; g.ship.vx = 200; g.portalTouch = null; g.dashMeter = 0;
  for (let i = 0; i < 20 && !g.portalDash; i++) portalFrame(g);
  assert.equal(g.portalDash?.phase, 'hop');
  assert.equal(g.portalDash.target.x, 600);
  assert.equal(g.dashMeter, 0);
  portalArrive(g, portalRight);
  portalFrame(g, { cancelDash: true });
  g.dashMeter = 1;
  g.ship.vx = 0; g.ship.vy = 0;
  for (let i = 0; i < 40; i++) portalFrame(g);
  assert.equal(g.portalDash, null, 'remaining inside the arrival portal cannot restart');
  const placed = portalQuiet();
  portalAnchor(placed, 600); placed.ship.x = 0;
  portalFrame(placed, buildIntent({ place: true, move: portalIdle.move }, 'portal'));
  assert.equal(placed.portals.length, 2, 'B places a portal even with a charged gauge and reachable target');
  assert.equal(placed.dashMeter, 1);
  assert.equal(placed.portalDash, null, 'placing under yourself does not activate it');
});

test('numbered choices distinguish portals in the same direction and immediately depart', () => {
  const g = portalQuiet();
  portalAnchor(g, -600); portalAnchor(g, 0); portalAnchor(g, 300); portalAnchor(g, 650); g.ship.x = -600;
  portalStart(g); portalArrive(g, portalRight);
  g.portals = g.portals.filter((p) => p.x >= 0);
  const choices = portalChoices(g);
  assert.equal(choices.length, 2);
  portalFrame(g, { portalIndex: 2 });
  assert.equal(g.portalDash.phase, 'hop');
  assert.equal(g.portalDash.target, choices[1].portal);
});

test('Space launches toward the nearest portal without steering and can buffer the next nearest hop', () => {
  const g = portalQuiet();
  const near = portalAnchor(g, -300), origin = portalAnchor(g, 0);
  portalAnchor(g, 600); g.ship.x = 0; g.ship.hx = 1; g.ship.hy = 0; g.dashMeter = 0.35;
  portalFrame(g, buildIntent({ dash: true, move: portalIdle.move }, 'portal'));
  assert.equal(g.portalDash.target, near, 'nearest wins even behind the heading');
  assert.equal(g.dashMeter, 0.35, 'partly charged gauge is neither required nor consumed'); assert.equal(g.portals.length, 3, 'Space creates no portal');
  portalArrive(g);
  portalFrame(g, { nearestPortal: true });
  assert.equal(g.portalDash.phase, 'hop');
  assert.equal(g.portalDash.target, origin);
  portalFrame(g, { nearestPortal: true });
  for (let i = 0; i < 100 && g.portalDash.hops < 2; i++) portalFrame(g);
  assert.equal(g.portalDash.phase, 'hop', 'buffered Space departs without the three-second wait');
  assert.equal(g.portalDash.target, near);
});

test('nearest travel accepts a nearby small portal, excludes blocked routes, and works with an empty gauge', () => {
  const close = portalQuiet(), small = portalAnchor(close, 80); close.ship.x = 0;
  portalFrame(close, { nearestPortal: true });
  assert.equal(close.portalDash.target, small, 'a portal closer than the ordinary minimum hop is reachable');
  const g = portalQuiet();
  portalAnchor(g, 300); const clear = portalAnchor(g, 0, 600); g.ship.y = -3000;
  g.field.planet = { x: 150, y: -3000, r: 30, gm: 0 };
  portalFrame(g, { nearestPortal: true });
  assert.equal(g.portalDash.target, clear, 'nearest obstructed route is skipped');
  g.portalDash = null; g.dashMeter = 0;
  portalFrame(g, { nearestPortal: true });
  assert.equal(g.portalDash.target, clear); assert.equal(g.dashMeter, 0);
  const empty = portalQuiet(); portalFrame(empty, { nearestPortal: true });
  assert.equal(empty.portalDash, null); assert.equal(empty.dashMeter, 1);
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

test('WASD targets eight exclusive sectors, selecting the nearest in each even outside numbered choices', () => {
  const g = portalQuiet();
  const directions = [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]];
  const anchors = directions.map(([x, y]) => portalAnchor(g, x * 600 / Math.hypot(x, y), y * 600 / Math.hypot(x, y)));
  g.ship.x = 0; g.ship.y = -3000;
  for (const [i, [x, y]] of directions.entries()) assert.equal(portalTarget(g, { x, y }), anchors[i]);
  assert.deepEqual(portalSectors(g).map((s) => s.portal), anchors);
  g.portals = [anchors[7]];
  assert.equal(portalTarget(g, { x: 0, y: -1 }), null, 'upper-right is never borrowed by the upper sector');
  g.portals = Array.from({ length: 9 }, (_, i) => ({ id: i + 1, manual: true, uses: Infinity,
    x: i < 8 ? 110 + i * 50 : 0, y: i < 8 ? -3000 : -3800 }));
  assert.equal(portalChoices(g).length, 8);
  assert.equal(portalTarget(g, { x: 0, y: -1 }), g.portals[8], 'direction selection sees every reachable portal');
  g.field.moons = [{ x: 0, y: -3400, r: 80, gm: 0 }];
  assert.equal(portalTarget(g, { x: 0, y: -1 }), null, 'obstructed sectors count as exits');
});

test('an empty sector exits in that direction, keeps held movement, and cannot immediately re-enter', () => {
  const g = portalQuiet(); portalAnchor(g, 0); portalAnchor(g, 600); g.ship.x = 0;
  portalStart(g); portalArrive(g);
  const y = g.ship.y, x = g.ship.x;
  portalFrame(g, { portalSelect: { x: 0, y: -1 }, move: { x: 0, y: -1 } });
  for (let i = 0; i < 12; i++) portalFrame(g, { move: { x: 0, y: -1 } });
  assert.equal(g.portalDash, null);
  assert.ok(g.ship.y < y - 20 && Math.abs(g.ship.x - x) < 1e-6);
  assert.ok(g.ship.vy < 0 && Math.abs(g.ship.vx) < 1e-6);
});

test('staggered diagonal presses combine before choosing; an in-flight empty direction exits after arrival', () => {
  const g = portalQuiet(); portalAnchor(g, -600); portalAnchor(g, 0); const diagonal = portalAnchor(g, 500, -500);
  g.ship.x = -600; g.ship.y = -3000; portalStart(g); portalArrive(g);
  portalFrame(g, { portalSelect: { x: 0, y: -1 } });
  assert.equal(g.portalDash?.phase, 'choose', 'the first W press must not leave before D can form a diagonal');
  portalFrame(g, { portalSelect: { x: 1, y: -1 } });
  assert.equal(g.portalDash?.target, diagonal);
  const flight = portalQuiet(); portalAnchor(flight, 0); portalAnchor(flight, 600); portalAnchor(flight, 600, 600);
  flight.ship.x = 0; flight.ship.y = -3000; portalStart(flight);
  portalFrame(flight, { portalSelect: { x: 0, y: -1 } });
  assert.equal(flight.portalDash.phase, 'hop');
  portalArrive(flight);
  assert.equal(flight.portalDash, null);
  assert.ok(Math.abs(flight.ship.x - 600) < 1e-6 && flight.ship.vy < 0, 'the hop completes before leaving upward');
});
