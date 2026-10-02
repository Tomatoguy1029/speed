import { CONFIG } from './config.js';
import { clamp, makeRng, TAU } from './math.js';
import { predictPath, annotatePrediction, previewPath, drawBudget, traceRadius } from './world.js';
import { attackPower, CRIT_ARMOR } from './combat.js';
import { xpForLevel } from './progression.js';
import { getPhase } from './spawner.js';
import { SLOTS, RARITIES, moduleDef } from './modules.js';
import { drawPart, drawShipAssembly } from './parts.js';

const STAR_TILE = 1600;
const MONO = 'ui-monospace, Menlo, monospace';

export function createRenderer(canvas) {
  const ctx = canvas.getContext('2d');
  const rng = makeRng(7);
  const layers = [0.06, 0.16, 0.35].map((p, i) => ({
    p,
    stars: Array.from({ length: 110 - i * 25 }, () => ({ x: rng() * STAR_TILE, y: rng() * STAR_TILE, s: 0.6 + rng() * (0.6 + i * 0.6), a: 0.25 + rng() * 0.6 })),
  }));
  return { canvas, ctx, layers, cam: { x: 0, y: 0, zoom: 1, ready: false }, W: 0, H: 0, dpr: 1, shake: 0, flash: 0, vapor: 0, zoomPunch: 0, stageFlash: null, hurt: 0 };
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

export function screenToWorld(r, x, y) {
  return { x: (x - r.W / 2) / r.cam.zoom + r.cam.x, y: (y - r.H / 2) / r.cam.zoom + r.cam.y };
}

// Zoom is tied to the ship's max speed so the view only widens as the build gets faster,
// instead of pumping in and out with every dash.
export function targetZoom(game, W, H) {
  const f = Math.pow(CONFIG.zoomRefSpeed / Math.max(CONFIG.zoomRefSpeed, game.stats.maxSpeed), CONFIG.zoomExp);
  return (Math.min(W, H) / CONFIG.baseView) * clamp(f, CONFIG.zoomMin, 1);
}

function updateCamera(r, game, dt) {
  const sh = game.ship;
  if (game.draw && r.cam.ready) {
    // hold the view still while a path is drawn and traced, so it is followed exactly where it was drawn
    game.viewRadius = Math.hypot(r.W, r.H) / 2 / r.cam.zoom;
    return;
  }
  const zoomT = targetZoom(game, r.W, r.H);
  // look ahead along the velocity, but keep the ship well inside the screen at any speed
  let ox = sh.vx * CONFIG.lookAhead, oy = sh.vy * CONFIG.lookAhead;
  const maxOff = (0.3 * Math.min(r.W, r.H)) / 2 / zoomT;
  const off = Math.hypot(ox, oy);
  if (off > maxOff) { ox *= maxOff / off; oy *= maxOff / off; }
  const tx = sh.x + ox;
  const ty = sh.y + oy;
  const cam = r.cam;
  if (!cam.ready) { cam.x = tx; cam.y = ty; cam.zoom = zoomT; cam.ready = true; }
  const kp = 1 - Math.exp(-7 * dt);
  const kz = 1 - Math.exp(-2.2 * dt);
  cam.x += (tx - cam.x) * kp;
  cam.y += (ty - cam.y) * kp;
  cam.zoom += (zoomT - cam.zoom) * kz;
  if (r.zoomPunch > 0) { cam.zoom *= 1 + r.zoomPunch; r.zoomPunch = Math.max(0, r.zoomPunch - dt * 0.5); }
  game.viewRadius = Math.hypot(r.W, r.H) / 2 / cam.zoom;
}

function handleEvents(r, game) {
  for (const ev of game.events) {
    if (ev.type === 'phase') r.banner = { text: ev.phase.name, sub: ev.phase.sub, life: 3, max: 3 };
    else if (ev.type === 'hurt') { r.shake = Math.max(r.shake, 14); r.hurt = 0.35; }
    else if (ev.type === 'kill' && ev.r > 25) r.shake = Math.max(r.shake, 8);
    else if (ev.type === 'kill' && ev.cause === 'ram') r.shake = Math.max(r.shake, 5);
    else if (ev.type === 'bounce') r.shake = Math.max(r.shake, 10);
    else if (ev.type === 'crash') r.shake = Math.max(r.shake, 16);
    else if (ev.type === 'stage') { r.stageFlash = { text: ev.name, kms: (ev.speed * CONFIG.speedToKms).toFixed(1), life: 1.4, max: 1.4 }; r.flash = Math.max(r.flash, 0.18); }
    else if (ev.type === 'sonic') { r.flash = 0.8; r.shake = Math.max(r.shake, 34); r.zoomPunch = 0.14; }
    else if (ev.type === 'barrier') r.vapor = 0.6;
    else if (ev.type === 'end' && ev.state === 'won') r.flash = 1;
  }
}

export function render(r, game, dt, pointer) {
  const { ctx } = r;
  handleEvents(r, game);
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
  drawZones(r);
  drawDust(r, game);
  drawSpecks(r);
  drawBodies(r, game);
  drawGems(r, game);
  drawCoins(r, game);
  drawCapsules(r, game);
  drawMines(r, game);
  drawEnemies(r, game);
  drawEnemyBullets(r, game);
  drawPathUi(r, game);
  drawFriendly(r, game);
  drawPrediction(r, game);
  drawTrail(r, game);
  drawVapor(r, game, dt);
  drawShip(r, game);
  drawFx(r, game);
  ctx.restore();
  drawSpeedLines(r, game);

  drawChargeUi(r, game, pointer);
  drawCapsuleArrows(r, game);
  drawDrawingHud(r, game);
  drawOverlays(r, game, dt);
  drawHud(r, game);
  drawMinimap(r, game);
  drawBanner(r, dt);
  drawStageFlash(r, dt);
  if (r.flash > 0) {
    ctx.fillStyle = `rgba(255,255,255,${Math.min(0.85, r.flash)})`;
    ctx.fillRect(0, 0, r.W, r.H);
    r.flash = Math.max(0, r.flash - dt * 2.2);
  }
}

// Conical shock layers wrapped around the ship near max speed.
function drawVapor(r, game, dt) {
  const sh = game.ship;
  const sp = Math.hypot(sh.vx, sh.vy);
  const ratio = sp / game.stats.maxSpeed;
  if (r.vapor > 0) r.vapor -= dt;
  const k = Math.max(r.vapor > 0 ? 1 : 0, (ratio - 0.88) / 0.12);
  if (k <= 0 || sp < 1) return;
  const { ctx } = r;
  const z = r.cam.zoom;
  const ux = sh.vx / sp, uy = sh.vy / sp;
  const back = Math.atan2(-uy, -ux);
  ctx.save();
  ctx.translate(sh.x, sh.y);
  ctx.lineCap = 'round';
  const unit = Math.max(1, 0.6 / z);
  for (let i = 0; i < 4; i++) {
    const rad = (26 + i * 16) * unit;
    const spread = 1.25 - i * 0.18;
    ctx.globalAlpha = Math.min(1, k) * (0.5 - i * 0.1) * (0.75 + 0.25 * Math.random());
    ctx.strokeStyle = '#eaf6ff';
    ctx.lineWidth = (3 - i * 0.5) * unit;
    ctx.beginPath();
    ctx.arc(-ux * (i * 10 - 14) * unit, -uy * (i * 10 - 14) * unit, rad, back - spread, back + spread);
    ctx.stroke();
  }
  ctx.restore();
  ctx.globalAlpha = 1;
}

function drawSpeedLines(r, game) {
  const sh = game.ship;
  const sp = Math.hypot(sh.vx, sh.vy);
  const k = (sp / CONFIG.escapeSpeed - 0.42) / 0.5;
  if (k <= 0) return;
  const { ctx, W, H } = r;
  const cx = W / 2, cy = H / 2;
  const R0 = Math.hypot(W, H) / 2;
  ctx.strokeStyle = '#dff3ff';
  ctx.lineWidth = 1.5;
  const n = Math.round(18 + 40 * Math.min(1, k));
  for (let i = 0; i < n; i++) {
    const a = Math.random() * TAU;
    const r1 = R0 * (0.62 + Math.random() * 0.2 * (1 - Math.min(1, k)));
    ctx.globalAlpha = Math.min(0.5, 0.15 + 0.35 * k) * Math.random();
    ctx.beginPath();
    ctx.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1);
    ctx.lineTo(cx + Math.cos(a) * R0, cy + Math.sin(a) * R0);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}

function drawStageFlash(r, dt) {
  const f = r.stageFlash;
  if (!f) return;
  f.life -= dt;
  if (f.life <= 0) { r.stageFlash = null; return; }
  const { ctx, W, H } = r;
  const t = 1 - f.life / f.max;
  ctx.globalAlpha = Math.min(1, f.life / 0.4);
  ctx.textAlign = 'center';
  ctx.fillStyle = '#bff3ff';
  ctx.font = `italic 800 ${Math.round(30 + 10 * (1 - t))}px ${MONO}`;
  ctx.fillText(f.text, W / 2, H * 0.68);
  ctx.font = `13px ${MONO}`;
  ctx.fillStyle = '#8fd8ff';
  ctx.fillText(`${f.kms} km/s`, W / 2, H * 0.68 + 20);
  const sweep = W * (t * 1.4 - 0.2);
  const g = ctx.createLinearGradient(sweep - 160, 0, sweep + 160, 0);
  g.addColorStop(0, 'rgba(191,243,255,0)');
  g.addColorStop(0.5, 'rgba(191,243,255,0.5)');
  g.addColorStop(1, 'rgba(191,243,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, H * 0.68 - 36, W, 2);
  ctx.globalAlpha = 1;
}

function drawGems(r, game) {
  const { ctx } = r;
  const s = Math.max(5, 3 / r.cam.zoom);
  ctx.fillStyle = '#6dffb0';
  for (const g of game.gems) {
    if (!onScreen(r, g.x, g.y, 20)) continue;
    const k = g.v > 8 ? 1.6 : g.v > 3 ? 1.25 : 1;
    ctx.beginPath();
    ctx.moveTo(g.x, g.y - s * k); ctx.lineTo(g.x + s * 0.7 * k, g.y); ctx.lineTo(g.x, g.y + s * k); ctx.lineTo(g.x - s * 0.7 * k, g.y);
    ctx.closePath(); ctx.fill();
  }
}

function capsuleColor(c) {
  return c.kind === 'core' ? '#ffd24a' : RARITIES[c.mod.r].color;
}

function drawCoins(r, game) {
  const { ctx } = r;
  const s = Math.max(6, 3.5 / r.cam.zoom);
  for (const c of game.coinDrops) {
    if (!onScreen(r, c.x, c.y, 20)) continue;
    ctx.fillStyle = '#ffd24a';
    ctx.beginPath(); ctx.arc(c.x, c.y, s, 0, TAU); ctx.fill();
    ctx.fillStyle = '#a07a10';
    ctx.fillRect(c.x - s * 0.15, c.y - s * 0.55, s * 0.3, s * 1.1);
  }
}

function drawCapsules(r, game) {
  const { ctx } = r;
  const z = r.cam.zoom;
  for (const c of game.capsules) {
    if (!onScreen(r, c.x, c.y, 200)) continue;
    const col = capsuleColor(c);
    const S = (c.kind === 'core' ? 30 : 20) * Math.max(1, 0.7 / z);
    const pulse = (game.t * 1.5 + c.x * 0.001) % 1;
    ctx.globalAlpha = 1 - pulse;
    ctx.strokeStyle = col;
    ctx.lineWidth = 2 / z;
    ctx.beginPath(); ctx.arc(c.x, c.y, S * (1.2 + pulse * 2.5), 0, TAU); ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.save();
    ctx.translate(c.x, c.y + Math.sin(game.t * 2 + c.x) * S * 0.12);
    if (c.kind === 'core') {
      ctx.rotate(game.t * 1.2);
      ctx.shadowColor = col; ctx.shadowBlur = 20;
      ctx.fillStyle = col;
      ctx.beginPath();
      for (let i = 0; i < 10; i++) { const a = i * TAU / 10, k = i % 2 ? 0.45 : 1; ctx.lineTo(Math.cos(a) * S * k, Math.sin(a) * S * k); }
      ctx.closePath(); ctx.fill();
      ctx.fillStyle = '#ffffff';
      ctx.beginPath(); ctx.arc(0, 0, S * 0.22, 0, TAU); ctx.fill();
    } else {
      // the module shows up as the ship part it is (nose, engine, gun, radar, wings, reactor)
      drawPart(ctx, c.mod.slot, S * 0.95, col, { glow: 22 });
    }
    ctx.restore();
  }
}

// Edge-of-screen pointers to capsules that are off screen.
function drawCapsuleArrows(r, game) {
  const { ctx, W, H } = r;
  const sh = game.ship;
  const m = 34;
  for (const c of game.capsules) {
    const d = Math.hypot(c.x - sh.x, c.y - sh.y);
    if (d > 5000 || onScreen(r, c.x, c.y, 0)) continue;
    const p = worldToScreen(r, c.x, c.y);
    const ang = Math.atan2(p.y - H / 2, p.x - W / 2);
    const k = Math.min((W / 2 - m) / Math.abs(Math.cos(ang) || 1e-6), (H / 2 - m) / Math.abs(Math.sin(ang) || 1e-6));
    const x = W / 2 + Math.cos(ang) * k, y = H / 2 + Math.sin(ang) * k;
    ctx.save();
    ctx.translate(x, y); ctx.rotate(ang);
    ctx.globalAlpha = 0.55 + 0.45 * (1 - d / 5000);
    ctx.fillStyle = capsuleColor(c);
    const s = c.kind === 'core' ? 13 : 9;
    ctx.beginPath(); ctx.moveTo(s, 0); ctx.lineTo(-s * 0.7, s * 0.7); ctx.lineTo(-s * 0.7, -s * 0.7); ctx.closePath(); ctx.fill();
    ctx.restore();
  }
  ctx.globalAlpha = 1;
}

function drawMines(r, game) {
  const { ctx } = r;
  const z = r.cam.zoom;
  for (const m of game.mines) {
    if (!onScreen(r, m.x, m.y, 30)) continue;
    ctx.fillStyle = m.armed > 0 ? '#7a5040' : (Math.floor(game.t * 6) % 2 ? '#ff7b54' : '#ffb08a');
    ctx.beginPath(); ctx.arc(m.x, m.y, 7 / Math.sqrt(z), 0, TAU); ctx.fill();
  }
  ctx.fillStyle = 'rgba(255,207,107,0.5)';
  for (const m of game.marks) {
    if (!onScreen(r, m.x, m.y, 30)) continue;
    ctx.beginPath(); ctx.arc(m.x, m.y, (4 + 6 * (1 - m.t / 0.55)) / Math.sqrt(z), 0, TAU); ctx.fill();
  }
}

function drawFriendly(r, game) {
  const { ctx } = r;
  const z = r.cam.zoom;
  for (const b of game.fbullets) {
    if (!onScreen(r, b.x, b.y, 40)) continue;
    ctx.fillStyle = b.color;
    ctx.globalAlpha = b.kind === 'corpse' ? 0.85 : 1;
    const s = b.kind === 'corpse' ? b.r * 0.6 : b.r / Math.sqrt(z);
    ctx.beginPath(); ctx.arc(b.x, b.y, s, 0, TAU); ctx.fill();
  }
  ctx.globalAlpha = 1;
}

function drawOverlays(r, game, dt) {
  const { ctx, W, H } = r;
  if (r.hurt > 0) {
    r.hurt -= dt;
    const g = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.3, W / 2, H / 2, Math.max(W, H) * 0.7);
    g.addColorStop(0, 'rgba(255,40,40,0)');
    g.addColorStop(1, `rgba(255,40,40,${0.5 * r.hurt / 0.35})`);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
  }
  const lowHp = game.ship.hp / game.stats.maxHp;
  if (lowHp < 0.3 && game.state === 'play') {
    const a = (0.3 - lowHp) * (0.6 + 0.4 * Math.sin(game.t * 8));
    ctx.strokeStyle = `rgba(255,50,50,${a})`;
    ctx.lineWidth = 16;
    ctx.strokeRect(0, 0, W, H);
  }
}

function drawBanner(r, dt) {
  const b = r.banner;
  if (!b) return;
  b.life -= dt;
  if (b.life <= 0) { r.banner = null; return; }
  const { ctx, W, H } = r;
  const t = b.max - b.life;
  const a = Math.min(1, t / 0.25, b.life / 0.6);
  ctx.globalAlpha = a;
  ctx.textAlign = 'center';
  ctx.fillStyle = '#ffffff';
  ctx.font = `800 ${Math.min(54, W / 10)}px "Hiragino Sans", "Noto Sans JP", sans-serif`;
  ctx.fillText(b.text, W / 2, H * 0.3);
  if (b.sub) {
    ctx.font = `16px "Hiragino Sans", "Noto Sans JP", sans-serif`;
    ctx.fillStyle = '#b8c6ea';
    ctx.fillText(b.sub, W / 2, H * 0.3 + 30);
  }
  ctx.globalAlpha = 1;
}

function drawZones(r) {
  const { ctx } = r;
  const z = r.cam.zoom;
  const g = ctx.createRadialGradient(0, 0, CONFIG.planetRadius, 0, 0, CONFIG.zoneInner);
  g.addColorStop(0, 'rgba(255,70,50,0.16)');
  g.addColorStop(1, 'rgba(255,70,50,0.02)');
  ctx.fillStyle = g;
  ctx.beginPath(); ctx.arc(0, 0, CONFIG.zoneInner, 0, TAU); ctx.fill();
  ctx.fillStyle = 'rgba(150,70,255,0.07)';
  ctx.beginPath();
  ctx.arc(0, 0, CONFIG.fieldRadius, 0, TAU);
  ctx.arc(0, 0, CONFIG.zoneOuter, 0, TAU, true);
  ctx.fill();
  ctx.lineWidth = 2 / z;
  ctx.setLineDash([30 / z, 24 / z]);
  ctx.strokeStyle = 'rgba(255,110,90,0.35)';
  ctx.beginPath(); ctx.arc(0, 0, CONFIG.zoneInner, 0, TAU); ctx.stroke();
  ctx.strokeStyle = 'rgba(170,120,255,0.35)';
  ctx.beginPath(); ctx.arc(0, 0, CONFIG.zoneOuter, 0, TAU); ctx.stroke();
  ctx.setLineDash([]);
  ctx.lineWidth = 6 / z;
  ctx.strokeStyle = 'rgba(190,120,255,0.8)';
  ctx.beginPath(); ctx.arc(0, 0, CONFIG.fieldRadius, 0, TAU); ctx.stroke();
}

function drawDust(r, game) {
  const { ctx } = r;
  for (const d of game.field.dust) {
    if (!onScreen(r, d.x, d.y, d.r)) continue;
    const g = ctx.createRadialGradient(d.x, d.y, 0, d.x, d.y, d.r);
    g.addColorStop(0, 'rgba(170,130,210,0.20)');
    g.addColorStop(0.7, 'rgba(140,100,190,0.10)');
    g.addColorStop(1, 'rgba(140,100,190,0)');
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(d.x, d.y, d.r, 0, TAU); ctx.fill();
  }
}

function onScreen(r, x, y, rad) {
  const halfW = r.W / 2 / r.cam.zoom + rad, halfH = r.H / 2 / r.cam.zoom + rad;
  return Math.abs(x - r.cam.x) < halfW && Math.abs(y - r.cam.y) < halfH;
}

function drawBodies(r, game) {
  const { ctx } = r;
  const p = game.field.planet;
  if (onScreen(r, p.x, p.y, p.r * 1.6)) {
    const halo = ctx.createRadialGradient(0, 0, p.r * 0.9, 0, 0, p.r * 1.6);
    halo.addColorStop(0, 'rgba(90,160,255,0.45)');
    halo.addColorStop(1, 'rgba(90,160,255,0)');
    ctx.fillStyle = halo;
    ctx.beginPath(); ctx.arc(0, 0, p.r * 1.6, 0, TAU); ctx.fill();
    const body = ctx.createRadialGradient(-p.r * 0.35, -p.r * 0.35, p.r * 0.1, 0, 0, p.r);
    body.addColorStop(0, '#6a8cff');
    body.addColorStop(0.6, '#2b3d8f');
    body.addColorStop(1, '#0d1238');
    ctx.fillStyle = body;
    ctx.beginPath(); ctx.arc(0, 0, p.r, 0, TAU); ctx.fill();
    ctx.save();
    ctx.beginPath(); ctx.arc(0, 0, p.r, 0, TAU); ctx.clip();
    ctx.strokeStyle = 'rgba(160,190,255,0.12)';
    ctx.lineWidth = p.r * 0.08;
    for (let i = -3; i <= 3; i++) {
      ctx.beginPath(); ctx.ellipse(0, i * p.r * 0.25, p.r * 1.1, p.r * 0.06, 0.15, 0, TAU); ctx.stroke();
    }
    ctx.restore();
  }
  for (const m of game.field.moons) {
    if (!onScreen(r, m.x, m.y, m.r * 3)) continue;
    const halo = ctx.createRadialGradient(m.x, m.y, m.r, m.x, m.y, m.r * 3);
    halo.addColorStop(0, 'rgba(200,170,120,0.12)');
    halo.addColorStop(1, 'rgba(200,170,120,0)');
    ctx.fillStyle = halo;
    ctx.beginPath(); ctx.arc(m.x, m.y, m.r * 3, 0, TAU); ctx.fill();
    const body = ctx.createRadialGradient(m.x - m.r * 0.3, m.y - m.r * 0.3, m.r * 0.1, m.x, m.y, m.r);
    body.addColorStop(0, '#b9a58a');
    body.addColorStop(1, '#4a3d33');
    ctx.fillStyle = body;
    ctx.beginPath(); ctx.arc(m.x, m.y, m.r, 0, TAU); ctx.fill();
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    for (let k = 0; k < 4; k++) {
      const a = k * 1.9 + m.orbit, d = m.r * (0.2 + 0.15 * k);
      ctx.beginPath(); ctx.arc(m.x + Math.cos(a) * d, m.y + Math.sin(a) * d, m.r * 0.16, 0, TAU); ctx.fill();
    }
  }
}

// Draw scheme: while charging, show how far a path could reach.
function drawReach(r, game) {
  const sh = game.ship;
  const reach = drawBudget(game, sh.gauge);
  const { ctx } = r;
  const z = r.cam.zoom;
  ctx.strokeStyle = sh.gauge >= 1 ? 'rgba(255,228,107,0.7)' : 'rgba(159,232,255,0.55)';
  ctx.lineWidth = 2 / z;
  ctx.setLineDash([14 / z, 10 / z]);
  ctx.beginPath(); ctx.arc(sh.x, sh.y, reach, 0, TAU); ctx.stroke();
  ctx.setLineDash([]);
}

function drawPathUi(r, game) {
  const d = game.draw;
  if (!d) return;
  const { ctx } = r;
  const z = r.cam.zoom;
  const sh = game.ship;
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  if (d.phase === 'run') {
    ctx.strokeStyle = 'rgba(159,232,255,0.14)';
    ctx.lineWidth = traceRadius(game) * 2;
    ctx.beginPath(); ctx.moveTo(sh.x, sh.y);
    for (let i = d.seg + 1; i < d.path.length; i++) ctx.lineTo(d.path[i].x, d.path[i].y);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(159,232,255,0.4)';
    ctx.lineWidth = 4 / z;
    ctx.setLineDash([10 / z, 8 / z]);
    ctx.beginPath(); ctx.moveTo(sh.x, sh.y);
    for (let i = d.seg + 1; i < d.path.length; i++) ctx.lineTo(d.path[i].x, d.path[i].y);
    ctx.stroke();
    ctx.setLineDash([]);
    return;
  }
  const pts = d.points;
  const line = () => { ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y); for (const p of pts) ctx.lineTo(p.x, p.y); };
  if (pts.length > 1) {
    // the band is the real hit width of the trace
    line(); ctx.strokeStyle = 'rgba(95,216,255,0.16)'; ctx.lineWidth = traceRadius(game) * 2; ctx.stroke();
    line(); ctx.strokeStyle = 'rgba(159,232,255,0.35)'; ctx.lineWidth = 2 / z; ctx.setLineDash([]);
    ctx.stroke();
    line(); ctx.strokeStyle = '#d6f6ff'; ctx.lineWidth = 3.5 / z; ctx.stroke();
  }
  const last = pts[pts.length - 1];
  if (d.cursor && d.used < d.budget - 0.5) {
    ctx.strokeStyle = 'rgba(214,246,255,0.3)';
    ctx.lineWidth = 2 / z;
    ctx.setLineDash([6 / z, 8 / z]);
    ctx.beginPath(); ctx.moveTo(last.x, last.y); ctx.lineTo(d.cursor.x, d.cursor.y); ctx.stroke();
    ctx.setLineDash([]);
  }
  const pv = previewPath(game);
  // enemies the band will cut: white ring, yellow if through the weak spot
  for (const [e, t] of pv.targets) {
    ctx.strokeStyle = t.crit ? '#ffe46b' : 'rgba(255,255,255,0.9)';
    ctx.lineWidth = 3 / z;
    ctx.beginPath(); ctx.arc(e.x, e.y, e.r + 7 / z, 0, TAU); ctx.stroke();
  }
  ctx.fillStyle = '#ffe46b';
  for (const p of pv.samples) if (p.hot) { ctx.beginPath(); ctx.arc(p.x, p.y, 6 / z, 0, TAU); ctx.fill(); }
  if (pv.block) {
    const k = 12 / z, b = pv.block;
    ctx.strokeStyle = '#ff4d4d'; ctx.lineWidth = 4 / z;
    ctx.beginPath(); ctx.moveTo(b.x - k, b.y - k); ctx.lineTo(b.x + k, b.y + k); ctx.moveTo(b.x + k, b.y - k); ctx.lineTo(b.x - k, b.y + k); ctx.stroke();
  }
  ctx.fillStyle = '#ffffff';
  ctx.beginPath(); ctx.arc(last.x, last.y, 5 / z, 0, TAU); ctx.fill();
}

// Screen-space: slow-time vignette and the remaining length / time while drawing.
function drawDrawingHud(r, game) {
  const d = game.draw;
  if (!d || d.phase !== 'draw') return;
  const { ctx, W, H } = r;
  const g = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.35, W / 2, H / 2, Math.max(W, H) * 0.75);
  g.addColorStop(0, 'rgba(40,80,200,0)');
  g.addColorStop(1, 'rgba(40,80,200,0.35)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);
  const bw = Math.min(320, W * 0.5), x = W / 2 - bw / 2, y = H * 0.72;
  const bar = (yy, frac, color, label) => {
    ctx.fillStyle = 'rgba(255,255,255,0.12)'; ctx.fillRect(x, yy, bw, 6);
    ctx.fillStyle = color; ctx.fillRect(x, yy, bw * Math.max(0, Math.min(1, frac)), 6);
    ctx.fillStyle = '#b8c6ea'; ctx.font = `11px ${MONO}`; ctx.textAlign = 'right'; ctx.fillText(label, x - 8, yy + 6);
  };
  bar(y, 1 - d.used / d.budget, '#9fe8ff', '長さ');
  bar(y + 14, d.timeLeft / CONFIG.drawTime, '#ffd24a', '時間');
  ctx.textAlign = 'center';
  ctx.fillStyle = '#e8f6ff';
  ctx.font = '14px "Hiragino Sans", "Noto Sans JP", sans-serif';
  ctx.fillText('カーソルで軌跡を描く — Space／クリックで駆け抜ける', W / 2, y - 12);
}

function drawPrediction(r, game) {
  const sh = game.ship;
  if (!sh.charging) return;
  if (game.scheme === 'draw') { drawReach(r, game); return; }
  let ax = sh.aimX, ay = sh.aimY;
  if (Math.hypot(ax, ay) < CONFIG.minDrag) { ax = sh.vx; ay = sh.vy; }
  if (Math.hypot(ax, ay) < 1) return;
  const pts = annotatePrediction(game, predictPath(game, ax, ay, sh.gauge, game.stats.predictTime), game.stats.predictTime);
  const { ctx } = r;
  const dot = 3.2 / r.cam.zoom;
  for (let i = 2; i < pts.length; i += 3) {
    const p = pts[i];
    ctx.globalAlpha = 0.85 * (1 - i / pts.length) + 0.1;
    ctx.fillStyle = p.hot ? '#ffe46b' : p.bounced ? '#c9a6ff' : '#9fe8ff';
    const s = p.hot ? dot * 2 : dot;
    ctx.beginPath(); ctx.arc(p.x, p.y, s, 0, TAU); ctx.fill();
  }
  ctx.globalAlpha = 1;
  const end = pts[pts.length - 1];
  if (end && end.block) {
    const k = 10 / r.cam.zoom;
    ctx.strokeStyle = '#ff4d4d';
    ctx.lineWidth = 3 / r.cam.zoom;
    ctx.beginPath();
    ctx.moveTo(end.x - k, end.y - k); ctx.lineTo(end.x + k, end.y + k);
    ctx.moveTo(end.x + k, end.y - k); ctx.lineTo(end.x - k, end.y + k);
    ctx.stroke();
  }
}

function shapePath(ctx, shape, R) {
  ctx.beginPath();
  if (shape === 'hex') {
    for (let i = 0; i < 6; i++) { const a = i * TAU / 6; ctx.lineTo(Math.cos(a) * R, Math.sin(a) * R); }
    ctx.closePath();
  } else if (shape === 'dart') {
    ctx.moveTo(R * 1.2, 0); ctx.lineTo(-R * 0.8, R * 0.8); ctx.lineTo(-R * 0.4, 0); ctx.lineTo(-R * 0.8, -R * 0.8); ctx.closePath();
  } else if (shape === 'diamond') {
    ctx.moveTo(R, 0); ctx.lineTo(0, R * 0.8); ctx.lineTo(-R, 0); ctx.lineTo(0, -R * 0.8); ctx.closePath();
  } else if (shape === 'blob') {
    for (let i = 0; i < 10; i++) { const a = i * TAU / 10, k = i % 2 ? 0.82 : 1; ctx.lineTo(Math.cos(a) * R * k, Math.sin(a) * R * k); }
    ctx.closePath();
  } else if (shape === 'ship') {
    ctx.moveTo(R * 1.3, 0); ctx.lineTo(R * 0.3, R * 0.55); ctx.lineTo(-R, R * 0.6); ctx.lineTo(-R * 0.8, 0); ctx.lineTo(-R, -R * 0.6); ctx.lineTo(R * 0.3, -R * 0.55); ctx.closePath();
  } else if (shape === 'rock') {
    for (let i = 0; i < 8; i++) { const a = i * TAU / 8, k = 0.8 + ((i * 37) % 5) * 0.06; ctx.lineTo(Math.cos(a) * R * k, Math.sin(a) * R * k); }
    ctx.closePath();
  } else {
    ctx.arc(0, 0, R, 0, TAU);
  }
}

function drawEnemies(r, game) {
  const { ctx } = r;
  const z = r.cam.zoom;
  const sp = Math.hypot(game.ship.vx, game.ship.vy);
  const atk = attackPower(sp, game.stats);
  const arcMult = game.stats.weakArcMult;
  for (const e of game.enemies) {
    if (!onScreen(r, e.x, e.y, e.r + 220)) continue;
    const R = e.r;
    ctx.save();
    ctx.translate(e.x, e.y);
    if (e.T.auraR) {
      const g = ctx.createRadialGradient(0, 0, R, 0, 0, e.T.auraR);
      g.addColorStop(0, 'rgba(199,125,255,0.22)');
      g.addColorStop(1, 'rgba(199,125,255,0)');
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(0, 0, e.T.auraR, 0, TAU); ctx.fill();
    }
    if (e.state === 'windup') {
      ctx.strokeStyle = 'rgba(255,90,60,0.7)';
      ctx.lineWidth = 3 / z;
      ctx.setLineDash([12 / z, 8 / z]);
      ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(Math.cos(e.facing) * 500, Math.sin(e.facing) * 500); ctx.stroke();
      ctx.setLineDash([]);
    }
    if (e.charge > 0) {
      ctx.fillStyle = `rgba(255,80,80,${0.25 + 0.5 * e.charge})`;
      ctx.beginPath(); ctx.arc(Math.cos(e.facing) * R, Math.sin(e.facing) * R, (4 + 8 * e.charge) / Math.sqrt(z), 0, TAU); ctx.fill();
    }
    const pierce = atk >= e.armor;
    const critOnly = !pierce && atk >= e.armor * CRIT_ARMOR;
    // body
    ctx.save();
    ctx.rotate(e.facing);
    shapePath(ctx, e.T.shape, R);
    ctx.fillStyle = e.flash > 0 ? '#ffffff' : e.T.color;
    ctx.globalAlpha = pierce ? 1 : 0.8;
    ctx.fill();
    ctx.globalAlpha = 1;
    ctx.lineWidth = Math.max(1.5 / z, R * 0.08);
    ctx.strokeStyle = e.elite ? '#ffcf4a' : pierce ? 'rgba(255,255,255,0.85)' : 'rgba(40,0,0,0.6)';
    ctx.stroke();
    // eye / nose shows facing
    ctx.fillStyle = '#0b0f1e';
    ctx.beginPath(); ctx.arc(R * 0.45, 0, R * 0.2, 0, TAU); ctx.fill();
    ctx.restore();
    // weak spot
    if (e.weakArc) {
      const wa = e.facing + e.weakDir, half = Math.min(Math.PI, e.weakArc * arcMult);
      const lw = Math.max(4 / z, R * 0.32);
      ctx.strokeStyle = '#ffe46b';
      ctx.lineWidth = lw;
      ctx.beginPath(); ctx.arc(0, 0, R + lw * 0.3, wa - half, wa + half); ctx.stroke();
      if (e.weakDir2 !== undefined) {
        const wb = e.facing + e.weakDir2;
        ctx.beginPath(); ctx.arc(0, 0, R + lw * 0.3, wb - half, wb + half); ctx.stroke();
      }
    }
    // cannot pierce: red ring (orange dashed = only through the weak spot)
    if (!pierce) {
      ctx.lineWidth = 3 / z;
      ctx.strokeStyle = critOnly ? '#ff9f40' : '#ff3b3b';
      if (critOnly) ctx.setLineDash([8 / z, 6 / z]);
      ctx.beginPath(); ctx.arc(0, 0, R + 9 / z + R * 0.2, 0, TAU); ctx.stroke();
      ctx.setLineDash([]);
    }
    if (e.hp < e.maxHp) {
      const w = Math.max(R * 2, 30 / z), h = 4 / z;
      ctx.fillStyle = 'rgba(0,0,0,0.6)';
      ctx.fillRect(-w / 2, -R - 16 / z, w, h);
      ctx.fillStyle = '#ff6b5a';
      ctx.fillRect(-w / 2, -R - 16 / z, w * Math.max(0, e.hp / e.maxHp), h);
    }
    ctx.restore();
  }
}

function drawEnemyBullets(r, game) {
  const { ctx } = r;
  const z = r.cam.zoom;
  for (const b of game.ebullets) {
    if (!onScreen(r, b.x, b.y, 40)) continue;
    const s = b.r / Math.sqrt(z);
    if (b.kind === 'missile') {
      const a = Math.atan2(b.vy, b.vx);
      ctx.save(); ctx.translate(b.x, b.y); ctx.rotate(a);
      ctx.fillStyle = '#ffb36b';
      ctx.beginPath(); ctx.moveTo(s * 1.6, 0); ctx.lineTo(-s, s * 0.7); ctx.lineTo(-s, -s * 0.7); ctx.closePath(); ctx.fill();
      ctx.fillStyle = 'rgba(255,200,120,0.5)';
      ctx.beginPath(); ctx.arc(-s * 1.6, 0, s * 0.6, 0, TAU); ctx.fill();
      ctx.restore();
    } else {
      ctx.fillStyle = '#ff5a6e';
      ctx.beginPath(); ctx.arc(b.x, b.y, s, 0, TAU); ctx.fill();
      ctx.fillStyle = '#ffd0d6';
      ctx.beginPath(); ctx.arc(b.x, b.y, s * 0.45, 0, TAU); ctx.fill();
    }
  }
}

function drawFx(r, game) {
  const { ctx } = r;
  const z = r.cam.zoom;
  const ps = 1 / Math.sqrt(z);
  for (const p of game.fx.particles) {
    ctx.globalAlpha = Math.min(1, p.life / 0.4);
    ctx.fillStyle = p.color;
    const s = p.size * ps;
    ctx.fillRect(p.x - s / 2, p.y - s / 2, s, s);
  }
  for (const g of game.fx.rings) {
    const k = 1 - g.life / g.max;
    ctx.globalAlpha = Math.max(0, g.life / g.max);
    ctx.strokeStyle = g.color;
    ctx.lineWidth = (10 * (1 - k) + 2) / z;
    ctx.beginPath(); ctx.arc(g.x, g.y, g.radius * (0.2 + 0.8 * Math.sqrt(k)), 0, TAU); ctx.stroke();
  }
  ctx.globalAlpha = 1;
  ctx.textAlign = 'center';
  for (const t of game.fx.texts) {
    ctx.globalAlpha = Math.min(1, t.life / 0.3);
    ctx.fillStyle = t.color;
    ctx.font = `800 ${Math.round((t.size || 16) / z)}px ${MONO}`;
    ctx.fillText(t.text, t.x, t.y);
  }
  ctx.globalAlpha = 1;
}

function drawMinimap(r, game) {
  const { ctx, W, H } = r;
  const R = Math.min(90, Math.min(W, H) * 0.12);
  const cx = W - R - 16, cy = R + 16;
  const k = R / (CONFIG.fieldRadius + 300);
  ctx.save();
  ctx.translate(cx, cy);
  ctx.fillStyle = 'rgba(8,12,28,0.78)';
  ctx.beginPath(); ctx.arc(0, 0, R, 0, TAU); ctx.fill();
  ctx.fillStyle = 'rgba(150,70,255,0.16)';
  ctx.beginPath(); ctx.arc(0, 0, CONFIG.fieldRadius * k, 0, TAU); ctx.arc(0, 0, CONFIG.zoneOuter * k, 0, TAU, true); ctx.fill();
  ctx.fillStyle = 'rgba(255,70,50,0.18)';
  ctx.beginPath(); ctx.arc(0, 0, CONFIG.zoneInner * k, 0, TAU); ctx.fill();
  ctx.strokeStyle = 'rgba(190,120,255,0.8)';
  ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.arc(0, 0, CONFIG.fieldRadius * k, 0, TAU); ctx.stroke();
  ctx.fillStyle = '#4a68d8';
  ctx.beginPath(); ctx.arc(0, 0, Math.max(3, CONFIG.planetRadius * k), 0, TAU); ctx.fill();
  ctx.fillStyle = '#a08a6c';
  for (const m of game.field.moons) { ctx.beginPath(); ctx.arc(m.x * k, m.y * k, 2.2, 0, TAU); ctx.fill(); }
  for (const e of game.enemies) {
    if (e.type !== 'battleship' && !e.elite) continue;
    ctx.fillStyle = e.type === 'battleship' ? '#ff5a5a' : '#ffcf4a';
    ctx.fillRect(e.x * k - 2, e.y * k - 2, 4, 4);
  }
  for (const c of game.capsules) {
    ctx.fillStyle = c.kind === 'core' ? '#ffd24a' : RARITIES[c.mod.r].color;
    const s2 = c.kind === 'core' ? 3.5 : 2.5;
    ctx.beginPath(); ctx.moveTo(c.x * k, c.y * k - s2); ctx.lineTo(c.x * k + s2, c.y * k); ctx.lineTo(c.x * k, c.y * k + s2); ctx.lineTo(c.x * k - s2, c.y * k); ctx.closePath(); ctx.fill();
  }
  const sh = game.ship;
  ctx.strokeStyle = 'rgba(255,255,255,0.25)';
  ctx.lineWidth = 1;
  ctx.beginPath(); ctx.arc(sh.x * k, sh.y * k, game.viewRadius * k, 0, TAU); ctx.stroke();
  ctx.strokeStyle = '#5fd8ff';
  ctx.beginPath(); ctx.moveTo(sh.x * k, sh.y * k); ctx.lineTo((sh.x + sh.vx * 1.5) * k, (sh.y + sh.vy * 1.5) * k); ctx.stroke();
  ctx.fillStyle = '#e8f6ff';
  ctx.beginPath(); ctx.arc(sh.x * k, sh.y * k, 3, 0, TAU); ctx.fill();
  ctx.restore();
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

// The ship never rotates: a round craft, so screen-absolute controls always read the same way.
// Direction is shown by the trail and the heading marker instead.
function drawShip(r, game) {
  const { ctx } = r;
  const sh = game.ship;
  const s = Math.max(CONFIG.shipRadius, 9 / r.cam.zoom);
  ctx.save();
  ctx.translate(sh.x, sh.y);
  if (sh.invulnT > 0 && Math.floor(game.t * 20) % 2 === 0) ctx.globalAlpha = 0.4;
  ctx.shadowColor = '#5fd8ff';
  ctx.shadowBlur = 18;
  ctx.fillStyle = '#1b3b5c';
  ctx.beginPath(); ctx.arc(0, 0, s, 0, TAU); ctx.fill();
  ctx.lineWidth = s * 0.28;
  ctx.strokeStyle = '#bff3ff';
  ctx.beginPath(); ctx.arc(0, 0, s * 0.82, 0, TAU); ctx.stroke();
  ctx.shadowBlur = 0;
  ctx.fillStyle = '#ffffff';
  ctx.beginPath(); ctx.arc(0, 0, s * 0.38, 0, TAU); ctx.fill();
  ctx.restore();
}

// Aim marker: a Space launch goes this way (scheme dependent).
function drawAimMarker(r, game) {
  const sh = game.ship;
  if (sh.charging || game.state !== 'play') return;
  const { ctx } = r;
  const p = worldToScreen(r, sh.x, sh.y);
  const ux = sh.markX, uy = sh.markY; // where a Space launch would go under the current scheme
  ctx.globalAlpha = 0.85;
  ctx.strokeStyle = '#9fe8ff';
  ctx.lineWidth = 2;
  ctx.setLineDash([3, 5]);
  ctx.beginPath(); ctx.moveTo(p.x + ux * 24, p.y + uy * 24); ctx.lineTo(p.x + ux * 46, p.y + uy * 46); ctx.stroke();
  ctx.setLineDash([]);
  const tx = p.x + ux * 56, ty = p.y + uy * 56;
  ctx.fillStyle = '#9fe8ff';
  ctx.beginPath();
  ctx.moveTo(tx + ux * 9, ty + uy * 9);
  ctx.lineTo(tx - ux * 3 - uy * 7, ty - uy * 3 + ux * 7);
  ctx.lineTo(tx - ux * 3 + uy * 7, ty - uy * 3 - ux * 7);
  ctx.closePath(); ctx.fill();
  ctx.globalAlpha = 1;
}

function drawChargeUi(r, game, pointer) {
  drawAimMarker(r, game);
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
  drawSpeedPanel(r, game);
  drawStatus(r, game);
  drawTimer(r, game);
  drawLoadout(r, game);
}

// Bottom-left: the ship assembled from the equipped parts (empty slots are dashed outlines),
// with the module names beside it on wide screens.
function drawLoadout(r, game) {
  const { ctx, H, W } = r;
  const unit = Math.min(15, H / 50);
  const cx = 12 + unit * 3.4, cy = H - 14 - unit * 3.4;
  ctx.fillStyle = 'rgba(8,12,28,0.55)';
  ctx.beginPath(); ctx.arc(cx, cy - unit * 0.1, unit * 3.4, 0, TAU); ctx.fill();
  drawShipAssembly(ctx, cx, cy, unit, (slot) => {
    const m = game.loadout[slot];
    return m ? RARITIES[m.r].color : null;
  }, null, game.t);
  if (W < 960) return; // names only where they clear the speed bar
  const x = cx + unit * 3.8, y0 = cy - unit * 3 + 4;
  ctx.textAlign = 'left';
  ctx.font = '12px "Hiragino Sans", "Noto Sans JP", sans-serif';
  SLOTS.forEach((s, i) => {
    const m = game.loadout[s.id];
    ctx.fillStyle = m ? RARITIES[m.r].color : '#4a5878';
    ctx.fillText(`${s.name}: ${m ? moduleDef(m.id).name : '—'}`, x, y0 + i * 17);
  });
}

function drawTimer(r, game) {
  const { ctx, W } = r;
  const left = Math.max(0, CONFIG.runTime - game.t);
  const m = Math.floor(left / 60), sec = Math.floor(left % 60);
  ctx.textAlign = 'center';
  ctx.fillStyle = left < 60 ? '#ff8a6b' : '#e8f0ff';
  ctx.font = `700 26px ${MONO}`;
  ctx.fillText(`${m}:${String(sec).padStart(2, '0')}`, W / 2, 40);
  ctx.font = '13px "Hiragino Sans", "Noto Sans JP", sans-serif';
  ctx.fillStyle = '#8fa3c8';
  ctx.fillText(getPhase(game.t).name, W / 2, 58);
  // xp bar
  const need = xpForLevel(game.level);
  ctx.fillStyle = 'rgba(255,255,255,0.08)';
  ctx.fillRect(0, 0, W, 5);
  ctx.fillStyle = '#6dffb0';
  ctx.fillRect(0, 0, W * Math.min(1, game.xp / need), 5);
}

function drawStatus(r, game) {
  const { ctx } = r;
  const sh = game.ship;
  const x = 16, y = 18, w = 220;
  ctx.fillStyle = 'rgba(255,255,255,0.1)';
  ctx.fillRect(x, y, w, 12);
  ctx.fillStyle = sh.hp / game.stats.maxHp < 0.3 ? '#ff5a4a' : '#5dffa0';
  ctx.fillRect(x, y, w * Math.max(0, sh.hp / game.stats.maxHp), 12);
  ctx.fillStyle = '#e8f0ff';
  ctx.font = `12px ${MONO}`;
  ctx.textAlign = 'left';
  ctx.fillText(`HP ${Math.ceil(Math.max(0, sh.hp))} / ${Math.round(game.stats.maxHp)}`, x, y + 28);
  const atk = attackPower(Math.hypot(sh.vx, sh.vy), game.stats);
  ctx.fillText(`ATK ${atk.toFixed(1)}   撃破 ${game.kills}   Lv ${game.level}`, x, y + 46);
  ctx.fillStyle = '#ffd24a';
  ctx.fillText(`部品 ${Math.round(game.coins)}`, x, y + 64);
}

function drawSpeedPanel(r, game) {
  const { ctx, W, H } = r;
  const sp = Math.hypot(game.ship.vx, game.ship.vy);
  const kms = (v) => (v * CONFIG.speedToKms).toFixed(2);
  const bw = Math.min(420, W * 0.5), bh = 10;
  const bx = W / 2 - bw / 2, by = H - 34;
  const top = CONFIG.escapeSpeed * 1.08;
  const X = (v) => bx + clamp(v / top, 0, 1) * bw;
  ctx.fillStyle = 'rgba(255,255,255,0.08)';
  ctx.fillRect(bx, by, bw, bh);
  const hot = sp > game.stats.maxSpeed;
  ctx.fillStyle = sp >= CONFIG.escapeSpeed ? '#ffd24a' : hot ? '#bff3ff' : '#5fd8ff';
  ctx.fillRect(bx, by, X(sp) - bx, bh);
  // max speed tick
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(X(game.stats.maxSpeed) - 1, by - 5, 2, bh + 10);
  // peak marker
  ctx.fillStyle = 'rgba(255,255,255,0.5)';
  ctx.fillRect(X(game.peakSpeed) - 1, by, 2, bh);
  // escape line
  ctx.fillStyle = '#ffd24a';
  ctx.fillRect(X(CONFIG.escapeSpeed) - 1.5, by - 8, 3, bh + 16);
  ctx.font = `11px ${MONO}`;
  ctx.textAlign = 'center';
  ctx.fillText(`脱出 ${kms(CONFIG.escapeSpeed)}`, X(CONFIG.escapeSpeed), by - 11);
  ctx.fillStyle = '#cfd8ee';
  ctx.fillText(`上限 ${kms(game.stats.maxSpeed)}`, X(game.stats.maxSpeed), by + bh + 14);
  ctx.textAlign = 'left';
  ctx.fillStyle = '#8fa3c8';
  ctx.fillText(`最高 ${kms(game.peakSpeed)}`, bx, by - 8);
  ctx.fillStyle = hot ? '#bff3ff' : '#e8f0ff';
  ctx.font = `700 34px ${MONO}`;
  ctx.textAlign = 'right';
  ctx.fillText(kms(sp), W / 2 + 40, by - 18);
  ctx.textAlign = 'left';
  ctx.font = `13px ${MONO}`;
  ctx.fillStyle = '#8fa3c8';
  ctx.fillText('km/s', W / 2 + 46, by - 19);
}
