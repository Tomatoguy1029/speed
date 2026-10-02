import { createRenderer, resizeRenderer, render } from './render.js';
import { createInput } from './input.js';
import { createGame, update } from './world.js';
import { showResult, clearScreens } from './ui.js';

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
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// console access for debugging
window.__speed = { get game() { return game; } };
