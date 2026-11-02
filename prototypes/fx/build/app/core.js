// ===== SPEED FX 試作ビューア：描画基盤 =====
// 画面は本番の基準（1280×720、ワールド1100が画面高、論理ピクセル＝画面高225）で描く。
const W = 1280, H = 720;
const Z = H / 1100;            // ワールド→画面（run_simulation.gd _base_zoom、最高速が基準以下のとき）
const LP = H / 225;            // 論理ピクセル1つの画面px（marlin_warning.gdshader の REFERENCE_HEIGHT）
const LW = Math.round(W / LP), LH = 225;
const CS = DATA.config.character_scale; // 1.3
const TAU = Math.PI * 2;
const IMG = {};
const PX = PIXELFX.core;
const hexc = (s) => PX.hex(s);

// ---------- 小道具
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); };
const angDiff = (a, b) => { let d = (a - b) % TAU; if (d > Math.PI) d -= TAU; if (d < -Math.PI) d += TAU; return d; };
const rotToward = (a, b, step) => { const d = angDiff(b, a); return Math.abs(d) <= step ? b : a + Math.sign(d) * step; };
const V = (x, y) => ({ x, y });
const add = (a, b) => V(a.x + b.x, a.y + b.y), sub = (a, b) => V(a.x - b.x, a.y - b.y), mul = (a, k) => V(a.x * k, a.y * k);
const len = (a) => Math.hypot(a.x, a.y), dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const norm = (a) => { const l = len(a) || 1; return V(a.x / l, a.y / l); };
const fromA = (a) => V(Math.cos(a), Math.sin(a));
const angOf = (a) => Math.atan2(a.y, a.x);
const orth = (a) => V(-a.y, a.x);
const lerpV = (a, b, t) => V(lerp(a.x, b.x, t), lerp(a.y, b.y, t));
const rgba = (c, a = 1) => { const k = typeof c === 'string' ? parseCol(c) : c; return `rgba(${k.r * 255 | 0},${k.g * 255 | 0},${k.b * 255 | 0},${clamp(a * (k.a ?? 1))})`; };
function parseCol(s) { s = s.replace('#', ''); if (s.length === 3) s = s.split('').map(c => c + c).join(''); return { r: parseInt(s.slice(0, 2), 16) / 255, g: parseInt(s.slice(2, 4), 16) / 255, b: parseInt(s.slice(4, 6), 16) / 255, a: s.length >= 8 ? parseInt(s.slice(6, 8), 16) / 255 : 1 }; }
const lighten = (c, k) => ({ r: c.r + (1 - c.r) * k, g: c.g + (1 - c.g) * k, b: c.b + (1 - c.b) * k, a: c.a ?? 1 });
const toHex = (c) => '#' + [c.r, c.g, c.b].map(v => Math.round(clamp(v) * 255).toString(16).padStart(2, '0')).join('');
// 決定的な乱数（scrubしても同じ絵になる）
function hash(n) { const s = Math.sin(n * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s); }
function mkRng(seed) { let s = (seed >>> 0) || 1; return () => { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return ((s >>> 0) % 100000) / 100000; }; }

// ---------- キャンバス
const cv = document.getElementById('stage');
const g = cv.getContext('2d');
cv.width = W; cv.height = H;
g.imageSmoothingEnabled = false;
// pixelFX のフレーム（後ろ・前）を論理ピクセルの解像度で持ち、色は通常合成・光は加算合成する
const FR = { back: PX.createFrame(LW, LH), front: PX.createFrame(LW, LH) };
const fxCanvas = document.createElement('canvas'); fxCanvas.width = LW; fxCanvas.height = LH;
const fxg = fxCanvas.getContext('2d');
const fxColor = fxg.createImageData(LW, LH), fxLight = fxg.createImageData(LW, LH);
const lightCanvas = document.createElement('canvas'); lightCanvas.width = LW; lightCanvas.height = LH;
const lg = lightCanvas.getContext('2d');
function blitFrame(f) {
  const C = f.color, L = f.light, oc = fxColor.data, ol = fxLight.data;
  let anyC = false, anyL = false;
  for (let i = 0, n = LW * LH; i < n; i++) {
    const c = C[i], l = L[i], j = i * 4;
    if (c) { anyC = true; oc[j] = c & 255; oc[j + 1] = (c >>> 8) & 255; oc[j + 2] = (c >>> 16) & 255; oc[j + 3] = c >>> 24; } else oc[j + 3] = 0;
    if (l & 0xffffff) { anyL = true; ol[j] = l & 255; ol[j + 1] = (l >>> 8) & 255; ol[j + 2] = (l >>> 16) & 255; ol[j + 3] = 255; } else { ol[j] = ol[j + 1] = ol[j + 2] = 0; ol[j + 3] = 255; }
  }
  g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.imageSmoothingEnabled = false;
  if (anyC) { fxg.putImageData(fxColor, 0, 0); g.drawImage(fxCanvas, 0, 0, LW * LP, LH * LP); }
  if (anyL) { lg.putImageData(fxLight, 0, 0); g.globalCompositeOperation = 'lighter'; g.drawImage(lightCanvas, 0, 0, LW * LP, LH * LP); }
  g.restore();
}
// ---------- カメラ
const cam = { x: 0, y: 0, shake: 0 };
function worldTransform() { g.setTransform(Z, 0, 0, Z, W / 2 - cam.x * Z, H / 2 - cam.y * Z); }
const px = (n) => n / Z;        // Godot の _px（画面px → ワールド）
// ワールド座標 → pixelFX の論理ピクセル座標
const toL = (p) => V((p.x - cam.x) * Z / LP + LW / 2, (p.y - cam.y) * Z / LP + LH / 2);
const WL = Z / LP;              // ワールド長 → 論理ピクセル長
function painter(layer = 'front') { const p = PX.painterFor(FR[layer]); p.place(0, 0); return p; }

// ---------- Godot の描画命令の移植（現行表示の再現に使う）
const D2 = {
  circle(p, r, col) { g.beginPath(); g.arc(p.x, p.y, Math.max(0, r), 0, TAU); g.fillStyle = col; g.fill(); },
  arc(p, r, a0, a1, col, w) { g.beginPath(); g.arc(p.x, p.y, Math.max(0, r), a0, a1, a1 < a0); g.strokeStyle = col; g.lineWidth = w; g.lineCap = 'butt'; g.stroke(); },
  roundArc(p, r, a0, a1, col, w) { g.beginPath(); g.arc(p.x, p.y, Math.max(0, r), a0, a1); g.strokeStyle = col; g.lineWidth = w; g.lineCap = 'round'; g.stroke(); g.lineCap = 'butt'; },
  line(a, b, col, w) { g.beginPath(); g.moveTo(a.x, a.y); g.lineTo(b.x, b.y); g.strokeStyle = col; g.lineWidth = w; g.lineCap = 'butt'; g.stroke(); },
  roundBeam(a, b, col, w) { g.beginPath(); g.moveTo(a.x, a.y); g.lineTo(b.x, b.y); g.strokeStyle = col; g.lineWidth = w; g.lineCap = 'round'; g.stroke(); g.lineCap = 'butt'; },
  poly(pts, col) { g.beginPath(); pts.forEach((q, i) => i ? g.lineTo(q.x, q.y) : g.moveTo(q.x, q.y)); g.closePath(); g.fillStyle = col; g.fill(); },
  polyline(pts, col, w) { g.beginPath(); pts.forEach((q, i) => i ? g.lineTo(q.x, q.y) : g.moveTo(q.x, q.y)); g.strokeStyle = col; g.lineWidth = w; g.lineJoin = 'round'; g.stroke(); },
  // 頂点色付きの多角形（扇形の中心だけ濃いなど）。近似：中心色から外周色への放射グラデーション
  fan(center, pts, c0, c1) { const r = Math.max(...pts.map(q => dist(q, center))); const gr = g.createRadialGradient(center.x, center.y, 0, center.x, center.y, r); gr.addColorStop(0, c0); gr.addColorStop(1, c1); D2.poly([center, ...pts], gr); },
};

// ---------- スプライト
function drawImg(key, pos, angle, halfMax, alpha = 1, flip = false, tint = null) {
  const im = IMG[key]; if (!im) return;
  const s = (2 * halfMax) / Math.max(im.width, im.height);
  g.save(); g.translate(pos.x, pos.y); g.rotate(angle); if (flip) g.scale(-1, 1);
  g.globalAlpha = alpha; g.imageSmoothingEnabled = false;
  g.drawImage(im, -im.width * s / 2, -im.height * s / 2, im.width * s, im.height * s);
  if (tint) { g.globalCompositeOperation = 'lighter'; g.globalAlpha = tint; g.filter = 'brightness(0) invert(1)'; g.drawImage(im, -im.width * s / 2, -im.height * s / 2, im.width * s, im.height * s); g.filter = 'none'; }
  g.restore();
}
// 敵の当たり判定半径と表示半径（enemy_system.gd apply_scaling / run_presentation.gd enemy_sprite_radius）
function enemyDef(type) { return DATA.enemies[type]; }
function enemyR(type, elite = false) { const d = enemyDef(type); const vs = d.visual_settings || {}; return d.radius * (elite ? 1.25 : 1) * CS * (vs.scale ?? 1) * (vs.collision_scale ?? 1); }
function spriteR(type, r) { const d = enemyDef(type); const vs = d.visual_settings || {}; const cr = r / (vs.collision_scale ?? 1); if (!d.look) return cr; return Math.max(d.look.w, d.look.h) * 0.5 * cr / d.radius; }
function enemyColor(type) { const c = enemyDef(type).color; return c ? { r: c.r, g: c.g, b: c.b, a: 1 } : { r: 1, g: 1, b: 1, a: 1 }; }
function drawEnemy(e, opts = {}) {
  const d = enemyDef(e.type);
  if (!d.look) { // 外観のない種類（swarm）は共通の矢じり形
    const u = fromA(e.facing), s = orth(u), r = e.r;
    D2.poly([add(e.pos, mul(u, r)), add(add(e.pos, mul(u, -r * 0.7)), mul(s, r * 0.7)), add(e.pos, mul(u, -r * 0.35)), add(add(e.pos, mul(u, -r * 0.7)), mul(s, -r * 0.7))], rgba(enemyColor(e.type)));
    return;
  }
  const ang = d.look.fixed_angle ? d.look.angle : d.look.angle + e.facing;
  const key = opts.key || 'enemy/' + e.type;
  drawImg(key, e.pos, ang, spriteR(e.type, e.r), opts.alpha ?? 1, false, e.flash > 0 ? 0.6 : (opts.white || 0));
}
// 機体（ship_visual.gd：原画の y=30 が機体位置、character_scale 倍）
function drawShip(s) {
  const im = IMG.ship; if (!im) return;
  g.save(); g.translate(s.pos.x, s.pos.y); g.rotate(s.heading + Math.PI / 2); g.imageSmoothingEnabled = false;
  if (s.speed > 5) { const f = IMG.airship_flame; if (f) { const fr = Math.floor(((typeof S !== 'undefined' && S) ? S.t : 0) * 12) % 3; g.drawImage(f, fr * im.width, 0, im.width, im.height, -im.width / 2 * CS, -30 * CS, im.width * CS, im.height * CS); } } // ship_visual.gd：3コマの噴射を機体と同じ矩形へ
  g.drawImage(im, -im.width / 2 * CS, -30 * CS, im.width * CS, im.height * CS);
  g.restore();
}
