shader_type canvas_item;
render_mode unshaded;

// 既存のカード画像の線と地色だけを置換し、輪郭・透過・アイコンを保つ。
uniform vec4 frame_color : source_color = vec4(0.372549, 0.803922, 0.894118, 1.0);
uniform vec4 background_color : source_color = vec4(0.121569, 0.196078, 0.239216, 1.0);
uniform bool fill_icon_background = false;
uniform vec4 source_frame : source_color = vec4(0.372549, 0.803922, 0.894118, 1.0);
uniform vec4 source_background : source_color = vec4(0.121569, 0.196078, 0.239216, 1.0);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (distance(pixel.rgb, source_frame.rgb) < 0.01) {
		pixel.rgb = frame_color.rgb;
	} else if (distance(pixel.rgb, source_background.rgb) < 0.01 || (fill_icon_background && length(pixel.rgb) < 0.01)) {
		pixel.rgb = background_color.rgb;
	}
	COLOR = pixel * tint;
}
