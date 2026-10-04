// Control schemes. buildIntent turns raw input into what the world needs (charge / release / aim);
// controlStep and controlAim run inside the world step for scheme-specific steering and aiming.
import { CONFIG } from './config.js';

export const SCHEMES = [
  { id: 'portal', name: 'ポータル連続突進（試作）', help: 'WASD／矢印で移動、Spaceで設置（水色・残る）、Eで最寄りポータルへ突進（ゲージ満タンが必要）。敵ドロップは紫色・3回で消える。ゲージ満タンでポータルに入ると自動で連続突進。黄色い線と「次」が行き先。到着後は3秒以内に行き先を選ぶ。待機中も敵と弾は通常速度で動き、何もしなければ次へ進む。1〜8の番号キーかWASDで行き先を変更、Spaceですぐ出発、Eで最寄りの次候補へ即出発、Xで終了。移動中にも次を予約できる。通過した軌跡は連続突進が終わるまで残る' },
  { id: 'draw', name: '軌跡を描いて駆け抜ける', help: 'カーソルの方向へ進む（クリック不要。タッチ操作では押した点からずらす仮想スティック）。経験値で高速攻撃ゲージが溜まり、満タンで Space か左下のボタン → 世界がほぼ止まる → 好きな場所をクリックしてそこから軌跡を描き、もう一度 Space／クリックで確定すると、描き始めの点へワープして軌跡を一瞬でなぞって駆け抜ける' },
  { id: 'mouse', name: 'マウスの方向へ進む ＋ Space', help: 'カーソルを置いた方向へ機体が向かう（クリック不要）。Space（またはクリック長押し）でチャージ → 離すとカーソルの方向へ突進' },
  { id: 'steer', name: 'WASD 旋回（画面基準）＋ Space', help: 'WASD で押した方向へ進行方向が素早く回る。Space 長押しでチャージ → 離すと進んでいる方向へ加速' },
  { id: 'relative', name: 'WASD 機体基準 ＋ Space', help: 'W 前進・S ブレーキ・A/D 左右に曲がる（止まっているとその場で旋回）。Space で機体の向きへ加速' },
  { id: 'nudge', name: 'WASD 微推力（画面基準）＋ Space', help: 'WASD で押した方向へ小さく推力。Space で進んでいる方向へ加速' },
  { id: 'rotate', name: 'A/D 照準を回す ＋ Space', help: 'A/D で照準を回す（長押しで速く）、W で進行方向へ、S で反転。Space で照準の向きへ突進' },
  { id: 'aim8', name: 'WASD 8 方向に狙う ＋ Space', help: 'WASD で狙う方向（8 方向）を決め、Space で突進。キーなしなら進行方向へ' },
  { id: 'drag', name: 'マウスで引っ張って離す', help: '押したままドラッグ → 離すとドラッグと逆方向へ突進。長く押すほど強い' },
];

export function schemeById(id) {
  return SCHEMES.find((s) => s.id === id) || SCHEMES.find((s) => s.id === 'draw');
}

// Raw input -> intent { charging, release, aimX, aimY, keyboard, move, snap, cursor }.
// keyboard: the launch direction comes from the scheme (controlAim) instead of a drag.
export function buildIntent(raw, scheme) {
  const it = { move: raw.move, snap: raw.snap, cursor: raw.cursor, press: !!raw.pressed, charging: false, release: false, aimX: 0, aimY: 0, keyboard: false };
  if (scheme === 'portal') {
    it.keyboard = true;
    it.dash = !!raw.dash;
    it.nearestPortal = !!raw.nearestPortal;
    it.portalSelect = raw.portalSelect;
    it.portalIndex = raw.portalIndex;
    it.cancelDash = !!raw.cancelDash;
  } else if (scheme === 'drag') {
    it.charging = raw.pointerDown;
    it.aimX = raw.drag.x; it.aimY = raw.drag.y;
    if (raw.release && raw.releaseSource === 'pointer') { it.release = true; it.aimX = raw.releaseDrag.x; it.aimY = raw.releaseDrag.y; }
  } else if (scheme === 'draw') {
    // mouse: head toward the cursor (no click needed). touch: the press is a virtual stick (offset
    // from the press point). Space / the button fires the gauge-based dash (no charging here).
    it.keyboard = true;
    it.dash = !!raw.dash;
    if (raw.pointerDown && raw.pointerType === 'touch') it.stick = { x: -raw.drag.x, y: -raw.drag.y };
  } else if (scheme === 'mouse') {
    it.charging = raw.space || raw.pointerDown;
    it.keyboard = true;
    it.release = raw.release;
  } else {
    // keyboard schemes keep the slingshot drag as a fallback
    if (raw.pointerDown) { it.charging = true; it.aimX = raw.drag.x; it.aimY = raw.drag.y; }
    else { it.charging = raw.space; it.keyboard = true; }
    if (raw.release) {
      it.release = true;
      if (raw.releaseSource === 'pointer') { it.keyboard = false; it.aimX = raw.releaseDrag.x; it.aimY = raw.releaseDrag.y; }
      else it.keyboard = true;
    }
  }
  return it;
}

const hasMove = (m) => m && (m.x || m.y);

// Swing the travel direction toward `want` at a fixed turn rate (speed kept); below cruise speed
// also accelerate that way so the ship can always get going.
function steerToward(game, want, dt, cruiseShare = CONFIG.steerCruise) {
  const sh = game.ship;
  const sp = Math.hypot(sh.vx, sh.vy);
  if (sp > 1) {
    const cur = Math.atan2(sh.vy, sh.vx);
    const d = Math.atan2(Math.sin(want - cur), Math.cos(want - cur));
    const turn = Math.max(-CONFIG.steerRate * dt, Math.min(CONFIG.steerRate * dt, d));
    const c = Math.cos(turn), s = Math.sin(turn);
    const vx = sh.vx * c - sh.vy * s;
    sh.vy = sh.vx * s + sh.vy * c;
    sh.vx = vx;
  }
  const cruise = game.stats.maxSpeed * cruiseShare;
  if (sp < cruise) {
    const add = Math.min(CONFIG.steerAccel * dt, cruise - sp);
    sh.vx += Math.cos(want) * add;
    sh.vy += Math.sin(want) * add;
  }
  sh.hx = Math.cos(want); sh.hy = Math.sin(want);
}

function stickAngle(stick) {
  if (!stick || Math.hypot(stick.x, stick.y) < CONFIG.stickDeadZone) return null;
  return Math.atan2(stick.y, stick.x);
}

function cursorAngle(game, cursor) {
  if (!cursor) return null;
  const sh = game.ship;
  const dx = cursor.x - sh.x, dy = cursor.y - sh.y;
  if (dx * dx + dy * dy < CONFIG.mouseDeadZone * CONFIG.mouseDeadZone) return null;
  return Math.atan2(dy, dx);
}

// Screen-absolute small thrust (forward thrust only helps while slow).
function nudgeAbsolute(game, move) {
  const sh = game.ship;
  const sp = Math.hypot(sh.vx, sh.vy);
  const acc = CONFIG.nudgeAccel + CONFIG.nudgeSteer * sp;
  let ax = move.x * acc, ay = move.y * acc;
  if (sp > 1) {
    const ux = sh.vx / sp, uy = sh.vy / sp;
    const par = ax * ux + ay * uy;
    if (par > 0 && sp >= game.stats.maxSpeed * CONFIG.nudgeMaxSpeed) { ax -= par * ux; ay -= par * uy; }
  } else {
    sh.hx = move.x; sh.hy = move.y;
  }
  return { ax, ay };
}

// Ship-relative: W forward, S brake (never reverse), A/D bend when moving or pivot when still.
function nudgeRelative(game, move, dt) {
  const sh = game.ship;
  const fwd = -Math.sign(move.y), side = Math.sign(move.x);
  const sp = Math.hypot(sh.vx, sh.vy);
  const rx = -sh.hy, ry = sh.hx;
  let ax = 0, ay = 0;
  if (side) {
    if (sp > CONFIG.pivotSpeed) {
      const acc = CONFIG.nudgeAccel + CONFIG.nudgeSteer * sp;
      ax += rx * side * acc; ay += ry * side * acc;
    } else {
      const a = Math.atan2(sh.hy, sh.hx) + side * CONFIG.pivotRate * dt;
      sh.hx = Math.cos(a); sh.hy = Math.sin(a);
    }
  }
  if (fwd > 0 && sp < game.stats.maxSpeed * CONFIG.nudgeMaxSpeed) { ax += sh.hx * CONFIG.nudgeAccel; ay += sh.hy * CONFIG.nudgeAccel; }
  if (fwd < 0 && sp > 0) {
    const brake = Math.min(CONFIG.nudgeAccel + CONFIG.nudgeSteer * sp, sp / dt);
    ax -= (sh.vx / sp) * brake; ay -= (sh.vy / sp) * brake;
  }
  return { ax, ay };
}

// Rotating aim: A/D turn (accelerating while held), W/S snap to travel direction / flip.
function rotateAim(game, input, dt) {
  const sh = game.ship;
  const turn = input.move ? Math.sign(input.move.x) : 0;
  if (turn) {
    sh.turnHeld += dt;
    const k = Math.min(1, sh.turnHeld / CONFIG.turnAccelTime);
    sh.aimAngle += turn * (CONFIG.turnRateMin + (CONFIG.turnRateMax - CONFIG.turnRateMin) * k) * dt;
  } else {
    sh.turnHeld = 0;
  }
  if (input.snap === 'forward' && Math.hypot(sh.vx, sh.vy) > 1) sh.aimAngle = Math.atan2(sh.vy, sh.vx);
  else if (input.snap === 'back') sh.aimAngle += Math.PI;
  sh.aimAngle = Math.atan2(Math.sin(sh.aimAngle), Math.cos(sh.aimAngle));
}

const ZERO = { ax: 0, ay: 0 };

// Per-step steering. Returns extra acceleration for the physics step.
export function controlStep(game, input, dt) {
  const sh = game.ship;
  switch (game.scheme) {
    case 'draw': {
      // mouse: head toward the cursor at the usual cruise speed (no click needed).
      // touch: a virtual stick; pushing it further goes faster.
      const throttle = (k) => CONFIG.steerCruise + (CONFIG.stickCruiseMax - CONFIG.steerCruise) * Math.max(0, Math.min(1, k));
      if (input.stick) {
        const a = stickAngle(input.stick);
        if (a !== null) {
          const len = Math.hypot(input.stick.x, input.stick.y);
          steerToward(game, a, dt, throttle((len - CONFIG.stickDeadZone) / Math.max(1, CONFIG.stickRadius - CONFIG.stickDeadZone)));
        }
        return ZERO;
      }
      const a = cursorAngle(game, input.cursor);
      if (a !== null) steerToward(game, a, dt);
      return ZERO;
    }
    case 'mouse': {
      const a = cursorAngle(game, input.cursor);
      if (a !== null) steerToward(game, a, dt);
      return ZERO;
    }
    case 'portal':
    case 'steer':
      if (hasMove(input.move)) steerToward(game, Math.atan2(input.move.y, input.move.x), dt);
      return ZERO;
    case 'nudge':
      return hasMove(input.move) ? nudgeAbsolute(game, input.move) : ZERO;
    case 'relative':
      return hasMove(input.move) ? nudgeRelative(game, input.move, dt) : ZERO;
    case 'rotate':
      rotateAim(game, input, dt);
      return ZERO;
    default:
      return ZERO;
  }
}

// Scheme aim for keyboard/hover launches: a vector, or null to boost along the heading.
export function controlAim(game, input) {
  const sh = game.ship;
  switch (game.scheme) {
    case 'draw': {
      const a = input.stick ? stickAngle(input.stick) : cursorAngle(game, input.cursor);
      return a === null ? null : { x: Math.cos(a) * 100, y: Math.sin(a) * 100 };
    }
    case 'mouse': {
      const a = cursorAngle(game, input.cursor);
      return a === null ? null : { x: Math.cos(a) * 100, y: Math.sin(a) * 100 };
    }
    case 'rotate':
      return { x: Math.cos(sh.aimAngle) * 100, y: Math.sin(sh.aimAngle) * 100 };
    case 'aim8':
      return hasMove(input.move) ? { x: input.move.x * 100, y: input.move.y * 100 } : null;
    default:
      return null;
  }
}
