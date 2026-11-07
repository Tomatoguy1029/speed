// 画面の写しをsRGBの8bitへ戻す。
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform bool linear_source = true;
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec3 rgb = linear_source ? mix(pixel.rgb * 12.92, 1.055 * pow(max(pixel.rgb, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), pixel.rgb)) : pixel.rgb;
	COLOR = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
