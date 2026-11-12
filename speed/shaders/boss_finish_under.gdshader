shader_type canvas_item;
render_mode unshaded, blend_disabled;
// 試作で画面へ直接足していた光（粒・後光・金の粉）を、sRGBで足してから元の色空間へ戻す。
uniform sampler2D screen_image : hint_screen_texture, filter_nearest;
uniform sampler2D fine_light : filter_nearest;
uniform bool linear_output = false;

vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)); }
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }

void fragment() {
	vec3 base = texture(screen_image, SCREEN_UV).rgb;
	if (linear_output) base = to_srgb(base);
	vec3 result = clamp(base + texture(fine_light, SCREEN_UV).rgb, 0.0, 1.0);
	COLOR = vec4(linear_output ? to_linear(result) : result, 1.0);
}
