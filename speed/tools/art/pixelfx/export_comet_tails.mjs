// Node 18+. Called by generate_comet_effects.py with a pixelfx checkout and output directory.
// pixelfx revision: a84159688af3ca37a4be05a0d422b94451b2e24e (MIT).
import assert from 'node:assert/strict';
import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const [checkoutArg, outputArg] = process.argv.slice(2);
if (!checkoutArg || !outputArg) throw new Error('Usage: node export_comet_tails.mjs PIXELFX_CHECKOUT OUTPUT_DIR');
const checkout = resolve(checkoutArg), output = resolve(outputArg);
const here = dirname(fileURLToPath(import.meta.url));
copyFileSync(join(here, 'frost_comet_tail.js'), join(checkout, 'src/fx/ice/_speed-comet-tail.js'));
const { loadEffect, renderFrames } = await import(pathToFileURL(join(checkout, 'tools/lib/fxlib.mjs')));
const { encodePNG } = await import(pathToFileURL(join(checkout, 'tools/lib/png.mjs')));
const fx = await loadEffect('ice/_speed-comet-tail');
const gold = ['#39220c', '#6e4210', '#a9701c', '#d49b2c', '#f2c557', '#ffe3a0', '#fff1cf', '#fffbea'];

for (const variant of ['normal', 'rare']) {
  const rendered = renderFrames(fx, { options: variant === 'rare' ? { palette: gold } : {} });
  assert.deepEqual([rendered.w, rendered.h, rendered.n], [248, 128, 36]);
  const dir = join(output, variant);
  mkdirSync(dir, { recursive: true });
  for (const [index, frame] of rendered.frames.entries()) {
    const full = new Uint8ClampedArray(248 * 128 * 4);
    for (let i = 0; i < frame.raw.length; i++) {
      const c = frame.raw[i], l = frame.light[i], ca = (c >>> 24) / 255;
      const channels = [0, 8, 16].map(shift => ((c >>> shift) & 255) * ca + ((l >>> shift) & 255));
      // Include color AND additive light when choosing alpha, avoiding clipped blue/gold highlights.
      const a = Math.min(1, Math.max(ca, ...channels.map(v => v / 255)));
      if (a) {
        for (let k = 0; k < 3; k++) full[i * 4 + k] = Math.min(255, channels[k] / a);
        full[i * 4 + 3] = a * 255;
      }
    }
    const coarse = new Uint8ClampedArray(full.length);
    for (let y = 0; y < 128; y += 2) for (let x = 0; x < 248; x += 2) {
      const sum = [0, 0, 0]; let alpha = 0;
      for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) {
        const i = ((y + dy) * 248 + x + dx) * 4, a = full[i + 3];
        alpha += a;
        for (let k = 0; k < 3; k++) sum[k] += full[i + k] * a;
      }
      const rgba = alpha ? [...sum.map(v => Math.round(v / alpha)), Math.round(alpha / 4)] : [0, 0, 0, 0];
      for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) coarse.set(rgba, ((y + dy) * 248 + x + dx) * 4);
    }
    writeFileSync(join(dir, `tail-${String(index).padStart(2, '0')}.png`), encodePNG(248, 128, coarse));
  }
}
console.log('Exported normal and rare tails: 36 frames each, 248x128, 2x2 pixel blocks.');
