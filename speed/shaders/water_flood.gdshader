// みずがめ座の水の演出（RenderManager の水の層が描く）。流れるノイズで水の動きを描く。
// 頂点の色で描き方を渡す：r が種類（0 予告のさざ波、1/3 照射の水流、2/3 光を集める溜め、1 霧）、g が強さ、b がずらし、a が濃さ。
// ビーム（種類 0・1/3・1）の UV：x は根元からの距離（世界の単位の 1/1000）、y は帯の中の左右の位置（端が ±1、外側に飛沫の余白）。
// 溜め（種類 2/3）の UV：瓶の口を中心に -1〜1（半径 1 の円の外は描かない）。
shader_type canvas_item;

// ビームの根元の幅の半分と、先へ行くほど広がる割合（世界の単位）。帯の中の位置を世界の距離に直すのに使う
uniform float half0 = 35.0;
uniform float slope = 0.33;

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

// 丸い粒。p はセルの単位。density の割合のセルに、半径 radius（セルの単位）の粒を1つ置く
float dots(vec2 p, float density, float radius) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	if (hash(i + 0.37) > density) {
		return 0.0;
	}
	vec2 c = vec2(hash(i + 3.1), hash(i + 7.7)) * 0.5 + 0.25;
	return smoothstep(radius, radius * 0.35, length(f - c));
}

// 照射の水流：幅いっぱいが明るく光る、高速で外へ噴き出す水。g が 1 未満なら細くなって飛沫にちぎれていく
vec4 rushing(float along, float across, float side, float g, float seed) {
	float t = TIME;
	float half = half0 + along * slope;
	float cw = across * half;
	// 外へ長く伸びる筋（流れの向きに引き伸ばしたノイズを速く流す）
	float long_streak = fbm(vec2(along * 0.0016 - t * 5.5, cw * 0.012 + seed));
	float fine_streak = fbm(vec2(along * 0.0045 - t * 13.0, cw * 0.05 + seed * 1.7));
	float flow = long_streak * 0.6 + fine_streak * 0.4;
	// 輪郭は水らしく揺れる
	float wobble = (fbm(vec2(along * 0.006 - t * 9.0, seed + side * 3.0)) - 0.5) * 0.08;
	float body = 1.0 - smoothstep(g * 0.9, g * 0.98, side + wobble);
	// 外側へにじむ光
	float halo = (1.0 - smoothstep(g * 0.95, g * 0.95 + 0.14, side)) * (1.0 - body);
	// ちぎれていくときは、流れの薄い所から抜ける
	float breakup = smoothstep(0.75 - 0.62 * g, 0.85 - 0.62 * g, flow);
	// 縁から外へ飛ぶ飛沫（丸い粒）
	float spray = dots(vec2(along / 22.0 - t * 75.0, (side - 0.9) * half / 12.0 + seed), 0.45, 0.32)
		* smoothstep(0.88 * g, 0.97 * g, side) * smoothstep(1.12, 1.0, side);
	vec3 trough = vec3(0.08, 0.42, 0.95);
	vec3 crest = vec3(0.45, 1.05, 1.45);
	vec3 col = mix(trough, crest, smoothstep(0.3, 0.75, flow));
	// 縁は泡立って明るい
	col = mix(col, vec3(0.85, 1.25, 1.55), smoothstep(0.65, 0.95, side) * 0.7);
	col += vec3(0.6, 1.0, 1.3) * pow(fine_streak, 4.0) * 1.2;
	float a = body * breakup * (0.86 + 0.14 * flow) + halo * 0.45 * g + spray * 0.9;
	col = mix(col, vec3(0.7, 1.0, 1.3), clamp(spray, 0.0, 1.0));
	return vec4(col, clamp(a, 0.0, 1.0));
}

// 予告のさざ波：ほぼ透明な水の膜に、外へ流れる細い波の線。照射が近いほど k が上がり、流れに勢いが出る
vec4 ripples(float along, float across, float side, float k, float seed) {
	float t = TIME;
	float half = half0 + along * slope;
	float cw = across * half;
	float inside = 1.0 - smoothstep(0.97, 1.0, side);
	float sheet = fbm(vec2(along * 0.003 - t * (0.4 + 1.4 * k), cw * 0.004 + seed));
	// 外へ流れる細い波の線（ノイズでゆらし、ところどころ途切れさせる）
	float speed = mix(1.4, 5.5, k * k);
	float warp = fbm(vec2(along * 0.003, cw * 0.006 + seed)) * 5.0;
	float wave = 0.5 + 0.5 * sin(along * mix(0.018, 0.03, k) - t * speed * 3.0 + warp);
	float crest = smoothstep(0.9, 1.0, wave) * smoothstep(0.3, 0.6, fbm(vec2(along * 0.005 - t * speed * 0.3, cw * 0.01 + seed)));
	// 範囲の端に沿って外へ走る水しぶきの線
	float line = smoothstep(0.94, 0.985, side) * (1.0 - smoothstep(0.995, 1.025, side));
	float drops = dots(vec2(along / 18.0 - t * mix(14.0, 45.0, k), (side - 1.0) * half / 10.0 + seed), 0.55, 0.38)
		* smoothstep(0.9, 0.98, side) * smoothstep(1.1, 1.0, side);
	float a = inside * ((0.025 + 0.035 * k) * (0.6 + sheet) + crest * (0.14 + 0.3 * k)) + line * (0.22 + 0.33 * k) + drops * (0.45 + 0.4 * k);
	vec3 col = mix(vec3(0.2, 0.55, 0.95), vec3(0.55, 0.88, 1.05), crest);
	col = mix(col, vec3(0.7, 0.95, 1.15), clamp(line + drops, 0.0, 1.0));
	return vec4(col, clamp(a, 0.0, 1.0));
}

// 溜め：周りから細い光の筋が渦を巻いて瓶の口へ吸い込まれ、口が明るくなる（円の外は描かない）
vec4 gather(vec2 uv, float k, float seed) {
	float t = TIME;
	float rad = length(uv);
	float mask = 1.0 - smoothstep(0.6, 1.0, rad);
	float ang = atan(uv.y, uv.x);
	float swirl = ang + rad * 1.4;
	// 角度は整数倍で回すので継ぎ目が出ない
	float ray = pow(0.5 + 0.5 * sin(swirl * 14.0 + 2.5 * sin(swirl * 5.0 + seed)), 10.0);
	float pulse = fract(rad * 2.4 + t * (0.9 + 1.8 * k) + 0.3 * sin(swirl * 3.0 + seed));
	float streak = ray * smoothstep(0.0, 0.25, pulse) * (1.0 - smoothstep(0.25, 0.7, pulse)) * smoothstep(0.08, 0.22, rad);
	float core = exp(-rad * rad * 90.0) * (0.25 + 0.75 * k);
	float a = (streak * (0.25 + 0.6 * k) + core) * mask;
	vec3 col = mix(vec3(0.45, 0.82, 1.05), vec3(0.9, 1.1, 1.25), clamp(core * 2.0, 0.0, 1.0));
	return vec4(col, clamp(a, 0.0, 1.0));
}

// 照射のあとに残る霧と丸い水滴
vec4 mist(float along, float across, float side, float life, float seed) {
	float t = TIME;
	float half = half0 + along * slope;
	float cw = across * half;
	float m = fbm(vec2(along * 0.003 - t * 0.35, cw * 0.004 + seed));
	float cloud = smoothstep(0.42, 0.78, m) * (1.0 - smoothstep(0.7, 1.1, side));
	float drops = dots(vec2(along / 26.0 - t * 2.0, cw / 26.0 + seed), 0.3, 0.22);
	float a = (cloud * 0.24 + drops * 0.65) * life;
	vec3 col = mix(vec3(0.3, 0.6, 0.9), vec3(0.8, 0.98, 1.1), drops);
	return vec4(col, clamp(a, 0.0, 1.0));
}

void fragment() {
	float mode = COLOR.r;
	float g = COLOR.g;
	float seed = COLOR.b * 97.0;
	float fade = COLOR.a;
	float along = UV.x * 1000.0;
	float side = abs(UV.y);
	vec4 c;
	if (mode < 0.15) {
		c = ripples(along, UV.y, side, g, seed);
	} else if (mode < 0.5) {
		c = rushing(along, UV.y, side, g, seed);
	} else if (mode < 0.85) {
		c = gather(UV, g, seed);
	} else {
		c = mist(along, UV.y, side, g, seed);
	}
	COLOR = vec4(c.rgb, c.a * fade);
}
