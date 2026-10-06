// Tuning panel: edits CONFIG live and offers shortcuts (time skip, modules, invincibility).
import { CONFIG } from './config.js';
import { refreshStats, pushOffer } from './world.js';
import { PHASES } from './spawner.js';
import { MODULES, RARITIES, moduleFitsScheme } from './modules.js';
import { SCHEMES, schemeById } from './controls.js';

const DEFAULTS = { ...CONFIG };

export const TUNABLES = [
  { key: 'bossTime', label: 'ボス出現時間（秒）', min: 30, max: 570, step: 30 },
  { key: 'bossHp', label: 'ボス HP', min: 100, max: 10000, step: 100 },
  { key: 'bossArmor', label: 'ボス装甲', min: 0, max: 100, step: 1 },
  { key: 'baseMaxSpeed', label: '基礎 最高速度', min: 300, max: 2500, step: 25 },
  { key: 'levelSpeedGrowth', label: 'レベルごとの最高速度 +', min: 0, max: 0.1, step: 0.005 },
  { key: 'launchRatio', label: '突進の強さ（上限比）', min: 0.3, max: 1.2, step: 0.02 },
  { key: 'carry', label: '勢いの持ち越し', min: 0, max: 1, step: 0.02 },
  { key: 'chargeTime', label: 'チャージ時間（秒）', min: 0.15, max: 2, step: 0.05 },
  { key: 'steerRate', label: '旋回の速さ（マウス / WASD 旋回）rad/s', min: 0.5, max: 12, step: 0.1 },
  { key: 'steerAccel', label: '旋回操作の加速（低速時）', min: 0, max: 3000, step: 50 },
  { key: 'steerCruise', label: '旋回操作だけで出せる速度（上限比）', min: 0, max: 1, step: 0.05 },
  { key: 'boostDuration', label: '突進エネルギー（秒）', min: 0.1, max: 3, step: 0.05 },
  { key: 'energyCut', label: 'エネルギー切れ後の速度', min: 0.5, max: 1, step: 0.01 },
  { key: 'cruiseDrag', label: '巡航ドラッグ', min: 0, max: 1, step: 0.01 },
  { key: 'overcapDecay', label: '上限超過の減衰', min: 0, max: 2, step: 0.05 },
  { key: 'planetGM', label: '中心惑星の重力（既定 0）', min: 0, max: 1.5e9, step: 1e7, fmt: (v) => `${(v / 1e8).toFixed(1)}e8` },
  { key: 'moonGM', label: '小惑星の重力', min: 0, max: 1e8, step: 1e6, fmt: (v) => `${(v / 1e6).toFixed(0)}e6` },
  { key: 'atkScale', label: '攻撃力の係数', min: 0.5, max: 3, step: 0.05 },
  { key: 'drawLength', label: '軌跡の長さ（満タン時）', min: 200, max: 3000, step: 50 },
  { key: 'portalReach', label: 'ポータル：1回の到達距離（基礎）', min: 300, max: 2500, step: 50 },
  { key: 'portalBudget', label: 'ポータル：連続突進の総距離（基礎）', min: 500, max: 6000, step: 100 },
  { key: 'portalExitHold', label: 'ポータル：Space長押しで離脱（秒）', min: 0.5, max: 3, step: 0.1 },
  { key: 'portalEdgeCooldown', label: 'ポータル：通った辺のクールダウン（秒）', min: 0, max: 30, step: 1 },
  { key: 'portalChooseScale', label: 'ポータル：選択中の世界の速さ', min: 0.05, max: 1, step: 0.05 },
  { key: 'portalHopTime', label: 'ポータル：1区間の移動時間（秒）', min: 0.05, max: 0.8, step: 0.01 },
  { key: 'portalSpacing', label: 'ポータル：密集を防ぐ間隔', min: 100, max: 700, step: 20 },
  { key: 'portalDropChance', label: 'ポータル：撃破での出現率', min: 0, max: 1, step: 0.02 },
  { key: 'portalWaveRadius', label: 'ポータル：到着波動の半径', min: 0, max: 600, step: 10 },
  { key: 'portalWaveDamage', label: 'ポータル：到着波動の威力（攻撃力比）', min: 0, max: 3, step: 0.1 },
  { key: 'enemyAimLag', label: '敵の照準の遅れ(秒)', min: 0, max: 2, step: 0.05 },
  { key: 'enemyAimSpeed', label: '敵の照準が追える速さ', min: 100, max: 3000, step: 50 },
  { key: 'stickRadius', label: 'スティックの半径(px)', min: 30, max: 200, step: 5 },
  { key: 'stickDeadZone', label: 'スティックの遊び(px)', min: 0, max: 40, step: 1 },
  { key: 'drawTimeScale', label: '描画中の世界の速さ（0＝停止、1＝通常）', min: 0, max: 1, step: 0.01 },
  { key: 'drawRunSlowRef', label: 'なぞり中の世界の遅さ（大きいほど速い。世界の速さ = この値 / 突進速度）', min: 20, max: 2000, step: 10 },
  { key: 'drawRunScaleMin', label: 'なぞり中の世界の速さ 下限', min: 0, max: 0.5, step: 0.01 },
  { key: 'drawRunTime', label: '軌跡をなぞる時間（秒）', min: 0.05, max: 2, step: 0.05 },
  { key: 'waveRadius', label: '軌跡の波動が届く距離', min: 0, max: 300, step: 5 },
  { key: 'waveDamage', label: '軌跡の波動の威力（攻撃力比）', min: 0, max: 3, step: 0.05 },
  { key: 'killHitstop', label: '一撃撃破のヒットストップ（秒）', min: 0, max: 0.2, step: 0.005 },
  { key: 'killHitstopCap', label: 'ヒットストップ上限／突進（秒）', min: 0, max: 2, step: 0.05 },
  { key: 'zoomExp', label: 'ズームアウト強さ', min: 0, max: 1.2, step: 0.05 },
  { key: 'zoomMin', label: '最小ズーム', min: 0.1, max: 1, step: 0.02 },
  { key: 'densityMult', label: '敵の数 倍率', min: 0.2, max: 8, step: 0.05 },
  { key: 'enemySpacing', label: '敵同士の間隔', min: 0, max: 100, step: 1 },
  { key: 'enemyPursuitSpread', label: '敵の接近経路の広がり', min: 0, max: 600, step: 20 },
  { key: 'drawOfferInterval', label: '描画版の獲得画面 最低間隔（秒）', min: 0, max: 90, step: 5 },
  { key: 'drawDropInterval', label: '描画版のドロップ 最低間隔（秒）', min: 0, max: 90, step: 5 },
  { key: 'enemyHpMult', label: '敵 HP 倍率', min: 0.2, max: 3, step: 0.05 },
  { key: 'enemyArmorMult', label: '敵 装甲 倍率', min: 0.2, max: 3, step: 0.05 },
  { key: 'dangerLevel', label: '危険ゾーンの強化', min: 0, max: 5, step: 0.1 },
  { key: 'xpMult', label: '経験値 倍率', min: 0.2, max: 4, step: 0.05 },
];

const STAT_KEYS = new Set(['baseMaxSpeed', 'levelSpeedGrowth', 'launchRatio', 'carry', 'chargeTime', 'boostDuration', 'cruiseFloor']);

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

export function setScheme(game, id) {
  CONFIG.controlScheme = schemeById(id).id;
  if (game) {
    game.scheme = CONFIG.controlScheme;
    game.draw = null; game.portalDash = null; game.portalPreview = null;
    game.ship.charging = false; game.releasePending = null;
  }
}

export function createDebugPanel(getGame, onScheme, onResetMeta, onDrawInput) {
  const root = document.createElement('div');
  root.id = 'debug';
  root.innerHTML = `<div class="dh"><b>調整パネル</b><span class="dclose">P で閉じる</span></div><label class="dctl"><span>操作方法</span><select></select></label><div class="dhelp"></div><div class="dinfo"></div><div class="dbtns"></div><div class="dsl"></div>`;
  document.body.append(root);
  const schemeSel = root.querySelector('.dctl select');
  const schemeHelp = root.querySelector('.dhelp');
  schemeSel.innerHTML = SCHEMES.map((s) => `<option value="${s.id}">${s.name}</option>`).join('');
  const syncScheme = () => { schemeSel.value = CONFIG.controlScheme; schemeHelp.textContent = schemeById(CONFIG.controlScheme).help; };
  schemeSel.addEventListener('change', () => {
    setScheme(getGame(), schemeSel.value);
    syncScheme();
    schemeSel.blur(); // keep WASD/Space for the game, not the select
    if (onScheme) onScheme(CONFIG.controlScheme);
  });
  syncScheme();
  const pathRow = document.createElement('label');
  pathRow.className = 'dctl';
  pathRow.innerHTML = '<span>軌跡の入力</span><select aria-label="軌跡の入力"><option value="freehand">マウスで描く（従来）</option><option value="points">クリックで通過点を置く</option></select>';
  const pathSel = pathRow.querySelector('select');
  const pathHelp = document.createElement('div');
  pathHelp.className = 'dhelp';
  schemeHelp.after(pathRow, pathHelp);
  const syncPathInput = () => {
    pathSel.value = CONFIG.drawInput;
    pathHelp.textContent = CONFIG.drawInput === 'points'
      ? '描画方式で使用。左クリックで開始点・通過点を置く。点の間は直線で結ぶ。右クリック／Spaceで発動、長さを使い切っても自動発動。通常移動は操作方法の設定どおり。'
      : '描画方式で使用。クリックで開始し、マウス移動で線を描く。再クリックか長さを使い切ると発動。';
  };
  pathSel.addEventListener('change', () => {
    CONFIG.drawInput = pathSel.value;
    const g = getGame();
    if (g?.draw?.phase === 'draw') { g.draw = null; g.dashMeter = 1; }
    syncPathInput(); pathSel.blur();
    if (onDrawInput) onDrawInput(CONFIG.drawInput);
  });
  syncPathInput();
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
  button('ボス出現へ', (g) => { g.t = Math.max(g.t, CONFIG.bossTime); });
  const sel = document.createElement('select');
  sel.innerHTML = '<option value="">時刻へ…</option>' + PHASES.map((p) => `<option value="${p.id}">${Math.floor(p.start / 60)}:${String(p.start % 60).padStart(2, '0')}ごろ</option>`).join('');
  sel.addEventListener('change', () => { const g = getGame(); if (g && sel.value) jumpToPhase(g, sel.value); sel.value = ''; });
  btns.append(sel);
  const inv = button('無敵: OFF', (g) => { g.debug.invincible = !g.debug.invincible; inv.textContent = `無敵: ${g.debug.invincible ? 'ON' : 'OFF'}`; });
  const rsel = document.createElement('select');
  rsel.innerHTML = RARITIES.map((r, i) => `<option value="${i}">${r.name}</option>`).join('');
  rsel.value = '2';
  btns.append(rsel);
  button('モジュール入手', (g) => {
    const r = Number(rsel.value);
    const pool = MODULES.filter((m) => m.rarities.includes(r) && moduleFitsScheme(m, g.scheme));
    const def = pool[Math.floor(Math.random() * pool.length)];
    if (g.state === 'play') pushOffer(g, { id: def.id, slot: def.slot, r }, 'capsule');
  });
  button('出力コア', (g) => { if (g.state === 'play') pushOffer(g, { id: 'limiter', slot: 'booster', r: 3 }, 'core'); });
  button('包囲炸裂を入手', (g) => {
    if (g.state === 'play' && g.scheme === 'portal') pushOffer(g,
      { id: 'loopBurst', slot: 'gun', r: Math.max(2, Number(rsel.value)) }, 'capsule');
  });
  button('HP 全快', (g) => { g.ship.hp = g.stats.maxHp; });
  button('敵を消す（ボス以外）', (g) => { g.enemies = g.enemies.filter((e) => e.type === 'boss' && !e.dead); g.newEnemies.length = 0; g.ebullets.length = 0; });
  button('部品 +100', (g) => { g.coins += 100; });
  if (onResetMeta) {
    const b = document.createElement('button');
    b.textContent = '機体強化をリセット';
    b.title = 'ステーションの機体強化をすべて 0 に戻し、使った部品を返す';
    b.addEventListener('click', () => { const n = onResetMeta(); b.textContent = `リセット済み（部品 +${n}）`; setTimeout(() => { b.textContent = '機体強化をリセット'; }, 1500); });
    btns.append(b);
  }
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
    toggle() { root.classList.toggle('open'); sync(); syncScheme(); syncPathInput(); },
    get open() { return root.classList.contains('open'); },
    tick(game, dt) {
      if (!root.classList.contains('open') || !game) return;
      fps = fps * 0.95 + (1 / Math.max(dt, 1e-3)) * 0.05;
      const sp = Math.hypot(game.ship.vx, game.ship.vy);
      info.textContent = `t ${game.t.toFixed(1)}s ・ 敵 ${game.enemies.length} ・ Lv ${game.level} ・ 上限 ${(game.stats.maxSpeed * CONFIG.speedToKms).toFixed(2)} ・ 現在 ${(sp * CONFIG.speedToKms).toFixed(2)} ・ 最高 ${(game.peakSpeed * CONFIG.speedToKms).toFixed(2)} km/s ・ ${fps.toFixed(0)} fps`;
    },
  };
}
