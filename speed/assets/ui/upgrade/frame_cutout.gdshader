shader_type canvas_item;
render_mode unshaded;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec2 at = UV * vec2(640.0, 360.0);
	if (at.x >= 428.0 && at.x < 609.0 && at.y >= 69.0 && at.y < 327.0) {
		pixel = vec4(0.0);
	}
	COLOR = pixel * tint;
}
