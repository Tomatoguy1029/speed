shader_type canvas_item;
render_mode unshaded;
uniform sampler2D guard_base : source_color, filter_nearest;
uniform sampler2D guard_armor : source_color, filter_nearest;
uniform sampler2D guard_normal : hint_normal, filter_nearest;
uniform float clock = 0.0;
uniform vec4 armor_paint : source_color = vec4(0.8, 0.8627451, 0.8784314, 1.0);
uniform bool linear_output = false;
varying vec2 local_pixel;
void vertex() { local_pixel = VERTEX; }
vec3 to_linear(vec3 c) { return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c)); }

float noise(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453) * 2.0 - 1.0; }
void fragment() {
	vec2 p = floor(local_pixel / 2.0) * 2.0 + 1.0;
	// 47x28の共通cropを時計回り。原向きpivot(23.5,21)を保つ配置。
	vec2 q = (local_pixel - vec2(13.0, -31.0)) / vec2(36.0, 61.0);
	vec2 source_uv = vec2(q.y, 1.0 - q.x);
	bool in_guard = all(greaterThanEqual(q, vec2(0.0))) && all(lessThan(q, vec2(1.0)));
	vec4 base = in_guard ? texture(guard_base, source_uv) : vec4(0.0);
	vec4 armor = in_guard ? texture(guard_armor, source_uv) : vec4(0.0);
	// 元の5領域キー22/157/170/1035/1076はすべて保存済みccdce0。
	vec4 solid = mix(base, armor_paint, armor.a);
	vec3 n = texture(guard_normal, source_uv).rgb;
	NORMAL_MAP = n;
	float a = atan(p.y, p.x);
	float cut = a < 0.0 ? 0.7955211 : 0.7620108;
	float d = length(p) - 42.0;
	vec4 membrane = vec4(0.0);
	float patch = sin(a * 3.0 + 0.4) * 0.55 + sin(a * 8.0 - 1.0) * 0.3 + sin(a * 13.0 + 0.9) * 0.15;
	if (abs(a) >= cut && max(base.a, armor.a) < 0.01) {
		if (d > -7.0 && d < 5.0) membrane = vec4(0.1098, 0.3647, 0.7176, 0.1373);
		if (d > -4.7 && d < 3.2) membrane = vec4(0.1569, 0.5020, 0.8353, 0.2549);
		if (d > -3.0 && d < 1.4) membrane = vec4(0.2824, 0.6745, 0.9176, 0.5882);
		if (d > -0.4 + patch * 0.7 && d < 1.7 + patch * 0.8) membrane = vec4(0.6824, 0.9255, 1.0, 0.9333);
		if (d > -0.1 && d < 1.4 && patch > -0.1) membrane = vec4(0.9098, 0.9882, 1.0, 1.0);
		if (d > -3.7 && d < -2.3 && patch > 0.0) membrane = vec4(0.5020, 0.8431, 0.9804, 0.6471);
	}
	float tick = clock / 0.15;
	float k = floor(tick);
	float u = smoothstep(0.0, 1.0, fract(tick));
	float region = floor((a + PI) / TAU * 14.0);
	float coarse = mix(noise(vec3(region, k, 0)), noise(vec3(region, k + 1.0, 0)), u);
	vec2 cell = floor(p / 4.0);
	float fine = mix(noise(vec3(cell, k)), noise(vec3(cell, k + 1.0)), u);
	float dip = max(0.0, noise(vec3(region, k + 7.0, 2)) - 0.38) * 0.6;
	membrane.a *= clamp(0.8 + 0.43 * coarse + 0.11 * fine - dip, 0.24, 1.16);
	if (linear_output) membrane.rgb = to_linear(membrane.rgb);
	COLOR = solid.a > 0.0 ? solid : membrane;
}
