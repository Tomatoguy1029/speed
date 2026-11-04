// Effect-only version of the tapered Frost Breath comet (MIT, Copyright (c) 2026 Patch).
// Frost Breath's recipes credit Hugo Duprez, MIT; see ice/frost-breath.js.
import { Painter, fit, createFrame, clearFrame } from '../../core/index.js';
import * as frost from './frost-breath.js';

export const meta = {
  ...frost.meta,
  name: 'Frost comet tail',
  desc: 'The original tapered frost comet effect, with its white nucleus removed.',
  tags: ['ice', 'comet', 'tail', 'directional', 'loop'],
  size: [248, 128],
  origin: [194, 60],
  options: { ...frost.meta.options, spread: 0.10, rootWidth: 19 },
};

const wakeFrame = createFrame(220, 128);
const wake = new Painter(wakeFrame);
const SOURCE_X = 12, SOURCE_Y = 60, FRONT = 13, LENGTH = 170;

function widthAt(x, width) {
  const root = 20;
  if (x <= 0 || x >= LENGTH) return 0;
  if (x < root) return width * Math.sqrt(1 - ((x - root) / root) ** 2);
  return width * Math.pow((LENGTH - x) / (LENGTH - root), 0.8);
}

export function draw(p, t, o) {
  clearFrame(wakeFrame);
  wake.reset().place(SOURCE_X, SOURCE_Y);
  frost.drawBack(wake, t, o);
  frost.draw(wake, t, o);
  const C = fit(o.palette, 8);
  p.glow(0, 0, o.rootWidth * 2, C[5], 0.25);
  // The hand-painted comet can be placed here, at local (0, 0).
  p.each(FRONT - LENGTH, -o.rootWidth - 1, FRONT, o.rootWidth + 1, (x, y, sx, sy) => {
    const along = FRONT - x, width = widthAt(along, o.rootWidth);
    if (width < 0.2 || Math.abs(y) >= width) return;
    const u = along / LENGTH, originalWidth = 2.5 + along * Math.tan(o.spread) * 1.08;
    const sampleX = Math.floor(SOURCE_X + along);
    const sampleY = Math.floor(SOURCE_Y + 7 * u * u + y / width * originalWidth);
    if (sampleX < 0 || sampleX >= wakeFrame.w || sampleY < 0 || sampleY >= wakeFrame.h) return;
    const i = sampleY * wakeFrame.w + sampleX, c = wakeFrame.color[i], light = wakeFrame.light[i];
    const edge = Math.min(1, (width - Math.abs(y)) / 1.5);
    const sheath = (1 - (y / width) ** 2) * Math.pow(1 - u, 0.7);
    p.blendPx(sx, sy, C[4], sheath * 0.12);
    if (c >>> 24) p.blendPx(sx, sy, c, (c >>> 24) / 255 * edge * 0.85);
    if (light & 0xffffff) p.add(sx, sy, light, edge * 0.85);
  });
}
