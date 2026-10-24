shader_type canvas_item;
render_mode unshaded;

uniform float line_progress : hint_range(0.0, 1.0) = 0.0;
uniform float information_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float glow = 0.0;
uniform float spectrum_speed = 0.15;
uniform float spectrum_base_height : hint_range(0.0, 1.0) = 0.45;
uniform float spectrum_motion : hint_range(0.0, 1.0) = 0.85;
uniform float spectrum_correlation : hint_range(0.0, 1.0) = 0.18;
uniform float spectrum_peak_frequency = 0.08;
uniform float spectrum_peak_strength : hint_range(0.0, 1.0) = 0.95;
uniform float orbit_speed = 0.025;
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

float activity(float seed, float time) {
	return mix(hash(seed + floor(time)), hash(seed + floor(time) + 1.0), smoothstep(0.0, 1.0, fract(time)));
}

float envelope(float age, float decay) {
	return age < 0.0 ? 0.0 : min(age / 0.025, 1.0) * exp(-age * decay);
}

float response(float seed, float time, float rate) {
	float clock = time * rate + hash(seed + 73.0) * 16.0;
	float event = floor(clock);
	float onset = 0.03 + hash(seed + event * 31.0) * 0.12;
	float age = fract(clock) - onset;
	float hold = 0.15 + hash(seed * 11.0 + event * 7.0) * 0.2;
	float release = 0.28 + hash(seed * 13.0 + event * 3.0) * 0.16;
	// 速度はアタック・保持・減衰・休止を一緒に伸縮させる。
	float shape = age < 0.0 ? 0.0 : (age < 0.025 ? age / 0.025
		: (age < 0.025 + hold ? 1.0 : exp(-(age - 0.025 - hold) / release * 2.3)));
	float quiet = 0.15 + hash(seed * 23.0 + event * 19.0) * 0.3;
	float peak = 0.6 + hash(seed * 17.0 + event * 13.0) * 0.4;
	return mix(quiet, peak, shape);
}

float orbit_glint(vec2 p, vec2 center, float radius, float angle) {
	vec2 offset = p - center;
	float difference = atan(sin(atan(offset.y, offset.x) - angle), cos(atan(offset.y, offset.x) - angle));
	return (1.0 - smoothstep(0.025, 0.11, abs(difference))) * (1.0 - smoothstep(0.6, 1.2, abs(length(offset) - radius)));
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
		float time = TIME * spectrum_speed;
		float group = floor(band / 4.0);
		// 全体の活動量、帯域、個々のアタックを別の時間スケールで変える。
		// 緩やかな補間は振幅の包絡だけに使い、棒の立ち上がりは短く保つ。
		float overall = activity(181.0, TIME * 0.11);
		float band_energy = activity(29.0 + group * 47.0, TIME * 0.23);
		float local_energy = activity(91.0 + band * 17.0, TIME * 0.7);
		float local = response(band + 7.0, time, 0.5 + hash(band + 3.0) * 0.8);
		float grouped = response(group + 87.0, time, 0.32 + hash(group) * 0.25);
		float moving = mix(local * (0.7 + local_energy * 0.3), grouped, spectrum_correlation)
			* mix(0.7, 1.25, band_energy) * mix(0.85, 1.2, overall);
		// 全体ピークは独立した低頻度のアクセント。帯域の同期度とは分ける。
		float peak_clock = TIME * spectrum_peak_frequency;
		float peak_event = floor(peak_clock);
		float peak_onset = 0.1 + hash(peak_event + 163.0) * 0.7;
		float peak_age = (fract(peak_clock) - peak_onset) / max(spectrum_peak_frequency, 0.0001);
		float peak = spectrum_peak_frequency > 0.0 ? envelope(peak_age, 3.8) : 0.0;
		float normal = spectrum_base_height + (moving - 0.5) * spectrum_motion;
		float accent = peak * spectrum_peak_strength * (0.65 + 0.35 * hash(band + peak_event * 31.0));
		float level = clamp(max(normal, accent), 0.0, 1.0);
		float height = floor(2.0 + level * 36.0);
		float bar = step(mod(floor(p.x) - 32.0, 4.0), 2.0) * step(328.0 - height, floor(p.y));
		art = vec4(0.35, 0.66, 0.72, bar);
	}
	if (p.x >= 28.0 && p.x < 90.0 && p.y >= 65.0 && p.y < 129.0) {
		// 原画の偏心した三つの軌道と中心を保つ。軌道上の光だけが少し巡る。
		float clock = TIME * orbit_speed;
		float glint = orbit_glint(p, vec2(59.75, 97.75), 15.75, clock + 0.7);
		glint = max(glint, orbit_glint(p, vec2(62.25, 95.25), 21.25, clock * 0.63 + 3.1));
		glint = max(glint, orbit_glint(p, vec2(59.5, 96.75), 30.75, clock * 0.35 + 4.8));
		art.rgb = mix(art.rgb, vec3(0.72, 0.86, 0.88), glint * art.a);
	}
	float alpha = information_alpha;
	if (position >= 0.0) {
		alpha = line_progress > 0.0 ? step(position, line_progress) : 0.0;
	}
	COLOR = vec4(art.rgb * (1.0 + glow), art.a * alpha) * tint;
}
