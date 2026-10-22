// 不透明なモジュールの背後から伸びる後光。前面素材とオーラは別パスで保つ。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 center = vec2(0.5, 0.47);
uniform vec4 light_color : source_color = vec4(0.89, 0.73, 0.42, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.8;
uniform float arrival : hint_range(0.0, 1.0) = 1.0;
uniform float exposure : hint_range(0.0, 1.0) = 0.0;
uniform float core_strength : hint_range(0.0, 4.0) = 3.6;
uniform float core_radius : hint_range(0.08, 0.35) = 0.22;
uniform float broad_ray_strength : hint_range(0.0, 4.0) = 1.2;
uniform float fine_ray_strength : hint_range(0.0, 4.0) = 0.75;
uniform float ray_reach : hint_range(0.3, 2.0) = 1.0;
uniform float ray_width : hint_range(0.5, 2.0) = 1.1;
uniform float surge_strength : hint_range(0.0, 3.0) = 0.12;
uniform float motion_time = 0.0;
uniform float core_distortion : hint_range(0.0, 1.0) = 0.35;
uniform float ray_turbulence : hint_range(0.0, 1.0) = 0.3;
uniform float ray_breakup : hint_range(0.0, 1.0) = 0.25;
float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}
float grain1(float p) {
	float cell = floor(p);
	return mix(hash(cell), hash(cell + 1.0), smoothstep(0.0, 1.0, fract(p)));
}
float cloud(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 h = fract(sin(vec4(dot(cell, vec2(12.9, 78.2)), dot(cell + vec2(1.0, 0.0), vec2(12.9, 78.2)),
		dot(cell + vec2(0.0, 1.0), vec2(12.9, 78.2)), dot(cell + vec2(1.0), vec2(12.9, 78.2)))) * 43758.5);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}
void fragment() {
	vec2 pixel = floor(UV * vec2(640.0, 360.0));
	vec2 p = (pixel / vec2(640.0, 360.0) - center) * vec2(1.77778, 1.0);
	float radius = length(p);
	// 低周波の偏りを形そのものへ使い、細かな場で縁と光の筋へほのかな揺らぎを加える。
	vec2 drift = vec2(motion_time * 0.10, -motion_time * 0.065);
	vec2 low = vec2(cloud(p * 3.2 + drift + 4.0), cloud(p * 3.2 + drift + 19.0)) - 0.5;
	vec2 detail = vec2(cloud(p * 15.0 + drift * 1.7 + 7.0), cloud(p * 15.0 + drift * 1.7 + 31.0)) - 0.5;
	vec2 direction = p / max(radius, 0.001);
	float lobe = cloud(direction * 2.6 + drift * 0.4 + 11.0);
	vec2 core_p = p + (low * 0.55 + detail * 0.06) * core_radius * core_distortion;
	float core_edge = core_radius * mix(1.0, 0.65 + lobe * 0.7, core_distortion);
	float core_distance = length(core_p);
	float core_density = mix(1.0, 0.8 + cloud(p * 11.0 + drift + 23.0) * 0.4, core_distortion);
	float angle = atan(p.y, p.x) + (low.x * 0.28 + detail.y * 0.05) * ray_turbulence;
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
		float width = mix(0.025, 0.1, hash(seed + 20.0)) * ray_width;
		float strand = grain1(radius * 8.0 + seed * 17.0 + motion_time * 0.6);
		width *= mix(1.0, 0.45 + strand * 1.15, ray_breakup);
		float beam = exp(-pow(d / width, 2.0));
		float gap = smoothstep(0.26, 0.66, grain1(radius * 20.0 + seed * 59.0 - motion_time * 0.45));
		float density = mix(1.0, 0.3 + gap * 0.9, ray_breakup);
		float reach = ray_reach * mix(0.38, 1.45, hash(seed + 89.0));
		float end = 1.0 - smoothstep(reach * 0.7, reach, radius + detail.x * 0.035);
		broad += beam * density * end * exp(-radius / ray_reach * mix(1.8, 3.8, hash(seed + 40.0))) * mix(0.35, 1.0, hash(seed + 70.0));
		sector = mod(fine_sector + float(i) + 38.0, 38.0);
		seed = sector + 101.0;
		a = (sector + hash(seed) * 0.95) * 6.2831853 / 38.0;
		d = abs(mod(wrapped_angle - a + 3.14159265, 6.2831853) - 3.14159265);
		width = mix(0.003, 0.012, hash(seed + 20.0)) * ray_width;
		width *= mix(1.0, 0.3 + strand * 1.4, ray_breakup);
		float length_fade = exp(-radius / ray_reach * mix(2.0, 5.0, hash(seed + 40.0)));
		gap = smoothstep(0.34, 0.58, grain1(radius * 32.0 + seed * 31.0 + motion_time * 0.65));
		reach = ray_reach * mix(0.24, 1.15, hash(seed + 89.0));
		end = 1.0 - smoothstep(reach * 0.65, reach, radius);
		fine += exp(-pow(d / width, 2.0)) * length_fade * end * mix(1.0, gap, ray_breakup) * mix(0.3, 1.0, hash(seed + 70.0));
	}
	float core = exp(-pow(core_distance / core_edge, 2.0)) * core_strength * core_density;
	float haze = exp(-radius * radius * 26.0) * 0.14;
	float shroud = cloud(p * 14.0 + vec2(arrival * 0.1, 0.0));
	float veil = mix(0.2 + shroud * 0.8, 1.0, exposure);
	float ray_mask = smoothstep(0.025, 0.07, radius);
	float rays = (broad * broad_ray_strength + fine * fine_ray_strength) * ray_mask * veil;
	// 白く飽和する光源を背面に置き、外側で金色へつなぐ。前面の材質は別パスで遮蔽する。
	vec3 white = vec3(1.0);
	vec3 gold = light_color.rgb;
	float warmth = smoothstep(core_edge * 0.7, core_edge * 1.6, core_distance);
	vec3 core_color = mix(white, mix(gold, white, 0.25), warmth);
	vec3 core_energy = core_color * core * (0.55 + surge * 0.6) * intensity;
	// 中心の白さを保ちながら、広い白ベタのクリップを柔らかな階調へ置き換える。
	vec3 emission = core_energy;
	emission += mix(gold, white, exp(-radius * 5.0) * 0.65) * rays * (0.85 + surge * 0.4) * intensity;
	emission += gold * haze * intensity;
	// 光の合成後に階調を圧縮し、白い核の周辺にもなだらかな明暗を残す。
	emission = vec3(0.98) * (vec3(1.0) - exp(-emission * 1.6));
	emission += vec3(0.05) * exp(-pow(core_distance / (core_edge * 0.36), 2.0));
	// 画素格子は上の UV で保つ。RGB を個別に丸めると金色の縁に色段差が出るため、
	// 光の色と階調はそのまま合成する。
	COLOR = vec4(emission, 1.0);
}
