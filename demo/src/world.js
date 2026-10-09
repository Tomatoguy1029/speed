import { CONFIG } from './config.js';
import { makeRng, segCircleT } from './math.js';
import { createShip, computeGauge, launchVelocity, stepShip } from './ship.js';
import { createField, updateMoons, dustDragAt } from './field.js';
import { updateMeteorField } from './meteor-field.js';
import { gravityAt } from './gravity.js';
import { attackPower, isWeakHit, resolveRam, pierceKeep, canPierce } from './combat.js';
import { addCombatImpact } from './impact-fx.js';
import { updateEnemy, updateEnemyAim, MAX_ENEMY_R } from './enemies.js';
import { updateEnemyBullets } from './projectiles.js';
import { buildGrid, queryGrid } from './grid.js';
import { updateSpawner, getPhase, phaseTarget } from './spawner.js';
import { xpForLevel } from './progression.js';
import { SLOTS, RARITIES, computeStats, moduleDef } from './modules.js';
import { damageEnemy, addText, addRing } from './hits.js';
import { createEffectState, updateEffects, onLaunch, onPierce, onShipHurt, endTraceAttack } from './effects.js';
import { onRunLaunch, onRunTrail, onRunContact, updateRunWeapons, updateRunFollowers, updateRunSonic, onRunElectricContact } from './run-weapons.js';
import { computeRunStats, rollRunChoices, grantRunItem, runModuleDef } from './run-build.js';
import { updateRareWeapons } from './rare-weapons.js';
import { SPEED_STAGES, speedStage } from './stages.js';
import { controlStep, controlAim, isDrawScheme } from './controls.js';
import { handlePortalInput, updatePortals, portalWorldScale, checkPortalEntry } from './portals.js';
import { recordBossApproach, advanceBossFinish, beginShipDeath, advanceShipDeath } from './finale.js';

export const STEP = 1 / 120;

export function createGame(opts = {}) {
  const meta = opts.meta || {};
  const seed = opts.seed ?? (Math.random() * 4294967296) >>> 0;
  const loadout = Object.fromEntries(SLOTS.map((s) => [s.id, null]));
  // The portal prototype starts with its arrival wave so the core interaction is immediately testable.
  if ((opts.scheme || CONFIG.controlScheme) === 'portal') loadout.radar = { id: 'portalPulse', slot: 'radar', r: 0, plus: 0 };
  const newBuild = isDrawScheme(opts.scheme || CONFIG.controlScheme);
  const weapons = { forward: 1 }, traits = {};
  const stats = newBuild ? computeRunStats(meta, weapons, traits) : computeStats(meta, loadout);
  const rng = makeRng(seed);
  const ship = createShip(stats, -CONFIG.startRadius, 0);
  ship.vy = -CONFIG.baseMaxSpeed * 0.3; // start drifting along the orbit
  return {
    t: 0, acc: 0, seed, rng,
    meta, stats, ship, loadout, newBuild, weapons, traits,
    rareQueue: [], rareOffer: null, levelChoices: null, buildClock: 0, weaponState: {}, drones: [], wstate: {}, wproj: [], wfx: [],
    runPaths: [], runTravel: [], vortexes: [], dashKills: 0, nextKillBoom: 0, criticalBeamAt: 0,
    scheme: opts.scheme || CONFIG.controlScheme,
    offerQueue: [], currentOffer: null, lastOfferSlot: null,
    field: createField(rng),
    debug: { invincible: false, autoOffer: null },
    enemies: [], newEnemies: [], ebullets: [],
    boss: null, bossSpawned: false,
    finale: null, death: null, finishFrames: [], finishClock: 0, sonicWaves: [],
    leechDrag: 0,
    gems: [], coinDrops: [],
    xp: 0, level: 0, pendingLevelups: 0,
    spawnAcc: 0, waveT: 0,
    phaseId: null,
    endReason: null,
    draw: null, lastPath: null,
    portals: [], portalSerial: 0, portalDash: null, portalPreview: null, portalTouch: null, portalEntryT: 0,
    portalSpace: { armed: false, seconds: 0, consumed: false },
    portalClock: 0, portalCooldowns: new Map(),
    dashMeter: 1, // normalized charge capacity; time-filled in the draw prototype
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
  frameDt = Math.min(frameDt, 0.1);
  if (game.state === 'dying') {
    if (game.death.phase !== 'freeze') updateFx(game, frameDt);
    if (advanceShipDeath(game, frameDt)) end(game, 'lost', 'hp');
    return;
  }
  if (game.state === 'finishing') {
    updateFx(game, frameDt * (game.finale.phase === 'slow' ? CONFIG.bossFinishReplayWindow / CONFIG.bossFinishSlowTime : 1));
    const finished = advanceBossFinish(game, frameDt);
    if (finished) end(game, 'won', 'boss');
    return;
  }
  if (game.state !== 'play') return;
  recordBossApproach(game, frameDt);
  game.buildClock += frameDt;
  if (game.newBuild && !game.draw) {
    const old = game.dashMeter;
    game.dashMeter = Math.min(1, old + frameDt / (game.stats.chargeTime * game.stats.gaugeMax));
    if (old < 1 && game.dashMeter >= 1) game.events.push({ type: 'dashReady' });
  }
  if (game.newBuild && !game.draw && !game.portalDash) {
    if (game.rareQueue.length) { openRareWeapon(game); return; }
    if (game.pendingLevelups) { openRunLevel(game); return; }
  }
  game.portalClock += frameDt;
  for (const [edge, until] of game.portalCooldowns) if (until <= game.portalClock) game.portalCooldowns.delete(edge);
  if (input.release) game.releasePending = { x: input.aimX, y: input.aimY, keyboard: !!input.keyboard };
  updateFx(game, frameDt);
  handlePortalInput(game, input, frameDt);
  if ((input.dash || input.drawClick) && isDrawScheme(game.scheme) && !game.draw && game.dashMeter >= (game.newBuild ? CONFIG.drawMinCharge : 1)) {
    startDrawing(game, input);
    input = { ...input, press: false, dash: false, drawRelease: false }; // consume the start click so it cannot also commit
  }
  if (game.hitstop > 0) { game.hitstop -= frameDt; return; }
  // outside a dash the hitstop budget refills slowly, so plain ramming kills keep their beat
  if (!game.draw && !game.portalDash && game.dashStop > 0) game.dashStop = Math.max(0, game.dashStop - frameDt * CONFIG.killHitstopRegen);
  if (game.portalDash) updatePortals(game, frameDt);
  if (game.state !== 'play') return;
  if (game.draw && game.draw.phase === 'draw') updateDrawing(game, input);
  if (game.draw && game.draw.phase === 'run') {
    // trace every frame on real time (world steps are rare while it is nearly frozen)
    runAlongPath(game, frameDt);
    if (game.state !== 'play') return;
    collideBodies(game);
    if (game.state !== 'play') return;
    recordTrail(game.ship, frameDt);
  }
  if (game.newBuild) updateRunFollowers(game);
  if (game.newBuild) updateRunSonic(game, frameDt);
  if (game.newBuild) updateRareWeapons(game, frameDt);
  if (game.state !== 'play') return;
  let scale = 1;
  if (game.draw) scale = drawWorldScale(game);
  if (game.portalDash) scale = portalWorldScale(game);
  if (game.slowmo > 0) { game.slowmo -= frameDt; scale = Math.min(scale, 0.18); }
  game.timeScale = scale;
  game.acc += frameDt * scale;
  // the run clock keeps real time while drawing/tracing even though the world crawls
  if (game.draw || game.portalDash) game.t += frameDt * (1 - scale);
  const phaseBefore = drawPhase(game);
  while (game.acc >= STEP) {
    game.acc -= STEP;
    step(game, STEP, input);
    if (input.snap) input = { ...input, snap: null }; // one-shot per frame, not per substep
    if (game.state !== 'play') break;
    if (drawPhase(game) !== phaseBefore) { game.acc = 0; break; } // time scale changes next frame
    if (game.newBuild && !game.draw && !game.portalDash) {
      if (game.rareQueue.length) { openRareWeapon(game); break; }
      if (game.pendingLevelups) { openRunLevel(game); break; }
    }
    if (game.offerQueue.length) {
      absorbDuplicates(game);
      if (game.offerQueue.length && !game.draw) { openOffer(game); break; }
    }
  }
  if (game.draw && game.slowmo <= 0) game.timeScale = drawWorldScale(game);
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

  const ctl = game.draw || game.portalDash ? { ax: 0, ay: 0 } : controlStep(game, input, dt);
  updateHeading(sh);
  const aim = schemeAim(game, input);
  sh.markX = aim.x / 100; sh.markY = aim.y / 100;
  if (game.draw || game.portalDash) {
    game.releasePending = null; // presses while drawing/running only commit the path
  } else if (input.charging && !game.releasePending) {
    if (!sh.charging) { sh.charging = true; sh.chargeT = 0; }
    sh.chargeT += dt;
    sh.gauge = computeGauge(sh.chargeT, stats, sh.gaugeBank);
    sh.aimX = input.keyboard ? aim.x : input.aimX;
    sh.aimY = input.keyboard ? aim.y : input.aimY;
  }
  if (game.releasePending && !game.draw && !game.portalDash) {
    const r = game.releasePending;
    game.releasePending = null;
    if (sh.charging) {
      if (r.keyboard && isDrawScheme(game.scheme)) startDrawing(game, input);
      else if (r.keyboard) launch(game, aim.x, aim.y);
      else launch(game, r.x, r.y);
    }
    sh.charging = false;
  }

  updateMoons(game.field, game.t);
  updateMeteorField(game, dt);
  game.leechDrag = 0;
  updateEnemyAim(game, dt);
  for (const e of game.enemies) updateEnemy(e, game, dt);
  flushNewEnemies(game);
  game.grid = buildGrid(game.enemies, 160, game.grid);

  if (!game.draw && !game.portalDash) {
    const g = gravityAt(game.field, game.t, sh.x, sh.y);
    const drag = dustDragAt(game.field, sh.x, sh.y) + game.leechDrag;
    const x0 = sh.x, y0 = sh.y;
    stepShip(sh, stats, dt, g.ax + ctl.ax, g.ay + ctl.ay, drag);
    collideEnemies(game, x0, y0);
    if (game.state !== 'play') return;
    collideBodies(game);
    if (game.state !== 'play') return;
    checkPortalEntry(game, x0, y0);
  }
  if (sh.invulnT > 0) sh.invulnT -= dt;
  if (game.newBuild) updateRunWeapons(game, dt);
  if (game.state !== 'play') return;
  updateEnemyBullets(game, dt, (b) => damageShip(game, b.dmg, b.slow, b.kind));
  if (game.state !== 'play') return;
  updateEffects(game, dt);
  if (game.state !== 'play') return;
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

  if (sh.hp <= 0) end(game, 'lost', 'hp');
  else if (game.t >= CONFIG.runTime) end(game, 'lost', 'time');
}

function end(game, state, reason) {
  if (state === 'won') game.coins += CONFIG.escapeBonus;
  game.state = state;
  game.endReason = reason;
  game.events.push({ type: 'end', state, reason });
}

// ---- draw-build level-ups ----

function openRareWeapon(game) {
  game.rareOffer = game.rareOffer || game.rareQueue.shift();
  const id = game.rareOffer, owned = game.weapons[id] || 0;
  const pick = { kind: 'weapon', id, level: owned + 1, rare: true };
  const slots = Object.keys(game.weapons).filter(k => game.weapons[k] > 0);
  game.levelChoices = owned >= CONFIG.weaponMaxLevel ? [] : owned || slots.length < CONFIG.weaponSlots ? [pick] :
    slots.map(replace => ({ ...pick, replace, replaceLevel: game.weapons[replace] }));
  game.levelChoices.push({ kind: 'rareSkip', id });
  game.state = 'levelup';
  game.ship.charging = false; game.releasePending = null;
}

function openRunLevel(game) {
  game.state = 'levelup';
  game.levelChoices = rollRunChoices(game);
  game.ship.charging = false;
  game.releasePending = null;
}

export function resolveRunLevel(game, index) {
  if (game.state !== 'levelup') return false;
  const c = game.levelChoices?.[index];
  if (!c) return false;
  if (game.rareOffer) {
    if (c.kind !== 'rareSkip') {
      if (!runModuleDef('weapon', c.id) || (game.weapons[c.id] || 0) >= CONFIG.weaponMaxLevel) return false;
      const count = Object.values(game.weapons).filter(n => n > 0).length;
      if (!game.weapons[c.id] && count + 1 - (c.replace && game.weapons[c.replace] ? 1 : 0) > CONFIG.weaponSlots) return false;
      if (c.replace) { delete game.weapons[c.replace]; delete game.weaponState[c.replace]; delete game.wstate[c.replace]; }
      if (!grantRunItem(game, 'weapon', c.id)) return false;
      refreshStats(game); game.events.push({ type: 'upgrade', mod: c });
    }
    game.rareOffer = null; game.levelChoices = null; game.state = 'play';
    if (game.rareQueue.length) openRareWeapon(game);
    else if (game.pendingLevelups) openRunLevel(game);
    return true;
  }
  if (c.kind === 'heal') game.ship.hp = Math.min(game.stats.maxHp, game.ship.hp + game.stats.maxHp * 0.3);
  else if (!grantRunItem(game, c.kind, c.id)) return false;
  refreshStats(game);
  game.events.push({ type: 'upgrade', mod: c });
  game.pendingLevelups = Math.max(0, game.pendingLevelups - 1);
  game.levelChoices = null;
  if (game.pendingLevelups) openRunLevel(game);
  else game.state = 'play';
  return true;
}

export function debugRunItem(game, kind, id, levels = 1) {
  if (!game.newBuild || !['play', 'levelup'].includes(game.state)) return false;
  const ok = grantRunItem(game, kind, id, levels);
  const name = runModuleDef(kind, id)?.name || id;
  addText(game, game.ship.x, game.ship.y - 46, ok ? name : '装備枠が満員／強化済み', ok ? '#9fe8ff' : '#ff9f40', 18);
  if (ok) {
    refreshStats(game);
    if (game.state === 'levelup') { if (game.rareOffer) openRareWeapon(game); else game.levelChoices = rollRunChoices(game); }
  }
  return ok;
}

// ---- legacy offers ----

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
  if (game.state === 'play' && !game.draw) {
    absorbDuplicates(game);
    if (game.offerQueue.length) openOffer(game);
  }
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
    game.loadout[mod.slot] = { id: mod.id, slot: mod.slot, r: mod.r, plus: 0 };
    refreshStats(game);
    game.events.push({ type: 'equip', mod });
  }
  absorbDuplicates(game);
  if (game.offerQueue.length) {
    game.currentOffer = game.offerQueue.shift();
  } else {
    game.currentOffer = null;
    game.state = 'play';
  }
}

export function refreshStats(game) {
  const oldMax = game.stats.maxHp;
  const burstPower = game.stats.burstPower, ignoreArmor = game.stats.ignoreArmor;
  game.stats = game.newBuild
    ? computeRunStats(game.meta, game.weapons, game.traits, { cores: game.cores, level: game.level })
    : computeStats(game.meta, game.loadout, { cores: game.cores, level: game.level });
  if (game.newBuild && game.draw?.phase === 'run') { game.stats.burstPower = burstPower; game.stats.ignoreArmor = ignoreArmor; }
  const gain = game.stats.maxHp - oldMax;
  if (gain > 0) game.ship.hp += gain;
  game.ship.hp = Math.min(game.ship.hp, game.stats.maxHp);
}

// ---- draw a path, then run it (draw scheme) ----

function drawPhase(game) {
  return game.draw ? game.draw.phase : game.portalDash ? `portal:${game.portalDash.phase}` : null;
}

export function drawBudget(game, gauge) {
  return CONFIG.drawLength * gauge * (game.stats.maxSpeed / CONFIG.baseMaxSpeed) * game.stats.drawLengthMult;
}

// How far the wave from a traced path reaches (the band drawn around the path).
export function waveRadius(game) {
  return CONFIG.waveRadius * game.stats.waveRadiusMult;
}

// The traced path gives off a wave: enemies within reach take damage once per pass and are
// pushed away from the path. Sampled finely so long, fast traces leave no gaps.
export function waveAlong(game, r, x0, y0, x1, y1) {
  const W = waveRadius(game);
  const len = Math.hypot(x1 - x0, y1 - y0);
  const n = Math.max(1, Math.ceil(len / Math.min(W, 40)));
  const dmg = attackPower(r.speed, game.stats) * CONFIG.waveDamage * game.stats.waveDmgMult;
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
      damageEnemy(game, e, dmg, { cause: 'wave', dirX: (e.x - px) / (d || 1), dirY: (e.y - py) / (d || 1), knock: 260, impactX: px, impactY: py });
    });
    if (game.state === 'finishing') return;
    r.waveAcc += len / n;
    if (r.waveAcc >= 45) { r.waveAcc = 0; addRing(game, px, py, W, 'rgba(130,225,255,0.9)', 0.35); }
  }
}

// World speed while tracing: the faster the dash, the slower everything else.
function traceWorldScale(game) {
  return Math.max(CONFIG.drawRunScaleMin, Math.min(1, CONFIG.drawRunSlowRef / Math.max(1, game.draw.speed)));
}

function drawWorldScale(game) {
  return game.draw.phase === 'draw' ? CONFIG.drawTimeScale : traceWorldScale(game);
}

// Real play seconds needed to fill the draw gauge from empty.
export function dashNeed(game) { return game.stats.chargeTime * game.stats.gaugeMax; }

function startDrawing(game, input) {
  const sh = game.ship;
  sh.glide = false;
  const fullCharge = game.dashMeter >= 1 - 1e-6;
  const gauge = game.stats.gaugeMax * (game.newBuild ? game.dashMeter : 1);
  const budget = drawBudget(game, gauge);
  // Keep the draw prototype's charge until commit; only the drawn length is spent.
  if (!game.newBuild) game.dashMeter = 0;
  // A mouse click starts the line immediately. Keyboard/touch shortcuts can still pick a start.
  const started = !!input.drawClick || (input.mobile && input.press);
  game.draw = { phase: 'draw', points: started ? [startPoint(game, input.clickCursor || input.cursor)] : [],
    budget, used: 0, gauge, charge: game.dashMeter, fullCharge, cursor: input.cursor || null, blocked: false, started, inputMethod: input.mobile ? 'freehand' : CONFIG.drawInput };
  sh.charging = false;
  game.events.push({ type: 'drawStart' });
}

// The path follows the cursor until its length runs out, it reaches a planet, or another click.
function updateDrawing(game, input) {
  const d = game.draw;
  if (input.drawCancel || (input.mobile && input.dash && !d.started)) { game.draw = null; return; }
  if (input.cursor) d.cursor = input.cursor;
  if (!d.started) {
    // the line only starts on a click (or Space), so moving the mouse never draws by accident
    if (input.press) { d.started = true; d.points.push(startPoint(game, d.cursor)); }
    if (input.drawRelease) game.draw = null;
    return;
  }
  if (d.inputMethod === 'points') {
    if (input.drawClick && (input.clickCursor || d.cursor)) extendPath(game, d, input.clickCursor || d.cursor);
    if (input.confirm || input.dash || d.used >= d.budget - 0.5 || d.blocked) {
      if (d.points.length >= 2) commitPath(game);
    }
    return;
  }
  if (input.cursor) extendPath(game, d, input.cursor);
  if (input.mobile && (input.drawRelease || input.dash)) {
    if (d.points.length >= 2) commitPath(game); else game.draw = null;
  } else if (input.press || d.used >= d.budget - 0.5 || d.blocked) commitPath(game);
}

// Where a path may start: the clicked point, pushed out of planets and moons.
function startPoint(game, c) {
  const sh = game.ship;
  const p = c ? { x: c.x, y: c.y } : { x: sh.x, y: sh.y };
  for (const b of [game.field.planet, ...game.field.moons]) {
    const dx = p.x - b.x, dy = p.y - b.y, dist = Math.hypot(dx, dy), min = b.r + CONFIG.shipRadius + 4;
    if (dist < min) { const k = min / (dist || 1); p.x = b.x + (dx || 1) * k; p.y = b.y + dy * k; }
  }
  return p;
}

function extendPath(game, d, c) {
  const last = d.points[d.points.length - 1];
  const dx = c.x - last.x, dy = c.y - last.y;
  const len = Math.hypot(dx, dy);
  if (len < CONFIG.drawStep) return;
  const remain = d.budget - d.used;
  if (remain <= 0.5) return;
  let L = Math.min(len, remain);
  const ux = dx / len, uy = dy / len;
  const R = CONFIG.shipRadius;
  for (const b of [game.field.planet, ...game.field.moons]) {
    const t = segCircleT(last.x, last.y, last.x + ux * L, last.y + uy * L, b.x, b.y, b.r + R);
    if (t >= 0) { L = Math.max(0, t * L - 2); d.blocked = true; }
  }
  if (L < 1) return;
  d.points.push({ x: last.x + ux * L, y: last.y + uy * L });
  d.used += L;
}

function commitPath(game) {
  const d = game.draw, sh = game.ship;
  if (d.points.length < 2) {
    // nothing drawn: dash straight for the full length — from the ship toward the cursor, or from
    // the clicked start onward in the direction ship -> start
    let ux = sh.hx, uy = sh.hy;
    if (!d.points.length) d.points.push({ x: sh.x, y: sh.y });
    const o = d.points[0];
    const tgt = Math.hypot(o.x - sh.x, o.y - sh.y) > 1 ? o : d.cursor;
    if (tgt) {
      const dx = tgt.x - sh.x, dy = tgt.y - sh.y, l = Math.hypot(dx, dy);
      if (l > 1) { ux = dx / l; uy = dy / l; }
    }
    extendPath(game, d, { x: o.x + ux * d.budget, y: o.y + uy * d.budget });
    if (d.points.length < 2) { game.draw = null; return; }
  }
  if (game.newBuild) game.dashMeter = Math.max(0, game.dashMeter - d.charge * Math.min(1, d.used / d.budget));
  const pts = d.points;
  warpTo(game, pts[0].x, pts[0].y);
  const l = Math.hypot(pts[1].x - pts[0].x, pts[1].y - pts[0].y);
  const dx = (pts[1].x - pts[0].x) / l, dy = (pts[1].y - pts[0].y) / l;
  onLaunch(game);
  const v = launchVelocity(sh.vx, sh.vy, dx, dy, d.gauge, game.stats);
  const speed = Math.max(Math.hypot(v.vx, v.vy), 1);
  sh.vx = dx * speed; sh.vy = dy * speed;
  sh.boostT = game.stats.boostDuration; sh.fadeT = 0; sh.gaugeBank = 0;
  sh.aimAngle = Math.atan2(dy, dx);
  game.dashId++;
  game.lastPath = pts;
  let total = 0;
  for (let i = 1; i < pts.length; i++) total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
  // speed = the dash speed (attack, escape, momentum afterwards); rate = how fast the path is traced on screen
  const rate = Math.max(speed, total / (CONFIG.drawRunTime / game.stats.traceSpeedMult));
  game.draw = { phase: 'run', path: pts, seg: 0, segPos: 0, speed, rate, budget: d.budget, inside: new Map(), passes: new Map(), waveInside: new Map(), waveAcc: 0 };
  if (game.newBuild) onRunLaunch(game, d.fullCharge);
  game.events.push({ type: 'launch', gauge: d.gauge, x: sh.x, y: sh.y, dx, dy });
}

// Blink to the start of the path, leaving a few fading afterimages behind.
function warpTo(game, x, y) {
  const sh = game.ship;
  const dx = x - sh.x, dy = y - sh.y, dist = Math.hypot(dx, dy);
  if (dist < 1) return;
  const ux = dx / dist, uy = dy / dist, step = Math.min(26, dist / 5);
  for (let i = 0; i < 4; i++) {
    game.fx.ghosts.push({ x: sh.x + ux * step * i, y: sh.y + uy * step * i, life: 0.45 - i * 0.08, max: 0.45 });
  }
  game.fx.ghosts.push({ x0: sh.x, y0: sh.y, x1: x, y1: y, life: 0.18, max: 0.18, streak: true });
  sh.x = x; sh.y = y;
  sh.trail = [];
  addRing(game, x, y, 46, 'rgba(190,240,255,0.9)', 0.3);
  game.events.push({ type: 'warp', dist });
}

// Trace the polyline quickly (the world is nearly frozen); piercing costs dash speed, a bounce ends it.
function runAlongPath(game, realDt) {
  const r = game.draw, sh = game.ship;
  let dist = r.rate * realDt;
  while (dist > 1e-9 && r.seg < r.path.length - 1) {
    const a = r.path[r.seg], b = r.path[r.seg + 1];
    const segLen = Math.hypot(b.x - a.x, b.y - a.y);
    if (segLen < 1e-6) { r.seg++; r.segPos = 0; continue; }
    const ux = (b.x - a.x) / segLen, uy = (b.y - a.y) / segLen;
    const move = Math.min(dist, segLen - r.segPos);
    const x0 = sh.x, y0 = sh.y;
    // enemies the ship body has left can be hit again on the next pass
    const R = CONFIG.shipRadius;
    for (const [id, e] of r.inside) {
      if (e.dead || Math.hypot(x0 - e.x, y0 - e.y) > e.r + R + 2) r.inside.delete(id);
    }
    r.segPos += move; dist -= move;
    sh.x = a.x + ux * r.segPos; sh.y = a.y + uy * r.segPos;
    sh.vx = ux * r.speed; sh.vy = uy * r.speed;
    game.dashPeakAtk = Math.max(game.dashPeakAtk, attackPower(r.speed, game.stats));
    waveAlong(game, r, x0, y0, sh.x, sh.y);
    if (game.state !== 'play') return;
    if (collideEnemies(game, x0, y0, R, r)) {
      onRunTrail(game, r, x0, y0, sh.x, sh.y);
      game.draw = null; endTraceAttack(game); return;
    }
    onRunTrail(game, r, x0, y0, sh.x, sh.y);
    if (game.state !== 'play') return;
    const sp = Math.hypot(sh.vx, sh.vy);
    if (sp < r.speed) r.speed = sp;
    if (r.segPos >= segLen - 1e-9) { r.seg++; r.segPos = 0; }
  }
  if (r.seg >= r.path.length - 1) {
    game.draw = null;
    sh.glide = true; // retain launch speed while allowing ordinary cursor/stick steering
    sh.boostT = game.stats.boostDuration; // keep cruising along the last segment
    endTraceAttack(game);
  }
}

// Preview for the drawing UI: where the run would crit (hot) and the first thing that would stop it.
export function previewPath(game, points = null) {
  const d = points ? { phase: 'draw', points, gauge: game.stats.gaugeMax } : game.draw;
  if (!d || d.phase !== 'draw' || d.points.length < 2) return { samples: [], block: null, targets: [] };
  const pts = d.points, sh = game.ship, R = CONFIG.shipRadius, W = waveRadius(game);
  const l = Math.hypot(pts[1].x - pts[0].x, pts[1].y - pts[0].y) || 1;
  const v = launchVelocity(sh.vx, sh.vy, (pts[1].x - pts[0].x) / l, (pts[1].y - pts[0].y) / l, d.gauge, game.stats);
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
  if (game.state !== 'play' || sh.invulnT > 0 || game.debug.invincible) return false;
  sh.hp -= amount * game.stats.damageTakenMult;
  if (slow > 0) sh.glide = false;
  const k = 1 - Math.min(0.9, slow * game.stats.hitSlowMult);
  sh.vx *= k; sh.vy *= k;
  sh.invulnT = CONFIG.invulnTime;
  game.events.push({ type: 'hurt', amount: amount * game.stats.damageTakenMult, x: sh.x, y: sh.y, cause });
  if (sh.hp <= 0) { beginShipDeath(game); return true; }
  addText(game, sh.x, sh.y - 30, `-${Math.round(amount * game.stats.damageTakenMult)}`, '#ff6b5a');
  onShipHurt(game);
  return true;
}

// R: hit radius of the ship (wider while tracing a drawn path).
// run: the trace state; while tracing, an enemy can be hit again each time the band re-enters it.
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
    if (e.dead) continue; // A preceding contact wave may already have removed this target.
    const hx = x0 + (x1 - x0) * t, hy = y0 + (y1 - y0) * t;
    const sp = Math.hypot(sh.vx, sh.vy);
    const ux = sp > 0 ? sh.vx / sp : 0, uy = sp > 0 ? sh.vy / sp : 0;
    const atk = attackPower(sp, stats);
    const weak = isWeakHit(e, hx, hy, stats.weakArcMult);
    const crit = weak || (game.newBuild && game.rng() < stats.critChance);
    const fast = !!run || sh.glide || sp >= stats.maxSpeed * 0.65;
    if (game.newBuild && !fast) {
      e.hitCD = 0.3;
      damageShip(game, e.contact, 0.1, `contact:${e.type}`);
      if (game.state === 'play') onRunElectricContact(game, e);
      continue;
    }
    const res = resolveRam(atk, e, crit, stats);
    if (res.pierce) {
      damageEnemy(game, e, res.damage, { crit, cause: 'ram', dirX: ux, dirY: uy, impactX: hx, impactY: hy });
      if (game.state === 'finishing') return false;
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
      const keep = sh.glide || game.draw?.phase === 'run' ? 1 : pierceKeep(e, e.dead, stats);
      sh.vx *= keep; sh.vy *= keep;
      game.dashPierce++;
      onPierce(game, hx, hy);
      if (game.state === 'finishing') return false;
      onRunContact(game, e, hx, hy, ux, uy);
      if (game.state === 'finishing') return false;
      if (e.T.steal) { sh.glide = false; const k = 1 - e.T.steal * stats.hitSlowMult; sh.vx *= k; sh.vy *= k; game.events.push({ type: 'drain', x: e.x, y: e.y }); }
      if (crit) game.hitstop = Math.max(game.hitstop, e.dead ? 0.05 : 0.035);
      continue;
    }
    // bounce off
    sh.glide = false;
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
    onRunContact(game, e, hx, hy, ux, uy);
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
      sh.glide = false;
      sh.vx -= (1 + restitution) * vn * nx;
      sh.vy -= (1 + restitution) * vn * ny;
      const dmg = Math.max(0, -vn - 200) * CONFIG.crashDamage * game.stats.bounceDamageMult;
      if (dmg > 0) damageShip(game, dmg, 0, b === f.planet ? 'planet' : 'moon');
      if (game.state !== 'play') return;
      game.events.push({ type: 'crash', x: sh.x, y: sh.y, power: -vn });
    }
  }
  // hard wall well outside the soft boundary
  const r = Math.hypot(sh.x, sh.y);
  const wall = CONFIG.fieldRadius + 500;
  if (r > wall) {
    sh.glide = false;
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
  const limit = Math.ceil(phaseTarget(game.t).pop * (1 + CONFIG.enemySplitOverflow));
  let population = 0;
  for (const e of game.enemies) if (!e.dead && e.type !== 'meteor' && e.type !== 'boss') population++;
  for (const e of game.newEnemies) {
    if (population >= limit) break;
    game.enemies.push(e);
    population++;
  }
  game.newEnemies.length = 0;
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
    if (game.newBuild) game.pendingLevelups++;
    game.ship.hp = Math.min(game.stats.maxHp, game.ship.hp + game.stats.maxHp * CONFIG.levelHeal);
    game.events.push({ type: 'levelup', level: game.level });
    need = xpForLevel(game.level);
    refreshStats(game); // deferred level choices never interrupt the traced movement
    addText(game, game.ship.x, game.ship.y - 34, `Lv ${game.level}`, '#6dffb0', 18);
  }
}

// ---- fx ----

function updateFx(game, dt) {
  const P = game.fx.particles;
  for (const p of P) { p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= 1 - 2.5 * dt; p.vy *= 1 - 2.5 * dt; p.life -= dt; if (p.spin) p.angle += p.spin * dt; }
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
