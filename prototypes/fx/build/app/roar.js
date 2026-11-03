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
const roarLevel = P => ROAR_LEVELS[P.roarLevel] || ROAR_LEVELS[1];
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
  { k: 'roarSize', label: '咆哮：全体の大きさ', type: 'range', min: 0.5, max: 1.8, step: 0.01, def: 1 },
  { k: 'roarColor', label: '咆哮：色', type: 'color', def: '#b6e5ff' },
  { k: 'roarClear', label: '咆哮：中心を残す広さ', type: 'range', min: 0.2, max: 1.2, step: 0.01, def: 0.5 },
  { k: 'roarRange', label: '咆哮：外側の範囲', type: 'range', min: 1.2, max: 3.6, step: 0.01, def: 2.35 },
  { k: 'roarBlur', label: '咆哮：景色のにじみ', type: 'range', min: 0, max: 2, step: 0.01, def: 1 },
  { k: 'roarLines', label: '咆哮：圧力の筋の強さ', type: 'range', min: 0, max: 2, step: 0.01, def: 1 },
];
let roarScreen = null;
function makeRoarScreen() {
  // ブラーだけを縦横1/2で処理し、元の高解像度の絵へ重ねる。中心は透明のまま。
  const canvas = document.createElement('canvas'); canvas.width = W / 2; canvas.height = H / 2;
  const source = document.createElement('canvas'); source.width = W / 2; source.height = H / 2;
  const out = { canvas, source, sourceG: source.getContext('2d', { willReadFrequently: true }), gl: null };
  const gl = canvas.getContext('webgl', { alpha: true, premultipliedAlpha: true, antialias: false, depth: false });
  if (!gl) return out;
  const vertex = `attribute vec2 position; varying vec2 uv;
    void main(){ uv=position*.5+.5; gl_Position=vec4(position,0.,1.); }`;
  const fragment = `precision highp float;
    uniform sampler2D scene; uniform vec2 center; uniform vec2 resolution;
    uniform vec2 radii; uniform float intensity; uniform float opacity; uniform vec3 tint;
    varying vec2 uv;
    void main(){
      vec2 delta=uv-center;
      float distance=length(delta*resolution);
      float outside=smoothstep(radii.x,radii.x*1.55,distance);
      float mask=outside*(1.-smoothstep(radii.y*.72,radii.y,distance))*opacity;
      if(mask<.001){ gl_FragColor=vec4(0.); return; }
      // ディザは像を抜くためではなく、各画素のサンプリング位置をずらすために使う。
      float jitter=fract(52.9829189*fract(dot(gl_FragCoord.xy,vec2(.06711056,.00583715))));
      vec3 color=vec3(0.);
      for(int i=0;i<3;i++){
        float phase=(float(i)+jitter)/3.;
        vec2 sampleUV=center+delta*(1.-intensity*outside*phase);
        color+=texture2D(scene,clamp(vec2(sampleUV.x,1.-sampleUV.y),vec2(.001),vec2(.999))).rgb;
      }
      gl_FragColor=vec4(color*(vec3(.3)+tint*.7)*(mask/3.),mask);
    }`;
  const shaders = [];
  try {
    const compile = (type, text) => {
      const shader = gl.createShader(type); shaders.push(shader); gl.shaderSource(shader, text); gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader));
      return shader;
    };
    const program = gl.createProgram();
    gl.attachShader(program, compile(gl.VERTEX_SHADER, vertex)); gl.attachShader(program, compile(gl.FRAGMENT_SHADER, fragment)); gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program));
    gl.useProgram(program);
    const buffer = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 1,-1, -1,1, -1,1, 1,-1, 1,1]), gl.STATIC_DRAW);
    const position = gl.getAttribLocation(program, 'position'); gl.enableVertexAttribArray(position); gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
    const texture = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, W / 2, H / 2, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    const locations = {}; for (const key of ['resolution','center','radii','intensity','opacity','tint']) locations[key] = gl.getUniformLocation(program, key);
    gl.uniform2f(locations.resolution, W, H); gl.uniform1i(gl.getUniformLocation(program, 'scene'), 0);
    Object.assign(out, { gl, locations });
    canvas.addEventListener('webglcontextlost', event => { event.preventDefault(); out.gl = null; });
  } catch (error) { out.unavailableReason = error.message; }
  finally { for (const shader of shaders) gl.deleteShader(shader); }
  return out;
}
// GPUが使えない場合も同じ中心除外とサンプリング位置のディザを使う。処理面は縦横1/4。
function fallbackRoar(processor, center, radii, intensity, opacity, tint) {
  if (!processor.fallback) {
    const source = document.createElement('canvas'); source.width = W / 4; source.height = H / 4;
    const canvas = document.createElement('canvas'); canvas.width = W / 4; canvas.height = H / 4;
    const ctx = canvas.getContext('2d');
    processor.fallback = { source, sourceG: source.getContext('2d', { willReadFrequently: true }), canvas, ctx, pixels: ctx.createImageData(canvas.width, canvas.height) };
  }
  const f = processor.fallback, w = f.canvas.width, h = f.canvas.height;
  f.sourceG.drawImage(cv, 0, 0, w, h);
  const src = f.sourceG.getImageData(0, 0, w, h).data, dst = f.pixels.data;
  const cx = center.x / 4, cy = center.y / 4, fract = x => x - Math.floor(x);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const index = (y * w + x) * 4, dx = x + 0.5 - cx, dy = y + 0.5 - cy, distance = Math.hypot(dx, dy) * 4;
    const outside = smooth(radii.x, radii.x * 1.55, distance), alpha = outside * (1 - smooth(radii.y * 0.72, radii.y, distance)) * opacity;
    dst[index + 3] = Math.round(alpha * 255); if (alpha < 0.001) continue;
    const jitter = fract(52.9829189 * fract((x + 0.5) * 0.06711056 + (h - y - 0.5) * 0.00583715));
    let red = 0, green = 0, blue = 0;
    for (let i = 0; i < 3; i++) {
      const scale = 1 - intensity * outside * (i + jitter) / 3;
      const sx = clamp(Math.floor(cx + dx * scale), 0, w - 1), sy = clamp(Math.floor(cy + dy * scale), 0, h - 1), at = (sy * w + sx) * 4;
      red += src[at]; green += src[at + 1]; blue += src[at + 2];
    }
    dst[index] = red / 3 * (0.3 + tint.r * 0.7); dst[index + 1] = green / 3 * (0.3 + tint.g * 0.7); dst[index + 2] = blue / 3 * (0.3 + tint.b * 0.7);
  }
  f.ctx.putImageData(f.pixels, 0, 0); g.drawImage(f.canvas, 0, 0, W, H);
}
// 空気が押し出されたときの薄い濃淡。色が変わったときだけ作り直す。
let pressureTexture = null;
function roarPressure(S, center, radii, unit, age, envelope, color, strength) {
  if (strength <= 0) return;
  const key = rgba(color);
  if (pressureTexture?.key !== key) {
    const stamp = document.createElement('canvas'); stamp.width = stamp.height = 160;
    const ctx = stamp.getContext('2d'), frame = ctx.createImageData(160, 160);
    for (let y = 0; y < 160; y++) for (let x = 0; x < 160; x++) {
      const dx = (x - 80) / 80, dy = (y - 80) / 80, d = Math.hypot(dx, dy), a = Math.atan2(dy, dx);
      const ridges = 0.5 + 0.5 * Math.sin(18 * a + 2.3 * Math.sin(4 * a) + 5 * d);
      const arc = 0.5 + 0.5 * Math.cos(3 * a - 1.5 * Math.sin(2 * a));
      const edge = 0.73 + 0.10 * Math.sin(5 * a) + ridges * 0.10;
      const band = Math.exp(-((d - edge) ** 2) / (0.006 + ridges * 0.018));
      const offset = (160 * y + x) * 4;
      frame.data[offset] = color.r * 255; frame.data[offset+1] = color.g * 255; frame.data[offset+2] = color.b * 255;
      frame.data[offset+3] = 180 * band * (0.12 + 0.88 * arc) * (0.2 + 0.8 * ridges) * (1 - smooth(0.86, 1, d));
    }
    ctx.putImageData(frame, 0, 0); pressureTexture = { key, stamp };
  }
  const radius = lerp(radii.x * 1.7, radii.y, 1 - (1 - age) ** 2);
  g.save(); g.translate(center.x, center.y); g.rotate(S.B.facing);
  g.beginPath(); g.arc(0, 0, radii.y, 0, TAU); g.moveTo(radii.x, 0); g.arc(0, 0, radii.x, 0, TAU); g.clip('evenodd');
  g.globalCompositeOperation = 'lighter'; g.globalAlpha = Math.min(0.72, strength * envelope * 0.58);
  g.drawImage(pressureTexture.stamp, -radius, -radius, 2 * radius, 2 * radius); g.restore();
}
function postCanisRoar(S, R) {
  const P = R.P;
  if (!CANIS_ROARS.has(S.tech) || P.roarPost <= 0 || P.intensity <= 0) return;
  const e = activeRoar(S, P); if (!e) return;
  const level = roarLevel(P), u = e.age / level.life;
  const envelope = smooth(0, 0.14, u) * (1 - smooth(0.28, 1, u));
  if (envelope <= 0.001) return;
  const center = mul(toL(S.B.visualMouth || e.at), LP), tint = parseCol(P.roarColor || '#b6e5ff');
  // 顔の近くに限定し、鼻先の芯と機体の絵はそのまま残す。
  const unit = S.B.r * Z * cam.zoom * P.size * (P.roarSize ?? 1), clearRadius = unit * (P.roarClear ?? 0.5);
  const radii = V(clearRadius, Math.max(clearRadius * 1.8, unit * (P.roarRange ?? 2.35)));
  const intensity = Math.min(0.35, level.blur * P.roarPost * P.intensity * (P.roarBlur ?? 1)) * envelope;
  const opacity = Math.min(1, level.mix * P.roarPost * P.intensity) * envelope;
  const processor = roarScreen ||= makeRoarScreen(), gl = processor.gl;
  g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.imageSmoothingEnabled = true;
  const ship = mul(toL(S.ship.pos), LP), shipClear = Math.max(DATA.config.ship_radius * 3, 48) * Z * cam.zoom + 8;
  g.beginPath(); g.rect(0, 0, W, H); g.moveTo(ship.x + shipClear, ship.y); g.arc(ship.x, ship.y, shipClear, 0, TAU); g.clip('evenodd');
  if (gl && intensity > 0) {
    processor.sourceG.drawImage(cv, 0, 0, W / 2, H / 2);
    const pixels = processor.sourceG.getImageData(0, 0, W / 2, H / 2);
    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, W / 2, H / 2, gl.RGBA, gl.UNSIGNED_BYTE, pixels.data);
    gl.uniform2f(processor.locations.center, center.x / W, 1 - center.y / H);
    gl.uniform2f(processor.locations.radii, radii.x, radii.y);
    gl.uniform3f(processor.locations.tint, tint.r, tint.g, tint.b);
    gl.uniform1f(processor.locations.intensity, intensity); gl.uniform1f(processor.locations.opacity, opacity);
    gl.drawArrays(gl.TRIANGLES, 0, 6); g.drawImage(processor.canvas, 0, 0, W, H);
  } else if (intensity > 0) fallbackRoar(processor, center, radii, intensity, opacity, tint);
  roarPressure(S, center, radii, unit, u, envelope, tint, (P.roarLines ?? 1) * P.roarPost * P.intensity);
  g.restore();
}
