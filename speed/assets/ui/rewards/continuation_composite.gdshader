// 継続演出の層（色はsRGB・alpha乗算済み）を、画面とsRGB上で重ねてから描画先の色空間へ戻す。
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D under : hint_screen_texture, filter_nearest, repeat_disable;
// source_colorを付けず、層のsRGBのバイト値をそのまま読む
uniform sampler2D layer_pixels : filter_nearest, repeat_disable;
uniform bool linear_target = true;
vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow(max((c + 0.055) / 1.055, vec3(0.0)), vec3(2.4)), step(vec3(0.04045), c));
}
void fragment() {
	vec4 below = texture(under, SCREEN_UV);
	vec4 layer = texture(layer_pixels, UV);
	vec3 base = linear_target ? to_srgb(below.rgb) : below.rgb;
	vec3 rgb = clamp(layer.rgb + clamp(base, 0.0, 1.0) * (1.0 - layer.a), 0.0, 1.0);
	COLOR = vec4(linear_target ? to_linear(rgb) : rgb, 1.0);
}
