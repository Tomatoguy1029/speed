// 色と輪郭が完成した画像だけをぼかし、鮮明な本体の後ろへ弱く加算する。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 field_size = vec2(220.0, 280.0);
uniform float radius = 7.0;
uniform float strength = 0.16;
vec3 light_at(sampler2D field, vec2 uv) {
	vec4 c = texture(field, clamp(uv, vec2(0.001), vec2(0.999)));
	return c.rgb * c.a;
}
void fragment() {
	vec2 a = vec2(radius) / field_size;
	vec3 near = light_at(TEXTURE, UV + vec2(a.x, 0.0)) + light_at(TEXTURE, UV - vec2(a.x, 0.0))
		+ light_at(TEXTURE, UV + vec2(0.0, a.y)) + light_at(TEXTURE, UV - vec2(0.0, a.y));
	vec3 far = light_at(TEXTURE, UV + a * 2.0) + light_at(TEXTURE, UV - a * 2.0)
		+ light_at(TEXTURE, UV + vec2(a.x, -a.y) * 2.0) + light_at(TEXTURE, UV + vec2(-a.x, a.y) * 2.0);
	vec3 glow = near * 0.17 + far * 0.08;
	COLOR = vec4(glow, strength);
}
