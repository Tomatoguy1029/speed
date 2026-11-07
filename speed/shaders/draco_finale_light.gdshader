shader_type canvas_item;
render_mode unshaded, blend_disabled;
// 承認済みの試作と同じ足し算になるよう、画面をsRGBへ戻して光を足し、元の色空間へ返す。
uniform sampler2D screen_image : hint_screen_texture, filter_linear;
uniform sampler2D fx_near : filter_nearest;
uniform sampler2D fx_soft : filter_linear;
uniform sampler2D wide_glow : filter_linear;
uniform sampler2D far_glow : filter_linear;
uniform sampler2D fine_light : filter_linear;
uniform bool smooth_fx = false;
uniform bool linear_output = true;
uniform float glow_strength = 1.0;

vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)); }
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }

void fragment() {
	vec3 base = texture(screen_image, SCREEN_UV).rgb;
	if (linear_output) { base = to_srgb(base); }
	vec3 light = texture(far_glow, SCREEN_UV).rgb * 0.9 + texture(wide_glow, SCREEN_UV).rgb * 0.8;
	light *= glow_strength;
	light += smooth_fx ? texture(fx_soft, SCREEN_UV).rgb : texture(fx_near, SCREEN_UV).rgb;
	light += texture(fine_light, SCREEN_UV).rgb;
	vec3 result = clamp(base + light, 0.0, 1.0);
	if (linear_output) { result = to_linear(result); }
	COLOR = vec4(result, 1.0);
}
