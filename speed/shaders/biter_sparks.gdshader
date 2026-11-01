shader_type canvas_item;
render_mode unshaded;
varying float phase;
void vertex() { phase = COLOR.r; }
void fragment() {
	// 口先を原点とする、長短と向きの異なる6本。四角形1枚で描く。
	vec2 p = floor((UV * 64.0 - vec2(20.0, 32.0)) * 2.0 + 0.5) * 0.5;
	float angles[6] = float[6](-0.05, -0.42, -0.92, 0.37, 0.78, 1.12);
	float lengths[6] = float[6](25.0, 17.0, 12.0, 14.0, 10.0, 8.0);
	float powers[6] = float[6](1.0, 0.76, 0.68, 0.55, 0.60, 0.53);
	float widths[6] = float[6](1.9, 1.5, 1.2, 1.4, 1.1, 0.9);
	float glow = 0.0;
	float light = 0.0;
	float core = 0.0;
	float stretch = smoothstep(0.0, 0.22, phase);
	for (int j = 0; j < 6; j++) {
		vec2 axis = vec2(cos(angles[j]), sin(angles[j]));
		float along = dot(p, axis);
		float across = abs(dot(p, vec2(-axis.y, axis.x)));
		float tip = lengths[j] * (0.18 + 0.82 * stretch);
		float tail = lengths[j] * pow(phase, 1.4) * 0.86;
		float segment = step(tail, along) * (1.0 - step(tip, along));
		float taper = max(0.08, 1.0 - along / max(tip, 0.01));
		float width = widths[j] * taper;
		float strength = segment * powers[j] * pow(1.0 - phase, 0.55);
		glow = max(glow, exp(-across * across / max(width * width * 5.0, 0.01)) * strength * 0.45);
		light = max(light, (1.0 - smoothstep(width * 0.45, width * 1.2, across)) * strength);
		core = max(core, (1.0 - smoothstep(width * 0.10, width * 0.40, across)) * strength * (1.0 - phase));
	}
	vec3 orange = mix(vec3(1.0, 0.62, 0.16), vec3(1.0, 0.29, 0.035), phase);
	vec3 rgb = mix(orange, vec3(1.0, 0.88, 0.44), light);
	rgb = mix(rgb, vec3(1.0, 0.985, 0.91), core);
	COLOR = vec4(rgb, min(1.0, max(glow, max(light, core))));
}
