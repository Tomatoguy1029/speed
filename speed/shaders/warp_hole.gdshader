// ワープホール。1枚の四角形に金色トンネル・吸い込まれる星・縁の四芒星を描く。
// 四角形の幅は穴の直径の extent 倍。cells は四角形の幅のドット数で、ドットに揃えて色を段階化する。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/warp_tunnel.gdshaderinc"

uniform float time = 0.0;
// 開き具合（0〜1）。開くとき・消える前に縮む。
uniform float size = 1.0;
// 消える前の点滅（0.6〜1）
uniform float blink = 1.0;
uniform float extent = 1.35;
uniform float cells = 96.0;
uniform float levels = 10.0;

// 吸い込まれる星。らせんにほどいた角度を区切り、区画ごとに1粒を奥へ流す。縁では速く、奥ではゆっくり小さくなる。
vec3 inflow(vec2 p, float dot_size) {
	float rr = length(p);
	if (rr < 0.04 || rr > 1.3) {
		return vec3(0.0);
	}
	float z = 1.0 / rr;
	float b = mod(atan(p.y, p.x) - z * 0.25 + time * 0.3, TAU);
	vec3 sum = vec3(0.0);
	for (int layer = 0; layer < 3; layer++) {
		float sectors = 30.0;
		float shift = float(layer) * 0.37;
		float s = floor(b / TAU * sectors + shift);
		float h1 = wt_hash3(vec3(s, float(layer), 1.0));
		float h2 = wt_hash3(vec3(s, float(layer), 2.0));
		float h3 = wt_hash3(vec3(s, float(layer), 3.0));
		float angle = (s - shift + 0.2 + 0.6 * h1) / sectors * TAU;
		float phase = fract(h2 + time * (0.25 + 0.2 * h3));
		float zz = 0.8 + phase * 9.0;
		float head = 1.0 / zz;
		float tail = 1.0 / max(zz - 0.9, 0.5);
		if (rr < head || rr > tail) {
			continue;
		}
		float q = (rr - head) / max(tail - head, 0.0001);
		float across = abs(b - angle) * rr;
		if (across > dot_size * 0.6) {
			continue;
		}
		float bright = min(1.0, (1.0 - phase) * 1.5) * min(1.0, phase * 8.0) * pow(1.0 - q, 1.5);
		vec3 tone = h3 < 0.4 ? WT_CORE : (h3 < 0.8 ? WT_GOLD : WT_WALL1);
		sum += tone * bright;
	}
	return sum;
}

// 縁のまわりにときどき光る金色の四芒星。
vec3 sparkle(vec2 p, float dot_size, float open) {
	vec3 sum = vec3(0.0);
	float step_t = floor(time * 1.5);
	float amp = sin(fract(time * 1.5) * PI) * blink * open;
	float reach = floor(1.0 + amp * 3.0);
	for (int k = 0; k < 5; k++) {
		float seed = step_t * 7.0 + float(k) * 13.0;
		float ang = wt_hash3(vec3(seed, 4.0, 0.0)) * TAU;
		float dist = mix(0.95, 1.25, wt_hash3(vec3(seed, 5.0, 0.0)));
		vec2 d = (p - vec2(cos(ang), sin(ang)) * dist) / dot_size;
		d = floor(d + 0.5);
		float w = 0.0;
		if (abs(d.y) < 0.5 && abs(d.x) <= reach) {
			w = 1.0 - abs(d.x) / (reach + 1.0);
		} else if (abs(d.x) < 0.5 && abs(d.y) <= reach) {
			w = 1.0 - abs(d.y) / (reach + 1.0);
		}
		sum += WT_GOLD * w * amp * 1.3;
	}
	return sum;
}

void fragment() {
	vec2 uv = (floor(UV * cells) + 0.5) / cells;
	float open = max(size, 0.001);
	vec2 p = (uv * 2.0 - 1.0) * extent / open;
	float dot_size = 2.0 * extent / cells / open;
	vec4 tunnel = warp_tunnel(p, time, 1.0, wt_sway(time));
	float rr0 = length(p);
	vec3 glow = vec3(0.0);
	glow += WT_RIM * exp(-pow((rr0 - 1.0) / 0.18, 2.0)) * step(1.0, rr0) * 0.12;
	glow += inflow(p, dot_size);
	glow += sparkle(p, dot_size, size);
	vec3 rgb = tunnel.rgb * tunnel.a * blink + glow * blink;
	float alpha = clamp(tunnel.a + max(glow.r, max(glow.g, glow.b)), 0.0, 1.0);
	rgb = round(rgb * levels) / levels;
	COLOR = vec4(rgb / max(alpha, 0.001), alpha);
}
