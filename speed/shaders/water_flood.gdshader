// みずがめ座の水の演出（RenderManager の水の層が描く）。作っておいたノイズ画像を流して、水と光の動きを描く。
// 光のにじみ（ブルーム）はここでは描かない。明るさ（1 を超える値）を出し、にじませるのはポストプロセス（RenderPipeline）。
// 頂点の色で描き方を渡す：r が種類（0 予告のさざ波、1/3 照射の光、1 霧）、g が強さ、b がずらし、a が濃さ。
// UV：ビームの中心の線に沿った、本体の中心からの距離（x）と、中心の線からの横のずれ（y）。どちらも世界の単位の 1/1000。
// ビームの三角形は本体の中心に頂点が集まるので、UV は位置と同じく三角形の中でまっすぐ補間される。
shader_type canvas_item;

// HDR の描画では頂点の色が線形に直されて届く。そのときは元の値（sRGB）に戻して読む
uniform bool linear_colors = false;
uniform float preview_clock = -1.0;
// 継ぎ目なく並ぶノイズ画像（assets/fx/water_noise.png）。R・G は大きなうねり、B は細かい揺らぎ
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
// ビームの根元の幅の半分、先へ行くほど広がる割合、長さ（世界の単位）
uniform float half0 = 0.0;
uniform float slope = 0.33;
uniform float beam_len = 2200.0;

// ノイズ画像を読む。座標 1 がうねり1つぶん
float wave_a(vec2 p) {
	return texture(noise_tex, p * 0.125).r;
}

float wave_b(vec2 p) {
	return texture(noise_tex, p * 0.125).g;
}

float ripple_fine(vec2 p) {
	return texture(noise_tex, p * 0.125).b;
}

// 丸い粒。p はセルの単位。density くらいの割合のセルに、半径 radius（セルの単位）の粒を1つ置く。
// セルごとのばらつきは、ノイズ画像の離れた画素を読んで決める
float dots(vec2 p, float density, float radius) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	ivec2 cell = ivec2(mod(i * vec2(37.0, 61.0) + i.yx * vec2(13.0, 7.0), 512.0));
	vec3 h = texelFetch(noise_tex, cell, 0).rgb;
	if (h.b > density) {
		return 0.0;
	}
	vec2 c = h.rg * 0.5 + 0.25;
	return smoothstep(radius, radius * 0.35, length(f - c));
}

// 照射の光：幅いっぱいが白く強く光り、外へ高速で流れる。g が 1 未満なら細くなって飛沫にちぎれていく
vec4 rushing(float along, float across, float side, float g, float seed) {
	float t = preview_clock >= 0.0 ? preview_clock : TIME;
	float half = half0 + along * slope;
	float cw = across * half;
	// 外へ高速で流れる光の筋（流れの向きに引き伸ばしたノイズ）
	float long_streak = wave_a(vec2(along * 0.0012 - t * 11.0, cw * 0.01 + seed));
	float fine_streak = wave_b(vec2(along * 0.0035 - t * 26.0, cw * 0.045 + seed * 1.7));
	float flow = long_streak * 0.55 + fine_streak * 0.45;
	// 輪郭は細かく震える
	float wobble = (ripple_fine(vec2(along * 0.02 - t * 40.0, seed)) - 0.5) * 0.05;
	float body = 1.0 - smoothstep(g * 0.92, g * 0.99, side + wobble);
	// ちぎれていくときは、流れの薄い所から抜ける
	float breakup = smoothstep(0.75 - 0.62 * g, 0.85 - 0.62 * g, flow);
	// 縁から外へ飛ぶ光の粒
	float spray = dots(vec2(along / 22.0 - t * 120.0, (side - 0.9) * half / 12.0 + seed), 0.45, 0.3)
		* smoothstep(0.88 * g, 0.97 * g, side) * smoothstep(1.12, 1.0, side);
	// 白い強い光。筋の明るい所はさらに強く、縁だけわずかに水色
	float intensity = 2.0 + 1.6 * smoothstep(0.35, 0.8, flow) + 1.5 * pow(fine_streak, 3.0);
	vec3 col = vec3(1.0) * intensity;
	col = mix(col, vec3(0.75, 1.0, 1.25) * 1.8, smoothstep(0.7, 0.99, side) * 0.6);
	float a = body * breakup + spray;
	col = mix(col, vec3(0.9, 1.05, 1.25) * 2.2, clamp(spray, 0.0, 1.0) * (1.0 - body));
	return vec4(col, clamp(a, 0.0, 1.0));
}

// 予告のさざ波：ほぼ透明な水の膜に、外へ流れる細い波の線。照射が近いほど k が上がり、流れに勢いが出る
vec4 ripples(float along, float across, float side, float k, float seed) {
	float t = preview_clock >= 0.0 ? preview_clock : TIME;
	float half = half0 + along * slope;
	float cw = across * half;
	float inside = 1.0 - smoothstep(0.97, 1.0, side);
	float sheet = wave_a(vec2(along * 0.003 - t * (0.4 + 1.4 * k), cw * 0.004 + seed));
	// 外へ流れる細い波の線（ノイズでゆらし、ところどころ途切れさせる）
	float speed = mix(1.4, 5.5, k * k);
	float warp = wave_b(vec2(along * 0.003, cw * 0.006 + seed)) * 5.0;
	float wave = 0.5 + 0.5 * sin(along * mix(0.018, 0.03, k) - t * speed * 3.0 + warp);
	float crest = smoothstep(0.9, 1.0, wave) * smoothstep(0.3, 0.6, ripple_fine(vec2(along * 0.005 - t * speed * 0.3, cw * 0.01 + seed)));
	// 範囲の端に沿って外へ走る水しぶきの線
	float line = smoothstep(0.94, 0.985, side) * (1.0 - smoothstep(0.995, 1.025, side));
	float drops = dots(vec2(along / 18.0 - t * mix(14.0, 45.0, k), (side - 1.0) * half / 10.0 + seed), 0.55, 0.38)
		* smoothstep(0.9, 0.98, side) * smoothstep(1.1, 1.0, side);
	float a = inside * ((0.025 + 0.035 * k) * (0.6 + sheet) + crest * (0.14 + 0.3 * k)) + line * (0.22 + 0.33 * k) + drops * (0.45 + 0.4 * k);
	vec3 col = mix(vec3(0.2, 0.55, 0.95), vec3(0.55, 0.88, 1.05), crest);
	col = mix(col, vec3(0.7, 0.95, 1.15), clamp(line + drops, 0.0, 1.0));
	return vec4(col, clamp(a, 0.0, 1.0));
}

// 照射のあとに残る霧と丸い水滴
vec4 mist(float along, float across, float side, float life, float seed) {
	float t = preview_clock >= 0.0 ? preview_clock : TIME;
	float half = half0 + along * slope;
	float cw = across * half;
	float m = wave_a(vec2(along * 0.003 - t * 0.35, cw * 0.004 + seed));
	float cloud = smoothstep(0.42, 0.78, m) * (1.0 - smoothstep(0.7, 1.1, side));
	float drops = dots(vec2(along / 26.0 - t * 2.0, cw / 26.0 + seed), 0.3, 0.22);
	float a = (cloud * 0.24 + drops * 0.65) * life;
	vec3 col = mix(vec3(0.3, 0.6, 0.9), vec3(0.8, 0.98, 1.1), drops);
	return vec4(col, clamp(a, 0.0, 1.0));
}

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void fragment() {
	vec3 raw = linear_colors ? to_srgb(COLOR.rgb) : COLOR.rgb;
	float mode = raw.r;
	float g = raw.g;
	float seed = raw.b * 97.0;
	float along = UV.x * 1000.0;
	// 帯の中の左右の位置（中心の線が 0、端が ±1）
	float across = UV.y * 1000.0 / max(half0 + along * slope, 1.0);
	float side = abs(across);
	// 先の方は薄くする
	float fade = COLOR.a * (1.0 - smoothstep(0.7, 1.0, along / beam_len));
	vec4 c;
	if (mode < 0.15) {
		c = ripples(along, across, side, g, seed);
	} else if (mode < 0.66) {
		c = rushing(along, across, side, g, seed);
	} else {
		c = mist(along, across, side, g, seed);
	}
	COLOR = vec4(c.rgb, c.a * fade);
}
