import { angleDiff } from './math.js';

export const CRIT_ARMOR = 0.5; // weak-spot hits only need half the armor

export function attackPower(speed, stats) {
  return (speed / 100) * stats.atkMult;
}

export function isWeakHit(e, hx, hy, arcMult) {
  if (!e.weakArc) return false;
  const a = Math.atan2(hy - e.y, hx - e.x);
  return Math.abs(angleDiff(a, e.facing + e.weakDir)) <= e.weakArc * arcMult;
}

export function canPierce(atk, e, crit) {
  return atk >= e.armor * (crit ? CRIT_ARMOR : 1);
}

export function resolveRam(atk, e, crit, stats) {
  if (canPierce(atk, e, crit)) {
    const damage = atk * (crit ? stats.critMult : 1);
    return { pierce: true, damage, kill: damage >= e.hp, shipDamage: 0 };
  }
  return { pierce: false, damage: atk * 0.25, kill: false, shipDamage: e.contact };
}

// Share of speed kept after going through an enemy.
export function pierceKeep(e, killed, stats) {
  const loss = killed ? 0.004 + e.r * 0.0006 : 0.1 + e.r * 0.002;
  return 1 - Math.min(0.6, loss * stats.pierceLossMult);
}
