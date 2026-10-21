// 白金の核・太さの異なる光芒・黒い遮蔽を局所的に重ねる。進行は UI の実時間で受け取る。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 center = vec2(0.5, 0.47);
uniform vec4 light_color : source_color = vec4(0.89, 0.73, 0.42, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.7;
uniform float arrival : hint_range(0.0, 1.0) = 1.0;
uniform float exposure : hint_range(0.0, 1.0) = 0.0;
uniform float core_strength : hint_range(0.0, 4.0) = 1.8;
uniform float broad_ray_strength : hint_range(0.0, 4.0) = 1.25;
uniform float fine_ray_strength : hint_range(0.0, 4.0) = 1.1;
uniform float surge_strength : hint_range(0.0, 3.0) = 1.0;
float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}
float cloud(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 h = fract(sin(vec4(dot(cell, vec2(12.9, 78.2)), dot(cell + vec2(1.0, 0.0), vec2(12.9, 78.2)),
		dot(cell + vec2(0.0, 1.0), vec2(12.9, 78.2)), dot(cell + vec2(1.0), vec2(12.9, 78.2)))) * 43758.5);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}
void fragment() {
	vec2 pixel = floor(UV * vec2(960.0, 540.0));
	vec2 p = (pixel / vec2(960.0, 540.0) - center) * vec2(1.77778, 1.0);
	float radius = length(p);
	float angle = atan(p.y, p.x);
	// 一度だけ息を吸って広がる光。角度やノイズをフレーム乱数で変えない。
	float surge = pow(max(0.0, sin(exposure * 3.14159265)), 1.3) * surge_strength;
	float broad = 0.0;
	float fine = 0.0;
	float wrapped_angle = mod(angle + 6.2831853, 6.2831853);
	float broad_sector = floor(wrapped_angle * 12.0 / 6.2831853);
	float fine_sector = floor(wrapped_angle * 38.0 / 6.2831853);
	// 画素の近くにある光芒だけを評価し、同じ分布を少ないサンプルで描く。
	for (int i = -1; i <= 1; i++) {
		float sector = mod(broad_sector + float(i) + 12.0, 12.0);
		float seed = sector + 1.0;
		float a = (sector + hash(seed) * 0.8) * 6.2831853 / 12.0;
		float d = abs(mod(wrapped_angle - a + 3.14159265, 6.2831853) - 3.14159265);
		float width = mix(0.018, 0.095, hash(seed + 20.0));
		float beam = exp(-pow(d / width, 2.0));
		broad += beam * exp(-radius * mix(2.0, 5.0, hash(seed + 40.0))) * mix(0.35, 1.0, hash(seed + 70.0));
		sector = mod(fine_sector + float(i) + 38.0, 38.0);
		seed = sector + 101.0;
		a = (sector + hash(seed) * 0.95) * 6.2831853 / 38.0;
		d = abs(mod(wrapped_angle - a + 3.14159265, 6.2831853) - 3.14159265);
		width = mix(0.002, 0.009, hash(seed + 20.0));
		float length_fade = exp(-radius * mix(2.2, 7.5, hash(seed + 40.0)));
		fine += exp(-pow(d / width, 2.0)) * length_fade * mix(0.3, 1.0, hash(seed + 70.0));
	}
	float core = exp(-radius * radius * 52.0) * core_strength;
	float haze = exp(-radius * radius * 10.0) * 0.2;
	float shroud = cloud(p * 14.0 + vec2(arrival * 0.1, 0.0));
	float veil = mix(0.2 + shroud * 0.8, 1.0, exposure);
	float ray_mask = smoothstep(0.025, 0.07, radius);
	float rays = (broad * broad_ray_strength + fine * fine_ray_strength) * ray_mask * veil;
	// 白い核から先へ金色が伸びる。黒い部品の遮蔽は前景の別パスが担う。
	vec3 white = vec3(1.0, 0.96, 0.82);
	vec3 gold = light_color.rgb;
	vec3 emission = white * core * (0.55 + surge * 2.8);
	emission += mix(gold, white, exp(-radius * 5.0) * 0.65) * rays * (0.28 + surge * 1.45);
	emission += gold * haze;
	float noise = fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
	emission *= 0.97 + noise * 0.03;
	COLOR = vec4(emission, intensity);
}
