import { createRenderer, resizeRenderer, render, screenToWorld } from './render.js';
import { createInput } from './input.js';
import { createGame, update, resolveOffer, resolveLevelup } from './world.js';
import { showResult, clearScreens, showOffer, showStation, showPause, showLevelup } from './ui.js';
import { loadSave, writeSave, buyUpgrade, applyRunResult, resetMeta } from './progression.js';
import { createAudio } from './audio.js';
import { createDebugPanel } from './debug.js';
import { buildIntent, isHyperScheme, schemeById } from './controls.js';
import { CONFIG } from './config.js';

const canvas = document.getElementById('game');
const renderer = createRenderer(canvas);
const input = createInput(canvas);
const storage = (() => { try { return window.localStorage; } catch { return null; } })();
const save = loadSave(storage);
const audio = createAudio();
window.addEventListener('pointerdown', () => audio.unlock(), true);
window.addEventListener('keydown', () => audio.unlock(), true);

let game = null;
// control scheme is a per-browser preference
// a saved scheme that no longer exists (the old drawing modes) falls back to the default
try { const c = window.localStorage.getItem('speed-controls-v2'); if (c) CONFIG.controlScheme = schemeById(c).id; } catch { /* ignore */ }
// A shareable local preview can opt into the prototype without replacing saved controls.
const previewControls = new URLSearchParams(window.location.search).get('controls');
if (previewControls === 'portal' || isHyperScheme(previewControls)) CONFIG.controlScheme = previewControls;
const debug = createDebugPanel(() => game, (id) => {
  try { window.localStorage.setItem('speed-controls-v2', id); } catch { /* ignore */ }
  if (mode === 'station') openStation();
}, () => {
  const refund = resetMeta(save);
  writeSave(storage, save);
  if (mode === 'station') openStation(); // the station screen shows the new levels at once
  return refund; // takes effect from the next run
});
let mode = 'station'; // station | run | result
let offerShown = null;
let levelShown = null;

window.addEventListener('resize', () => resizeRenderer(renderer));
if (typeof ResizeObserver !== 'undefined') new ResizeObserver(() => resizeRenderer(renderer)).observe(renderer.canvas);
if (window.visualViewport) window.visualViewport.addEventListener('resize', () => resizeRenderer(renderer));
resizeRenderer(renderer);

function openStation() {
  mode = 'station';
  input.state.enabled = false;
  input.reset();
  if (!game) { game = createGame({ meta: save.meta }); game.spawning = false; game.state = 'idle'; }
  showStation(save, (id) => { if (buyUpgrade(save, id)) { writeSave(storage, save); openStation(); } }, startRun);
}

function startRun() {
  clearScreens();
  input.reset();
  input.state.enabled = true;
  renderer.cam.ready = false;
  offerShown = null;
  levelShown = null;
  game = createGame({ meta: save.meta });
  mode = 'run';
}

function finishRun() {
  mode = 'result';
  input.state.enabled = false;
  input.reset();
  const before = save.coins;
  applyRunResult(save, game);
  writeSave(storage, save);
  showResult(game, [['獲得部品', `+${save.coins - before}`]], openStation, startRun);
}

function chooseOffer(accept) {
  if (game.state !== 'offer') return;
  resolveOffer(game, accept);
  offerShown = null;
  if (game.state === 'play') { clearScreens(); input.reset(); }
}

function chooseLevel(i) {
  if (game.state !== 'levelup') return;
  resolveLevelup(game, i);
  levelShown = null;
  if (game.state === 'play') { clearScreens(); input.reset(); }
}

function togglePause() {
  if (mode !== 'run') return;
  if (game.state === 'play') {
    game.state = 'paused';
    input.reset();
    showPause(togglePause, () => { game.state = 'lost'; game.endReason = 'time'; clearScreens(); finishRun(); });
  } else if (game.state === 'paused') {
    game.state = 'play';
    clearScreens();
  }
}

window.addEventListener('keydown', (e) => {
  if (mode === 'run' && game.state === 'offer') {
    if (e.key === '1') chooseOffer(true);
    else if (e.key === '2') chooseOffer(false);
    return;
  }
  if (mode === 'run' && game.state === 'levelup') {
    if (e.key === '1' || e.key === '2' || e.key === '3') chooseLevel(Number(e.key) - 1);
    return;
  }
  if (e.key === 'Escape') togglePause();
  if (e.key === 'm' || e.key === 'M') audio.toggleMute();
  if ((e.key === 'p' || e.key === 'P') && game.state !== 'finishing') debug.toggle();
  if (e.key === 'Enter') {
    if (mode === 'station') { e.preventDefault(); startRun(); }
  }
});

// Touch-only shortcut: toggles hyperdrive (Space on a keyboard).
const dashBtn = document.getElementById('dashBtn');
dashBtn.addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); input.triggerDash(); });
function updateDashButton() {
  const show = mode === 'run' && isHyperScheme(game.scheme) && game.state === 'play' &&
    (input.state.pointerType === 'touch' || window.matchMedia('(pointer: coarse)').matches);
  dashBtn.classList.toggle('show', show);
  if (!show) return;
  dashBtn.disabled = !game.hyper.focus && game.hyper.charges < 1;
  dashBtn.classList.toggle('active', game.hyper.focus);
}

window.addEventListener('blur', () => { if (mode === 'run' && game.state === 'play') togglePause(); });

openStation();

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.1, (now - last) / 1000);
  last = now;
  const wasRunning = game.state === 'play' || game.state === 'finishing';
  const raw = input.read();
  raw.cursor = raw.hover ? screenToWorld(renderer, raw.hover.x, raw.hover.y) : null;
  raw.clickCursor = raw.click ? screenToWorld(renderer, raw.click.x, raw.click.y) : null;
  raw.clickCursors = raw.clicks.map((c) => screenToWorld(renderer, c.x, c.y));
  update(game, dt, buildIntent(raw, game.scheme));
  if (game.state === 'finishing') input.state.enabled = false;
  render(renderer, game, dt, input.state);
  updateDashButton();
  audio.handle(game.events);
  audio.update(game, dt);
  debug.tick(game, dt);
  game.events.length = 0;
  if (mode === 'run') {
    if (wasRunning && (game.state === 'won' || game.state === 'lost')) finishRun();
    if (game.state === 'levelup' && levelShown !== game.levelChoices) {
      levelShown = game.levelChoices;
      input.reset();
      showLevelup(game, chooseLevel);
    }
    if (game.state === 'offer' && offerShown !== game.currentOffer) {
      offerShown = game.currentOffer;
      input.reset();
      showOffer(game, chooseOffer);
    }
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// console access for debugging
window.__speed = { get game() { return game; }, save };
