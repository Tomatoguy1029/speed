// All tunable numbers live here. The debug panel edits this object directly.
export const CONFIG = {
  // run
  runTime: 600,
  escapeSpeed: 2800, // px/s needed to clear
  speedToKms: 0.004, // display factor: 2800 px/s => 11.2 km/s

  // field
  fieldRadius: 6000,
  planetRadius: 420,
  zoneInner: 2200,
  zoneOuter: 4200,
  startRadius: 3200,

  // ship
  baseMaxSpeed: 1000,
  launchRatio: 0.8, // full gauge launch = maxSpeed * launchRatio
  carry: 0.65, // share of current speed carried into the next launch (same direction)
  chargeTime: 0.7, // seconds to fill the gauge
  minGauge: 0.12,
  minDrag: 14, // screen px; shorter drags boost forward along velocity
  boostDuration: 0.9, // seconds after launch with no cruise drag
  cruiseDrag: 0.3, // per second, once boost energy runs out
  cruiseFloor: 0.35, // cruise drag never slows below this share of max speed
  overcapDecay: 0.45, // per second decay of speed above max speed
  shipRadius: 16,
  baseHP: 100,
  invulnTime: 0.6,
  pickupRadius: 140,

  // camera
  baseView: 1100, // world units visible on the shorter screen side at rest
  zoomRefSpeed: 700,
  zoomExp: 0.7,
  zoomMin: 0.28,
  lookAhead: 0.32,
};
