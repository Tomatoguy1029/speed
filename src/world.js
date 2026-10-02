import { CONFIG } from './config.js';
import { makeRng } from './math.js';
import { baseStats, createShip, computeGauge, launchVelocity, stepShip } from './ship.js';

export const STEP = 1 / 120;

export function createGame(opts = {}) {
  const meta = opts.meta || {};
  const seed = opts.seed ?? (Math.random() * 4294967296) >>> 0;
  const stats = baseStats(meta);
  const ship = createShip(stats, -CONFIG.startRadius, 0);
  return {
    t: 0, acc: 0, seed, rng: makeRng(seed),
    meta, stats, ship,
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

  stepShip(sh, stats, dt, 0, 0, 0);

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
