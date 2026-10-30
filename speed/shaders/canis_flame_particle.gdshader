shader_type canvas_item;
render_mode unshaded, blend_add;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = pow(max(0.0, 1.0 - d), 1.4);
	vec3 col = mix(vec3(0.25, 0.55, 1.0), vec3(0.81, 0.94, 1.0), (1.0 - smoothstep(0.15, 1.0, d)));
	col = mix(col, vec3(1.0), 1.0 - smoothstep(0.0, 0.22, d));
	COLOR = vec4(col, a * COLOR.a);
}
