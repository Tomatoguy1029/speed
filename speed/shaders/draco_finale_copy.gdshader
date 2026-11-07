shader_type canvas_item;
render_mode unshaded, blend_disabled;
// 光の絵の色をそのまま縮小先へ写す。透明度で暗くしない。
void fragment() {
	COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0);
}
