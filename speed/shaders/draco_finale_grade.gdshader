shader_type canvas_item;
render_mode unshaded;
// 試作の「色相と彩度を置き換える」合成。明るさを残したまま世界を一色へ沈める。
uniform sampler2D screen_image : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform bool linear_output = true;
uniform vec3 tint = vec3(0.137, 0.227, 0.549);

vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)); }
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }
float lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

void fragment() {
	vec3 base = texture(screen_image, SCREEN_UV).rgb;
	if (linear_output) { base = to_srgb(base); }
	vec3 shifted = clamp(tint + (lum(base) - lum(tint)), 0.0, 1.0);
	vec3 result = mix(base, shifted, amount);
	result = mix(result, vec3(0.02, 0.039, 0.133), amount * 0.34);
	if (linear_output) { result = to_linear(result); }
	COLOR = vec4(result, 1.0);
}
