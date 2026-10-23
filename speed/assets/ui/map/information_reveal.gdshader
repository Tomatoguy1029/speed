shader_type canvas_item;
render_mode unshaded;

uniform float line_progress : hint_range(0.0, 1.0) = 0.0;
uniform float information_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float glow = 0.0;
uniform float spectrum_speed = 1.3;
uniform float spectrum_motion : hint_range(0.0, 1.0) = 0.85;
uniform float spectrum_correlation : hint_range(0.0, 1.0) = 0.72;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

// 元のピクセル線を、折れ線に沿った移動距離で現す。
float along_segment(vec2 p, vec2 a, vec2 b) {
	return clamp(dot(p - a, b - a) / dot(b - a, b - a), 0.0, 1.0);
}

float along_leader(vec2 p, vec2 a, vec2 b, vec2 c) {
	float ab = along_segment(p, a, b);
	float bc = along_segment(p, b, c);
	float first = length(b - a);
	float second = length(c - b);
	float distance_along = distance(p, mix(a, b, ab)) < distance(p, mix(b, c, bc))
		? ab * first : first + bc * second;
	return distance_along / (first + second);
}

float hash(float value) {
	return fract(sin(value * 127.1 + 311.7) * 43758.5453);
}

float pulse(float time) {
	float phase = fract(time);
	// 瞬発的なアタックと短い減衰。ゆっくりした往復補間を使わない。
	return min(phase / 0.025, 1.0) * exp(-phase * 5.5);
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 p = UV * vec2(640.0, 360.0);
	float position = -1.0;
	if (p.x >= 237.0 && p.y >= 105.0 && p.y < 204.0) {
		position = along_leader(p, vec2(237.5, 202.0), vec2(285.0, 106.5), vec2(385.0, 106.5));
	} else if (p.x <= 142.0 && p.y >= 270.0 && (p.x >= 110.0 || p.y >= 328.5)) {
		position = along_leader(p, vec2(141.5, 271.0), vec2(111.5, 330.0), vec2(27.0, 330.0));
	} else if (p.x >= 251.0 && p.y >= 270.0) {
		position = along_leader(p, vec2(252.0, 271.0), vec2(296.0, 317.0), vec2(378.0, 317.0));
	} else if (p.x >= 89.0 && p.x <= 130.0 && p.y >= 98.0 && p.y <= 115.0) {
		position = along_leader(p, vec2(128.5, 114.0), vec2(113.5, 99.0), vec2(89.5, 99.0));
	}
	if (p.x >= 32.0 && p.x < 96.0 && p.y >= 290.0 && p.y < 328.5) {
		float band = floor((p.x - 32.0) / 4.0);
		float time = TIME * spectrum_speed * 3.2;
		float beat = floor(time);
		// 無音に近い間と、大きな共通の反応を混ぜる。
		float hit = hash(beat + 31.0);
		float common = step(0.3, hit) * (0.45 + hit * 0.55) * pulse(time);
		float local_time = time * 1.7 + band * 0.19;
		float local = hash(band * 17.0 + floor(local_time)) * pulse(local_time);
		float band_gain = 0.45 + 0.55 * hash(band * 7.0 + beat);
		float moving = mix(local, common * band_gain, spectrum_correlation);
		float level = mix(hash(band + 41.0), moving, spectrum_motion);
		float height = floor(5.0 + level * 33.0);
		float bar = step(mod(floor(p.x) - 32.0, 4.0), 2.0) * step(328.0 - height, floor(p.y));
		art = vec4(0.35, 0.66, 0.72, bar);
	}
	float alpha = information_alpha;
	if (position >= 0.0) {
		alpha = line_progress > 0.0 ? step(position, line_progress) : 0.0;
	}
	COLOR = vec4(art.rgb * (1.0 + glow), art.a * alpha) * tint;
}
