// 色と輪郭が完成した画像だけをぼかし、鮮明な本体の後ろへ弱く加算する。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 field_size = vec2(220.0, 280.0);
uniform float radius = 7.0;
uniform float strength = 0.16;
void fragment() {
	vec2 a = vec2(radius) / field_size;
	vec2 offsets[8] = vec2[8](vec2(a.x, 0.0), vec2(-a.x, 0.0), vec2(0.0, a.y), vec2(0.0, -a.y),
		a * 2.0, -a * 2.0, vec2(a.x, -a.y) * 2.0, vec2(-a.x, a.y) * 2.0);
	vec3 near = vec3(0.0);
	vec3 far = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		vec4 c = texture(TEXTURE, clamp(UV + offsets[i], vec2(0.001), vec2(0.999)));
		if (i < 4) {
			near += c.rgb * c.a;
		} else {
			far += c.rgb * c.a;
		}
	}
	vec3 glow = near * 0.17 + far * 0.08;
	COLOR = vec4(glow, strength);
}
