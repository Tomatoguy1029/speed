import { test } from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { buildBundle, buildHtml } from '../build.js';

test('bundle strips module syntax and compiles', () => {
  const js = buildBundle();
  assert.doesNotMatch(js, /^\s*import\s/m);
  assert.doesNotMatch(js, /^\s*export\s/m);
  assert.doesNotThrow(() => new vm.Script(js));
});

test('html embeds bundle and canvas', () => {
  const html = buildHtml();
  assert.match(html, /<canvas id="game"/);
  assert.match(html, /<script>/);
  assert.doesNotMatch(html, /<!--BUNDLE-->/);
});
