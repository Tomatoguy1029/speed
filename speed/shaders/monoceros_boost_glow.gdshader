// 元のmono_boost.jsと同じ論理画素上で発光を計算する。
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform vec2 field_size = vec2(192.0, 512.0);
void fragment() {
	vec2 a = vec2(2.0) / field_size;
	vec2 offsets[8] = vec2[8](vec2(a.x, 0.0), vec2(-a.x, 0.0), vec2(0.0, a.y), vec2(0.0, -a.y),
		a * 2.0, -a * 2.0, vec2(a.x, -a.y) * 2.0, vec2(-a.x, a.y) * 2.0);
	vec3 near = vec3(0.0);
	vec3 far = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		vec4 pixel = texture(TEXTURE, clamp(UV + offsets[i], vec2(0.001), vec2(0.999)));
		if (i < 4) near += pixel.rgb * pixel.a;
		else far += pixel.rgb * pixel.a;
	}
	COLOR = vec4((near * 0.17 + far * 0.08) * 0.16, 1.0);
}
