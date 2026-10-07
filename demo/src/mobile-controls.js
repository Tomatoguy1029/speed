import { CONFIG } from './config.js';

// Independent touch surfaces keep the steering thumb out of the path input.
export function createMobileControls({ onDraw, onPause, onDebug }) {
  const active = window.matchMedia('(pointer: coarse)').matches || new URLSearchParams(window.location.search).get('mobile') === '1';
  document.body.classList.toggle('mobile', active);
  const root = document.getElementById('mobileControls');
  const stick = document.getElementById('mobileStick');
  const knob = stick.querySelector('.stick-knob');
  const draw = document.getElementById('dashBtn');
  if (!active) document.body.append(draw); // preserve the previous touch shortcut on hybrid PCs
  let pointerId = null, enabled = false;
  const vector = { x: 0, y: 0 };
  function reset() {
    pointerId = null; vector.x = vector.y = 0;
    knob.style.transform = 'translate(0px, 0px)';
  }
  function move(e) {
    const rect = stick.getBoundingClientRect();
    const radius = rect.width * 0.35;
    let x = e.clientX - rect.left - rect.width / 2;
    let y = e.clientY - rect.top - rect.height / 2;
    const scale = Math.min(1, radius / Math.max(1, Math.hypot(x, y)));
    x *= scale; y *= scale;
    // The world uses the existing stick's pixel scale and dead zone.
    vector.x = x / radius * CONFIG.stickRadius; vector.y = y / radius * CONFIG.stickRadius;
    knob.style.transform = `translate(${x}px, ${y}px)`;
  }
  stick.addEventListener('pointerdown', e => {
    if (!enabled || pointerId !== null) return;
    e.preventDefault(); pointerId = e.pointerId;
    stick.setPointerCapture(pointerId); move(e);
  });
  stick.addEventListener('pointermove', e => { if (e.pointerId === pointerId) { e.preventDefault(); move(e); } });
  for (const event of ['pointerup', 'pointercancel', 'lostpointercapture']) {
    stick.addEventListener(event, e => { if (e.pointerId === pointerId) reset(); });
  }
  draw.addEventListener('pointerdown', e => { e.preventDefault(); e.stopPropagation(); if ((!active || enabled) && !draw.disabled) onDraw(); });
  document.getElementById('mobilePause').addEventListener('click', onPause);
  document.getElementById('mobileDebug').addEventListener('click', onDebug);
  window.addEventListener('blur', reset);
  return {
    active, reset,
    read: () => active ? { ...vector } : null,
    sync(game, running, debugOpen) {
      if (!active) return;
      const playable = running && game.state === 'play' && !debugOpen;
      if (!playable && enabled) reset();
      enabled = playable;
      document.body.classList.toggle('mobile-running', running && !['finishing', 'dying', 'won', 'lost'].includes(game.state));
      root.hidden = !running || ['finishing', 'dying', 'won', 'lost'].includes(game.state);
      stick.classList.toggle('inactive', !enabled);
      const drawing = game.draw?.phase === 'draw';
      draw.classList.toggle('show', playable && (!game.draw || drawing));
      draw.disabled = !drawing && game.dashMeter < CONFIG.drawMinCharge;
      draw.textContent = drawing ? (game.draw.started ? '発動' : 'キャンセル') : `描く ${Math.floor(game.dashMeter * 100)}%`;
      document.getElementById('mobilePause').textContent = game.state === 'paused' ? '再開' : '一時停止';
      document.getElementById('mobileDebug').textContent = debugOpen ? '調整を閉じる' : '調整';
    },
  };
}
