import { createRenderer, resizeRenderer, render, screenToWorld } from './render.js';
import { createInput } from './input.js';
import { createGame, update, resolveOffer, resolveRunLevel } from './world.js';
import { showResult, clearScreens, showOffer, showStation, showPause, showRunLevel } from './ui.js';
import { loadSave, writeSave, buyUpgrade, applyRunResult, resetMeta } from './progression.js';
import { createAudio } from './audio.js';
import { createDebugPanel } from './debug.js';
import { buildIntent, isDrawScheme } from './controls.js';
import { createMobileControls } from './mobile-controls.js';
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
try { const c = window.localStorage.getItem('speed-controls-v2'); if (c) CONFIG.controlScheme = c; } catch { /* ignore */ }
try {
  const method = window.localStorage.getItem('speed-draw-input-v1');
  if (method === 'points' || method === 'freehand') CONFIG.drawInput = method;
} catch { /* ignore */ }
// A shareable local preview can opt into the prototype without replacing saved controls.
const previewControls = new URLSearchParams(window.location.search).get('controls');
if (previewControls === 'portal' || isDrawScheme(previewControls)) CONFIG.controlScheme = previewControls;
const mobile = createMobileControls({ onDraw: () => input.triggerDash(), onPause: () => togglePause(), onDebug: () => debug.toggle() });
// Touch uses drawing plus an independent stick, without overwriting PC preferences.
if (mobile.active) CONFIG.controlScheme = 'draw';
renderer.mobile = mobile.active;
const debug = createDebugPanel(() => game, (id) => {
  try { if (!mobile.active) window.localStorage.setItem('speed-controls-v2', id); } catch { /* ignore */ }
  if (mode === 'station') openStation();
}, () => {
  const refund = resetMeta(save);
  writeSave(storage, save);
  if (mode === 'station') openStation(); // the station screen shows the new levels at once
  return refund; // takes effect from the next run
}, (method) => {
  try { window.localStorage.setItem('speed-draw-input-v1', method); } catch { /* ignore */ }
});
let mode = 'station'; // station | run | result
let offerShown = null;

let portraitViewport = window.innerHeight >= window.innerWidth;
window.addEventListener('resize', () => {
  const portrait = window.innerHeight >= window.innerWidth;
  if (mobile.active && portrait !== portraitViewport) {
    mobile.reset(); input.reset();
    if (game?.draw?.phase === 'draw') game.draw = null;
    renderer.cam.ready = false;
  }
  portraitViewport = portrait;
  resizeRenderer(renderer);
});
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

function chooseRunCard(index) {
  if (game.state !== 'levelup') return;
  if (!resolveRunLevel(game, index)) return;
  offerShown = null;
  if (game.state === 'play') { clearScreens(); input.reset(); input.state.enabled = true; }
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
  if (mode === 'run' && game.state === 'levelup') {
    if (/^[1-9]$/.test(e.key) && Number(e.key) <= game.levelChoices.length && !e.repeat && !['SELECT', 'INPUT'].includes(e.target.tagName)) { e.preventDefault(); chooseRunCard(Number(e.key) - 1); }
    if (e.key === 'p' || e.key === 'P') debug.toggle();
    return;
  }
  if (mode === 'run' && game.state === 'offer') {
    if (e.key === '1') chooseOffer(true);
    else if (e.key === '2') chooseOffer(false);
    return;
  }
  if (e.key === 'Escape') togglePause();
  if (e.key === 'm' || e.key === 'M') audio.toggleMute();
  if ((e.key === 'p' || e.key === 'P') && !['finishing', 'dying'].includes(game.state)) debug.toggle();
  if (e.key === 'Enter') {
    if (mode === 'station') { e.preventDefault(); startRun(); }
  }
});

// Touch-only shortcut: leave the virtual stick and pick a drawing start. Charge lives in the cursor ring.
const dashBtn = document.getElementById('dashBtn');
function updateDashButton() {
  if (mobile.active) { mobile.sync(game, mode === 'run', debug.open); return; }
  const show = mode === 'run' && isDrawScheme(game.scheme) && game.state === 'play' && !game.draw &&
    (input.state.pointerType === 'touch' || window.matchMedia('(pointer: coarse)').matches);
  dashBtn.classList.toggle('show', show);
  if (!show) return;
  dashBtn.disabled = game.dashMeter < (game.newBuild ? CONFIG.drawMinCharge : 1);
}

window.addEventListener('blur', () => { if (mode === 'run' && game.state === 'play') togglePause(); });

openStation();

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.1, (now - last) / 1000);
  last = now;
  const beforeState = game.state;
  const wasRunning = ['play', 'finishing', 'dying'].includes(beforeState);
  const raw = input.read();
  raw.mobile = mobile.active;
  raw.mobileStick = mobile.read();
  if (debug.open && mobile.active) { raw.mobileStick = { x: 0, y: 0 }; raw.dash = raw.pressed = false; }
  raw.cursor = raw.hover ? screenToWorld(renderer, raw.hover.x, raw.hover.y) : null;
  raw.clickCursor = raw.click ? screenToWorld(renderer, raw.click.x, raw.click.y) : null;
  update(game, dt, buildIntent(raw, game.scheme));
  if (game.state === 'finishing' || game.state === 'dying') input.state.enabled = false;
  if (game.state === 'dying' && (beforeState !== 'dying' || debug.open || offerShown)) {
    input.reset(); clearScreens(); offerShown = null; debug.hide();
  }
  render(renderer, game, dt, input.state);
  updateDashButton();
  audio.handle(game.events);
  audio.update(game, dt);
  debug.tick(game, dt);
  game.events.length = 0;
  if (mode === 'run') {
    if (game.state === 'play' && offerShown) {
      offerShown = null; clearScreens(); input.reset(); input.state.enabled = true;
    }
    if (wasRunning && (game.state === 'won' || game.state === 'lost')) finishRun();
    if (game.state === 'levelup' && offerShown !== game.levelChoices) {
      offerShown = game.levelChoices; input.reset(); input.state.enabled = false;
      showRunLevel(game, chooseRunCard);
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
