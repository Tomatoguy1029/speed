import { CONFIG } from './config.js';

export function xpForLevel(level) {
  return CONFIG.xpBase + CONFIG.xpGrowth * level;
}

// Station upgrades bought with coins (parts). Effects are applied in baseStats().
export const META_UPGRADES = [
  { id: 'speed', name: '主推進器', desc: '最高速度 +5%', max: 5, costs: [25, 50, 90, 140, 210] },
  { id: 'hp', name: '機体フレーム', desc: '最大 HP +15', max: 5, costs: [20, 40, 70, 110, 160] },
  { id: 'atk', name: '衝角素材', desc: '攻撃力 +6%', max: 5, costs: [20, 40, 70, 110, 160] },
  { id: 'charge', name: '充電効率', desc: 'チャージ時間 -5%', max: 5, costs: [20, 40, 70, 110, 160] },
  { id: 'pickup', name: '回収装置', desc: '回収範囲 +15%', max: 5, costs: [15, 30, 55, 85, 125] },
  { id: 'xp', name: '学習回路', desc: '経験値 +8%', max: 5, costs: [25, 50, 90, 140, 210] },
];

const SAVE_KEY = 'speed-save-v1';

export function metaCost(id, level) {
  const u = META_UPGRADES.find((x) => x.id === id);
  if (!u || level >= u.max) return null;
  return u.costs[level];
}

export function buyUpgrade(save, id) {
  const lv = save.meta[id] || 0;
  const cost = metaCost(id, lv);
  if (cost == null || save.coins < cost) return false;
  save.coins -= cost;
  save.meta[id] = lv + 1;
  return true;
}

// Debug: put every station upgrade back to 0 and refund the parts spent on them.
export function resetMeta(save) {
  let refund = 0;
  for (const u of META_UPGRADES) {
    const lv = save.meta[u.id] || 0;
    for (let i = 0; i < lv; i++) refund += u.costs[i] || 0;
  }
  save.meta = {};
  save.coins += refund;
  return refund;
}

export function defaultSave() {
  return { coins: 0, meta: {}, best: { runs: 0, escapes: 0, escapeTime: null, topSpeed: 0 } };
}

export function loadSave(storage) {
  try {
    const raw = storage && storage.getItem(SAVE_KEY);
    if (!raw) return defaultSave();
    const s = JSON.parse(raw);
    const d = defaultSave();
    if (typeof s !== 'object' || !s) return d;
    return {
      coins: Number.isFinite(s.coins) ? s.coins : 0,
      meta: typeof s.meta === 'object' && s.meta ? s.meta : {},
      best: { ...d.best, ...(s.best || {}) },
    };
  } catch {
    return defaultSave();
  }
}

export function writeSave(storage, save) {
  try { storage && storage.setItem(SAVE_KEY, JSON.stringify(save)); } catch { /* storage unavailable */ }
}

export function applyRunResult(save, game) {
  save.coins += Math.round(game.coins);
  save.best.runs++;
  save.best.topSpeed = Math.max(save.best.topSpeed, game.peakSpeed);
  if (game.state === 'won') {
    save.best.escapes++;
    save.best.escapeTime = save.best.escapeTime == null ? game.t : Math.min(save.best.escapeTime, game.t);
  }
}
