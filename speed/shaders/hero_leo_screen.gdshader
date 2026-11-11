// しし座の力が効いている間の画面：魔法の力に包まれたように、画面の外側に紫・マゼンタ・淡い青の星雲の光が薄くにじみ、
// 細く長い十字の光の筋をもつきらめきがまたたく。外側はやわらかくぼけてゆっくり揺らぐ。真ん中はくっきりのまま。
// 宇宙の暗さは残し、色は獅子と同じ紫・マゼンタ・青と金の系統で、濃さは抑える。
// 元の画面は画素の位置そのままで拾って色を変えず、足す光とぼけだけ機体の1ドットの格子で求める。
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
uniform vec4 violet = vec4(0.58, 0.40, 0.95, 1.0);
uniform vec4 magenta = vec4(0.90, 0.45, 0.85, 1.0);
uniform vec4 azure = vec4(0.45, 0.62, 1.0, 1.0);
uniform vec4 shine = vec4(1.0, 0.97, 0.92, 1.0);
uniform vec4 gold = vec4(1.0, 0.85, 0.55, 1.0);
// にじみ始める、真ん中からの距離（画面の縁が 1）
uniform float inner : hint_range(0.0, 1.4, 0.01) = 0.8;
// 外側でのぼけの半径（ドット）
uniform float soften : hint_range(0.0, 12.0, 0.1) = 3.0;
// 星雲の光の濃さ
uniform float nebula_light : hint_range(0.0, 1.0, 0.01) = 0.22;
// きらめきの濃さ
uniform float sparkle_light : hint_range(0.0, 2.0, 0.01) = 0.9;
group_uniforms;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 lin(vec3 c) {
	return linear_output ? to_linear(c) : c;
}

// 薄い光をドットの段に区切る。段の境目はドットの網目（4×4 のディザ）でぼかし、くっきりした境目を出さない
float steps(float v, float count, vec2 cell) {
	ivec2 g = ivec2(mod(cell, 4.0));
	const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return floor(v * count + (BAYER[g.y * 4 + g.x] + 0.5) / 16.0) / count;
}

// 十字のきらめき：升目ごとに1つ、芯が明るく、細く長い十字の光の筋がまたたく
float sparkle(vec2 cell, float spacing) {
	vec2 slot = floor(cell / spacing);
	float light = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 s = slot + vec2(float(x), float(y));
			float phase = time / (1.4 + 1.2 * hash(s + 8.0)) + hash(s + 9.0);
			vec2 round_seed = s + floor(phase) * 13.7;
			if (hash(round_seed) > 0.45) continue;
			float t = fract(phase);
			float flash = sin(3.14159 * t);
			flash *= flash;
			vec2 center = floor((s + vec2(hash(round_seed + 1.0), hash(round_seed + 2.0))) * spacing);
			vec2 d = abs(cell - center);
			float arm = (3.0 + 9.0 * hash(round_seed + 5.0)) * flash;
			float c = 0.0;
			if (d.x < 0.5 && d.y < 0.5) c = 1.0;
			else if (d.x < 0.5 && d.y <= arm) c = 1.0 - d.y / (arm + 1.0);
			else if (d.y < 0.5 && d.x <= arm) c = 1.0 - d.x / (arm + 1.0);
			else if (d.x < 1.5 && d.y < 1.5 && flash > 0.6) c = 0.35;
			light = max(light, c * flash);
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
	// 端のほうだけにかかり、内側へは長いグラデーションでぼかして消える
	float edge = smoothstep(inner, 1.5, length(q));
	edge = edge * edge * (3.0 - 2.0 * edge) * strength;
	// 元の画面は画素の位置そのままで拾い、色を変えない（ずらして拾うと画素が混ざって色が変わる）
	vec3 col = textureLod(screen, SCREEN_UV, 0.0).rgb;
	if (edge > 0.001) {
		// 外側ほど、水の中のようにゆっくり揺らぎ、やわらかくぼける
		vec2 wave = vec2(sin(uv.y * 18.0 + time * 1.1), cos(uv.x * 14.0 + time * 0.9)) * 0.002 * edge;
		vec3 soft = vec3(0.0);
		float radius = (1.0 + soften * edge) * cell_px;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7854;
			soft += textureLod(screen, SCREEN_UV + wave + vec2(cos(a), sin(a)) * radius / size, 1.0).rgb;
		}
		col = mix(col, soft / 8.0, edge);
	}
	// 星雲の光：紫・マゼンタ・淡い青が、外側にゆっくりうごめきながらにじむ
	float n1 = vnoise(vec3(cell * 0.012 + vec2(time * 0.04, 0.0), 2.0));
	float n2 = vnoise(vec3(cell * 0.02 - vec2(0.0, time * 0.05), 5.0));
	vec3 cloud = mix(violet.rgb, magenta.rgb, smoothstep(0.35, 0.75, n1));
	cloud = mix(cloud, azure.rgb, smoothstep(0.55, 0.85, n2) * 0.7);
	float veil = edge * (0.4 + 0.6 * n1) * nebula_light;
	col += lin(cloud) * steps(veil, 16.0, cell) * 0.35;
	// 十字のきらめき：外寄りほど多く、ところどころ金
	float star = sparkle(cell, 34.0) * (0.25 + 0.75 * smoothstep(0.0, 0.5, edge / max(strength, 0.001))) * strength;
	vec3 star_col = hash(floor(cell / 34.0) + 21.0) > 0.7 ? gold.rgb : shine.rgb;
	col += lin(star_col) * floor(star * sparkle_light * 8.0) / 8.0;
	COLOR = vec4(col, 1.0);
}
