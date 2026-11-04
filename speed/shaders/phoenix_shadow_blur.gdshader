// 鳳凰の実画像の影を、画面画素で指定した半径のガウスぼかしへ変換する。
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D source_texture : filter_linear, repeat_disable;
uniform vec2 source_size;
uniform vec2 output_size;
uniform vec2 padding;
uniform vec2 direction;
uniform float sigma;

void fragment() {
	vec2 center = UV * output_size - padding;
	float sum = 0.0;
	float total = 0.0;
	int extent = int(ceil(sigma * 3.0));
	for (int i = -extent; i <= extent; i++) {
		float x = float(i);
		float weight = exp(-0.5 * x * x / max(sigma * sigma, 0.000001));
		vec2 point = center + direction * x;
		if (point.x >= 0.0 && point.y >= 0.0 && point.x < source_size.x && point.y < source_size.y) {
			sum += texture(source_texture, point / source_size).a * weight;
		}
		total += weight;
	}
	COLOR = vec4(26.0 / 255.0, 6.0 / 255.0, 8.0 / 255.0, sum / max(total, 0.000001));
}
