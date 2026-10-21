shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	vec2 pixel = UV * vec2(640.0, 360.0);
	if (max(ink.r, max(ink.g, ink.b)) < 0.01 ||
		(pixel.x >= 8.0 && pixel.x < 100.0 && pixel.y > 40.0 && pixel.y < 65.0)) {
		ink.a = 0.0;
	}
	COLOR = ink;
}
