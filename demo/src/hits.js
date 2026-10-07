// Damage, kills, drops and area attacks applied to enemies.
import { CONFIG } from './config.js';
import { onEnemyDeath } from './enemies.js';
import { getPhase } from './spawner.js';
import { dangerAt } from './field.js';
import { rollModule } from './modules.js';
import { attackPower } from './combat.js';
import { dropPortal } from './portals.js';
import { onRunCritical, onRunKill } from './run-weapons.js';
import { xpForLevel } from './progression.js';
import { beginBossFinish } from './finale.js';

export function damageEnemy(game, e, dmg, opts = {}) {
  if (e.dead || game.state === 'finishing' || game.state === 'dying' || dmg <= 0) return;
  let critical = !!opts.crit;
  if (game.newBuild && opts.crit === undefined && !opts.noCrit) {
    critical = game.rng() < game.stats.critChance;
    if (critical) dmg *= game.stats.critMult;
  }
  opts = { ...opts, crit: critical };
  let fresh = e.hp >= e.maxHp - 1e-6;
  // during a traced dash, the wave reaches an enemy just before the body does: judge "one-shot"
  // by its HP when this dash first touched it, so wave + body still count as one strike
  if ((game.draw && game.draw.phase === 'run') || game.portalDash) {
    if (e.dashSeen !== game.dashId) { e.dashSeen = game.dashId; e.dashFresh = fresh; }
    fresh = e.dashFresh;
  }
  e.hp -= dmg;
  e.flash = 0.12;
  game.events.push({ type: 'hit', x: e.x, y: e.y, crit: !!opts.crit, dmg, cause: opts.cause });
  if (opts.crit) addText(game, e.x, e.y - e.r - 10, 'CRIT', '#ffe46b');
  if (e.hp <= 0) {
    if (fresh && (opts.cause === 'ram' || opts.cause === 'wave')) killStop(game, e, opts.crit);
    killEnemy(game, e, opts);
  } else if (opts.dirX !== undefined) {
    const k = opts.knock ?? 160;
    const mass = Math.max(1, e.r / 20);
    e.vx += (opts.dirX * k) / mass; e.vy += (opts.dirY * k) / mass;
    if (['sonic', 'killSonic', 'critBeam', 'laser'].includes(opts.cause) && e.type !== 'boss') e.knockT = 0.3;
  }
  if (game.newBuild && critical && !opts.noCrit) onRunCritical(game, opts.impactX ?? e.x, opts.impactY ?? e.y);
}

// One-shot ram kills freeze the action for a beat, so each kill in a sweep lands on its own.
function killStop(game, e, crit) {
  if (game.dashStop >= CONFIG.killHitstopCap) return;
  const t = CONFIG.killHitstop * (e.r > 25 ? 1.8 : 1) * (crit ? 1.3 : 1);
  game.hitstop = Math.max(game.hitstop, t);
  game.dashStop = (game.dashStop || 0) + t;
}

export function killEnemy(game, e, opts = {}) {
  if (e.dead || game.state === 'finishing') return;
  if (e === game.boss) { beginBossFinish(game, e, opts); return; }
  e.dead = true;
  game.kills++;
  game.events.push({ type: 'kill', x: e.x, y: e.y, r: e.r, crit: !!opts.crit, enemyType: e.type, elite: e.elite, cause: opts.cause });
  const forceful = ['sonic', 'killSonic', 'critBeam', 'laser'].includes(opts.cause);
  if (game.newBuild && e.r >= CONFIG.hullDebrisMinRadius && e.type !== 'meteor' && opts.cause !== 'hullDebris' &&
      !(opts.cause === 'ram' && game.weapons.knockback)) {
    const shove = e.shove;
    const speed = shove ? Math.hypot(shove.vx, shove.vy) : forceful ? CONFIG.hullDebrisForceSpeed : CONFIG.hullDebrisSpeed;
    scatterHull(game, e, shove ? shove.vx / (speed || 1) : opts.dirX || 0,
      shove ? shove.vy / (speed || 1) : opts.dirY || 0, speed,
      attackPower(0, game.stats) * CONFIG.hullDebrisDamage);
  }
  burst(game, e.x, e.y, e.T.color, 6 + Math.round(e.r / 3), opts.dirX || 0, opts.dirY || 0, (260 + e.r * 4) * (forceful ? 1.8 : 1));
  onEnemyDeath(e, game);
  dropPortal(game, e.x, e.y);
  const phase = getPhase(game.t);
  const danger = dangerAt(Math.hypot(e.x, e.y));
  const xp = e.xp * game.stats.xpMult * CONFIG.xpMult * (phase.xpBonus || 1) * (1 + danger);
  dropGem(game, e.x, e.y, xp);
  dropCoins(game, e, danger);
  if (e.type === 'meteor' && game.rng() < CONFIG.meteorHealChance) {
    game.capsules.push({ kind: 'heal', src: 'drop', x: e.x, y: e.y, age: 0 });
  }
  // Roll independently for each kill; drop frequency is controlled by probability, not a timer.
  const power = e.xp;
  const chance = Math.min(CONFIG.dropMax, CONFIG.dropBase * Math.pow(power, CONFIG.dropPowerExp));
  if (game.rng() < chance) {
    dropModule(game, e.x, e.y, power, danger);
  }
  if (opts.cause === 'ram' && game.stats.fling) flingCorpse(game, e);
  onRunKill(game, opts.cause);
}

// Evenly spaced fragments expose the direction of a successful hit without consuming drop RNG.
// Fragment kills never create more fragments, keeping large chain attacks finite.
export function scatterHull(game, e, ux, uy, speed, dmg) {
  if (e.r < CONFIG.hullDebrisMinRadius || e.type === 'meteor' || e.type === 'boss' || e.hullScattered) return false;
  e.hullScattered = true;
  const count = Math.min(CONFIG.hullDebrisMaxPieces, Math.max(6, Math.ceil(e.r / 12)));
  const directed = Math.hypot(ux, uy) > 0.01;
  const base = directed ? Math.atan2(uy, ux) : e.facing || 0;
  const spread = directed ? Math.PI * 0.85 : Math.PI * 2;
  for (let i = 0; i < count; i++) {
    const a = base + (directed ? i / (count - 1) - 0.5 : i / count) * spread;
    const dx = Math.cos(a), dy = Math.sin(a), v = speed * (0.85 + (i % 3) * 0.12);
    game.fbullets.push({ kind: 'corpse', cause: 'hullDebris', noCrit: true,
      x: e.x + dx * e.r * 0.3, y: e.y + dy * e.r * 0.3,
      vx: dx * v, vy: dy * v, r: Math.min(20, Math.max(10, e.r * 0.17)), dmg,
      life: CONFIG.hullDebrisLife, pierce: true, hit: new Set([e.id]), color: e.T.color, knock: 500 });
  }
  return true;
}

function flingCorpse(game, e) {
  const sh = game.ship;
  const sp = Math.hypot(sh.vx, sh.vy);
  if (sp < 1) return;
  const base = Math.atan2(sh.vy, sh.vx);
  const dmg = attackPower(sp, game.stats) * game.stats.fling;
  for (const off of [-0.28, 0, 0.28]) {
    const a = base + off;
    game.fbullets.push({
      kind: 'corpse', x: e.x, y: e.y, vx: Math.cos(a) * sp * 0.9, vy: Math.sin(a) * sp * 0.9,
      r: Math.max(10, e.r * 0.8), dmg, life: 0.7, pierce: true, hit: new Set(), color: e.T.color,
    });
  }
}

function dropCoins(game, e, danger) {
  let n = 0;
  if (e.type === 'battleship') n = 12;
  else if (e.elite) n = 3 + Math.floor(game.rng() * 4);
  else if (e.type === 'meteor') n = game.rng() < CONFIG.meteorCoinChance ? 1 + Math.floor(game.rng() * 3) : 0;
  else if (game.rng() < 0.03 * (1 + danger * 2)) n = 1;
  for (let i = 0; i < n; i++) {
    const a = game.rng() * Math.PI * 2, d = game.rng() * e.r;
    game.coinDrops.push({ x: e.x + Math.cos(a) * d, y: e.y + Math.sin(a) * d, v: 1, pulled: false, taken: false });
  }
}

export function dropGem(game, x, y, v) {
  if (game.gems.length > 600) {
    const old = game.gems.shift();
    v += old.v;
  }
  const a = game.rng() * Math.PI * 2;
  game.gems.push({ x: x + Math.cos(a) * 8, y: y + Math.sin(a) * 8, v, age: 0, pulled: false, taken: false });
}

function dropModule(game, x, y, power, danger) {
  if (game.newBuild) {
    game.capsules.push({ kind: 'cache', src: 'drop', x, y, xp: xpForLevel(game.level) * 0.15, age: 0 });
    return;
  }
  const mod = rollModule(game.rng, { t: game.t, loadout: game.loadout, source: 'drop', power, danger, scheme: game.scheme });
  game.capsules.push({ kind: 'capsule', src: 'drop', x, y, mod, age: 0 });
}

export function dropCapsule(game, x, y, src, danger) {
  if (game.newBuild) {
    game.capsules.push({ kind: 'cache', src, x, y, xp: xpForLevel(game.level) * 0.2, age: 0 });
    return;
  }
  const mod = rollModule(game.rng, { t: game.t, loadout: game.loadout, source: 'capsule', danger, scheme: game.scheme });
  game.capsules.push({ kind: 'capsule', src, x, y, mod, age: 0 });
}

// Area damage that ignores armor (module effects, sonic booms).
export function explode(game, x, y, radius, dmg, opts = {}) {
  const knock = opts.knock ?? 300;
  for (const e of game.enemies) {
    if (e.dead) continue;
    const dx = e.x - x, dy = e.y - y;
    const rr = radius + e.r;
    const d2 = dx * dx + dy * dy;
    if (d2 > rr * rr) continue;
    const d = Math.sqrt(d2) || 1;
    damageEnemy(game, e, dmg, { cause: opts.cause, dirX: dx / d, dirY: dy / d, knock });
  }
  addRing(game, x, y, radius, opts.color || '#ffb36b', opts.life || 0.4);
  game.events.push({ type: 'explode', x, y, radius, cause: opts.cause });
}

export function burst(game, x, y, color, n, dx, dy, speed) {
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

export function addText(game, x, y, text, color, size = 16) {
  if (game.fx.texts.length > 40) game.fx.texts.shift();
  game.fx.texts.push({ x, y, text, color, life: size > 16 ? 0.9 : 0.7, size });
}

export function addRing(game, x, y, radius, color, life = 0.45) {
  if (game.fx.rings.length > 80) game.fx.rings.shift();
  game.fx.rings.push({ x, y, radius, color, life, max: life });
}
