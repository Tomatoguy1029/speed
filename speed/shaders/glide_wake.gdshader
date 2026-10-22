shader_type canvas_item;
render_mode unshaded, blend_add;

// TIME を使わず、ゲームが進めた時計で流す（ポーズ中も静止する）。
uniform float flow_time = 0.0;
uniform bool sonic = false;
uniform vec4 warm_color : source_color = vec4(1.0, 0.48, 0.18, 1.0);
uniform vec4 cool_color : source_color = vec4(0.25, 0.65, 1.0, 1.0);
uniform float filament_strength : hint_range(0.0, 2.0) = 0.7;
uniform sampler2D noise_tex : repeat_enable, filter_linear;

void fragment() {
	vec4 vertex = COLOR;
	vec3 tint = sonic ? cool_color.rgb : warm_color.rgb;
	float across = UV.y * 2.0 - 1.0;
	float along = vertex.b > 0.5 ? 1.0 - UV.x : UV.x;
	float flow = texture(noise_tex, vec2(along * 0.8 - flow_time * 1.6, UV.y * 0.8)).g;
	float fine = texture(noise_tex, vec2(along * 1.6 - flow_time * 2.5, UV.y * 2.3)).b;
	float alpha;
	float core;
	if (vertex.b > 0.5) {
		// 機首の外周から両舷を回り込み、後ろへほどける流線。
		float x = UV.x * 2.0 - 1.0;
		float rim = sqrt(max(0.0, 1.0 - pow(max(x, 0.0), 2.0))) * 0.72;
		float edge = abs(abs(across) - rim + (flow - 0.5) * 0.07);
		float shell = exp(-edge * edge * 220.0);
		float ends = smoothstep(0.0, 0.25, UV.x) * (1.0 - smoothstep(0.85, 1.0, UV.x));
		alpha = shell * ends * (0.12 + 0.22 * fine);
		core = shell * 0.3;
	} else {
		// 長手方向へ引き伸ばしたノイズを流し、尾の先と両端を柔らかく消す。
		float envelope = (1.0 - smoothstep(0.15, 1.0, UV.x)) * (1.0 - smoothstep(0.45, 1.0, abs(across)));
		float offset = (flow - 0.5) * 0.25;
		core = exp(-pow((across + offset) * 6.0, 2.0));
		float strands = pow(fine, 3.0) * filament_strength;
		alpha = envelope * (0.12 + strands * 0.5 + core * 0.28);
	}
	COLOR = vec4(mix(tint, vec3(1.0), core * 0.35), alpha * vertex.a);
}
