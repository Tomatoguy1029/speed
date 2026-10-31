// カジキの予兆専用。直線の芯と平行な薄い光を、画面高225の論理ピクセルで描く。
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float beam_length = 1.0;
uniform float path_length = 1.0;
uniform float path_offset = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float clock = 0.0;
uniform bool linear_output = false;

varying vec3 packets[11];

float hash01(float value) {
	return fract(sin(value * 127.1 + 311.7) * 43758.5453);
}

// 包みの位置・幅・明るさは頂点側で求め、同じ三角関数を全画素で繰り返さない。
void vertex() {
	float time = fract(clock / 4.0);
	for (int i = 0; i < 11; i++) {
		float key = seed * 3.17 + float(i) * 19.13;
		float phase = hash01(key + 1.0);
		float speed = hash01(key + 2.0) < 0.5 ? 1.0 : 2.0;
		float drift = 0.012 * sin(TAU * (time + hash01(key + 3.0)))
			+ 0.007 * sin(TAU * (time * 2.0 + hash01(key + 4.0)));
		float center = fract(phase + speed * time + drift);
		float width = mix(0.035, 0.102, hash01(key + 5.0))
			* (1.0 + 0.12 * sin(TAU * (time + hash01(key + 6.0))));
		float strength = mix(0.22, 0.67, hash01(key + 7.0))
			* (0.88 + 0.12 * sin(TAU * (time * 2.0 + hash01(key + 8.0))));
		packets[i] = vec3(center, width, strength);
	}
}

// 間隔・長さ・速度・明るさを別々に持つ光の包み。芯の方向は揺らさない。
float packet_flow(float along) {
	float sum = 0.0;
	for (int i = 0; i < 11; i++) {
		float distance = fract(along - packets[i].x + 0.5) - 0.5;
		sum += exp(-pow(distance / packets[i].y, 2.0)) * packets[i].z;
	}
	return 1.0 - exp(-sum * 0.9);
}

vec3 to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + vec3(0.055)) / 1.055, vec3(2.4)),
		step(vec3(0.04045), color));
}

void fragment() {
	float a = clamp(floor(UV.x * beam_length + 0.5), 0.0, beam_length);
	float b = floor((UV.y - 0.5) * 14.0 + 0.5);
	float envelope = smoothstep(0.0, 11.0, a) * smoothstep(0.0, 36.0, beam_length - a);
	float along = clamp((a + path_offset) / max(path_length, 0.001), 0.0, 1.0);
	float flow = packet_flow(along);
	float width = (0.63 + 0.23 * flow) * sqrt(envelope);
	float core = exp(-pow(b / (width + 0.02), 2.0)) * envelope;
	float middle = exp(-pow(b / 1.22, 2.0)) * envelope;
	float glow = exp(-pow(b / 2.25, 2.0)) * envelope;
	float offset = 2.2 * sqrt(envelope);
	float left = exp(-pow((b - offset) / 0.39, 2.0)) * envelope;
	float right = exp(-pow((b + offset) / 0.39, 2.0)) * envelope;
	vec3 light = glow * vec3(24.0, 3.0, 5.0) * (0.8 + 0.2 * flow)
		+ middle * vec3(115.0, 18.0, 20.0) * (0.88 + 0.12 * flow)
		+ core * vec3(173.0, 122.0, 85.0) * (0.9 + 0.1 * flow)
		+ left * vec3(72.0, 14.0, 18.0) * (0.75 + 0.25 * flow)
		+ right * vec3(55.0, 10.0, 15.0) * (0.78 + 0.22 * flow);
	light = clamp(light / 255.0 * (0.7 + 0.3 * charge), vec3(0.0), vec3(1.0));
	// 加算済みの光量をそのまま渡す。alphaで端の減衰を二重に掛けない。
	COLOR = vec4(linear_output ? to_linear(light) : light, 1.0);
}
