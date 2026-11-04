// 元のmono_boost.jsと同じ論理画素上で発光を計算する。
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform vec2 field_size = vec2(192.0, 512.0);
vec3 sample_at(vec2 point) {
	vec4 pixel = texture(TEXTURE, clamp(point, vec2(0.001), vec2(0.999)));
	return pixel.rgb * pixel.a;
}
void fragment() {
	vec2 a = vec2(2.0) / field_size;
	vec3 near = sample_at(UV + vec2(a.x, 0.0)) + sample_at(UV - vec2(a.x, 0.0))
		+ sample_at(UV + vec2(0.0, a.y)) + sample_at(UV - vec2(0.0, a.y));
	vec3 far = sample_at(UV + a * 2.0) + sample_at(UV - a * 2.0)
		+ sample_at(UV + vec2(a.x, -a.y) * 2.0) + sample_at(UV + vec2(-a.x, a.y) * 2.0);
	COLOR = vec4((near * 0.17 + far * 0.08) * 0.16, 1.0);
}
