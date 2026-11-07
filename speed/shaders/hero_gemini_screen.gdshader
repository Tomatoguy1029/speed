// ふたご座の力が効いている間の画面：画面の縁を紫のかすみがなめらかに包み、その上に金の粉が散ってまたたく。
// 左右の側面には、金の粒でできた太い線の束が縁にそって縦に流れ、角で上・下の縁へ弧を描いて抜ける（右下は右の縁から下の縁へ、
// 左上は左の縁から上の縁へ）。線にそって光が流れる。真ん中はくっきりのまま。
// 元の画面は画素の位置そのままで拾って色を変えず、足す光だけ機体の1ドットの格子で求める。
// HDR の画面ではリニアのまま扱い、足す色だけリニアへ直す。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/burst_noise.gdshaderinc"
#include "res://shaders/hero_color.gdshaderinc"
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
uniform float time = 0.0;
// 画面での1ドットの大きさ（画素）
uniform float cell_px = 2.0;
uniform bool linear_output = false;
group_uniforms tuning;
uniform vec4 violet = vec4(0.42, 0.18, 0.72, 1.0);
uniform vec4 deep = vec4(0.14, 0.05, 0.26, 1.0);
uniform vec4 gold = vec4(1.0, 0.76, 0.24, 1.0);
uniform vec4 amber = vec4(0.95, 0.55, 0.14, 1.0);
uniform vec4 pale_gold = vec4(1.0, 0.9, 0.6, 1.0);
// 紫のかすみがかかり始める、真ん中からの距離（画面の縁が 1）
uniform float inner : hint_range(0.0, 1.4, 0.01) = 0.85;
// 紫のかすみの濃さ
uniform float veil_amount : hint_range(0.0, 1.0, 0.01) = 0.32;
// 縁を沈める濃さ
uniform float shadow_amount : hint_range(0.0, 1.0, 0.01) = 0.2;
// 外側でのぼけの半径（ドット）
uniform float soften : hint_range(0.0, 12.0, 0.1) = 3.0;
// 金の粉の濃さ
uniform float dust_light : hint_range(0.0, 2.0, 0.01) = 1.4;
// 角から流れ込む金の線の濃さ
uniform float line_light : hint_range(0.0, 2.0, 0.01) = 1.3;
group_uniforms;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 lin(vec3 c) {
	return linear_output ? to_linear(c) : c;
}

float steps(float v, float count, vec2 cell) {
	ivec2 g = ivec2(mod(cell, 4.0));
	const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return floor(v * count + (BAYER[g.y * 4 + g.x] + 0.5) / 16.0) / count;
}

// 金の粉：spacing ドットの升目ごとに1粒（density の割合で）。粒ごとに違う周期でまたたき、たまに2ドットの大きな粒
vec4 glitter(vec2 cell, float spacing, float density) {
	vec2 slot = floor(cell / spacing);
	if (hash(slot + 31.0) > density) return vec4(0.0);
	vec2 at = floor((slot + vec2(hash(slot + 1.0), hash(slot + 2.0))) * spacing);
	vec2 d = abs(cell - at);
	float big = hash(slot + 3.0) > 0.85 ? 1.0 : 0.0;
	if (d.x > big + 0.5 || d.y > big + 0.5) return vec4(0.0);
	float twinkle = 0.5 + 0.5 * sin(time * (1.5 + 3.0 * hash(slot + 4.0)) + hash(slot + 5.0) * 6.28);
	float pick = hash(slot + 6.0);
	vec3 c = pick > 0.66 ? pale_gold.rgb : pick > 0.33 ? gold.rgb : amber.rgb;
	return vec4(c, twinkle * twinkle);
}

// 線の束の i 本目の、高さ y での横の位置（画面の 0〜1）。p は右下の束の向きの画面の位置。
// 上の端は右の縁の top の高さから始まり、下へ行くほど内へ寄って、下の縁では bottom の位置に届く
float sweep_x(float y, float top, float bottom, float phase) {
	float k = clamp((y - top) / (1.0 - top), 0.0, 1.0);
	return mix(1.02, bottom, pow(k, 1.8)) + 0.006 * sin(y * 9.0 + time * 0.5 + phase);
}

// 金の線の束と、そのまわりにこぼれる粉
float lines(vec2 p, vec2 cell, vec2 size, float seed) {
	float light = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float top = 0.22 + 0.06 * fi;
		if (p.y < top) continue;
		float x = sweep_x(p.y, top, 0.9 - 0.045 * fi, fi * 1.7 + seed);
		float dist = abs(p.x - x) * size.x / cell_px;
		// 上の端は細く消える
		float along = smoothstep(top, top + 0.18, p.y);
		// 線にそって光が流れる
		float run = 0.5 + 0.5 * sin(p.y * 22.0 + time * (1.2 + 0.3 * fi) + fi * 2.0);
		float core = along * (0.45 + 0.55 * run) * (0.7 + 0.06 * fi);
		// 線は幅のある粒の帯：真ん中ほど粒が詰まり、粒ごとに明るさが違う
		if (dist < 8.0) {
			if (hash(cell + fi * 7.0 + seed) < 0.75 - 0.08 * dist) light = max(light, core * (0.5 + 0.5 * hash(cell + fi * 3.0 + seed + 9.0)) * (1.0 - dist / 12.0));
		}
		// 線のまわりにこぼれる粉
		else if (dist < 22.0) {
			vec2 slot = floor(cell / 3.0);
			if (hash(slot + fi * 13.0 + seed) > 1.0 - 0.5 * (1.0 - dist / 22.0)) {
				vec2 at = floor((slot + vec2(hash(slot + 1.0 + fi), hash(slot + 2.0 + fi))) * 3.0);
				if (all(lessThan(abs(cell - at), vec2(0.5)))) light = max(light, along * run * 0.8);
			}
		}
	}
	return light;
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / cell_px);
	vec2 uv = (cell + 0.5) * cell_px / size;
	vec2 q = (uv - 0.5) * 2.0;
	q.x *= size.x / size.y * 0.8;
	float r = length(q);
	float edge = smoothstep(inner, 1.7, r);
	edge = edge * edge;
	vec3 col = textureLod(screen, SCREEN_UV, 0.0).rgb;
	float e = edge * strength;
	if (e > 0.001) {
		// 外側ほど、やわらかくぼける
		vec3 soft = vec3(0.0);
		float radius = (1.0 + soften * e) * cell_px;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7854;
			soft += textureLod(screen, SCREEN_UV + vec2(cos(a), sin(a)) * radius / size, 1.0).rgb;
		}
		col = mix(col, soft / 8.0, e);
		// 紫のかすみ：縁を少し沈め、ゆっくり濃淡が揺れる紫で包む
		float haze = 0.75 + 0.25 * vnoise(vec3(cell * 0.01 + vec2(time * 0.03, -time * 0.02), 3.0));
		col = mix(col, lin(deep.rgb), steps(e * shadow_amount, 24.0, cell));
		col += lin(violet.rgb) * steps(e * haze * veil_amount, 24.0, cell);
		// 金の粉：外側ほど多い
		vec4 g = glitter(cell, 4.0, 0.2 + 0.6 * edge);
		col += lin(g.rgb) * floor(g.a * e * dust_light * 6.0) / 6.0;
	}
	// 側面を流れる金の線の束：右下と、それを画面の中心で回した左上
	float flow = max(lines(uv, cell, size, 0.0), lines(vec2(1.0) - uv, cell, size, 40.0));
	col += lin(mix(amber.rgb, pale_gold.rgb, flow)) * floor(flow * strength * line_light * 6.0) / 6.0;
	COLOR = vec4(col, 1.0);
}
