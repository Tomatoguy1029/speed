shader_type canvas_item;
render_mode unshaded;

// 元画像の内部の水色だけを置換し、枠・目盛り・白い針の色と透過を保つ。
uniform vec4 source_fill : source_color = vec4(0.37254902, 0.80392157, 0.89411765, 1.0);
uniform vec4 fill_color : source_color = vec4(0.37254902, 0.80392157, 0.89411765, 1.0);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float fill = 1.0 - step(0.005, distance(pixel.rgb, source_fill.rgb));
	COLOR = vec4(mix(pixel.rgb, fill_color.rgb, fill), pixel.a) * tint;
}
