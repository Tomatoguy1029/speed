// Weapon actions and route traits for the draw prototype. All damage uses attack stats.
import { CONFIG } from './config.js';
import { attackPower } from './combat.js';
import { segCircleT } from './math.js';
import { queryGrid } from './grid.js';
import { MAX_ENEMY_R } from './enemies.js';
import { damageEnemy, explode, addRing, addText } from './hits.js';
import { runWeaponStats, runTrait } from './run-build.js';
import { updateWeapons } from './experimental-weapons.js';
import { tracePortalLoop } from './portal-loops.js';

function runNearest(game, x, y, range) {
  let found = null, best = range * range;
  queryGrid(game.grid, x - range - MAX_ENEMY_R, y - range - MAX_ENEMY_R, x + range + MAX_ENEMY_R, y + range + MAX_ENEMY_R, e => {
    if (e.dead) return;
    const d = (e.x - x) ** 2 + (e.y - y) ** 2;
    if (d < best) { best = d; found = e; }
  });
  return found;
}

function runShot(game, x, y, angle, damage, options = {}) {
  const speed = options.speed || 1300;
  game.fbullets.push({ kind: 'runShot', x, y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
    r: options.r || 5, dmg: damage, life: options.life || 0.9, pierce: false,
    pierceLeft: options.pierce || 0, hit: new Set(), color: options.color || '#ffe46b' });
}

export function runBeam(game, x, y, ux, uy, length, width, dmg, cause = 'critBeam') {
  const x1 = x + ux * length, y1 = y + uy * length, pad = width / 2 + MAX_ENEMY_R;
  queryGrid(game.grid, Math.min(x, x1) - pad, Math.min(y, y1) - pad, Math.max(x, x1) + pad, Math.max(y, y1) + pad, e => {
    if (e.dead || segCircleT(x, y, x1, y1, e.x, e.y, e.r + width / 2) < 0) return;
    damageEnemy(game, e, dmg, { cause, noCrit: cause === 'critBeam', dirX: ux, dirY: uy, knock: CONFIG.lanceKnock });
  });
  game.wfx.push({ kind: 'beam', x0: x, y0: y, x1, y1, width, life: 0.4, max: 0.4 });
}

export function onRunCritical(game, x, y) {
  const n = runTrait(game, 'critBeam');
  if (!n || game.buildClock < game.criticalBeamAt || game.state !== 'play') return;
  game.criticalBeamAt = game.buildClock + 0.15;
  const sh = game.ship, sp = Math.hypot(sh.vx, sh.vy);
  const ux = sp > 1 ? sh.vx / sp : sh.hx, uy = sp > 1 ? sh.vy / sp : sh.hy;
  runBeam(game, x, y, ux, uy, CONFIG.lanceLength + n * CONFIG.lanceLengthPerStack,
    CONFIG.lanceWidth + n * CONFIG.lanceWidthPerStack, attackPower(0, game.stats) * (CONFIG.lanceDamage + n * CONFIG.lanceDamagePerStack));
}

export function onRunLaunch(game, full) {
  game.dashKills = 0;
  game.nextKillBoom = Math.max(3, 9 - runTrait(game, 'killSonic'));
  game.runPendingPath = [];
  game.crossUsed = new Set();
  game.runLegSerial = game.runLegSerial || 0;
  const n = runTrait(game, 'fullCharge');
  game.stats.ignoreArmor = !!(full && n);
  game.stats.burstPower = full && n ? 1.25 + n * 0.25 : 1;
  if (game.weapons.sonic) runSonic(game, 'sonic');
}

export function onRunKill(game, cause) {
  if (!game.newBuild || !game.dashActive) return;
  game.dashKills++;
  const n = runTrait(game, 'killSonic');
  if (!n || cause === 'killSonic' || game.dashKills < game.nextKillBoom || game.state !== 'play') return;
  // Advance before dealing damage so kills from this blast cannot recursively retrigger it.
  game.nextKillBoom = game.dashKills + Math.max(3, 9 - n);
  runSonic(game, 'killSonic');
}

function runSonic(game, cause) {
  const sh = game.ship, n = runTrait(game, 'killSonic');
  const L = runWeaponStats('sonic', game.weapons.sonic || 1);
  const radius = cause === 'killSonic' ? CONFIG.killSonicRadius + n * CONFIG.killSonicRadiusPerStack : CONFIG.sonicRadius * L.radius;
  const mult = cause === 'killSonic' ? CONFIG.killSonicDamage + n * CONFIG.killSonicDamagePerStack : CONFIG.sonicDamage * L.damage;
  const wave = { x: sh.x, y: sh.y, radius, dmg: attackPower(0, game.stats) * mult, cause,
    life: CONFIG.sonicTravelTime, max: CONFIG.sonicTravelTime, hits: new Set() };
  game.sonicWaves.push(wave);
  if (game.sonicWaves.length > 4) game.sonicWaves.shift();
  sweepRunSonic(game, wave, sh.x, sh.y, sh.x, sh.y);
  addRing(game, sh.x, sh.y, radius, '#c8f7ff', 0.5);
  game.events.push({ type: 'sonic', x: sh.x, y: sh.y, radius });
}

// The same damaging wave accompanies the ship; each enemy is struck once per wave.
function sweepRunSonic(game, wave, x0, y0, x1, y1) {
  const steps = Math.max(1, Math.ceil(Math.hypot(x1 - x0, y1 - y0) / (wave.radius * 0.3)));
  for (let i = 1; i <= steps && game.state === 'play'; i++) {
    const x = x0 + (x1 - x0) * i / steps, y = y0 + (y1 - y0) * i / steps, pad = wave.radius + MAX_ENEMY_R;
    queryGrid(game.grid, x - pad, y - pad, x + pad, y + pad, e => {
      if (e.dead || wave.hits.has(e.id) || game.state !== 'play') return;
      const dx = e.x - x, dy = e.y - y, dist = Math.hypot(dx, dy);
      if (dist > wave.radius + e.r) return;
      wave.hits.add(e.id);
      damageEnemy(game, e, wave.dmg, { cause: wave.cause, dirX: dx / (dist || 1), dirY: dy / (dist || 1), knock: CONFIG.sonicKnock });
    });
  }
  wave.x = x1; wave.y = y1;
}

export function updateRunSonic(game, dt) {
  const sh = game.ship;
  for (const wave of [...game.sonicWaves]) {
    if (game.state !== 'play') break;
    // Traced movement sweeps every actual segment in onRunTrail, including corners.
    sweepRunSonic(game, wave, wave.x, wave.y, sh.x, sh.y);
    wave.life -= dt;
  }
  game.sonicWaves = game.sonicWaves.filter(w => w.life > 0);
}

export function onRunContact(game, e, x, y, ux, uy) {
  if (!game.newBuild) return;
  const atk = attackPower(0, game.stats);
  if (game.weapons.knockback) {
    const L = runWeaponStats('knockback', game.weapons.knockback);
    const velocity = 800 + 90 * game.weapons.knockback;
    if (e.dead) {
      game.fbullets.push({ kind: 'corpse', x: e.x, y: e.y, vx: ux * velocity, vy: uy * velocity,
        r: Math.max(10, e.r * 0.6), dmg: atk * 0.7 * L.damage, life: 0.9, pierce: true, hit: new Set([e.id]), color: e.T.color });
    } else {
      e.shove = { time: 1.2, vx: ux * velocity, vy: uy * velocity, dmg: atk * 0.7 * L.damage, hits: new Set([e.id]) };
      e.vx = ux * velocity; e.vy = uy * velocity;
    }
  }
  if (game.weapons.contactWave && game.state === 'play') {
    const L = runWeaponStats('contactWave', game.weapons.contactWave);
    explode(game, x, y, 90 * L.radius, atk * 0.45 * L.damage, { cause: 'contactWave', color: '#9fe8ff', knock: 280, life: 0.3 });
  }
  const recovery = runTrait(game, 'recovery');
  if (recovery) game.dashMeter = Math.min(1, game.dashMeter + recovery * 0.02);
}

function runSegmentCross(a, b, c, d) {
  const rx = b.x - a.x, ry = b.y - a.y, sx = d.x - c.x, sy = d.y - c.y;
  const den = rx * sy - ry * sx;
  if (Math.abs(den) < 1e-7) return null;
  const dx = c.x - a.x, dy = c.y - a.y;
  const t = (dx * sy - dy * sx) / den, u = (dx * ry - dy * rx) / den;
  if (t <= 1e-6 || t > 1 || u < 0 || u > 1) return null;
  return { x: a.x + t * rx, y: a.y + t * ry };
}

export function onRunTrail(game, run, x0, y0, x1, y1) {
  if (!game.newBuild || game.state !== 'play') return;
  for (const wave of [...game.sonicWaves]) sweepRunSonic(game, wave, x0, y0, x1, y1);
  if (game.state !== 'play') return;
  const a = { x: x0, y: y0 }, b = { x: x1, y: y1 };
  const len = Math.hypot(x1 - x0, y1 - y0);
  if (len < 1e-6) return;
  const n = runTrait(game, 'crossBlast');
  if (n) for (const old of game.runPaths) {
    if (old.until <= game.buildClock) continue;
    const p = runSegmentCross(a, b, old.a, old.b);
    if (!p) continue;
    const key = `${Math.round(p.x / 20)},${Math.round(p.y / 20)}`;
    if (game.crossUsed.has(key)) continue;
    game.crossUsed.add(key);
    explode(game, p.x, p.y, 100 + n * 25, attackPower(0, game.stats) * (0.8 + n * 0.4), { cause: 'crossBlast', color: '#ff6bd5', knock: 400 });
  }
  game.runPendingPath.push({ a, b, until: game.buildClock + CONFIG.pathMemoryTime });
  game.runTravel.push({ a, b, serial: ++game.runLegSerial, time: game.buildClock });
  if (game.runTravel.length > 600) game.runTravel.splice(0, game.runTravel.length - 600);
  if (game.stats.loopBurst) {
    run.loopPath = run.loopPath || [a];
    tracePortalLoop(game, run, x0, y0, x1, y1);
    run.loopPath.push(b);
  }
  // Distance-based placement follows every traveled segment, including corners within one frame.
  for (const [id, spacing] of [['mines', 75], ['trailBurst', 45]]) {
    const lv = game.weapons[id];
    if (!lv) continue;
    const st = game.weaponState[id] || (game.weaponState[id] = { distance: 0 });
    const L = runWeaponStats(id, lv), step = spacing / L.rate;
    for (let d = step - st.distance; d <= len; d += step) {
      const x = x0 + (x1 - x0) * d / len, y = y0 + (y1 - y0) * d / len;
      const dmg = attackPower(0, game.stats) * L.damage;
      if (id === 'mines') {
        if (game.mines.length < 250) game.mines.push({ x, y, life: 6, armed: 0.25, dmg, radius: 110 * L.radius });
      } else if (game.marks.length < 250) game.marks.push({ x, y, t: 0.55, dmg: dmg * 0.5, radius: 85 * L.radius });
    }
    st.distance = (st.distance + len) % step;
  }
}

export function onRunEnd(game) {
  if (!game.newBuild || game.state !== 'play') return;
  game.runPaths = [...game.runPaths.filter(p => p.until > game.buildClock), ...(game.runPendingPath || [])].slice(-CONFIG.pathMemoryMax);
  game.runPendingPath = [];
  const sh = game.ship, n = runTrait(game, 'endBlast');
  if (n) explode(game, sh.x, sh.y, 180 + n * 30, attackPower(0, game.stats) * (1 + n * 0.5), { cause: 'endBlast', color: '#c46bff', knock: 500 });
  const v = runTrait(game, 'vortex');
  if (v && game.state === 'play') {
    const life = 1.5 + v * 0.4;
    game.vortexes.push({ x: sh.x, y: sh.y, radius: 180 + v * 35, life, max: life, power: 200 + v * 70 });
    if (game.vortexes.length > 12) game.vortexes.shift();
  }
  game.stats.burstPower = 1;
  game.stats.ignoreArmor = false;
}

export function onRunHurt(game) {
  const n = runTrait(game, 'reactive');
  if (n) explode(game, game.ship.x, game.ship.y, 170 + n * 30, attackPower(0, game.stats) * (0.8 + n * 0.4), { cause: 'reactive', color: '#ff6b5a', knock: 450 });
}

export function updateRunFollowers(game) {
  if (!game.newBuild) return;
  game.runPaths = game.runPaths.filter(p => p.until > game.buildClock);
  const lv = game.weapons.drone || 0;
  if (!lv) { game.drones = []; return; }
  const L = runWeaponStats('drone', lv), sh = game.ship;
  while (game.drones.length < L.drones) game.drones.push({ x: sh.x, y: sh.y, serial: game.runLegSerial || 0, hits: new Map(), trail: [] });
  for (let i = 0; i < game.drones.length; i++) {
    const d = game.drones[i], delay = CONFIG.droneDelay * (i + 1);
    for (const leg of game.runTravel) {
      if (leg.serial <= d.serial || leg.time + delay > game.buildClock) continue;
      d.serial = leg.serial; d.x = leg.b.x; d.y = leg.b.y; d.followUntil = leg.time + delay + 0.25;
      const pad = 14 + MAX_ENEMY_R;
      queryGrid(game.grid, Math.min(leg.a.x, leg.b.x) - pad, Math.min(leg.a.y, leg.b.y) - pad, Math.max(leg.a.x, leg.b.x) + pad, Math.max(leg.a.y, leg.b.y) + pad, e => {
        if (e.dead || (d.hits.get(e.id) || 0) > game.buildClock || segCircleT(leg.a.x, leg.a.y, leg.b.x, leg.b.y, e.x, e.y, e.r + 14) < 0) return;
        d.hits.set(e.id, game.buildClock + 0.3);
        damageEnemy(game, e, attackPower(0, game.stats) * L.damage * 0.5, { cause: 'drone' });
      });
      d.trail.push({ x: d.x, y: d.y, time: game.buildClock });
    }
    if (!d.followUntil || d.followUntil < game.buildClock) {
      const a = game.buildClock * 1.5 + i * Math.PI * 2 / L.drones;
      const x = sh.x + Math.cos(a) * 90, y = sh.y + Math.sin(a) * 90;
      d.x += (x - d.x) * 0.25; d.y += (y - d.y) * 0.25;
    }
    d.trail = d.trail.filter(p => p.time > game.buildClock - 0.35).slice(-18);
    if (d.hits.size > 400) for (const [id, until] of d.hits) if (until < game.buildClock) d.hits.delete(id);
  }
}

export function updateRunWeapons(game, dt) {
  if (!game.newBuild) return;
  const sh = game.ship, atk = attackPower(0, game.stats);
  const busy = !!game.draw;
  for (const [id, interval] of [['forward', 0.45], ['scatter', 1.05], ['turret', 0.5], ['barrier', 0.7], ['sonic', 5]]) {
    const lv = game.weapons[id];
    if (!lv || busy) continue;
    const L = runWeaponStats(id, lv), st = game.weaponState[id] || (game.weaponState[id] = { t: 0 });
    st.t += dt;
    if (st.t < interval / L.rate) continue;
    st.t = 0;
    if (id === 'sonic') { runSonic(game, 'sonic'); continue; }
    if (id === 'barrier') {
      explode(game, sh.x, sh.y, 70 * L.radius, atk * 0.4 * L.damage, { cause: 'barrier', color: '#76aaff', knock: 180, life: 0.2 });
      continue;
    }
    const target = id === 'turret' ? runNearest(game, sh.x, sh.y, 700) : null;
    const a = target ? Math.atan2(target.y - sh.y, target.x - sh.x) : Math.atan2(sh.hy, sh.hx);
    for (let i = 0; i < L.shots; i++) runShot(game, sh.x, sh.y, a + (i - (L.shots - 1) / 2) * (id === 'scatter' ? 0.16 : 0.08),
      atk * L.damage * (id === 'scatter' ? 0.55 : 0.8), { pierce: L.pierce, life: id === 'scatter' ? 0.45 : 0.9, color: id === 'scatter' ? '#ffb36b' : '#ffe46b' });
    game.events.push({ type: 'turret' });
  }
  if (game.weapons.barrier) {
    const L = runWeaponStats('barrier', game.weapons.barrier), st = game.weaponState.barrier || (game.weaponState.barrier = { t: 0 });
    st.blockT = Math.max(0, (st.blockT || 0) - dt);
    if (!st.blockT) for (const b of game.ebullets) {
      if (b.life <= 0 || Math.hypot(b.x - sh.x, b.y - sh.y) > 70 * L.radius + b.r) continue;
      b.life = 0; st.blockT = 0.8 / L.rate;
      addRing(game, b.x, b.y, 32, '#76aaff', 0.25); break;
    }
  }
  if (game.weapons.drone && !busy) {
    const L = runWeaponStats('drone', game.weapons.drone), st = game.weaponState.drone || (game.weaponState.drone = { t: 0 });
    st.t += dt;
    if (st.t >= 0.65 / L.rate) {
      st.t = 0;
      for (const d of game.drones) {
        const e = runNearest(game, d.x, d.y, 550);
        if (e) runShot(game, d.x, d.y, Math.atan2(e.y - d.y, e.x - d.x), atk * 0.45 * L.damage, { color: '#a8ffdb', r: 4 });
      }
    }
  }
  for (const v of game.vortexes) {
    v.life -= dt;
    queryGrid(game.grid, v.x - v.radius - MAX_ENEMY_R, v.y - v.radius - MAX_ENEMY_R, v.x + v.radius + MAX_ENEMY_R, v.y + v.radius + MAX_ENEMY_R, e => {
      if (e.dead || e.type === 'boss') return;
      const dx = v.x - e.x, dy = v.y - e.y, d = Math.hypot(dx, dy);
      if (d > v.radius || d < 10) return;
      const move = Math.min(d - 10, v.power * dt / Math.max(1, e.r / 30));
      e.x += dx / d * move; e.y += dy / d * move;
    });
  }
  game.vortexes = game.vortexes.filter(v => v.life > 0);
  updateShovedEnemies(game);
  updateWeapons(game, dt); // Experimental weapons never enter the normal offer pool.
}

function updateShovedEnemies(game) {
  for (const e of game.enemies) {
    if (e.dead || !e.shove || e.shove.time <= 0 || !e.shoveFrom) continue;
    const p = e.shoveFrom, shove = e.shove, pad = e.r + MAX_ENEMY_R;
    queryGrid(game.grid, Math.min(p.x, e.x) - pad, Math.min(p.y, e.y) - pad, Math.max(p.x, e.x) + pad, Math.max(p.y, e.y) + pad, other => {
      if (other.dead || shove.hits.has(other.id) || segCircleT(p.x, p.y, e.x, e.y, other.x, other.y, other.r + e.r) < 0) return;
      shove.hits.add(other.id);
      const sp = Math.hypot(shove.vx, shove.vy) || 1;
      damageEnemy(game, other, shove.dmg, { cause: 'knockbackChain', dirX: shove.vx / sp, dirY: shove.vy / sp, knock: 400 });
      addRing(game, other.x, other.y, other.r + 30, '#ff986b', 0.25);
    });
    e.shoveFrom = null;
  }
}
