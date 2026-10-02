import { CONFIG } from './config.js';
import { makeRng, segCircleT } from './math.js';
import { createShip, computeGauge, launchVelocity, stepShip } from './ship.js';
import { createField, updateMoons, dustDragAt } from './field.js';
import { gravityAt } from './gravity.js';
import { attackPower, isWeakHit, resolveRam, pierceKeep, canPierce } from './combat.js';
import { updateEnemy, MAX_ENEMY_R } from './enemies.js';
import { updateEnemyBullets } from './projectiles.js';
import { buildGrid, queryGrid } from './grid.js';
import { updateSpawner, getPhase } from './spawner.js';
import { xpForLevel } from './progression.js';
import { SLOTS, computeStats, rollModule } from './modules.js';
import { damageEnemy, addText } from './hits.js';
import { createEffectState, updateEffects, onLaunch, onPierce, onShipHurt } from './effects.js';
import { SPEED_STAGES, speedStage } from './stages.js';

export const STEP = 1 / 120;

export function createGame(opts = {}) {
  const meta = opts.meta || {};
  const seed = opts.seed ?? (Math.random() * 4294967296) >>> 0;
  const loadout = Object.fromEntries(SLOTS.map((s) => [s.id, null]));
  const stats = computeStats(meta, loadout);
  const rng = makeRng(seed);
  const ship = createShip(stats, -CONFIG.startRadius, 0);
  ship.vy = -CONFIG.baseMaxSpeed * 0.3; // start drifting along the orbit
  return {
    t: 0, acc: 0, seed, rng,
    meta, stats, ship, loadout,
    offerQueue: [], currentOffer: null, lastOfferSlot: null,
    field: createField(rng),
    debug: { invincible: false, autoOffer: null },
    enemies: [], newEnemies: [], ebullets: [],
    leechDrag: 0,
    gems: [], coinDrops: [],
    xp: 0, level: 0, pendingLevelups: 0,
    spawnAcc: 0, waveT: 0,
    phaseId: null,
    endReason: null,
    grid: buildGrid([], 160),
    fx: { particles: [], rings: [], texts: [] },
    ...createEffectState(),
    kills: 0, coins: 0, cores: 0,
    hitstop: 0, slowmo: 0,
    spawning: true,
    dashPierce: 0, dashId: 0,
    state: 'play',
    timeScale: 1,
    releasePending: null,
    peakSpeed: 0, stage: 0,
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
  if (game.slowmo > 0) { game.slowmo -= frameDt; game.timeScale = 0.18; } else game.timeScale = 1;
  game.acc += frameDt * game.timeScale;
  while (game.acc >= STEP) {
    game.acc -= STEP;
    step(game, STEP, input);
    if (game.state !== 'play') break;
    queueOffers(game);
    if (game.offerQueue.length) { openOffer(game); break; }
  }
}

function step(game, dt, input) {
  const sh = game.ship;
  const stats = game.stats;
  game.t += dt;
  const phase = getPhase(game.t);
  if (phase.id !== game.phaseId) {
    game.phaseId = phase.id;
    game.events.push({ type: 'phase', phase });
  }

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
  game.leechDrag = 0;
  for (const e of game.enemies) updateEnemy(e, game, dt);
  flushNewEnemies(game);
  separateEnemies(game);
  game.grid = buildGrid(game.enemies, 160);

  const g = gravityAt(game.field, game.t, sh.x, sh.y);
  const drag = dustDragAt(game.field, sh.x, sh.y) + game.leechDrag;
  const x0 = sh.x, y0 = sh.y;
  stepShip(sh, stats, dt, g.ax, g.ay, drag);
  collideEnemies(game, x0, y0);
  collideBodies(game);
  if (sh.invulnT > 0) sh.invulnT -= dt;
  updateEnemyBullets(game, dt, (b) => damageShip(game, b.dmg, b.slow, b.kind));
  updateEffects(game, dt);
  if (game.enemies.some((e) => e.dead)) game.enemies = game.enemies.filter((e) => !e.dead);
  flushNewEnemies(game);
  updateSpawner(game, dt);
  updateGems(game, dt);
  if (stats.regen > 0) sh.hp = Math.min(stats.maxHp, sh.hp + stats.regen * dt);

  const sp = Math.hypot(sh.vx, sh.vy);
  if (sp > game.peakSpeed) game.peakSpeed = sp;
  recordTrail(sh, dt);
  const st = speedStage(sp);
  if (st > game.stage) {
    game.stage = st;
    game.events.push({ type: 'stage', stage: st, name: SPEED_STAGES[st - 1].name, speed: sp });
  } else if (game.stage > 0 && sp < SPEED_STAGES[game.stage - 1].v * 0.85) {
    game.stage = st;
  }

  if (sp >= CONFIG.escapeSpeed) end(game, 'won', 'escape');
  else if (sh.hp <= 0) end(game, 'lost', 'hp');
  else if (game.t >= CONFIG.runTime) end(game, 'lost', 'time');
}

function end(game, state, reason) {
  if (state === 'won') game.coins += CONFIG.escapeBonus;
  game.state = state;
  game.endReason = reason;
  game.events.push({ type: 'end', state, reason });
}

// ---- offers ----

function queueOffers(game) {
  while (game.pendingLevelups > 0) {
    game.pendingLevelups--;
    pushOffer(game, rollModule(game.rng, { t: game.t, loadout: game.loadout, source: 'xp', lastSlot: game.lastOfferSlot }), 'xp');
  }
}

export function pushOffer(game, mod, source) {
  game.lastOfferSlot = mod.slot;
  game.offerQueue.push({ ...mod, source });
}

function openOffer(game) {
  const auto = game.debug.autoOffer;
  game.state = 'offer';
  game.currentOffer = game.offerQueue.shift();
  game.ship.charging = false;
  game.releasePending = null;
  game.events.push({ type: 'offer' });
  if (auto) while (game.state === 'offer') resolveOffer(game, auto === 'equip' || (auto === 'better' && isBetter(game, game.currentOffer)));
}

function isBetter(game, mod) {
  const cur = game.loadout[mod.slot];
  return !cur || mod.r >= cur.r;
}

// accept: equip (the old module in that slot is thrown away); otherwise discard the offer.
export function resolveOffer(game, accept) {
  const mod = game.currentOffer;
  if (!mod) return;
  if (accept) {
    game.loadout[mod.slot] = { id: mod.id, slot: mod.slot, r: mod.r };
    refreshStats(game);
    game.events.push({ type: 'equip', mod });
  }
  if (game.offerQueue.length) {
    game.currentOffer = game.offerQueue.shift();
  } else {
    game.currentOffer = null;
    game.state = 'play';
  }
}

export function refreshStats(game) {
  const oldMax = game.stats.maxHp;
  game.stats = computeStats(game.meta, game.loadout, { cores: game.cores });
  const gain = game.stats.maxHp - oldMax;
  if (gain > 0) game.ship.hp += gain;
  game.ship.hp = Math.min(game.ship.hp, game.stats.maxHp);
}

// ---- ship ----

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
  onLaunch(game);
  const v = launchVelocity(sh.vx, sh.vy, dx, dy, sh.gauge, game.stats);
  sh.vx = v.vx; sh.vy = v.vy;
  sh.boostT = game.stats.boostDuration;
  sh.fadeT = 0;
  sh.gaugeBank = 0;
  game.dashId++;
  game.events.push({ type: 'launch', gauge: sh.gauge, x: sh.x, y: sh.y, dx, dy });
}

// amount: hp lost, slow: share of speed lost (0..1)
export function damageShip(game, amount, slow, cause = 'other') {
  const sh = game.ship;
  if (sh.invulnT > 0 || game.debug.invincible) return false;
  sh.hp -= amount * game.stats.damageTakenMult;
  const k = 1 - Math.min(0.9, slow * game.stats.hitSlowMult);
  sh.vx *= k; sh.vy *= k;
  sh.invulnT = CONFIG.invulnTime;
  game.events.push({ type: 'hurt', amount: amount * game.stats.damageTakenMult, x: sh.x, y: sh.y, cause });
  addText(game, sh.x, sh.y - 30, `-${Math.round(amount * game.stats.damageTakenMult)}`, '#ff6b5a');
  onShipHurt(game);
  return true;
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
      onPierce(game);
      if (e.T.steal) { const k = 1 - e.T.steal * stats.hitSlowMult; sh.vx *= k; sh.vy *= k; game.events.push({ type: 'drain', x: e.x, y: e.y }); }
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
    sh.vx *= stats.bounceKeep; sh.vy *= stats.bounceKeep;
    if (Math.hypot(sh.vx, sh.vy) < 220) { sh.vx = nx * 220; sh.vy = ny * 220; }
    if (!stats.reflect) sh.boostT = 0;
    damageEnemy(game, e, res.damage, { crit, cause: 'bump', dirX: -nx, dirY: -ny });
    e.hitCD = 0.25;
    damageShip(game, res.shipDamage * stats.bounceDamageMult, 0, `bump:${e.type}`);
    game.events.push({ type: 'bounce', x: sh.x, y: sh.y });
    break;
  }
}

function collideBodies(game) {
  const sh = game.ship;
  const R = CONFIG.shipRadius;
  const f = game.field;
  const restitution = game.stats.reflect ? 0.9 : CONFIG.crashRestitution;
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
      sh.vx -= (1 + restitution) * vn * nx;
      sh.vy -= (1 + restitution) * vn * ny;
      const dmg = Math.max(0, -vn - 200) * CONFIG.crashDamage * game.stats.bounceDamageMult;
      if (dmg > 0) damageShip(game, dmg, 0, b === f.planet ? 'planet' : 'moon');
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

function recordTrail(sh, dt) {
  sh.trailAcc += dt;
  if (sh.trailAcc < 1 / 60) return;
  sh.trailAcc = 0;
  sh.trail.push({ x: sh.x, y: sh.y });
  if (sh.trail.length > 150) sh.trail.shift();
}

// ---- enemies ----

function flushNewEnemies(game) {
  if (!game.newEnemies.length) return;
  for (const e of game.newEnemies) game.enemies.push(e);
  game.newEnemies.length = 0;
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

// ---- pickups ----

function updateGems(game, dt) {
  const sh = game.ship;
  const pr = game.stats.pickupRadius;
  const sp = Math.hypot(sh.vx, sh.vy);
  for (const g of game.gems) {
    g.age += dt;
    const dx = sh.x - g.x, dy = sh.y - g.y;
    const d = Math.hypot(dx, dy);
    if (d < pr || g.pulled) {
      g.pulled = true;
      const pull = 700 + sp * 1.2;
      g.x += (dx / (d || 1)) * pull * dt;
      g.y += (dy / (d || 1)) * pull * dt;
    }
    if (d < CONFIG.shipRadius + 14) { g.taken = true; addXp(game, g.v); }
  }
  if (game.gems.some((g) => g.taken)) game.gems = game.gems.filter((g) => !g.taken);
  for (const c of game.coinDrops) {
    const dx = sh.x - c.x, dy = sh.y - c.y;
    const d = Math.hypot(dx, dy);
    if (d < pr * 1.3 || c.pulled) {
      c.pulled = true;
      const pull = 700 + sp * 1.2;
      c.x += (dx / (d || 1)) * pull * dt;
      c.y += (dy / (d || 1)) * pull * dt;
    }
    if (d < CONFIG.shipRadius + 14) { c.taken = true; game.coins += c.v; game.events.push({ type: 'coin' }); }
  }
  if (game.coinDrops.some((c) => c.taken)) game.coinDrops = game.coinDrops.filter((c) => !c.taken);
}

export function addXp(game, v) {
  game.xp += v;
  let need = xpForLevel(game.level);
  while (game.xp >= need) {
    game.xp -= need;
    game.level++;
    game.pendingLevelups++;
    game.ship.hp = Math.min(game.stats.maxHp, game.ship.hp + game.stats.maxHp * CONFIG.levelHeal);
    game.events.push({ type: 'levelup', level: game.level });
    need = xpForLevel(game.level);
  }
}

// ---- fx ----

function updateFx(game, dt) {
  const P = game.fx.particles;
  for (const p of P) { p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= 1 - 2.5 * dt; p.vy *= 1 - 2.5 * dt; p.life -= dt; }
  game.fx.particles = P.filter((p) => p.life > 0);
  for (const t of game.fx.texts) { t.y -= 40 * dt; t.life -= dt; }
  game.fx.texts = game.fx.texts.filter((t) => t.life > 0);
  for (const r of game.fx.rings) r.life -= dt;
  game.fx.rings = game.fx.rings.filter((r) => r.life > 0);
}

// ---- prediction ----

// Ballistic preview of a launch along (dx, dy) with the given gauge, under gravity only.
export function predictPath(game, dx, dy, gauge, seconds) {
  const sh = game.ship;
  const len = Math.hypot(dx, dy) || 1;
  const v = launchVelocity(sh.vx, sh.vy, dx / len, dy / len, gauge, game.stats);
  return simulateFrom(game, { x: sh.x, y: sh.y, vx: v.vx, vy: v.vy, boostT: game.stats.boostDuration, fadeT: 0 }, 0, seconds);
}

function simulateFrom(game, ghost, t0, seconds) {
  const pts = [];
  const h = 1 / 60;
  const field = { ...game.field, moons: game.field.moons.map((m) => ({ ...m })) };
  for (let t = t0; t < seconds; t += h) {
    updateMoons(field, game.t + t);
    const g = gravityAt(field, game.t + t, ghost.x, ghost.y);
    stepShip(ghost, game.stats, h, g.ax, g.ay, 0);
    const p = { x: ghost.x, y: ghost.y, sp: Math.hypot(ghost.vx, ghost.vy), t, vx: ghost.vx, vy: ghost.vy };
    pts.push(p);
    if (hitsBody(field, p.x, p.y)) { p.block = true; break; }
  }
  return pts;
}

function hitsBody(field, x, y) {
  const R = CONFIG.shipRadius;
  for (const b of [field.planet, ...field.moons]) {
    if ((x - b.x) ** 2 + (y - b.y) ** 2 < (b.r + R) ** 2) return true;
  }
  return false;
}

// Marks predicted points that cross a weak spot (hot) and stops at the first enemy that would block.
// With the bounce-preview radar the path continues past the block.
export function annotatePrediction(game, pts, seconds) {
  const R = CONFIG.shipRadius;
  const out = [];
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i];
    let blocker = null;
    queryGrid(game.grid, p.x - R - MAX_ENEMY_R, p.y - R - MAX_ENEMY_R, p.x + R + MAX_ENEMY_R, p.y + R + MAX_ENEMY_R, (e) => {
      const dx = p.x - e.x, dy = p.y - e.y;
      const rr = e.r + R;
      if (dx * dx + dy * dy > rr * rr) return;
      const crit = isWeakHit(e, p.x, p.y, game.stats.weakArcMult);
      if (crit) p.hot = true;
      if (!canPierce(attackPower(p.sp, game.stats), e, crit)) blocker = e;
    });
    out.push(p);
    if (p.block) break;
    if (blocker) {
      p.block = true;
      if (game.stats.predictBounce && seconds) {
        let nx = p.x - blocker.x, ny = p.y - blocker.y;
        const nd = Math.hypot(nx, ny) || 1;
        nx /= nd; ny /= nd;
        let vx = p.vx, vy = p.vy;
        const vn = vx * nx + vy * ny;
        if (vn < 0) { vx -= 2 * vn * nx; vy -= 2 * vn * ny; }
        vx *= game.stats.bounceKeep; vy *= game.stats.bounceKeep;
        const ghost = { x: blocker.x + nx * (blocker.r + R + 1), y: blocker.y + ny * (blocker.r + R + 1), vx, vy, boostT: 0, fadeT: 0 };
        for (const q of simulateFrom(game, ghost, p.t, seconds)) { q.bounced = true; out.push(q); }
      }
      break;
    }
  }
  return out;
}
