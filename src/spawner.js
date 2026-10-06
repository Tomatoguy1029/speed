import { createEnemy, ENEMY_TYPES } from './enemies.js';
import { lerp, pickWeighted, TAU, clamp } from './math.js';
import { CONFIG } from './config.js';
import { dangerAt } from './field.js';

// The run's experience curve. pop = enemies kept around the ship, level = enemy strength.
export const PHASES = [
  { id: 'build1', name: '強化期', sub: '弱い敵を吹っ飛ばして機体を育てろ', start: 0, end: 150, pop: [14, 45], level: [1.0, 1.35], rate: 6, mix: { drifter: 6, darter: 1.5, splitter: 0.8, swarm: 1, titan: 0.05 } },
  { id: 'pressure', name: '圧力期', sub: '敵が硬くなってきた', start: 150, end: 240, pop: [45, 70], level: [1.7, 2.3], rate: 8, mix: { drifter: 3.5, darter: 3, armored: 2.2, gunner: 1.1, leech: 1.5, splitter: 1.5, titan: 0.3 } },
  { id: 'build2', name: '強化期 II', sub: '今のうちに組み上げろ', start: 240, end: 300, pop: [38, 45], level: [2.0, 2.2], rate: 6, xpBonus: 1.4, mix: { drifter: 4, darter: 2, splitter: 2, gunner: 1, swarm: 2, titan: 0.4 } },
  { id: 'rampage', name: '無双期', sub: '群れが来る — まとめて貫け', start: 300, end: 360, pop: [140, 260], level: [1.3, 1.6], rate: 60, waves: 3.5, mix: { swarm: 10, drifter: 3, splitling: 2 } },
  { id: 'tension', name: '緊張期', sub: '互角の相手。弱点を突け', start: 360, end: 510, pop: [70, 110], level: [3.0, 4.4], rate: 10, mix: { darter: 3, armored: 3, gunner: 2, missile: 1.3, leech: 2, splitter: 2, drifter: 2.5, titan: 1.2, battleship: 0.3 } },
  { id: 'escape', name: '脱出期', sub: '出力コアで上限を解放し、脱出速度へ', start: 510, end: 600, pop: [90, 120], level: [4.2, 5.0], rate: 12, cores: true, mix: { darter: 3, armored: 3, gunner: 2, missile: 1.6, leech: 2, splitter: 1.5, swarm: 3, titan: 2, battleship: 0.6 } },
];

export function getPhase(t) {
  for (const p of PHASES) if (t < p.end) return p;
  return PHASES[PHASES.length - 1];
}

export function phaseTarget(t) {
  const p = getPhase(t);
  const k = clamp((t - p.start) / (p.end - p.start), 0, 1);
  return { phase: p, pop: lerp(p.pop[0], p.pop[1], k) * CONFIG.densityMult, level: lerp(p.level[0], p.level[1], k) };
}

function spawnPoint(game, extra = 0) {
  const sh = game.ship;
  for (let i = 0; i < 6; i++) {
    const a = game.rng() * TAU;
    const d = game.viewRadius + 100 + extra + game.rng() * 300;
    const x = sh.x + Math.cos(a) * d, y = sh.y + Math.sin(a) * d;
    const r = Math.hypot(x, y);
    if (r < CONFIG.fieldRadius + 200 && r > CONFIG.planetRadius + 150) return { x, y, a };
  }
  return null;
}

// Dangerous zones add tougher enemies; early in the run that bias is mostly armor, not guns.
function mixAt(phase, danger, t) {
  const items = Object.entries(phase.mix);
  if (danger > 0.25) {
    const ramp = clamp(t / 150, 0.15, 1);
    items.push(['armored', 2 * danger], ['gunner', danger * ramp], ['missile', 0.7 * danger * ramp]);
  }
  return items;
}

function spawnOne(game, target) {
  const pt = spawnPoint(game);
  if (!pt) return;
  const danger = dangerAt(Math.hypot(pt.x, pt.y));
  const type = pickWeighted(game.rng, mixAt(target.phase, danger, game.t));
  if (type === 'battleship' && game.enemies.some((e) => e.type === 'battleship')) return;
  if (type === 'titan' && game.enemies.filter((e) => e.type === 'titan').length >= 6) return;
  const T = ENEMY_TYPES[type];
  const late = target.phase.id === 'tension' || target.phase.id === 'escape';
  const elite = type !== 'battleship' && game.rng() < 0.01 + 0.06 * danger + (late ? 0.02 : 0);
  const level = target.level + danger * CONFIG.dangerLevel;
  const size = T.sizeVar ? T.r * (0.85 + game.rng() * 0.45) : undefined;
  game.enemies.push(createEnemy(type, level, pt.x, pt.y, { elite, size, facing: pt.a + Math.PI }));
}

function spawnWave(game, target, remaining) {
  const sh = game.ship;
  const n = Math.min(Math.round(30 * CONFIG.densityMult), Math.ceil(remaining));
  if (game.rng() < 0.5) {
    // ring closing in
    const d = game.viewRadius * 0.95;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * TAU;
      game.enemies.push(createEnemy('swarm', target.level, sh.x + Math.cos(a) * d, sh.y + Math.sin(a) * d, { facing: a + Math.PI }));
    }
  } else {
    // a stream from one direction
    const a = game.rng() * TAU;
    for (let i = 0; i < n; i++) {
      const d = game.viewRadius + 80 + i * 34;
      const off = (game.rng() - 0.5) * 120;
      game.enemies.push(createEnemy('swarm', target.level, sh.x + Math.cos(a) * d - Math.sin(a) * off, sh.y + Math.sin(a) * d + Math.cos(a) * off, { facing: a + Math.PI }));
    }
  }
  game.events.push({ type: 'wave' });
}

function keepMeteors(game) {
  let near = 0;
  for (const e of game.enemies) if (e.type === 'meteor') near++;
  if (near >= CONFIG.meteorCount) return;
  const pt = spawnPoint(game, 200);
  if (!pt) return;
  const m = createEnemy('meteor', 1, pt.x, pt.y, { size: 24 + game.rng() * 46, spin: (game.rng() - 0.5) * 1.2, facing: game.rng() * TAU });
  const a = pt.a + Math.PI + (game.rng() - 0.5) * 1.6;
  m.vx = Math.cos(a) * m.speed; m.vy = Math.sin(a) * m.speed;
  game.enemies.push(m);
}

function despawnFar(game) {
  const sh = game.ship;
  const far = game.viewRadius * 2.6 + 800;
  let removed = false;
  for (const e of game.enemies) {
    if (e.type === 'boss') continue;
    const lim = e.type === 'battleship' ? far * 1.6 : far;
    if (Math.abs(e.x - sh.x) > lim || Math.abs(e.y - sh.y) > lim) { e.dead = true; removed = true; }
  }
  if (removed) game.enemies = game.enemies.filter((e) => !e.dead);
}

export function updateSpawner(game, dt) {
  if (!game.spawning) return;
  if (!game.bossSpawned && game.t >= CONFIG.bossTime) spawnBoss(game);
  despawnFar(game);
  keepMeteors(game);
  const target = phaseTarget(game.t);
  const P = target.phase;
  let alive = 0;
  for (const e of game.enemies) if (e.type !== 'meteor' && e.type !== 'boss') alive++;
  game.spawnAcc = Math.min(game.spawnAcc + P.rate * CONFIG.densityMult * dt, Math.max(8, 8 * CONFIG.densityMult));
  while (game.spawnAcc >= 1 && alive < target.pop) {
    game.spawnAcc -= 1;
    spawnOne(game, target);
    alive++;
  }
  if (P.waves) {
    game.waveT = (game.waveT || 0) + dt;
    if (game.waveT >= P.waves) { game.waveT = 0; if (alive < target.pop) spawnWave(game, target, target.pop - alive); }
  }
}

function spawnBoss(game) {
  const sh = game.ship;
  const distance = Math.min(1000, game.viewRadius * 0.65);
  const angle = game.rng() * TAU;
  let x = sh.x + Math.cos(angle) * distance, y = sh.y + Math.sin(angle) * distance;
  const planet = game.field.planet;
  if (Math.hypot(x - planet.x, y - planet.y) < planet.r + 180) {
    const a = Math.atan2(sh.y - planet.y, sh.x - planet.x);
    x = planet.x + Math.cos(a) * (planet.r + 220);
    y = planet.y + Math.sin(a) * (planet.r + 220);
  }
  const r = Math.hypot(x, y);
  if (r > CONFIG.fieldRadius - 160) { x *= (CONFIG.fieldRadius - 160) / r; y *= (CONFIG.fieldRadius - 160) / r; }
  const boss = createEnemy('boss', 1, x, y, { facing: Math.atan2(sh.y - y, sh.x - x) });
  boss.hp = boss.maxHp = CONFIG.bossHp * CONFIG.enemyHpMult;
  boss.armor = CONFIG.bossArmor * CONFIG.enemyArmorMult;
  game.boss = boss;
  game.bossSpawned = true;
  game.enemies.push(boss);
  game.events.push({ type: 'bossSpawn', x, y });
}
