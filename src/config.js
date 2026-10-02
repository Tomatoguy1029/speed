// All tunable numbers live here. The debug panel edits this object directly.
export const CONFIG = {
  // run
  runTime: 600,
  escapeSpeed: 2400, // px/s needed to clear
  escapeBonus: 30, // coins for escaping
  speedToKms: 11.2 / 2400, // display factor: escape speed shows as 11.2 km/s

  // field
  fieldRadius: 6000,
  planetRadius: 420,
  zoneInner: 2200,
  zoneOuter: 4200,
  startRadius: 3200,
  planetGM: 5.12e8, // ~50 px/s^2 at the start radius
  moonCount: 6,
  moonGM: 1.2e7,
  moonOrbitSpeed: 0.02, // rad/s
  dustCount: 34,
  dustDrag: 0.55,
  boundaryPush: 600,
  crashRestitution: 0.45,
  crashDamage: 0.012, // hp per px/s of impact speed above 200

  // ship
  baseMaxSpeed: 1000,
  launchRatio: 0.8, // full gauge launch = maxSpeed * launchRatio
  carry: 0.65, // share of current speed carried into the next launch (same direction)
  chargeTime: 0.7, // seconds to fill the gauge
  minGauge: 0.12,
  minDrag: 14, // screen px; shorter drags boost forward along velocity
  boostDuration: 0.9, // seconds after launch with no cruise drag
  energyCut: 0.85, // speed kept when the launch energy runs out (applied over ~0.3s)
  cruiseDrag: 0.06, // weak per-second drag after the energy runs out
  cruiseFloor: 0.35, // cruise drag never slows below this share of max speed
  overcapDecay: 0.3, // per second decay of speed above max speed
  shipRadius: 16,
  baseHP: 120,
  invulnTime: 0.6,
  pickupRadius: 140,

  // enemies
  enemyHpMult: 1,
  enemyArmorMult: 1,
  densityMult: 1,
  dangerLevel: 2.2, // extra enemy level at full danger (planet surface / field edge)
  meteorCount: 12,
  meteorCoinChance: 0.4,
  coreBoost: 0.18, // max speed gained per power core
  levelHeal: 0.08, // share of max HP restored per level-up
  capsuleCount: 5, // field capsules kept on the map
  capsuleInterval: 16, // seconds between respawns

  // growth
  xpBase: 10,
  xpGrowth: 7,
  xpMult: 1,

  // camera
  baseView: 1100, // world units visible on the shorter screen side at rest
  zoomRefSpeed: 700,
  zoomExp: 0.7,
  zoomMin: 0.28,
  lookAhead: 0.32,
};
