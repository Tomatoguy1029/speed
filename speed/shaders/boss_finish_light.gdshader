shader_type canvas_item;
render_mode unshaded, blend_disabled;
// 試作の最後の合成：画面を暗く掛けてから、4分の1の光の絵と、それを6ドットぼかした光を足す。
uniform sampler2D screen_image : hint_screen_texture, filter_nearest;
uniform sampler2D glow : filter_linear, repeat_disable;
uniform bool linear_output = false;
uniform vec3 dim = vec3(1.0);
// 試作の960×540の画面で6ドット。
uniform vec2 blur_radius = vec2(0.00625, 0.0111);

vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)); }
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }

void fragment() {
	vec3 base = texture(screen_image, SCREEN_UV).rgb;
	if (linear_output) base = to_srgb(base);
	vec3 soft = vec3(0.0);
	float total = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			float w = exp(-0.5 * float(x * x + y * y));
			soft += texture(glow, SCREEN_UV + vec2(float(x), float(y)) * blur_radius).rgb * w;
			total += w;
		}
	}
	vec3 result = clamp(base * dim + texture(glow, SCREEN_UV).rgb + soft / total * 0.55, 0.0, 1.0);
	COLOR = vec4(linear_output ? to_linear(result) : result, 1.0);
}
