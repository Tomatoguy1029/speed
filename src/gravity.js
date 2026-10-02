import { CONFIG } from './config.js';

function pull(out, x, y, b) {
  const dx = b.x - x, dy = b.y - y;
  const d2 = Math.max(dx * dx + dy * dy, b.r * b.r);
  const d = Math.sqrt(d2);
  const a = b.gm / d2;
  out.ax += (dx / d) * a;
  out.ay += (dy / d) * a;
}

export function gravityAt(field, t, x, y) {
  const out = { ax: 0, ay: 0 };
  pull(out, x, y, field.planet);
  for (const m of field.moons) pull(out, x, y, m);
  const r = Math.hypot(x, y);
  if (r > CONFIG.fieldRadius) {
    const push = CONFIG.boundaryPush + (r - CONFIG.fieldRadius) * 4;
    out.ax -= (x / r) * push;
    out.ay -= (y / r) * push;
  }
  return out;
}
