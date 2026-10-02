// Launch direction is opposite to the drag: start - current.
export function aimFromDrag(sx, sy, cx, cy) {
  return { x: sx - cx, y: sy - cy };
}

export function createInput(el) {
  const st = { down: false, sx: 0, sy: 0, cx: 0, cy: 0, release: false, relX: 0, relY: 0, pointerId: null, enabled: true };
  el.addEventListener('pointerdown', (e) => {
    if (!st.enabled || e.button > 0) return;
    st.down = true; st.pointerId = e.pointerId;
    st.sx = st.cx = e.clientX; st.sy = st.cy = e.clientY;
    el.setPointerCapture?.(e.pointerId);
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

  return {
    state: st,
    read() {
      const a = st.release ? { x: st.relX, y: st.relY } : aimFromDrag(st.sx, st.sy, st.cx, st.cy);
      const out = { charging: st.down, aimX: a.x, aimY: a.y, release: st.release };
      st.release = false;
      return out;
    },
    reset() { st.down = false; st.release = false; },
  };
}
