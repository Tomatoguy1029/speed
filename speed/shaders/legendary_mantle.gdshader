// 物体の表面と輪郭に纏う薄い流れ・金粉。背面の白光の手前にも金色の濃淡を残す。
shader_type canvas_item;
render_mode unshaded;
uniform vec4 radiance_color : source_color = vec4(1.0, 0.88, 0.6, 1.0);
uniform float motion_time = 0.0;
uniform float flow_strength : hint_range(0.0, 1.0) = 0.4;
uniform float wisp_strength : hint_range(0.0, 2.0) = 0.85;
uniform float dust_strength : hint_range(0.0, 2.0) = 0.9;
uniform float surface_strength : hint_range(0.0, 1.0) = 0.45;
varying vec4 item_tint;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
float cloud(vec2 p) {
	vec2 c = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(c), hash(c + vec2(1.0, 0.0)), f.x),
		mix(hash(c + vec2(0.0, 1.0)), hash(c + vec2(1.0)), f.x), f.y);
}
void vertex() { item_tint = COLOR; }
void fragment() {
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 uv = (pixel + 0.5) * TEXTURE_PIXEL_SIZE;
	float shape = texture(TEXTURE, uv).a;
	float field = cloud(pixel / vec2(23.0, 36.0) + vec2(motion_time * 0.025, motion_time * 0.07));
	float folds = cloud(pixel / vec2(9.0, 27.0) + vec2(field * 2.0, motion_time * 0.1));
	float thread = pow(max(0.0, 1.0 - abs(folds * 2.0 - 1.0)), 9.0);
	float around = 0.0;
	float rising = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		around += texture(TEXTURE, uv + vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * 9.0).a / 8.0;
	}
	for (int i = 1; i <= 6; i++) {
		float height = float(i) * 8.0;
		vec2 offset = vec2((field - 0.5) * height * 0.45, height) * TEXTURE_PIXEL_SIZE;
		rising += texture(TEXTURE, uv + offset).a * exp(-float(i) * 0.42) / 2.0;
	}
	float proximity = max(0.0, max(around, rising * 0.8) - shape);
	vec2 drifting = pixel + vec2(motion_time * 0.7, motion_time * 3.0);
	vec2 cell = floor(drifting / 4.0);
	vec2 dot_pos = vec2(hash(cell + 11.0), hash(cell + 37.0)) * 2.8 + 0.6;
	float powder = (1.0 - smoothstep(0.25, 0.9, length(mod(drifting, 4.0) - dot_pos))) * step(0.7, hash(cell));
	float curl = pixel.x * 0.24 + sin(pixel.y * 0.07 + motion_time * 0.15) * 1.8 + field * 3.0;
	float tendril = pow(max(0.0, sin(curl)), 12.0);
	float smoke = proximity * (tendril * 0.65 + thread * 0.35) * (0.3 + field * 0.7) * wisp_strength * 1.4;
	float surface = shape * (thread * flow_strength * 0.1 + powder * dust_strength * 0.7) * surface_strength;
	float mote = powder * smoothstep(0.02, 0.15, proximity) * dust_strength * 0.7;
	float alpha = floor(clamp(smoke + surface + mote, 0.0, 0.8) * 32.0 + hash(pixel) * 0.5) / 32.0;
	vec3 gold = mix(radiance_color.rgb * 0.7, vec3(1.0, 0.93, 0.67), smoothstep(0.4, 0.85, folds));
	COLOR = vec4(gold, alpha) * item_tint;
}
