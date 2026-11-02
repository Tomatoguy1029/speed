// ===== 試作エフェクト部品（pixelFX の Painter で論理ピクセルへ描く） =====
// 参照：shaders/marlin_warning.gdshader（芯＋平行な薄い光＋光の包みの流れ）、
//       pixelFX src/fx/arcane/arcane-beam.js（帯の段階・発射元フレア・終端の火花、Hugo Duprez 由来 MIT）、
//       pixelFX src/fx/melee/sword-slash.js（白から冷える三日月と残光）、src/core/painter.js（glow/ring/disc/beam）。
// ノイズは関数で作らず、決定的な hash（事前の値表と同じ扱い）だけを使う。ブルームは光バッファの加算に任せる。
// SPEED 向けの変更：pixelFX の put は半透明を Bayer ディザで抜くため、細い線が点線に見える。
// 予兆を点線にしないため、半透明（0.12以上）は暗い背景へ重ねたときの色（色×濃さ）で途切れずに塗る。ごく薄い所だけディザを残す。
(() => {
  const P0 = PX.Painter.prototype, put0 = P0.put;
  P0.put = function (sx, sy, c, a = 1) {
    if (!c) return; const af = a * this.fade;
    if (af >= 0.999 || af < 0.12) return put0.call(this, sx, sy, c, a);
    const k = 0.2 + 0.8 * af, r = (c & 255) * k | 0, gg = ((c >>> 8) & 255) * k | 0, b = ((c >>> 16) & 255) * k | 0;
    const f = this.fade; this.fade = 1; put0.call(this, sx, sy, ((255 << 24) | (b << 16) | (gg << 8) | r) >>> 0, 1); this.fade = f;
  };
})();
const FX = (() => {
  const C = (s) => hexc(s);
  const ramp = (hex, k = 1) => { // 主色から暗→明の5段（pixelFX の PAL と同じ並び）
    const c = parseCol(hex);
    const mk = (f, w) => toHex({ r: lerp(c.r * f, 1, w), g: lerp(c.g * f, 1, w), b: lerp(c.b * f, 1, w) });
    return [mk(0.35, 0), mk(0.6, 0), mk(1, 0), mk(1, 0.45), '#ffffff'].map(C);
  };
  // 11個の光の包み（marlin_warning.gdshader の packets と同じ作り：位置・幅・明るさ・速さが別々）
  function packets(seed, time) {
    const out = [];
    for (let i = 0; i < 11; i++) {
      const key = seed * 3.17 + i * 19.13, ph = hash(key + 1), sp = hash(key + 2) < 0.5 ? 1 : 2;
      const center = ((ph + sp * time) % 1 + 1) % 1, width = lerp(0.035, 0.102, hash(key + 5)), str = lerp(0.22, 0.67, hash(key + 7));
      out.push([center, width, str]);
    }
    return out;
  }
  function flow(pk, along) { let s = 0; for (const [c, w, k] of pk) { let d = along - c + 0.5; d = d - Math.floor(d) - 0.5; s += Math.exp(-((d / w) ** 2)) * k; } return 1 - Math.exp(-s * 0.9); }
  // 予兆の光線：途切れない芯と左右の細い光。点線にせず、明るさの包みだけが流れる。k は溜まり具合（0〜1）
  function warnRail(p, A, B, o) {
    const pal = ramp(o.color), dx = B.x - A.x, dy = B.y - A.y, L = Math.hypot(dx, dy); if (L < 1) return;
    const ux = dx / L, uy = dy / L, nx = -uy, ny = ux, k = clamp(o.k), pk = packets(o.seed || 0, (o.time || 0) / 4);
    const side = (o.rail ?? 2.2) * (0.6 + 0.4 * k), inten = (o.intensity ?? 1);
    // 芯は1論理ピクセルの実線（ディザで抜かない）。明るさは段階色と、加算の光（左右の平行光・包み）で表す
    for (let d = 0; d <= L; d += 1) {
      const env = smooth(0, 6, d) * smooth(0, 14, L - d) * (o.reveal == null ? 1 : smooth(o.reveal * L, o.reveal * L - 8, d));
      if (env <= 0.04) continue;
      const f = flow(pk, (d + (o.offset || 0)) / (o.path || L));
      const x = A.x + ux * d, y = A.y + uy * d;
      const b = env * (0.35 + 0.65 * k) * (0.7 + 0.6 * f) * inten;
      p.px(x, y, b > 0.95 ? pal[4] : b > 0.62 ? pal[3] : b > 0.3 ? pal[2] : pal[1]);
      p.light(x, y, pal[2], 0.16 * env * (0.4 + k) * (0.6 + f) * inten);
      p.light(x + nx * side, y + ny * side, pal[2], 0.22 * env * (0.3 + 0.7 * k) * (0.6 + 0.6 * f) * inten);
      p.light(x - nx * side, y - ny * side, pal[1], 0.18 * env * (0.3 + 0.7 * k) * (0.6 + 0.6 * f) * inten);
    }
    p.glowLine(A.x, A.y, B.x, B.y, 2.5 + 2 * k, pal[2], 0.10 * k * inten);
  }
  // 照射中のビーム：芯（白）→明→主→暗の帯、芯を流れる包み、ゆらぐ幅、発射元のフレア
  function beam(p, A, B, o) {
    const pal = ramp(o.color), dx = B.x - A.x, dy = B.y - A.y, L = Math.hypot(dx, dy); if (L < 1) return;
    const ux = dx / L, uy = dy / L, nx = -uy, ny = ux, t = o.time || 0, a = clamp(o.alpha ?? 1), w0 = o.w;
    const LV = [pal[4], pal[3], pal[2], pal[1], pal[0]];
    for (let d = 0; d <= L; d += 0.5) {
      const ends = o.round ? Math.min(1, Math.sqrt(Math.max(0, Math.min(d, L - d)) / (w0 * 0.9 + 0.01))) : Math.min(1, (d + 2) / 4);
      const w = w0 * (1 + 0.1 * Math.sin(d * 0.35 - t * 40)) * ends;
      const pulse = ((d * 0.03 - t * 3) % 1 + 1) % 1 < 0.06 ? 1 : 0;
      const x = A.x + ux * d, y = A.y + uy * d;
      for (let q0 = -w * 1.25; q0 <= w * 1.25; q0 += 0.5) {
        const q = Math.abs(q0) / Math.max(w, 0.01);
        let lv = q < 0.25 ? 0 : q < 0.45 ? 1 : q < 0.7 ? 2 : q < 0.95 ? 3 : 4;
        lv = Math.max(0, lv - pulse);
        const al = a * (lv === 4 ? 0.45 : 1);
        p.dot(x + nx * q0, y + ny * q0, LV[lv], al);
      }
      if ((Math.round(d * 2) & 5) === 0) p.light(x, y, pal[2], 0.25 * a * (o.intensity ?? 1));
    }
    p.glowLine(A.x, A.y, B.x, B.y, w0 * 2.6 + 3, pal[2], 0.35 * a * (o.intensity ?? 1));
    if (o.source !== false) flare(p, A, w0 * 1.3, o.color, t, a);
  }
  // 発射元・着弾点のフレア（arcane-beam の source：回る光条と白い芯）
  function flare(p, P0, r, color, t, a = 1, rays = 4) {
    const pal = ramp(color), fr = r * (1 + 0.12 * Math.sin(t * 60));
    for (let i = 0; i < rays; i++) { const an = t * 15 + i * TAU / rays, l = r * 1.8 + r * 0.6 * Math.sin(t * 36 + i); p.line(P0.x, P0.y, P0.x + Math.cos(an) * l, P0.y + Math.sin(an) * l, (u) => (u < 0.5 ? pal[4] : pal[3]), (u) => (u < 0.6 ? a : a * (1.6 - u))); }
    p.circle(P0.x, P0.y, fr + 1.2, pal[2], a); p.circle(P0.x, P0.y, fr * 0.75, pal[3], a); p.circle(P0.x, P0.y, fr * 0.45, pal[4], a);
    p.glow(P0.x, P0.y, r * 5 + 4, pal[2], 0.6 * a); p.glow(P0.x, P0.y, r * 2 + 2, pal[4], 0.4 * a);
  }
  // 吸い込む光の粒（溜め）。粒ごとに角度・速さ・寿命を変える（pixelFX cycle と同じ考え方を決定的に）
  function gather(p, P0, R, k, color, t, n = 14, seed = 1) {
    const pal = ramp(color);
    for (let i = 0; i < n; i++) {
      const life = lerp(0.35, 0.7, hash(seed + i)), ph = ((t / life + hash(seed * 7 + i)) % 1), an = hash(seed * 3 + i) * TAU + t * 0.7;
      const rr = R * (1 - ph) * lerp(0.7, 1.15, hash(i + seed * 11)) + 1;
      const x = P0.x + Math.cos(an) * rr, y = P0.y + Math.sin(an) * rr;
      const tail = Math.min(4, 1 + R * 0.08);
      p.line(x, y, x + Math.cos(an) * tail, y + Math.sin(an) * tail, ph > 0.7 ? pal[4] : pal[3], k * (0.4 + 0.6 * ph));
      p.light(x, y, pal[2], 0.25 * k * ph);
    }
    p.glow(P0.x, P0.y, R * 0.35 * (0.4 + k) + 2, pal[2], 0.55 * k); p.circle(P0.x, P0.y, 1 + 2.2 * k, pal[3], k); p.circle(P0.x, P0.y, 0.6 + 1.2 * k, pal[4], k);
  }
  // 三日月の斬撃（白→色へ冷え、残光が尾から薄れる）。a0→a1 へ振り抜き、head（0〜1）が刃先、tail（0〜1）が残光の後端
  function crescent(p, Cn, R, a0, a1, head, tail, thick, color, alpha = 1) {
    const pal = ramp(color), span = a1 - a0, steps = Math.max(8, Math.abs(span) * R * 1.4);
    for (let s = 0; s <= steps; s++) {
      const u = s / steps; if (u > head || u < tail) continue;
      const an = a0 + span * u, age = (head - u) / Math.max(0.001, head - tail + 0.001);
      const w = thick * (0.35 + 0.65 * Math.sin(Math.PI * Math.min(1, u * 1.05))) * (1 - 0.6 * age);
      for (let q = -w; q <= w; q += 0.5) {
        const rr = R + q, x = Cn.x + Math.cos(an) * rr, y = Cn.y + Math.sin(an) * rr, edge = Math.abs(q) / Math.max(w, 0.01);
        let lv = age < 0.12 ? 4 : age < 0.35 ? (edge < 0.5 ? 4 : 3) : age < 0.7 ? (edge < 0.4 ? 3 : 2) : (edge < 0.4 ? 2 : 1);
        // 薄さは段階色を暗くして表す（ディザの点々にしない）。ごく薄いときだけ縁から抜く
        const a2 = alpha * (1 - age * 0.55); lv = Math.max(0, lv - Math.floor((1 - a2) * 3.2));
        if (a2 > 0.18 || edge < 0.5) p.px(x, y, pal[lv]); else p.dot(x, y, pal[lv], a2 * 3);
      }
      if (s % 3 === 0) p.light(Cn.x + Math.cos(an) * R, Cn.y + Math.sin(an) * R, pal[2], 0.3 * alpha * (1 - age));
    }
  }
  function sparks(p, P0, t, seed, n, color, speed = 40, life = 0.35, dir = null, spread = Math.PI) {
    const pal = ramp(color);
    for (let i = 0; i < n; i++) {
      const lf = life * lerp(0.6, 1.2, hash(seed + i * 1.7)); if (t > lf || t < 0) continue;
      const an = (dir == null ? hash(seed * 5 + i) * TAU : dir + (hash(seed * 5 + i) - 0.5) * 2 * spread), sp = speed * lerp(0.5, 1.3, hash(seed * 9 + i));
      const q = t / lf, d = sp * t * (1 - q * 0.4), x = P0.x + Math.cos(an) * d, y = P0.y + Math.sin(an) * d + 20 * t * t;
      const tl = Math.min(4, 1 + sp * 0.03 * (1 - q));
      p.line(x - Math.cos(an) * tl, y - Math.sin(an) * tl, x, y, (u) => (u > 0.5 ? (q < 0.4 ? pal[4] : pal[3]) : pal[2]), 1 - q * 0.6);
      p.light(x, y, pal[2], 0.3 * (1 - q));
    }
  }
  function shock(p, P0, R, w, color, a = 1) { const pal = ramp(color); p.ring(P0.x, P0.y, R, Math.max(1, w), pal[3], a); p.ring(P0.x, P0.y, Math.max(0, R - w * 0.6), Math.max(1, w * 0.4), pal[4], a * 0.8); p.glowRing(P0.x, P0.y, R, w * 2 + 3, pal[2], 0.45 * a); }
  // 稲妻（決定的なジグザグ。0.06秒ごとに形を変える＝pixel_lightning.gd の SHAPE_INTERVAL の考え方）
  function bolt(p, A, B, seed, color, a = 1, width = 1) {
    const pal = ramp(color), n = Math.max(4, Math.round(dist(A, B) / 5)); let prev = A;
    const dx = B.x - A.x, dy = B.y - A.y, L = Math.hypot(dx, dy), nx = -dy / L, ny = dx / L;
    for (let i = 1; i <= n; i++) {
      const u = i / n, off = i === n ? 0 : (hash(seed + i * 13.1) - 0.5) * Math.min(10, L * 0.18) * Math.sin(Math.PI * u);
      const q = V(A.x + dx * u + nx * off, A.y + dy * u + ny * off);
      p.line(prev.x, prev.y, q.x, q.y, pal[4], a); if (width > 1) p.line(prev.x + 1, prev.y, q.x + 1, q.y, pal[3], a * 0.8);
      p.glowLine(prev.x, prev.y, q.x, q.y, 4, pal[2], 0.25 * a); prev = q;
    }
  }
  // 炎の舌（ドット単位。下から上へ揺らぐ。色は段階で、ブルームは光バッファ）
  function flameStrip(p, A, B, w, t, color, a = 1, seed = 1, hot = '#ffffff') {
    const pal = ramp(color), dx = B.x - A.x, dy = B.y - A.y, L = Math.hypot(dx, dy); if (L < 0.5) return;
    const ux = dx / L, uy = dy / L, nx = -uy, ny = ux;
    for (let d = 0; d <= L; d += 1) {
      const n1 = hash(Math.floor(d / 3) * 7.3 + seed + Math.floor(t * 14) * 3.1);
      const hgt = w * (0.8 + 0.9 * n1) * a;
      for (let q = -hgt; q <= hgt; q += 0.5) {
        const e = Math.abs(q) / Math.max(hgt, 0.01), lv = e < 0.25 ? 4 : e < 0.5 ? 3 : e < 0.8 ? 2 : 1;
        p.dot(A.x + ux * d + nx * q, A.y + uy * d + ny * q, pal[lv], a * (e > 0.8 ? 0.5 : 1));
      }
      if (d % 2 === 0) p.light(A.x + ux * d, A.y + uy * d, pal[2], 0.22 * a);
    }
  }
  return { ramp, warnRail, beam, flare, gather, crescent, sparks, shock, bolt, flameStrip, packets, flow };
})();
// ワールド座標で呼ぶ版
const FXW = {
  warnRail: (p, a, b, o) => FX.warnRail(p, toL(a), toL(b), o),
  beam: (p, a, b, o) => FX.beam(p, toL(a), toL(b), { ...o, w: o.w * WL }),
  flare: (p, a, r, c, t, al, rays) => FX.flare(p, toL(a), r * WL, c, t, al, rays),
  gather: (p, a, R, k, c, t, n, s) => FX.gather(p, toL(a), R * WL, k, c, t, n, s),
  crescent: (p, cn, R, a0, a1, h, tl, th, c, al) => FX.crescent(p, toL(cn), R * WL, a0, a1, h, tl, th * WL, c, al),
  sparks: (p, a, t, s, n, c, sp, life, dir, spread) => FX.sparks(p, toL(a), t, s, n, c, (sp ?? 40), life, dir, spread),
  shock: (p, a, R, w, c, al) => FX.shock(p, toL(a), R * WL, w * WL, c, al),
  bolt: (p, a, b, s, c, al, w) => FX.bolt(p, toL(a), toL(b), s, c, al, w),
  flameStrip: (p, a, b, w, t, c, al, s) => FX.flameStrip(p, toL(a), toL(b), w * WL, t, c, al, s),
};
