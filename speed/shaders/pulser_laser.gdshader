// 集積輪と飛翔輪は同じ断面。84本の光筋は頂点側で動かす。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float radius = 28.8;
uniform float pixel = 1.25;
// 0..1 は溜め、負なら完成した波。
uniform float progress = -1.0;
uniform float seed = 0.0;
uniform bool linear_output = false;
varying vec2 at;
varying vec4 segment;
varying float kind;
varying float strength;

float hash01(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}
float arrival(float slot) {
	// 最後の隙間はprogress=1で埋まる。到着順は個体ごとに置換する。
	float order = mod(slot * 37.0 + mod(seed, 84.0), 84.0);
	return 0.2 + 1.2 * pow(order / 83.0, 0.6);
}
vec2 path(float angle, float distance, float curve, float phase) {
	float u = clamp(phase, 0.0, 1.0);
	float r = radius + distance * pixel * (1.0 - pow(u, 2.25));
	float a = angle + curve * pow(1.0 - u, 1.25);
	return vec2(cos(a), sin(a)) * r;
}
void vertex() {
	vec2 corner = VERTEX.xy;
	strength = 1.0;
	kind = 0.0;
	segment = vec4(0.0);
	if (INSTANCE_ID == 0) {
		VERTEX.xy = corner * (radius + 7.0 * pixel) * 2.0;
	} else {
		float slot = float(INSTANCE_ID - 1);
		float key = slot * 19.13 + seed * 3.17;
		float end = arrival(slot);
		float duration = min(end + 0.015, mix(0.24, 0.49, hash01(key)));
		float elapsed = max(progress, 0.0) * 1.4;
		float phase = (elapsed - end + duration) / duration;
		float angle = slot * TAU / 84.0;
		vec2 head;
		vec2 tail;
		kind = 1.0;
		if (progress < 0.0 || phase < 0.0 || elapsed - end > 0.085) {
			strength = 0.0;
			head = vec2(0.0);
			tail = head;
		} else if (phase < 1.0) {
			float distance = mix(32.0, 68.0, hash01(key + 1.0));
			float curve = mix(-0.27, 0.27, hash01(key + 2.0));
			float tail_time = mix(0.018, 0.034, hash01(key + 3.0));
			head = path(angle, distance, curve, phase);
			tail = path(angle, distance, curve, phase - tail_time / duration);
			strength = smoothstep(0.0, 0.12, phase) * mix(0.72, 1.0, hash01(key + 4.0));
		} else {
			// 到着点だけ白熱し、別の集積輪へ光を残す。
			head = vec2(cos(angle), sin(angle)) * radius;
			tail = head;
			kind = 2.0;
			strength = 1.0 - (elapsed - end) / 0.085;
		}
		segment = vec4(head, tail);
		vec2 lo = min(head, tail) - vec2(3.0 * pixel);
		vec2 hi = max(head, tail) + vec2(3.0 * pixel);
		VERTEX.xy = mix(lo, hi, corner + vec2(0.5));
	}
	at = VERTEX.xy;
}
vec3 to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + vec3(0.055)) / 1.055, vec3(2.4)),
		step(vec3(0.04045), color));
}
void fragment() {
	vec2 p = floor(at / pixel + vec2(0.5)) * pixel;
	vec3 light = vec3(0.0);
	if (kind < 0.5) {
		float distance = abs(length(p) - radius) / pixel;
		float deposited = 1.0;
		if (progress >= 0.0 && progress < 1.0) {
			float angle = mod(atan(p.y, p.x) + TAU, TAU);
			float slot = mod(floor(angle * 84.0 / TAU + 0.5), 84.0);
			deposited = step(arrival(slot), progress * 1.4) * (0.7 + 0.3 * progress);
		}
		float core = 1.0 - smoothstep(0.3, 0.8, distance);
		float beam = 1.0 - smoothstep(1.0, 1.7, distance);
		float edge = 1.0 - smoothstep(2.0, 2.6, distance);
		float glow = exp(-distance * 1.05) * 0.18;
		light = (vec3(0.24, 0.001, 0.012) * edge + vec3(0.76, 0.046, 0.13) * beam
			+ vec3(0.0, 0.90, 0.88) * core + vec3(1.0, 0.006, 0.028) * glow) * deposited;
	} else if (strength > 0.0) {
		vec2 line = segment.zw - segment.xy;
		float along = clamp(dot(p - segment.xy, line) / max(dot(line, line), 0.001), 0.0, 1.0);
		float distance = length(p - segment.xy - line * along) / pixel;
		float head = length(p - segment.xy) / pixel;
		float body = (1.0 - smoothstep(0.35, 1.05, distance)) * (1.0 - along * 0.85);
		float hot = 1.0 - smoothstep(0.35, kind > 1.5 ? 1.25 : 0.95, head);
		light = (vec3(1.0, 0.025, 0.09) * body + vec3(0.0, 0.94, 0.91) * hot
			+ vec3(0.24, 0.002, 0.015) * exp(-distance * 1.4) * (1.0 - along)) * strength;
	}
	light = clamp(light, vec3(0.0), vec3(1.0));
	COLOR = vec4(linear_output ? to_linear(light) : light, 1.0);
}
