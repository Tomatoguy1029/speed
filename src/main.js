import { createRenderer, resizeRenderer, render } from './render.js';
import { createInput } from './input.js';
import { createGame, update } from './world.js';

const canvas = document.getElementById('game');
const renderer = createRenderer(canvas);
const input = createInput(canvas);
let game = createGame({});

window.addEventListener('resize', () => resizeRenderer(renderer));
resizeRenderer(renderer);

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.1, (now - last) / 1000);
  last = now;
  update(game, dt, input.read());
  render(renderer, game, dt, input.state);
  game.events.length = 0;
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
