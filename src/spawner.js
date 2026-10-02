import { createEnemy } from './enemies.js';
import { lerp, pickWeighted, TAU, clamp } from './math.js';
import { CONFIG } from './config.js';
import { dangerAt } from './field.js';

// The run's experience curve. pop = enemies kept around the ship, level = enemy strength.
export const PHASES = [
  { id: 'build1', name: '強化期', sub: '弱い敵を吹っ飛ばして機体を育てろ', start: 0, end: 150, pop: [14, 45], level: [1.0, 1.35], rate: 6, mix: { drifter: 6, darter: 1.5, splitter: 0.8, swarm: 1 } },
  { id: 'pressure', name: '圧力期', sub: '敵が硬くなってきた', start: 150, end: 240, pop: [45, 70], level: [1.7, 2.3], rate: 8, mix: { drifter: 3, darter: 3, armored: 2.2, gunner: 2, leech: 1.5, splitter: 1.5 } },
  { id: 'build2', name: '強化期 II', sub: '今のうちに組み上げろ', start: 240, end: 300, pop: [38, 45], level: [2.0, 2.2], rate: 6, xpBonus: 1.4, mix: { drifter: 4, darter: 2, splitter: 2, gunner: 1, swarm: 2 } },
  { id: 'rampage', name: '無双期', sub: '群れが来る — まとめて貫け', start: 300, end: 360, pop: [140, 260], level: [1.3, 1.6], rate: 60, waves: 3.5, mix: { swarm: 10, drifter: 3, splitling: 2 } },
  { id: 'tension', name: '緊張期', sub: '互角の相手。弱点を突け', start: 360, end: 510, pop: [70, 110], level: [3.0, 4.4], rate: 10, mix: { darter: 3, armored: 3, gunner: 3, missile: 2, leech: 2, splitter: 2, drifter: 2, battleship: 0.12 } },
  { id: 'escape', name: '脱出期', sub: '出力コアで上限を解放し、脱出速度へ', start: 510, end: 600, pop: [90, 120], level: [4.2, 5.0], rate: 12, cores: true, mix: { darter: 3, armored: 3, gunner: 3, missile: 2.5, leech: 2, splitter: 1.5, swarm: 3, battleship: 0.25 } },
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

function mixAt(phase, danger) {
  const items = Object.entries(phase.mix);
  if (danger > 0.25) {
    items.push(['armored', 2 * danger], ['gunner', 1.5 * danger], ['missile', danger]);
  }
  return items;
}

function spawnOne(game, target) {
  const pt = spawnPoint(game);
  if (!pt) return;
  const danger = dangerAt(Math.hypot(pt.x, pt.y));
  const type = pickWeighted(game.rng, mixAt(target.phase, danger));
  if (type === 'battleship' && game.enemies.some((e) => e.type === 'battleship')) return;
  const late = target.phase.id === 'tension' || target.phase.id === 'escape';
  const elite = type !== 'battleship' && game.rng() < 0.01 + 0.06 * danger + (late ? 0.02 : 0);
  const level = target.level + danger * CONFIG.dangerLevel;
  game.enemies.push(createEnemy(type, level, pt.x, pt.y, { elite, facing: pt.a + Math.PI }));
}

function spawnWave(game, target) {
  const sh = game.ship;
  const n = Math.round(30 * CONFIG.densityMult);
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
    const lim = e.type === 'battleship' ? far * 1.6 : far;
    if (Math.abs(e.x - sh.x) > lim || Math.abs(e.y - sh.y) > lim) { e.dead = true; removed = true; }
  }
  if (removed) game.enemies = game.enemies.filter((e) => !e.dead);
}

export function updateSpawner(game, dt) {
  if (!game.spawning) return;
  despawnFar(game);
  keepMeteors(game);
  const target = phaseTarget(game.t);
  const P = target.phase;
  let alive = 0;
  for (const e of game.enemies) if (e.type !== 'meteor') alive++;
  game.spawnAcc = Math.min(game.spawnAcc + P.rate * dt, 8);
  while (game.spawnAcc >= 1 && alive < target.pop) {
    game.spawnAcc -= 1;
    spawnOne(game, target);
    alive++;
  }
  if (P.waves) {
    game.waveT = (game.waveT || 0) + dt;
    if (game.waveT >= P.waves) { game.waveT = 0; spawnWave(game, target); }
  }
}
