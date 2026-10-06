// All tunable numbers live here. The debug panel edits this object directly.
export const CONFIG = {
  // run
  runTime: 600,
  escapeSpeed: 2250, // legacy speed reference for visual effects, no longer a clear condition
  escapeBonus: 30, // clear bonus (legacy key retained)
  bossTime: 420, // one provisional boss appears after seven minutes
  bossHp: 2200,
  bossArmor: 14,
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
  baseMaxSpeed: 500, // start slow (2.5 km/s) so growth over the run is felt
  levelSpeedGrowth: 0.02, // +2% max speed per level
  levelAtkGrowth: 0.02, // +2% attack per level
  levelHpGrowth: 4, // +4 max HP per level
  levelChargeGrowth: 0.01, // -1% charge time per level (down to 60%)
  dropBase: 0.005, // module drop chance = dropBase * power^dropPowerExp (power = enemy xp)
  dropPowerExp: 1,
  dropMax: 0.5,
  drawDropScale: 0.1, // fewer module drops even with five times as many enemies
  drawDropInterval: 35, // minimum seconds between enemy module drops in draw mode
  drawOfferInterval: 30, // minimum play seconds between selection screens
  drawCapsuleCount: 2,
  drawCapsuleInterval: 40,
  dupBonus: 0.15, // each duplicate pickup adds +15% to that module's effect
  atkScale: 1.8, // attack = speed / 100 * atkMult * atkScale (keeps early fodder one-shot at the slower start)
  launchRatio: 0.8, // full gauge launch = maxSpeed * launchRatio
  carry: 0.65, // share of current speed carried into the next launch (same direction)
  chargeTime: 0.7, // seconds to fill the gauge
  minGauge: 0.12,
  minDrag: 14, // screen px; shorter drags boost forward along velocity
  controlScheme: 'draw', // see controls.js SCHEMES
  portalSpacing: 260, // minimum separation between portals (including manual ones)
  portalManualMax: 12,
  portalDropMax: 36,
  portalDropChance: 0, // temporarily disabled; portals are placed with B
  portalDropUses: 3,
  portalRefillInterval: 1.5, // nearby kills replenish at most once per this many world seconds
  portalMinHop: 100,
  portalReach: 900, // scales with max speed and path-length modules
  portalBudget: 2400, // total distance per activation; same growth as reach
  portalExitHold: 0.5, // real seconds holding Space to leave; a short release confirms a route
  portalEdgeCooldown: 10, // real play seconds; shared by both directions and survives leaving
  portalChooseScale: 1, // enemies and bullets keep normal speed while choosing
  portalEntryRadius: 28, // ship body + this radius triggers a portal on entry
  portalEntryCooldown: 0.6, // world seconds after ending a chain
  portalHopTime: 0.22, // maximum real seconds for each segment
  portalWaveRadius: 160,
  portalWaveDamage: 0.9,
  portalLoopDamage: 1.2, // attack power x rarity multiplier inside a closed path
  portalLoopSplashRadius: 90, // legendary: each enclosed enemy also explodes outward
  portalLoopSplashDamage: 0.5,
  portalLoopMinArea: 64, // reject degenerate backtracking loops
  drawLength: 1000, // draw scheme: path length at full gauge (scales with max speed / base max speed)
  drawTime: 5, // real seconds to draw before the path commits itself
  drawTimeScale: 0.05, // world speed while drawing
  drawRunSlowRef: 260, // world speed while tracing = drawRunSlowRef / dash speed (faster ship -> slower world)
  drawRunScaleMin: 0.03, // ...but never slower than this
  waveRadius: 45, // reach of the wave a traced path gives off (the band's half-width); the ship body itself stays shipRadius
  waveDamage: 0.5, // wave damage = attack x this (ignores armor; the body hit is separate)
  drawRunTime: 0.5, // real seconds to trace the whole path, however long it is (plus kill hitstops)
  killHitstop: 0.045, // seconds of hitstop per one-shot ram kill (x1.8 big, x1.3 crit)
  killHitstopCap: 0.6, // max hitstop per dash
  enemyAimLag: 0.5, // seconds: enemies aim at a lagging copy of the ship's position
  enemyAimSpeed: 450, // px/s: that copy never moves faster than this (dashes leave enemy aim behind)
  killHitstopRegen: 0.3, // outside dashes the hitstop budget refills this many seconds per second
  drawStep: 8, // min world distance between path points
  stickCruiseMax: 0.75, // draw-mode stick pushed to its edge cruises up to this share of max speed (ramming = the normal attack)
  dashXpFrac: 0.35, // draw mode: XP to fill the dash gauge = this share of the current level's XP (scaled by charge-time stats)
  stickDeadZone: 8, // screen px: draw-mode stick offset below this does not steer
  stickRadius: 70, // screen px: stick offset for full speed (the press point stays fixed)
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
  densityMult: 5,
  enemySpacing: 12, // gap between bodies; crowds stay legible instead of overlapping
  enemyPursuitSpread: 280, // distributed approach targets, fading out near the actual ship
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
