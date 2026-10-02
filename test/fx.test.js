import { test } from 'node:test';
import assert from 'node:assert/strict';
import { SPEED_STAGES, speedStage } from '../src/stages.js';
import { createAudio } from '../src/audio.js';
import { createGame, update, refreshStats } from '../src/world.js';
import { CONFIG } from '../src/config.js';

const idle = { charging: false, aimX: 0, aimY: 0, release: false };

test('speed stages climb with speed and top out at the escape speed', () => {
  assert.equal(speedStage(0), 0);
  assert.equal(speedStage(SPEED_STAGES[0].v + 1), 1);
  assert.equal(speedStage(CONFIG.escapeSpeed), SPEED_STAGES.length);
  for (let i = 1; i < SPEED_STAGES.length; i++) assert.ok(SPEED_STAGES[i].v > SPEED_STAGES[i - 1].v);
});

test('crossing a stage threshold emits one stage event', () => {
  const game = createGame({ seed: 3 });
  game.spawning = false;
  game.field.planet.gm = 0; game.field.moons.length = 0; game.field.dust.length = 0;
  game.ship.vx = 0; game.ship.vy = 0;
  update(game, 0.05, idle);
  game.events.length = 0;
  game.ship.vx = SPEED_STAGES[1].v + 20; game.ship.boostT = 5;
  const ev = [];
  for (let i = 0; i < 5; i++) { update(game, 0.05, idle); ev.push(...game.events); game.events.length = 0; }
  const stages = ev.filter((e) => e.type === 'stage');
  assert.equal(stages.length, 1);
  assert.equal(stages[0].stage, 2);
});

test('sonic boom slows time for a moment', () => {
  const game = createGame({ seed: 3 });
  game.spawning = false;
  game.field.planet.gm = 0; game.field.moons.length = 0; game.field.dust.length = 0;
  game.loadout.gen = { id: 'sonicS', slot: 'gen', r: 1 };
  refreshStats(game);
  game.ship.vx = game.stats.maxSpeed * 0.8; game.ship.vy = 0; game.ship.boostT = 5;
  update(game, 0.05, idle);
  game.ship.vx = game.stats.maxSpeed * 0.97;
  update(game, 0.05, idle);
  assert.ok(game.slowmo > 0);
  update(game, 0.05, idle);
  assert.ok(game.timeScale < 0.5);
});

test('audio is a safe no-op without Web Audio', () => {
  const audio = createAudio();
  assert.doesNotThrow(() => {
    audio.unlock();
    audio.handle([{ type: 'kill' }, { type: 'sonic' }], null);
    audio.update(null, 0.016);
  });
});
