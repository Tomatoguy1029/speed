shader_type canvas_item;
render_mode unshaded, blend_disabled;
#include "res://shaders/draco_rift_shape.gdshaderinc"
// 登場のあいだ竜へ重ねる光（目の赤い光・胸の北極星）。画面の写しへ表示色で足し、HDRの画面へ描くときだけ最後にリニアへ直す。
uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
uniform bool linear_target = false;
uniform float strength = 0.0;
uniform int count = 0;
uniform vec4 blobs[4]; // 中心の UV.xy、半径の UV.xy
uniform vec4 tints[4]; // 色と強さ
uniform vec3 star_cross = vec3(0.0); // 十字の光：長さの半分（UV）、太さ（UV）、強さ
// 奥にいる間は裂け目の内側だけに出す。
uniform bool behind = false;
uniform vec2 rift_viewport = vec2(1280.0, 720.0);
uniform vec4 rift_ends = vec4(0.0);
uniform vec4 rift_shape = vec4(0.0);
float falloff(float r) {
	return r < 0.18 ? mix(1.0, 0.667, r / 0.18) : r < 0.5 ? mix(0.667, 0.149, (r - 0.18) / 0.32) : mix(0.149, 0.0, clamp((r - 0.5) / 0.5, 0.0, 1.0));
}
void fragment() {
	if (behind && !rift_interior(rift_cell(SCREEN_UV, rift_viewport), rift_ends, rift_shape)) { discard; }
	vec3 add = vec3(0.0);
	for (int i = 0; i < count; i++) {
		float r = length((UV - blobs[i].xy) / blobs[i].zw);
		if (r < 1.0) { add += tints[i].rgb * falloff(r) * tints[i].a; }
	}
	if (star_cross.z > 0.0) {
		vec2 d = abs(UV - 0.5);
		for (int k = 0; k < 2; k++) {
			float along = k == 0 ? d.x : d.y, across = k == 0 ? d.y : d.x;
			if (along < star_cross.x && across < star_cross.y * 0.5) {
				float t = 1.0 - along / star_cross.x;
				add += mix(vec3(0.745, 0.902, 1.0), vec3(1.0), t) * t * star_cross.z;
			}
		}
	}
	add *= strength;
	if (add.r + add.g + add.b <= 0.0005) { discard; }
	vec3 base = texture(screen, SCREEN_UV).rgb;
	vec3 shown = (linear_target ? pow(max(base, vec3(0.0)), vec3(1.0 / 2.2)) : base) + add;
	COLOR = vec4(linear_target ? pow(shown, vec3(2.2)) : shown, 1.0);
}
