import { CONFIG } from './config.js';
import { makeRng } from './math.js';
import { baseStats, createShip, computeGauge, launchVelocity, stepShip } from './ship.js';
import { createField, updateMoons, dustDragAt } from './field.js';
import { gravityAt } from './gravity.js';

export const STEP = 1 / 120;

export function createGame(opts = {}) {
  const meta = opts.meta || {};
  const seed = opts.seed ?? (Math.random() * 4294967296) >>> 0;
  const stats = baseStats(meta);
  const rng = makeRng(seed);
  const ship = createShip(stats, -CONFIG.startRadius, 0);
  ship.vy = -CONFIG.baseMaxSpeed * 0.3; // start drifting along the orbit
  return {
    t: 0, acc: 0, seed, rng,
    meta, stats, ship,
    field: createField(rng),
    debug: { invincible: false },
    state: 'play',
    timeScale: 1,
    releasePending: null,
    dashId: 0,
    peakSpeed: 0,
    events: [],
    viewRadius: 1400,
  };
}

export function update(game, frameDt, input) {
  if (game.state !== 'play') return;
  if (input.release) game.releasePending = { x: input.aimX, y: input.aimY };
  game.acc += Math.min(frameDt, 0.1) * game.timeScale;
  while (game.acc >= STEP) {
    game.acc -= STEP;
    step(game, STEP, input);
    if (game.state !== 'play') break;
  }
}

function step(game, dt, input) {
  const sh = game.ship;
  const stats = game.stats;
  game.t += dt;

  if (input.charging && !game.releasePending) {
    if (!sh.charging) { sh.charging = true; sh.chargeT = 0; }
    sh.chargeT += dt;
    sh.gauge = computeGauge(sh.chargeT, stats, sh.gaugeBank);
    sh.aimX = input.aimX; sh.aimY = input.aimY;
  }
  if (game.releasePending) {
    const r = game.releasePending;
    game.releasePending = null;
    if (sh.charging) launch(game, r.x, r.y);
    sh.charging = false;
  }

  updateMoons(game.field, game.t);
  const g = gravityAt(game.field, game.t, sh.x, sh.y);
  const drag = dustDragAt(game.field, sh.x, sh.y);
  stepShip(sh, stats, dt, g.ax, g.ay, drag);
  collideBodies(game);
  if (sh.invulnT > 0) sh.invulnT -= dt;

  const sp = Math.hypot(sh.vx, sh.vy);
  if (sp > game.peakSpeed) game.peakSpeed = sp;
  recordTrail(sh, dt);
}

function launch(game, ax, ay) {
  const sh = game.ship;
  const len = Math.hypot(ax, ay);
  let dx, dy;
  if (len < CONFIG.minDrag) {
    const sp = Math.hypot(sh.vx, sh.vy);
    if (sp < 1) return;
    dx = sh.vx / sp; dy = sh.vy / sp;
  } else {
    dx = ax / len; dy = ay / len;
  }
  const v = launchVelocity(sh.vx, sh.vy, dx, dy, sh.gauge, game.stats);
  sh.vx = v.vx; sh.vy = v.vy;
  sh.boostT = game.stats.boostDuration;
  sh.gaugeBank = 0;
  game.dashId++;
  game.events.push({ type: 'launch', gauge: sh.gauge, x: sh.x, y: sh.y, dx, dy });
}

function collideBodies(game) {
  const sh = game.ship;
  const R = CONFIG.shipRadius;
  const f = game.field;
  for (const b of [f.planet, ...f.moons]) {
    const dx = sh.x - b.x, dy = sh.y - b.y;
    const d = Math.hypot(dx, dy);
    const min = b.r + R;
    if (d >= min || d === 0) continue;
    const nx = dx / d, ny = dy / d;
    sh.x = b.x + nx * min;
    sh.y = b.y + ny * min;
    const vn = sh.vx * nx + sh.vy * ny;
    if (vn < 0) {
      sh.vx -= (1 + CONFIG.crashRestitution) * vn * nx;
      sh.vy -= (1 + CONFIG.crashRestitution) * vn * ny;
      const dmg = Math.max(0, -vn - 200) * CONFIG.crashDamage;
      if (dmg > 0) damageShip(game, dmg, 0);
      game.events.push({ type: 'crash', x: sh.x, y: sh.y, power: -vn });
    }
  }
  // hard wall well outside the soft boundary
  const r = Math.hypot(sh.x, sh.y);
  const wall = CONFIG.fieldRadius + 500;
  if (r > wall) {
    const nx = sh.x / r, ny = sh.y / r;
    sh.x = nx * wall; sh.y = ny * wall;
    const vn = sh.vx * nx + sh.vy * ny;
    if (vn > 0) { sh.vx -= 2 * vn * nx; sh.vy -= 2 * vn * ny; }
  }
}

// amount: hp lost, slow: share of speed lost (0..1)
export function damageShip(game, amount, slow) {
  const sh = game.ship;
  if (sh.invulnT > 0 || game.debug.invincible) return false;
  sh.hp -= amount * game.stats.damageTakenMult;
  const k = 1 - Math.min(0.9, slow * game.stats.hitSlowMult);
  sh.vx *= k; sh.vy *= k;
  sh.invulnT = CONFIG.invulnTime;
  game.events.push({ type: 'hurt', amount, x: sh.x, y: sh.y });
  return true;
}

// Ballistic preview of a launch along (dx, dy) with the given gauge, under gravity only.
export function predictPath(game, dx, dy, gauge, seconds) {
  const sh = game.ship;
  const len = Math.hypot(dx, dy) || 1;
  const v = launchVelocity(sh.vx, sh.vy, dx / len, dy / len, gauge, game.stats);
  const ghost = { x: sh.x, y: sh.y, vx: v.vx, vy: v.vy, boostT: game.stats.boostDuration };
  const pts = [];
  const h = 1 / 60;
  const moons = game.field.moons.map((m) => ({ ...m }));
  const field = { ...game.field, moons };
  for (let t = 0; t < seconds; t += h) {
    updateMoons(field, game.t + t);
    const g = gravityAt(field, game.t + t, ghost.x, ghost.y);
    stepShip(ghost, game.stats, h, g.ax, g.ay, 0);
    pts.push({ x: ghost.x, y: ghost.y, sp: Math.hypot(ghost.vx, ghost.vy) });
    if (Math.hypot(ghost.x, ghost.y) < CONFIG.planetRadius + CONFIG.shipRadius) break;
  }
  return pts;
}

function recordTrail(sh, dt) {
  sh.trailAcc += dt;
  if (sh.trailAcc < 1 / 60) return;
  sh.trailAcc = 0;
  sh.trail.push({ x: sh.x, y: sh.y });
  if (sh.trail.length > 150) sh.trail.shift();
}

export function shipSpeed(game) {
  return Math.hypot(game.ship.vx, game.ship.vy);
}
