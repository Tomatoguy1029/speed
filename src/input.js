// Raw input only: keys, Space, pointer drag and hover. Control schemes (controls.js) turn this into intent.

// Launch direction is opposite to the drag: start - current.
export function aimFromDrag(sx, sy, cx, cy) {
  return { x: sx - cx, y: sy - cy };
}

const MOVE_KEYS = {
  KeyW: [0, -1], ArrowUp: [0, -1],
  KeyS: [0, 1], ArrowDown: [0, 1],
  KeyA: [-1, 0], ArrowLeft: [-1, 0],
  KeyD: [1, 0], ArrowRight: [1, 0],
};
const SNAP_KEYS = { KeyW: 'forward', ArrowUp: 'forward', KeyS: 'back', ArrowDown: 'back' };
const KEY_CODES = { a: 'KeyA', d: 'KeyD', w: 'KeyW', s: 'KeyS', arrowleft: 'ArrowLeft', arrowright: 'ArrowRight', arrowup: 'ArrowUp', arrowdown: 'ArrowDown' };

// Held movement keys -> unit vector (zero when none or cancelled).
export function moveVector(keys) {
  let dx = 0, dy = 0;
  for (const k of keys) {
    const d = MOVE_KEYS[k];
    if (d) { dx += d[0]; dy += d[1]; }
  }
  dx = Math.sign(dx); dy = Math.sign(dy);
  if (dx === 0 && dy === 0) return { x: 0, y: 0 };
  const len = Math.hypot(dx, dy);
  return { x: dx / len || 0, y: dy / len || 0 };
}

// Physical key position (works with IME on), falling back to the key name.
function keyCode(e) {
  return e.code || KEY_CODES[(e.key || '').toLowerCase()] || '';
}

const isSpace = (e) => e.code === 'Space' || e.key === ' ';

export function createInput(el, keyTarget = typeof window !== 'undefined' ? window : null) {
  const st = {
    down: false, sx: 0, sy: 0, cx: 0, cy: 0, pointerId: null, enabled: true, hover: null,
    release: false, relSource: null, relX: 0, relY: 0,
    keys: new Set(), space: false, snap: null, pressed: false,
  };
  el.addEventListener('pointerdown', (e) => {
    st.hover = { x: e.clientX, y: e.clientY };
    if (st.enabled && e.button === 0) st.pressed = true;
    if (!st.enabled || e.button > 0 || st.space) return;
    st.down = true; st.pointerId = e.pointerId;
    st.sx = st.cx = e.clientX; st.sy = st.cy = e.clientY;
    try { el.setPointerCapture(e.pointerId); } catch { /* synthetic or lost pointer */ }
  });
  el.addEventListener('pointermove', (e) => {
    st.hover = { x: e.clientX, y: e.clientY };
    if (!st.down || e.pointerId !== st.pointerId) return;
    st.cx = e.clientX; st.cy = e.clientY;
  });
  const up = (e) => {
    if (!st.down || e.pointerId !== st.pointerId) return;
    st.cx = e.clientX; st.cy = e.clientY;
    const a = aimFromDrag(st.sx, st.sy, st.cx, st.cy);
    st.down = false; st.release = true; st.relSource = 'pointer'; st.relX = a.x; st.relY = a.y;
  };
  el.addEventListener('pointerup', up);
  el.addEventListener('pointercancel', up);
  el.addEventListener('contextmenu', (e) => e.preventDefault());

  if (keyTarget) {
    keyTarget.addEventListener('keydown', (e) => {
      const code = keyCode(e);
      if (MOVE_KEYS[code]) { st.keys.add(code); if (st.enabled) e.preventDefault(); }
      if (SNAP_KEYS[code] && !e.repeat) st.snap = SNAP_KEYS[code];
      if (isSpace(e)) {
        if (st.enabled) e.preventDefault();
        if (!st.enabled || e.repeat || st.space) return;
        st.pressed = true;
        if (st.down) return;
        st.space = true;
      }
    });
    keyTarget.addEventListener('keyup', (e) => {
      st.keys.delete(keyCode(e));
      if (isSpace(e) && st.space) {
        st.space = false; st.release = true; st.relSource = 'space'; st.relX = 0; st.relY = 0;
      }
    });
    keyTarget.addEventListener('blur', () => { st.keys.clear(); st.space = false; });
  }

  return {
    state: st,
    read() {
      const out = {
        move: st.enabled ? moveVector(st.keys) : { x: 0, y: 0 },
        snap: st.enabled ? st.snap : null,
        space: st.space,
        pressed: st.pressed, // a fresh Space press or click this frame (commits a drawn path)
        pointerDown: st.down,
        drag: st.down ? aimFromDrag(st.sx, st.sy, st.cx, st.cy) : { x: 0, y: 0 },
        hover: st.hover,
        release: st.release,
        releaseSource: st.release ? st.relSource : null,
        releaseDrag: { x: st.relX, y: st.relY },
      };
      st.release = false;
      st.snap = null;
      st.pressed = false;
      return out;
    },
    reset() { st.down = false; st.space = false; st.release = false; st.snap = null; st.pressed = false; st.pointerId = null; },
  };
}
