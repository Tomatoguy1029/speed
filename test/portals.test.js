import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../src/config.js';
import { createGame, update, addXp } from '../src/world.js';
import { createEnemy } from '../src/enemies.js';
import { placePortal, dropPortal, portalTarget, portalReach, portalChoices } from '../src/portals.js';

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
function portalArrive(g, direction) {
  portalFrame(g, { portalSelect: direction });
  portalFrame(g, { dash: true });
  for (let i = 0; i < 300 && (g.portalDash?.phase === 'hop' || g.hitstop > 0); i++) portalFrame(g);
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

test('portal dash traverses and attacks the path, emits the equipped arrival wave, then waits in slow time', () => {
  const g = portalQuiet(); portalAnchor(g, 0); portalAnchor(g, 600); g.ship.x = 0;
  const body = createEnemy('drifter', 1, 300, -3000);
  const nearby = createEnemy('swarm', 1, 620, -2900);
  g.enemies.push(body, nearby);
  portalFrame(g, { dash: true });
  assert.equal(g.dashMeter, 0);
  portalFrame(g, { portalSelect: portalRight });
  portalFrame(g, { dash: true });
  assert.ok(g.ship.x > 0 && g.ship.x < 600, 'moves through space, not a teleport');
  for (let i = 0; i < 300 && (g.portalDash?.phase === 'hop' || g.hitstop > 0); i++) portalFrame(g);
  assert.ok(body.dead, 'path destroys enemies');
  assert.ok(nearby.dead, 'arrival wave destroys enemies outside the path');
  assert.equal(g.portalDash?.phase, 'choose');
  assert.ok(Math.abs(g.ship.x - 600) < 1e-6);
  portalFrame(g);
  assert.equal(g.timeScale, CONFIG.portalChooseScale);
  assert.equal(g.portals.find((p) => p.manual && p.x === 600).uses, Infinity);
});

test('a dropped destination loses one use per arrival and disappears after three; anchors remain', () => {
  const g = portalQuiet(); portalAnchor(g, 0); g.rng = () => 0;
  dropPortal(g, 600, -3000); const p = g.portals.find((n) => !n.manual);
  for (let i = 0; i < CONFIG.portalDropUses; i++) {
    g.ship.x = 0; g.ship.y = -3000; g.ship.vx = 0; g.ship.vy = 0;
    g.portalDash = null; g.dashMeter = 1;
    portalFrame(g, { dash: true }); portalArrive(g, portalRight);
    assert.equal(p.uses, CONFIG.portalDropUses - i - 1);
  }
  assert.ok(!g.portals.includes(p));
  assert.equal(g.portals.filter((n) => n.manual).length, 1);
});

test('buffered direction is resolved from the arrival point and the distance budget bounds permanent loops', () => {
  const g = portalQuiet(); portalAnchor(g, 0); portalAnchor(g, 600); portalAnchor(g, 600, 600);
  g.ship.x = 0; g.ship.y = -3000;
  portalFrame(g, { dash: true });
  portalFrame(g, { portalSelect: portalRight });
  portalFrame(g, { dash: true });
  portalFrame(g, { portalSelect: portalDown });
  for (let i = 0; i < 200 && (g.portalDash?.hops || 0) < 2; i++) portalFrame(g);
  assert.equal(g.portalDash?.hops, 2);
  assert.ok(Math.abs(g.ship.x - 600) < 1e-6 && Math.abs(g.ship.y + 2400) < 1e-6);
  portalFrame(g, { cancelDash: true }); // voluntarily exit before testing the permanent loop
  g.ship.x = 0; g.ship.y = -3000; g.ship.vx = 0; g.ship.vy = 0; g.dashMeter = 1;
  g.portals = g.portals.filter((p) => p.y === -3000);
  portalFrame(g, { dash: true });
  for (let i = 0; i < 5 && g.portalDash; i++) portalArrive(g, i % 2 ? portalLeft : portalRight);
  assert.equal(g.portalDash, null, 'permanent nodes do not permit infinite attacks');
});

test('no route leaves the gauge intact; waiting automatically departs; XP refills; growth extends reach', () => {
  const g = portalQuiet(); portalFrame(g, { dash: true });
  assert.equal(g.dashMeter, 1); assert.equal(g.portalDash, null);
  portalAnchor(g, 0); portalAnchor(g, 600); g.ship.x = 0;
  portalFrame(g, { dash: true });
  for (let i = 0; i < 70 && g.portalDash?.phase === 'choose'; i++) portalFrame(g, {}, 0.05);
  assert.equal(g.portalDash?.phase, 'hop');
  portalFrame(g, { cancelDash: true });
  assert.equal(g.portalDash, null);
  addXp(g, 2); assert.ok(g.dashMeter > 0);
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
  portalFrame(g, { dash: true }); portalArrive(g, portalRight);
  assert.equal(g.portalDash, null);
  assert.ok(g.ship.x < 600 && g.ship.hp < g.stats.maxHp);
  assert.ok(g.events.some((ev) => ev.type === 'bounce'));
});


test('entering a portal automatically launches; placement and staying inside do not retrigger', () => {
  const g = portalQuiet();
  portalAnchor(g, 0); portalAnchor(g, 600);
  g.ship.x = -90; g.ship.vx = 200; g.portalTouch = null;
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
  portalFrame(placed, { place: true });
  assert.equal(placed.portalDash, null, 'placing under yourself does not activate it');
});

test('numbered choices distinguish portals in the same direction and selection never launches before confirmation', () => {
  const g = portalQuiet();
  portalAnchor(g, 0); portalAnchor(g, 300); portalAnchor(g, 650); g.ship.x = 0;
  portalFrame(g, { dash: true });
  const choices = portalChoices(g);
  assert.equal(choices.length, 2);
  portalFrame(g, { portalIndex: 2 });
  assert.equal(g.portalDash.phase, 'choose');
  assert.equal(g.portalDash.next, choices[1].portal);
  assert.equal(g.portalPreview, choices[1].portal);
  assert.ok(g.portalDash.timeLeft > 2.5);
  portalFrame(g, { dash: true });
  assert.equal(g.portalDash.target, choices[1].portal);
});
