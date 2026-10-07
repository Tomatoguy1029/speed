import { isDrawScheme } from './controls.js';
// Module effects that change how the ship attacks, plus field capsules and power cores.
import { CONFIG } from './config.js';
import { attackPower } from './combat.js';
import { explode, damageEnemy, addRing, addText } from './hits.js';
import { queryGrid } from './grid.js';
import { rollModule } from './modules.js';
import { dangerAt } from './field.js';
import { getPhase } from './spawner.js';
import { onRunEnd, onRunHurt } from './run-weapons.js';
import { xpForLevel } from './progression.js';
import { refreshStats, addXp } from './world.js';
import { randRange, TAU, segCircleT } from './math.js';

export function createEffectState() {
  return {
    fbullets: [], marks: [], mines: [], capsules: [],
    fx2: { waveT: 0, trailDist: 0, lastX: 0, lastY: 0, mineT: 0, turretT: 0, sonicCD: 0, prevSpeed: 0, capsuleT: 0, coreT: 0, coresStarted: false },
    dashActive: false, dashPeakAtk: 0, traceEndHandled: false,
  };
}

export function onLaunch(game) {
  if (game.dashActive) finishDash(game);
  game.traceEndHandled = false;
  game.dashActive = true;
  game.dashPeakAtk = 0;
  game.dashPierce = 0;
  game.dashStop = 0;
}

function finishDash(game) {
  game.dashActive = false;
  const eb = game.stats.endBlast;
  if (eb && game.dashPierce >= eb.min) {
    const sh = game.ship;
    explode(game, sh.x, sh.y, eb.radius, game.dashPeakAtk * eb.mult, { cause: 'endBlast', color: '#ff9f40', knock: 500, life: 0.5 });
  }
}

export function endTraceAttack(game) {
  game.traceEndHandled = true;
  finishDash(game);
  if (game.newBuild) { onRunEnd(game); return; }
  const pulse = game.stats.traceEndBlast, sh = game.ship;
  if (pulse && game.state === 'play') explode(game, sh.x, sh.y, pulse.radius,
    attackPower(Math.hypot(sh.vx, sh.vy), game.stats) * pulse.mult,
    { cause: 'traceEnd', color: '#c46bff', knock: 500, life: 0.5 });
}

export function onPierce(game, x = game.ship.x, y = game.ship.y) {
  const s = game.stats, sh = game.ship;
  if (s.regenGauge) sh.gaugeBank = Math.min(s.gaugeMax, sh.gaugeBank + s.regenGauge);
  if (s.regenGauge && isDrawScheme(game.scheme)) game.dashMeter = Math.min(1, game.dashMeter + s.regenGauge * 0.15);
  if (s.pierceWave) explode(game, x, y, s.pierceWave.radius,
    attackPower(Math.hypot(sh.vx, sh.vy), s) * s.pierceWave.mult,
    { cause: 'pierceWave', color: '#9fe8ff', knock: 350, life: 0.3 });
}

export function onShipHurt(game) {
  if (game.newBuild) { onRunHurt(game); return; }
  const s = game.stats, sh = game.ship;
  if (s.reactive) explode(game, sh.x, sh.y, 260, attackPower(s.maxSpeed, s) * s.reactive, { cause: 'reactive', color: '#ff6b5a', knock: 450 });
}

export function updateEffects(game, dt) {
  const sh = game.ship, s = game.stats, F = game.fx2;
  const sp = Math.hypot(sh.vx, sh.vy);
  const atkNow = attackPower(sp, s);
  const atkMax = attackPower(s.maxSpeed, s);

  // dash bookkeeping (end-of-dash blast)
  if (sh.boostT > 0 && !game.dashActive && !game.traceEndHandled) { game.dashActive = true; game.dashPeakAtk = 0; }
  if (game.dashActive) {
    game.dashPeakAtk = Math.max(game.dashPeakAtk, atkNow);
    if (sh.boostT <= 0 && !game.portalDash && !game.draw) finishDash(game);
  }

  // charge shockwave
  if (s.chargeWave && sh.charging) {
    F.waveT += dt;
    if (F.waveT >= 0.5) {
      F.waveT = 0;
      explode(game, sh.x, sh.y, s.chargeWave.radius, atkMax * s.chargeWave.mult, { cause: 'chargeWave', color: '#5fd8ff', knock: 350 });
    }
  } else {
    F.waveT = 0.25;
  }

  // trail burst marks
  if (s.trailBurst && sh.boostT > 0 && sp > 200 && !game.portalDash) {
    F.trailDist += sp * dt;
    if (F.trailDist >= 45) {
      F.trailDist = 0;
      game.marks.push({ x: sh.x, y: sh.y, t: 0.55, dmg: atkNow * s.trailBurst });
    }
  }
  for (const m of game.marks) {
    m.t -= dt;
    if (m.t <= 0) explode(game, m.x, m.y, m.radius || 85, m.dmg, { cause: 'trail', color: '#ffcf6b', knock: 120, life: 0.25 });
  }
  if (game.marks.length) game.marks = game.marks.filter((m) => m.t > 0);

  // mines
  if (s.mines && sp > 0.6 * s.maxSpeed) {
    F.mineT += dt;
    if (F.mineT >= 0.2) {
      F.mineT = 0;
      game.mines.push({ x: sh.x, y: sh.y, life: 5, armed: 0.3, dmg: atkMax * s.mines });
    }
  }
  for (const m of game.mines) {
    m.life -= dt; m.armed -= dt;
    if (m.armed > 0) continue;
    for (const e of game.enemies) {
      if (e.dead) continue;
      const rr = 70 + e.r;
      if ((e.x - m.x) ** 2 + (e.y - m.y) ** 2 < rr * rr) {
        explode(game, m.x, m.y, m.radius || 120, m.dmg, { cause: 'mine', color: '#ff7b54', knock: 300, life: 0.3 });
        m.life = 0;
        break;
      }
    }
  }
  if (game.mines.length) game.mines = game.mines.filter((m) => m.life > 0);

  // auto turret
  if (s.turret) {
    F.turretT += dt;
    if (F.turretT >= 1 / (1.6 * s.turret)) {
      let best = null, bd = 650 * 650;
      for (const e of game.enemies) {
        if (e.dead) continue;
        const d = (e.x - sh.x) ** 2 + (e.y - sh.y) ** 2;
        if (d < bd) { bd = d; best = e; }
      }
      if (best) {
        F.turretT = 0;
        const a = Math.atan2(best.y - sh.y, best.x - sh.x);
        game.fbullets.push({ kind: 'shot', x: sh.x, y: sh.y, vx: Math.cos(a) * 1300 + sh.vx * 0.5, vy: Math.sin(a) * 1300 + sh.vy * 0.5, r: 6, dmg: atkMax * 0.22, life: 0.8, pierce: false, hit: new Set(), color: '#9fe8ff' });
        game.events.push({ type: 'turret' });
      }
    }
  }
  updateFriendly(game, dt);

  // sonic boom on crossing 92% of max speed
  F.sonicCD -= dt;
  const thr = 0.92 * s.maxSpeed;
  if (s.sonic && F.sonicCD <= 0 && F.prevSpeed < thr && sp >= thr) {
    F.sonicCD = 2.5;
    explode(game, sh.x, sh.y, s.sonic.radius, atkMax * s.sonic.mult, { cause: 'sonic', color: '#ffffff', knock: 900, life: 0.7 });
    game.events.push({ type: 'sonic', x: sh.x, y: sh.y, radius: s.sonic.radius });
    game.slowmo = 0.45;
  }
  if (sp >= thr && F.prevSpeed < thr) game.events.push({ type: 'barrier', x: sh.x, y: sh.y });
  F.prevSpeed = sp;

  updateCapsules(game, dt);
}

function updateFriendly(game, dt) {
  const B = game.fbullets;
  for (const b of B) {
    const x0 = b.x, y0 = b.y;
    b.x += b.vx * dt; b.y += b.vy * dt; b.life -= dt;
    const pad = b.r + 130, hits = [];
    queryGrid(game.grid, Math.min(x0, b.x) - pad, Math.min(y0, b.y) - pad, Math.max(x0, b.x) + pad, Math.max(y0, b.y) + pad, e => {
      if (e.dead || b.hit.has(e.id)) return;
      const t = segCircleT(x0, y0, b.x, b.y, e.x, e.y, b.r + e.r);
      if (t >= 0) hits.push({ e, t });
    });
    hits.sort((a, b) => a.t - b.t);
    for (const { e } of hits) {
      if (b.life <= 0 || e.dead) continue;
      b.hit.add(e.id);
      const sp = Math.hypot(b.vx, b.vy) || 1;
      damageEnemy(game, e, b.dmg, { cause: b.kind, dirX: b.vx / sp, dirY: b.vy / sp, knock: 250 });
      if (!b.pierce) { if ((b.pierceLeft || 0) > 0) b.pierceLeft--; else b.life = 0; }
    }
  }
  game.fbullets = B.filter(b => b.life > 0);
}

function fieldCapsulePoint(game) {
  const rng = game.rng;
  if (isDrawScheme(game.scheme)) {
    // Put build opportunities within reach of the current fight, rather than across the whole map.
    const distance = Math.max(200, game.viewRadius * (0.25 + rng() * 0.3));
    for (let i = 0; i < 16; i++) {
      const a = rng() * TAU;
      const x = game.ship.x + Math.cos(a) * distance, y = game.ship.y + Math.sin(a) * distance;
      const r = Math.hypot(x, y);
      if (r > CONFIG.planetRadius + 100 && r < CONFIG.fieldRadius - 100) return { x, y, r };
    }
  }
  const roll = rng();
  let r;
  if (roll < 0.4) r = randRange(rng, CONFIG.planetRadius + 200, CONFIG.zoneInner);
  else if (roll < 0.75) r = randRange(rng, CONFIG.zoneOuter, CONFIG.fieldRadius - 150);
  else r = randRange(rng, CONFIG.zoneInner, CONFIG.zoneOuter);
  const a = rng() * TAU;
  return { x: Math.cos(a) * r, y: Math.sin(a) * r, r };
}

function updateCapsules(game, dt) {
  const F = game.fx2, sh = game.ship;
  if (isDrawScheme(game.scheme)) game.capsules = game.capsules.filter(c => c.src !== 'field' || Math.hypot(c.x - sh.x, c.y - sh.y) < game.viewRadius * 2);
  if (game.spawning) {
    F.capsuleT += dt;
    const field = game.capsules.filter((c) => c.src === 'field').length;
    const fieldCount = isDrawScheme(game.scheme) ? CONFIG.drawCapsuleCount : CONFIG.capsuleCount;
    const fieldInterval = isDrawScheme(game.scheme) ? CONFIG.drawCapsuleInterval : CONFIG.capsuleInterval;
    if (field < fieldCount && (game.t < 2 || F.capsuleT >= fieldInterval)) {
      F.capsuleT = 0;
      const p = fieldCapsulePoint(game);
      if (game.newBuild) game.capsules.push({ kind: 'cache', src: 'field', x: p.x, y: p.y, xp: xpForLevel(game.level) * 0.2, age: 0 });
      else {
        const mod = rollModule(game.rng, { t: game.t, loadout: game.loadout, source: 'capsule', danger: dangerAt(p.r), scheme: game.scheme });
        game.capsules.push({ kind: 'capsule', src: 'field', x: p.x, y: p.y, mod, age: 0 });
      }
    }
    if (getPhase(game.t).cores) {
      F.coreT += dt;
      const cores = game.capsules.filter((c) => c.kind === 'core').length;
      if (cores < 3 && (!F.coresStarted || F.coreT >= 20)) {
        F.coreT = 0;
        const a = game.rng() * TAU;
        const r = randRange(game.rng, CONFIG.planetRadius + 250, CONFIG.zoneInner - 300);
        game.capsules.push({ kind: 'core', src: 'core', x: Math.cos(a) * r, y: Math.sin(a) * r, mod: rollModule(game.rng, { source: 'core', t: game.t, loadout: game.loadout }), age: 0 });
        if (!F.coresStarted || cores >= 2) F.coresStarted = true;
        game.events.push({ type: 'core' });
      }
    }
  }
  let taken = false;
  const pull = game.stats.pickupRadius * 1.6;
  for (const c of game.capsules) {
    c.age += dt;
    if (c.src === 'drop' || c.src === 'elite') {
      const dx = sh.x - c.x, dy = sh.y - c.y, d = Math.hypot(dx, dy);
      if (d < pull && d > 1) { const v = (600 + Math.hypot(sh.vx, sh.vy)) * dt; c.x += (dx / d) * Math.min(v, d); c.y += (dy / d) * Math.min(v, d); }
    }
    const reach = 22 + CONFIG.shipRadius + 14;
    if ((c.x - sh.x) ** 2 + (c.y - sh.y) ** 2 < reach * reach) {
      c.taken = true; taken = true;
      if (c.kind === 'core') {
        game.cores++;
        refreshStats(game);
        addText(game, sh.x, sh.y - 50, `出力 +${Math.round(CONFIG.coreBoost * 100)}%`, '#ffd24a');
      } else if (c.kind === 'cache') {
        addXp(game, c.xp);
        addText(game, c.x, c.y, 'XP', CONFIG.xpColor);
      } else {
        game.offerQueue.push({ ...c.mod, source: c.src && c.src !== 'field' ? c.src : 'capsule' });
      }
      addRing(game, c.x, c.y, 120, c.kind === 'core' ? '#ffd24a' : '#9fe8ff', 0.5);
      game.events.push({ type: 'pickup', kind: c.kind, r: c.mod?.r || 0 });
    }
    if ((c.src === 'elite' || c.src === 'drop') && c.age > 45) { c.taken = true; taken = true; }
  }
  if (taken) game.capsules = game.capsules.filter((c) => !c.taken);
}
