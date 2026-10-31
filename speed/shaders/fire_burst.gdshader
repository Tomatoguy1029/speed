// 試作の pfire：ドット単位の炎の爆発。焼いた値ノイズで縁を崩し、密度で4段の色に分け、一番外は市松で透かす。
// 長さはドット単位。四角の中心が炎の中心で、半径の 1.2 倍の外は描かない。
// tuning の値は戦闘エフェクトツールで装備ごとに上書きする（ShaderTuning）。
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D value_noise : repeat_disable, filter_nearest;
uniform float half_cells = 30.0;
uniform float radius = 20.0;
uniform float life = 0.0;
// 炎の中心のドット座標と種（ノイズを場所ごと・炎ごとに変える）
uniform vec2 origin = vec2(0.0);
uniform float seed = 0.0;
group_uniforms tuning;
uniform vec4 c0 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 c1 : source_color = vec4(1.0, 0.949, 0.659, 1.0);
uniform vec4 c2 : source_color = vec4(1.0, 0.690, 0.188, 1.0);
uniform vec4 c3 : source_color = vec4(0.824, 0.275, 0.110, 1.0);
uniform float noise_scale : hint_range(0.04, 0.5, 0.01) = 0.16;
uniform float roughness : hint_range(0.0, 2.0, 0.05) = 0.95;
uniform float burn_speed : hint_range(0.3, 3.0, 0.05) = 1.15;
uniform float start_size : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform float flash_boost : hint_range(0.0, 1.5, 0.05) = 0.7;
uniform float outer_dither : hint_range(0.0, 1.0, 0.05) = 1.0;
group_uniforms;

float lattice(vec3 p) {
	vec3 i = mod(p, 64.0);
	vec2 tile = vec2(mod(i.z, 8.0), floor(i.z / 8.0));
	return texture(value_noise, (tile * 64.0 + i.xy + 0.5) / 512.0).r;
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(lattice(i), lattice(i + vec3(1, 0, 0)), u.x), mix(lattice(i + vec3(0, 1, 0)), lattice(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(lattice(i + vec3(0, 0, 1)), lattice(i + vec3(1, 0, 1)), u.x), mix(lattice(i + vec3(0, 1, 1)), lattice(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * 2.0 * half_cells);
	float rt = radius * (start_size + (1.0 - start_size) * (1.0 - pow(1.0 - min(1.0, life * 3.0), 3.0)));
	float d = length(cell) / max(rt, 0.1);
	if (d > 1.2) {
		discard;
	}
	vec2 at = cell + origin;
	float n = vnoise(vec3(at.x * noise_scale + seed, at.y * noise_scale - life * 3.0, life * 5.0 + seed));
	float den = (1.0 - d) * 1.35 + (n - 0.5) * roughness - life * burn_speed + (life < 0.07 ? flash_boost : 0.0);
	if (den > 0.8) {
		COLOR = c0;
	} else if (den > 0.55) {
		COLOR = c1;
	} else if (den > 0.33) {
		COLOR = c2;
	} else if (den > 0.16) {
		float coverage = mix(0.5, 1.0 - mod(at.x + at.y, 2.0), outer_dither);
		if (coverage <= 0.0) discard;
		COLOR = vec4(c3.rgb, c3.a * coverage);
	} else {
		discard;
	}
}
