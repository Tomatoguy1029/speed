import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createInput, moveVector } from '../src/input.js';

function fakeTarget() {
  const h = {};
  return {
    addEventListener: (type, fn) => { (h[type] ||= []).push(fn); },
    fire: (type, props = {}) => { for (const fn of h[type] || []) fn({ preventDefault() {}, ...props }); },
  };
}

const press = (win, code, key) => win.fire('keydown', { code, key });
const lift = (win, code, key) => win.fire('keyup', { code, key });

test('A/D cycles follow key presses and repeats; reset clears queued choices and placement', () => {
  const win = fakeTarget(), input = createInput(fakeTarget(), win);
  press(win, 'KeyD', 'd');
  assert.equal(input.read().portalCycle, 1);
  assert.equal(input.read().portalCycle, 0);
  win.fire('keydown', { code: 'KeyD', key: 'd', repeat: true });
  assert.equal(input.read().portalCycle, 1, 'holding D can scan through many candidate lines');
  lift(win, 'KeyD', 'd'); press(win, 'KeyD', 'd'); lift(win, 'KeyD', 'd');
  assert.equal(input.read().portalCycle, 1, 'a tap released before the next frame still chooses');
  press(win, 'KeyB', 'b');
  assert.equal(input.read().place, true);
  assert.equal(input.read().place, false);
  press(win, 'KeyB', 'b'); input.triggerDash(); input.reset();
  const r = input.read();
  assert.equal(r.place, false); assert.equal(r.dash, false); assert.deepEqual(r.move, { x: 0, y: 0 });
});

test('WASD and arrows make a unit move vector; opposite keys cancel', () => {
  assert.deepEqual(moveVector(new Set(['KeyW'])), { x: 0, y: -1 });
  assert.deepEqual(moveVector(new Set(['ArrowRight'])), { x: 1, y: 0 });
  const d = moveVector(new Set(['KeyS', 'KeyA']));
  assert.ok(d.x < 0 && d.y > 0 && Math.abs(Math.hypot(d.x, d.y) - 1) < 1e-9);
  assert.deepEqual(moveVector(new Set(['KeyA', 'KeyD'])), { x: 0, y: 0 });
});

test('raw input: held keys, Space hold and a one-shot Space release', () => {
  const win = fakeTarget();
  const input = createInput(fakeTarget(), win);
  press(win, 'KeyD', 'd');
  assert.deepEqual(input.read().move, { x: 1, y: 0 });
  press(win, 'Space', ' ');
  assert.equal(input.read().space, true);
  win.fire('keydown', { code: 'Space', key: ' ', repeat: true });
  assert.equal(input.read().space, true);
  lift(win, 'Space', ' ');
  let r = input.read();
  assert.equal(r.space, false);
  assert.equal(r.release, true);
  assert.equal(r.releaseSource, 'space');
  assert.equal(input.read().release, false, 'release is consumed once');
});

test('W/S also report a one-shot snap (used by the rotating-aim scheme)', () => {
  const win = fakeTarget();
  const input = createInput(fakeTarget(), win);
  press(win, 'KeyW', 'w');
  assert.equal(input.read().snap, 'forward');
  assert.equal(input.read().snap, null);
  press(win, 'ArrowDown', 'ArrowDown');
  assert.equal(input.read().snap, 'back');
});

test('the pointer is tracked without clicking, and a drag reports its pull', () => {
  const canvas = fakeTarget();
  const input = createInput(canvas, fakeTarget());
  canvas.fire('pointermove', { clientX: 300, clientY: 200, pointerId: 1 });
  assert.deepEqual(input.read().hover, { x: 300, y: 200 });
  canvas.fire('pointerdown', { clientX: 300, clientY: 200, pointerId: 1, button: 0 });
  canvas.fire('pointermove', { clientX: 260, clientY: 230, pointerId: 1 });
  let r = input.read();
  assert.equal(r.pointerDown, true);
  assert.deepEqual(r.drag, { x: 40, y: -30 });
  canvas.fire('pointerup', { clientX: 260, clientY: 230, pointerId: 1 });
  r = input.read();
  assert.equal(r.release, true);
  assert.equal(r.releaseSource, 'pointer');
  assert.deepEqual(r.releaseDrag, { x: 40, y: -30 });
});

test('reset drops a held Space so no stray launch happens after a menu', () => {
  const win = fakeTarget();
  const input = createInput(fakeTarget(), win);
  press(win, 'Space', ' ');
  input.reset();
  lift(win, 'Space', ' ');
  const r = input.read();
  assert.equal(r.space, false);
  assert.equal(r.release, false);
});
