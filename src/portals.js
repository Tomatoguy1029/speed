import { CONFIG } from './config.js';
import { segCircleT } from './math.js';
import { launchVelocity } from './ship.js';
import { attackPower } from './combat.js';
import { addText, addRing, explode } from './hits.js';
import { onLaunch } from './effects.js';
import { waveAlong, collideEnemies, damageShip } from './world.js';

export const PORTAL_DIRECTIONS = [
  { key: 'W', x: 0, y: -1 }, { key: 'D', x: 1, y: 0 },
  { key: 'S', x: 0, y: 1 }, { key: 'A', x: -1, y: 0 },
];

export function portalGrowth(game) {
  return game.stats.maxSpeed / CONFIG.baseMaxSpeed * game.stats.drawLengthMult * game.stats.gaugeMax;
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
  return portalCreate(game, sh.x, sh.y, true);
}

// Check spacing before rolling for a drop. A crowd can replenish one node, not create a pile.
export function dropPortal(game, x, y) {
  if (game.scheme !== 'portal') return;
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

export function portalTarget(game, direction, origin = game.ship) {
  if (!direction || !(direction.x || direction.y)) return null;
  const len = Math.hypot(direction.x, direction.y);
  const reach = Math.min(portalReach(game), game.portalDash?.remaining ?? Infinity);
  let best = null, score = Infinity;
  for (const p of game.portals) {
    const dx = p.x - origin.x, dy = p.y - origin.y, d = Math.hypot(dx, dy);
    if (d < CONFIG.portalMinHop || d > reach || !portalClearLine(game, origin.x, origin.y, p.x, p.y)) continue;
    const dot = (dx * direction.x + dy * direction.y) / (d * len);
    if (dot < Math.SQRT1_2 - 1e-6) continue;
    const s = d * (1 + 4 * (1 - dot));
    if (s < score) { best = p; score = s; }
  }
  return best;
}

export function portalChoices(game) {
  const origin = game.portalDash?.phase === 'hop' ? game.portalDash.target : game.ship;
  return PORTAL_DIRECTIONS.map((dir) => ({ ...dir, portal: portalTarget(game, dir, origin) })).filter((c) => c.portal);
}

export function stopPortalDash(game, message = '') {
  game.portalDash = null;
  game.ship.boostT = game.stats.boostDuration;
  if (message) addText(game, game.ship.x, game.ship.y - 48, message, '#e8f6ff');
}

export function handlePortalInput(game, input) {
  if (game.scheme !== 'portal') return;
  if (input.place) placePortal(game);
  const move = input.move;
  game.portalPreview = portalTarget(game, move);
  if (input.dash) {
    if (game.portalDash) { stopPortalDash(game); return; }
    if (game.dashMeter < 1) return;
    if (!portalChoices(game).length) { addText(game, game.ship.x, game.ship.y - 45, 'E で設置・敵の撃破でも出現', '#9fe8ff'); return; }
    const budget = CONFIG.portalBudget * portalGrowth(game);
    game.dashMeter = 0;
    game.portalDash = { phase: 'choose', remaining: budget, budget, timeLeft: CONFIG.portalChooseTime, hops: 0, queued: null };
    game.ship.charging = false;
    onLaunch(game);
    game.ship.boostT = game.stats.boostDuration;
    const first = input.portalSelect || move;
    if (first && (first.x || first.y)) portalBeginHop(game, first);
  } else if (game.portalDash && input.portalSelect && (input.portalSelect.x || input.portalSelect.y)) {
    if (game.portalDash.phase === 'hop') game.portalDash.queued = { ...input.portalSelect };
    else portalBeginHop(game, input.portalSelect);
  }
}

function portalBeginHop(game, direction) {
  const d = game.portalDash, sh = game.ship;
  const target = portalTarget(game, direction);
  if (!target) return false;
  const len = Math.hypot(target.x - sh.x, target.y - sh.y);
  const dx = (target.x - sh.x) / len, dy = (target.y - sh.y) / len;
  const v = launchVelocity(sh.vx, sh.vy, dx, dy, game.stats.gaugeMax, game.stats);
  const speed = Math.max(1, Math.hypot(v.vx, v.vy));
  d.remaining = Math.max(0, d.remaining - len);
  d.phase = 'hop'; d.target = target; d.left = len; d.dx = dx; d.dy = dy;
  d.speed = speed; d.rate = Math.max(speed, len * game.stats.traceSpeedMult / CONFIG.portalHopTime);
  d.inside = new Map(); d.passes = new Map(); d.waveInside = new Map(); d.waveAcc = 0; d.trailAcc = 0;
  sh.vx = dx * speed; sh.vy = dy * speed; sh.hx = dx; sh.hy = dy;
  sh.boostT = game.stats.boostDuration; sh.fadeT = 0; sh.gaugeBank = 0;
  game.dashId++;
  game.events.push({ type: 'launch', gauge: game.stats.gaugeMax, x: sh.x, y: sh.y, dx, dy });
  return true;
}

export function portalWorldScale(game) {
  const d = game.portalDash;
  if (!d) return 1;
  return d.phase === 'choose' ? CONFIG.portalChooseScale
    : Math.max(CONFIG.drawRunScaleMin, Math.min(1, CONFIG.drawRunSlowRef / Math.max(1, d.speed)));
}

export function updatePortals(game, realDt) {
  const d = game.portalDash;
  if (!d) return;
  if (d.phase === 'choose') {
    d.timeLeft -= realDt;
    if (d.timeLeft <= 0 || !portalChoices(game).length) stopPortalDash(game, '通常移動へ');
    return;
  }
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
    if (collideEnemies(game, x0, y0, CONFIG.shipRadius, d)) { stopPortalDash(game, '弾かれた'); return; }
    d.speed = Math.hypot(sh.vx, sh.vy);
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
  if (!d.target.manual) {
    d.target.uses--;
    d.target.refillAt = game.t + CONFIG.portalRefillInterval;
    if (d.target.uses <= 0) game.portals = game.portals.filter((p) => p !== d.target);
  }
  d.hops++;
  d.phase = 'choose'; d.timeLeft = CONFIG.portalChooseTime;
  const wave = game.stats.portalWave;
  if (wave) explode(game, sh.x, sh.y, CONFIG.portalWaveRadius * game.stats.waveRadiusMult,
    attackPower(d.speed, game.stats) * CONFIG.portalWaveDamage * wave * game.stats.waveDmgMult,
    { cause: 'portalWave', color: '#c995ff', knock: 500, life: 0.45 });
  else addRing(game, sh.x, sh.y, 48, '#9fe8ff', 0.25);
  // A buffered direction is interpreted from the arrival point, never from the departure point.
  if (!portalChoices(game).length) { stopPortalDash(game, '通常移動へ'); return; }
  if (d.queued) { const next = d.queued; d.queued = null; portalBeginHop(game, next); }
  game.portalPreview = game.portalDash?.phase === 'hop' ? game.portalDash.target : null;
}
