shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float luminance = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR.rgb = mix(vec3(luminance), COLOR.rgb, 0.8);
}
