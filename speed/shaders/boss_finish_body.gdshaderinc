// ボス撃破の演出で、撮ったボスの絵を色の層と光の層に分ける。試作の bossFrame と同じ計算。
// 座標はすべて世界座標。長さの単位は「ボスの絵の1ドット」＝世界のキャラクター倍率（cs）。
uniform sampler2D capture : filter_nearest, repeat_disable;
uniform sampler2D noise : filter_nearest, repeat_enable;
uniform vec2 capture_size = vec2(1.0);
uniform vec2 cap_x = vec2(1.0, 0.0);
uniform vec2 cap_y = vec2(0.0, 1.0);
uniform vec2 cap_o = vec2(0.0);
uniform vec2 scr_x = vec2(1.0, 0.0);
uniform vec2 scr_y = vec2(0.0, 1.0);
uniform vec2 scr_o = vec2(0.0);
uniform vec2 target_size = vec2(1.0);
uniform bool linear_input = false;
uniform bool linear_output = false;
uniform vec2 origin;
uniform vec2 impact;
uniform vec2 cut_dir = vec2(0.0, -1.0);
uniform float cs = 1.0;
uniform float max_r = 140.0;
uniform bool boost = true;
uniform float cut_end = -1e9;
uniform float hit = 0.0;
uniform float gray = 0.0;
uniform float dark = 0.0;
uniform float front = 0.0;
uniform float pulse = 0.0;
uniform float gold = 0.0;
uniform float cut_alpha = 1.0;
uniform float since_burst = -1.0;
uniform float burst_time = 1.0;
uniform int silhouette = 0;
uniform vec2 shift;
uniform float turn = 0.0;
uniform float squash = 1.0;

vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)); }
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }

vec2 screen_world(vec2 pixel) { return scr_x * pixel.x + scr_y * pixel.y + scr_o; }

// col：色の層（sRGB・不透明度）。glow：光の層（sRGB・強さ）。
void body_sample(vec2 world, out vec4 col, out vec4 glow) {
	col = vec4(0.0);
	glow = vec4(0.0);
	vec2 rel = world - origin - shift;
	float c = cos(-turn), s = sin(-turn);
	rel = vec2(rel.x * c - rel.y * s, rel.x * s + rel.y * c) / squash;
	vec2 source = origin + rel;
	vec2 uv = (cap_x * source.x + cap_y * source.y + cap_o) / capture_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return;
	vec4 base = texture(capture, uv);
	if (base.a < 0.04) return;
	vec3 rgb = linear_input ? to_srgb(base.rgb) : base.rgb;
	vec2 dot_pos = floor(rel / cs) + 0.5;
	vec2 cut_pos = (origin + dot_pos * cs - impact) / cs;
	float u = dot(cut_pos, cut_dir);
	float d = cut_pos.x * cut_dir.y - cut_pos.y * cut_dir.x;
	vec4 n = texture(noise, dot_pos / 252.0);
	float edge = n.r * 16.0;
	float r = length(dot_pos);
	float ad = boost ? abs(d) : r;
	float tf = boost ? 0.03 + 0.58 * (0.65 * abs(d) / max_r + 0.35 * r / max_r) : 0.03 + 0.62 * r / max_r;
	tf += 0.09 * n.b + 0.09 * n.g;
	if (silhouette > 0) {
		col = vec4(vec3(silhouette == 1 ? 0.0 : 1.0), 1.0);
		if (boost && silhouette == 2 && abs(d) < 1.6 && u < cut_end) glow = vec4(1.0);
		return;
	}
	if (since_burst >= 0.0) {
		float q = since_burst - tf * burst_time;
		if (q > 0.07) return;
		if (q > -0.1) {
			float m = clamp((q + 0.1) / 0.1, 0.0, 1.0);
			rgb = mix(rgb, vec3(1.0, 250.0 / 255.0, 225.0 / 255.0), m);
			glow = vec4(1.0, 240.0 / 255.0, 200.0 / 255.0, m);
		}
	}
	float lum = rgb.r * 0.3 + rgb.g * 0.55 + rgb.b * 0.15;
	rgb = mix(rgb, vec3(lum * 0.8, lum * 0.84, lum * 0.95), gray * 0.8);
	rgb *= 1.0 - dark;
	rgb = mix(rgb, vec3(1.0), hit);
	if (boost && u < cut_end && cut_alpha > 0.0) {
		float near = exp(-abs(d) / 5.0) * cut_alpha * (0.55 + 0.45 * pulse);
		rgb += vec3(1.0, mix(1.0, 205.0 / 255.0, gold), mix(1.0, 110.0 / 255.0, gold)) * near;
		if (abs(d) < 1.5) glow = vec4(1.0, mix(1.0, 232.0 / 255.0, gold), mix(1.0, 170.0 / 255.0, gold), cut_alpha);
	}
	if (front > 0.0 && ad < front) {
		float width = (1.0 - 0.6 * ad / front) * (0.8 + 0.3 * pulse) + (since_burst > 0.0 ? since_burst * 4.0 : 0.0);
		if (edge < width) {
			float m = 0.55 + 0.45 * pulse;
			rgb = mix(rgb, vec3(1.0, mix(215.0, 250.0, pulse) / 255.0, mix(120.0, 215.0, pulse) / 255.0), m);
			glow = vec4(1.0, 220.0 / 255.0, 130.0 / 255.0, max(glow.a, m));
		}
	}
	col = vec4(min(rgb, vec3(1.0)), 1.0);
}
