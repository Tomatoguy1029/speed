// Weapons gained and upgraded through level-ups (Vampire Survivors style). Each weapon has 8 levels;
// damage scales with the attack multiplier (level, modules, station), never with speed. No weapon
// starts an attack during a jump; projectiles already flying keep going on world time.
import { CONFIG } from './config.js';
import { queryGrid } from './grid.js';
import { MAX_ENEMY_R } from './enemies.js';
import { damageEnemy, explode } from './hits.js';

// Builds cumulative per-level stats: level 1 = base, each step edits a copy of the previous level.
function ladder(base, steps) {
  const out = [{ ...base, text: null }];
  for (const [text, edit] of steps) {
    const s = { ...out[out.length - 1], text };
    edit(s);
    out.push(s);
  }
  return out;
}

export const GUN_LEVELS = ladder({ dmg: 1, rate: 1, shots: 1, pierce: 0 }, [
  ['威力 +30%', (s) => { s.dmg = 1.3; }],
  ['弾 +1', (s) => { s.shots = 2; }],
  ['連射 +30%', (s) => { s.rate = 1.3; }],
  ['貫通 +1', (s) => { s.pierce = 1; }],
  ['弾 +1', (s) => { s.shots = 3; }],
  ['威力 +40%', (s) => { s.dmg = 1.8; }],
  ['貫通 +2、連射 +25%', (s) => { s.pierce = 3; s.rate = 1.6; }],
]);

const MISSILE_LEVELS = ladder({ count: 1, dmg: 1, radius: 70, rate: 1 }, [
  ['ミサイル +1', (s) => { s.count++; }],
  ['威力 +30%', (s) => { s.dmg *= 1.3; }],
  ['爆発範囲 +25%', (s) => { s.radius *= 1.25; }],
  ['ミサイル +1', (s) => { s.count++; }],
  ['発射間隔 -20%', (s) => { s.rate *= 1.25; }],
  ['ミサイル +1', (s) => { s.count++; }],
  ['威力 +40%、爆発範囲 +20%', (s) => { s.dmg *= 1.4; s.radius *= 1.2; }],
]);

const ORBIT_LEVELS = ladder({ blades: 2, dmg: 1, dist: 90, spin: 3.2 }, [
  ['威力 +30%', (s) => { s.dmg *= 1.3; }],
  ['刃 +1', (s) => { s.blades++; }],
  ['回転半径 +25%、回転 +20%', (s) => { s.dist *= 1.25; s.spin *= 1.2; }],
  ['刃 +1', (s) => { s.blades++; }],
  ['威力 +30%', (s) => { s.dmg *= 1.3; }],
  ['刃 +1', (s) => { s.blades++; }],
  ['回転半径 +25%、威力 +30%', (s) => { s.dist *= 1.25; s.dmg *= 1.3; }],
]);

const NOVA_LEVELS = ladder({ radius: 180, dmg: 1, rate: 1 }, [
  ['範囲 +20%', (s) => { s.radius *= 1.2; }],
  ['威力 +40%', (s) => { s.dmg *= 1.4; }],
  ['間隔 -20%', (s) => { s.rate *= 1.25; }],
  ['範囲 +20%', (s) => { s.radius *= 1.2; }],
  ['威力 +40%', (s) => { s.dmg *= 1.4; }],
  ['間隔 -20%', (s) => { s.rate *= 1.25; }],
  ['範囲 +25%、威力 +40%', (s) => { s.radius *= 1.25; s.dmg *= 1.4; }],
]);

const ARC_LEVELS = ladder({ chains: 3, dmg: 1, rate: 1, reach: 220, bolts: 1 }, [
  ['威力 +30%', (s) => { s.dmg *= 1.3; }],
  ['連鎖 +2', (s) => { s.chains += 2; }],
  ['発射間隔 -20%', (s) => { s.rate *= 1.25; }],
  ['威力 +30%', (s) => { s.dmg *= 1.3; }],
  ['連鎖 +2、飛び移る距離 +20%', (s) => { s.chains += 2; s.reach *= 1.2; }],
  ['稲妻 +1', (s) => { s.bolts++; }],
  ['威力 +40%、連鎖 +3', (s) => { s.dmg *= 1.4; s.chains += 3; }],
]);

const LASER_LEVELS = ladder({ beams: 1, dmg: 1, width: 14, length: 700, rate: 1 }, [
  ['威力 +30%', (s) => { s.dmg *= 1.3; }],
  ['太さ +50%', (s) => { s.width *= 1.5; }],
  ['発射間隔 -20%', (s) => { s.rate *= 1.25; }],
  ['長さ +30%', (s) => { s.length *= 1.3; }],
  ['ビーム +1', (s) => { s.beams++; }],
  ['威力 +40%', (s) => { s.dmg *= 1.4; }],
  ['ビーム +1、太さ +30%', (s) => { s.beams++; s.width *= 1.3; }],
]);

const DISC_LEVELS = ladder({ discs: 1, dmg: 1, size: 16, rate: 1 }, [
  ['威力 +30%', (s) => { s.dmg *= 1.3; }],
  ['ディスク +1', (s) => { s.discs++; }],
  ['大きさ +40%', (s) => { s.size *= 1.4; }],
  ['発射間隔 -20%', (s) => { s.rate *= 1.25; }],
  ['ディスク +1', (s) => { s.discs++; }],
  ['威力 +40%', (s) => { s.dmg *= 1.4; }],
  ['ディスク +1、大きさ +30%', (s) => { s.discs++; s.size *= 1.3; }],
]);

// fire(game, L, st): one attack. interval: seconds between attacks at rate 1 (omit for always-on weapons).
export const WEAPONS = [
  { id: 'gun', name: 'ブラスター', color: '#ffe46b', levels: GUN_LEVELS, // interval from CONFIG.gunRate (tunable)
    desc: '進行方向へ弾を撃つ（止まっていても最後に進んだ方向へ）', fire: fireGun },
  { id: 'missile', name: '追尾ミサイル', color: '#ff9f40', levels: MISSILE_LEVELS, interval: 1.6,
    desc: '近くの敵を追いかけて小さく爆発するミサイル', fire: fireMissiles },
  { id: 'orbit', name: 'オービットブレード', color: '#9fe8ff', levels: ORBIT_LEVELS,
    desc: '機体の周りを回り続ける刃。触れた敵を切り続ける', fire: null },
  { id: 'nova', name: 'パルスノヴァ', color: '#c995ff', levels: NOVA_LEVELS, interval: 2.5,
    desc: '一定間隔で機体から衝撃波を放ち、周りの敵を押し返す', fire: fireNova },
  { id: 'arc', name: 'アークコイル', color: '#a8f0ff', levels: ARC_LEVELS, interval: 1.2,
    desc: '近くの敵に稲妻を落とし、次々と飛び移る', fire: fireArc },
  { id: 'laser', name: 'レーザーランス', color: '#ff6bd5', levels: LASER_LEVELS, interval: 2.2,
    desc: '最も近い敵の方向へ、すべてを貫く長いビームを撃つ', fire: fireLaser },
  { id: 'disc', name: 'リターンディスク', color: '#6dffb0', levels: DISC_LEVELS, interval: 1.8,
    desc: '敵の方へ投げると戻ってくる刃。行きも帰りも貫く', fire: fireDiscs },
];

const WEAPON_DEFS = Object.fromEntries(WEAPONS.map((w) => [w.id, w]));

export function weaponDef(id) {
  return WEAPON_DEFS[id];
}

export function weaponCount(game) {
  return Object.values(game.weapons).filter((lv) => lv > 0).length;
}

const wdmg = (game, base) => base * game.stats.atkMult * CONFIG.atkScale * (game.stats.burstPower || 1);

// Nearest live enemies to (x, y) within range, closest first.
function nearestEnemies(game, x, y, range, n, skip) {
  const found = [];
  queryGrid(game.grid, x - range - MAX_ENEMY_R, y - range - MAX_ENEMY_R, x + range + MAX_ENEMY_R, y + range + MAX_ENEMY_R, (e) => {
    if (e.dead || (skip && skip.has(e.id))) return;
    const d = Math.hypot(e.x - x, e.y - y) - e.r;
    if (d <= range) found.push({ e, d });
  });
  found.sort((a, b) => a.d - b.d);
  return found.slice(0, n).map((f) => f.e);
}

function aimAt(game, target) {
  const sh = game.ship;
  if (target) return Math.atan2(target.y - sh.y, target.x - sh.x);
  return Math.atan2(sh.hy, sh.hx);
}

export function updateWeapons(game, dt) {
  const busy = game.draw || game.portalDash;
  for (const w of WEAPONS) {
    const lv = game.weapons[w.id] || 0;
    if (!lv || w.id === 'gun') continue;
    const L = w.levels[lv - 1];
    const st = game.wstate[w.id] || (game.wstate[w.id] = { t: 0 });
    if (w.id === 'orbit') { updateOrbit(game, L, st, dt); continue; }
    if (busy) continue;
    st.t += dt;
    if (st.t < (w.interval ?? 1 / CONFIG.gunRate) / (L.rate || 1)) continue;
    if (w.fire(game, L, st) !== false) st.t = 0;
  }
  updateWeaponProjectiles(game, dt);
  for (const f of game.wfx) f.life -= dt;
  if (game.wfx.length) game.wfx = game.wfx.filter((f) => f.life > 0);
}

function fireGun(game, L) {
  const sh = game.ship;
  const base = Math.atan2(sh.hy, sh.hx);
  const dmg = wdmg(game, CONFIG.gunDamage * L.dmg);
  for (let i = 0; i < L.shots; i++) {
    const a = base + (i - (L.shots - 1) / 2) * CONFIG.gunSpread;
    game.fbullets.push({ kind: 'gun', x: sh.x, y: sh.y, vx: Math.cos(a) * CONFIG.gunSpeed + sh.vx, vy: Math.sin(a) * CONFIG.gunSpeed + sh.vy,
      r: 5, dmg, life: CONFIG.gunLife, pierce: false, pierceLeft: L.pierce, hit: new Set(), color: '#ffe46b' });
  }
  game.events.push({ type: 'turret' });
}

function fireMissiles(game, L) {
  const sh = game.ship;
  const targets = nearestEnemies(game, sh.x, sh.y, 750, L.count);
  if (!targets.length) return false;
  for (let i = 0; i < L.count; i++) {
    const t = targets[i % targets.length];
    const a = aimAt(game, t) + (i - (L.count - 1) / 2) * 0.5;
    game.wproj.push({ kind: 'missile', x: sh.x, y: sh.y, vx: Math.cos(a) * 420, vy: Math.sin(a) * 420, target: t, life: 2.5,
      dmg: wdmg(game, 8 * L.dmg), radius: L.radius });
  }
  game.events.push({ type: 'shoot' });
}

function fireNova(game, L) {
  const sh = game.ship;
  explode(game, sh.x, sh.y, L.radius, wdmg(game, 6 * L.dmg), { cause: 'nova', color: '#c995ff', knock: 380, life: 0.5 });
}

function fireArc(game, L) {
  const sh = game.ship;
  const hit = new Set();
  let any = false;
  for (let b = 0; b < L.bolts; b++) {
    let from = { x: sh.x, y: sh.y };
    const pts = [from];
    let next = nearestEnemies(game, sh.x, sh.y, 450, 1, hit)[0];
    for (let k = 0; k < L.chains && next; k++) {
      hit.add(next.id);
      pts.push({ x: next.x, y: next.y });
      damageEnemy(game, next, wdmg(game, 7 * L.dmg), { cause: 'arc', dirX: (next.x - from.x) / (Math.hypot(next.x - from.x, next.y - from.y) || 1), dirY: (next.y - from.y) / (Math.hypot(next.x - from.x, next.y - from.y) || 1), knock: 120 });
      from = next;
      next = nearestEnemies(game, from.x, from.y, L.reach, 1, hit)[0];
    }
    if (pts.length > 1) { any = true; game.wfx.push({ kind: 'bolt', pts, life: 0.18, max: 0.18 }); }
  }
  if (!any) return false;
  game.events.push({ type: 'shoot' });
}

function fireLaser(game, L) {
  const sh = game.ship;
  const targets = nearestEnemies(game, sh.x, sh.y, L.length, L.beams);
  if (!targets.length) return false;
  const dmg = wdmg(game, 10 * L.dmg);
  for (let i = 0; i < L.beams; i++) {
    const a = aimAt(game, targets[i % targets.length]) + (i >= targets.length ? 0.4 * i : 0);
    const ux = Math.cos(a), uy = Math.sin(a);
    const x1 = sh.x + ux * L.length, y1 = sh.y + uy * L.length, half = L.width / 2;
    queryGrid(game.grid, Math.min(sh.x, x1) - half - MAX_ENEMY_R, Math.min(sh.y, y1) - half - MAX_ENEMY_R,
      Math.max(sh.x, x1) + half + MAX_ENEMY_R, Math.max(sh.y, y1) + half + MAX_ENEMY_R, (e) => {
        if (e.dead) return;
        const t = Math.max(0, Math.min(L.length, (e.x - sh.x) * ux + (e.y - sh.y) * uy));
        if (Math.hypot(sh.x + ux * t - e.x, sh.y + uy * t - e.y) > e.r + half) return;
        damageEnemy(game, e, dmg, { cause: 'laser', dirX: ux, dirY: uy, knock: 140 });
      });
    game.wfx.push({ kind: 'beam', x0: sh.x, y0: sh.y, x1, y1, width: L.width, life: 0.22, max: 0.22 });
  }
  game.events.push({ type: 'shoot' });
}

function fireDiscs(game, L) {
  const sh = game.ship;
  const t = nearestEnemies(game, sh.x, sh.y, 600, 1)[0];
  const base = aimAt(game, t);
  for (let i = 0; i < L.discs; i++) {
    const a = base + (i - (L.discs - 1) / 2) * 0.45;
    game.wproj.push({ kind: 'disc', x: sh.x, y: sh.y, vx: Math.cos(a) * 950 + sh.vx * 0.5, vy: Math.sin(a) * 950 + sh.vy * 0.5,
      ax: -Math.cos(a) * 1300, ay: -Math.sin(a) * 1300, life: 1.6, r: L.size, dmg: wdmg(game, 6 * L.dmg), hits: new Map(), spin: 0 });
  }
}

// Orbit blades are always out (even during jumps); each enemy can be cut again every 0.4 s.
function updateOrbit(game, L, st, dt) {
  const sh = game.ship;
  st.angle = (st.angle || 0) + L.spin * dt;
  st.hits = st.hits || new Map();
  const dmg = wdmg(game, 4 * L.dmg), R = 14;
  st.blades = [];
  for (let i = 0; i < L.blades; i++) {
    const a = st.angle + i * Math.PI * 2 / L.blades;
    const bx = sh.x + Math.cos(a) * L.dist, by = sh.y + Math.sin(a) * L.dist;
    st.blades.push({ x: bx, y: by, a });
    queryGrid(game.grid, bx - R - MAX_ENEMY_R, by - R - MAX_ENEMY_R, bx + R + MAX_ENEMY_R, by + R + MAX_ENEMY_R, (e) => {
      if (e.dead || (st.hits.get(e.id) || 0) > game.t) return;
      const d = Math.hypot(e.x - bx, e.y - by);
      if (d > e.r + R) return;
      st.hits.set(e.id, game.t + 0.4);
      damageEnemy(game, e, dmg, { cause: 'orbit', dirX: (e.x - sh.x) / (Math.hypot(e.x - sh.x, e.y - sh.y) || 1), dirY: (e.y - sh.y) / (Math.hypot(e.x - sh.x, e.y - sh.y) || 1), knock: 200 });
    });
  }
  if (st.hits.size > 400) for (const [id, until] of st.hits) if (until <= game.t) st.hits.delete(id);
}

function updateWeaponProjectiles(game, dt) {
  const P = game.wproj;
  if (!P.length) return;
  for (const p of P) {
    p.life -= dt;
    if (p.kind === 'missile') {
      if (!p.target || p.target.dead) p.target = nearestEnemies(game, p.x, p.y, 600, 1)[0] || null;
      const sp = Math.hypot(p.vx, p.vy) || 1;
      let a = Math.atan2(p.vy, p.vx);
      if (p.target) {
        const want = Math.atan2(p.target.y - p.y, p.target.x - p.x);
        const d = Math.atan2(Math.sin(want - a), Math.cos(want - a));
        a += Math.max(-6 * dt, Math.min(6 * dt, d));
      }
      const v = Math.min(900, sp + 900 * dt);
      p.vx = Math.cos(a) * v; p.vy = Math.sin(a) * v;
      p.x += p.vx * dt; p.y += p.vy * dt;
      let boom = p.life <= 0;
      if (!boom) {
        queryGrid(game.grid, p.x - 10 - MAX_ENEMY_R, p.y - 10 - MAX_ENEMY_R, p.x + 10 + MAX_ENEMY_R, p.y + 10 + MAX_ENEMY_R, (e) => {
          if (!e.dead && Math.hypot(e.x - p.x, e.y - p.y) < e.r + 10) boom = true;
        });
      }
      if (boom) { explode(game, p.x, p.y, p.radius, p.dmg, { cause: 'missile', color: '#ff9f40', knock: 260, life: 0.3 }); p.life = 0; }
    } else if (p.kind === 'disc') {
      p.vx += p.ax * dt; p.vy += p.ay * dt;
      p.x += p.vx * dt; p.y += p.vy * dt;
      p.spin += dt * 14;
      queryGrid(game.grid, p.x - p.r - MAX_ENEMY_R, p.y - p.r - MAX_ENEMY_R, p.x + p.r + MAX_ENEMY_R, p.y + p.r + MAX_ENEMY_R, (e) => {
        if (e.dead || (p.hits.get(e.id) || 0) > game.t) return;
        if (Math.hypot(e.x - p.x, e.y - p.y) > e.r + p.r) return;
        p.hits.set(e.id, game.t + 0.35);
        const sp = Math.hypot(p.vx, p.vy) || 1;
        damageEnemy(game, e, p.dmg, { cause: 'disc', dirX: p.vx / sp, dirY: p.vy / sp, knock: 180 });
      });
    }
  }
  game.wproj = P.filter((p) => p.life > 0);
}
