import { CONFIG } from './config.js';

const BACK = Math.PI;

// hp/armor/contact are level-1 values; armor is in attack units (speed/100 at x1 multiplier).
export const ENEMY_TYPES = {
  drifter: { name: 'ドリフター', r: 14, hp: 6, armor: 2, speed: 130, accel: 2.5, contact: 6, xp: 1, color: '#7fd1ff', shape: 'orb', behavior: 'chase', weakDir: BACK, weakArc: 1.0 },
  armored: { name: '装甲型', r: 30, hp: 40, armor: 12, speed: 70, accel: 1.2, contact: 16, xp: 6, color: '#9aa7b8', shape: 'hex', behavior: 'chase', weakDir: BACK, weakArc: 0.8, turn: 1.2 },
};

export const MAX_ENEMY_R = 130;

let nextId = 1;

export function createEnemy(type, level, x, y, opts = {}) {
  const T = ENEMY_TYPES[type];
  const L = Math.max(1, level);
  const elite = !!opts.elite;
  return {
    id: nextId++, type, T, level: L, elite,
    x, y, vx: 0, vy: 0,
    r: T.r * (elite ? 1.25 : 1),
    hp: 0, maxHp: 0,
    armor: T.armor * (1 + 0.35 * (L - 1)) * CONFIG.enemyArmorMult * (elite ? 1.3 : 1),
    contact: T.contact * (1 + 0.3 * (L - 1)),
    xp: T.xp * (1 + 0.5 * (L - 1)) * (elite ? 4 : 1),
    speed: T.speed * (1 + 0.04 * (L - 1)),
    facing: opts.facing ?? 0,
    weakDir: T.weakDir, weakArc: T.weakArc || 0,
    hitCD: 0, flash: 0, dead: false,
    state: 'move', timer: 0, fireT: 0, budT: 0, age: 0,
    ...(function hp() {
      const v = T.hp * (1 + 0.6 * (L - 1)) * CONFIG.enemyHpMult * (elite ? 3 : 1);
      return { hp: v, maxHp: v };
    })(),
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

export const BEHAVIORS = {
  chase(e, game, dt) {
    const sh = game.ship;
    steerTo(e, sh.x, sh.y, e.speed, e.T.accel || 2, dt);
    turnToward(e, Math.atan2(sh.y - e.y, sh.x - e.x), e.T.turn || 4, dt);
  },
};

export function updateEnemy(e, game, dt) {
  e.age += dt;
  if (e.hitCD > 0) e.hitCD -= dt;
  if (e.flash > 0) e.flash -= dt;
  BEHAVIORS[e.T.behavior](e, game, dt);
  e.x += e.vx * dt;
  e.y += e.vy * dt;
  // stay out of the planet
  const p = game.field.planet;
  const d = Math.hypot(e.x, e.y);
  if (d < p.r + e.r && d > 0) {
    e.x = (e.x / d) * (p.r + e.r);
    e.y = (e.y / d) * (p.r + e.r);
  }
}
