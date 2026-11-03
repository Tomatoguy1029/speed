// ===== 咆哮：本体をぼかさず、周囲の景色だけを外へ流す =====
// 参照：G2 Studios「軽くて綺麗なラディアルブラーを作ろう！」
// https://note.com/g2studios/n/n7b7a0c068a1c
// サンプリング位置のディザで残像の段差を散らす。白い面・集光粒子は描かない。
const CANIS_ROARS = new Set(['command', 'stream', 'howl', 'bay', 'relay', 'hunt', 'hunt_pounce']);
const ROAR_LEVELS = {
  1: { life: 0.24, blur: 0.028, reach: 3.2, mix: 0.55 },
  2: { life: 0.36, blur: 0.075, reach: 5, mix: 0.8 },
  3: { life: 0.52, blur: 0.17, reach: 8, mix: 1 },
};
// 咆哮（中）＝段階2の初期値（本人指定）。小・大は各つまみの既定値のまま
const ROAR_LEVEL_DEFAULTS = { 2: { roarPost: 1.4, roarTime: 2.5, roarSize: 0.8, roarClear: 0.7, roarRange: 2.0, roarBlur: 0.5, roarLines: 1.0, roarShake: 0.8, orderWait: 0.1 } };
const roarLevel = P => { const l = ROAR_LEVELS[P.roarLevel] || ROAR_LEVELS[1]; return { ...l, life: l.life * (P.roarTime ?? 1) }; }; // 長さはつまみの倍率（待ち時間の起点も一緒にずれる）
function activeRoar(S, P) {
  const e = S.shouts.findLast(e => !e.small), age = e ? (S.t - e.t) / P.timing : -1;
  return age >= 0 && age < roarLevel(P).life ? { ...e, age } : null;
}
// 現行の咆哮時刻は保ち、試作はこの咆哮の終了を猟犬の行動時計の起点にする。
function canisOrderCue(S) {
  if (!CANIS_ROARS.has(S.tech) || S.shouted) return;
  const warn = ['hunt', 'hunt_pounce'].includes(S.tech) ? bossRule('canis_major', 'stream', S.B.phase).warn : S.r.warn;
  const cue = S.orderTiming?.cue ?? warn - Math.min(warn * 0.65, S.tech === 'howl' ? 0.55 : 0.32);
  if (S.age >= cue) { canisShout(S); S.shouted = true; }
}

const CANIS_ROAR_VISUAL_PARAMS = [
  { k: 'roarTime', label: '咆哮：長さ（倍率）', type: 'range', min: 0.3, max: 4, step: 0.05, def: 1 },
  { k: 'roarSize', label: '咆哮：全体の大きさ', type: 'range', min: 0.5, max: 1.8, step: 0.01, def: 1 },
  { k: 'roarColor', label: '咆哮：色', type: 'color', def: '#b6e5ff' },
  { k: 'roarClear', label: '咆哮：中心を残す広さ', type: 'range', min: 0.2, max: 1.2, step: 0.01, def: 0.5 },
  { k: 'roarRange', label: '咆哮：外側の範囲', type: 'range', min: 1.2, max: 3.6, step: 0.01, def: 2.35 },
  { k: 'roarBlur', label: '咆哮：景色のにじみ', type: 'range', min: 0, max: 2, step: 0.01, def: 1 },
  { k: 'roarLines', label: '咆哮：圧力の筋の強さ', type: 'range', min: 0, max: 2, step: 0.01, def: 1 },
  { k: 'roarShake', label: '咆哮：画面の揺れ（段階2・3）', type: 'range', min: 0, max: 2, step: 0.01, def: 1 },
];
// 咆哮の後処理（キャンバス2D）：今のコマを写し取り、①顔の外側だけ中心から外へ拡大して重ねるズームブラー、
// ②顔のすぐ周りから外へ広がる帯の中だけ景色を外へずらす屈折（放射状の筋で崩し、輪郭線は描かない）、③画面の揺れ、を重ねる。
// 顔の中心は残す。景色ごと流れるので、本体の後ろ側・猟犬・機体・星がまとめて押し出されて見える
const ROAR_SHAKE = { 1: 0, 2: 0.5, 3: 1 };
let roarCanvases = null, roarStreaks = null, roarLumps = null;
function roarBuffers() {
  if (roarCanvases && roarCanvases.snap.width === W) return roarCanvases;
  const mk = () => { const c = document.createElement('canvas'); c.width = W; c.height = H; return c; };
  return (roarCanvases = { snap: mk(), blur: mk(), band: mk() });
}
function roarStreakTex() { // 放射状の筋（角度ごとに濃さと長さが違う）。咆哮ごとに回して使う
  if (roarStreaks) return roarStreaks; const c = document.createElement('canvas'); c.width = c.height = 512; const x = c.getContext('2d'), Rg = new PX.Rng(9);
  x.translate(256, 256); for (let i = 0; i < 420; i++) { const a = Rg.range(0, TAU), r0 = Rg.range(40, 150), r1 = r0 + Rg.range(60, 220), al = Rg.range(0.25, 1); x.strokeStyle = `rgba(255,255,255,${al})`; x.lineWidth = Rg.range(1, 4); x.beginPath(); x.moveTo(Math.cos(a) * r0, Math.sin(a) * r0); x.lineTo(Math.cos(a) * r1, Math.sin(a) * r1); x.stroke(); }
  return (roarStreaks = c);
}
function roarLumpTex() { // 大きなむら（角度ごとに帯を途切れさせる）
  if (roarLumps) return roarLumps; const c = document.createElement('canvas'); c.width = c.height = 256; const x = c.getContext('2d'), Rg = new PX.Rng(21);
  for (let i = 0; i < 26; i++) { const px = Rg.range(0, 256), py = Rg.range(0, 256), r = Rg.range(25, 70), gr = x.createRadialGradient(px, py, 0, px, py, r); gr.addColorStop(0, `rgba(255,255,255,${Rg.range(0.6, 1)})`); gr.addColorStop(1, 'rgba(255,255,255,0)'); x.fillStyle = gr; x.fillRect(0, 0, 256, 256); }
  return (roarLumps = c);
}
function radialMask(ctx, c, stops) { const gr = ctx.createRadialGradient(c.x, c.y, 0, c.x, c.y, stops[stops.length - 1][0]); for (const [r, a] of stops) gr.addColorStop(Math.min(1, r / stops[stops.length - 1][0]), `rgba(0,0,0,${a})`); ctx.globalCompositeOperation = 'destination-in'; ctx.fillStyle = gr; ctx.fillRect(0, 0, W, H); ctx.globalCompositeOperation = 'source-over'; }
function postCanisRoar(S, R) {
  const P = R.P;
  if ((!CANIS_ROARS.has(S.tech) && S.tech !== 'nova') || P.roarPost <= 0 || P.intensity <= 0) return;
  const e = activeRoar(S, P); if (!e) return;
  const lv = P.roarLevel || 1, level = roarLevel(P), u = e.age / level.life, env = smooth(0, 0.08, u) * (1 - smooth(0.35, 1, u));
  if (env <= 0.001) return;
  const B = roarBuffers(), c = mul(toL(S.B.visualMouth || e.at), LP), unit = S.B.r * Z * cam.zoom * P.size * (P.roarSize ?? 1);
  const rc = unit * (P.roarClear ?? 0.5), ro = Math.max(rc * 1.8, unit * (P.roarRange ?? 2.35) * (0.7 + 0.3 * lv / 3)), str = Math.min(1, level.mix * P.roarPost * P.intensity);
  B.snap.getContext('2d').drawImage(cv, 0, 0);
  g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.imageSmoothingEnabled = true;
  const shake = (ROAR_SHAKE[lv] ?? 0) * (P.roarShake ?? 1) * env * unit * 0.06; // ③揺れ
  if (shake > 0.3) g.drawImage(B.snap, Math.sin(e.age * 91 + e.seed) * shake, Math.cos(e.age * 73 + e.seed) * shake);
  // ①ズームブラー：顔の外側だけ、中心から外へ拡大した写しを重ねる
  const bx = B.blur.getContext('2d'), zoom = level.blur * (P.roarBlur ?? 1) * env * 2.2;
  if (zoom > 0.002) { bx.setTransform(1, 0, 0, 1, 0, 0); bx.clearRect(0, 0, W, H); bx.globalAlpha = 1; bx.drawImage(B.snap, 0, 0);
    for (let i = 1; i <= 6; i++) { const k = 1 + zoom * i / 6; bx.globalAlpha = 0.55 / i + 0.1; bx.setTransform(k, 0, 0, k, c.x * (1 - k), c.y * (1 - k)); bx.drawImage(B.snap, 0, 0); }
    bx.setTransform(1, 0, 0, 1, 0, 0); bx.globalAlpha = 1; radialMask(bx, c, [[0, 0], [rc, 0], [rc * 1.6, 1], [ro * 0.8, 1], [ro * 1.25, 0]]);
    g.globalAlpha = Math.min(1, str * env * 1.2); g.drawImage(B.blur, 0, 0); g.globalAlpha = 1; }
  // ②屈折の帯：顔のすぐ周りから外へ広がる。帯の中だけ景色を外へずらし、放射状の筋で崩す
  const rb = rc + (ro - rc) * (1 - Math.pow(1 - clamp(u * 1.4), 2)), bw = unit * 0.45, nx = B.band.getContext('2d'), disp = 0.035 * (0.6 + 0.4 * lv / 3) * (P.roarLines ?? 1);
  if (disp > 0 && rb > 1) { nx.setTransform(1, 0, 0, 1, 0, 0); nx.clearRect(0, 0, W, H); const k = 1 + disp; nx.setTransform(k, 0, 0, k, c.x * (1 - k), c.y * (1 - k)); nx.drawImage(B.snap, 0, 0); nx.setTransform(1, 0, 0, 1, 0, 0);
    const tint = P.roarColor || '#b6e5ff'; nx.globalCompositeOperation = 'lighter'; nx.globalAlpha = 0.1 * (0.5 + 0.5 * lv / 3); nx.fillStyle = tint; nx.fillRect(0, 0, W, H); nx.globalAlpha = 1; nx.globalCompositeOperation = 'source-over';
    radialMask(nx, c, [[0, 0], [Math.max(0, rb - bw), 0], [rb - bw * 0.3, 1], [rb, 1], [rb + bw * 0.35, 0], [rb + bw, 0]]);
    nx.globalCompositeOperation = 'destination-in'; nx.save(); nx.translate(c.x, c.y); nx.rotate(e.seed * 1.7); const st = roarStreakTex(), sz = (rb + bw) * 2.4; nx.drawImage(st, -sz / 2, -sz / 2, sz, sz); nx.rotate(e.seed * 2.3 + e.age * 0.8); nx.drawImage(roarLumpTex(), -sz / 2, -sz / 2, sz, sz); nx.restore(); // 筋で崩し、大きなむらで途切れさせる（輪にしない） nx.globalCompositeOperation = 'source-over';
    g.globalAlpha = Math.min(1, str * env * 1.4); g.drawImage(B.band, 0, 0); g.globalAlpha = 1; }
  g.restore();
}
