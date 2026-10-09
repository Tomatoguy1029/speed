import { CONFIG } from './config.js';

// Independent touch surfaces keep the steering thumb out of the path input.
export function createMobileControls({ onDraw, onPause, onDebug }) {
  const active = window.matchMedia('(pointer: coarse)').matches || new URLSearchParams(window.location.search).get('mobile') === '1';
  document.body.classList.toggle('mobile', active);
  const root = document.getElementById('mobileControls');
  const menu = document.getElementById('mobileMenu');
  const menuToggle = document.getElementById('mobileMenuToggle');
  const menuPanel = document.getElementById('mobileMenuPanel');
  let menuOpen = false;
  function closeMenu() { menuOpen = false; menuPanel.hidden = true; menuToggle.setAttribute('aria-expanded', 'false'); }
  menuToggle.addEventListener('click', () => {
    reset(); menuOpen = !menuOpen; menuPanel.hidden = !menuOpen;
    menuToggle.setAttribute('aria-expanded', String(menuOpen));
  });
  window.addEventListener('pointerdown', e => {
    if (!menuOpen || menu.contains(e.target)) return;
    closeMenu(); e.preventDefault(); e.stopImmediatePropagation();
  }, true);
  const stick = document.getElementById('mobileStick');
  const knob = stick.querySelector('.stick-knob');
  const draw = document.getElementById('dashBtn');
  if (!active) document.body.append(draw); // preserve the previous touch shortcut on hybrid PCs
  const canvas = document.getElementById('game');
  let pointerId = null, enabled = false, drawing = false, surface = null;
  let originX = 0, originY = 0;
  stick.hidden = true;
  const vector = { x: 0, y: 0 };
  function reset() {
    const captured = surface, id = pointerId;
    pointerId = null; surface = null; vector.x = vector.y = 0;
    stick.hidden = true;
    knob.style.transform = 'translate(0px, 0px)';
    if (captured && id !== null && captured.hasPointerCapture(id)) captured.releasePointerCapture(id);
  }
  function move(e) {
    const radius = stick.getBoundingClientRect().width * 0.35;
    let x = e.clientX - originX;
    let y = e.clientY - originY;
    const scale = Math.min(1, radius / Math.max(1, Math.hypot(x, y)));
    x *= scale; y *= scale;
    // The world uses the existing stick's pixel scale and dead zone.
    vector.x = x / radius * CONFIG.stickRadius; vector.y = y / radius * CONFIG.stickRadius;
    knob.style.transform = `translate(${x}px, ${y}px)`;
  }
  // Capture steering before the canvas's drawing input. The drawing finger stays
  // independent while the movement finger keeps capture on its original surface.
  if (active) {
    const area = canvas;
    area.addEventListener('pointerdown', e => {
      if (!enabled || e.button !== 0 || e.target.closest('button')) return;
      if (drawing) return;
      e.preventDefault(); e.stopImmediatePropagation();
      if (pointerId !== null) return;
      pointerId = e.pointerId; surface = area;
      originX = e.clientX; originY = e.clientY;
      stick.style.left = `${originX}px`; stick.style.top = `${originY}px`;
      stick.hidden = false;
      area.setPointerCapture(pointerId); move(e);
    }, true);
    area.addEventListener('pointermove', e => {
      if (e.pointerId !== pointerId) return;
      e.preventDefault(); e.stopImmediatePropagation(); move(e);
    }, true);
    for (const event of ['pointerup', 'pointercancel', 'lostpointercapture']) {
      area.addEventListener(event, e => {
        if (e.pointerId !== pointerId) return;
        e.stopImmediatePropagation(); reset();
      }, true);
    }
  }
  draw.addEventListener('pointerdown', e => {
    e.preventDefault(); e.stopPropagation();
    if ((!active || enabled) && !draw.disabled) { drawing = true; onDraw(); }
  });
  document.getElementById('mobilePause').addEventListener('click', () => { closeMenu(); onPause(); });
  document.getElementById('mobileDebug').addEventListener('click', () => { closeMenu(); onDebug(); });
  window.addEventListener('blur', () => { reset(); closeMenu(); });
  return {
    active, reset,
    get menuOpen() { return menuOpen; },
    read: () => active ? { ...vector } : null,
    sync(game, running, debugOpen) {
      if (!active) return;
      const playable = running && game.state === 'play' && !debugOpen && !menuOpen;
      if (!playable && enabled) reset();
      enabled = playable;
      root.hidden = !running || ['finishing', 'dying', 'won', 'lost'].includes(game.state);
      menu.hidden = root.hidden;
      if (menu.hidden) closeMenu();
      drawing = game.draw?.phase === 'draw';
      draw.classList.toggle('show', playable && (!game.draw || drawing));
      draw.disabled = !drawing && game.dashMeter < CONFIG.drawMinCharge;
      draw.textContent = drawing ? (game.draw.started ? '発動' : '取消') : '描く';
      draw.style.setProperty('--charge', `${Math.max(0, Math.min(1, game.dashMeter)) * 360}deg`);
      draw.setAttribute('aria-label', drawing ? (game.draw.started ? '発動' : 'キャンセル') : `描く：充填${Math.floor(game.dashMeter * 100)}%`);
      document.getElementById('mobilePause').textContent = game.state === 'paused' ? '再開' : '一時停止';
      document.getElementById('mobileDebug').textContent = debugOpen ? '調整を閉じる' : '調整';
    },
  };
}
