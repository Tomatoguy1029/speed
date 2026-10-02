import { test } from 'node:test';
import assert from 'node:assert/strict';
import { clamp, angleDiff, segCircleT, makeRng, pickWeighted } from '../src/math.js';

test('clamp bounds values', () => {
  assert.equal(clamp(5, 0, 3), 3);
  assert.equal(clamp(-1, 0, 3), 0);
  assert.equal(clamp(2, 0, 3), 2);
});

test('angleDiff returns smallest signed difference', () => {
  assert.ok(Math.abs(angleDiff(0.1, -0.1) - 0.2) < 1e-9);
  assert.ok(Math.abs(angleDiff(Math.PI - 0.1, -Math.PI + 0.1) + 0.2) < 1e-9);
});

test('segCircleT finds entry time along segment', () => {
  const t = segCircleT(0, 0, 100, 0, 50, 0, 10);
  assert.ok(Math.abs(t - 0.4) < 1e-9);
  assert.equal(segCircleT(0, 0, 100, 0, 50, 50, 10), -1);
  assert.equal(segCircleT(50, 0, 100, 0, 50, 0, 10), 0); // starts inside
});

test('makeRng is deterministic per seed', () => {
  const a = makeRng(42), b = makeRng(42);
  for (let i = 0; i < 5; i++) assert.equal(a(), b());
  const v = a();
  assert.ok(v >= 0 && v < 1);
});

test('pickWeighted respects zero weights', () => {
  const rng = makeRng(1);
  for (let i = 0; i < 50; i++) {
    assert.equal(pickWeighted(rng, [['a', 0], ['b', 3]]), 'b');
  }
});
