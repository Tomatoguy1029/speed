shader_type canvas_item;
render_mode unshaded;

uniform bool use_normal = true;
uniform bool cosmic = false;
uniform float boss_hit_white : hint_range(0.0, 0.28) = 0.0;
uniform bool normal_flip_x = false;
uniform bool painted = false;
uniform vec4 paint : source_color = vec4(1.0);
uniform float normal_strength = 1.0;
uniform float ambient = 0.08;
uniform float key_energy = 1.1;
uniform float fill_energy = 0.6;
uniform vec3 key_direction = vec3(0.686, -0.686, 0.243);
uniform vec3 fill_direction = vec3(-0.686, 0.686, 0.243);
uniform bool linear_target = false;
uniform bool finale_tone = false;
uniform float finale_gray = 0.0;
uniform float finale_lit = 0.0;
uniform float finale_gap = 0.0;
uniform vec2 finale_center = vec2(0.0);
// 登場時だけ、顔の元画像の赤い目を発光させ、奥の部位を裂け目の内側へ隠す。
uniform bool entrance = false;
uniform bool entrance_head = false;
uniform float entrance_depth = 1.0;
uniform float entrance_eyes = 0.0;
uniform vec2 entrance_portal = vec2(0.0);
uniform float entrance_open = 1.0;
varying vec2 world_at;
varying vec2 axis_x;
varying vec2 axis_y;
varying vec4 vertex_tint;

void vertex() {
	axis_x = normalize(MODEL_MATRIX[0].xy);
	axis_y = normalize(MODEL_MATRIX[1].xy);
	vertex_tint = COLOR;
	world_at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (finale_gap > 0.0) {
		vec2 at = world_at - finale_center;
		float jag = 6.0 * sin(at.y * 0.07) + 5.0 * sin(at.y * 0.19 + 1.0) + 3.0 * sin(at.y * 0.41 + 2.0);
		if (abs(at.x - jag) < finale_gap) { discard; }
	}
	// 陰影は絵の色のまま掛ける。決着の階調は出力の色で決めてある。
	bool srgb_light = linear_target && !finale_tone;
	vec3 albedo = srgb_light ? pow(pixel.rgb, vec3(1.0 / 2.2)) : pixel.rgb;
	if (painted) {
		float shade = max(pixel.r, max(pixel.g, pixel.b));
		float shade_paint = srgb_light ? max(albedo.r, max(albedo.g, albedo.b)) : shade;
		albedo = (srgb_light ? pow(paint.rgb, vec3(1.0 / 2.2)) : paint.rgb) * shade_paint;
	}
	float light_amount = 1.0;
	if (use_normal) {
		vec3 normal = texture(NORMAL_TEXTURE, UV).rgb * 2.0 - 1.0;
		if (normal_flip_x) { normal.x = -normal.x; }
		normal = normalize(vec3(normal.xy * normal_strength, max(normal.z, 0.001)));
		vec2 world_xy = mat2(axis_x, -axis_y) * normal.xy;
		normal = vec3(world_xy, normal.z);
		light_amount = ambient + key_energy * max(dot(normal, key_direction), 0.0)
			+ fill_energy * max(dot(normal, fill_direction), 0.0);
	}
	vec3 result = albedo * light_amount;
	if (cosmic) {
		float wave = sin(UV.y * 19.0 + UV.x * 8.0 + TIME * 2.0) * 0.5 + 0.5;
		result = mix(result, mix(vec3(0.14, 0.08, 0.45), vec3(0.25, 0.8, 1.0), wave), 0.65);
	}
	if (finale_tone) {
		float tone = clamp(dot(result, vec3(0.3, 0.59, 0.11)) * 255.0 / 150.0, 0.0, 1.0);
		vec3 gray = mix(vec3(0.19, 0.24, 0.32), vec3(0.43, 0.47, 0.53), tone);
		vec3 shadow = mix(vec3(0.02, 0.04, 0.094), gray, finale_gray);
		result = mix(shadow, result, finale_lit);
	}
	if (entrance) {
		vec2 portal_at = world_at - entrance_portal;
		float aperture = max(1.0, 190.0 * entrance_open) * sqrt(max(0.0, 1.0 - pow(portal_at.y / 390.0, 2.0)));
		if (entrance_depth < 0.25 && (abs(portal_at.y) > 390.0 || abs(portal_at.x) > aperture)) { discard; }
		bool eye = entrance_head && albedo.r > 0.2 && albedo.r > albedo.g * 1.6 && albedo.r > albedo.b * 1.4;
		if (entrance_depth <= 0.001 && !eye) { discard; }
		result *= smoothstep(0.0, 0.7, entrance_depth);
		if (eye) { result = mix(result, vec3(1.0, 0.025, 0.055), entrance_eyes); }
	}
	result = mix(result, vec3(1.0), boss_hit_white);
	COLOR = vec4(srgb_light ? pow(max(result, vec3(0.0)), vec3(2.2)) : result, pixel.a) * vertex_tint;
}
