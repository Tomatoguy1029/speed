import { CONFIG } from './config.js';
import { burst, addRing } from './hits.js';

// Only keep the recent approach while the boss is alive; no world snapshots or replayed damage.
export function recordBossApproach(game, dt) {
  if (!game.boss || game.boss.dead) return;
  game.finishClock += dt;
  const sh = game.ship, frames = game.finishFrames;
  frames.push({ t: game.finishClock - dt, x: sh.x, y: sh.y, vx: sh.vx, vy: sh.vy });
  const cutoff = game.finishClock - CONFIG.bossFinishReplayWindow;
  while (frames.length > 2 && frames[1].t < cutoff) frames.shift();
  if (frames.length > 64) frames.shift();
}

export function beginBossFinish(game, boss, hit = {}) {
  if (game.finale) return;
  const sh = game.ship;
  const impact = { t: game.finishClock, x: hit.impactX ?? sh.x, y: hit.impactY ?? sh.y, vx: sh.vx, vy: sh.vy };
  const frames = [...game.finishFrames, impact];
  game.finale = { phase: 'slow', elapsed: 0, boss, frames, impact };
  game.state = 'finishing';
  game.endReason = 'boss';
  game.spawning = false;
  game.hitstop = game.slowmo = game.acc = 0;
  game.draw = game.portalDash = game.releasePending = null;
  game.offerQueue.length = 0;
  game.currentOffer = null;
  sh.charging = false; sh.invulnT = 0;
  game.events.push({ type: 'bossFinish' });
}

// Timings are in real seconds. The slow segment replays positions, never combat or pickups.
export function advanceBossFinish(game, dt) {
  const f = game.finale, sh = game.ship;
  f.elapsed += dt;
  if (f.phase === 'slow') {
    const k = Math.min(1, f.elapsed / CONFIG.bossFinishSlowTime);
    const frames = f.frames;
    const start = Math.max(frames[0].t, f.impact.t - CONFIG.bossFinishReplayWindow);
    const time = start + (f.impact.t - start) * k;
    let i = 0;
    while (i < frames.length - 2 && frames[i + 1].t < time) i++;
    const a = frames[i], b = frames[i + 1] || a;
    const mix = Math.max(0, Math.min(1, (time - a.t) / (b.t - a.t || 1)));
    for (const key of ['x', 'y', 'vx', 'vy']) sh[key] = a[key] + (b[key] - a[key]) * mix;
    sh.trail = frames.slice(0, i + 1).map(p => ({ x: p.x, y: p.y }));
    game.timeScale = CONFIG.bossFinishReplayWindow / CONFIG.bossFinishSlowTime;
    f.boss.flash = 0.12;
    if (k < 1) return false;
    sh.trail = [];
    sh.invulnT = 0;
    f.phase = 'blast'; f.elapsed = 0;
    bossClearBlast(game);
  } else {
    game.timeScale = 1;
    // Release the shot at normal speed, then let it settle as the camera opens back out.
    sh.x += sh.vx * dt; sh.y += sh.vy * dt;
    const drag = Math.exp(-3 * dt);
    sh.vx *= drag; sh.vy *= drag;
    sh.trail.push({ x: sh.x, y: sh.y });
    if (sh.trail.length > 64) sh.trail.shift();
    if (f.phase === 'blast' && f.elapsed >= CONFIG.bossFinishBlastTime) {
      f.phase = 'clear'; f.elapsed = 0;
    }
  }
  return f.phase === 'clear' && f.elapsed >= CONFIG.bossFinishClearTime;
}

function bossClearBlast(game) {
  const f = game.finale, boss = f.boss;
  game.timeScale = 1;
  game.fx.particles = [];
  // This is the victory sweep, not a chain of gameplay kills: no drops, splits or extra offers.
  burst(game, boss.x, boss.y, '#ffe3a3', 90, 0, 0, 900);
  for (const e of new Set([boss, ...game.enemies, ...game.newEnemies])) {
    if (e.dead) continue;
    e.dead = true;
    game.kills++;
    const dx = e.x - boss.x, dy = e.y - boss.y, d = Math.hypot(dx, dy) || 1;
    if (e !== boss) burst(game, e.x, e.y, e.T.color, 4, dx / d, dy / d, 500);
    if (game.fx.particles.length < 1400) for (let i = 0; i < (e === boss ? 24 : 3); i++) {
      const a = Math.random() * Math.PI * 2, speed = 150 + Math.random() * 550;
      game.fx.particles.push({ kind: 'finishDebris', x: e.x, y: e.y,
        vx: Math.cos(a) * speed + dx / d * 300, vy: Math.sin(a) * speed + dy / d * 300,
        life: CONFIG.bossFinishBlastTime, max: CONFIG.bossFinishBlastTime,
        color: e.T.color, size: e === boss ? 10 + Math.random() * 16 : 3 + Math.random() * 5,
        angle: a, spin: (Math.random() - 0.5) * 8 });
    }
  }
  boss.dead = true;
  game.enemies = []; game.newEnemies = []; game.ebullets = []; game.fbullets = [];
  game.mines = []; game.capsules = []; game.gems = []; game.coinDrops = [];
  game.fx.texts = [];
  const radius = Math.max(900, game.viewRadius * 1.4);
  addRing(game, boss.x, boss.y, radius, '#ffe7aa', 0.85);
  addRing(game, boss.x, boss.y, radius * 0.8, '#ff526e', 0.7);
  game.events.push({ type: 'bossExplosion', x: boss.x, y: boss.y });
}

export function finishCameraTarget(game, W, H, baseZoom) {
  const f = game.finale;
  if (!f || game.state !== 'finishing') return null;
  const sh = game.ship, boss = f.boss;
  const zoom = baseZoom * CONFIG.bossFinishZoom;
  const dx = boss.x - sh.x, dy = boss.y - sh.y, dist = Math.hypot(dx, dy) || 1;
  const offset = Math.min(dist * 0.25, Math.min(W, H) * 0.2 / zoom);
  if (f.phase === 'slow') return { x: sh.x + dx / dist * offset, y: sh.y + dy / dist * offset, zoom };
  if (f.phase === 'blast') return { x: boss.x, y: boss.y, zoom: baseZoom };
  return { x: sh.x, y: sh.y, zoom: baseZoom };
}

export function drawBossFinish(r, game) {
  const f = game.finale;
  if (!f || game.state !== 'finishing') return;
  const { ctx, W, H } = r;
  ctx.save();
  if (f.phase === 'slow') {
    // A vignette draws attention to the actual final approach without explanatory HUD.
    const vignette = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.18, W / 2, H / 2, Math.max(W, H) * 0.65);
    vignette.addColorStop(0, 'rgba(0,0,0,0)'); vignette.addColorStop(1, 'rgba(0,0,0,0.65)');
    ctx.fillStyle = vignette; ctx.fillRect(0, 0, W, H);
  } else {
    const blastAge = f.phase === 'blast' ? f.elapsed : CONFIG.bossFinishBlastTime + f.elapsed;
    const p = { x: (f.boss.x - r.cam.x) * r.cam.zoom + W / 2, y: (f.boss.y - r.cam.y) * r.cam.zoom + H / 2 };
    const radius = Math.max(1, (70 + blastAge * 1400) * r.cam.zoom);
    const glow = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, radius);
    const alpha = Math.max(0, 0.8 * (1 - blastAge / 1.1));
    glow.addColorStop(0, `rgba(255,248,215,${alpha})`);
    glow.addColorStop(0.25, `rgba(255,150,60,${alpha * 0.7})`);
    glow.addColorStop(1, 'rgba(255,70,70,0)');
    ctx.fillStyle = glow; ctx.fillRect(0, 0, W, H);
  }
  if (f.phase === 'clear') {
    ctx.globalAlpha = Math.min(1, f.elapsed / 0.2);
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.font = `900 ${Math.min(104, W * 0.17, H * 0.2)}px system-ui, sans-serif`;
    ctx.shadowColor = '#ffac32'; ctx.shadowBlur = 28;
    ctx.fillStyle = '#fff2bf'; ctx.fillText('CLEAR!', W / 2, H / 2);
  }
  ctx.restore();
}
