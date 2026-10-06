import { angleDiff } from './math.js';
import { CONFIG } from './config.js';

export const CRIT_ARMOR = 0.5; // critical contact needs half the armor; no directional weak spot

export function attackPower(speed, stats) {
  return CONFIG.baseAttack * stats.atkMult * CONFIG.atkScale * (stats.burstPower || 1);
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
  if (stats.ignoreArmor || canPierce(atk * (stats.armorPierceMult || 1), e, crit)) {
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
