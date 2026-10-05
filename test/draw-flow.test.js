import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createGame, update, resolveOffer } from '../src/world.js';
import { createEnemy } from '../src/enemies.js';
import { killEnemy } from '../src/hits.js';
import { CONFIG } from '../src/config.js';

const flowIdle = { charging: false, release: false, cursor: null };
function flowGame() {
  const game = createGame({ seed: 5, scheme: 'draw' });
  game.spawning = false;
  game.field.moons.length = 0;
  game.field.dust.length = 0;
  Object.assign(game.ship, { x: 0, y: -3000, vx: 0, vy: 0 });
  return game;
}
function flowTrace(game) {
  update(game, 0.02, { ...flowIdle, dash: true });
  update(game, 0.02, { ...flowIdle, press: true, cursor: { x: 0, y: -3000 } });
  update(game, 0.02, { ...flowIdle, cursor: { x: 800, y: -3000 } });
  update(game, 0.02, { ...flowIdle, press: true });
}

test('a pickup during tracing waits until the line ends, then resumes with the same velocity', () => {
  const game = flowGame();
  flowTrace(game);
  game.capsules.push({ kind: 'capsule', src: 'drop', x: game.ship.x, y: game.ship.y,
    mod: { id: 'ram', slot: 'bow', r: 0 }, age: 0 });
  for (let i = 0; i < 60 && game.draw; i++) {
    update(game, 0.01, flowIdle);
    if (game.draw) assert.equal(game.state, 'play');
  }
  assert.equal(game.draw, null);
  assert.equal(game.state, 'offer');
  const vx = game.ship.vx;
  assert.ok(game.ship.x >= 800);
  assert.ok(game.ship.glide);
  resolveOffer(game, true);
  for (let i = 0; i < 150; i++) update(game, 0.02, { ...flowIdle, cursor: { x: -1000, y: -3000 } });
  assert.equal(game.ship.vx, vx, 'cursor, boost expiry and cruise drag must not end the straight flight');
  assert.equal(game.ship.vy, 0);
});

test('post-trace flight pierces fodder without slowing, but an armored bounce restores ordinary movement', () => {
  const game = flowGame();
  Object.assign(game.ship, { vx: 400, glide: true });
  const fodder = createEnemy('drifter', 1, 100, -3000);
  const wall = createEnemy('armored', 8, 500, -3000, { facing: Math.PI });
  fodder.speed = wall.speed = 0;
  game.enemies.push(fodder, wall);
  for (let i = 0; i < 50 && !fodder.dead; i++) update(game, 0.02, flowIdle);
  assert.ok(fodder.dead);
  assert.equal(game.ship.vx, 400);
  assert.ok(game.ship.glide);
  for (let i = 0; i < 100 && game.ship.glide; i++) update(game, 0.02, flowIdle);
  assert.ok(!game.ship.glide);
  assert.ok(game.ship.vx < 0);
  assert.ok(game.ship.hp < game.stats.maxHp);
});

test('large elite sweeps cannot flood draw mode with module drops or consecutive selection screens', () => {
  const game = flowGame();
  for (let i = 0; i < 100; i++) killEnemy(game, createEnemy('drifter', 1, 200, -3000, { elite: true }));
  assert.equal(game.capsules.length, 1);
  game.t = game.nextModuleDropAt;
  killEnemy(game, createEnemy('drifter', 1, 200, -3000, { elite: true }));
  assert.equal(game.capsules.length, 2);
  game.offerQueue.push({ id: 'ram', slot: 'bow', r: 0 }, { id: 'thruster', slot: 'booster', r: 0 });
  update(game, 0.02, flowIdle);
  assert.equal(game.state, 'offer');
  resolveOffer(game, false);
  update(game, 0.02, flowIdle);
  assert.equal(game.state, 'play');
  game.t = game.nextOfferAt;
  update(game, 0.02, flowIdle);
  assert.equal(game.state, 'offer');
  assert.equal(game.currentOffer.id, 'thruster');
  assert.equal(game.nextOfferAt - game.t, CONFIG.drawOfferInterval);
});
