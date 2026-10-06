import { CONFIG } from './config.js';
import { segCircleT } from './math.js';
import { launchVelocity } from './ship.js';
import { attackPower } from './combat.js';
import { addText, addRing, explode } from './hits.js';
import { onLaunch } from './effects.js';
import { waveAlong, collideEnemies, damageShip } from './world.js';
import { tracePortalLoop } from './portal-loops.js';

export function portalGrowth(game) {
  return game.stats.maxSpeed / CONFIG.baseMaxSpeed * game.stats.rangeMult * game.stats.gaugeMax;
}

export function portalReach(game) {
  return CONFIG.portalReach * portalGrowth(game);
}

function portalClearLine(game, x, y, tx, ty) {
  return ![game.field.planet, ...game.field.moons].some((b) =>
    segCircleT(x, y, tx, ty, b.x, b.y, b.r + CONFIG.shipRadius) >= 0);
}

function portalNearby(game, x, y) {
  let best = null, dist = CONFIG.portalSpacing;
  for (const p of game.portals) {
    const d = Math.hypot(p.x - x, p.y - y);
    if (d < dist) { best = p; dist = d; }
  }
  return best;
}

function portalCreate(game, x, y, manual) {
  const p = { id: ++game.portalSerial, x, y, manual, uses: manual ? Infinity : CONFIG.portalDropUses, refillAt: game.t + CONFIG.portalRefillInterval };
  game.portals.push(p);
  addRing(game, x, y, 45, manual ? '#5fd8ff' : '#c995ff', 0.35);
  return p;
}

export function placePortal(game) {
  if (game.scheme !== 'portal' || game.portalDash) return null;
  const sh = game.ship;
  if ([game.field.planet, ...game.field.moons].some((b) => Math.hypot(sh.x - b.x, sh.y - b.y) <= b.r + CONFIG.shipRadius + 4)) return null;
  const near = portalNearby(game, sh.x, sh.y);
  if (near?.manual) { addText(game, sh.x, sh.y - 45, '近くに設置済み', '#9fe8ff'); return null; }
  if (game.portals.filter((p) => p.manual).length >= CONFIG.portalManualMax) {
    addText(game, sh.x, sh.y - 45, '設置上限', '#9fe8ff'); return null;
  }
  // A dropped portal can become a permanent anchor without creating an overlapping node.
  if (near) { near.manual = true; near.uses = Infinity; addRing(game, near.x, near.y, 45, '#5fd8ff'); return near; }
  const created = portalCreate(game, sh.x, sh.y, true);
  game.portalTouch = created.id;
  return created;
}

// Check spacing before rolling for a drop. A crowd can replenish one node, not create a pile.
export function dropPortal(game, x, y) {
  if (game.scheme !== 'portal' || CONFIG.portalDropChance <= 0) return;
  const near = portalNearby(game, x, y);
  if (near) {
    if (!near.manual && near.uses < CONFIG.portalDropUses && game.t >= near.refillAt) {
      near.uses++;
      near.refillAt = game.t + CONFIG.portalRefillInterval;
      addRing(game, near.x, near.y, 35, '#c995ff', 0.25);
    }
    return;
  }
  if (game.portals.filter((p) => !p.manual).length >= CONFIG.portalDropMax || game.rng() >= CONFIG.portalDropChance) return;
  if ([game.field.planet, ...game.field.moons].some((b) => Math.hypot(x - b.x, y - b.y) <= b.r + CONFIG.shipRadius + 4)) return;
  portalCreate(game, x, y, false);
}

function portalEdgeKey(a, b) {
  const pa = `${a.x},${a.y}`, pb = `${b.x},${b.y}`;
  return pa < pb ? `${pa}|${pb}` : `${pb}|${pa}`;
}

function portalEdgeUnavailable(game, a, b) {
  const key = portalEdgeKey(a, b);
  return game.portalDash?.usedEdges.has(key) || (game.portalCooldowns.get(key) ?? 0) > game.portalClock;
}

function portalAtShip(game) {
  return game.portals.find((p) => Math.hypot(p.x - game.ship.x, p.y - game.ship.y) < CONFIG.portalEntryRadius + CONFIG.shipRadius) ?? null;
}

export function portalChoices(game, origin = game.portalDash?.phase === 'hop' ? game.portalDash.target : portalAtShip(game) || game.ship) {
  const reach = Math.min(portalReach(game), game.portalDash?.remaining ?? Infinity);
  const angle = (p) => (Math.atan2(p.y - origin.y, p.x - origin.x) + Math.PI * 2.5) % (Math.PI * 2);
  return game.portals.filter((p) => {
    const dist = Math.hypot(p.x - origin.x, p.y - origin.y);
    return dist >= CONFIG.portalMinHop && dist <= reach && portalClearLine(game, origin.x, origin.y, p.x, p.y)
      && !portalEdgeUnavailable(game, origin, p);
  }).sort((a, b) => angle(a) - angle(b)
    || Math.hypot(a.x - origin.x, a.y - origin.y) - Math.hypot(b.x - origin.x, b.y - origin.y)
    || a.id - b.id).map((p, i) => ({ key: String(i + 1), portal: p }));
}

export function portalNearest(game) {
  if (game.portalDash) {
    const origin = game.portalDash.phase === 'hop' ? game.portalDash.target : game.ship;
    return portalChoices(game).map((c) => c.portal).sort((a, b) =>
      Math.hypot(a.x - origin.x, a.y - origin.y) - Math.hypot(b.x - origin.x, b.y - origin.y))[0] ?? null;
  }
  const sh = portalAtShip(game) || game.ship;
  let nearest = null, best = Math.min(portalReach(game), CONFIG.portalBudget * portalGrowth(game));
  for (const p of game.portals) {
    const dist = Math.hypot(p.x - sh.x, p.y - sh.y);
    if (dist < CONFIG.portalEntryRadius + CONFIG.shipRadius || dist > best
      || !portalClearLine(game, sh.x, sh.y, p.x, p.y) || portalEdgeUnavailable(game, sh, p)) continue;
    nearest = p; best = dist;
  }
  return nearest;
}

function portalDefaultNext(game) {
  const d = game.portalDash;
  const origin = d?.phase === 'hop' ? d.target : game.ship;
  let best = null, score = Infinity;
  for (const { portal: p } of portalChoices(game)) {
    const dx = p.x - origin.x, dy = p.y - origin.y, dist = Math.hypot(dx, dy);
    const alignment = (dx * game.ship.hx + dy * game.ship.hy) / dist;
    const penalty = (p.id === d?.previous ? 4 : 0) + (d?.visited.has(p.id) ? 2 : 0);
    const s = (penalty + 1 - alignment) * portalReach(game) + dist * 0.25;
    if (s < score) { best = p; score = s; }
  }
  return best;
}

function startPortalDash(game, entry = null, initialTarget = null) {
  if (!initialTarget && !portalChoices(game, entry || game.ship).length) return false;
  const budget = CONFIG.portalBudget * portalGrowth(game);
  if (entry) { game.ship.x = entry.x; game.ship.y = entry.y; }
  game.portalDash = { phase: 'choose', remaining: budget, budget, usedEdges: new Set(),
    hops: 0, next: null, explicitNext: false, currentPortal: entry?.id ?? null, previous: null,
    visited: new Set(entry ? [entry.id] : []), path: [{ x: game.ship.x, y: game.ship.y }],
    loopPath: [{ x: game.ship.x, y: game.ship.y }], departOnArrival: false };
  game.ship.charging = false;
  onLaunch(game);
  game.ship.boostT = game.stats.boostDuration;
  game.portalDash.next = initialTarget || portalDefaultNext(game);
  game.portalPreview = game.portalDash.next;
  return true;
}

// Sweep the movement segment so fast entries are detected even between physics ticks.
export function checkPortalEntry(game, x0, y0) {
  if (game.scheme !== 'portal' || game.portalDash || game.portalSpace.consumed) return;
  const sh = game.ship, R = CONFIG.portalEntryRadius + CONFIG.shipRadius;
  const previousTouch = game.portalTouch;
  game.portalTouch = game.portals.find((p) => Math.hypot(p.x - sh.x, p.y - sh.y) < R)?.id ?? null;
  if (game.t < game.portalEntryT) return;
  let entry = null, first = Infinity;
  for (const p of game.portals) {
    if (p.id === previousTouch) continue;
    const t = segCircleT(x0, y0, sh.x, sh.y, p.x, p.y, R);
    if (t >= 0 && t < first) { entry = p; first = t; }
  }
  if (entry) startPortalDash(game, entry);
}

export function stopPortalDash(game, message = '') {
  game.portalDash = null;
  game.portalPreview = null;
  game.portalEntryT = game.t + CONFIG.portalEntryCooldown;
  game.ship.boostT = game.stats.boostDuration;
  if (message) addText(game, game.ship.x, game.ship.y - 48, message, '#e8f6ff');
}

function portalLeave(game, direction) {
  const sh = game.ship, len = Math.hypot(direction.x, direction.y);
  stopPortalDash(game, 'ポータル離脱');
  game.portalPreview = null;
  sh.hx = direction.x / len; sh.hy = direction.y / len;
  const speed = game.stats.maxSpeed * CONFIG.steerCruise;
  sh.vx = sh.hx * speed; sh.vy = sh.hy * speed;
  sh.boostT = 0; sh.fadeT = 0;
}

export function handlePortalInput(game, input, realDt = 0) {
  if (game.scheme !== 'portal') return;
  const press = game.portalSpace;
  if (input.portalPressed) { press.armed = true; press.seconds = 0; press.consumed = false; }
  if (press.armed && input.portalHolding) press.seconds += realDt;
  if (press.armed && input.portalHeldTime !== undefined) press.seconds = Math.max(press.seconds, input.portalHeldTime);
  if (press.armed && !press.consumed && press.seconds >= CONFIG.portalExitHold) {
    press.consumed = true;
    if (game.portalDash) portalLeave(game, input.move?.x || input.move?.y ? input.move : { x: game.ship.hx, y: game.ship.hy });
  }
  const confirm = !!input.portalReleased && press.armed && !press.consumed;
  if (input.portalReleased || (!input.portalHolding && !input.portalPressed)) {
    press.armed = false; press.seconds = 0; press.consumed = false;
  }
  if (!game.portalDash) {
    if (input.place) placePortal(game);
    const nearest = portalNearest(game);
    game.portalPreview = nearest;
    if (confirm) {
      const entry = portalAtShip(game);
      if (nearest && startPortalDash(game, entry, nearest)) portalBeginHop(game, nearest, CONFIG.portalEntryRadius + CONFIG.shipRadius);
      else addText(game, game.ship.x, game.ship.y - 45, '到達できるポータルが必要', '#9fe8ff');
    }
    return;
  }
  const d = game.portalDash;
  portalRefreshNext(game);
  if (!game.portalDash) return;
  if (input.portalCycle) {
    const choices = portalChoices(game);
    if (choices.length) {
      const current = Math.max(0, choices.findIndex((c) => c.portal === d.next));
      const index = ((current + input.portalCycle) % choices.length + choices.length) % choices.length;
      d.next = choices[index].portal; d.explicitNext = true;
    }
  }
  game.portalPreview = d.next;
  if (confirm && d.next) {
    if (d.phase === 'choose') portalBeginHop(game, d.next);
    else d.departOnArrival = true;
  }
}

function portalBeginHop(game, target, minDistance = CONFIG.portalMinHop) {
  const d = game.portalDash, sh = game.ship;
  if (!target || !game.portals.includes(target)) return false;
  const len = Math.hypot(target.x - sh.x, target.y - sh.y);
  if (len < minDistance || len > Math.min(portalReach(game), d.remaining)
    || !portalClearLine(game, sh.x, sh.y, target.x, target.y)
    || portalEdgeUnavailable(game, sh, target)) return false;
  d.edgeKey = portalEdgeKey(sh, target);
  d.usedEdges.add(d.edgeKey);
  game.portalCooldowns.set(d.edgeKey, game.portalClock + CONFIG.portalEdgeCooldown);
  d.previous = d.currentPortal;
  d.currentPortal = target.id;
  d.visited.add(target.id);
  d.explicitNext = false;
  d.departOnArrival = false;
  const dx = (target.x - sh.x) / len, dy = (target.y - sh.y) / len;
  const v = launchVelocity(sh.vx, sh.vy, dx, dy, game.stats.gaugeMax, game.stats);
  const speed = Math.max(1, Math.hypot(v.vx, v.vy));
  d.remaining = Math.max(0, d.remaining - len);
  d.phase = 'hop'; d.target = target; d.left = len; d.dx = dx; d.dy = dy;
  d.speed = speed; d.rate = Math.max(speed, len * game.stats.traceSpeedMult / CONFIG.portalHopTime);
  d.inside = new Map(); d.passes = new Map(); d.waveInside = new Map(); d.waveAcc = 0; d.trailAcc = 0;
  sh.vx = dx * speed; sh.vy = dy * speed; sh.hx = dx; sh.hy = dy;
  sh.boostT = game.stats.boostDuration; sh.fadeT = 0; sh.gaugeBank = 0;
  d.next = portalDefaultNext(game);
  game.portalPreview = d.next;
  game.dashId++;
  game.events.push({ type: 'launch', gauge: game.stats.gaugeMax, x: sh.x, y: sh.y, dx, dy });
  return true;
}

function portalRefreshNext(game) {
  const d = game.portalDash;
  if (!d) return;
  if (!portalChoices(game).some((c) => c.portal === d.next)) {
    d.next = portalDefaultNext(game);
    d.explicitNext = false;
  }
  game.portalPreview = d.next;
  if (d.phase === 'choose' && !d.next) {
    if (game.portalSpace.armed) game.portalSpace.consumed = true;
    portalLeave(game, { x: game.ship.hx, y: game.ship.hy });
  }
}

export function portalWorldScale(game) {
  const d = game.portalDash;
  if (!d) return 1;
  return d.phase === 'choose' ? CONFIG.portalChooseScale
    : Math.max(CONFIG.dashScaleMin, Math.min(1, CONFIG.dashSlowRef / Math.max(1, d.speed)));
}

export function updatePortals(game, realDt) {
  const d = game.portalDash;
  if (!d) return;
  if (d.phase === 'choose') { portalRefreshNext(game); return; }
  const sh = game.ship;
  let travel = Math.min(d.left, d.rate * realDt);
  // Small swept steps keep body hits, wave hits, obstacles and trail explosions in travel order.
  while (travel > 1e-6) {
    const stepDist = Math.min(20, travel), x0 = sh.x, y0 = sh.y;
    const x1 = x0 + d.dx * stepDist, y1 = y0 + d.dy * stepDist;
    if (!portalClearLine(game, x0, y0, x1, y1)) {
      damageShip(game, Math.max(0, d.speed - 200) * CONFIG.crashDamage, 0, 'portalCrash');
      sh.vx *= -0.4; sh.vy *= -0.4;
      game.events.push({ type: 'bounce', x: x0, y: y0 });
      stopPortalDash(game, '障害物に衝突'); return;
    }
    for (const [id, e] of d.inside) {
      if (e.dead || Math.hypot(x0 - e.x, y0 - e.y) > e.r + CONFIG.shipRadius + 2) d.inside.delete(id);
    }
    sh.x = x1; sh.y = y1;
    sh.vx = d.dx * d.speed; sh.vy = d.dy * d.speed;
    waveAlong(game, d, x0, y0, x1, y1);
    if (game.state === 'finishing') return;
    if (collideEnemies(game, x0, y0, CONFIG.shipRadius, d)) { stopPortalDash(game, '弾かれた'); return; }
    if (game.state === 'finishing') return;
    d.speed = Math.hypot(sh.vx, sh.vy);
    tracePortalLoop(game, d, x0, y0, sh.x, sh.y);
    d.trailAcc += stepDist;
    if (game.stats.trailBurst && d.trailAcc >= 45) {
      d.trailAcc = 0;
      game.marks.push({ x: x1, y: y1, t: 0.55, dmg: attackPower(d.speed, game.stats) * game.stats.trailBurst });
    }
    sh.trail.push({ x: sh.x, y: sh.y });
    if (sh.trail.length > 150) sh.trail.shift();
    travel -= stepDist; d.left -= stepDist;
    game.dashPeakAtk = Math.max(game.dashPeakAtk, attackPower(d.speed, game.stats));
    if (sh.hp <= 0) { stopPortalDash(game); return; }
  }
  if (d.left > 1e-6) return;
  sh.x = d.target.x; sh.y = d.target.y;
  game.portalCooldowns.set(d.edgeKey, game.portalClock + CONFIG.portalEdgeCooldown);
  d.path.push({ x: sh.x, y: sh.y });
  const loopEnd = d.loopPath[d.loopPath.length - 1];
  if (Math.hypot(loopEnd.x - sh.x, loopEnd.y - sh.y) > 1e-6) d.loopPath.push({ x: sh.x, y: sh.y });
  game.portalTouch = d.target.id;
  if (!d.target.manual) {
    d.target.uses--;
    d.target.refillAt = game.t + CONFIG.portalRefillInterval;
    if (d.target.uses <= 0) game.portals = game.portals.filter((p) => p !== d.target);
  }
  d.hops++;
  d.phase = 'choose';
  const wave = game.stats.portalWave;
  if (wave) explode(game, sh.x, sh.y, CONFIG.portalWaveRadius * game.stats.waveRadiusMult,
    attackPower(d.speed, game.stats) * CONFIG.portalWaveDamage * wave * game.stats.waveDmgMult,
    { cause: 'portalWave', color: '#c995ff', knock: 500, life: 0.45 });
  else addRing(game, sh.x, sh.y, 48, '#9fe8ff', 0.25);
  // Include routes opened by kills while retaining an explicit choice made in flight.
  portalRefreshNext(game);
  if (!game.portalDash) return;
  if (d.departOnArrival && d.next) portalBeginHop(game, d.next);
  else d.departOnArrival = false;
}
