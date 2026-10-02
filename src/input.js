// Launch direction is opposite to the drag: start - current.
export function aimFromDrag(sx, sy, cx, cy) {
  return { x: sx - cx, y: sy - cy };
}

const DIR_KEYS = {
  w: [0, -1], arrowup: [0, -1],
  s: [0, 1], arrowdown: [0, 1],
  a: [-1, 0], arrowleft: [-1, 0],
  d: [1, 0], arrowright: [1, 0],
};
const CODE_NAMES = { KeyW: 'w', KeyA: 'a', KeyS: 's', KeyD: 'd', ArrowUp: 'arrowup', ArrowDown: 'arrowdown', ArrowLeft: 'arrowleft', ArrowRight: 'arrowright' };

// Keyboard aim: held direction keys -> vector of length 100 (or zero when none / cancelled).
export function keyAim(keys) {
  let dx = 0, dy = 0;
  for (const k of keys) {
    const d = DIR_KEYS[k];
    if (d) { dx += d[0]; dy += d[1]; }
  }
  dx = Math.sign(dx); dy = Math.sign(dy);
  if (dx === 0 && dy === 0) return { x: 0, y: 0 };
  const len = Math.hypot(dx, dy);
  return { x: (dx / len) * 100 || 0, y: (dy / len) * 100 || 0 };
}

function keyName(e) {
  return CODE_NAMES[e.code] || (e.key || '').toLowerCase();
}

const isSpace = (e) => e.code === 'Space' || e.key === ' ';

export function createInput(el, keyTarget = typeof window !== 'undefined' ? window : null) {
  const st = {
    down: false, sx: 0, sy: 0, cx: 0, cy: 0, pointerId: null, enabled: true,
    release: false, relX: 0, relY: 0,
    keys: new Set(), space: false,
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
    st.down = false; st.release = true; st.relX = a.x; st.relY = a.y;
  };
  el.addEventListener('pointerup', up);
  el.addEventListener('pointercancel', up);
  el.addEventListener('contextmenu', (e) => e.preventDefault());

  if (keyTarget) {
    keyTarget.addEventListener('keydown', (e) => {
      const name = keyName(e);
      if (DIR_KEYS[name]) { st.keys.add(name); if (st.enabled) e.preventDefault(); }
      if (isSpace(e)) {
        if (st.enabled) e.preventDefault();
        if (!st.enabled || e.repeat || st.space || st.down) return;
        st.space = true;
      }
    });
    keyTarget.addEventListener('keyup', (e) => {
      const name = keyName(e);
      if (DIR_KEYS[name]) st.keys.delete(name);
      if (isSpace(e) && st.space) {
        const a = keyAim(st.keys);
        st.space = false; st.release = true; st.relX = a.x; st.relY = a.y;
      }
    });
    keyTarget.addEventListener('blur', () => { st.keys.clear(); st.space = false; });
  }

  return {
    state: st,
    read() {
      let a;
      if (st.release) a = { x: st.relX, y: st.relY };
      else if (st.down) a = aimFromDrag(st.sx, st.sy, st.cx, st.cy);
      else a = keyAim(st.keys);
      const out = { charging: st.down || st.space, aimX: a.x, aimY: a.y, release: st.release };
      st.release = false;
      return out;
    },
    reset() { st.down = false; st.space = false; st.release = false; st.pointerId = null; },
  };
}
