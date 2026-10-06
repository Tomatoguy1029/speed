// Level-up choices: weapons that grow with level-ups (Vampire Survivors style) and stackable perks
// that change how hyperdrive plays. Every level-up offers three of them.
import { CONFIG } from './config.js';
import { isHyperScheme } from './controls.js';

export const PERK_MAX = 5; // each perk can be taken up to this many times

// Blaster: cumulative stats per weapon level (index = level - 1).
export const GUN_LEVELS = [
  { dmg: 1, rate: 1, shots: 1, pierce: 0, text: '進行方向へ弾を撃つ' },
  { dmg: 1.3, rate: 1, shots: 1, pierce: 0, text: '威力 +30%' },
  { dmg: 1.3, rate: 1, shots: 2, pierce: 0, text: '弾 +1' },
  { dmg: 1.3, rate: 1.3, shots: 2, pierce: 0, text: '連射 +30%' },
  { dmg: 1.3, rate: 1.3, shots: 2, pierce: 1, text: '貫通 +1' },
  { dmg: 1.3, rate: 1.3, shots: 3, pierce: 1, text: '弾 +1' },
  { dmg: 1.8, rate: 1.3, shots: 3, pierce: 1, text: '威力 +40%' },
  { dmg: 1.8, rate: 1.6, shots: 3, pierce: 3, text: '貫通 +2、連射 +25%' },
];

export const WEAPONS = [
  { id: 'gun', name: 'ブラスター', levels: GUN_LEVELS },
];

// desc(n): what the perk does with n stacks.
export const PERKS = [
  { id: 'chainBlast', name: '連鎖爆発', hyperOnly: true,
    desc: (n) => `ハイパードライブ中の3回目ごとのジャンプが着地点で爆発（半径 ${perkBlastRadius(n)}、威力 ジャンプ攻撃力×${perkBlastMult(n).toFixed(1)}）` },
  { id: 'killRecharge', name: '撃破充填', hyperOnly: true,
    desc: (n) => `ジャンプ中に倒した敵1体ごとにチャージが ${Math.round(8 * n)}% 溜まる。群れを抜けるほど連鎖が続く` },
  { id: 'fullCharge', name: '満タン突撃', hyperOnly: true,
    desc: (n) => `チャージ満タンから跳んだジャンプは硬い敵にも弾かれず、攻撃力 ×${fullChargePower(n).toFixed(1)}。貯めて待つほど強い一撃` },
  { id: 'crossBlast', name: '交差爆破', hyperOnly: true,
    desc: (n) => `同じハイパードライブ中に自分のジャンプの線を横切ると、交点が爆発（半径 ${120 + 25 * n}、威力 ジャンプ攻撃力×${(0.8 + 0.4 * n).toFixed(1)}）` },
  { id: 'vortex', name: '余韻の渦', hyperOnly: true,
    desc: (n) => `ジャンプの着地点に渦が残り、${vortexLife(n).toFixed(1)}秒間 半径${vortexRadius(n)}の敵を引き寄せる。次のジャンプでまとめて貫く` },
  { id: 'extraCell', name: '予備セル', hyperOnly: true,
    desc: (n) => `チャージの最大数 +${n}（合計 ${CONFIG.hyperMaxCharges + n}）` },
  { id: 'quickCell', name: '急速充填', hyperOnly: true,
    desc: (n) => `チャージの充填時間 -${Math.round((1 - Math.pow(0.85, n)) * 100)}%` },
];

const PERK_BY_ID = Object.fromEntries(PERKS.map((p) => [p.id, p]));
const WEAPON_BY_ID = Object.fromEntries(WEAPONS.map((w) => [w.id, w]));

export function perkLevel(game, id) {
  return game.perks[id] || 0;
}

export function perkBlastRadius(n) { return 150 + 30 * (n - 1); }
export function perkBlastMult(n) { return 1.2 + 0.6 * (n - 1); }
export function fullChargePower(n) { return 1.5 + 0.5 * (n - 1); }
export function vortexRadius(n) { return 220 + 30 * (n - 1); }
export function vortexLife(n) { return 1.5 + 0.3 * (n - 1); }

// Three different choices: weapon upgrades are a little more likely than any single perk.
export function rollLevelChoices(game) {
  const pool = [];
  for (const w of WEAPONS) {
    const lv = game.weapons[w.id] || 0;
    if (lv < w.levels.length) pool.push({ kind: 'weapon', id: w.id, level: lv + 1, weight: 1.6 });
  }
  for (const p of PERKS) {
    if (p.hyperOnly && !isHyperScheme(game.scheme)) continue;
    const n = perkLevel(game, p.id);
    if (n < PERK_MAX) pool.push({ kind: 'perk', id: p.id, level: n + 1, weight: 1 });
  }
  const out = [];
  while (out.length < 3 && pool.length) {
    let roll = game.rng() * pool.reduce((a, c) => a + c.weight, 0);
    let i = 0;
    while (i < pool.length - 1 && roll >= pool[i].weight) { roll -= pool[i].weight; i++; }
    out.push(pool.splice(i, 1)[0]);
  }
  if (out.length < 3) out.push({ kind: 'heal', id: 'repair', level: 1 });
  return out;
}

// Card text for a choice.
export function choiceInfo(c) {
  if (c.kind === 'weapon') {
    const w = WEAPON_BY_ID[c.id];
    return { tag: c.level === 1 ? '新しい武器' : '武器強化', name: `${w.name} Lv${c.level}`, desc: w.levels[c.level - 1].text };
  }
  if (c.kind === 'perk') {
    const p = PERK_BY_ID[c.id];
    return { tag: c.level === 1 ? '新しい特性' : '特性強化', name: `${p.name}${c.level > 1 ? ` ×${c.level}` : ''}`, desc: p.desc(c.level) };
  }
  return { tag: '回復', name: '緊急修理', desc: 'HP を 30% 回復' };
}

export function applyLevelChoice(game, c) {
  if (c.kind === 'weapon') game.weapons[c.id] = c.level;
  else if (c.kind === 'perk') game.perks[c.id] = c.level;
  else game.ship.hp = Math.min(game.stats.maxHp, game.ship.hp + game.stats.maxHp * 0.3);
}

// The current build, for the level-up screen.
export function buildSummary(game) {
  const out = [];
  for (const w of WEAPONS) if (game.weapons[w.id]) out.push(`${w.name} Lv${game.weapons[w.id]}`);
  for (const p of PERKS) if (game.perks[p.id]) out.push(`${p.name}${game.perks[p.id] > 1 ? ` ×${game.perks[p.id]}` : ''}`);
  return out;
}

// Blaster: fires along the ship's heading (the last travel direction when stopped). Runs on world time,
// so it keeps firing (slowly) in hyperdrive's slow motion, but not during a jump itself.
// Damage comes from stats (attack multiplier: level, modules, station), not from speed.
export function updateGun(game, dt) {
  const lv = game.weapons.gun || 0;
  if (!lv || game.jump || game.portalDash) return;
  const L = GUN_LEVELS[lv - 1];
  game.gunT += dt;
  const interval = 1 / (CONFIG.gunRate * L.rate);
  if (game.gunT < interval) return;
  game.gunT = 0;
  const sh = game.ship;
  const base = Math.atan2(sh.hy, sh.hx);
  const dmg = CONFIG.gunDamage * L.dmg * game.stats.atkMult;
  for (let i = 0; i < L.shots; i++) {
    const a = base + (i - (L.shots - 1) / 2) * CONFIG.gunSpread;
    game.fbullets.push({ kind: 'gun', x: sh.x, y: sh.y, vx: Math.cos(a) * CONFIG.gunSpeed + sh.vx, vy: Math.sin(a) * CONFIG.gunSpeed + sh.vy,
      r: 5, dmg, life: CONFIG.gunLife, pierce: false, pierceLeft: L.pierce, hit: new Set(), color: '#ffe46b' });
  }
  game.events.push({ type: 'turret' });
}
