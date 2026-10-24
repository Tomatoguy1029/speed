shader_type canvas_item;
render_mode unshaded;

uniform float elapsed = 0.0;
uniform float reveal = 0.0;
uniform vec4 ember_color : source_color = vec4(0.95, 0.055, 0.035, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float cloud(vec2 p) {
	float value = 0.0;
	float weight = 0.55;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * weight;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + 3.7;
		weight *= 0.5;
	}
	return value;
}

void fragment() {
	// 背景のノイズもゲームのピクセルの粗さにそろえる。
	vec2 sample_uv = (floor(UV * 144.0) + 0.5) / 144.0;
	vec2 p = (sample_uv - 0.5) * 2.0;
	vec2 flow = vec2(elapsed * 0.13, -elapsed * 0.085);
	vec2 warp = vec2(cloud(p * 2.6 + flow), cloud(p * 2.6 - flow + 9.1)) - 0.5;
	vec2 q = p + warp * 0.35;
	float curl = cloud(q * 3.0 + flow);
	float smoke = cloud(q * 5.0 + vec2(curl, -curl) - flow * 0.7);
	float radius = length(q * vec2(0.93, 1.08));
	float boundary = 0.50 + curl * 0.30 + smoke * 0.14;
	float field = boundary - radius;
	float density = smoothstep(-0.12, 0.24, field);
	float edge = exp(-pow((field - 0.015) * 11.0, 2.0));
	float pulse = 0.72 + 0.28 * sin(elapsed * 2.5 + curl * 7.0);
	// 分岐する赤い筋と外へほつれる流れ。均一な円の輪郭は保たない。
	float branch_noise = cloud(q * 6.0 + warp * 1.2 + flow * 1.4);
	float veins = 1.0 - smoothstep(0.018, 0.075, abs(branch_noise - 0.50));
	float breaks = smoothstep(0.30, 0.65, cloud(q * 3.5 - flow));
	float tendril = veins * smoothstep(0.45, 0.65, radius) * (1.0 - smoothstep(0.65, 1.08, radius));
	float ember = (edge * (0.18 + veins * 0.72) * breaks + density * veins * 0.36 + tendril * 0.36) * pulse;
	vec3 black_smoke = vec3(0.009, 0.0006, 0.0002);
	vec3 color = mix(black_smoke, ember_color.rgb, clamp(ember, 0.0, 1.0));
	float alpha = reveal * clamp(density * 0.78 + edge * breaks * 0.22 + tendril * 0.40, 0.0, 0.94);
	COLOR = vec4(color, alpha);
}
