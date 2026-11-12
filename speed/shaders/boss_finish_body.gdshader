shader_type canvas_item;
render_mode unshaded;
// ボス撃破の演出で、ボスの色の層を描く。画面全体の四角に描き、撮った絵を世界座標で読む。
#include "res://shaders/boss_finish_body.gdshaderinc"

void fragment() {
	vec4 col;
	vec4 glow;
	body_sample(screen_world(SCREEN_UV * target_size), col, glow);
	if (col.a <= 0.0) discard;
	COLOR = vec4(linear_output ? to_linear(col.rgb) : col.rgb, col.a);
}
