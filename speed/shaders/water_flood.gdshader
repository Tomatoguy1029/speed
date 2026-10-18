// みずがめ座の水の演出（RenderManager の水の層が描く）。流れるノイズで水の動きを描く。
// 頂点の色で描き方を渡す：r が種類（0 予告のさざ波、1/3 照射の水流、2/3 光を集める溜め、1 霧）、g が強さ、b がずらし、a が濃さ。
// ビーム（種類 0・1/3・1）の UV：x は根元からの距離（世界の単位の 1/1000）、y は帯の中の左右の位置（端が ±1、外側に飛沫の余白）。
// 溜め（種類 2/3）の UV：瓶の口を中心に -1〜1。
shader_type canvas_item;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

// 深い水 → 明るい水 → 泡（1 を超えるとにじんで光る）
vec3 water_ramp(float x) {
	vec3 deep = vec3(0.02, 0.12, 0.36);
	vec3 mid = vec3(0.08, 0.42, 0.85);
	vec3 light = vec3(0.45, 0.85, 1.0);
	vec3 foam = vec3(1.25, 1.45, 1.6);
	vec3 c = mix(deep, mid, smoothstep(0.0, 0.45, x));
	c = mix(c, light, smoothstep(0.45, 0.75, x));
	return mix(c, foam, smoothstep(0.78, 0.95, x));
}

// 照射の水流。強さ g が 1 未満なら細くなって飛沫に崩れていく
vec4 rushing(float along, float across, float g, float seed) {
	float t = TIME;
	float side = abs(across);
	float widen = 0.6 + along / 700.0;
	vec2 q = vec2(along * 0.0022 - t * 3.6, across * 2.2 * widen + seed);
	float n1 = fbm(q);
	float n2 = fbm(vec2(along * 0.0055 - t * 6.5, across * 5.0 * widen + seed * 1.7) + n1 * 1.3);
	float streak = pow(fbm(vec2(along * 0.0012 - t * 7.5, across * 16.0 * widen + seed * 3.1)), 3.0) * 2.2;
	float flow = n1 * 0.55 + n2 * 0.45;
	// 端は荒れて白く泡立つ
	float edge_foam = smoothstep(0.55, 1.0, side) * (0.35 + 0.5 * n2);
	float x = clamp(flow * 0.9 + streak * 0.35 + edge_foam, 0.0, 1.0);
	// 輪郭はノイズで欠け、強さが落ちると内側へ細る
	float limit = g * (0.9 + 0.16 * (n2 - 0.5));
	float body = 1.0 - smoothstep(limit - 0.08, limit + 0.02, side);
	// 崩れていくときは、流れの薄い所から飛沫にちぎれる
	float breakup = smoothstep(0.62 - 0.55 * g, 0.75 - 0.5 * g, flow + streak * 0.2);
	// 外側の余白に飛ぶ飛沫
	float spray = smoothstep(0.7, 0.9, noise(vec2(along * 0.03 - t * 14.0, side * 40.0 + seed))) *
		smoothstep(1.12, 0.95, side) * smoothstep(0.9 * g, 1.0 * g, side);
	float a = body * breakup * (0.72 + 0.28 * flow) + spray * 0.85 * g;
	vec3 col = water_ramp(x) + vec3(0.6, 0.85, 1.0) * spray * 0.9;
	// 根元は水が噴き出すので明るい
	col += vec3(0.5, 0.8, 1.0) * exp(-along / 140.0) * 0.8;
	return vec4(col, clamp(a, 0.0, 1.0));
}

// 予告のさざ波。照射が近いほど k が上がり、流れに勢いが出る
vec4 ripples(float along, float across, float k, float seed) {
	float t = TIME;
	float side = abs(across);
	float widen = 0.6 + along / 700.0;
	// 薄い水の膜
	float sheet = fbm(vec2(along * 0.003 - t * (0.4 + 1.6 * k), across * 2.0 * widen + seed));
	float inside = 1.0 - smoothstep(0.96, 1.0, side);
	// 外へ流れる波の筋（ノイズでゆらし、さざ波らしく途切れさせる）
	float speed = mix(1.2, 5.0, k * k);
	float freq = mix(0.016, 0.03, k);
	float warp = fbm(vec2(along * 0.004, across * 3.0 * widen + seed)) * 6.0;
	float wave = 0.5 + 0.5 * sin(along * freq - t * speed * 3.0 + warp);
	float crest = pow(wave, mix(10.0, 6.0, k)) * smoothstep(0.35, 0.65, fbm(vec2(along * 0.006 - t * speed * 0.3, across * 6.0 * widen + seed)));
	// 範囲の端に沿って外へ走る水しぶきの線
	float line = smoothstep(0.88, 0.97, side) * (1.0 - smoothstep(1.0, 1.07, side));
	float drops = smoothstep(0.5, 0.7, noise(vec2(along * 0.018 - t * mix(4.0, 13.0, k), side * 26.0 + seed)));
	float spray = line * (0.35 + 0.65 * drops);
	float a = inside * ((0.05 + 0.08 * k) * (0.6 + sheet) + crest * (0.18 + 0.4 * k)) + spray * (0.4 + 0.5 * k);
	vec3 col = mix(vec3(0.1, 0.45, 0.9), vec3(0.55, 0.9, 1.1), crest) ;
	col = mix(col, vec3(0.75, 1.0, 1.25) * (1.0 + 0.4 * k), clamp(spray * 1.5, 0.0, 1.0));
	return vec4(col, clamp(a, 0.0, 1.0));
}

// 溜め：周りから光の筋が瓶の口へ吸い込まれ、口が明るくなる
vec4 gather(vec2 uv, float k, float seed) {
	float t = TIME;
	float rad = length(uv);
	float ang = atan(uv.y, uv.x);
	float swirl = ang + rad * 1.3;
	float rays = noise(vec2(swirl * 7.0 + seed, rad * 3.0 + t * (1.4 + 2.6 * k)));
	rays = smoothstep(0.62 - 0.12 * k, 0.9, rays) * smoothstep(1.0, 0.25, rad) * smoothstep(0.02, 0.15, rad);
	float motes = smoothstep(0.86, 0.97, noise(vec2(swirl * 22.0 + seed, rad * 9.0 + t * (2.5 + 3.5 * k))))
		* smoothstep(1.0, 0.3, rad);
	float core = exp(-rad * rad * (40.0 - 22.0 * k)) * (0.4 + 1.6 * k);
	float a = (rays * 0.55 + motes) * (0.3 + 0.7 * k) + core;
	vec3 col = mix(vec3(0.45, 0.8, 1.1), vec3(1.3, 1.5, 1.7), clamp(core + motes * 0.5, 0.0, 1.0));
	return vec4(col, clamp(a, 0.0, 1.0));
}

// 照射のあとに残る霧と水滴
vec4 mist(float along, float across, float life, float seed) {
	float t = TIME;
	float side = abs(across);
	float widen = 0.6 + along / 700.0;
	float m = fbm(vec2(along * 0.0035 - t * 0.35, across * 1.6 * widen + seed));
	float cloud = smoothstep(0.42, 0.78, m) * smoothstep(1.15, 0.6, side);
	float drops = smoothstep(0.9, 0.98, noise(vec2(along * 0.04 - t * 1.5, across * 30.0 * widen + seed)));
	float a = (cloud * 0.28 + drops * 0.7) * life;
	vec3 col = mix(vec3(0.3, 0.6, 0.9), vec3(0.85, 1.0, 1.2), drops);
	return vec4(col, clamp(a, 0.0, 1.0));
}

void fragment() {
	float mode = COLOR.r;
	float g = COLOR.g;
	float seed = COLOR.b * 97.0;
	float fade = COLOR.a;
	vec4 c;
	if (mode < 0.15) {
		c = ripples(UV.x * 1000.0, UV.y, g, seed);
	} else if (mode < 0.5) {
		c = rushing(UV.x * 1000.0, UV.y, g, seed);
	} else if (mode < 0.85) {
		c = gather(UV, g, seed);
	} else {
		c = mist(UV.x * 1000.0, UV.y, g, seed);
	}
	COLOR = vec4(c.rgb, c.a * fade);
}
