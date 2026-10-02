import { test } from 'node:test';
import assert from 'node:assert/strict';
import { keyAim, createInput } from '../src/input.js';

function fakeTarget() {
  const h = {};
  return {
    addEventListener: (type, fn) => { (h[type] ||= []).push(fn); },
    fire: (type, props = {}) => { for (const fn of h[type] || []) fn({ preventDefault() {}, ...props }); },
  };
}

test('WASD maps to launch directions, diagonals included', () => {
  assert.deepEqual(keyAim(new Set(['w'])), { x: 0, y: -100 });
  assert.deepEqual(keyAim(new Set(['d'])), { x: 100, y: 0 });
  const diag = keyAim(new Set(['s', 'a']));
  assert.ok(diag.x < 0 && diag.y > 0);
  assert.ok(Math.abs(Math.hypot(diag.x, diag.y) - 100) < 1e-9);
  assert.deepEqual(keyAim(new Set(['w', 's'])), { x: 0, y: 0 });
  assert.deepEqual(keyAim(new Set(['arrowleft'])), { x: -100, y: 0 });
});

test('holding Space charges and releasing launches toward the WASD direction', () => {
  const canvas = fakeTarget(), win = fakeTarget();
  const input = createInput(canvas, win);
  win.fire('keydown', { key: 'd', code: 'KeyD' });
  win.fire('keydown', { key: ' ', code: 'Space' });
  let r = input.read();
  assert.equal(r.charging, true);
  assert.equal(r.release, false);
  assert.ok(r.aimX > 0 && r.aimY === 0);
  win.fire('keydown', { key: 'w', code: 'KeyW' }); // change direction mid-charge
  r = input.read();
  assert.ok(r.aimX > 0 && r.aimY < 0);
  win.fire('keyup', { key: ' ', code: 'Space' });
  r = input.read();
  assert.equal(r.charging, false);
  assert.equal(r.release, true);
  assert.ok(r.aimX > 0 && r.aimY < 0);
  assert.equal(input.read().release, false, 'release is consumed once');
});

test('Space with no direction releases with a zero aim (boost forward)', () => {
  const canvas = fakeTarget(), win = fakeTarget();
  const input = createInput(canvas, win);
  win.fire('keydown', { key: ' ', code: 'Space' });
  win.fire('keyup', { key: ' ', code: 'Space' });
  const r = input.read();
  assert.equal(r.release, true);
  assert.equal(Math.hypot(r.aimX, r.aimY), 0);
});

test('reset drops a held Space so no stray launch happens after a menu', () => {
  const canvas = fakeTarget(), win = fakeTarget();
  const input = createInput(canvas, win);
  win.fire('keydown', { key: ' ', code: 'Space' });
  input.reset();
  win.fire('keyup', { key: ' ', code: 'Space' });
  const r = input.read();
  assert.equal(r.charging, false);
  assert.equal(r.release, false);
});

test('key repeat does not restart the charge', () => {
  const canvas = fakeTarget(), win = fakeTarget();
  const input = createInput(canvas, win);
  win.fire('keydown', { key: ' ', code: 'Space' });
  win.fire('keydown', { key: ' ', code: 'Space', repeat: true });
  assert.equal(input.read().charging, true);
});
