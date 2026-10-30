shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float world_time = 0.0;
void fragment() {
	vec2 p = UV;
	float y = (p.y - 0.5) * 2.0;
	float flow = p.x * 12.0 - world_time * 8.0;
	float sway = sin(flow * 1.7) * 0.14 + sin(flow * 0.73 + 2.0) * 0.08;
	float size = 0.50 + 0.17 * sin(flow) + 0.13 * p.x;
	float flame = (1.0 - smoothstep(0.05, size, abs(y - sway)));
	float core = 1.0 - smoothstep(0.12, 0.16, abs(y));
	vec3 col = mix(vec3(0.32, 0.67, 1.0), vec3(0.81, 0.94, 1.0), flame);
	col = mix(col, vec3(1.0), core);
	COLOR = vec4(col * COLOR.rgb, max(core, flame * 0.8) * COLOR.a);
}
