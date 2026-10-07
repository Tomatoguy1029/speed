// 光のにじみ（簡易版。ブラウザの Compatibility 用）：光る物だけを描いた絵をぼかして足す。
shader_type canvas_item;
render_mode blend_add;

uniform float intensity = 0.9;
uniform float spread = 2.5;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * spread;
	vec4 sum = vec4(0.0);
	float wsum = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.0);
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * px) * w;
			wsum += w;
		}
	}
	vec4 c = sum / wsum;
	COLOR = vec4(c.rgb * intensity, c.a * intensity);
}
