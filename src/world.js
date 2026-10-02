import { CONFIG } from './config.js';
import { makeRng } from './math.js';
import { baseStats, createShip, computeGauge, launchVelocity, stepShip } from './ship.js';
import { createField, updateMoons, dustDragAt } from './field.js';
import { gravityAt } from './gravity.js';
import { attackPower, isWeakHit, resolveRam, pierceKeep, canPierce } from './combat.js';
import { updateEnemy, MAX_ENEMY_R } from './enemies.js';
import { buildGrid, queryGrid } from './grid.js';
import { segCircleT } from './math.js';
import { updateSpawner } from './spawner.js';

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
    enemies: [],
    grid: buildGrid([], 160),
    fx: { particles: [], rings: [], texts: [] },
    kills: 0,
    hitstop: 0,
    spawning: true,
    dashPierce: 0,
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
  frameDt = Math.min(frameDt, 0.1);
  updateFx(game, frameDt);
  if (game.hitstop > 0) { game.hitstop -= frameDt; return; }
  game.acc += frameDt * game.timeScale;
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
  for (const e of game.enemies) updateEnemy(e, game, dt);
  separateEnemies(game);
  game.grid = buildGrid(game.enemies, 160);

  const g = gravityAt(game.field, game.t, sh.x, sh.y);
  const drag = dustDragAt(game.field, sh.x, sh.y);
  const x0 = sh.x, y0 = sh.y;
  stepShip(sh, stats, dt, g.ax, g.ay, drag);
  collideEnemies(game, x0, y0);
  collideBodies(game);
  if (game.enemies.some((e) => e.dead)) game.enemies = game.enemies.filter((e) => !e.dead);
  updateSpawner(game, dt);
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
  game.dashPierce = 0;
  game.events.push({ type: 'launch', gauge: sh.gauge, x: sh.x, y: sh.y, dx, dy });
}

function separateEnemies(game) {
  const grid = buildGrid(game.enemies, 120);
  for (const e of game.enemies) {
    queryGrid(grid, e.x - e.r - 40, e.y - e.r - 40, e.x + e.r + 40, e.y + e.r + 40, (o) => {
      if (o.id <= e.id) return;
      const dx = o.x - e.x, dy = o.y - e.y;
      const min = (e.r + o.r) * 0.9;
      const d2 = dx * dx + dy * dy;
      if (d2 >= min * min || d2 === 0) return;
      const d = Math.sqrt(d2);
      const push = (min - d) * 0.5;
      const wE = o.r * o.r / (e.r * e.r + o.r * o.r);
      e.x -= (dx / d) * push * 2 * wE; e.y -= (dy / d) * push * 2 * wE;
      o.x += (dx / d) * push * 2 * (1 - wE); o.y += (dy / d) * push * 2 * (1 - wE);
    });
  }
}

function collideEnemies(game, x0, y0) {
  const sh = game.ship, stats = game.stats;
  const x1 = sh.x, y1 = sh.y;
  const R = CONFIG.shipRadius;
  const pad = R + MAX_ENEMY_R;
  const hits = [];
  queryGrid(game.grid, Math.min(x0, x1) - pad, Math.min(y0, y1) - pad, Math.max(x0, x1) + pad, Math.max(y0, y1) + pad, (e) => {
    if (e.hitCD > 0) return;
    const t = segCircleT(x0, y0, x1, y1, e.x, e.y, e.r + R);
    if (t >= 0) hits.push({ e, t });
  });
  if (!hits.length) return;
  hits.sort((a, b) => a.t - b.t);
  for (const { e, t } of hits) {
    const hx = x0 + (x1 - x0) * t, hy = y0 + (y1 - y0) * t;
    const sp = Math.hypot(sh.vx, sh.vy);
    const ux = sp > 0 ? sh.vx / sp : 0, uy = sp > 0 ? sh.vy / sp : 0;
    const atk = attackPower(sp, stats);
    const crit = isWeakHit(e, hx, hy, stats.weakArcMult);
    const res = resolveRam(atk, e, crit, stats);
    if (res.pierce) {
      damageEnemy(game, e, res.damage, { crit, cause: 'ram', dirX: ux, dirY: uy });
      e.hitCD = 0.3;
      const keep = pierceKeep(e, e.dead, stats);
      sh.vx *= keep; sh.vy *= keep;
      game.dashPierce++;
      if (crit) game.hitstop = Math.max(game.hitstop, e.dead ? 0.05 : 0.035);
      continue;
    }
    // bounce off
    let nx = hx - e.x, ny = hy - e.y;
    const nd = Math.hypot(nx, ny) || 1;
    nx /= nd; ny /= nd;
    sh.x = e.x + nx * (e.r + R + 1);
    sh.y = e.y + ny * (e.r + R + 1);
    const vn = sh.vx * nx + sh.vy * ny;
    if (vn < 0) { sh.vx -= 2 * vn * nx; sh.vy -= 2 * vn * ny; }
    const keep = stats.bounceKeep;
    sh.vx *= keep; sh.vy *= keep;
    if (Math.hypot(sh.vx, sh.vy) < 220) { sh.vx = nx * 220; sh.vy = ny * 220; }
    sh.boostT = 0;
    damageEnemy(game, e, res.damage, { crit, cause: 'bump', dirX: -nx, dirY: -ny });
    e.hitCD = 0.25;
    e.vx -= nx * 120; e.vy -= ny * 120;
    damageShip(game, res.shipDamage * stats.bounceDamageMult, 0);
    game.events.push({ type: 'bounce', x: sh.x, y: sh.y });
    break;
  }
}

export function damageEnemy(game, e, dmg, opts = {}) {
  if (e.dead || dmg <= 0) return;
  e.hp -= dmg;
  e.flash = 0.12;
  game.events.push({ type: 'hit', x: e.x, y: e.y, crit: !!opts.crit, dmg, cause: opts.cause });
  if (opts.crit) addText(game, e.x, e.y - e.r - 10, 'CRIT', '#ffe46b');
  if (e.hp <= 0) {
    killEnemy(game, e, opts);
  } else if (opts.dirX !== undefined) {
    e.vx += opts.dirX * 160; e.vy += opts.dirY * 160;
  }
}

export function killEnemy(game, e, opts = {}) {
  if (e.dead) return;
  e.dead = true;
  game.kills++;
  game.events.push({ type: 'kill', x: e.x, y: e.y, r: e.r, crit: !!opts.crit, enemyType: e.type, elite: e.elite, cause: opts.cause });
  burst(game, e.x, e.y, e.T.color, 6 + Math.round(e.r / 3), opts.dirX || 0, opts.dirY || 0, 260 + e.r * 4);
}

function burst(game, x, y, color, n, dx, dy, speed) {
  const P = game.fx.particles;
  if (P.length > 1600) return;
  for (let i = 0; i < n; i++) {
    const a = game.rng() * Math.PI * 2;
    const s = speed * (0.3 + game.rng());
    P.push({
      x, y,
      vx: Math.cos(a) * s * 0.6 + dx * s * 0.8,
      vy: Math.sin(a) * s * 0.6 + dy * s * 0.8,
      life: 0.5 + game.rng() * 0.4, max: 0.9, color, size: 2 + game.rng() * 4,
    });
  }
}

export function addText(game, x, y, text, color) {
  if (game.fx.texts.length > 40) game.fx.texts.shift();
  game.fx.texts.push({ x, y, text, color, life: 0.7 });
}

export function addRing(game, x, y, radius, color, life = 0.45) {
  game.fx.rings.push({ x, y, radius, color, life, max: life });
}

function updateFx(game, dt) {
  const P = game.fx.particles;
  for (const p of P) { p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= 1 - 2.5 * dt; p.vy *= 1 - 2.5 * dt; p.life -= dt; }
  game.fx.particles = P.filter((p) => p.life > 0);
  for (const t of game.fx.texts) { t.y -= 40 * dt; t.life -= dt; }
  game.fx.texts = game.fx.texts.filter((t) => t.life > 0);
  for (const r of game.fx.rings) r.life -= dt;
  game.fx.rings = game.fx.rings.filter((r) => r.life > 0);
}

// Marks predicted points that cross a weak spot (hot) and stops at the first enemy that would block.
export function annotatePrediction(game, pts) {
  const R = CONFIG.shipRadius;
  const out = [];
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i];
    let block = false;
    queryGrid(game.grid, p.x - R - MAX_ENEMY_R, p.y - R - MAX_ENEMY_R, p.x + R + MAX_ENEMY_R, p.y + R + MAX_ENEMY_R, (e) => {
      const dx = p.x - e.x, dy = p.y - e.y;
      const rr = e.r + R;
      if (dx * dx + dy * dy > rr * rr) return;
      const crit = isWeakHit(e, p.x, p.y, game.stats.weakArcMult);
      if (crit) p.hot = true;
      if (!canPierce(attackPower(p.sp, game.stats), e, crit)) block = true;
    });
    out.push(p);
    if (block) { p.block = true; break; }
  }
  return out;
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
  addText(game, sh.x, sh.y - 30, `-${Math.round(amount * game.stats.damageTakenMult)}`, '#ff6b5a');
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
