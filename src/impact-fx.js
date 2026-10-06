import { CONFIG } from './config.js';

// Effects remain at the actual contact; the illuminated hull follows a surviving blocker.
export function addCombatImpact(game, enemy, kind, nx, ny) {
  const impacts = game.fx.impacts;
  if (impacts.length >= 48) {
    if (kind !== 'block') return;
    const old = impacts.findIndex(i => i.kind !== 'block');
    impacts.splice(Math.max(0, old), 1);
  }
  const life = kind === 'block' ? CONFIG.blockImpactLife : CONFIG.weakImpactLife;
  const x = enemy.x + nx * enemy.r, y = enemy.y + ny * enemy.r;
  impacts.push({ kind, enemy, x, y, nx, ny, life, max: life });
  const count = kind === 'block' ? CONFIG.blockSparkCount : CONFIG.weakFlameCount;
  const normal = Math.atan2(ny, nx);
  for (let i = 0; i < count && game.fx.particles.length < 1800; i++) {
    const side = i % 2 ? 1 : -1;
    const angle = kind === 'block' ? normal + side * (0.8 + Math.random() * 0.75)
      : normal + (Math.random() - 0.5) * 1.25;
    const speed = kind === 'block' ? 180 + Math.random() * 460 : 100 + Math.random() * 260;
    const duration = life * (0.6 + Math.random() * 0.4);
    game.fx.particles.push({ kind: kind === 'block' ? 'spark' : 'flame', x, y,
      vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
      life: duration, max: duration, color: i % 3 ? '#ffae40' : '#fff6c7', size: 2 + Math.random() * 3 });
  }
}

export function drawCombatImpacts(r, game) {
  const { ctx } = r;
  const z = r.cam.zoom;
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  ctx.lineCap = 'round';
  for (const impact of game.fx.impacts) {
    const a = impact.life / impact.max;
    const { enemy, nx, ny } = impact;
    const x = impact.kind === 'block' && !enemy.dead ? enemy.x + nx * enemy.r : impact.x;
    const y = impact.kind === 'block' && !enemy.dead ? enemy.y + ny * enemy.r : impact.y;
    const reach = (impact.kind === 'block' ? 60 : 38) / Math.sqrt(z);
    const glow = ctx.createRadialGradient(x, y, 0, x, y, reach);
    glow.addColorStop(0, `rgba(255,245,190,${a * 0.85})`);
    glow.addColorStop(0.2, `rgba(255,157,38,${a * 0.6})`);
    glow.addColorStop(1, 'rgba(255,80,12,0)');
    ctx.fillStyle = glow;
    ctx.fillRect(x - reach, y - reach, reach * 2, reach * 2);
    if (impact.kind === 'block') {
      // A brief reflection across this hull identifies the enemy that stopped the dash.
      const angle = Math.atan2(ny, nx);
      ctx.globalAlpha = a;
      ctx.strokeStyle = '#ffcf69'; ctx.lineWidth = 5 / z;
      ctx.beginPath(); ctx.arc(enemy.x, enemy.y, enemy.r + 2 / z, angle - 1.15, angle + 1.15); ctx.stroke();
      ctx.globalAlpha = 1;
    }
  }
  ctx.restore();
}
