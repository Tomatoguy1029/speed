import { isHyperScheme } from './controls.js';
import { baseStats } from './ship.js';
import { pickWeighted } from './math.js';
import { CONFIG } from './config.js';

export const SLOTS = [
  { id: 'bow', name: '船首', icon: '▲' },
  { id: 'booster', name: 'ブースター', icon: '»' },
  { id: 'gun', name: '銃', icon: '✶' },
  { id: 'radar', name: 'レーダー', icon: '◎' },
  { id: 'armor', name: '装甲', icon: '■' },
  { id: 'gen', name: 'ジェネレーター', icon: 'ϟ' },
];

export const RARITIES = [
  { name: 'コモン', color: '#b8c4d6' },
  { name: 'レア', color: '#4fa3ff' },
  { name: 'エピック', color: '#c46bff' },
  { name: 'レジェンド', color: '#ffb340' },
];

export const RARITY_MULT = [1, 1.6, 2.4, 3.5];

const ALL = [0, 1, 2, 3];
const pct = (v) => `${Math.round(v * 100)}%`;
const M = (r) => RARITY_MULT[r];

export const MODULES = [
  // 船首: 貫通と衝突時の効果
  { id: 'ram', slot: 'bow', name: '衝角強化', rarities: ALL,
    desc: (r) => `攻撃力 +${pct(0.25 * M(r))}`,
    apply: (s, m) => { s.atkMult *= 1 + 0.25 * m; } },
  { id: 'piercer', slot: 'bow', name: '貫通弾頭', rarities: ALL,
    desc: (r) => `貫通時の減速 -${pct(1 - 1 / (1 + M(r)))}、攻撃力 +${pct(0.08 * M(r))}`,
    apply: (s, m) => { s.pierceLossMult /= 1 + m; s.atkMult *= 1 + 0.08 * m; } },
  { id: 'burstHead', slot: 'bow', name: '炸裂弾頭', rarities: ALL,
    desc: (r) => `1回の突進で ${Math.max(2, 6 - r)} 体以上貫くと、突進の終点で大爆発（半径 ${Math.round(220 * (1 + 0.25 * r))}）`,
    apply: (s, m, r) => { s.endBlast = { min: Math.max(2, 6 - r), radius: 220 * (1 + 0.25 * r), mult: 0.9 * m }; } },
  { id: 'flinger', slot: 'bow', name: '吹き飛ばし衝角', rarities: ALL,
    desc: (r) => `倒した敵が弾丸となって吹き飛び、周りの敵を巻き込む（威力 ${pct(0.5 * M(r))}）`,
    apply: (s, m) => { s.fling = 0.5 * m; } },
  { id: 'weakHunter', slot: 'bow', name: '弱点特攻', rarities: ALL,
    desc: (r) => `クリティカル倍率 +${M(r).toFixed(1)}、弱点の範囲 +${pct(0.15 * M(r))}`,
    apply: (s, m) => { s.critMult += m; s.weakArcMult *= 1 + 0.15 * m; } },

  // ブースター: 最高速度と加速
  { id: 'thruster', slot: 'booster', name: '高出力スラスター', rarities: ALL,
    desc: (r) => `最高速度 +${pct(0.12 * M(r))}`,
    apply: (s, m) => { s.maxSpeed *= 1 + 0.12 * m; } },
  { id: 'inertia', slot: 'booster', name: '慣性保持ノズル', rarities: ALL,
    desc: (r) => `突進後の減速が遅く、勢いの持ち越し +${pct(0.06 * M(r))}、最高速度 +${pct(0.04 * M(r))}`,
    apply: (s, m) => { s.boostDuration *= 1 + 0.5 * m; s.carry = Math.min(0.95, s.carry + 0.06 * m); s.maxSpeed *= 1 + 0.04 * m; } },
  { id: 'reflector', slot: 'booster', name: '反射スラスター', rarities: ALL,
    desc: (r) => `弾かれても勢いを ${pct(Math.min(1, 0.8 + 0.06 * r))} 保つ、弾かれ時の被ダメ -${pct(1 - 0.7 / Math.sqrt(M(r)))}、最高速度 +${pct(0.05 * M(r))}`,
    apply: (s, m, r) => { s.bounceKeep = Math.min(1, 0.8 + 0.06 * r); s.bounceDamageMult *= 0.7 / Math.sqrt(m); s.maxSpeed *= 1 + 0.05 * m; s.reflect = true; } },
  { id: 'slipstream', slot: 'booster', name: 'スリップストリーム', rarities: ALL, schemeOnly: 'hyper',
    desc: (r) => `同じ方向（±${CONFIG.streakAngle}°）へ続けてジャンプするたびに速度 +${pct(0.15 * M(r))}（最大 ${CONFIG.streakMax} 段。速度＝攻撃力）。${CONFIG.streakWindow} 秒途切れるか向きを変えるとリセット`,
    apply: (s, m) => { s.streakBoost = 0.15 * m; } },
  { id: 'quickTrace', slot: 'booster', name: '高速トレーサー', rarities: ALL, hyperOnly: true,
    desc: (r, scheme) => `${scheme === 'portal' ? '経路を駆け抜ける速さ' : 'ジャンプの速さ'} +${pct(0.3 * M(r))}、最高速度 +${pct(0.04 * M(r))}`,
    apply: (s, m) => { s.traceSpeedMult *= 1 + 0.3 * m; s.maxSpeed *= 1 + 0.04 * m; } },
  { id: 'limiter', slot: 'booster', name: 'リミッター解除', rarities: [2, 3], minTime: 480,
    desc: (r) => `最高速度 +${pct(0.18 * M(r))}。脱出のための出力`,
    apply: (s, m) => { s.maxSpeed *= 1 + 0.18 * m; } },

  // 銃: 突進以外の攻撃
  { id: 'trailBurst', slot: 'gun', name: '軌跡炸裂', rarities: ALL,
    desc: (r) => `突進で通った軌跡が遅れて爆ぜる（威力 ${pct(0.35 * M(r))}）`,
    apply: (s, m) => { s.trailBurst = 0.35 * m; } },
  { id: 'loopBurst', slot: 'gun', name: '包囲炸裂', rarities: [2, 3], portalOnly: true,
    desc: (r) => `通過軌跡が閉じると、内側の敵が一斉に爆発（装甲無視・威力 ${pct(CONFIG.portalLoopDamage * M(r))}）${r === 3 ? `。敵の爆発が半径${CONFIG.portalLoopSplashRadius}の周囲にも波及` : ''}`,
    apply: (s, m, r) => { s.loopBurst = { mult: CONFIG.portalLoopDamage * m, splash: r === 3 }; } },
  { id: 'chargeWave', slot: 'gun', name: 'チャージ衝撃波', rarities: ALL, portalExcluded: true,
    desc: (r) => `チャージ中、0.5 秒ごとに周囲へ衝撃波（半径 ${Math.round(170 * (1 + 0.25 * r))}）`,
    apply: (s, m, r) => { s.chargeWave = { mult: 0.5 * m, radius: 170 * (1 + 0.25 * r) }; } },
  { id: 'turret', slot: 'gun', name: '自動砲台', rarities: ALL,
    desc: (r) => `近くの敵を自動で撃つ（${(1.6 * M(r)).toFixed(1)} 発/秒）`,
    apply: (s, m) => { s.turret = m; } },
  { id: 'waveAmp', slot: 'gun', name: '波動増幅器', rarities: ALL, hyperOnly: true,
    desc: (r) => `軌跡から出る波動の届く距離 +${pct(0.25 * M(r))}、威力 +${pct(0.3 * M(r))}`,
    apply: (s, m) => { s.waveRadiusMult *= 1 + 0.25 * m; s.waveDmgMult *= 1 + 0.3 * m; } },
  { id: 'tsunami', slot: 'gun', name: '大波動', rarities: [2, 3], minTime: 420, hyperOnly: true,
    desc: (r) => `軌跡の波動が届く距離 ×${(1 + 0.9 * M(r)).toFixed(1)}、威力 ×${(1 + 0.8 * M(r)).toFixed(1)}。群れをまとめて消し飛ばす`,
    apply: (s, m) => { s.waveRadiusMult *= 1 + 0.9 * m; s.waveDmgMult *= 1 + 0.8 * m; } },
  { id: 'mines', slot: 'gun', name: '機雷投下', rarities: ALL,
    desc: (r) => `最高速度の 60% 以上で機雷をばらまく（威力 ${pct(0.6 * M(r))}）`,
    apply: (s, m) => { s.mines = 0.6 * m; } },

  // レーダー: 読みの補助
  { id: 'portalPulse', slot: 'radar', name: '共振ビーコン', rarities: ALL, portalOnly: true,
    desc: (r) => `ポータル到着時に波動で周囲を吹き飛ばす（半径 ${CONFIG.portalWaveRadius}、威力 ${pct(CONFIG.portalWaveDamage * M(r))}）`,
    apply: (s, m) => { s.portalWave = m; } },
  { id: 'scope', slot: 'radar', name: '長距離予測', rarities: ALL,
    desc: (r) => `予測線 +${(0.6 * M(r)).toFixed(1)} 秒、回収範囲 +10%`,
    apply: (s, m) => { s.predictTime += 0.6 * m; s.pickupRadius *= 1.1; } },
  { id: 'bounceScope', slot: 'radar', name: '反射予測', rarities: ALL,
    desc: (r) => `予測線が反射先まで見える、予測線 +${(0.3 * M(r)).toFixed(1)} 秒`,
    apply: (s, m) => { s.predictBounce = true; s.predictTime += 0.3 * m; s.weakArcMult *= 1 + 0.05 * m; } },
  { id: 'weakScan', slot: 'radar', name: '弱点スキャナ', rarities: ALL,
    desc: (r) => `弱点の範囲 +${pct(0.25 * M(r))}、クリティカル倍率 +${(0.3 * M(r)).toFixed(1)}`,
    apply: (s, m) => { s.weakArcMult *= 1 + 0.25 * m; s.critMult += 0.3 * m; } },
  { id: 'magnet', slot: 'radar', name: '回収ビーコン', rarities: ALL,
    desc: (r) => `回収範囲 +${pct(0.5 * M(r))}、経験値 +${pct(0.08 * M(r))}`,
    apply: (s, m) => { s.pickupRadius *= 1 + 0.5 * m; s.xpMult *= 1 + 0.08 * m; } },

  // 装甲: 耐久
  { id: 'plating', slot: 'armor', name: '複合装甲', rarities: ALL,
    desc: (r) => `最大 HP +${Math.round(30 * M(r))}`,
    apply: (s, m) => { s.maxHp += 30 * m; } },
  { id: 'absorber', slot: 'armor', name: '衝撃吸収材', rarities: ALL,
    desc: (r) => `被ダメージ -${pct(1 - 1 / (1 + 0.3 * M(r)))}、被弾時の減速 -${pct(1 - 1 / (1 + 0.6 * M(r)))}`,
    apply: (s, m) => { s.damageTakenMult /= 1 + 0.3 * m; s.hitSlowMult /= 1 + 0.6 * m; } },
  { id: 'repair', slot: 'armor', name: '自己修復', rarities: ALL,
    desc: (r) => `HP を毎秒 ${(0.8 * M(r)).toFixed(1)} 回復`,
    apply: (s, m) => { s.regen += 0.8 * m; } },
  { id: 'reactive', slot: 'armor', name: '反応装甲', rarities: ALL,
    desc: (r) => `被弾すると周囲に衝撃波（威力 ${pct(1.2 * M(r))}）、最大 HP +${Math.round(10 * M(r))}`,
    apply: (s, m) => { s.reactive = 1.2 * m; s.maxHp += 10 * m; } },

  // ジェネレーター: エネルギーとチャージ
  { id: 'quickCharge', slot: 'gen', name: '高速チャージャ', rarities: ALL, portalExcluded: true,
    desc: (r, scheme) => `${scheme === 'hyper' ? 'ジャンプの充填時間' : 'チャージ時間'} -${pct(1 - 1 / (1 + 0.35 * M(r)))}`,
    apply: (s, m) => { s.chargeTime /= 1 + 0.35 * m; } },
  { id: 'overcharge', slot: 'gen', name: '過充填コンデンサ', rarities: ALL,
    desc: (r, scheme) => scheme === 'portal' ? `突進出力・到達距離・総移動距離 +${pct(0.15 * M(r))}` : scheme === 'hyper' ? `ジャンプの出力 ${pct(1 + 0.15 * M(r))}。最高速度を超えて突っ込む` : `ゲージ上限 ${pct(1 + 0.15 * M(r))}。溜めきると最高速度を超えて突進`,
    apply: (s, m) => { s.gaugeMax = 1 + 0.15 * m; } },
  // not in hyperdrive: refilling jumps on hits allowed endless dashing
  { id: 'regenGen', slot: 'gen', name: '回生ジェネレーター', rarities: ALL, portalExcluded: true, hyperExcluded: true,
    desc: (r) => `敵を貫くたびに次のゲージが ${pct(0.1 * M(r))} 溜まる、チャージ時間 -8%`,
    apply: (s, m) => { s.regenGauge = 0.1 * m; s.chargeTime *= 0.92; } },
  { id: 'longTrail', slot: 'gen', name: '軌跡延長コイル', rarities: ALL, hyperOnly: true,
    desc: (r, scheme) => `${scheme === 'portal' ? 'ポータルの到達距離・総移動距離' : 'ジャンプの届く距離'} +${pct(0.25 * M(r))}`,
    apply: (s, m) => { s.rangeMult *= 1 + 0.25 * m; } },
  { id: 'trailOverdrive', slot: 'gen', name: '軌跡オーバードライブ', rarities: [2, 3], minTime: 420, hyperOnly: true,
    desc: (r, scheme) => `${scheme === 'portal' ? 'ポータルの到達距離・総移動距離' : 'ジャンプの届く距離'} ×${(1 + 0.8 * M(r)).toFixed(1)}。画面中を駆けめぐれる`,
    apply: (s, m) => { s.rangeMult *= 1 + 0.8 * m; } },
  { id: 'sonicS', slot: 'gen', name: 'ソニックブーム（小）', rarities: [1, 2], minTime: 240,
    desc: (r) => `最高速度の 92% を超えた瞬間、衝撃波で周囲を吹き飛ばす（半径 ${Math.round(420 * (1 + 0.15 * r))}）`,
    apply: (s, m, r) => { s.sonic = { radius: 420 * (1 + 0.15 * r), mult: 2 * m }; } },
  { id: 'sonicL', slot: 'gen', name: 'ソニックブーム（大）', rarities: [2, 3], minTime: 360,
    desc: (r) => `最高速度の 92% を超えた瞬間、巨大な衝撃波で一掃する（半径 ${Math.round(950 * (1 + 0.15 * (r - 2)))}）`,
    apply: (s, m, r) => { s.sonic = { radius: 950 * (1 + 0.15 * (r - 2)), mult: 3.5 * m }; } },
];

const BY_ID = Object.fromEntries(MODULES.map((m) => [m.id, m]));

export function moduleDef(id) {
  return BY_ID[id];
}

// bonus.cores: power cores collected this run; bonus.level: current level. Both raise max speed.
export function computeStats(meta, loadout, bonus = {}) {
  const s = baseStats(meta);
  for (const slot of SLOTS) {
    const mod = loadout[slot.id];
    if (mod) BY_ID[mod.id].apply(s, RARITY_MULT[mod.r] * (1 + CONFIG.dupBonus * (mod.plus || 0)), mod.r);
  }
  const lv = bonus.level || 0;
  s.maxSpeed *= (1 + CONFIG.coreBoost * (bonus.cores || 0)) * (1 + CONFIG.levelSpeedGrowth * lv);
  s.atkMult *= 1 + CONFIG.levelAtkGrowth * lv;
  s.maxHp += CONFIG.levelHpGrowth * lv;
  s.chargeTime *= Math.max(0.6, 1 - CONFIG.levelChargeGrowth * lv);
  return s;
}

function rarityWeights(ctx) {
  if (ctx.source === 'core') return [0, 0, 1, 2];
  if (ctx.source === 'capsule') {
    const d = ctx.danger || 0;
    return [6 * (1 - d), 3 + d, 0.6 + 4 * d, 2.4 * d * d];
  }
  if (ctx.source === 'drop') {
    // stronger enemies (power = their xp: type x level x elite) drop rarer modules
    const d = Math.max(Math.min(1, ((ctx.power || 1) - 1) / 20), (ctx.danger || 0) * 0.6);
    return [6 * (1 - d), 3 + d, 0.6 + 4 * d, 2.4 * d * d];
  }
  const t = ctx.t;
  if (t < 150) return [7, 2.5, 0.5, 0];
  if (t < 300) return [5, 4, 1.2, 0.1];
  if (t < 480) return [3, 4, 2.5, 0.4];
  return [1.5, 3, 4, 1.2];
}

export function rollModule(rng, ctx) {
  const t = ctx.t || 0;
  const loadout = ctx.loadout;
  let slot;
  let pool;
  if (ctx.source === 'core') {
    slot = 'booster';
    pool = [BY_ID.limiter];
  } else {
    slot = pickWeighted(rng, SLOTS.map((s) => {
      const cur = loadout[s.id];
      let w = 1 + (cur ? (3 - cur.r) * 0.25 : 1.2);
      if (s.id === ctx.lastSlot) w *= 0.35;
      return [s.id, w];
    }));
    pool = MODULES.filter((m) => m.slot === slot && (m.minTime || 0) <= t
      && (!m.hyperOnly || !ctx.scheme || isHyperScheme(ctx.scheme) || ctx.scheme === 'portal')
      && (!m.portalOnly || ctx.scheme === 'portal')
      && (!m.portalExcluded || ctx.scheme !== 'portal')
      && (!m.hyperExcluded || !isHyperScheme(ctx.scheme))
      && (!m.schemeOnly || ctx.scheme === m.schemeOnly));
  }
  const rw = rarityWeights(ctx);
  const r = pickWeighted(rng, rw.map((w, i) => [i, w]));
  const fits = pool.filter((m) => m.rarities.includes(r));
  if (fits.length) {
    const def = fits[Math.floor(rng() * fits.length)];
    return { id: def.id, slot, r };
  }
  const def = pool[Math.floor(rng() * pool.length)];
  const nearest = def.rarities.reduce((a, b) => (Math.abs(b - r) < Math.abs(a - r) ? b : a));
  return { id: def.id, slot, r: nearest };
}
