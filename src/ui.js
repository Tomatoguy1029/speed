import { CONFIG } from './config.js';
import { SLOTS, RARITIES, moduleDef } from './modules.js';
import { META_UPGRADES, metaCost } from './progression.js';

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
  escape: ['重力圏 脱出', 'win', '脱出速度に到達した'],
  hp: ['機体 大破', 'lose', 'HP が尽きた'],
  time: ['時間切れ', 'lose', '10 分以内に脱出速度へ届かなかった'],
};

export function showResult(game, extra, onNext) {
  const [title, cls, sub] = END_TEXT[game.endReason] || END_TEXT.time;
  const rows = [
    ['経過時間', fmtTime(game.t)],
    ['最高速度', `${kms(game.peakSpeed)} km/s`],
    ['脱出速度', `${kms(CONFIG.escapeSpeed)} km/s`],
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

const SOURCE_TEXT = { xp: '経験値', capsule: '漂流カプセル', elite: '強敵のドロップ', core: '出力コア' };

function moduleCard(mod, tag, isNew) {
  if (!mod) return el('div', { class: 'card empty' }, '空きスロット');
  const def = moduleDef(mod.id);
  const rar = RARITIES[mod.r];
  const card = el('div', { class: `card${isNew ? ' new' : ''}` },
    el('div', { class: 'tag' }, tag),
    el('div', { class: 'name' }, def.name),
    el('div', { class: 'rar', style: `color:${rar.color}` }, rar.name),
    el('div', { class: 'desc' }, def.desc(mod.r)));
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
    el('div', { class: 'src' }, `${SOURCE_TEXT[mod.source] || '入手'}${game.offerQueue.length ? `　残り ${game.offerQueue.length}` : ''}`),
    el('h1', {}, `${slot.icon} ${slot.name}`),
    el('div', { class: 'sub' }, '付け替えると今のモジュールは捨てられる'),
    el('div', { class: 'cards' }, moduleCard(cur, '装備中', false), el('div', { class: 'arrowcol' }, '→'), moduleCard(mod, '新規', true)),
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
    el('div', {}, '脱出'), el('div', {}, `${b.escapes} 回`),
    el('div', {}, '最速脱出'), el('div', {}, b.escapeTime == null ? '—' : fmtTime(b.escapeTime)),
    el('div', {}, '最高速度'), el('div', {}, `${kms(b.topSpeed)} km/s`));
  const go = el('button', { class: 'primary', onclick: onDepart }, '出発 ', el('kbd', {}, 'Enter'));
  showScreen(el('div', { class: 'panel' },
    el('div', { class: 'row' }, el('h1', {}, 'ステーション'), el('div', { class: 'coins' }, `部品 ${save.coins}`), go),
    el('div', { class: 'sub' }, `10 分以内に、実際の速度で脱出速度 ${kms(CONFIG.escapeSpeed)} km/s に到達すれば重力圏脱出`),
    el('h2', {}, '操作'),
    el('ul', { class: 'how' },
      el('li', {}, '画面を押したままドラッグ → 離すと、ドラッグと逆方向へ突進。長く押すほど強い'),
      el('li', {}, 'チャージ中も機体は流れ続ける。同じ向きへ続けて突進すると勢いが乗る'),
      el('li', {}, '攻撃力 = 速度。赤い輪の敵は今の速度では貫けない（橙の点線は弱点からなら貫ける）'),
      el('li', {}, '黄色い弧が弱点。そこに当たると必ずクリティカル。予測線が黄色く光る位置を狙う'),
      el('li', {}, '中心の惑星の重力をかすめると上限を超えて加速できる。中心ほど敵は強いがレアなカプセルがある'),
      el('li', {}, el('kbd', {}, 'Esc'), ' ポーズ　', el('kbd', {}, 'M'), ' ミュート　', el('kbd', {}, 'P'), ' 調整パネル')),
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
