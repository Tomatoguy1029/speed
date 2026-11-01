shader_type canvas_item;
render_mode unshaded;

// 装備枠画像の水色の線だけを塗り替え、元の輪郭と透過を保つ。
uniform vec4 outline_color : source_color = vec4(0.372549, 0.803922, 0.894118, 1.0);
uniform vec4 frame_color : source_color;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float outline = 1.0 - step(0.01, distance(pixel.rgb, outline_color.rgb));
	COLOR = vec4(frame_color.rgb, pixel.a * outline * frame_color.a) * tint;
}
