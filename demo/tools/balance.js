// Headless balance probe: a simple bot plays full runs and reports each phase.
// usage: node tools/balance.js [runs=3] [seed=1]
import { createGame, update, predictPath } from '../src/world.js';
import { CONFIG } from '../src/config.js';
import { attackPower, canPierce } from '../src/combat.js';
import { getPhase, PHASES } from '../src/spawner.js';
import { moduleDef } from '../src/modules.js';
import { queryRadius } from '../src/grid.js';

const TAU = Math.PI * 2;
const kms = (v) => (v * CONFIG.speedToKms).toFixed(2);

function scoreDir(game, dx, dy) {
  const s = game.stats;
  const pts = predictPath(game, dx, dy, s.gaugeMax, 0.8);
  let score = 0;
  const seen = new Set();
  let peak = 0;
  for (let i = 0; i < pts.length; i += 2) {
    const p = pts[i];
    peak = Math.max(peak, p.sp);
    let blocked = false;
    queryRadius(game.grid, p.x, p.y, 26, (e) => {
      if (seen.has(e.id) || blocked) return;
      seen.add(e.id);
      if (canPierce(attackPower(p.sp, s), e, false)) score += 1 + (e.elite ? 3 : 0) + (e.type === 'battleship' ? 6 : 0);
      else { score -= 6; blocked = true; }
    });
    if (blocked) break;
    for (const c of game.capsules) if ((c.x - p.x) ** 2 + (c.y - p.y) ** 2 < 70 * 70) score += c.kind === 'core' ? 30 : 6 + c.mod.r * 3;
  }
  const end = pts[pts.length - 1];
  if (!end) return -100;
  if (end.block) score -= 12; // hits the planet or a moon
  const r = Math.hypot(end.x, end.y);
  if (r > CONFIG.fieldRadius) score -= 8;
  // early on stay away from the dangerous zones, late game go chase speed
  const late = game.t > 480;
  if (!late && (r < CONFIG.zoneInner * 0.8 || r > CONFIG.zoneOuter + 600)) score -= 3;
  if (late) score += (peak / CONFIG.escapeSpeed) * 25;
  return score;
}

function chooseAim(game) {
  let best = [1, 0], bs = -1e9;
  for (let i = 0; i < 24; i++) {
    const a = (i / 24) * TAU + game.rng() * 0.1;
    const sc = scoreDir(game, Math.cos(a), Math.sin(a));
    if (sc > bs) { bs = sc; best = [Math.cos(a), Math.sin(a)]; }
  }
  return best;
}

const GOD = process.argv.includes('god');

function runOnce(seed, log) {
  const game = createGame({ seed });
  game.debug.autoOffer = 'better';
  game.debug.invincible = GOD;
  const dt = 1 / 30;
  let holdT = 0;
  const rows = [];
  const per = {};
  let lastKills = 0, lastT = 0, lastHp = game.ship.hp;
  let pierceSamples = [];
  let bounces = 0, hurt = 0;
  while (game.state === 'play') {
    const ph = getPhase(game.t).id;
    const P = (per[ph] ||= { kills: 0, dashes: 0, pierce: 0, maxPierce: 0, bounces: 0, hurt: 0, alive: 0, samples: 0 });
    holdT += dt;
    const need = game.stats.chargeTime * game.stats.gaugeMax + 0.03;
    let input;
    if (holdT >= need) {
      const [ax, ay] = chooseAim(game);
      P.dashes++;
      P.pierce += game.dashPierce;
      P.maxPierce = Math.max(P.maxPierce, game.dashPierce);
      input = { charging: false, aimX: ax * 100, aimY: ay * 100, release: true };
      holdT = 0;
    } else {
      input = { charging: true, aimX: 100, aimY: 0, release: false };
    }
    const k0 = game.kills;
    update(game, dt, input);
    P.kills += game.kills - k0;
    for (const e of game.events) {
      if (e.type === 'bounce') P.bounces++;
      if (e.type === 'hurt') { P.hurt += e.amount; (P.causes ||= {})[e.cause] = ((P.causes[e.cause]) || 0) + e.amount; }
    }
    game.events.length = 0;
    P.alive += game.enemies.length; P.samples++;
    if (game.t - lastT >= 30 || game.state !== 'play') {
      const L = Object.values(game.loadout).filter(Boolean).map((m) => `${moduleDef(m.id).name}${'★'.repeat(m.r)}`).join(' ');
      rows.push(`${String(Math.round(game.t)).padStart(3)}s コア${game.cores} ${getPhase(game.t).name.padEnd(5, '　')} 敵${String(game.enemies.length).padStart(4)} 撃破+${String(game.kills - lastKills).padStart(4)} Lv${String(game.level).padStart(3)} 上限${kms(game.stats.maxSpeed)} 最高${kms(game.peakSpeed)} HP${Math.round(game.ship.hp)}/${Math.round(game.stats.maxHp)} | ${L}`);
      lastKills = game.kills; lastT = game.t;
    }
  }
  if (log) console.log(rows.join('\n'));
  if (log) for (const [id, P] of Object.entries(per)) console.log(id, Object.entries(P.causes || {}).map(([k, v]) => `${k}:${Math.round(v)}`).join(' '));
  return { game, per };
}

const runs = Number(process.argv[2] || 3);
const seed0 = Number(process.argv[3] || 1);
const agg = {};
const results = [];
for (let i = 0; i < runs; i++) {
  const { game, per } = runOnce(seed0 + i, i === 0);
  results.push(`seed ${seed0 + i}: ${game.state} (${game.endReason}) t=${game.t.toFixed(0)} 最高${kms(game.peakSpeed)} 撃破${game.kills} Lv${game.level} 部品${Math.round(game.coins)}`);
  for (const [id, P] of Object.entries(per)) {
    const A = (agg[id] ||= { kills: 0, dashes: 0, pierce: 0, maxPierce: 0, bounces: 0, hurt: 0, alive: 0, samples: 0, runs: 0 });
    for (const k of Object.keys(P)) if (k !== 'causes') A[k] = k === 'maxPierce' ? Math.max(A[k], P[k]) : A[k] + P[k];
    A.runs++;
  }
}
console.log('\n' + results.join('\n'));
console.log('\nフェーズ別（平均）');
for (const p of PHASES) {
  const A = agg[p.id];
  if (!A) continue;
  const secs = (p.end - p.start);
  console.log(`${p.name.padEnd(6, '　')} 撃破/秒 ${(A.kills / A.runs / secs).toFixed(2).padStart(5)}  貫通/突進 ${(A.pierce / Math.max(1, A.dashes)).toFixed(1).padStart(4)} (最大${A.maxPierce})  弾かれ ${(A.bounces / A.runs).toFixed(0).padStart(3)}  被ダメ ${(A.hurt / A.runs).toFixed(0).padStart(4)}  平均敵数 ${(A.alive / A.samples).toFixed(0)}`);
}
