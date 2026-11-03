// ===== 咆哮：口元の白い乱流と、描画済みの景色にかける圧力・放射ブラー =====
// pixelFX ground-slam.js の圧力の立ち上がりと、薄い雲がほぐれる手法を参考にした。
// 丸い線は描かず、密度にむらのある空気の面を描く。判定・役者の座標には触れない。
const CANIS_ROARS = new Set(['command', 'stream', 'howl', 'bay', 'relay', 'hunt', 'hunt_pounce']);
const ROAR_LEVELS = {
  1: { reach: 0.42, air: 0.5, life: 0.4, post: 0 },
  2: { reach: 0.72, air: 0.8, life: 0.62, post: 0.38 },
  3: { reach: 1, air: 1, life: 0.85, post: 1 },
};
const roarLevel = P => ROAR_LEVELS[P.roarLevel] || ROAR_LEVELS[1];
function roarEvents(S, P) {
  return S.shouts.map(e => ({ ...e, age: (S.t - e.t) / P.timing }))
    .filter(e => e.age >= 0 && e.age < (e.small ? 0.38 : roarLevel(P).life)).slice(-8);
}
function drawRoar(R, e) {
  const P = R.P, level = e.small ? ROAR_LEVELS[1] : roarLevel(P), gain = P.roarFX * P.intensity * level.air;
  if (gain <= 0) return;
  const a = toL(e.at), age = e.age, small = e.small, span = small ? 0.38 : level.life;
  const rise = smooth(0, 0.045, age), fade = rise * (1 - smooth(span * 0.32, span, age));
  const reach = (small ? 38 : 118) * P.size * level.reach, radius = (9 + reach * Math.sqrt(age / span)) * (small ? 0.55 : 1);
  const white = hexc('#edf5ff'), pale = FX.ramp(P.color)[3], phase = Math.floor(age * 30) / 30;
  const x0 = Math.max(0, Math.floor(a.x - radius)), x1 = Math.min(LW, Math.ceil(a.x + radius));
  const y0 = Math.max(0, Math.floor(a.y - radius)), y1 = Math.min(LH, Math.ceil(a.y + radius));
  // 白い空気が外へ伸びてほぐれる。放射方向に長いむらを作り、輪郭は閉じない。
  for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
    const dx = x - a.x, dy = y - a.y, d = Math.hypot(dx, dy), k = d / radius;
    if (k > 1 || k < 0.04) continue;
    const angle = Math.atan2(dy, dx), forward = 0.65 + 0.35 * Math.cos(angle - e.a);
    const flow = Math.sin(angle * 11 + Math.sin(angle * 5 + e.seed) * 2 + k * 3 - phase * 2);
    const curl = Math.sin(dx * 0.13 + Math.sin(dy * 0.09) * 2 - phase * 11 + e.seed);
    const density = smooth(-0.65, 0.85, flow * 0.7 + curl * 0.3);
    const envelope = Math.sin(k * Math.PI) ** 1.2 * (1 - smooth(0.7, 1, k));
    const alpha = density * envelope * fade * gain * forward * (small ? 0.10 : 0.19);
    R.front.blend(x, y, density > 0.65 ? white : pale, alpha);
    if ((x & 3) === 0 && (y & 3) === 0) R.front.light(x, y, pale, alpha * 0.42);
  }
  // 吐き出した息の濃い芯だけを短く残す。
  R.front.glow(a.x, a.y, (small ? 4 : 13) * P.size * level.reach, white, fade * gain * 0.24 * (1 - smooth(0.05, 0.3, age)));
}

let roarScreen = null;
function makeRoarScreen() {
  const canvas = document.createElement('canvas'); canvas.width = W; canvas.height = H;
  const source = document.createElement('canvas'); source.width = W; source.height = H;
  const sourceG = source.getContext('2d');
  const gl = canvas.getContext('webgl', { alpha: false, antialias: false, depth: false, preserveDrawingBuffer: false });
  const out = { canvas, source, sourceG, gl: null };
  if (!gl) return out;
  const vertex = `attribute vec2 position; varying vec2 uv;
    void main(){ uv=position*.5+.5; gl_Position=vec4(position,0.,1.); }`;
  const fragment = `precision highp float;
    uniform sampler2D scene; uniform vec2 resolution; uniform int count;
    uniform vec4 waves[8]; uniform vec2 shake; uniform float impact;
    varying vec2 uv;
    vec3 readScene(vec2 p) { return texture2D(scene,clamp(vec2(p.x,1.-p.y),vec2(.001),vec2(.999))).rgb; }
    void main(){
      vec2 point=vec2(uv.x,1.-uv.y), pixel=point*resolution;
      vec2 displacement=vec2(0.), blur=vec2(0.); float fog=0.;
      for(int i=0;i<8;i++) {
        if(i>=count) break;
        vec4 w=waves[i]; vec2 delta=pixel-w.xy;
        float d=length(delta), age=w.z, strength=w.w;
        vec2 direction=delta/max(d,1.);
        float angle=atan(delta.y,delta.x);
        float irregular=sin(angle*7.+sin(angle*3.)*1.8+age*6.)*15.;
        float front=35.+age*950.+irregular;
        float width=55.+age*100.;
        float pressure=exp(-pow((d-front)/width,2.))*pow(max(0.,1.-age/.85),1.5)*strength;
        float near=exp(-d*d/85000.)*(1.-smoothstep(.12,.6,age))*strength;
        displacement+=direction*pressure*16.;
        blur+=direction*(pressure*24.+near*12.);
        fog+=near*.14;
      }
      // 圧力が通った景色自体をずらし、中心から外へにじませる。
      displacement=clamp(displacement,vec2(-28.),vec2(28.));
      blur=clamp(blur,vec2(-40.),vec2(40.));
      vec2 at=point-(displacement+shake)/resolution;
      vec3 color=readScene(at)*.30;
      color+=readScene(at-blur/resolution*.25)*.24;
      color+=readScene(at-blur/resolution*.50)*.20;
      color+=readScene(at-blur/resolution*.75)*.15;
      color+=readScene(at-blur/resolution)*.11;
      float edge=clamp(length(point-vec2(.5))*.95,0.,1.);
      color*=1.-impact*edge*.21;
      color=mix(color,vec3(.76,.85,.89),clamp(fog,0.,.24));
      gl_FragColor=vec4(color,1.);
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
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    const locations = {}; for (const key of ['resolution','count','waves[0]','shake','impact']) locations[key] = gl.getUniformLocation(program, key);
    gl.uniform2f(locations.resolution, W, H); gl.uniform1i(gl.getUniformLocation(program, 'scene'), 0);
    Object.assign(out, { gl, locations });
    canvas.addEventListener('webglcontextlost', event => { event.preventDefault(); out.gl = null; });
  } catch (error) {
    // GPUが使えない環境でも、描画済みの景色の放射ブラーと短い揺れは残す。
    out.gl = null; out.unavailableReason = error.message;
  } finally { for (const shader of shaders) gl.deleteShader(shader); }
  return out;
}
function postCanisRoar(S, R) {
  const P = R.P, level = roarLevel(P);
  if (level.post === 0 || !CANIS_ROARS.has(S.tech) || P.roarPost <= 0 || P.intensity <= 0) return;
  // 猟犬の細かな吠えは口元だけ。全画面を繰り返し揺らさない。
  const events = roarEvents(S, P).filter(e => !e.small);
  if (!events.length) return;
  const processor = roarScreen ||= makeRoarScreen(), waves = new Float32Array(32);
  let impact = 0, shakeX = 0, shakeY = 0;
  events.forEach((e, i) => {
    const point = toL(e.at), strength = P.roarPost * P.intensity * level.post;
    waves.set([point.x * LP, point.y * LP, e.age * 0.85 / level.life, strength], i * 4);
    const kick = smooth(0, 0.025, e.age) * (1 - smooth(0.06, 0.28, e.age)) * strength;
    impact = Math.max(impact, kick);
    shakeX += Math.sin(e.age * 93 + e.seed) * kick * 6;
    shakeY += Math.cos(e.age * 77 + e.seed) * kick * 4;
  });
  g.save(); g.setTransform(1, 0, 0, 1, 0, 0);
  const gl = processor.gl;
  if (gl) {
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, cv);
    gl.uniform1i(processor.locations.count, events.length); gl.uniform4fv(processor.locations['waves[0]'], waves);
    gl.uniform2f(processor.locations.shake, shakeX, shakeY); gl.uniform1f(processor.locations.impact, Math.min(1.5, impact));
    gl.drawArrays(gl.TRIANGLES, 0, 6); g.drawImage(processor.canvas, 0, 0);
  } else {
    processor.sourceG.drawImage(cv, 0, 0);
    g.fillStyle = '#05060f'; g.fillRect(0, 0, W, H); g.drawImage(processor.source, shakeX, shakeY);
    const e = events[0], point = toL(e.at), cx = point.x * LP, cy = point.y * LP;
    const strength = Math.min(1.5, P.roarPost * P.intensity * level.post) * (1 - smooth(0.1, level.life, e.age)) * smooth(0, 0.03, e.age);
    for (let i = 1; i <= 4; i++) { const scale = 1 + strength * i * 0.012; g.globalAlpha = strength * 0.10; g.drawImage(processor.source, cx * (1 - scale) + shakeX, cy * (1 - scale) + shakeY, W * scale, H * scale); }
    g.globalAlpha = strength * 0.035; g.fillStyle = '#d5e7ef'; g.fillRect(0, 0, W, H);
  }
  g.restore();
}
