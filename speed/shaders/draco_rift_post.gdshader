shader_type canvas_item;
render_mode unshaded, blend_disabled;
// 空間の裂け目：奥に次元の狭間がのぞき、まわりの景色が押しのけられて筋になる。論理画素の格子で計算する。
uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform bool linear_target = false;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float time = 0.0;
uniform int count = 0;
uniform vec4 ends[12];  // 論理画素の A.xy, B.xy
uniform vec4 shape[12]; // wide, tip(0-1), open2, seed
const float PIXEL_HEIGHT = 225.0;
const float BAND = 34.0;
float hash1(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }
float tear_edge(float s, float seed) { return (hash1(floor(s / 5.0) * 1.7 + seed) * 2.0 - 1.0) * 0.3 + mod(s, 5.0) / 5.0 * 0.16; }
float width_at(float s, float side, float L, float tip_s, float wide, float seed) {
	float lens = pow(sin(3.14159265 * clamp(s / L, 0.0, 1.0)), 0.55);
	float mouth = smoothstep(0.0, max(8.0, tip_s * 0.35), tip_s - s);
	return wide * lens * mouth * (1.0 + tear_edge(s + side * 13.0, seed));
}
vec3 to_target(vec3 c) { return linear_target ? pow(c, vec3(2.2)) : c; }
void fragment() {
	float lp = viewport_size.y / PIXEL_HEIGHT;
	vec2 cell = floor(SCREEN_UV * viewport_size / lp) + 0.5;
	vec2 logical_size = viewport_size / lp;
	vec3 out_color = vec3(0.0);
	float out_a = 0.0;
	for (int i = 0; i < count && out_a < 0.5; i++) {
		vec2 A = ends[i].xy, B = ends[i].zw;
		float L = distance(A, B);
		if (L < 1.0) continue;
		vec2 u = (B - A) / L, n = vec2(-u.y, u.x), d = cell - A;
		float wide = shape[i].x, seed = shape[i].w, tip_s = L * shape[i].y, al = dot(d, u), lat = dot(d, n);
		if (al < 0.0 || al > tip_s + BAND * 0.6 || abs(lat) > BAND + wide * 1.3) continue;
		float s = min(al, L);
		float up = al <= tip_s ? width_at(s, 1.0, L, tip_s, wide, seed) : 0.0;
		float dn = al <= tip_s ? width_at(s, -1.0, L, tip_s, wide, seed) : 0.0;
		if (al <= tip_s && lat < up && lat > -dn) {
			float edge = min(up - lat, lat + dn);
			float depth = 1.0 - abs(lat) / max(1.0, lat > 0.0 ? up : dn);
			if (edge < 1.0) { out_color = vec3(1.0, 0.957, 1.0); out_a = 1.0; continue; }
			if (edge < 2.2) { out_color = vec3(0.769, 0.588, 1.0); out_a = 1.0; continue; }
			float n1 = texture(noise_tex, vec2(al * 0.035 + time * 0.35, lat * 0.09 - time * 0.9 + seed) * 0.12).r;
			float n2 = texture(noise_tex, vec2(al * 0.07 - time * 0.6, lat * 0.16 + time * 0.5) * 0.12).r;
			float core = smoothstep(0.35, 1.0, depth);
			float mix_k = smoothstep(0.35, 0.8, n1) * (1.0 - core * 0.55);
			vec3 col = n2 > 0.5 ? vec3(1.0, 0.431, 0.839) : vec3(0.471, 0.886, 1.0);
			float glow_k = smoothstep(0.62, 0.92, n1) * 0.7 * (1.0 - core * 0.6);
			vec3 c = mix(mix(vec3(0.024, 0.012, 0.063), vec3(0.149, 0.071, 0.361), mix_k), col, glow_k);
			float line = floor(lat);
			if (hash1(floor(al * 0.9 - time * 26.0 * (1.0 + mod(line, 2.0))) * 7.1 + line * 13.3 + seed) > 0.985) c = vec3(1.0);
			out_color = c;
			out_a = 1.0;
			continue;
		}
		float side = lat >= 0.0 ? 1.0 : -1.0;
		float gap = abs(lat) - (lat >= 0.0 ? up : dn);
		float fade = 1.0 - clamp(gap / BAND, 0.0, 1.0);
		float open2 = shape[i].z * clamp(min(al, L - al) / 18.0, 0.0, 1.0);
		float push = 17.0 * fade * fade * open2;
		if (push < 0.4) continue;
		float drag = side * 12.0 * fade * fade * open2 + sin(al * 0.12 + time * 7.0) * 1.6 * fade;
		vec3 best = vec3(0.0);
		float lum = -1.0;
		for (int k = -2; k <= 2; k++) {
			vec2 at = cell - n * side * push + u * (drag + float(k) * 2.5 * fade);
			vec3 sampled = texture(screen, at / logical_size).rgb;
			float v = sampled.r + sampled.g + sampled.b;
			if (v > lum) { lum = v; best = sampled; }
		}
		float tint = 0.32 * fade * fade * fade * open2;
		// 色の混ぜ方は試作の表示色で行う。
		vec3 shown = linear_target ? pow(best, vec3(1.0 / 2.2)) : best;
		out_color = to_target(mix(shown, vec3(0.588, 0.392, 1.0), tint));
		out_a = 2.0;
	}
	if (out_a < 0.5) discard;
	COLOR = vec4(out_a > 1.5 ? out_color : to_target(out_color), 1.0);
}
