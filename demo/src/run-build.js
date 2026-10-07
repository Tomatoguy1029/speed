// The draw prototype's run build. Experimental items remain outside the regular level-up pool.
import { CONFIG } from './config.js';
import { baseStats } from './ship.js';

export const RUN_WEAPONS = [
  { id: 'forward', catalog: 'W01', name: 'ブラスター', normal: true, desc: '進行方向へ自動射撃。Lvで威力・連射・弾数・貫通が伸びる' },
  { id: 'scatter', catalog: 'W02', name: '散弾砲', normal: true, desc: '進行方向へ扇状の散弾。群れに向けて進むとまとめて当たる' },
  { id: 'knockback', catalog: 'W03', name: '吹き飛ばし衝角', normal: true, desc: '高速接触で敵の船体を進行方向へ吹き飛ばす。他の敵にぶつかると連鎖ダメージ' },
  { id: 'contactWave', catalog: 'W04', name: '接触波動', normal: true, desc: '高速で敵に接触するたび波動。弾かれた接触でも発動' },
  { id: 'barrier', catalog: 'W05', name: 'バリアシステム', normal: true, desc: '周囲の敵へ周期ダメージ、敵弾を遮断。Lvで範囲・威力・遮断頻度が伸びる' },
  { id: 'drone', catalog: 'W06', name: '追走ドローン', normal: true, desc: '周囲を飛ぶドローンが敵へ自動射撃。高速移動では遅れて同じ経路を追い、触れた敵も攻撃' },
  { id: 'mines', catalog: 'W07', name: '軌跡機雷', normal: true, desc: '高速で実際に通った経路に機雷を残す。遅れて入る敵を爆破' },
  { id: 'sonic', catalog: 'W08', name: 'ソニックブーム', normal: true, desc: '高速攻撃の開始時に広範囲の衝撃波。0.5秒間、機体とともに進路を掃く。通常移動でも周期発動' },
  { id: 'contactArc', catalog: 'W17', name: '接触電撃', normal: true, desc: '敵に触れると電撃が近くの敵へ伝播。通常接触でも高速接触でも発動。Lvごとに連鎖数が増える' },
  { id: 'massTow', catalog: 'W21', name: '質量牽引砲', group: '隕石限定', exclusive: true, desc: '高速攻撃で倒した船体を大型敵ごと牽引。経路終了後、進行方向へ順番に高速発射し、弾が尽きるまで撃ち続ける' },
  { id: 'bipolar', catalog: 'W22', name: '双極ビーム', group: '隕石限定', exclusive: true, desc: '高速攻撃の開始点に発射器を残し、経路終了時に自機との間を太いビームで貫く。迂回した群れも直線で一掃' },
  { id: 'orbit', catalog: 'W09', name: 'オービットブレード', group: '保留', desc: '自機を回る刃で接触攻撃。通常抽選には出ない' },
  { id: 'disc', catalog: 'W10', name: 'リターンディスク', group: '保留', desc: '敵に向けて投げ、戻る貫通刃。通常抽選には出ない' },
  { id: 'missile', catalog: 'W11', name: '追尾ミサイル', group: '保留', desc: '敵を追尾し、着弾時に爆発。通常抽選には出ない' },
  { id: 'arc', catalog: 'W12', name: 'アークコイル', group: '保留', desc: '近くの敵から敵へ稲妻が連鎖。通常抽選には出ない' },
  { id: 'turret', catalog: 'W13', name: '自動砲台', group: '既存候補', desc: '最寄りの敵へ自動射撃' },
  { id: 'nova', catalog: 'W14', name: 'パルスノヴァ', group: '既存候補', desc: '自機中心に周期衝撃波' },
  { id: 'laser', catalog: 'W15', name: 'レーザーランス', group: '既存候補', desc: '最寄りの敵へ貫通ビーム' },
  { id: 'trailBurst', catalog: 'W16', name: '軌跡炸裂', group: '既存候補', desc: '高速で通った位置が遅れて爆発' },
];

export const RUN_TRAITS = [
  { id: 'endBlast', catalog: 'T01', name: '終端爆縮', normal: true, desc: n => `高速移動の終点で爆発。半径${180 + n * 30}、威力×${(1 + n * 0.5).toFixed(1)}` },
  { id: 'crossBlast', catalog: 'T02', name: '交差爆破', normal: true, desc: n => `過去${CONFIG.pathMemoryTime}秒の高速軌跡を横切ると交点で爆発。半径${100 + n * 25}、威力×${(0.8 + n * 0.4).toFixed(1)}` },
  { id: 'vortex', catalog: 'T03', name: '余韻の渦', normal: true, desc: n => `終点に${(1.5 + n * 0.4).toFixed(1)}秒の渦。半径${180 + n * 35}の敵を引き寄せる` },
  { id: 'fullCharge', catalog: 'T04', name: '満タン突撃', normal: true, desc: n => `満タン発動の経路移動中は装甲を無視し、攻撃力×${(1.25 + n * 0.25).toFixed(2)}。部分充填での通常発動には適用しない` },
  { id: 'killSonic', catalog: 'T05', name: '連鎖ソニック', normal: true, desc: n => `1回の高速攻撃中に${Math.max(3, 9 - n)}体倒すたびソニックブーム。半径${CONFIG.killSonicRadius + n * CONFIG.killSonicRadiusPerStack}、威力×${(CONFIG.killSonicDamage + n * CONFIG.killSonicDamagePerStack).toFixed(1)}` },
  { id: 'critBeam', catalog: 'T06', name: 'クリティカルランス', normal: true, desc: n => `クリティカル時に突進方向へ貫通ビーム。射程${CONFIG.lanceLength + n * CONFIG.lanceLengthPerStack}、威力×${(CONFIG.lanceDamage + n * CONFIG.lanceDamagePerStack).toFixed(1)}。ビームからは再発動しない` },
  { id: 'quickCharge', catalog: 'T07', name: '急速充填', normal: true, desc: n => `時間チャージの充填速度 +${n * 25}%` },
  { id: 'capacity', catalog: 'T08', name: '大容量チャージ', normal: true, desc: n => `チャージ容量 +${n * 20}%。満タンまでの時間と描ける長さが伸びる（回数ストックではない）` },
  { id: 'critRate', catalog: 'T09', name: 'クリティカル率', normal: true, desc: n => `クリティカル率 +${n * 8}%（基礎${Math.round(CONFIG.baseCritChance * 100)}%）。弱点方向を狙う必要はない` },
  { id: 'speed', catalog: 'T10', name: '最高速度', normal: true, desc: n => `最高速度 +${n * 12}%。攻撃力とは独立` },
  { id: 'attack', catalog: 'T11', name: '攻撃力', normal: true, desc: n => `全攻撃の攻撃力倍率 +${n * 20}%` },
  { id: 'pickup', catalog: 'T12', name: '広域回収', normal: true, desc: n => `回収範囲 +${n * 30}%` },
  { id: 'reactive', catalog: 'T13', name: '反応波動', normal: true, desc: n => `被弾時に半径${170 + n * 30}へ衝撃波。威力×${(0.8 + n * 0.4).toFixed(1)}` },
  { id: 'length', catalog: 'T14', name: '軌跡延長', normal: true, desc: n => `描ける軌跡の長さ +${n * 25}%` },
  { id: 'wave', catalog: 'T15', name: '波動増幅', group: '既存候補', desc: n => `軌跡の波動範囲 +${n * 25}%、威力 +${n * 30}%` },
  { id: 'loop', catalog: 'T16', name: '包囲炸裂', group: '既存候補', desc: n => `高速軌跡で囲んだ敵へ威力×${(1 + n * 0.6).toFixed(1)}の爆発。3重ね以上では周囲へも波及` },
  { id: 'traceSpeed', catalog: 'T17', name: '高速トレーサー', group: '既存候補', desc: n => `経路の実行速度 +${n * 25}%` },
  { id: 'hp', catalog: 'T18', name: '複合装甲', group: '既存候補', desc: n => `最大HP +${n * 25}` },
  { id: 'guard', catalog: 'T19', name: '衝撃吸収', group: '既存候補', desc: n => `被ダメージ・被弾時の減速を${Math.round((1 - 1 / (1 + n * 0.2)) * 100)}%軽減` },
  { id: 'regen', catalog: 'T20', name: '自己修復', group: '既存候補', desc: n => `毎秒HPを${(n * 0.8).toFixed(1)}回復` },
  { id: 'reflect', catalog: 'T21', name: '反射スラスター', group: '既存候補', desc: n => `弾かれた際の速度を${Math.min(95, 65 + n * 6)}%保持し、衝突ダメージ軽減` },
  { id: 'pierce', catalog: 'T22', name: '貫通弾頭', group: '既存候補', desc: n => `高速接触の装甲判定を${Math.round((1 - 1 / (1 + n * 0.2)) * 100)}%緩和（軌跡移動の減速軽減は不要）` },
  { id: 'inertia', catalog: 'T23', name: '慣性保持', group: '既存候補', desc: n => `衝突後の加速持続 +${n * 30}%、突進への速度持ち越し +${n * 5}%` },
  { id: 'recovery', catalog: 'T24', name: '回生充填', group: '既存候補', desc: n => `高速貫通のたびチャージ容量の${n * 2}%回復` },
];

export function runModuleDef(kind, id) {
  return (kind === 'weapon' ? RUN_WEAPONS : RUN_TRAITS).find(d => d.id === id);
}

export function runItemCount(items) { return Object.values(items).filter(n => n > 0).length; }
export function runTrait(game, id) { return game.traits?.[id] || 0; }

// Compress the original eight performance tiers into five picks, preserving the final build.
export function runWeaponTier(level) {
  return 1 + Math.round((Math.max(1, Math.min(CONFIG.weaponMaxLevel, level)) - 1) * 7 / (CONFIG.weaponMaxLevel - 1));
}

export function runWeaponStats(id, level) {
  const n = runWeaponTier(level) - 1;
  return { damage: 1 + n * 0.3, rate: 1 + n * 0.12, radius: 1 + n * 0.1,
    tier: n + 1,
    shots: id === 'scatter' ? 5 + Math.floor(n / 2) : 1 + Math.floor(n / 3),
    pierce: Math.floor(n / 3), drones: 1 + Math.floor(n / 2) };
}

export function computeRunStats(meta, weapons, traits, bonus = {}) {
  const s = baseStats(meta), n = id => traits[id] || 0;
  s.runBuild = true;
  s.atkMult *= (1 + CONFIG.levelAtkGrowth * (bonus.level || 0)) * (1 + n('attack') * 0.2);
  s.maxSpeed *= (1 + CONFIG.levelSpeedGrowth * (bonus.level || 0)) * (1 + CONFIG.coreBoost * (bonus.cores || 0)) * (1 + n('speed') * 0.12);
  s.maxHp += CONFIG.levelHpGrowth * (bonus.level || 0) + n('hp') * 25;
  s.gaugeMax = 1 + n('capacity') * 0.2;
  s.chargeTime = CONFIG.dashChargeTime * Math.pow(0.95, meta.charge || 0) / (1 + n('quickCharge') * 0.25);
  s.critChance = Math.min(0.9, CONFIG.baseCritChance + n('critRate') * 0.08);
  s.pickupRadius *= 1 + n('pickup') * 0.3;
  s.drawLengthMult *= 1 + n('length') * 0.25;
  s.traceSpeedMult *= 1 + n('traceSpeed') * 0.25;
  s.waveRadiusMult *= 1 + n('wave') * 0.25;
  s.waveDmgMult *= 1 + n('wave') * 0.3;
  s.damageTakenMult /= 1 + n('guard') * 0.2;
  s.hitSlowMult /= 1 + n('guard') * 0.2;
  s.regen += n('regen') * 0.8;
  s.armorPierceMult = 1 + n('pierce') * 0.2;
  if (n('reflect')) { s.reflect = true; s.bounceKeep = Math.min(0.95, 0.65 + n('reflect') * 0.06); s.bounceDamageMult = 1 / (1 + n('reflect') * 0.2); }
  s.boostDuration *= 1 + n('inertia') * 0.3;
  s.carry = Math.min(0.95, s.carry + n('inertia') * 0.05);
  if (n('loop')) s.loopBurst = { mult: 1 + n('loop') * 0.6, splash: n('loop') >= 3 };
  return s;
}

export function rollRunChoices(game) {
  const pool = [];
  for (const [kind, defs, owned, slots, max] of [
    ['weapon', RUN_WEAPONS, game.weapons, CONFIG.weaponSlots, CONFIG.weaponMaxLevel],
    ['trait', RUN_TRAITS, game.traits, CONFIG.traitSlots, 5],
  ]) {
    const free = runItemCount(owned) < slots;
    for (const d of defs) {
      const lv = owned[d.id] || 0;
      if ((!d.normal && !lv) || lv >= max || (!lv && !free)) continue;
      pool.push({ kind, id: d.id, level: lv + 1, weight: lv ? 1.6 : 1 });
    }
  }
  const out = [];
  while (out.length < 3 && pool.length) {
    let roll = game.rng() * pool.reduce((sum, c) => sum + c.weight, 0), i = 0;
    while (i < pool.length - 1 && roll >= pool[i].weight) { roll -= pool[i].weight; i++; }
    out.push(pool.splice(i, 1)[0]);
  }
  // All remaining eligible items are still shown; healing fills only otherwise empty slots.
  while (out.length < 3) out.push({ kind: 'heal', id: `heal${out.length}`, level: 1 });
  return out;
}

export function runRankColor(level) {
  return ['#d5dbea', '#8ed7a3', '#3989ff', '#bf91ef', '#efcb70'][Math.max(0, Math.min(4, level - 1))];
}

export function runChoiceInfo(c) {
  if (c.kind === 'rareSkip') return { tag: '見送る', name: '今の装備を維持', color: '#9ba7bd', desc: '今回の限定武器は装備せず、現在のビルドで続ける' };
  if (c.kind === 'heal') return { tag: '回復', name: '緊急修理', color: '#6dffb0', desc: 'HPを30%回復（取得・強化できる装備が残り少ない場合）' };
  const d = runModuleDef(c.kind, c.id);
  const suffix = c.kind === 'weapon' ? `Lv${c.level}` : `${c.level}/5`;
  const tag = c.level === 1 ? (c.kind === 'weapon' ? '新しい武器' : '新しい特性') : (c.kind === 'weapon' ? '武器強化' : '特性強化');
  let desc = c.kind === 'weapon' ? d.desc : d.desc(c.level);
  if (c.kind === 'weapon' && c.id === 'contactArc') desc += `。近隣${c.level * 2}体へ伝播、1回の伝播距離240`;
  if (c.kind === 'weapon' && c.level > 1 && (d.normal || d.exclusive || ['turret', 'trailBurst'].includes(c.id))) {
    const before = runWeaponStats(c.id, c.level - 1), after = runWeaponStats(c.id, c.level);
    desc += `。威力 ×${before.damage.toFixed(1)} → ×${after.damage.toFixed(1)}`;
    if (['forward', 'scatter', 'turret'].includes(c.id)) desc += `、弾数${before.shots}→${after.shots}`;
    else if (c.id === 'drone') desc += `、機数${before.drones}→${after.drones}`;
    else if (c.id === 'massTow') desc += `、発射間隔${(CONFIG.massTowInterval / before.rate).toFixed(3)}→${(CONFIG.massTowInterval / after.rate).toFixed(3)}秒`;
    else if (c.id === 'knockback') desc += `、吹き飛ばす速さ${800 + 90 * before.tier}→${800 + 90 * after.tier}`;
    else if (c.id === 'contactArc') desc += `、伝播${2 * (c.level - 1)}→${2 * c.level}体`;
    else desc += `、範囲 ×${before.radius.toFixed(1)} → ×${after.radius.toFixed(1)}`;
  }
  if (c.replace) desc += `。${runModuleDef('weapon', c.replace).name} Lv${c.replaceLevel}と交換`;
  return { tag: c.rare ? (c.replace ? `${runModuleDef('weapon', c.replace).name} Lv${c.replaceLevel}と交換` : '隕石限定武器') : tag, name: `${d.name} ${suffix}`, desc, color: runRankColor(c.level) };
}

export function grantRunItem(game, kind, id, levels = 1) {
  const def = runModuleDef(kind, id);
  if (!def) return false;
  const owned = kind === 'weapon' ? game.weapons : game.traits;
  const max = kind === 'weapon' ? CONFIG.weaponMaxLevel : 5, slots = kind === 'weapon' ? CONFIG.weaponSlots : CONFIG.traitSlots;
  if (!owned[id] && runItemCount(owned) >= slots) return false;
  if ((owned[id] || 0) >= max) return false;
  owned[id] = Math.min(max, (owned[id] || 0) + levels);
  return true;
}
