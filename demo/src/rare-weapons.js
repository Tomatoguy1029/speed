import { CONFIG } from './config.js';
import { attackPower } from './combat.js';
import { damageEnemy, addRing } from './hits.js';
import { queryGrid } from './grid.js';
import { MAX_ENEMY_R } from './enemies.js';
import { segCircleT } from './math.js';
import { runWeaponStats } from './run-build.js';

export function beginRareRoute(game) {
  if (game.weapons.bipolar) {
    game.weaponState.bipolar = { origin: { x: game.ship.x, y: game.ship.y } };
  }
}

// Store the whole defeated hull, including large ships; projectile kills cannot reload it.
export function captureTowHull(game, e, cause) {
  if (!game.newBuild || !game.weapons.massTow || game.draw?.phase !== 'run' ||
      e.type === 'meteor' || e.type === 'boss' || e.towed ||
      !['ram', 'wave', 'bump', 'sonic', 'killSonic', 'contactWave', 'contactArc', 'critBeam', 'crossBlast'].includes(cause)) return false;
  const st = game.weaponState.massTow || (game.weaponState.massTow = { cargo: [], head: 0, fireT: 0 });
  e.towed = true;
  st.cargo.push({ x: e.x, y: e.y, r: e.r, color: e.T.color, shape: e.T.shape,
    angle: e.facing, sourceId: e.id, ready: false });
  return true;
}

export function endRareRoute(game) {
  const origin = game.weaponState.bipolar?.origin, sh = game.ship;
  if (origin && game.weapons.bipolar) {
    game.weaponState.bipolar.origin = null;
    const dx = sh.x - origin.x, dy = sh.y - origin.y, length = Math.hypot(dx, dy);
    if (length > 20) {
      const L = runWeaponStats('bipolar', game.weapons.bipolar);
      const width = CONFIG.bipolarWidth * L.radius, pad = width / 2 + MAX_ENEMY_R;
      const x1 = sh.x, y1 = sh.y, ux = dx / length, uy = dy / length;
      const damage = attackPower(0, game.stats) * CONFIG.bipolarDamage * L.damage;
      queryGrid(game.grid, Math.min(origin.x, x1) - pad, Math.min(origin.y, y1) - pad,
        Math.max(origin.x, x1) + pad, Math.max(origin.y, y1) + pad, e => {
          if (e.dead || game.state !== 'play' || segCircleT(origin.x, origin.y, x1, y1, e.x, e.y, e.r + width / 2) < 0) return;
          damageEnemy(game, e, damage, { cause: 'bipolar', dirX: ux, dirY: uy, knock: 1100 });
        });
      game.wfx.push({ kind: 'beam', color: '#69fff0', x0: origin.x, y0: origin.y, x1, y1,
        width, life: CONFIG.bipolarLife, max: CONFIG.bipolarLife });
      addRing(game, origin.x, origin.y, 65, '#69fff0', CONFIG.bipolarLife);
      addRing(game, x1, y1, 65, '#69fff0', CONFIG.bipolarLife);
    }
  }
  const st = game.weaponState.massTow;
  if (st && game.state === 'play') {
    for (let i = st.head; i < st.cargo.length; i++) st.cargo[i].ready = true;
    st.fireT = 0;
  }
}

export function updateRareWeapons(game, dt) {
  if (!game.newBuild || game.state !== 'play') return;
  const st = game.weaponState.massTow;
  if (!st || !game.weapons.massTow) return;
  const sh = game.ship, sp = Math.hypot(sh.vx, sh.vy);
  const ux = sp > 1 ? sh.vx / sp : sh.hx, uy = sp > 1 ? sh.vy / sp : sh.hy;
  const follow = 1 - Math.exp(-CONFIG.massTowFollow * dt);
  // Keep all ammunition. Only the visible front of a large train needs animation.
  for (let j = 0; j < Math.min(CONFIG.massTowVisible, st.cargo.length - st.head); j++) {
    const h = st.cargo[st.head + j], back = 85 + Math.floor(j / 4) * 85 + h.r;
    const side = (j % 4 - 1.5) * 65;
    const tx = sh.x - ux * back - uy * side, ty = sh.y - uy * back + ux * side;
    h.x += (tx - h.x) * follow; h.y += (ty - h.y) * follow;
    h.angle = Math.atan2(uy, ux) + Math.PI;
  }
  st.fireT -= dt;
  const L = runWeaponStats('massTow', game.weapons.massTow), interval = CONFIG.massTowInterval / L.rate;
  while (st.fireT <= 0 && st.cargo[st.head]?.ready) {
    const hull = st.cargo[st.head++], r = hull.r;
    game.fbullets.push({ kind: 'corpse', cause: 'towShot', hull, x: hull.x, y: hull.y,
      vx: ux * (CONFIG.massTowSpeed + sp), vy: uy * (CONFIG.massTowSpeed + sp), r,
      dmg: attackPower(0, game.stats) * CONFIG.massTowDamage * L.damage * Math.max(1, hull.r / 25),
      life: CONFIG.massTowLife, pierce: true, hit: new Set([hull.sourceId]), noCrit: true, knock: 1200, color: hull.color });
    addRing(game, hull.x, hull.y, Math.max(34, r), '#ffbe65', 0.15);
    st.fireT += interval;
  }
  if (!st.cargo[st.head]?.ready) st.fireT = 0;
  if (st.head > 64 || st.head === st.cargo.length) { st.cargo.splice(0, st.head); st.head = 0; }
}

export function drawTowHull(ctx, hull, x, y, angle, z, radius = hull.r) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(angle);
  ctx.fillStyle = hull.color; ctx.strokeStyle = '#ffc778'; ctx.lineWidth = 2 / z;
  ctx.beginPath();
  if (hull.shape === 'orb') ctx.arc(0, 0, radius, 0, Math.PI * 2);
  else if (hull.shape === 'ship') {
    ctx.moveTo(radius, 0); ctx.lineTo(radius * 0.3, -radius * 0.6); ctx.lineTo(-radius * 0.8, -radius * 0.5);
    ctx.lineTo(-radius, radius * 0.35); ctx.lineTo(radius * 0.2, radius * 0.65);
  } else {
    const n = hull.shape === 'dart' ? 3 : hull.shape === 'diamond' ? 4 : 6;
    for (let i = 0; i < n; i++) {
      const a = i * Math.PI * 2 / n;
      ctx.lineTo(Math.cos(a) * radius, Math.sin(a) * radius * 0.8);
    }
  }
  ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.strokeStyle = '#3a2d38'; ctx.lineWidth = Math.max(2 / z, radius * 0.06);
  ctx.beginPath(); ctx.moveTo(-radius * 0.6, -radius * 0.4); ctx.lineTo(radius * 0.1, 0);
  ctx.lineTo(-radius * 0.3, radius * 0.5); ctx.stroke();
  ctx.fillStyle = '#ffe1ab'; ctx.fillRect(-4 / z, -4 / z, 8 / z, 8 / z);
  ctx.restore();
}

export function debugRareMeteor(game, weapon) {
  if (!game.newBuild || game.state !== 'play') return;
  const sh = game.ship;
  game.field.meteors.push({ kind: 'belt', x: sh.x + sh.hx * 200, y: sh.y + sh.hy * 200,
    vx: 0, vy: 0, size: 55, facing: 0, spin: 0.2, destroyed: false, entity: null, rareWeapon: weapon });
  game.meteorStreamT = 0;
}
