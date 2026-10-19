shader_type canvas_item;
render_mode unshaded;
uniform bool highlighted = false;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	COLOR = vec4(highlighted ? vec3(0.357, 0.784, 0.859) : pixel.rgb, pixel.a) * tint;
}
