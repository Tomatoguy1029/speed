// Launch direction is opposite to the drag: start - current.
export function aimFromDrag(sx, sy, cx, cy) {
  return { x: sx - cx, y: sy - cy };
}

const TURN_KEYS = { KeyA: -1, ArrowLeft: -1, KeyD: 1, ArrowRight: 1 };
const SNAP_KEYS = { KeyW: 'forward', ArrowUp: 'forward', KeyS: 'back', ArrowDown: 'back' };
const KEY_CODES = { a: 'KeyA', d: 'KeyD', w: 'KeyW', s: 'KeyS', arrowleft: 'ArrowLeft', arrowright: 'ArrowRight', arrowup: 'ArrowUp', arrowdown: 'ArrowDown' };

// Physical key position (works with IME on), falling back to the key name.
function keyCode(e) {
  return e.code || KEY_CODES[(e.key || '').toLowerCase()] || '';
}

const isSpace = (e) => e.code === 'Space' || e.key === ' ';

export function createInput(el, keyTarget = typeof window !== 'undefined' ? window : null) {
  const st = {
    down: false, sx: 0, sy: 0, cx: 0, cy: 0, pointerId: null, enabled: true,
    release: false, relX: 0, relY: 0,
    keys: new Set(), space: false, snap: null, relKeyboard: false,
  };
  el.addEventListener('pointerdown', (e) => {
    if (!st.enabled || e.button > 0) return;
    st.down = true; st.pointerId = e.pointerId;
    st.sx = st.cx = e.clientX; st.sy = st.cy = e.clientY;
    try { el.setPointerCapture(e.pointerId); } catch { /* synthetic or lost pointer */ }
  });
  el.addEventListener('pointermove', (e) => {
    if (!st.down || e.pointerId !== st.pointerId) return;
    st.cx = e.clientX; st.cy = e.clientY;
  });
  const up = (e) => {
    if (!st.down || e.pointerId !== st.pointerId) return;
    st.cx = e.clientX; st.cy = e.clientY;
    const a = aimFromDrag(st.sx, st.sy, st.cx, st.cy);
    st.down = false; st.release = true; st.relX = a.x; st.relY = a.y; st.relKeyboard = false;
  };
  el.addEventListener('pointerup', up);
  el.addEventListener('pointercancel', up);
  el.addEventListener('contextmenu', (e) => e.preventDefault());

  if (keyTarget) {
    keyTarget.addEventListener('keydown', (e) => {
      const code = keyCode(e);
      if (TURN_KEYS[code]) { st.keys.add(code); if (st.enabled) e.preventDefault(); }
      if (SNAP_KEYS[code]) { if (!e.repeat) st.snap = SNAP_KEYS[code]; if (st.enabled) e.preventDefault(); }
      if (isSpace(e)) {
        if (st.enabled) e.preventDefault();
        if (!st.enabled || e.repeat || st.space || st.down) return;
        st.space = true;
      }
    });
    keyTarget.addEventListener('keyup', (e) => {
      st.keys.delete(keyCode(e));
      if (isSpace(e) && st.space) {
        st.space = false; st.release = true; st.relX = 0; st.relY = 0; st.relKeyboard = true;
      }
    });
    keyTarget.addEventListener('blur', () => { st.keys.clear(); st.space = false; });
  }

  return {
    state: st,
    // keyboard: the aim comes from the ship's aim angle (world applies turn/snap).
    read() {
      let a = { x: 0, y: 0 };
      if (st.release) a = { x: st.relX, y: st.relY };
      else if (st.down) a = aimFromDrag(st.sx, st.sy, st.cx, st.cy);
      let turn = 0;
      for (const k of st.keys) turn += TURN_KEYS[k] || 0;
      const out = {
        charging: st.down || st.space,
        aimX: a.x, aimY: a.y,
        release: st.release,
        keyboard: st.release ? st.relKeyboard : st.space && !st.down,
        turn: Math.sign(turn),
        snap: st.snap,
      };
      st.release = false;
      st.snap = null;
      return out;
    },
    reset() { st.down = false; st.space = false; st.release = false; st.pointerId = null; },
  };
}
