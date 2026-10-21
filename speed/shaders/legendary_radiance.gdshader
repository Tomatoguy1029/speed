// 既存モジュールのアルファ輪郭から溢れる後光。専用画像にも同じ輪郭追従を使う。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 radiance_color : source_color = vec4(1.0, 0.88, 0.6, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 1.25;
uniform float motion_time = 0.0;
uniform float flow_strength : hint_range(0.0, 1.0) = 0.4;
uniform float exposure : hint_range(0.0, 1.0) = 0.0;
varying vec4 item_tint;
void vertex() {
	item_tint = COLOR;
}
void fragment() {
	vec4 tint = item_tint;
	vec2 uv = (floor(UV / TEXTURE_PIXEL_SIZE) + 0.5) * TEXTURE_PIXEL_SIZE;
	float shape = texture(TEXTURE, uv).a;
	float near = 0.0;
	float glow = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		vec2 direction = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		near += texture(TEXTURE, uv + direction * 2.5).a / 8.0;
	}
	// 半径と方角を分散して光をにじませる。等間隔の複製輪郭を残さない。
	for (int i = 0; i < 24; i++) {
		float angle = float(i) * 2.39996323;
		float radius = sqrt((float(i) + 0.5) / 24.0) * 15.0;
		vec2 offset = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * radius;
		glow += texture(TEXTURE, uv + offset).a / 24.0;
	}
	// 黒い本体が光を遮り、その外側に細い白金の縁と広い金のにじみが残る。
	float rim = max(0.0, near - shape) * 0.9;
	float spill = max(0.0, glow - shape) * 0.6;
	float restraint = mix(1.0, 0.72, exposure);
	// 表面の近くをゆっくり巡る密度。角度の連続変化で、粒や輪郭を点滅させない。
	float current = sin(uv.x * 12.0 + sin(uv.y * 8.0 - motion_time * 0.3) * 1.4 + motion_time * 0.4);
	float flow = 1.0 + current * flow_strength * 0.45;
	vec2 pixel = floor(uv / TEXTURE_PIXEL_SIZE);
	float dust = fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
	float proximity = max(0.0, glow - shape);
	float motes = step(0.992, dust) * proximity * 0.7;
	float fold = uv.x * 35.0 + uv.y * 10.0 + sin(uv.y * 20.0 - motion_time * 0.4) * 2.0;
	float threads = pow(max(0.0, sin(fold)), 10.0) * proximity * flow_strength * 0.35;
	vec3 light = mix(radiance_color.rgb, vec3(1.0, 0.97, 0.85), clamp(rim * 0.6, 0.0, 0.3));
	float density = ((rim + spill) * flow + motes + threads) * intensity * restraint;
	density = floor(density * 24.0 + dust * 0.6) / 24.0;
	COLOR = vec4(light, density) * tint;
}
