const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

function resize() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.floor(window.innerWidth * dpr);
  canvas.height = Math.floor(window.innerHeight * dpr);
}
window.addEventListener('resize', resize);
resize();

function frame() {
  ctx.fillStyle = '#04050b';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
