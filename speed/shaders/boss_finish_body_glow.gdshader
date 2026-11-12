shader_type canvas_item;
render_mode unshaded, blend_add;
// ボス撃破の演出で、ボスの光の層を4分の1の大きさの光の絵へ足す。試作の縮小と同じく4点の平均で細い線を残す。
#include "res://shaders/boss_finish_body.gdshaderinc"
uniform float strength = 0.9;

void fragment() {
	vec3 sum = vec3(0.0);
	vec2 pixel = SCREEN_UV * target_size;
	for (int i = 0; i < 4; i++) {
		vec2 offset = vec2(float(i % 2), float(i / 2)) * 0.5 - 0.25;
		vec4 col;
		vec4 glow;
		body_sample(screen_world(pixel + offset), col, glow);
		sum += glow.rgb * glow.a;
	}
	COLOR = vec4(sum * 0.25 * strength, 1.0);
}
