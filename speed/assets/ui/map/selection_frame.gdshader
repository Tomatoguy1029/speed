shader_type canvas_item;
render_mode unshaded;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 artwork = texture(TEXTURE, UV);
	vec2 pixel = UV * vec2(640.0, 360.0);
	// 見本の星座を素材から除き、選択データ用の空の窓にする。
	if (pixel.x >= 421.0 && pixel.x < 594.0 && pixel.y >= 83.0 && pixel.y < 191.0) {
		artwork = vec4(0.012, 0.082, 0.114, 1.0);
	}
	COLOR = artwork * tint;
}
