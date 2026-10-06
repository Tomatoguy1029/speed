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
const KEY_CODES = { a: 'KeyA', d: 'KeyD', w: 'KeyW', s: 'KeyS', b: 'KeyB', arrowleft: 'ArrowLeft', arrowright: 'ArrowRight', arrowup: 'ArrowUp', arrowdown: 'ArrowDown' };

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
    down: false, sx: 0, sy: 0, cx: 0, cy: 0, pointerId: null, enabled: true, hover: null, click: null,
    release: false, relSource: null, relX: 0, relY: 0,
    keys: new Set(), space: false, spaceStartedAt: 0, spaceDuration: 0, cycle: 0, snap: null, pressed: false, dash: false, place: false, confirm: false, clicks: [],
  };
  // pointer position in the element's own CSS pixels (the same space the canvas is drawn in)
  const local = (e) => {
    const b = el.getBoundingClientRect ? el.getBoundingClientRect() : null;
    return b ? { x: e.clientX - b.left, y: e.clientY - b.top } : { x: e.clientX, y: e.clientY };
  };
  el.addEventListener('pointerdown', (e) => {
    st.hover = local(e);
    if (st.enabled && e.button === 2) { st.confirm = true; e.preventDefault(); }
    if (st.enabled && e.button === 0) { st.pressed = true; st.click = st.hover; st.clicks.push(st.hover); }
    if (!st.enabled || e.button > 0) return;
    st.down = true; st.pointerId = e.pointerId; st.pointerType = e.pointerType || 'mouse';
    ({ x: st.sx, y: st.sy } = local(e)); st.cx = st.sx; st.cy = st.sy;
    try { el.setPointerCapture(e.pointerId); } catch { /* synthetic or lost pointer */ }
  });
  el.addEventListener('pointermove', (e) => {
    st.hover = local(e);
    if (!st.down || e.pointerId !== st.pointerId) return;
    ({ x: st.cx, y: st.cy } = local(e));
  });
  const up = (e) => {
    if (!st.down || e.pointerId !== st.pointerId) return;
    ({ x: st.cx, y: st.cy } = local(e));
    const a = aimFromDrag(st.sx, st.sy, st.cx, st.cy);
    st.down = false; st.release = true; st.relSource = 'pointer'; st.relX = a.x; st.relY = a.y;
  };
  el.addEventListener('pointerup', up);
  el.addEventListener('pointercancel', up);
  el.addEventListener('contextmenu', (e) => e.preventDefault());

  if (keyTarget) {
    keyTarget.addEventListener('keydown', (e) => {
      const code = keyCode(e);
      if (MOVE_KEYS[code]) {
        const fresh = st.enabled && !e.repeat && !st.keys.has(code);
        st.keys.add(code); if (st.enabled) e.preventDefault();
        if (st.enabled && (fresh || e.repeat)) {
          if (code === 'KeyA' || code === 'ArrowLeft') st.cycle--;
          if (code === 'KeyD' || code === 'ArrowRight') st.cycle++;
        }
      }
      if (code === 'KeyB' && st.enabled) { e.preventDefault(); if (!e.repeat) st.place = true; }
      if (SNAP_KEYS[code] && !e.repeat) st.snap = SNAP_KEYS[code];
      if (isSpace(e)) {
        if (st.enabled) e.preventDefault();
        if (!st.enabled || e.repeat || st.space) return;
        st.pressed = true;
        st.dash = true;
        st.space = true; st.spaceStartedAt = performance.now(); st.spaceDuration = 0;
      }
    });
    keyTarget.addEventListener('keyup', (e) => {
      st.keys.delete(keyCode(e));
      if (isSpace(e) && st.space) {
        st.spaceDuration = (performance.now() - st.spaceStartedAt) / 1000;
        st.space = false; st.release = true; st.relSource = 'space'; st.relX = 0; st.relY = 0;
      }
    });
    keyTarget.addEventListener('blur', () => { st.keys.clear(); st.space = false; st.release = false; st.spaceDuration = 0; st.cycle = 0; });
  }

  return {
    state: st,
    read() {
      const out = {
        move: st.enabled ? moveVector(st.keys) : { x: 0, y: 0 },
        snap: st.enabled ? st.snap : null,
        space: st.enabled && st.space,
        spaceHeldTime: st.enabled ? (st.space ? (performance.now() - st.spaceStartedAt) / 1000 : st.spaceDuration) : 0,
        portalCycle: st.enabled ? st.cycle : 0,
        pressed: st.pressed, // a fresh Space press or click this frame (commits a drawn path)
        dash: st.dash, // a fresh Space press or the on-screen dash button (draw mode)
        place: st.enabled && st.place,
        confirm: st.enabled && st.confirm,
        pointerDown: st.down,
        pointerType: st.pointerType || 'mouse', // 'touch' turns the press into a virtual stick (draw mode)
        drag: st.down ? aimFromDrag(st.sx, st.sy, st.cx, st.cy) : { x: 0, y: 0 },
        hover: st.hover,
        click: st.click, // preserve the press position even if the mouse moves before the next frame
        clicks: st.clicks, // every press this frame, in order (fast clicks between frames are not lost)
        release: st.release,
        releaseSource: st.release ? st.relSource : null,
        releaseDrag: { x: st.relX, y: st.relY },
      };
      st.release = false;
      st.snap = null;
      st.pressed = false;
      st.click = null;
      st.clicks = [];
      st.dash = false;
      st.place = false;
      st.confirm = false;
      st.cycle = 0; st.spaceDuration = 0;
      return out;
    },
    triggerDash() { if (st.enabled) st.dash = true; },
    reset() { st.down = false; st.space = false; st.spaceDuration = 0; st.cycle = 0; st.release = false; st.snap = null; st.pressed = false; st.click = null; st.clicks = []; st.dash = false; st.place = false; st.confirm = false; st.keys.clear(); st.pointerId = null; },
  };
}
