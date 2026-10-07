import { CONFIG } from './config.js';

const BACK = Math.PI;
const SIDE = Math.PI / 2;

// hp/armor/contact are level-1 values; armor is in attack units (speed/100 at x1 multiplier).
export const ENEMY_TYPES = {
  drifter: { name: 'ドリフター', r: 14, hp: 6, armor: 2, speed: 130, accel: 2.5, contact: 6, xp: 1, color: '#7fd1ff', shape: 'orb', behavior: 'chase', weakDir: BACK, weakArc: 1.0 },
  swarm: { name: 'スウォーム', r: 11, hp: 3, armor: 1.2, speed: 200, accel: 3, contact: 4, xp: 0.6, color: '#9df0ff', shape: 'dart', behavior: 'chase', weakDir: BACK, weakArc: 1.1 },
  darter: { name: 'ダーター', r: 16, hp: 9, armor: 3.5, speed: 110, accel: 2, contact: 10, xp: 2, color: '#ff9f6b', shape: 'dart', behavior: 'dash', weakDir: BACK, weakArc: 0.9, range: 520, windup: 0.7, dashSpeed: 760, dashTime: 0.55, recover: 0.9 },
  armored: { name: '装甲型', r: 30, hp: 40, armor: 12, speed: 70, accel: 1.2, contact: 11, xp: 6, color: '#9aa7b8', shape: 'hex', behavior: 'chase', weakDir: BACK, weakArc: 0.8, turn: 1.2 },
  splitter: { name: '分裂型', r: 22, hp: 14, armor: 4, speed: 60, accel: 1.5, contact: 8, xp: 2, color: '#a8ff7a', shape: 'blob', behavior: 'split', weakDir: SIDE, weakDir2: -SIDE, weakArc: 0.55, budInterval: 5, maxBuds: 5, turn: 1.5 },
  splitling: { name: '分裂体', r: 10, hp: 3, armor: 1.5, speed: 150, accel: 2.5, contact: 4, xp: 0.4, color: '#cfff9a', shape: 'blob', behavior: 'chase', weakDir: BACK, weakArc: 1.2 },
  leech: { name: '減速型', r: 20, hp: 14, armor: 5, speed: 120, accel: 1.6, contact: 6, xp: 3, color: '#c77dff', shape: 'diamond', behavior: 'leech', weakDir: BACK, weakArc: 0.9, auraR: 210, drain: 0.9, steal: 0.2 },
  gunner: { name: '射撃型', r: 18, hp: 12, armor: 4, speed: 110, accel: 2, contact: 8, xp: 3, color: '#ff6b9a', shape: 'ship', behavior: 'gunner', weakDir: BACK, weakArc: 0.9, keep: 560, fireInterval: 2.8, telegraph: 0.5, bulletSpeed: 430, bulletDmg: 7, slow: 0.12 },
  missile: { name: 'ミサイル艇', r: 22, hp: 20, armor: 6, speed: 85, accel: 1.5, contact: 10, xp: 5, color: '#ffb36b', shape: 'ship', behavior: 'missile', weakDir: SIDE, weakDir2: -SIDE, weakArc: 0.6, keep: 720, fireInterval: 4.5, telegraph: 0.6, missileSpeed: 500, missileTurn: 1.7, bulletDmg: 11, slow: 0.2 },
  battleship: { name: '戦艦', r: 95, hp: 420, armor: 20, speed: 45, accel: 0.6, contact: 22, xp: 45, color: '#d0d6e8', shape: 'ship', behavior: 'battleship', weakDir: BACK, weakArc: 0.55, turn: 0.5, fireInterval: 1.8, telegraph: 0.5, volley: 7, spread: 0.9, bulletSpeed: 380, bulletDmg: 12, slow: 0.15 },
  titan: { name: 'タイタン', r: 75, hp: 160, armor: 6, speed: 38, accel: 0.8, contact: 18, xp: 25, color: '#ff8fd1', shape: 'blob', behavior: 'chase', weakDir: BACK, weakArc: 1.0, turn: 0.8, sizeVar: true },
  boss: { name: 'ボス戦艦（暫定）', r: 120, hp: 2200, armor: 14, speed: 100, accel: 0.8, contact: 28, xp: 100, color: '#ff526e', shape: 'ship', behavior: 'battleship', weakDir: BACK, weakArc: 0.7, turn: 0.7, fireInterval: 2.6, telegraph: 0.8, volley: 9, spread: 1.3, bulletSpeed: 420, bulletDmg: 15, slow: 0.15 },
  meteor: { name: '隕石', r: 40, hp: 20, armor: 5, speed: 40, accel: 0, contact: 10, xp: 1, color: '#8b7a6a', shape: 'rock', behavior: 'drift', weakDir: 0, weakArc: 0 },
};

export const MAX_ENEMY_R = 130;

let nextId = 1;

export function createEnemy(type, level, x, y, opts = {}) {
  const T = ENEMY_TYPES[type];
  const L = Math.max(1, level);
  const elite = !!opts.elite;
  const size = type === 'meteor' || T.sizeVar ? (opts.size || T.r) : T.r;
  const sz = size / T.r;
  const hp = T.hp * sz * sz * (1 + 0.6 * (L - 1)) * CONFIG.enemyHpMult * (elite ? 3 : 1);
  return {
    id: nextId++, type, T, level: L, elite,
    x, y, vx: 0, vy: 0,
    r: size * (elite ? 1.25 : 1),
    hp, maxHp: hp,
    armor: T.armor * sz * (1 + 0.35 * (L - 1)) * CONFIG.enemyArmorMult * (elite ? 1.3 : 1),
    contact: T.contact * (1 + 0.2 * (L - 1)),
    xp: T.xp * sz * (1 + 0.5 * (L - 1)) * (elite ? 4 : 1),
    speed: T.speed * (1 + 0.04 * (L - 1)),
    facing: opts.facing ?? 0,
    weakDir: T.weakDir, weakDir2: T.weakDir2, weakArc: 0, // directional weak spots are not part of the current prototype
    hitCD: 0, flash: 0, dead: false,
    state: 'move', timer: 0, fireT: (T.fireInterval || 0) * (0.5 + Math.random() * 0.5), charge: 0, budT: 0, buds: 0, age: 0,
    parent: opts.parent || 0,
    spin: opts.spin || 0,
  };
}

function steerTo(e, tx, ty, speed, accel, dt) {
  const dx = tx - e.x, dy = ty - e.y;
  const d = Math.hypot(dx, dy) || 1;
  const k = Math.min(1, accel * dt);
  e.vx += ((dx / d) * speed - e.vx) * k;
  e.vy += ((dy / d) * speed - e.vy) * k;
}

function turnToward(e, target, rate, dt) {
  let d = target - e.facing;
  d = Math.atan2(Math.sin(d), Math.cos(d));
  const m = rate * dt;
  e.facing += Math.max(-m, Math.min(m, d));
}

// Where enemies think the ship is: a sluggish copy of its position (see updateEnemyAim), so a
// fast dash leaves their aim behind instead of being tracked instantly.
function enemyTarget(game) {
  return game.enemyAim || game.ship;
}

function angleToShip(e, game) {
  const t = enemyTarget(game);
  return Math.atan2(t.y - e.y, t.x - e.x);
}

// Ease the enemies' idea of the ship's position toward the real one: lagging by `enemyAimLag`
// seconds and never faster than `enemyAimSpeed`.
export function updateEnemyAim(game, dt) {
  const sh = game.ship;
  if (!game.enemyAim) { game.enemyAim = { x: sh.x, y: sh.y }; return; }
  const a = game.enemyAim;
  let dx = sh.x - a.x, dy = sh.y - a.y, d = Math.hypot(dx, dy);
  // Keep the reaction lag, but never let its target remain several screens behind forever.
  const maxLag = Math.max(300, game.viewRadius * 0.55);
  if (d > maxLag) {
    a.x = sh.x - dx / d * maxLag; a.y = sh.y - dy / d * maxLag;
    dx = sh.x - a.x; dy = sh.y - a.y; d = maxLag;
  }
  if (d < 1e-6) return;
  const step = Math.min(d * (1 - Math.exp(-dt / CONFIG.enemyAimLag)), CONFIG.enemyAimSpeed * dt);
  a.x += dx / d * step; a.y += dy / d * step;
}

// Hold a ring around the ship at `keep` distance while circling it.
function keepDistance(e, game, dt) {
  const sh = enemyTarget(game);
  const dx = e.x - sh.x, dy = e.y - sh.y;
  const d = Math.hypot(dx, dy) || 1;
  const side = e.id % 2 ? 1 : -1;
  const tx = sh.x + (dx / d) * e.T.keep - (dy / d) * 200 * side;
  const ty = sh.y + (dy / d) * e.T.keep + (dx / d) * 200 * side;
  steerTo(e, tx, ty, e.speed, e.T.accel, dt);
  turnToward(e, angleToShip(e, game), 3, dt);
}

function fire(game, e, angle, speed, kind) {
  const T = e.T;
  const lv = 1 + 0.25 * (e.level - 1);
  game.ebullets.push({
    kind, x: e.x + Math.cos(angle) * e.r, y: e.y + Math.sin(angle) * e.r,
    vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, speed,
    r: kind === 'missile' ? 9 : 7, dmg: T.bulletDmg * lv, slow: T.slow, life: kind === 'missile' ? 4.5 : 4,
    turn: T.missileTurn || 0,
  });
  game.events.push({ type: 'shoot', x: e.x, y: e.y, kind });
}

// Count down to a shot; `charge` > 0 while telegraphing.
function gunTimer(e, dt) {
  e.fireT -= dt;
  e.charge = e.fireT < e.T.telegraph ? 1 - Math.max(0, e.fireT) / e.T.telegraph : 0;
  if (e.fireT <= 0) { e.fireT = e.T.fireInterval; return true; }
  return false;
}

export const BEHAVIORS = {
  chase(e, game, dt) {
    const sh = enemyTarget(game);
    // Stagger pursuit so the whole population cannot settle around one central coordinate.
    // Bosses keep pursuing directly; ordinary enemies alternate rushes and broad moving routes.
    const cycle = (e.age + e.id * 1.61803398875) % CONFIG.enemyApproachCycle;
    const roam = e.type === 'boss' ? 0 : Math.max(0, Math.min(1,
      (cycle - CONFIG.enemyApproachTime) / CONFIG.enemyApproachBlend,
      (CONFIG.enemyApproachCycle - cycle) / CONFIG.enemyApproachBlend));
    const view = game.spawnView || { x: sh.x, y: sh.y, halfW: game.viewRadius * 0.707, halfH: game.viewRadius * 0.707 };
    const angle = e.id * 2.39996322973 + e.age * CONFIG.enemyRoamTurn;
    const ux = Math.cos(angle), uy = Math.sin(angle);
    const radius = (0.45 + 0.5 * Math.sqrt((e.id * 0.61803398875) % 1)) * Math.min(1, CONFIG.enemyPursuitSpread / 480);
    const edge = radius / Math.max(Math.abs(ux), Math.abs(uy));
    const tx = sh.x + (view.x + ux * edge * view.halfW - sh.x) * roam;
    const ty = sh.y + (view.y + uy * edge * view.halfH - sh.y) * roam;
    steerTo(e, tx, ty, e.speed, e.T.accel || 2, dt);
    turnToward(e, angleToShip(e, game), e.T.turn || 4, dt);
  },
  dash(e, game, dt) {
    const T = e.T;
    const sh = enemyTarget(game);
    const d = Math.hypot(sh.x - e.x, sh.y - e.y);
    e.timer -= dt;
    if (e.state === 'move') {
      BEHAVIORS.chase(e, game, dt);
      if (d < T.range) { e.state = 'windup'; e.timer = T.windup; }
    } else if (e.state === 'windup') {
      e.vx *= 1 - 4 * dt; e.vy *= 1 - 4 * dt;
      turnToward(e, angleToShip(e, game), 6, dt);
      if (e.timer <= 0) {
        e.state = 'dash'; e.timer = T.dashTime;
        e.vx = Math.cos(e.facing) * T.dashSpeed; e.vy = Math.sin(e.facing) * T.dashSpeed;
      }
    } else if (e.state === 'dash') {
      if (e.timer <= 0) { e.state = 'recover'; e.timer = T.recover; }
    } else {
      e.vx *= 1 - 2 * dt; e.vy *= 1 - 2 * dt;
      if (e.timer <= 0) e.state = 'move';
    }
  },
  split(e, game, dt) {
    BEHAVIORS.chase(e, game, dt);
    e.budT += dt;
    if (e.budT >= e.T.budInterval) {
      e.budT = 0;
      if (e.buds < e.T.maxBuds) {
        e.buds++;
        const a = game.rng() * Math.PI * 2;
        game.newEnemies.push(createEnemy('splitling', e.level, e.x + Math.cos(a) * e.r * 1.5, e.y + Math.sin(a) * e.r * 1.5, { parent: e.id, facing: a }));
      }
    }
  },
  leech(e, game, dt) {
    BEHAVIORS.chase(e, game, dt);
    const sh = game.ship;
    const d = Math.hypot(sh.x - e.x, sh.y - e.y);
    if (d < e.T.auraR) game.leechDrag += e.T.drain * (1 - d / e.T.auraR * 0.5);
  },
  gunner(e, game, dt) {
    keepDistance(e, game, dt);
    if (gunTimer(e, dt)) fire(game, e, angleToShip(e, game), e.T.bulletSpeed, 'bullet');
  },
  missile(e, game, dt) {
    keepDistance(e, game, dt);
    if (gunTimer(e, dt)) fire(game, e, e.facing, e.T.missileSpeed, 'missile');
  },
  battleship(e, game, dt) {
    BEHAVIORS.chase(e, game, dt);
    if (gunTimer(e, dt)) {
      const base = angleToShip(e, game);
      const n = e.T.volley;
      for (let i = 0; i < n; i++) fire(game, e, base + (i / (n - 1) - 0.5) * e.T.spread, e.T.bulletSpeed, 'bullet');
    }
  },
  drift(e, game, dt) {
    e.facing += e.spin * dt;
  },
};

export function onEnemyDeath(e, game) {
  if (e.type === 'splitter') {
    for (let i = 0; i < 2; i++) {
      const a = e.facing + (i ? 1 : -1) * Math.PI / 2;
      const c = createEnemy('splitling', e.level, e.x + Math.cos(a) * e.r, e.y + Math.sin(a) * e.r, { facing: a });
      c.vx = Math.cos(a) * 200; c.vy = Math.sin(a) * 200;
      c.hitCD = 0.35;
      game.newEnemies.push(c);
    }
  }
}

export function updateEnemy(e, game, dt) {
  e.age += dt;
  if (e.hitCD > 0) e.hitCD -= dt;
  if (e.flash > 0) e.flash -= dt;
  if (e.shove && e.shove.time > 0) {
    e.shoveFrom = { x: e.x, y: e.y };
    e.shove.time -= dt;
    e.vx = e.shove.vx; e.vy = e.shove.vy;
    e.shove.vx *= Math.exp(-dt * 0.8); e.shove.vy *= Math.exp(-dt * 0.8);
  } else if (e.knockT > 0) {
    e.knockT -= dt;
    const drag = Math.exp(-dt * 2);
    e.vx *= drag; e.vy *= drag;
  } else BEHAVIORS[e.T.behavior](e, game, dt);
  e.x += e.vx * dt;
  e.y += e.vy * dt;
  // stay out of the planet
  const p = game.field.planet;
  const d = Math.hypot(e.x - p.x, e.y - p.y);
  if (d < p.r + e.r && d > 0) {
    e.x = p.x + ((e.x - p.x) / d) * (p.r + e.r);
    e.y = p.y + ((e.y - p.y) / d) * (p.r + e.r);
  }
}
