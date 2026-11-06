shader_type canvas_item;
render_mode unshaded;
// 試作の「色相と彩度を置き換える」合成。明るさを残したまま世界を一色へ沈める。
uniform sampler2D screen_image : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform vec3 tint = vec3(0.137, 0.227, 0.549);

float lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

void fragment() {
	vec3 base = texture(screen_image, SCREEN_UV).rgb;
	vec3 shifted = clamp(tint + (lum(base) - lum(tint)), 0.0, 1.0);
	vec3 result = mix(base, shifted, amount);
	COLOR = vec4(mix(result, vec3(0.02, 0.039, 0.133), amount * 0.34), 1.0);
}
