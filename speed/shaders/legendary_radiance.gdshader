// 既存モジュールのアルファ輪郭から溢れる後光。専用画像にも同じ輪郭追従を使う。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 radiance_color : source_color = vec4(1.0, 0.88, 0.6, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 1.4;
uniform float exposure : hint_range(0.0, 1.0) = 0.0;
varying vec4 item_tint;
void vertex() {
	item_tint = COLOR;
}
void fragment() {
	vec4 tint = item_tint;
	float shape = texture(TEXTURE, UV).a;
	float near = 0.0;
	float glow = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		vec2 direction = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		near += texture(TEXTURE, UV + direction * 2.5).a / 8.0;
	}
	// 半径と方角を分散して光をにじませる。等間隔の複製輪郭を残さない。
	for (int i = 0; i < 24; i++) {
		float angle = float(i) * 2.39996323;
		float radius = sqrt((float(i) + 0.5) / 24.0) * 21.0;
		vec2 offset = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * radius;
		glow += texture(TEXTURE, UV + offset).a / 24.0;
	}
	// 黒い本体が光を遮り、その外側に細い白金の縁と広い金のにじみが残る。
	float rim = max(0.0, near - shape) * 0.9;
	float spill = max(0.0, glow - shape) * 0.6;
	float restraint = mix(1.0, 0.62, exposure);
	vec3 light = mix(radiance_color.rgb, vec3(1.0, 0.97, 0.85), clamp(rim * 2.0, 0.0, 1.0));
	COLOR = vec4(light, (rim + spill) * intensity * restraint) * tint;
}
