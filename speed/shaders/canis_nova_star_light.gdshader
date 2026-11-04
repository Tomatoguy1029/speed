shader_type canvas_item;
render_mode unshaded, blend_add;

void fragment() {
	COLOR = vec4(vec3(1.0), COLOR.a);
}
