// 本体のアルファ形状からにじむ背面オーラ。表面と手前の金粉は legendary_mantle が描く。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 radiance_color : source_color = vec4(1.0, 0.765, 0.16, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 1.8;
uniform float motion_time = 0.0;
uniform float flow_strength : hint_range(0.0, 1.0) = 0.65;
uniform float wisp_strength : hint_range(0.0, 2.0) = 1.4;
uniform float dust_strength : hint_range(0.0, 2.0) = 0.9;
uniform float exposure : hint_range(0.0, 1.0) = 0.0;
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
float dust(vec2 pixel) {
	// 種ごとに位置をずらした金粉をゆっくり上へ運ぶ。明滅で増減させない。
	vec2 drifting = pixel + vec2(motion_time * 2.8, motion_time * 14.0);
	vec2 cell = floor(drifting / 4.0);
	vec2 dot_pos = vec2(hash(cell + 11.0), hash(cell + 37.0)) * 2.8 + 0.6;
	float distance = length(mod(drifting, 4.0) - dot_pos);
	return (1.0 - smoothstep(0.25, 0.9, distance)) * step(0.7, hash(cell)) * (0.4 + hash(cell + 73.0) * 0.6);
}
void vertex() {
	item_tint = COLOR;
}
void fragment() {
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 uv = (pixel + 0.5) * TEXTURE_PIXEL_SIZE;
	float shape = texture(TEXTURE, uv).a;
	vec2 drift = vec2(motion_time * 0.16, motion_time * 0.65);
	float field = cloud(pixel / vec2(23.0, 36.0) + drift);
	float folds = cloud(pixel / vec2(9.0, 27.0) + vec2(field * 2.0, motion_time * 0.55));
	float thread = pow(max(0.0, 1.0 - abs(folds * 2.0 - 1.0)), 8.0);
	float powder = dust(pixel) * dust_strength;
	vec3 light = radiance_color.rgb;
	float density = 0.0;
	float near = 0.0;
	float glow = 0.0;
	float rising = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		vec2 direction = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		near += texture(TEXTURE, uv + direction * 2.5).a / 8.0;
	}
	for (int i = 0; i < 24; i++) {
		float angle = float(i) * 2.39996323;
		float radius = sqrt((float(i) + 0.5) / 24.0) * 25.0;
		radius *= 0.8 + field * 0.4;
		vec2 offset = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * radius;
		glow += texture(TEXTURE, uv + offset).a / 24.0;
	}
	// 輪郭を起点にした上向きの薄い流れ。物体のない場所へ発生させない。
	for (int i = 1; i <= 12; i++) {
		float height = float(i) * 4.5;
		float bend = sin(pixel.y * 0.035 + field * 4.0 + motion_time * 0.65) * height * 0.35;
		vec2 offset = vec2(bend, height) * TEXTURE_PIXEL_SIZE;
		rising += texture(TEXTURE, uv + offset).a * exp(-float(i) * 0.16) / 4.0;
	}
	float proximity = max(0.0, glow - shape);
	float plume = max(0.0, rising - shape) * smoothstep(0.15, 0.65, field);
	float rim = max(0.0, near - shape) * 0.7;
	float envelope = max(proximity, plume * 0.6);
	float smoke = plume * (0.3 + thread * 0.95) * wisp_strength;
	float motes = powder * smoothstep(0.015, 0.12, envelope) * 0.75;
	float current = 0.7 + field * 0.6;
	density = (rim + proximity * 1.1 + smoke + motes) * current * intensity * mix(1.0, 0.8, exposure);
	light = mix(light * vec3(1.0, 0.85, 0.25), light, clamp(thread + rim, 0.0, 1.0));
	// UV の画素格子で輪郭を保ち、細かなディザによる色粒は重ねない。
	density = 1.0 - exp(-max(0.0, density) * 1.3);
	COLOR = vec4(light, density) * item_tint;
}
