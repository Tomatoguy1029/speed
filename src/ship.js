import { CONFIG } from './config.js';

export function baseStats(meta = {}) {
  const lv = (k) => meta[k] || 0;
  return {
    maxSpeed: CONFIG.baseMaxSpeed * (1 + 0.05 * lv('speed')),
    launchRatio: CONFIG.launchRatio,
    carry: CONFIG.carry,
    chargeTime: CONFIG.chargeTime * Math.pow(0.95, lv('charge')),
    gaugeMax: 1,
    boostDuration: CONFIG.boostDuration,
    cruiseDrag: CONFIG.cruiseDrag,
    cruiseFloor: CONFIG.cruiseFloor,
    atkMult: 1 + 0.06 * lv('atk'),
    maxHp: CONFIG.baseHP + 15 * lv('hp'),
    pickupRadius: CONFIG.pickupRadius * (1 + 0.15 * lv('pickup')),
    xpMult: 1 + 0.08 * lv('xp'),
    damageTakenMult: 1,
    hitSlowMult: 1,
    critMult: 2.5,
    weakArcMult: 1,
    pierceLossMult: 1,
    bounceKeep: 0.5,
    bounceDamageMult: 1,
    predictTime: 0.9,
    predictBounce: false,
    regen: 0,
    drawLengthMult: 1, traceSpeedMult: 1, waveRadiusMult: 1, waveDmgMult: 1, // draw-mode modules
  };
}

export function createShip(stats, x, y) {
  return {
    x, y, vx: 0, vy: 0,
    hp: stats.maxHp,
    charging: false, chargeT: 0, gauge: 0, gaugeBank: 0,
    aimX: 0, aimY: 0, hx: 0, hy: -1, // heading: travel direction, or the last control direction when nearly still
    markX: 0, markY: -1, // where a Space launch would go right now (drawn as the aim marker)
    aimAngle: -Math.PI / 2, turnHeld: 0, // rotating-aim scheme
    boostT: 0, fadeT: 0, invulnT: 0, glide: false,
    trail: [], trailAcc: 0,
  };
}

export function computeGauge(chargeT, stats, bank = 0) {
  return Math.min(stats.gaugeMax, Math.max(CONFIG.minGauge, bank + chargeT / stats.chargeTime));
}

// New velocity after launching along unit direction (dx, dy) with the given gauge.
export function launchVelocity(vx, vy, dx, dy, gauge, stats) {
  const speed = Math.hypot(vx, vy);
  const cos = speed > 0 ? Math.max(0, (vx * dx + vy * dy) / speed) : 0;
  const carried = speed * stats.carry * cos;
  const thrust = stats.maxSpeed * stats.launchRatio * gauge;
  const limit = stats.maxSpeed * Math.max(1, gauge);
  const newSpeed = Math.max(Math.min(carried + thrust, limit), speed * cos);
  return { vx: dx * newSpeed, vy: dy * newSpeed };
}

// Integrate one step: acceleration (ax, ay), drag rules, then position.
export function stepShip(ship, stats, dt, ax, ay, extraDrag) {
  if (ship.glide) {
    ship.boostT = Math.max(0, ship.boostT - dt);
    ship.fadeT = 0;
    ship.x += ship.vx * dt;
    ship.y += ship.vy * dt;
    return;
  }
  ship.vx += ax * dt;
  ship.vy += ay * dt;
  let sp = Math.hypot(ship.vx, ship.vy);
  if (sp > 0) {
    let target = sp;
    if (ship.boostT > 0) {
      ship.boostT -= dt;
      if (ship.boostT <= 0) ship.fadeT = 0.3;
    } else {
      if (ship.fadeT > 0) {
        ship.fadeT -= dt;
        if (target > stats.maxSpeed * stats.cruiseFloor) target *= Math.pow(CONFIG.energyCut, dt / 0.3);
      }
      const floor = stats.maxSpeed * stats.cruiseFloor;
      if (target > floor) target = floor + (target - floor) * Math.exp(-stats.cruiseDrag * dt);
    }
    if (target > stats.maxSpeed) {
      target = stats.maxSpeed + (target - stats.maxSpeed) * Math.exp(-CONFIG.overcapDecay * dt);
    }
    if (extraDrag > 0) target *= Math.exp(-extraDrag * dt);
    const k = target / sp;
    ship.vx *= k;
    ship.vy *= k;
  }
  ship.x += ship.vx * dt;
  ship.y += ship.vy * dt;
}
