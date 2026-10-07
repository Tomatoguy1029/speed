import { CONFIG } from './config.js';

// Renderer-owned history follows the actual projectiles, including during world slowdown.
export function drawCorpseDebris(r, game, dt) {
  if (r.debrisGame !== game) {
    r.debrisGame = game;
    r.debrisTime = 0;
    r.debrisTracks = new Map();
  }
  if (game.state === 'play') r.debrisTime += dt;
  const now = r.debrisTime;
  const cutoff = now - CONFIG.corpseTrailLife;
  const tracks = r.debrisTracks;
  for (const [bullet, track] of tracks) {
    track.active = false;
    if (track.lastSeen < cutoff) tracks.delete(bullet);
  }
  for (const b of game.fbullets) {
    if (b.kind !== 'corpse') continue;
    let track = tracks.get(b);
    if (!track) {
      track = { points: [], lastSeen: now, active: true };
      tracks.set(b, track);
    }
    track.active = true;
    track.lastSeen = now;
    const points = track.points;
    const last = points[points.length - 1];
    if (!last || last.x !== b.x || last.y !== b.y) points.push({ x: b.x, y: b.y, t: now });
    else last.t = now;
    while (points.length > CONFIG.corpseTrailPoints || (points.length > 1 && points[0].t < cutoff)) points.shift();
  }

  const { ctx } = r;
  ctx.save();
  ctx.lineCap = 'butt';
  ctx.globalCompositeOperation = 'lighter';
  const halfW = (r.W / 2 + 40) / r.cam.zoom, halfH = (r.H / 2 + 40) / r.cam.zoom;
  for (const [b, track] of tracks) {
    const points = track.points;
    const width = Math.max(1.5 / r.cam.zoom, b.r * 0.3);
    for (let i = 1; i < points.length; i++) {
      const from = points[i - 1], to = points[i];
      // Keep offscreen history for camera movement, but skip invisible canvas strokes.
      if (Math.max(from.x, to.x) + width < r.cam.x - halfW ||
          Math.min(from.x, to.x) - width > r.cam.x + halfW ||
          Math.max(from.y, to.y) + width < r.cam.y - halfH ||
          Math.min(from.y, to.y) - width > r.cam.y + halfH) continue;
      const fade = Math.max(0, 1 - (now - from.t) / CONFIG.corpseTrailLife);
      if (!fade) continue;
      ctx.globalAlpha = fade * fade * 0.55;
      ctx.strokeStyle = b.color;
      ctx.lineWidth = width;
      ctx.beginPath(); ctx.moveTo(from.x, from.y); ctx.lineTo(to.x, to.y); ctx.stroke();
      ctx.globalAlpha *= 0.65;
      ctx.strokeStyle = '#fff3d5';
      ctx.lineWidth = width * 0.3;
      ctx.stroke();
    }
  }
  ctx.globalCompositeOperation = 'source-over';
  for (const [b, track] of tracks) {
    if (!track.active) continue;
    const sx = (b.x - r.cam.x) * r.cam.zoom + r.W / 2;
    const sy = (b.y - r.cam.y) * r.cam.zoom + r.H / 2;
    const pad = b.r * r.cam.zoom;
    if (sx < -pad || sx > r.W + pad || sy < -pad || sy > r.H + pad) continue;
    const size = b.r * 0.65;
    ctx.save();
    ctx.translate(b.x, b.y);
    ctx.rotate(Math.atan2(b.vy, b.vx) + now * CONFIG.corpseSpinRate);
    ctx.globalAlpha = 0.95;
    ctx.fillStyle = '#26323d';
    ctx.strokeStyle = b.color;
    ctx.lineWidth = Math.max(1 / r.cam.zoom, size * 0.16);
    ctx.beginPath();
    ctx.moveTo(size, -size * 0.25);
    ctx.lineTo(-size * 0.15, -size * 0.7);
    ctx.lineTo(-size * 0.85, size * 0.35);
    ctx.lineTo(size * 0.25, size * 0.6);
    ctx.closePath(); ctx.fill(); ctx.stroke();
    ctx.strokeStyle = '#fff3d5';
    ctx.beginPath(); ctx.moveTo(-size * 0.15, -size * 0.7); ctx.lineTo(size, -size * 0.25); ctx.stroke();
    ctx.restore();
  }
  ctx.restore();
}
