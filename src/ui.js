import { CONFIG } from './config.js';
import { SLOTS, RARITIES, moduleDef } from './modules.js';
import { META_UPGRADES, metaCost } from './progression.js';
import { schemeById } from './controls.js';
import { drawPart, drawShipAssembly } from './parts.js';

const root = () => document.getElementById('ui');

export function el(tag, attrs = {}, ...kids) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') n.className = v;
    else if (k.startsWith('on')) n.addEventListener(k.slice(2), v);
    else if (k === 'html') n.innerHTML = v;
    else n.setAttribute(k, v);
  }
  for (const c of kids) if (c != null) n.append(c);
  return n;
}

export function clearScreens() {
  for (const n of [...root().querySelectorAll('.screen')]) n.remove();
}

export function showScreen(panel, id) {
  clearScreens();
  const s = el('div', { class: 'screen', id }, panel);
  root().append(s);
  return s;
}

export function fmtTime(t) {
  const m = Math.floor(t / 60), s = Math.floor(t % 60);
  return `${m}:${String(s).padStart(2, '0')}`;
}

export const kms = (v) => (v * CONFIG.speedToKms).toFixed(2);

const END_TEXT = {
  boss: ['ボス 撃破', 'win', '敵の大群を突破し、ボスを撃破した'],
  hp: ['機体 大破', 'lose', 'HP が尽きた'],
  time: ['時間切れ', 'lose', '時間内にボスを撃破できなかった'],
};

export function showResult(game, extra, onNext) {
  const [title, cls, sub] = END_TEXT[game.endReason] || END_TEXT.time;
  const rows = [
    ['経過時間', fmtTime(game.t)],
    ['最高速度', `${kms(game.peakSpeed)} km/s`],
    ['撃破数', String(game.kills)],
    ['レベル', String(game.level)],
    ...(extra || []),
  ];
  const stats = el('div', { class: 'stats' });
  for (const [k, v] of rows) stats.append(el('div', {}, k), el('div', {}, v));
  const btn = el('button', { class: 'primary', onclick: onNext }, 'ステーションへ ', el('kbd', {}, 'Enter'));
  showScreen(el('div', { class: 'panel' },
    el('h1', { class: cls }, title),
    el('div', { class: 'sub' }, sub),
    stats,
    el('div', { class: 'btns' }, btn)), 'result');
  btn.focus();
}

const SOURCE_TEXT = { xp: '経験値', capsule: '漂流カプセル', elite: '強敵のドロップ', drop: '敵のドロップ', core: '出力コア' };

function partCanvas(slot, color, size = 64) {
  const c = el('canvas', { class: 'part' });
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  c.width = size * dpr; c.height = size * dpr;
  c.style.width = c.style.height = `${size}px`;
  const ctx = c.getContext('2d');
  ctx.scale(dpr, dpr);
  ctx.translate(size / 2, size / 2);
  drawPart(ctx, slot, size * (slot === 'armor' ? 0.26 : 0.36), color, { glow: color ? 10 : 0 });
  return c;
}

// The assembled ship with `slot` pulsing; redraws itself while the offer is open.
function assemblyCanvas(game, slot, size = 150) {
  const c = el('canvas', { class: 'assembly' });
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  c.width = size * dpr; c.height = size * dpr;
  c.style.width = c.style.height = `${size}px`;
  const ctx = c.getContext('2d');
  const paint = (t) => {
    if (!c.isConnected && t > 0) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, size, size);
    drawShipAssembly(ctx, size / 2, size / 2 + size * 0.03, size / 7.4, (s) => {
      const m = game.loadout[s];
      return m ? RARITIES[m.r].color : null;
    }, slot, t / 1000);
    requestAnimationFrame(paint);
  };
  paint(0);
  return c;
}

function moduleCard(mod, tag, isNew, scheme) {
  if (!mod) return el('div', { class: 'card empty' }, '空きスロット');
  const def = moduleDef(mod.id);
  const rar = RARITIES[mod.r];
  const card = el('div', { class: `card${isNew ? ' new' : ''}` },
    partCanvas(mod.slot, rar.color),
    el('div', { class: 'tag' }, tag),
    el('div', { class: 'name' }, `${def.name}${mod.plus ? ` +${mod.plus}` : ''}`),
    el('div', { class: 'rar', style: `color:${rar.color}` }, rar.name),
    el('div', { class: 'desc' }, def.desc(mod.r, scheme)));
  if (isNew) card.style.borderColor = rar.color;
  return card;
}

export function showOffer(game, onChoose) {
  const mod = game.currentOffer;
  const slot = SLOTS.find((s) => s.id === mod.slot);
  const cur = game.loadout[mod.slot];
  const loadout = el('div', { class: 'loadout' });
  for (const s of SLOTS) {
    const m = game.loadout[s.id];
    const d = el('div', { class: s.id === mod.slot ? 'hl' : '' }, `${s.icon} ${s.name}: ${m ? moduleDef(m.id).name : '—'}`);
    if (m) d.style.color = RARITIES[m.r].color;
    loadout.append(d);
  }
  const equip = el('button', { class: 'primary', onclick: () => onChoose(true) }, '付け替える ', el('kbd', {}, '1'));
  const skip = el('button', { onclick: () => onChoose(false) }, '捨てる ', el('kbd', {}, '2'));
  showScreen(el('div', { class: 'panel' },
    el('div', { class: 'offerhead' },
      assemblyCanvas(game, mod.slot),
      el('div', {},
        el('div', { class: 'src' }, `${SOURCE_TEXT[mod.source] || '入手'}${game.offerQueue.length ? `　残り ${game.offerQueue.length}` : ''}`),
        el('h1', {}, slot.name),
        el('div', { class: 'sub' }, '付け替えると今のモジュールは捨てられる'))),
    el('div', { class: 'cards' }, moduleCard(cur, '装備中', false, game.scheme), el('div', { class: 'arrowcol' }, '→'), moduleCard(mod, '新規', true, game.scheme)),
    el('div', { class: 'btns' }, equip, skip),
    loadout), 'offer');
}

export function showStation(save, onBuy, onDepart) {
  const b = save.best;
  const ups = el('div', { class: 'ups' });
  for (const u of META_UPGRADES) {
    const lv = save.meta[u.id] || 0;
    const cost = metaCost(u.id, lv);
    const btn = el('button', { onclick: () => onBuy(u.id) }, cost == null ? '最大' : `強化  ${cost} 部品`);
    if (cost == null || save.coins < cost) btn.disabled = true;
    ups.append(el('div', { class: 'up' },
      el('div', { class: 'n' }, u.name),
      el('div', { class: 'd' }, u.desc),
      el('div', { class: 'pips' }, '●'.repeat(lv) + '○'.repeat(u.max - lv)),
      btn));
  }
  const records = el('div', { class: 'stats' },
    el('div', {}, '出撃'), el('div', {}, `${b.runs} 回`),
    el('div', {}, 'クリア'), el('div', {}, `${b.escapes} 回`),
    el('div', {}, '最速クリア'), el('div', {}, b.escapeTime == null ? '—' : fmtTime(b.escapeTime)),
    el('div', {}, '最高速度'), el('div', {}, `${kms(b.topSpeed)} km/s`));
  const go = el('button', { class: 'primary', onclick: onDepart }, '出発 ', el('kbd', {}, 'Enter'));
  showScreen(el('div', { class: 'panel' },
    el('div', { class: 'row' }, el('h1', {}, 'ステーション'), el('div', { class: 'coins' }, `部品 ${save.coins}`), go),
    el('div', { class: 'version-links' },
      el('a', { href: './draw-original.html', target: '_blank', rel: 'noopener' }, '元の版：線を描いて駆け抜ける'),
      el('a', { href: './index.html?controls=portal', target: '_blank', rel: 'noopener' }, 'ポータル試作')),
    el('div', { class: 'sub' }, `${fmtTime(CONFIG.bossTime)}ごろにボス出現。敵の大群を吹き飛ばし、${fmtTime(CONFIG.runTime)}以内にボスを撃破すればクリア`),
    el('h2', {}, '操作'),
    el('ul', { class: 'how' },
      el('li', {}, el('b', {}, `${schemeById(CONFIG.controlScheme).name}`), '：', schemeById(CONFIG.controlScheme).help, '（', el('kbd', {}, 'P'), ' の調整パネルで操作方法を切り替えられます）'),
      el('li', {}, CONFIG.controlScheme === 'portal' ? '共振ビーコンを装備して出発。ポータル到着時に周囲へ波動が出る。次の行き先の線に赤い×が出ると、その敵には弾かれる' : CONFIG.controlScheme === 'draw' ? '線を走り切った後も高速を維持し、カーソル／スティックで方向を変えられる。貫通できる敵では減速せず、硬い敵に弾かれると通常移動へ戻る。移動中に拾ったモジュールの選択画面は線の終了後に出る' : 'チャージ中も機体は流れ続ける。同じ向きへ続けて突進すると勢いが乗る'),
      el('li', {}, '攻撃力 = 速度。赤い輪の敵は今の速度では貫けない（橙の点線は弱点からなら貫ける）'),
      el('li', {}, '黄色い弧が弱点。そこに当たると必ずクリティカル。予測線が黄色く光る位置を狙う'),
      el('li', {}, 'モジュールは敵が落とす（強い敵ほどよく落とし、レア度も高い）。同じモジュールを拾うと自動で強化（+1）。レベルアップでは基礎性能が上がる'),
      el('li', {}, '中心の惑星に近いほど敵は強いが、レアなカプセルが落ちている'),
      el('li', {}, '8:30 以降、中心付近に出力コア（金の星）が出現。拾うたびに最高速度 +18%。ボスとの戦いに向けて機体を強化する'),
      el('li', {}, el('kbd', {}, 'Esc'), ' ポーズ　', el('kbd', {}, 'M'), ' 音のオン／オフ（最初はミュート）　', el('kbd', {}, 'P'), ' 調整パネル')),
    el('h2', {}, '機体強化'),
    ups,
    el('h2', {}, '記録'),
    records,
    el('div', { class: 'btns' }, el('button', { class: 'primary', onclick: onDepart }, '出発'))), 'station');
}

export function showPause(onResume, onAbandon) {
  showScreen(el('div', { class: 'panel' },
    el('h1', {}, 'ポーズ'),
    el('div', { class: 'btns' },
      el('button', { class: 'primary', onclick: onResume }, '再開 ', el('kbd', {}, 'Esc')),
      el('button', { onclick: onAbandon }, 'ランを終了してステーションへ'))), 'pause');
}
