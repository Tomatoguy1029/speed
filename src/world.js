import { CONFIG } from './config.js';
import { makeRng, segCircleT } from './math.js';
import { createShip, computeGauge, launchVelocity, stepShip } from './ship.js';
import { createField, updateMoons, dustDragAt } from './field.js';
import { gravityAt } from './gravity.js';
import { attackPower, isWeakHit, resolveRam, pierceKeep, canPierce } from './combat.js';
import { addCombatImpact } from './impact-fx.js';
import { updateEnemy, updateEnemyAim, MAX_ENEMY_R } from './enemies.js';
import { updateEnemyBullets } from './projectiles.js';
import { buildGrid, queryGrid } from './grid.js';
import { updateSpawner, getPhase } from './spawner.js';
import { xpForLevel } from './progression.js';
import { SLOTS, RARITIES, computeStats, moduleDef } from './modules.js';
import { damageEnemy, addText, addRing, explode } from './hits.js';
import { createEffectState, updateEffects, onLaunch, onPierce, onShipHurt } from './effects.js';
import { SPEED_STAGES, speedStage } from './stages.js';
import { controlStep, controlAim, isHyperScheme } from './controls.js';
import { rollLevelChoices, applyLevelChoice, updateGun, perkLevel, perkBlastRadius, perkBlastMult, fullChargePower, vortexRadius, vortexLife } from './upgrades.js';
import { handlePortalInput, updatePortals, portalWorldScale, checkPortalEntry } from './portals.js';

export const STEP = 1 / 120;

export function createGame(opts = {}) {
  const meta = opts.meta || {};
  const seed = opts.seed ?? (Math.random() * 4294967296) >>> 0;
  const loadout = Object.fromEntries(SLOTS.map((s) => [s.id, null]));
  // The portal prototype starts with its arrival wave so the core interaction is immediately testable.
  if ((opts.scheme || CONFIG.controlScheme) === 'portal') loadout.radar = { id: 'portalPulse', slot: 'radar', r: 0, plus: 0 };
  const stats = computeStats(meta, loadout);
  const rng = makeRng(seed);
  const ship = createShip(stats, -CONFIG.startRadius, 0);
  ship.vy = -CONFIG.baseMaxSpeed * 0.3; // start drifting along the orbit
  return {
    t: 0, acc: 0, seed, rng,
    meta, stats, ship, loadout,
    scheme: opts.scheme || CONFIG.controlScheme,
    offerQueue: [], currentOffer: null, lastOfferSlot: null,
    nextOfferAt: 0, nextModuleDropAt: 0,
    field: createField(rng),
    debug: { invincible: false, autoOffer: null },
    enemies: [], newEnemies: [], ebullets: [],
    boss: null, bossSpawned: false,
    leechDrag: 0,
    gems: [], coinDrops: [],
    xp: 0, level: 0, pendingLevelups: 0, levelChoices: null,
    weapons: { gun: 1 }, perks: {}, gunT: 0, vortices: [],
    spawnAcc: 0, waveT: 0,
    phaseId: null,
    endReason: null,
    jump: null, hyper: createHyperState(),
    portals: [], portalSerial: 0, portalDash: null, portalPreview: null, portalTouch: null, portalEntryT: 0,
    portalSpace: { armed: false, seconds: 0, consumed: false },
    portalClock: 0, portalCooldowns: new Map(),
    grid: buildGrid([], 160),
    fx: { particles: [], rings: [], texts: [], ghosts: [], loops: [], impacts: [] },
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
  if (game.boss?.dead) { end(game, 'won', 'boss'); return; }
  frameDt = Math.min(frameDt, 0.1);
  game.portalClock += frameDt;
  for (const [edge, until] of game.portalCooldowns) if (until <= game.portalClock) game.portalCooldowns.delete(edge);
  if (input.release) game.releasePending = { x: input.aimX, y: input.aimY, keyboard: !!input.keyboard };
  updateFx(game, frameDt);
  handlePortalInput(game, input, frameDt);
  updateHyper(game, input, frameDt);
  if (game.hitstop > 0) { game.hitstop -= frameDt; return; }
  // outside a dash the hitstop budget refills slowly, so plain ramming kills keep their beat
  if (!game.jump && !game.portalDash && game.dashStop > 0) game.dashStop = Math.max(0, game.dashStop - frameDt * CONFIG.killHitstopRegen);
  if (game.portalDash) updatePortals(game, frameDt);
  if (game.jump) {
    // jump every frame on real time (world steps are rare while it is nearly frozen)
    const kills = game.kills;
    runJump(game, frameDt);
    const refill = perkLevel(game, 'killRecharge');
    if (refill && game.kills > kills) addHyperCharge(game, (game.kills - kills) * 0.08 * refill);
    collideBodies(game);
    recordTrail(game.ship, frameDt);
  }
  let scale = 1;
  if (isHyperScheme(game.scheme)) scale = hyperWorldScale(game);
  if (game.portalDash) scale = portalWorldScale(game);
  if (game.slowmo > 0) { game.slowmo -= frameDt; scale = Math.min(scale, 0.18); }
  game.timeScale = scale;
  game.acc += frameDt * scale;
  // the run clock keeps real time in hyperdrive and during jumps even though the world crawls
  if (game.jump || game.hyper.focus || game.portalDash) game.t += frameDt * (1 - scale);
  const phaseBefore = jumpPhase(game);
  while (game.acc >= STEP) {
    game.acc -= STEP;
    step(game, STEP, input);
    if (input.snap) input = { ...input, snap: null }; // one-shot per frame, not per substep
    if (jumpPhase(game) !== phaseBefore) { game.acc = 0; break; } // time scale changes next frame
    if (game.state !== 'play') break;
    // level-ups wait until hyperdrive and jumps are over, like module offers
    if (game.pendingLevelups > 0 && !game.jump && !game.hyper.focus && !game.portalDash) { openLevelup(game); break; }
    if (game.offerQueue.length) {
      absorbDuplicates(game);
      if (game.offerQueue.length && !game.jump && !game.hyper.focus &&
          (!isHyperScheme(game.scheme) || game.t >= game.nextOfferAt)) { openOffer(game); break; }
    }
  }
  if (isHyperScheme(game.scheme) && !game.portalDash && game.slowmo <= 0) game.timeScale = hyperWorldScale(game);
  if (game.state === 'play' && game.t >= CONFIG.runTime) end(game, 'lost', 'time');
}

// Heading follows the travel direction; when nearly still it keeps whatever the controls last set.
function updateHeading(sh) {
  const sp = Math.hypot(sh.vx, sh.vy);
  if (sp > CONFIG.pivotSpeed) { sh.hx = sh.vx / sp; sh.hy = sh.vy / sp; }
}

// Direction a keyboard/hover launch would take right now.
function schemeAim(game, input) {
  return controlAim(game, input) || { x: game.ship.hx * 100, y: game.ship.hy * 100 };
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

  const ctl = game.jump || game.portalDash ? { ax: 0, ay: 0 } : controlStep(game, input, dt);
  updateHeading(sh);
  const aim = schemeAim(game, input);
  sh.markX = aim.x / 100; sh.markY = aim.y / 100;
  if (game.jump || game.portalDash) {
    game.releasePending = null; // presses during a jump do not launch
  } else if (input.charging && !game.releasePending) {
    if (!sh.charging) { sh.charging = true; sh.chargeT = 0; }
    sh.chargeT += dt;
    sh.gauge = computeGauge(sh.chargeT, stats, sh.gaugeBank);
    sh.aimX = input.keyboard ? aim.x : input.aimX;
    sh.aimY = input.keyboard ? aim.y : input.aimY;
  }
  if (game.releasePending && !game.jump && !game.portalDash) {
    const r = game.releasePending;
    game.releasePending = null;
    if (sh.charging) {
      if (r.keyboard) launch(game, aim.x, aim.y);
      else launch(game, r.x, r.y);
    }
    sh.charging = false;
  }

  updateMoons(game.field, game.t);
  game.leechDrag = 0;
  updateEnemyAim(game, dt);
  for (const e of game.enemies) updateEnemy(e, game, dt);
  flushNewEnemies(game);
  separateEnemies(game);
  game.grid = buildGrid(game.enemies, 160);

  if (!game.jump && !game.portalDash) {
    const g = gravityAt(game.field, game.t, sh.x, sh.y);
    const drag = dustDragAt(game.field, sh.x, sh.y) + game.leechDrag;
    const x0 = sh.x, y0 = sh.y;
    stepShip(sh, stats, dt, g.ax + ctl.ax, g.ay + ctl.ay, drag);
    if (isHyperScheme(game.scheme)) hyperSlowdown(game, dt);
    collideEnemies(game, x0, y0);
    collideBodies(game);
    checkPortalEntry(game, x0, y0);
  }
  if (sh.invulnT > 0) sh.invulnT -= dt;
  updateGun(game, dt);
  updateVortices(game, dt);
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

  if (game.boss?.dead) end(game, 'won', 'boss');
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

// Picking up a module you already have upgrades it (+1, +15% effect each) instead of asking.
export function absorbDuplicates(game) {
  while (game.offerQueue.length) {
    const o = game.offerQueue[0];
    const cur = game.loadout[o.slot];
    if (!cur || cur.id !== o.id) return;
    game.offerQueue.shift();
    cur.r = Math.max(cur.r, o.r);
    cur.plus = (cur.plus || 0) + 1;
    refreshStats(game);
    const sh = game.ship;
    addText(game, sh.x, sh.y - 46, `${moduleDef(cur.id).name} +${cur.plus}`, RARITIES[cur.r].color, 20);
    game.events.push({ type: 'upgrade', mod: cur });
  }
}

export function pushOffer(game, mod, source) {
  game.lastOfferSlot = mod.slot;
  game.offerQueue.push({ ...mod, source });
}

function openOffer(game) {
  const auto = game.debug.autoOffer;
  if (isHyperScheme(game.scheme)) game.nextOfferAt = game.t + CONFIG.hyperOfferInterval;
  game.state = 'offer';
  game.currentOffer = game.offerQueue.shift();
  game.ship.charging = false;
  game.releasePending = null;
  game.events.push({ type: 'offer' });
  if (auto) while (game.state === 'offer') resolveOffer(game, auto === 'equip' || (auto === 'better' && isBetter(game, game.currentOffer)));
}

// ---- level-ups ----

function openLevelup(game) {
  game.state = 'levelup';
  game.levelChoices = rollLevelChoices(game);
  game.ship.charging = false;
  game.releasePending = null;
  game.events.push({ type: 'levelupOpen' });
  if (game.debug.autoOffer || game.debug.autoLevel) while (game.state === 'levelup') resolveLevelup(game, 0);
}

// Take choice i; further pending level-ups roll new choices right away.
export function resolveLevelup(game, i) {
  const c = game.levelChoices?.[i];
  if (!c) return;
  applyLevelChoice(game, c);
  game.events.push({ type: 'levelupPick', choice: c });
  game.pendingLevelups = Math.max(0, game.pendingLevelups - 1);
  if (game.pendingLevelups > 0) game.levelChoices = rollLevelChoices(game);
  else { game.levelChoices = null; game.state = 'play'; }
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
    game.loadout[mod.slot] = { id: mod.id, slot: mod.slot, r: mod.r, plus: 0 };
    refreshStats(game);
    game.events.push({ type: 'equip', mod });
  }
  absorbDuplicates(game);
  if (game.offerQueue.length && !isHyperScheme(game.scheme)) {
    game.currentOffer = game.offerQueue.shift();
  } else {
    game.currentOffer = null;
    game.state = 'play';
  }
}

export function refreshStats(game) {
  const oldMax = game.stats.maxHp;
  game.stats = computeStats(game.meta, game.loadout, { cores: game.cores, level: game.level });
  const gain = game.stats.maxHp - oldMax;
  if (gain > 0) game.ship.hp += gain;
  game.ship.hp = Math.min(game.ship.hp, game.stats.maxHp);
}

// ---- hyperdrive (hyper scheme) ----
// Charges refill over time (up to hyperMaxCharges). Space opens hyperdrive: the world slows and each
// click jumps straight toward the clicked point, clamped to the reach circle. Jumps chain while charges last.

export function createHyperState() {
  return { charges: CONFIG.hyperMaxCharges, progress: 0, focus: false, focusT: 0, queue: [], chain: 0, lines: [] };
}

// Charge cap: the base plus the spare-cell perk.
export function hyperMaxCharges(game) {
  return CONFIG.hyperMaxCharges + perkLevel(game, 'extraCell');
}

function jumpPhase(game) {
  return game.jump ? 'jump' : game.portalDash ? `portal:${game.portalDash.phase}` : game.hyper.focus ? 'focus' : null;
}

// Jump reach: grows with max speed and range modules.
export function hyperReach(game) {
  return CONFIG.hyperRadius * (game.stats.maxSpeed / CONFIG.baseMaxSpeed) * game.stats.rangeMult;
}

// Seconds per charge; charge-time stats (modules, levels) shorten it.
export function hyperChargeTime(game) {
  return CONFIG.hyperChargeTime * (game.stats.chargeTime / CONFIG.chargeTime) * Math.pow(0.85, perkLevel(game, 'quickCell'));
}

export function addHyperCharge(game, share) {
  const h = game.hyper;
  const max = hyperMaxCharges(game);
  if (h.charges >= max) { h.progress = 0; return; }
  h.progress += share;
  while (h.progress >= 1 && h.charges < max) {
    h.progress -= 1;
    h.charges++;
    game.events.push({ type: 'dashReady', charges: h.charges });
  }
  if (h.charges >= max) h.progress = 0;
}

// How far the wave from a jump reaches (the band drawn around it).
export function waveRadius(game) {
  return CONFIG.waveRadius * game.stats.waveRadiusMult;
}

// A jump gives off a wave: enemies within reach take damage once per pass and are pushed away
// from the line. Sampled finely so long, fast jumps leave no gaps.
export function waveAlong(game, r, x0, y0, x1, y1) {
  const W = waveRadius(game);
  const len = Math.hypot(x1 - x0, y1 - y0);
  const n = Math.max(1, Math.ceil(len / Math.min(W, 40)));
  const dmg = attackPower(r.speed, game.stats) * (r.power || 1) * CONFIG.waveDamage * game.stats.waveDmgMult;
  for (let k = 1; k <= n; k++) {
    const px = x0 + (x1 - x0) * k / n, py = y0 + (y1 - y0) * k / n;
    for (const [id, e] of r.waveInside) {
      if (e.dead || Math.hypot(px - e.x, py - e.y) > e.r + W + 2) r.waveInside.delete(id);
    }
    queryGrid(game.grid, px - W - MAX_ENEMY_R, py - W - MAX_ENEMY_R, px + W + MAX_ENEMY_R, py + W + MAX_ENEMY_R, (e) => {
      if (r.waveInside.has(e.id)) return;
      const d = Math.hypot(e.x - px, e.y - py);
      if (d > e.r + W) return;
      r.waveInside.set(e.id, e);
      damageEnemy(game, e, dmg, { cause: 'wave', dirX: (e.x - px) / (d || 1), dirY: (e.y - py) / (d || 1), knock: 260 });
    });
    r.waveAcc += len / n;
    if (r.waveAcc >= 45) { r.waveAcc = 0; addRing(game, px, py, W, 'rgba(130,225,255,0.9)', 0.35); }
  }
}

// World speed during a jump: the faster the jump, the slower everything else.
function jumpWorldScale(game) {
  return Math.max(CONFIG.dashScaleMin, Math.min(1, CONFIG.dashSlowRef / Math.max(1, game.jump.speed)));
}

function hyperWorldScale(game) {
  let s = 1;
  if (game.hyper.focus) s = CONFIG.hyperFocusScale;
  if (game.jump) s = Math.min(s, jumpWorldScale(game));
  return s;
}

// Charges, the mode toggle and clicks; runs every frame on real time.
function updateHyper(game, input, frameDt) {
  if (!isHyperScheme(game.scheme)) return;
  const h = game.hyper;
  // charges refill on play time (they crawl with the world while it is slowed)
  addHyperCharge(game, frameDt * game.timeScale / hyperChargeTime(game));
  if (input.hyperToggle) {
    if (h.focus) closeHyper(game);
    else if (h.charges >= 1 || game.jump) openHyper(game);
  } else if (input.hyperExit && h.focus) closeHyper(game);
  if (!h.focus) return;
  if (!game.jump) h.focusT += frameDt;
  // clicks made during a jump (or several in one frame) wait their turn, as many as there are charges
  for (const c of input.jumpClicks || []) if (h.queue.length < h.charges) h.queue.push({ x: c.x, y: c.y });
  while (!game.jump && h.queue.length) startJump(game, h.queue.shift());
  if (!game.jump && (h.charges < 1 || (CONFIG.hyperFocusMax > 0 && h.focusT >= CONFIG.hyperFocusMax))) closeHyper(game);
}

function openHyper(game) {
  const h = game.hyper;
  h.focus = true; h.focusT = 0; h.queue = []; h.chain = 0; h.lines = [];
  game.ship.charging = false;
  game.events.push({ type: 'hyperOpen' });
}

function closeHyper(game) {
  const h = game.hyper;
  if (!h.focus) return;
  h.focus = false; h.queue = [];
  game.events.push({ type: 'hyperClose' });
}

// Where a jump from the ship toward c ends: clamped to the reach circle, stopped short of planets.
export function jumpTarget(game, c) {
  const sh = game.ship;
  let dx = c.x - sh.x, dy = c.y - sh.y;
  let len = Math.hypot(dx, dy);
  if (len < 1) { dx = sh.hx; dy = sh.hy; len = 1; }
  const ux = dx / len, uy = dy / len;
  let L = Math.min(len, hyperReach(game));
  const R = CONFIG.shipRadius;
  let blocked = false;
  for (const b of [game.field.planet, ...game.field.moons]) {
    const t = segCircleT(sh.x, sh.y, sh.x + ux * L, sh.y + uy * L, b.x, b.y, b.r + R);
    if (t >= 0) { L = Math.max(0, t * L - 2); blocked = true; }
  }
  return { x: sh.x + ux * L, y: sh.y + uy * L, ux, uy, len: L, blocked };
}

function startJump(game, c) {
  const h = game.hyper, sh = game.ship;
  if (h.charges < 1) return false;
  const tgt = jumpTarget(game, c);
  if (tgt.len < 4) return false;
  // full-charge perk: a jump from a full stock never bounces and hits harder
  const full = perkLevel(game, 'fullCharge') && h.charges >= hyperMaxCharges(game);
  h.charges--;
  h.chain++;
  onLaunch(game);
  const v = launchVelocity(sh.vx, sh.vy, tgt.ux, tgt.uy, game.stats.gaugeMax, game.stats);
  const speed = Math.max(Math.hypot(v.vx, v.vy), 1);
  sh.vx = tgt.ux * speed; sh.vy = tgt.uy * speed;
  sh.boostT = game.stats.boostDuration; sh.fadeT = 0; sh.gaugeBank = 0;
  sh.aimAngle = Math.atan2(tgt.uy, tgt.ux);
  game.dashId++;
  // speed = the jump speed (attack, momentum afterwards); rate = how fast it crosses on screen
  const rate = Math.max(speed, tgt.len * game.stats.traceSpeedMult / CONFIG.hyperJumpTime);
  const from = { x: sh.x, y: sh.y }, to = { x: tgt.x, y: tgt.y };
  game.jump = { from, to, ux: tgt.ux, uy: tgt.uy, len: tgt.len, pos: 0,
    speed, rate, inside: new Map(), passes: new Map(), waveInside: new Map(), waveAcc: 0,
    chain: h.chain, overdrive: !!full, power: full ? fullChargePower(perkLevel(game, 'fullCharge')) : 1,
    crossings: perkLevel(game, 'crossBlast') ? lineCrossings(h.lines, from, to) : [] };
  if (h.focus) h.lines.push({ a: from, b: to });
  game.events.push({ type: 'launch', gauge: game.stats.gaugeMax, x: sh.x, y: sh.y, dx: tgt.ux, dy: tgt.uy });
  return true;
}

// Cross the jump quickly on real time; piercing costs no speed, a bounce ends it.
function runJump(game, realDt) {
  const j = game.jump, sh = game.ship;
  const R = CONFIG.shipRadius;
  const move = Math.min(j.rate * realDt, j.len - j.pos);
  if (move > 1e-9) {
    const x0 = sh.x, y0 = sh.y;
    for (const [id, e] of j.inside) {
      if (e.dead || Math.hypot(x0 - e.x, y0 - e.y) > e.r + R + 2) j.inside.delete(id);
    }
    j.pos += move;
    sh.x = j.from.x + j.ux * j.pos; sh.y = j.from.y + j.uy * j.pos;
    sh.vx = j.ux * j.speed; sh.vy = j.uy * j.speed;
    waveAlong(game, j, x0, y0, sh.x, sh.y);
    if (collideEnemies(game, x0, y0, R, j)) { game.jump = null; endJump(game, j); return; }
  }
  if (j.pos >= j.len - 1e-9) {
    game.jump = null;
    endJump(game, j);
    // keep part of the jump speed, then the normal slowdown takes over
    sh.vx = j.ux * j.speed * CONFIG.hyperKeep; sh.vy = j.uy * j.speed * CONFIG.hyperKeep;
    sh.boostT = CONFIG.hyperCoast; sh.fadeT = 0;
  }
}

// Where a new jump line crosses earlier ones from this hyperdrive (not at the shared endpoints).
function lineCrossings(lines, p, q) {
  const out = [];
  for (const { a, b } of lines) {
    const rx = q.x - p.x, ry = q.y - p.y, sx = b.x - a.x, sy = b.y - a.y;
    const den = rx * sy - ry * sx;
    if (Math.abs(den) < 1e-9) continue;
    const t = ((a.x - p.x) * sy - (a.y - p.y) * sx) / den;
    const u = ((a.x - p.x) * ry - (a.y - p.y) * rx) / den;
    if (t > 0.02 && t < 0.98 && u > 0.02 && u < 0.98) out.push({ x: p.x + rx * t, y: p.y + ry * t });
  }
  return out;
}

// Perks that go off when a jump ends (landing or bouncing).
function endJump(game, j) {
  const sh = game.ship;
  const atk = attackPower(j.speed, game.stats) * j.power;
  const chainN = perkLevel(game, 'chainBlast');
  if (chainN && j.chain % 3 === 0) {
    explode(game, sh.x, sh.y, perkBlastRadius(chainN), atk * perkBlastMult(chainN), { cause: 'chainBlast', color: '#ff9f40', knock: 520, life: 0.5 });
    addText(game, sh.x, sh.y - 40, '連鎖爆発', '#ffb340', 20);
  }
  const crossN = perkLevel(game, 'crossBlast');
  for (const c of j.crossings) {
    explode(game, c.x, c.y, 120 + 25 * crossN, atk * (0.8 + 0.4 * crossN), { cause: 'crossBlast', color: '#c995ff', knock: 420, life: 0.45 });
  }
  const vortexN = perkLevel(game, 'vortex');
  if (vortexN) game.vortices.push({ x: sh.x, y: sh.y, r: vortexRadius(vortexN), life: vortexLife(vortexN), max: vortexLife(vortexN) });
}

// Vortices left by jumps pull nearby enemies (not the boss) toward their centre.
function updateVortices(game, dt) {
  if (!game.vortices.length) return;
  for (const v of game.vortices) {
    v.life -= dt;
    queryGrid(game.grid, v.x - v.r - MAX_ENEMY_R, v.y - v.r - MAX_ENEMY_R, v.x + v.r + MAX_ENEMY_R, v.y + v.r + MAX_ENEMY_R, (e) => {
      if (e.dead || e.type === 'boss') return;
      const dx = v.x - e.x, dy = v.y - e.y, d = Math.hypot(dx, dy);
      if (d > v.r || d < 8) return;
      const pull = Math.min(d, 420 * dt / Math.max(1, e.r / 20));
      e.x += dx / d * pull; e.y += dy / d * pull;
    });
  }
  game.vortices = game.vortices.filter((v) => v.life > 0);
}

// After a jump the kept speed fades back toward cruise speed, so the ship slows down over time.
function hyperSlowdown(game, dt) {
  const sh = game.ship;
  if (sh.boostT > 0) return;
  const sp = Math.hypot(sh.vx, sh.vy);
  const cruise = game.stats.maxSpeed * CONFIG.steerCruise;
  if (sp <= cruise) return;
  const k = (cruise + (sp - cruise) * Math.exp(-CONFIG.hyperDecay * dt)) / sp;
  sh.vx *= k; sh.vy *= k;
}

// Preview of a straight jump: enemies it would cut (body or wave) and the first one that would stop it.
export function previewPath(game, points) {
  if (!points || points.length < 2) return { samples: [], block: null, targets: [] };
  const pts = points, sh = game.ship, R = CONFIG.shipRadius, W = waveRadius(game);
  const l = Math.hypot(pts[1].x - pts[0].x, pts[1].y - pts[0].y) || 1;
  const v = launchVelocity(sh.vx, sh.vy, (pts[1].x - pts[0].x) / l, (pts[1].y - pts[0].y) / l, game.stats.gaugeMax, game.stats);
  const atk = attackPower(Math.hypot(v.vx, v.vy), game.stats);
  const samples = [];
  const targets = new Map(); // enemy -> { crit, hits }
  let prev = new Set();
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i], b = pts[i + 1];
    const len = Math.hypot(b.x - a.x, b.y - a.y);
    const n = Math.max(1, Math.ceil(len / 14));
    for (let k = 1; k <= n; k++) {
      const p = { x: a.x + (b.x - a.x) * k / n, y: a.y + (b.y - a.y) * k / n, hot: false };
      let blocked = false;
      const cur = new Set();
      queryGrid(game.grid, p.x - W - MAX_ENEMY_R, p.y - W - MAX_ENEMY_R, p.x + W + MAX_ENEMY_R, p.y + W + MAX_ENEMY_R, (e) => {
        const d2 = (p.x - e.x) ** 2 + (p.y - e.y) ** 2;
        if (d2 > (e.r + W) ** 2) return;
        const t = targets.get(e) || { crit: false, body: false };
        targets.set(e, t);
        if (d2 > (e.r + R) ** 2) return; // wave only
        cur.add(e);
        if (prev.has(e)) return; // still inside from the previous sample: same pass
        const crit = isWeakHit(e, p.x, p.y, game.stats.weakArcMult);
        if (crit) p.hot = true;
        if (!canPierce(atk, e, crit)) { blocked = true; return; }
        t.body = true; t.crit = t.crit || crit;
      });
      prev = cur;
      samples.push(p);
      if (blocked) return { samples, block: p, targets: [...targets] };
    }
  }
  return { samples, block: null, targets: [...targets] };
}

// ---- ship ----

function launch(game, ax, ay) {
  const sh = game.ship;
  const len = Math.hypot(ax, ay);
  let dx, dy;
  if (len < CONFIG.minDrag) {
    dx = sh.hx; dy = sh.hy;
  } else {
    dx = ax / len; dy = ay / len;
  }
  onLaunch(game);
  sh.aimAngle = Math.atan2(dy, dx);
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

// R: hit radius of the ship.
// run: the jump state; during a jump an enemy can be hit again each time the ship re-enters it.
export function collideEnemies(game, x0, y0, R = CONFIG.shipRadius, run = null) {
  const sh = game.ship, stats = game.stats;
  const x1 = sh.x, y1 = sh.y;
  const pad = R + MAX_ENEMY_R;
  const hits = [];
  queryGrid(game.grid, Math.min(x0, x1) - pad, Math.min(y0, y1) - pad, Math.max(x0, x1) + pad, Math.max(y0, y1) + pad, (e) => {
    if (run ? run.inside.has(e.id) : e.hitCD > 0) return;
    const t = segCircleT(x0, y0, x1, y1, e.x, e.y, e.r + R);
    if (t >= 0) hits.push({ e, t });
  });
  if (!hits.length) return false;
  hits.sort((a, b) => a.t - b.t);
  for (const { e, t } of hits) {
    const hx = x0 + (x1 - x0) * t, hy = y0 + (y1 - y0) * t;
    const sp = Math.hypot(sh.vx, sh.vy);
    const ux = sp > 0 ? sh.vx / sp : 0, uy = sp > 0 ? sh.vy / sp : 0;
    const atk = attackPower(sp, stats) * (run?.power || 1);
    const crit = isWeakHit(e, hx, hy, stats.weakArcMult);
    let res = resolveRam(atk, e, crit, stats);
    if (run?.overdrive && !res.pierce) res = { pierce: true, damage: atk * (crit ? stats.critMult : 1), shipDamage: 0 };
    if (res.pierce) {
      damageEnemy(game, e, res.damage, { crit, cause: 'ram', dirX: ux, dirY: uy });
      if (crit) {
        const len = Math.hypot(hx - e.x, hy - e.y) || 1;
        addCombatImpact(game, e, 'weak', (hx - e.x) / len, (hy - e.y) / len);
      }
      e.hitCD = 0.3;
      if (run) {
        run.inside.set(e.id, e);
        const n = (run.passes.get(e.id) || 0) + 1;
        run.passes.set(e.id, n);
        if (n > 1) addText(game, e.x + e.r, e.y - e.r - 16, `×${n}`, crit ? '#ffe46b' : '#ffffff', 22 + 4 * Math.min(n, 5));
      }
      const keep = game.jump ? 1 : pierceKeep(e, e.dead, stats);
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
    addCombatImpact(game, e, 'block', nx, ny);
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
    return true;
  }
  return false;
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

export function separateEnemies(game) {
  for (let pass = 0; pass < 2; pass++) {
    const grid = buildGrid(game.enemies, 120);
    for (const e of game.enemies) {
      if (e.dead) continue;
      const reach = e.r + MAX_ENEMY_R + CONFIG.enemySpacing;
      queryGrid(grid, e.x - reach, e.y - reach, e.x + reach, e.y + reach, (o) => {
        if (o.id <= e.id) return;
        let dx = o.x - e.x, dy = o.y - e.y;
        const min = e.r + o.r + CONFIG.enemySpacing;
        const d2 = dx * dx + dy * dy;
        if (d2 >= min * min) return;
        const d = Math.sqrt(d2);
        if (d < 1e-6) {
          const a = (e.id + o.id) * 2.39996322973;
          dx = Math.cos(a); dy = Math.sin(a);
        } else { dx /= d; dy /= d; }
        const push = (min - d) * 0.5;
        const wE = o.r * o.r / (e.r * e.r + o.r * o.r);
        e.x -= dx * push * 2 * wE; e.y -= dy * push * 2 * wE;
        o.x += dx * push * 2 * (1 - wE); o.y += dy * push * 2 * (1 - wE);
      });
    }
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
    refreshStats(game); // level-ups raise base stats; modules come from enemy drops
    addText(game, game.ship.x, game.ship.y - 34, `Lv ${game.level}`, '#6dffb0', 18);
  }
}

// ---- fx ----

function updateFx(game, dt) {
  const P = game.fx.particles;
  for (const p of P) { p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= 1 - 2.5 * dt; p.vy *= 1 - 2.5 * dt; p.life -= dt; }
  game.fx.particles = P.filter((p) => p.life > 0);
  for (const t of game.fx.texts) { t.y -= 40 * dt; t.life -= dt; }
  for (const g of game.fx.ghosts) g.life -= dt;
  game.fx.ghosts = game.fx.ghosts.filter((g) => g.life > 0);
  game.fx.texts = game.fx.texts.filter((t) => t.life > 0);
  for (const r of game.fx.rings) r.life -= dt;
  game.fx.rings = game.fx.rings.filter((r) => r.life > 0);
  for (const loop of game.fx.loops) loop.life -= dt;
  game.fx.loops = game.fx.loops.filter((loop) => loop.life > 0);
  for (const impact of game.fx.impacts) impact.life -= dt;
  game.fx.impacts = game.fx.impacts.filter((impact) => impact.life > 0);
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
