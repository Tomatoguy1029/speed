import { createRenderer, resizeRenderer, render } from './render.js';
import { createInput } from './input.js';
import { createGame, update, resolveOffer } from './world.js';
import { showResult, clearScreens, showOffer, showStation, showPause } from './ui.js';
import { loadSave, writeSave, buyUpgrade, applyRunResult } from './progression.js';
import { createAudio } from './audio.js';
import { createDebugPanel } from './debug.js';

const canvas = document.getElementById('game');
const renderer = createRenderer(canvas);
const input = createInput(canvas);
const storage = (() => { try { return window.localStorage; } catch { return null; } })();
const save = loadSave(storage);
const audio = createAudio();
window.addEventListener('pointerdown', () => audio.unlock(), true);
window.addEventListener('keydown', () => audio.unlock(), true);

let game = null;
const debug = createDebugPanel(() => game);
let mode = 'station'; // station | run | result
let offerShown = null;

window.addEventListener('resize', () => resizeRenderer(renderer));
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
  showResult(game, [['獲得部品', `+${save.coins - before}`]], openStation);
}

function chooseOffer(accept) {
  if (game.state !== 'offer') return;
  resolveOffer(game, accept);
  offerShown = null;
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
  if (e.key === 'Escape') togglePause();
  if (e.key === 'm' || e.key === 'M') audio.toggleMute();
  if (e.key === 'p' || e.key === 'P') debug.toggle();
  if (e.key === 'Enter') {
    if (mode === 'station') { e.preventDefault(); startRun(); }
    else if (mode === 'result') { e.preventDefault(); openStation(); }
  }
});

window.addEventListener('blur', () => { if (mode === 'run' && game.state === 'play') togglePause(); });

openStation();

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.1, (now - last) / 1000);
  last = now;
  const wasPlaying = game.state === 'play';
  update(game, dt, input.read());
  render(renderer, game, dt, input.state);
  audio.handle(game.events);
  audio.update(game, dt);
  debug.tick(game, dt);
  game.events.length = 0;
  if (mode === 'run') {
    if (wasPlaying && (game.state === 'won' || game.state === 'lost')) finishRun();
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
