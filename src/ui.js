import { CONFIG } from './config.js';

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
  const btn = el('button', { class: 'primary', onclick: onNext }, 'ステーションへ');
  showScreen(el('div', { class: 'panel' },
    el('h1', { class: cls }, title),
    el('div', { class: 'sub' }, sub),
    stats,
    el('div', { class: 'btns' }, btn)), 'result');
  btn.focus();
}
