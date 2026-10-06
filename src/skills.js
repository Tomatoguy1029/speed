// Draw-mode skills: the shape of the drawn path picks a skill (straight -> Blink, zigzag -> Lightning,
// inward spiral -> Blast, anything else -> a plain trace). Only the shape test lives here; the
// effects run in world.js where the trace state is.
import { CONFIG } from './config.js';

export const SKILL_INFO = {
  blink: { name: 'BLINK', sub: '一閃', color: '#bff3ff' },
  lightning: { name: 'LIGHTNING', sub: '迅雷', color: '#ffe46b' },
  blast: { name: 'BLAST', sub: '爆縮', color: '#ff9f40' },
};

// Evenly spaced copy of a polyline, so the shape tests do not depend on how fast the mouse moved.
function resamplePath(points, step) {
  const out = [{ x: points[0].x, y: points[0].y }];
  let carry = 0;
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1], b = points[i];
    const len = Math.hypot(b.x - a.x, b.y - a.y);
    let t = step - carry;
    while (t <= len) {
      out.push({ x: a.x + (b.x - a.x) * t / len, y: a.y + (b.y - a.y) * t / len });
      t += step;
    }
    carry = len - (t - step);
  }
  const last = points[points.length - 1], tail = out[out.length - 1];
  if (Math.hypot(last.x - tail.x, last.y - tail.y) > step * 0.3) out.push({ x: last.x, y: last.y });
  return out;
}

// Net angle the path sweeps around its centroid (radians); one loop around it is about ±2π.
// Swept angle (not heading turns) so sharp zigzag corners cannot add up to fake loops.
function windingOf(pts) {
  let cx = 0, cy = 0;
  for (const p of pts) { cx += p.x; cy += p.y; }
  cx /= pts.length; cy /= pts.length;
  let total = 0, prev = Math.atan2(pts[0].y - cy, pts[0].x - cx);
  for (let i = 1; i < pts.length; i++) {
    const a = Math.atan2(pts[i].y - cy, pts[i].x - cx);
    total += Math.atan2(Math.sin(a - prev), Math.cos(a - prev));
    prev = a;
  }
  return total;
}

// How many times the path swings back across its main axis (with a minimum swing size).
function zigzagFlips(pts) {
  let mx = 0, my = 0;
  for (const p of pts) { mx += p.x; my += p.y; }
  mx /= pts.length; my /= pts.length;
  let sxx = 0, syy = 0, sxy = 0;
  for (const p of pts) { const dx = p.x - mx, dy = p.y - my; sxx += dx * dx; syy += dy * dy; sxy += dx * dy; }
  const axis = 0.5 * Math.atan2(2 * sxy, sxx - syy); // principal direction
  const nx = -Math.sin(axis), ny = Math.cos(axis);
  const H = CONFIG.skillZigzagSwing;
  let dir = 0, ext = (pts[0].x - mx) * nx + (pts[0].y - my) * ny, flips = 0;
  for (const p of pts) {
    const v = (p.x - mx) * nx + (p.y - my) * ny;
    if (dir === 0) { if (Math.abs(v - ext) > H) { dir = Math.sign(v - ext); ext = v; } }
    else if (dir > 0) { if (v > ext) ext = v; else if (ext - v > H) { flips++; dir = -1; ext = v; } }
    else if (v < ext) ext = v;
    else if (v - ext > H) { flips++; dir = 1; ext = v; }
  }
  return flips;
}

// Outside -> inside: early points sit much farther from the centroid than late ones.
function spiralsInward(pts) {
  const n = pts.length;
  let cx = 0, cy = 0;
  for (const p of pts) { cx += p.x; cy += p.y; }
  cx /= n; cy /= n;
  const avg = (arr) => arr.reduce((s, p) => s + Math.hypot(p.x - cx, p.y - cy), 0) / arr.length;
  const third = Math.max(1, Math.floor(n / 3));
  return avg(pts.slice(0, third)) > CONFIG.skillSpiralShrink * avg(pts.slice(n - third));
}

// 'blink' | 'lightning' | 'blast' | null
export function classifyPath(points) {
  if (!points || points.length < 2) return null;
  let total = 0;
  for (let i = 1; i < points.length; i++) total += Math.hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y);
  if (total < CONFIG.skillMinLength) return null;
  const pts = resamplePath(points, Math.max(6, total / 160));
  const winding = Math.abs(windingOf(pts));
  if (winding >= CONFIG.skillSpiralTurns * 2 * Math.PI && spiralsInward(pts)) return 'blast';
  const first = points[0], last = points[points.length - 1];
  if (Math.hypot(last.x - first.x, last.y - first.y) >= total * CONFIG.skillStraightness) return 'blink';
  if (winding < 1.2 * Math.PI && zigzagFlips(pts) >= CONFIG.skillZigzagFlips) return 'lightning';
  return null;
}
