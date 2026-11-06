// ふたご座の機体1つ分の絵。MultiMesh の1つずつが、機体の絵のまわりへ PAD セル広げた四角を描く。
// INSTANCE_CUSTOM：x は種類（0 光のオーラ、1 影の機体、2 光の残光、3 影の残像、4 溶けて崩れる影、5 光の機体）、
// y は濃さか進み（0〜1）、z は全体の不透明度、w は形の乱れの種。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/hero_gemini.gdshaderinc"

varying flat vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 cell = floor(UV * (SHIP + 2.0 * PAD)) - PAD;
	int kind = int(v_custom.x + 0.5);
	float k = v_custom.y;
	float seed = v_custom.w;
	vec4 c = vec4(0.0);
	if (kind == 0) {
		c = light_aura(cell, seed, k);
	} else if (kind == 5) {
		c = light_body(cell, seed);
	} else if (kind == 1 || kind == 4) {
		float crumble = kind == 4 ? k : 0.0;
		c = shadow_body(cell, seed, crumble);
		if (c.a <= 0.0) c = shadow_aura(cell, seed, kind == 4 ? 1.0 - k : k);
	} else if (kind == 2) {
		// 鮮明な残光：形はくずさず、金に光って薄れる
		if (ship_at(cell).a >= 0.5) {
			bool rim = ship_dist(cell + vec2(1.0, 0.0)) > 0.0 || ship_dist(cell - vec2(1.0, 0.0)) > 0.0 || ship_dist(cell + vec2(0.0, 1.0)) > 0.0 || ship_dist(cell - vec2(0.0, 1.0)) > 0.0;
			float a = (1.0 - k) * (1.0 - k) * (rim ? 0.95 : 0.55);
			c = vec4(rim ? LIGHT_CORE : LIGHT_MID, dither(a, cell));
		}
	} else if (kind == 3) {
		// 崩れながら薄れる暗い残像：古いほど輪郭がうねり、穴があく
		vec2 w = shadow_wobble(cell, seed, 1.5 + 4.0 * k);
		if (ship_at(w).a >= 0.5) {
			float n = vnoise(vec3(cell * 0.25, seed * 2.0 + k * 3.0));
			if (n > k * 1.1) {
				float a = (1.0 - k) * 0.75;
				c = vec4(n < k * 1.1 + 0.07 ? SHADOW_RIM : mix(SHADOW_BODY, SHADOW_DEEP, k), dither(a, cell));
			}
		}
	}
	c.a *= v_custom.z;
	if (c.a <= 0.001) discard;
	COLOR = finish(c);
}
