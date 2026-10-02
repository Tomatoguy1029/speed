// Tuning panel: edits CONFIG live and offers shortcuts (time skip, modules, invincibility).
import { CONFIG } from './config.js';
import { refreshStats, pushOffer } from './world.js';
import { PHASES } from './spawner.js';
import { MODULES, RARITIES } from './modules.js';

const DEFAULTS = { ...CONFIG };

export const TUNABLES = [
  { key: 'escapeSpeed', label: '脱出速度', min: 1200, max: 4000, step: 50, fmt: (v) => `${(v * CONFIG.speedToKms).toFixed(1)} km/s` },
  { key: 'baseMaxSpeed', label: '基礎 最高速度', min: 500, max: 2500, step: 25 },
  { key: 'launchRatio', label: '突進の強さ（上限比）', min: 0.3, max: 1.2, step: 0.02 },
  { key: 'carry', label: '勢いの持ち越し', min: 0, max: 1, step: 0.02 },
  { key: 'chargeTime', label: 'チャージ時間（秒）', min: 0.15, max: 2, step: 0.05 },
  { key: 'nudgeAccel', label: 'WASD 推力（静止時）', min: 0, max: 1500, step: 25 },
  { key: 'nudgeSteer', label: 'WASD 曲がりやすさ（速度比）', min: 0, max: 3, step: 0.05 },
  { key: 'nudgeMaxSpeed', label: 'WASD で加速できる上限（上限比）', min: 0, max: 1, step: 0.05 },
  { key: 'boostDuration', label: '突進エネルギー（秒）', min: 0.1, max: 3, step: 0.05 },
  { key: 'energyCut', label: 'エネルギー切れ後の速度', min: 0.5, max: 1, step: 0.01 },
  { key: 'cruiseDrag', label: '巡航ドラッグ', min: 0, max: 1, step: 0.01 },
  { key: 'overcapDecay', label: '上限超過の減衰', min: 0, max: 2, step: 0.05 },
  { key: 'planetGM', label: '中心惑星の重力', min: 0, max: 1.5e9, step: 1e7, fmt: (v) => `${(v / 1e8).toFixed(1)}e8` },
  { key: 'moonGM', label: '小惑星の重力', min: 0, max: 1e8, step: 1e6, fmt: (v) => `${(v / 1e6).toFixed(0)}e6` },
  { key: 'zoomExp', label: 'ズームアウト強さ', min: 0, max: 1.2, step: 0.05 },
  { key: 'zoomMin', label: '最小ズーム', min: 0.1, max: 1, step: 0.02 },
  { key: 'densityMult', label: '敵の数 倍率', min: 0.2, max: 3, step: 0.05 },
  { key: 'enemyHpMult', label: '敵 HP 倍率', min: 0.2, max: 3, step: 0.05 },
  { key: 'enemyArmorMult', label: '敵 装甲 倍率', min: 0.2, max: 3, step: 0.05 },
  { key: 'dangerLevel', label: '危険ゾーンの強化', min: 0, max: 5, step: 0.1 },
  { key: 'xpMult', label: '経験値 倍率', min: 0.2, max: 4, step: 0.05 },
];

const STAT_KEYS = new Set(['baseMaxSpeed', 'launchRatio', 'carry', 'chargeTime', 'boostDuration', 'cruiseFloor']);

export function applyTunable(game, key, value) {
  CONFIG[key] = value;
  if (!game) return;
  if (STAT_KEYS.has(key)) refreshStats(game);
  if (key === 'planetGM') game.field.planet.gm = value;
  if (key === 'moonGM') for (const m of game.field.moons) m.gm = value;
}

export function resetConfig(game) {
  for (const t of TUNABLES) applyTunable(game, t.key, DEFAULTS[t.key]);
}

export function skipTime(game, sec) {
  game.t = Math.min(CONFIG.runTime - 1, game.t + sec);
}

export function jumpToPhase(game, id) {
  const p = PHASES.find((x) => x.id === id);
  if (p) game.t = p.start + 0.01;
}

export function createDebugPanel(getGame) {
  const root = document.createElement('div');
  root.id = 'debug';
  root.innerHTML = `<div class="dh"><b>調整パネル</b><span class="dclose">P で閉じる</span></div><div class="dinfo"></div><div class="dbtns"></div><div class="dsl"></div>`;
  document.body.append(root);
  const info = root.querySelector('.dinfo');
  const btns = root.querySelector('.dbtns');
  const sliders = root.querySelector('.dsl');

  const button = (label, fn) => {
    const b = document.createElement('button');
    b.textContent = label;
    b.addEventListener('click', () => { const g = getGame(); if (g) fn(g); });
    btns.append(b);
    return b;
  };
  button('+30 秒', (g) => skipTime(g, 30));
  button('+60 秒', (g) => skipTime(g, 60));
  const sel = document.createElement('select');
  sel.innerHTML = '<option value="">フェーズへ…</option>' + PHASES.map((p) => `<option value="${p.id}">${p.name}（${Math.floor(p.start / 60)}:${String(p.start % 60).padStart(2, '0')}）</option>`).join('');
  sel.addEventListener('change', () => { const g = getGame(); if (g && sel.value) jumpToPhase(g, sel.value); sel.value = ''; });
  btns.append(sel);
  const inv = button('無敵: OFF', (g) => { g.debug.invincible = !g.debug.invincible; inv.textContent = `無敵: ${g.debug.invincible ? 'ON' : 'OFF'}`; });
  const rsel = document.createElement('select');
  rsel.innerHTML = RARITIES.map((r, i) => `<option value="${i}">${r.name}</option>`).join('');
  rsel.value = '2';
  btns.append(rsel);
  button('モジュール入手', (g) => {
    const r = Number(rsel.value);
    const pool = MODULES.filter((m) => m.rarities.includes(r));
    const def = pool[Math.floor(Math.random() * pool.length)];
    if (g.state === 'play') pushOffer(g, { id: def.id, slot: def.slot, r }, 'capsule');
  });
  button('出力コア', (g) => { if (g.state === 'play') pushOffer(g, { id: 'limiter', slot: 'booster', r: 3 }, 'core'); });
  button('HP 全快', (g) => { g.ship.hp = g.stats.maxHp; });
  button('敵を消す', (g) => { g.enemies.length = 0; g.ebullets.length = 0; });
  button('部品 +100', (g) => { g.coins += 100; });
  button('既定値に戻す', (g) => { resetConfig(g); sync(); });

  const inputs = [];
  for (const t of TUNABLES) {
    const row = document.createElement('label');
    row.className = 'drow';
    const name = document.createElement('span');
    name.textContent = t.label;
    const val = document.createElement('span');
    val.className = 'dval';
    const inp = document.createElement('input');
    inp.type = 'range'; inp.min = t.min; inp.max = t.max; inp.step = t.step;
    inp.addEventListener('input', () => {
      applyTunable(getGame(), t.key, Number(inp.value));
      val.textContent = t.fmt ? t.fmt(CONFIG[t.key]) : String(CONFIG[t.key]);
    });
    row.append(name, val, inp);
    sliders.append(row);
    inputs.push({ t, inp, val });
  }
  function sync() {
    for (const { t, inp, val } of inputs) {
      inp.value = CONFIG[t.key];
      val.textContent = t.fmt ? t.fmt(CONFIG[t.key]) : String(CONFIG[t.key]);
    }
  }
  sync();

  let fps = 60;
  return {
    toggle() { root.classList.toggle('open'); sync(); },
    get open() { return root.classList.contains('open'); },
    tick(game, dt) {
      if (!root.classList.contains('open') || !game) return;
      fps = fps * 0.95 + (1 / Math.max(dt, 1e-3)) * 0.05;
      const sp = Math.hypot(game.ship.vx, game.ship.vy);
      info.textContent = `t ${game.t.toFixed(1)}s ・ 敵 ${game.enemies.length} ・ Lv ${game.level} ・ 上限 ${(game.stats.maxSpeed * CONFIG.speedToKms).toFixed(2)} ・ 現在 ${(sp * CONFIG.speedToKms).toFixed(2)} ・ 最高 ${(game.peakSpeed * CONFIG.speedToKms).toFixed(2)} km/s ・ ${fps.toFixed(0)} fps`;
    },
  };
}
