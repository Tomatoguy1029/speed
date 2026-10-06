// Module slots drawn as spaceship parts. Each part has its own silhouette, and the six of them
// assemble into one ship (nose, radar, gun, reactor, wings, engine). Pure canvas drawing.

const TAU_P = Math.PI * 2;

// Where each part sits in the assembled ship, in units (ship points up, center = reactor).
export const PART_LAYOUT = {
  armor: { x: 0, y: 0.35, s: 1 },
  booster: { x: 0, y: 1.85, s: 1 },
  gen: { x: 0, y: -0.05, s: 0.95 },
  gun: { x: 1.15, y: -1.0, s: 0.8 },
  radar: { x: -1.15, y: -1.0, s: 0.8 },
  bow: { x: 0, y: -2.2, s: 1 },
};
const DRAW_ORDER = ['armor', 'booster', 'gen', 'gun', 'radar', 'bow'];

function trace(ctx, slot, s) {
  ctx.beginPath();
  switch (slot) {
    case 'bow': // nose cone
      ctx.moveTo(0, -1.15 * s);
      ctx.quadraticCurveTo(0.8 * s, -0.25 * s, 0.62 * s, 0.85 * s);
      ctx.lineTo(-0.62 * s, 0.85 * s);
      ctx.quadraticCurveTo(-0.8 * s, -0.25 * s, 0, -1.15 * s);
      break;
    case 'booster': // twin engine bells
      for (const sx of [-1, 1]) {
        const cx = sx * 0.42 * s;
        ctx.moveTo(cx - 0.26 * s, -0.55 * s);
        ctx.lineTo(cx + 0.26 * s, -0.55 * s);
        ctx.lineTo(cx + 0.4 * s, 0.45 * s);
        ctx.lineTo(cx - 0.4 * s, 0.45 * s);
        ctx.closePath();
      }
      break;
    case 'gun': // turret + barrel
      ctx.rect(-0.16 * s, -1.15 * s, 0.32 * s, 1.15 * s);
      ctx.moveTo(0.48 * s, 0.25 * s);
      ctx.arc(0, 0.25 * s, 0.48 * s, 0, TAU_P);
      break;
    case 'radar': // dish on a mast
      ctx.moveTo(-0.85 * s, -0.55 * s);
      ctx.quadraticCurveTo(0, 0.55 * s, 0.85 * s, -0.55 * s);
      ctx.quadraticCurveTo(0, -0.05 * s, -0.85 * s, -0.55 * s);
      ctx.rect(-0.1 * s, 0, 0.2 * s, 0.75 * s);
      break;
    case 'armor': // a pair of swept wing plates
      for (const sx of [-1, 1]) {
        ctx.moveTo(sx * 0.45 * s, -0.55 * s);
        ctx.lineTo(sx * 1.55 * s, 0.35 * s);
        ctx.lineTo(sx * 1.55 * s, 0.95 * s);
        ctx.lineTo(sx * 0.45 * s, 0.55 * s);
        ctx.closePath();
      }
      break;
    case 'gen': // hexagonal reactor
    default:
      for (let i = 0; i < 6; i++) {
        const a = i * TAU_P / 6 - Math.PI / 2;
        if (i === 0) ctx.moveTo(Math.cos(a) * 0.72 * s, Math.sin(a) * 0.72 * s);
        else ctx.lineTo(Math.cos(a) * 0.72 * s, Math.sin(a) * 0.72 * s);
      }
      ctx.closePath();
  }
}

// One part at the origin. color = rarity color (filled), or null for an empty outline.
export function drawPart(ctx, slot, s, color, opts = {}) {
  ctx.save();
  if (color) {
    if (opts.glow) { ctx.shadowColor = color; ctx.shadowBlur = opts.glow; }
    trace(ctx, slot, s);
    ctx.fillStyle = color;
    ctx.fill('nonzero');
    ctx.shadowBlur = 0;
    ctx.lineWidth = Math.max(1, s * 0.09);
    ctx.strokeStyle = 'rgba(10,14,30,0.75)';
    ctx.stroke();
    // small details so the parts read as machinery
    ctx.fillStyle = 'rgba(255,255,255,0.75)';
    if (slot === 'bow') { ctx.beginPath(); ctx.ellipse(0, -0.2 * s, 0.18 * s, 0.3 * s, 0, 0, TAU_P); ctx.fill(); }
    if (slot === 'gen') { ctx.beginPath(); ctx.arc(0, 0, 0.3 * s, 0, TAU_P); ctx.fill(); }
    if (slot === 'radar') { ctx.beginPath(); ctx.arc(0, -0.25 * s, 0.11 * s, 0, TAU_P); ctx.fill(); }
    if (slot === 'gun') { ctx.fillRect(-0.16 * s, -1.15 * s, 0.32 * s, 0.16 * s); }
    if (slot === 'booster' && opts.flame !== false) {
      ctx.fillStyle = 'rgba(255,170,80,0.85)';
      for (const sx of [-1, 1]) {
        const cx = sx * 0.42 * s;
        ctx.beginPath(); ctx.moveTo(cx - 0.26 * s, 0.5 * s); ctx.lineTo(cx + 0.26 * s, 0.5 * s); ctx.lineTo(cx, 1.1 * s); ctx.closePath(); ctx.fill();
      }
    }
  } else {
    trace(ctx, slot, s);
    ctx.setLineDash([Math.max(2, s * 0.18), Math.max(2, s * 0.14)]);
    ctx.lineWidth = Math.max(1, s * 0.07);
    ctx.strokeStyle = opts.outline || 'rgba(190,205,240,0.35)';
    ctx.stroke();
    ctx.setLineDash([]);
  }
  ctx.restore();
}

// The whole ship. colorOf(slot) -> rarity color or null (empty). highlight: slot to pulse.
export function drawShipAssembly(ctx, cx, cy, unit, colorOf, highlight, t = 0) {
  ctx.save();
  ctx.translate(cx, cy);
  // chassis spine that holds the parts
  ctx.strokeStyle = 'rgba(160,180,230,0.25)';
  ctx.lineWidth = Math.max(1, unit * 0.12);
  ctx.beginPath(); ctx.moveTo(0, -1.4 * unit); ctx.lineTo(0, 1.3 * unit); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(-1.15 * unit, -0.75 * unit); ctx.lineTo(1.15 * unit, -0.75 * unit); ctx.stroke();
  for (const slot of DRAW_ORDER) {
    const L = PART_LAYOUT[slot];
    ctx.save();
    ctx.translate(L.x * unit, L.y * unit);
    const color = colorOf(slot);
    drawPart(ctx, slot, L.s * unit, color, { glow: color ? unit * 0.4 : 0 });
    if (slot === highlight) {
      const pulse = 0.5 + 0.5 * Math.sin(t * 6);
      drawPart(ctx, slot, L.s * unit * (1.12 + 0.06 * pulse), null, { outline: `rgba(255,255,255,${0.5 + 0.5 * pulse})` });
    }
    ctx.restore();
  }
  ctx.restore();
}
