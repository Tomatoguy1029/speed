// 粒子をRGBの独立した密度場へ加算する。ここでは粒子そのものを表示しない。
shader_type canvas_item;
render_mode unshaded, blend_add;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float density = exp(-dot(p, p) * 3.2) * (1.0 - smoothstep(0.72, 1.0, length(p)));
	COLOR = vec4(COLOR.rgb, COLOR.a * density);
}
