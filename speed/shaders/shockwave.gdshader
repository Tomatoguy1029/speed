// 衝撃波の歪み（全画面の処理）：画面の中の円の波紋で、背後の絵をずらす。
// 波紋は最大 8 個。中心（画面の割合）、半径（画面の高さに対する割合）、強さ（0〜1）。
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform int count = 0;
uniform vec4 waves[8];
uniform float aspect = 1.7778;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 offset = vec2(0.0);
	for (int i = 0; i < 8; i++) {
		if (i >= count) {
			break;
		}
		vec4 w = waves[i];
		vec2 d = uv - w.xy;
		d.x *= aspect;
		float dist = length(d);
		float band = 1.0 - smoothstep(0.0, 0.035, abs(dist - w.z));
		offset += (dist > 0.0001 ? d / dist : vec2(0.0)) * band * w.w * 0.012;
	}
	offset.x /= aspect;
	COLOR = texture(screen, uv - offset);
}
