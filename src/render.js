import { CONFIG } from './config.js';
import { clamp, makeRng, TAU } from './math.js';

const STAR_TILE = 1600;

export function createRenderer(canvas) {
  const ctx = canvas.getContext('2d');
  const rng = makeRng(7);
  const layers = [0.06, 0.16, 0.35].map((p, i) => ({
    p,
    stars: Array.from({ length: 110 - i * 25 }, () => ({ x: rng() * STAR_TILE, y: rng() * STAR_TILE, s: 0.6 + rng() * (0.6 + i * 0.6), a: 0.25 + rng() * 0.6 })),
  }));
  return { canvas, ctx, layers, cam: { x: 0, y: 0, zoom: 1, ready: false }, W: 0, H: 0, dpr: 1, shake: 0, flash: 0 };
}

export function resizeRenderer(r) {
  r.dpr = Math.min(window.devicePixelRatio || 1, 2);
  r.W = window.innerWidth;
  r.H = window.innerHeight;
  r.canvas.width = Math.floor(r.W * r.dpr);
  r.canvas.height = Math.floor(r.H * r.dpr);
}

export function worldToScreen(r, x, y) {
  return { x: (x - r.cam.x) * r.cam.zoom + r.W / 2, y: (y - r.cam.y) * r.cam.zoom + r.H / 2 };
}

function speedZoom(sp) {
  const f = Math.pow(CONFIG.zoomRefSpeed / Math.max(CONFIG.zoomRefSpeed, sp), CONFIG.zoomExp);
  return clamp(f, CONFIG.zoomMin, 1);
}

function updateCamera(r, game, dt) {
  const sh = game.ship;
  const sp = Math.hypot(sh.vx, sh.vy);
  const base = Math.min(r.W, r.H) / CONFIG.baseView;
  const zoomT = base * speedZoom(sp);
  const tx = sh.x + sh.vx * CONFIG.lookAhead;
  const ty = sh.y + sh.vy * CONFIG.lookAhead;
  const cam = r.cam;
  if (!cam.ready) { cam.x = tx; cam.y = ty; cam.zoom = zoomT; cam.ready = true; }
  const kp = 1 - Math.exp(-7 * dt);
  const kz = 1 - Math.exp(-2.2 * dt);
  cam.x += (tx - cam.x) * kp;
  cam.y += (ty - cam.y) * kp;
  cam.zoom += (zoomT - cam.zoom) * kz;
  game.viewRadius = Math.hypot(r.W, r.H) / 2 / cam.zoom;
}

export function render(r, game, dt, pointer) {
  const { ctx } = r;
  updateCamera(r, game, dt);
  ctx.setTransform(r.dpr, 0, 0, r.dpr, 0, 0);
  drawBackground(r, game);

  ctx.save();
  let sx = 0, sy = 0;
  if (r.shake > 0) {
    sx = (Math.random() - 0.5) * r.shake;
    sy = (Math.random() - 0.5) * r.shake;
    r.shake = Math.max(0, r.shake - dt * 60);
  }
  ctx.translate(r.W / 2 + sx, r.H / 2 + sy);
  ctx.scale(r.cam.zoom, r.cam.zoom);
  ctx.translate(-r.cam.x, -r.cam.y);
  drawSpecks(r);
  drawTrail(r, game);
  drawShip(r, game);
  ctx.restore();

  drawChargeUi(r, game, pointer);
  drawHud(r, game);
}

function drawBackground(r, game) {
  const { ctx, W, H } = r;
  ctx.fillStyle = '#04050b';
  ctx.fillRect(0, 0, W, H);
  const sh = game.ship;
  const vx = sh.vx, vy = sh.vy;
  for (const L of r.layers) {
    const ox = ((-r.cam.x * L.p) % STAR_TILE + STAR_TILE) % STAR_TILE;
    const oy = ((-r.cam.y * L.p) % STAR_TILE + STAR_TILE) % STAR_TILE;
    const stretch = Math.min(260, Math.hypot(vx, vy) * L.p * 0.05);
    const sp = Math.hypot(vx, vy) || 1;
    const ux = -vx / sp, uy = -vy / sp;
    ctx.strokeStyle = '#cfe0ff';
    ctx.fillStyle = '#cfe0ff';
    for (const s of L.stars) {
      for (let tx = -STAR_TILE; tx < W + STAR_TILE; tx += STAR_TILE) {
        const x = s.x + ox + tx - STAR_TILE;
        if (x < -20 || x > W + 20) continue;
        for (let ty = -STAR_TILE; ty < H + STAR_TILE; ty += STAR_TILE) {
          const y = s.y + oy + ty - STAR_TILE;
          if (y < -20 || y > H + 20) continue;
          ctx.globalAlpha = s.a;
          if (stretch > 2) {
            ctx.lineWidth = s.s;
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.lineTo(x + ux * stretch, y + uy * stretch);
            ctx.stroke();
          } else {
            ctx.fillRect(x, y, s.s, s.s);
          }
        }
      }
    }
  }
  ctx.globalAlpha = 1;
}

// Procedural dust specks in world space: the main cue for how fast the world flows by.
function drawSpecks(r) {
  const { ctx, cam } = r;
  const cell = 420;
  const halfW = r.W / 2 / cam.zoom, halfH = r.H / 2 / cam.zoom;
  const x0 = Math.floor((cam.x - halfW) / cell), x1 = Math.floor((cam.x + halfW) / cell);
  const y0 = Math.floor((cam.y - halfH) / cell), y1 = Math.floor((cam.y + halfH) / cell);
  ctx.fillStyle = '#7f8db8';
  const size = 2.2 / cam.zoom;
  for (let cx = x0; cx <= x1; cx++) {
    for (let cy = y0; cy <= y1; cy++) {
      let h = (cx * 73856093) ^ (cy * 19349663);
      for (let k = 0; k < 3; k++) {
        h = Math.imul(h ^ (h >>> 13), 0x5bd1e995) >>> 0;
        const px = cx * cell + (h & 1023) / 1023 * cell;
        h = Math.imul(h ^ (h >>> 15), 0x27d4eb2d) >>> 0;
        const py = cy * cell + (h & 1023) / 1023 * cell;
        ctx.globalAlpha = 0.35 + ((h >>> 12) & 7) / 14;
        ctx.fillRect(px, py, size, size);
      }
    }
  }
  ctx.globalAlpha = 1;
}

function drawTrail(r, game) {
  const { ctx } = r;
  const sh = game.ship;
  const tr = sh.trail;
  if (tr.length < 2) return;
  const sp = Math.hypot(sh.vx, sh.vy);
  const ratio = sp / game.stats.maxSpeed;
  const n = Math.min(tr.length, Math.round(6 + clamp(ratio, 0, 2) * 55));
  const start = tr.length - n;
  const hot = clamp((ratio - 0.85) / 0.4, 0, 1);
  ctx.lineCap = 'round';
  for (let i = start + 1; i < tr.length; i++) {
    const a = (i - start) / n;
    ctx.globalAlpha = a * 0.85;
    ctx.strokeStyle = hot > 0 ? `rgb(${120 + 135 * hot},${220 + 35 * hot},255)` : '#5fd8ff';
    ctx.lineWidth = (CONFIG.shipRadius * 1.1) * a + 1 / r.cam.zoom;
    ctx.beginPath();
    ctx.moveTo(tr[i - 1].x, tr[i - 1].y);
    ctx.lineTo(tr[i].x, tr[i].y);
    ctx.stroke();
  }
  ctx.beginPath();
  ctx.moveTo(tr[tr.length - 1].x, tr[tr.length - 1].y);
  ctx.lineTo(sh.x, sh.y);
  ctx.stroke();
  ctx.globalAlpha = 1;
}

function drawShip(r, game) {
  const { ctx } = r;
  const sh = game.ship;
  let ang = Math.atan2(sh.vy, sh.vx);
  if (sh.charging && Math.hypot(sh.aimX, sh.aimY) >= CONFIG.minDrag) ang = Math.atan2(sh.aimY, sh.aimX);
  const R = CONFIG.shipRadius;
  const minPx = 9 / r.cam.zoom;
  const s = Math.max(R, minPx);
  ctx.save();
  ctx.translate(sh.x, sh.y);
  ctx.rotate(ang);
  if (sh.invulnT > 0 && Math.floor(game.t * 20) % 2 === 0) ctx.globalAlpha = 0.4;
  ctx.shadowColor = '#5fd8ff';
  ctx.shadowBlur = 18;
  ctx.fillStyle = '#e8f6ff';
  ctx.beginPath();
  ctx.moveTo(s * 1.3, 0);
  ctx.lineTo(-s * 0.9, s * 0.8);
  ctx.lineTo(-s * 0.5, 0);
  ctx.lineTo(-s * 0.9, -s * 0.8);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function drawChargeUi(r, game, pointer) {
  const sh = game.ship;
  if (!sh.charging) return;
  const { ctx } = r;
  const p = worldToScreen(r, sh.x, sh.y);
  const g = sh.gauge;
  const full = g >= 1;
  // gauge ring
  ctx.lineWidth = 5;
  ctx.strokeStyle = 'rgba(255,255,255,0.15)';
  ctx.beginPath(); ctx.arc(p.x, p.y, 34, 0, TAU); ctx.stroke();
  ctx.strokeStyle = g > 1 ? '#ff9f40' : full ? '#ffe46b' : '#5fd8ff';
  ctx.beginPath(); ctx.arc(p.x, p.y, 34, -Math.PI / 2, -Math.PI / 2 + TAU * Math.min(1, g)); ctx.stroke();
  if (g > 1) {
    ctx.strokeStyle = '#ff5a3c';
    ctx.beginPath(); ctx.arc(p.x, p.y, 40, -Math.PI / 2, -Math.PI / 2 + TAU * (g - 1) / Math.max(0.01, game.stats.gaugeMax - 1)); ctx.stroke();
  }
  // aim arrow
  const len = Math.hypot(sh.aimX, sh.aimY);
  if (len >= CONFIG.minDrag) {
    const ux = sh.aimX / len, uy = sh.aimY / len;
    const L = 50 + 90 * Math.min(1.5, g);
    ctx.strokeStyle = full ? '#ffe46b' : '#9fe8ff';
    ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(p.x + ux * 40, p.y + uy * 40); ctx.lineTo(p.x + ux * L, p.y + uy * L); ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(p.x + ux * (L + 12), p.y + uy * (L + 12));
    ctx.lineTo(p.x + ux * L - uy * 8, p.y + uy * L + ux * 8);
    ctx.lineTo(p.x + ux * L + uy * 8, p.y + uy * L - ux * 8);
    ctx.closePath();
    ctx.fillStyle = ctx.strokeStyle; ctx.fill();
  }
  // drag rubber band (screen space)
  if (pointer && pointer.down) {
    ctx.strokeStyle = 'rgba(255,255,255,0.25)';
    ctx.lineWidth = 1.5;
    ctx.setLineDash([4, 6]);
    ctx.beginPath(); ctx.moveTo(pointer.sx, pointer.sy); ctx.lineTo(pointer.cx, pointer.cy); ctx.stroke();
    ctx.setLineDash([]);
    ctx.beginPath(); ctx.arc(pointer.sx, pointer.sy, 6, 0, TAU); ctx.stroke();
  }
}

function drawHud(r, game) {
  const { ctx, W, H } = r;
  const sp = Math.hypot(game.ship.vx, game.ship.vy);
  ctx.textAlign = 'center';
  ctx.fillStyle = '#e8f0ff';
  ctx.font = '700 34px ui-monospace, Menlo, monospace';
  ctx.fillText(`${(sp * CONFIG.speedToKms).toFixed(2)}`, W / 2, H - 46);
  ctx.font = '12px ui-monospace, Menlo, monospace';
  ctx.fillStyle = '#8fa3c8';
  ctx.fillText('km/s', W / 2, H - 28);
}
