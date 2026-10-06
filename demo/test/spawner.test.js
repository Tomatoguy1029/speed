import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PHASES, getPhase, phaseTarget } from '../src/spawner.js';
import { xpForLevel } from '../src/progression.js';
import { CONFIG } from '../src/config.js';

test('phase table covers the whole run in order', () => {
  assert.equal(PHASES[0].start, 0);
  assert.equal(PHASES[PHASES.length - 1].end, CONFIG.runTime);
  for (let i = 1; i < PHASES.length; i++) assert.equal(PHASES[i].start, PHASES[i - 1].end);
});

test('getPhase follows the designed timeline', () => {
  assert.equal(getPhase(10).id, 'build1');
  assert.equal(getPhase(200).id, 'pressure');
  assert.equal(getPhase(270).id, 'build2');
  assert.equal(getPhase(330).id, 'rampage');
  assert.equal(getPhase(450).id, 'tension');
  assert.equal(getPhase(560).id, 'escape');
  assert.equal(getPhase(9999).id, 'escape');
});

test('rampage is the most crowded but its enemies are weaker than pressure', () => {
  const ramp = phaseTarget(330);
  for (const t of [60, 200, 270, 450, 560]) assert.ok(ramp.pop > phaseTarget(t).pop * 1.5, `t=${t}`);
  assert.ok(ramp.level < phaseTarget(200).level);
});

test('enemies get stronger from pressure to tension to escape', () => {
  assert.ok(phaseTarget(200).level > phaseTarget(60).level);
  assert.ok(phaseTarget(450).level > phaseTarget(200).level);
  assert.ok(phaseTarget(580).level > phaseTarget(450).level);
});

test('xp needed grows with level', () => {
  assert.ok(xpForLevel(5) > xpForLevel(0));
});
