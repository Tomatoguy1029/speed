// All tunable numbers live here. The debug panel edits this object directly.
export const CONFIG = {
  // run
  runTime: 600,
  escapeSpeed: 2250, // px/s needed to clear
  escapeBonus: 30, // coins for escaping
  speedToKms: 11.2 / 2250, // display factor: escape speed shows as 11.2 km/s

  // field
  fieldRadius: 6000,
  planetRadius: 420,
  zoneInner: 2200,
  zoneOuter: 4200,
  startRadius: 3200,
  planetGM: 0, // gravity is off (the user found it annoying); 3.0e8 gives ~29 px/s^2 at the start radius
  gravityTestGM: 3.0e8, // reference strength used by the gravity tests and the panel's slider range
  moonCount: 6,
  moonGM: 0, // was 1.2e7; moons are now plain obstacles
  moonOrbitSpeed: 0.02, // rad/s
  dustCount: 34,
  dustDrag: 0.55,
  boundaryPush: 600,
  crashRestitution: 0.45,
  crashDamage: 0.012, // hp per px/s of impact speed above 200

  // ship
  baseMaxSpeed: 650, // start slow (3.2 km/s) so growth over the run is felt
  levelSpeedGrowth: 0.015, // +1.5% max speed per level
  atkScale: 1.4, // attack = speed / 100 * atkMult * atkScale (keeps early fodder one-shot at the slower start)
  launchRatio: 0.8, // full gauge launch = maxSpeed * launchRatio
  carry: 0.65, // share of current speed carried into the next launch (same direction)
  chargeTime: 0.7, // seconds to fill the gauge
  minGauge: 0.12,
  minDrag: 14, // screen px; shorter drags boost forward along velocity
  controlScheme: 'draw', // see controls.js SCHEMES
  drawLength: 1000, // draw scheme: path length at full gauge (scales with max speed / base max speed)
  drawTime: 2.5, // real seconds to draw before the path commits itself
  drawTimeScale: 0.06, // world speed while drawing
  drawRunTimeScale: 0.05, // world speed while the ship traces the path (stays nearly frozen so the plan holds)
  drawRunTime: 0.3, // real seconds to trace the whole path, however long it is
  drawStep: 8, // min world distance between path points
  mouseDeadZone: 40, // world units: a cursor this close to the ship does not steer
  nudgeAccel: 450, // nudge/relative schemes: WASD thrust at rest
  nudgeSteer: 0.7, // extra thrust per px/s of speed so fast ships can still bend
  nudgeMaxSpeed: 0.4, // forward thrust only speeds the ship up below this share of max speed
  pivotSpeed: 60, // below this speed the heading stays where the controls left it
  pivotRate: 3.2, // relative scheme: rad/s turning in place
  turnRateMin: 1.6, // rotate scheme: rad/s when tapping A/D
  turnRateMax: 4.6, // rotate scheme: rad/s after holding
  turnAccelTime: 0.35,
  steerRate: 4.5, // rad/s the travel direction swings toward the held WASD direction
  steerAccel: 900, // px/s^2 WASD acceleration while below cruise speed
  steerCruise: 0.4, // WASD alone gets the ship up to this share of max speed
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
