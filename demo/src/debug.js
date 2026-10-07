// Tuning panel: edits CONFIG live and offers shortcuts (time skip, modules, invincibility).
import { debugRareMeteor } from './rare-weapons.js';
import { CONFIG } from './config.js';
import { refreshStats, pushOffer, addXp, debugRunItem, damageShip } from './world.js';
import { PHASES } from './spawner.js';
import { MODULES, RARITIES, SLOTS, moduleFitsScheme } from './modules.js';
import { RUN_WEAPONS, RUN_TRAITS, runModuleDef, runChoiceInfo } from './run-build.js';
import { xpForLevel } from './progression.js';
import { SCHEMES, schemeById, isDrawScheme } from './controls.js';

const DEFAULTS = { ...CONFIG };

export const TUNABLES = [
  { key: 'bossTime', label: 'ボス出現時間（秒）', min: 30, max: 570, step: 30 },
  { key: 'bossHp', label: 'ボス HP', min: 100, max: 10000, step: 100 },
  { key: 'bossArmor', label: 'ボス装甲', min: 0, max: 100, step: 1 },
  { key: 'baseMaxSpeed', label: '基礎 最高速度', min: 300, max: 2500, step: 25 },
  { key: 'levelSpeedGrowth', label: 'レベルごとの最高速度 +', min: 0, max: 0.1, step: 0.005 },
  { key: 'launchRatio', label: '突進の強さ（上限比）', min: 0.3, max: 1.2, step: 0.02 },
  { key: 'carry', label: '勢いの持ち越し', min: 0, max: 1, step: 0.02 },
  { key: 'dashChargeTime', label: '描画版：1単位の充填時間（実秒）', min: 1, max: 20, step: 0.5 },
  { key: 'drawMinCharge', label: '描画版：発動できる最低充填率', min: 0.1, max: 1, step: 0.05 },
  { key: 'weaponSlots', label: '描画版：武器枠', min: 1, max: 8, step: 1 },
  { key: 'traitSlots', label: '描画版：特性枠', min: 1, max: 12, step: 1 },
  { key: 'chargeTime', label: '旧方式：押下チャージ時間（秒）', min: 0.15, max: 2, step: 0.05 },
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
  { key: 'meteorCount', label: '隕石の配置密度（次のラン）', min: 0, max: 100, step: 1 },
  { key: 'rareMeteorChance', label: '光る隕石の割合（次のラン）', min: 0, max: 0.1, step: 0.001, fmt: v => `${(v * 100).toFixed(1)}%` },
  { key: 'meteorHealChance', label: '隕石：回復ドロップ率', min: 0, max: 1, step: 0.01, fmt: v => `${Math.round(v * 100)}%` },
  { key: 'meteorMagnetChance', label: '隕石：経験値回収アイテムのドロップ率', min: 0, max: 1, step: 0.01, fmt: v => `${Math.round(v * 100)}%` },
  { key: 'meteorHealFrac', label: '修理キット：最大HPに対する回復量', min: 0.05, max: 1, step: 0.05, fmt: v => `${Math.round(v * 100)}%` },
  { key: 'enemyPursuitSpread', label: '敵の広域移動の強さ', min: 0, max: 480, step: 20 },
  { key: 'dropBase', label: 'カプセル基本ドロップ率（描画版はXP）', min: 0, max: 0.05, step: 0.0005, fmt: v => `${(v * 100).toFixed(2)}%` },
  { key: 'dropMax', label: 'カプセルドロップ率 上限', min: 0, max: 1, step: 0.01, fmt: v => `${Math.round(v * 100)}%` },
  { key: 'enemyHpMult', label: '敵 HP 倍率', min: 0.2, max: 3, step: 0.05 },
  { key: 'enemyArmorMult', label: '敵 装甲 倍率', min: 0.2, max: 3, step: 0.05 },
  { key: 'dangerLevel', label: '危険ゾーンの強化', min: 0, max: 5, step: 0.1 },
  { key: 'xpBase', label: 'レベル経験値：基礎', min: 20, max: 200, step: 10 },
  { key: 'xpGrowth', label: 'レベル経験値：一次増加', min: 0, max: 100, step: 2 },
  { key: 'xpCurve', label: 'レベル経験値：二次増加', min: 0, max: 20, step: 1 },
  { key: 'xpMult', label: '経験値 倍率', min: 0.2, max: 4, step: 0.05 },
];

const STAT_KEYS = new Set(['baseMaxSpeed', 'levelSpeedGrowth', 'launchRatio', 'carry', 'chargeTime', 'dashChargeTime', 'boostDuration', 'cruiseFloor']);

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
    const wasBuild = game.newBuild;
    game.scheme = CONFIG.controlScheme;
    game.newBuild = isDrawScheme(game.scheme);
    if (game.newBuild !== wasBuild) {
      game.levelChoices = null; game.pendingLevelups = 0; game.rareOffer = null; game.rareQueue = [];
      game.currentOffer = null; game.offerQueue = [];
      if (game.state === 'levelup' || game.state === 'offer') game.state = 'play';
      if (game.newBuild) for (const c of game.capsules) {
        if (c.kind !== 'capsule') continue;
        c.kind = 'cache'; c.xp = xpForLevel(game.level) * 0.2; delete c.mod;
      }
    }
    game.draw = null; game.portalDash = null; game.portalPreview = null;
    refreshStats(game); // Temporary full-charge effects must end with the interrupted route.
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
    syncModulePicker();
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
  const moduleRow = document.createElement('label');
  moduleRow.className = 'dctl';
  moduleRow.innerHTML = '<span>入手するモジュール</span><select aria-label="入手するモジュール"></select>';
  const moduleSel = moduleRow.querySelector('select');
  const moduleHelp = document.createElement('div');
  moduleHelp.className = 'dhelp';
  btns.before(moduleRow, moduleHelp);

  const button = (label, fn) => {
    const b = document.createElement('button');
    b.textContent = label;
    b.addEventListener('click', () => { const g = getGame(); if (g) fn(g); });
    btns.append(b);
    return b;
  };
  button('+30 秒', (g) => skipTime(g, 30));
  button('+60 秒', (g) => skipTime(g, 60));
  button('レベルアップ', g => { if (g.newBuild && ['play', 'levelup'].includes(g.state)) addXp(g, Math.max(0, xpForLevel(g.level) - g.xp)); });
  button('双極ビームの隕石', g => debugRareMeteor(g, 'bipolar'));
  button('質量牽引砲の隕石', g => debugRareMeteor(g, 'massTow'));
  button('ゲージ満タン', g => { g.dashMeter = 1; });
  for (const fatal of [false, true]) button(fatal ? '致命傷を確認' : '被弾を確認', g => {
    if (g.state !== 'play') return;
    const invincible = g.debug.invincible; g.debug.invincible = false; g.ship.invulnT = 0;
    damageShip(g, fatal ? g.ship.hp + 1 : Math.min(12, g.ship.hp / 2), 0, 'debug');
    g.debug.invincible = invincible;
  });
  button('装備をリセット', g => {
    if (!g.newBuild || !['play', 'levelup'].includes(g.state)) return;
    g.weapons = { forward: 1 }; g.traits = {}; g.weaponState = {}; g.wstate = {}; g.drones = []; g.wproj = []; g.sonicWaves = [];
    g.mines = []; g.marks = []; g.vortexes = []; g.stats.burstPower = 1; g.stats.ignoreArmor = false; refreshStats(g);
    g.rareOffer = null; g.rareQueue = [];
    if (g.state === 'levelup') g.levelChoices = null, g.pendingLevelups = 0, g.state = 'play';
  });
  button('ボス出現へ', (g) => { g.t = Math.max(g.t, CONFIG.bossTime); });
  const sel = document.createElement('select');
  sel.innerHTML = '<option value="">時刻へ…</option>' + PHASES.map((p) => `<option value="${p.id}">${Math.floor(p.start / 60)}:${String(p.start % 60).padStart(2, '0')}ごろ</option>`).join('');
  sel.addEventListener('change', () => { const g = getGame(); if (g && sel.value) jumpToPhase(g, sel.value); sel.value = ''; });
  btns.append(sel);
  const inv = button('無敵: OFF', (g) => { g.debug.invincible = !g.debug.invincible; inv.textContent = `無敵: ${g.debug.invincible ? 'ON' : 'OFF'}`; });
  const rsel = document.createElement('select');
  rsel.setAttribute('aria-label', '入手するモジュールのレア度');
  rsel.innerHTML = RARITIES.map((r, i) => `<option value="${i}">${r.name}</option>`).join('');
  rsel.value = '2';
  btns.append(rsel);
  function syncModuleRarity() {
    const modern = isDrawScheme(getGame()?.scheme || CONFIG.controlScheme);
    if (modern) {
      rsel.setAttribute('aria-label', '入手するモジュールの強化回数');
      const [kind, id] = moduleSel.value.split(':');
      const def = runModuleDef(kind, id), max = kind === 'trait' ? 5 : CONFIG.weaponMaxLevel;
      const selected = Number(rsel.value) || 1;
      rsel.innerHTML = Array.from({ length: max }, (_, i) => `<option value="${i + 1}">+${i + 1} 段階</option>`).join('');
      rsel.value = String(Math.min(max, Math.max(1, selected)));
      moduleHelp.textContent = def ? `${def.group || '通常候補'}：${kind === 'trait' ? def.desc(1) : def.desc}。空き枠があれば直接入手、同じ装備なら強化。` : '武器／特性と強化回数を指定して直接入手。待機・選択画面なし。満員なら装備リセットで試せます。';
      return;
    }
    rsel.setAttribute('aria-label', '入手するモジュールのレア度');
    if (rsel.options.length !== RARITIES.length || rsel.options[0].textContent !== RARITIES[0].name) rsel.innerHTML = RARITIES.map((r, i) => `<option value="${i}">${r.name}</option>`).join('');
    const def = MODULES.find(m => m.id === moduleSel.value);
    if (def && !def.rarities.includes(Number(rsel.value))) rsel.value = String(def.rarities[0]);
    for (const option of rsel.options) option.disabled = !!def && !def.rarities.includes(Number(option.value));
    moduleHelp.textContent = def ? def.desc(Number(rsel.value)) : '従来の6部位モジュールを指定して入手。';
  }
  function syncModulePicker() {
    const selected = moduleSel.value, scheme = getGame()?.scheme || CONFIG.controlScheme;
    moduleSel.innerHTML = '<option value="">ランダム</option>';
    if (isDrawScheme(scheme)) {
      for (const [kind, defs] of [['weapon', RUN_WEAPONS], ['trait', RUN_TRAITS]]) {
        for (const groupName of [undefined, '隕石限定', '保留', '既存候補']) {
          const group = document.createElement('optgroup');
          group.label = `${kind === 'weapon' ? '武器' : '特性'}：${groupName || '通常候補'}`;
          for (const def of defs.filter(d => d.group === groupName)) {
            const option = document.createElement('option'); option.value = `${kind}:${def.id}`; option.textContent = def.name; group.append(option);
          }
          if (group.children.length) moduleSel.append(group);
        }
      }
    } else for (const slot of SLOTS) {
      const group = document.createElement('optgroup'); group.label = slot.name;
      for (const mod of MODULES.filter(m => m.slot === slot.id && moduleFitsScheme(m, scheme))) {
        const option = document.createElement('option'); option.value = mod.id; option.textContent = mod.name; group.append(option);
      }
      if (group.children.length) moduleSel.append(group);
    }
    if ([...moduleSel.options].some(o => o.value === selected)) moduleSel.value = selected;
    syncModuleRarity();
  }
  moduleSel.addEventListener('change', () => { syncModuleRarity(); moduleSel.blur(); });
  rsel.addEventListener('change', () => { syncModuleRarity(); rsel.blur(); });
  syncModulePicker();
  button('モジュール入手', (g) => {
    if (g.newBuild) {
      let [kind, id] = moduleSel.value.split(':');
      if (!id) { const choices = [...RUN_WEAPONS.filter(d => d.normal).map(d => ['weapon', d.id]), ...RUN_TRAITS.filter(d => d.normal).map(d => ['trait', d.id])]; [kind, id] = choices[Math.floor(g.rng() * choices.length)]; }
      debugRunItem(g, kind, id, Number(rsel.value)); return;
    }
    const r = Number(rsel.value);
    const pool = MODULES.filter((m) => m.rarities.includes(r) && moduleFitsScheme(m, g.scheme));
    const def = pool.find(m => m.id === moduleSel.value) || pool[Math.floor(Math.random() * pool.length)];
    if (g.state === 'play' || g.state === 'offer') pushOffer(g, { id: def.id, slot: def.slot, r }, 'capsule');
  });
  button('出力コア', g => { if (g.state === 'play') { g.cores++; refreshStats(g); } });
  button('包囲炸裂を入手', (g) => {
    if (g.newBuild) { debugRunItem(g, 'trait', 'loop', Number(rsel.value)); return; }
    if (g.state === 'play' && g.scheme === 'portal') pushOffer(g,
      { id: 'loopBurst', slot: 'gun', r: Math.max(2, Number(rsel.value)) }, 'capsule');
  });
  button('HP 全快', (g) => { g.ship.hp = g.stats.maxHp; });
  button('月の近くへ', (g) => {
    const m = g.field.moons[0];
    if (!m || g.state !== 'play') return;
    g.ship.x = m.x; g.ship.y = m.y + m.r + 200;
    g.ship.vx = g.ship.vy = 0; g.ship.hx = 0; g.ship.hy = -1;
    g.enemyAim = { x: g.ship.x, y: g.ship.y };
  });
  button('隕石地帯へ', (g) => {
    const m = g.field.meteors.find(m => m.kind === 'belt' && !m.destroyed);
    if (!m || g.state !== 'play') return;
    g.ship.x = m.x; g.ship.y = m.y + 180;
    g.ship.vx = g.ship.vy = 0;
    g.enemyAim = { x: g.ship.x, y: g.ship.y };
    g.meteorStreamT = 0;
  });
  button('経験値回収アイテム', (g) => {
    if (g.state === 'play') g.capsules.push({ kind: 'magnet', src: 'drop', x: g.ship.x, y: g.ship.y, age: 0 });
  });
  button('敵を消す（ボス以外）', (g) => { g.enemies = g.enemies.filter((e) => (e.type === 'boss' || e.type === 'meteor') && !e.dead); g.newEnemies.length = 0; g.ebullets.length = 0; });
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
    toggle() { root.classList.toggle('open'); sync(); syncScheme(); syncPathInput(); syncModulePicker(); },
    hide() { root.classList.remove('open'); },
    get open() { return root.classList.contains('open'); },
    tick(game, dt) {
      if (!root.classList.contains('open') || !game) return;
      fps = fps * 0.95 + (1 / Math.max(dt, 1e-3)) * 0.05;
      const sp = Math.hypot(game.ship.vx, game.ship.vy);
      info.textContent = `t ${game.t.toFixed(1)}s ・ 敵 ${game.enemies.length} ・ Lv ${game.level} ・ 上限 ${(game.stats.maxSpeed * CONFIG.speedToKms).toFixed(2)} ・ 現在 ${(sp * CONFIG.speedToKms).toFixed(2)} ・ 最高 ${(game.peakSpeed * CONFIG.speedToKms).toFixed(2)} km/s ・ ${fps.toFixed(0)} fps`;
    },
  };
}
