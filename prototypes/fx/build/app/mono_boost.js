// GIFと同じ噴射口・直進する帯・加減速。シミュレーション中に長さと太さを更新する。
function monoBoostStep(S, dt) {
  const B = S.B, P0 = P(), k = B.r / 96;
  const run = S.stage === 'run' || S.tech === 'sweep' && S.stage === 'approach';
  if (run && S.boostRunAt == null) S.boostRunAt = S.t;
  if (!run) S.boostRunAt = null;
  const burst = run ? 1 + 0.5 * (1 - smooth(0, 0.18, S.t - S.boostRunAt)) : 1;
  const move = S.tech === 'sweep' ? clamp((S.v || 0) / (S.r.approach_speed_max || 1), 0, 1.2) : clamp((S.travel || 700) / 700, 0.4, 2);
  const idle = 50 * 0.55 * k, braking = ['brake', 'stop', 'end'].includes(S.stage);
  const ratio = braking ? clamp(len(B.vel) / Math.max(1, S.runSpeed || S.r.speed || S.r.approach_speed_max), 0, 1) : 0;
  const drive = run ? 1 : ratio, lengthScale = (P0.tailJet ?? 1) * P0.size, widthScale = (P0.tailJetWidth ?? 1) * P0.size;
  const target = lerp(idle, B.r * 2.6 * burst * move, drive) * lengthScale;
  const targetWidth = lerp(12 * k, 16 * k * burst * Math.sqrt(Math.max(0.2, move)), drive) * widthScale;
  const state = S.boost ||= { length: idle * lengthScale, width: 12 * k * widthScale };
  const response = 1 - Math.exp(-dt / (target > state.length ? 0.045 / (P0.tailJetResponse ?? 1) : 0.22));
  state.length = lerp(state.length, target, response);
  state.width = lerp(state.width, targetWidth, response);
}
function monoBoostSamples(S) {
  const L = S.boost.length * WL, W0 = S.boost.width * WL, clock = S.t, samples = [];
  if (L <= 0 || W0 <= 0) return samples;
  for (let x = 0; x < L; x += 0.55) {
    const u = x / L, flow = 0.88 + 0.12 * Math.sin(x * 0.55 - clock * 39);
    const w = Math.max(0.12, W0 * Math.pow(1 - u, 0.62) * flow * (0.94 + 0.06 * Math.sin(x * 0.9 - clock * 24)));
    const taper = smooth(0, Math.min(2, L * 0.1), x) * (1 - smooth(0.84, 1, u));
    for (const [factor, channel] of [[1.5, 0], [0.85, 1], [0.32, 2]]) {
      const radius = w * factor * taper;
      if (radius > 0.1) samples.push([x, 0, radius, channel, 1.5]);
    }
  }
  return samples;
}
// 既存pixel_fire_density / shape / glowの式を、そのままWebGLへ移す。
// 粒のRGB密度を加算し、輪郭・3色の面・弱い発光を別々のパスで描く。
function monoCreateFireShader() {
  const canvas = document.createElement('canvas');
  const gl = canvas.getContext('webgl2', { alpha: true, premultipliedAlpha: true, antialias: false, preserveDrawingBuffer: true });
  if (!gl) return null;
  const compile = (type, source) => {
    const shader = gl.createShader(type); gl.shaderSource(shader, source); gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader));
    return shader;
  };
  const program = (vertex, fragment) => {
    const p = gl.createProgram();
    const vs = compile(gl.VERTEX_SHADER, vertex), fs = compile(gl.FRAGMENT_SHADER, fragment);
    gl.attachShader(p, vs); gl.attachShader(p, fs); gl.linkProgram(p); gl.deleteShader(vs); gl.deleteShader(fs);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
    return p;
  };
  const quadVS = `#version 300 es
    in vec2 position; out vec2 uv;
    void main(){ uv=(position+1.0)*0.5; gl_Position=vec4(position.x,-position.y,0.0,1.0); }`;
  const density = program(`#version 300 es
    in vec2 position; in vec2 texcoord; in vec3 channel; uniform vec2 field_size;
    out vec2 uv; out vec3 tint;
    void main(){ uv=texcoord; tint=channel; gl_Position=vec4(position.x/field_size.x*2.0-1.0,1.0-position.y/field_size.y*2.0,0.0,1.0); }`,
    `#version 300 es
    precision highp float; in vec2 uv; in vec3 tint; out vec4 color;
    void main(){ vec2 p=uv*2.0-1.0;
      float d=exp(-dot(p,p)*3.2)*(1.0-smoothstep(0.72,1.0,length(p)));
      color=vec4(tint*d,0.0); }`);
  const shape = program(quadVS, `#version 300 es
    precision highp float; in vec2 uv; out vec4 color; uniform sampler2D source;
    uniform vec2 field_size; uniform float clock;
    uniform vec3 outer_color; uniform vec3 inner_color; uniform vec3 core_color;
    void main(){
      vec2 pixel=(floor(uv*field_size)+0.5)/field_size;
      vec2 w=pixel*field_size;
      vec2 warp=vec2(sin(w.y*0.075-clock*4.4)+sin(w.x*0.11+w.y*0.033+clock*2.1),cos(w.x*0.08+clock*3.0)*0.55);
      vec2 at=clamp(pixel+warp*0.35/field_size,vec2(0.001),vec2(0.999));
      vec3 density=texture(source,vec2(at.x,1.0-at.y)).rgb;
      vec3 mask=step(vec3(0.5),smoothstep(vec3(0.32),vec3(0.36),density));
      mask.g*=mask.r; mask.b*=mask.g;
      vec3 c=mix(mix(outer_color,inner_color,mask.g),core_color,mask.b);
      color=vec4(c*mask.r,mask.r);
    }`);
  const glow = program(quadVS, `#version 300 es
    precision highp float; in vec2 uv; out vec4 color; uniform sampler2D source; uniform vec2 field_size;
    vec3 sample_at(vec2 offset){vec2 q=clamp(uv+offset,vec2(0.001),vec2(0.999));return texture(source,vec2(q.x,1.0-q.y)).rgb;}
    void main(){vec2 a=vec2(2.0)/field_size;
      vec3 near=sample_at(vec2(a.x,0.0))+sample_at(vec2(-a.x,0.0))+sample_at(vec2(0.0,a.y))+sample_at(vec2(0.0,-a.y));
      vec3 far=sample_at(a*2.0)+sample_at(-a*2.0)+sample_at(vec2(a.x,-a.y)*2.0)+sample_at(vec2(-a.x,a.y)*2.0);
      color=vec4((near*0.17+far*0.08)*0.16,1.0);
    }`);
  const body = program(quadVS, `#version 300 es
    precision highp float; in vec2 uv; out vec4 color; uniform sampler2D source;
    void main(){color=texture(source,vec2(uv.x,1.0-uv.y));}`);
  const particles = gl.createBuffer(), quad = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, quad); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]), gl.STATIC_DRAW);
  const textures = [gl.createTexture(), gl.createTexture()], buffers = [gl.createFramebuffer(), gl.createFramebuffer()];
  let width = 0, height = 0;
  const uniform = (p, name) => gl.getUniformLocation(p, name);
  const fieldSize = p => gl.uniform2f(uniform(p, 'field_size'), width, height);
  const bindQuad = p => {
    gl.useProgram(p); gl.bindBuffer(gl.ARRAY_BUFFER, quad);
    const loc = gl.getAttribLocation(p, 'position'); gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    gl.activeTexture(gl.TEXTURE0); gl.uniform1i(uniform(p, 'source'), 0);
  };
  const resize = (w, h) => {
    if (w === width && h === height) return;
    width = w; height = h; canvas.width = w; canvas.height = h;
    for (let i = 0; i < 2; i++) {
      gl.bindTexture(gl.TEXTURE_2D, textures[i]);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
      gl.bindFramebuffer(gl.FRAMEBUFFER, buffers[i]); gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, textures[i], 0);
    }
  };
  return { draw(S, at, angle, samples, P0) {
    if (!samples.length) return;
    const side = Math.max(...samples.map(q => q[2]));
    resize(Math.max(192, Math.ceil(side*2+16)), Math.max(512, Math.ceil(S.boost.length*WL+80)));
    const ox = width*0.5, oy = height-40, values = [];
    for (const [x,y,r,ch,axial] of samples) {
      for (const [sx,sy] of [[-1,-1],[1,-1],[-1,1],[-1,1],[1,-1],[1,1]]) {
        values.push(ox+y+sx*r,oy-x+sy*axial,(sx+1)/2,(sy+1)/2,ch===0?1:0,ch===1?1:0,ch===2?1:0);
      }
    }
    gl.viewport(0,0,width,height); gl.bindFramebuffer(gl.FRAMEBUFFER,buffers[0]); gl.clearColor(0,0,0,0); gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(density); fieldSize(density); gl.bindBuffer(gl.ARRAY_BUFFER,particles); gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(values),gl.DYNAMIC_DRAW);
    for (const [name,size,offset] of [['position',2,0],['texcoord',2,8],['channel',3,16]]) {
      const loc=gl.getAttribLocation(density,name); gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc,size,gl.FLOAT,false,28,offset);
    }
    gl.enable(gl.BLEND); gl.blendFunc(gl.ONE,gl.ONE); gl.drawArrays(gl.TRIANGLES,0,values.length/7); gl.disable(gl.BLEND);
    gl.bindFramebuffer(gl.FRAMEBUFFER,buffers[1]); gl.clear(gl.COLOR_BUFFER_BIT); bindQuad(shape); gl.bindTexture(gl.TEXTURE_2D,textures[0]); fieldSize(shape);
    gl.uniform1f(uniform(shape,'clock'),S.t);
    for (const [name,col] of [['outer_color',P0.tailOuterColor],['inner_color',P0.tailJetColor],['core_color',P0.tailCoreColor]]) {
      const c=parseCol(col); gl.uniform3f(uniform(shape,name),c.r,c.g,c.b);
    }
    gl.drawArrays(gl.TRIANGLES,0,6);
    const point=toL(at);
    g.save(); g.setTransform(LP,0,0,LP,0,0); g.translate(point.x,point.y); g.rotate(angle+Math.PI/2); g.imageSmoothingEnabled=false;
    g.globalAlpha=Math.min(1,P0.intensity);
    gl.bindFramebuffer(gl.FRAMEBUFFER,null); bindQuad(glow); gl.bindTexture(gl.TEXTURE_2D,textures[1]); fieldSize(glow); gl.drawArrays(gl.TRIANGLES,0,6);
    g.globalCompositeOperation='lighter'; g.drawImage(canvas,-ox,-oy);
    bindQuad(body); gl.bindTexture(gl.TEXTURE_2D,textures[1]); gl.drawArrays(gl.TRIANGLES,0,6);
    g.globalCompositeOperation='source-over'; g.drawImage(canvas,-ox,-oy); g.restore();
  }};
}
let MONO_FIRE_SHADER;
function monoPixelBooster(S, R, rig) {
  if (!S.boost) monoBoostStep(S, 0);
  if (R.P.intensity <= 0 || R.P.tailJet <= 0 || R.P.tailJetWidth <= 0) return;
  const mat = rig.mats['TailBooster/Sprite/booster']; if (!mat) return;
  if (MONO_FIRE_SHADER === undefined) MONO_FIRE_SHADER = monoCreateFireShader();
  if (MONO_FIRE_SHADER) MONO_FIRE_SHADER.draw(S, M.pt(mat,V(37,0)), S.tailAngle+Math.PI, monoBoostSamples(S), R.P);
}
