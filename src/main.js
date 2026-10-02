import { createRenderer, resizeRenderer, render } from './render.js';
import { createInput } from './input.js';
import { createGame, update, resolveOffer } from './world.js';
import { showResult, clearScreens, showOffer } from './ui.js';

const canvas = document.getElementById('game');
const renderer = createRenderer(canvas);
const input = createInput(canvas);
let game = null;

window.addEventListener('resize', () => resizeRenderer(renderer));
resizeRenderer(renderer);

function startRun() {
  clearScreens();
  input.reset();
  renderer.cam.ready = false;
  game = createGame({});
}

let offerShown = null;

function chooseOffer(accept) {
  if (game.state !== 'offer') return;
  resolveOffer(game, accept);
  offerShown = null;
  if (game.state === 'play') { clearScreens(); input.reset(); }
}

window.addEventListener('keydown', (e) => {
  if (game.state === 'offer') {
    if (e.key === '1') chooseOffer(true);
    else if (e.key === '2') chooseOffer(false);
  }
});

function onEnd() {
  input.reset();
  showResult(game, [], startRun);
}

startRun();

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.1, (now - last) / 1000);
  last = now;
  const wasPlaying = game.state === 'play';
  update(game, dt, input.read());
  render(renderer, game, dt, input.state);
  game.events.length = 0;
  if (wasPlaying && (game.state === 'won' || game.state === 'lost')) onEnd();
  if (game.state === 'offer' && offerShown !== game.currentOffer) {
    offerShown = game.currentOffer;
    input.reset();
    showOffer(game, chooseOffer);
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// console access for debugging
window.__speed = { get game() { return game; } };
