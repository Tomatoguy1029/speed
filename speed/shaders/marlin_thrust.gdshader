// 吻先から後方へ開く白い短筋。原画の1pixelを単位に、各筋の頂点だけを動かす。
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float clock = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
varying vec2 pixel_position;
varying vec4 stroke; // tail, head, length, opacity
varying float slope;
varying float pulse;

float hash01(float value) {
	return fract(sin(value * 127.1 + 311.7) * 43758.5453);
}

void vertex() {
	float ray = UV.x;
	float key = ray * 19.13 + 713.0;
	float length;
	float opacity;
	float phase = hash01(key + 4.0);
	float segment;
	if (ray < 36.0) {
		slope = (mod(ray, 2.0) < 1.0 ? -1.0 : 1.0) * mix(0.19, 0.37, hash01(key));
		length = mix(36.0, 100.0, hash01(key + 1.0));
		opacity = mix(110.0, 175.0, hash01(key + 2.0));
		segment = mix(0.28, 0.61, hash01(key + 3.0));
	} else if (ray < 64.0) {
		slope = mix(-0.17, 0.17, hash01(key));
		length = mix(40.0, 94.0, hash01(key + 1.0));
		opacity = mix(95.0, 145.0, hash01(key + 2.0));
		segment = mix(0.22, 0.48, hash01(key + 3.0));
	} else {
		float n = ray - 64.0;
		slope = n < 2.0 ? (n < 1.0 ? -0.35 : 0.35) : (n < 3.0 ? -0.33 : 0.33);
		length = n < 1.0 ? 112.0 : (n < 2.0 ? 106.0 : (n < 3.0 ? 98.0 : 101.0));
		opacity = n < 1.0 ? 205.0 : (n < 2.0 ? 195.0 : (n < 3.0 ? 145.0 : 149.0));
		phase = n < 1.0 ? 0.10 : (n < 2.0 ? 0.31 : (n < 3.0 ? 0.51 : 0.82));
		segment = n < 1.0 ? 0.57 : (n < 2.0 ? 0.59 : (n < 3.0 ? 0.45 : 0.49));
	}
	float cycle = fract(clock * (1.8 + mod(ray, 5.0) * 0.13) + phase);
	float head = min(length, cycle * 1.27 * length);
	float tail = max(0.0, cycle * 1.27 * length - length * segment);
	pulse = 0.8 + 0.2 * sin(clock * 19.0 + ray * 2.4);
	// 吻先の短い接続筋も同じメッシュに含める。
	if (ray >= 68.0) {
		float n = ray - 68.0;
		slope = n < 1.0 ? -0.35 : (n < 2.0 ? -0.29 : (n < 3.0 ? 0.29 : 0.35));
		head = floor(9.0 + 4.0 * sin(clock * 15.0 + n * 3.0));
		tail = 0.0;
		length = head + 1.0;
		opacity = 64.0 + 14.0 * sin(clock * 22.0 + n);
		pulse = 1.0;
	}
	float a = UV.y == 1.0 || UV.y == 2.0 ? head : tail;
	float side = UV.y < 2.0 ? -1.0 : 1.0;
	VERTEX = vec2(a, slope * a + side);
	pixel_position = VERTEX;
	stroke = vec4(tail, head, length, opacity / 255.0);
}

void fragment() {
	vec2 p = floor(pixel_position + vec2(0.5));
	if (abs(p.y - floor(slope * p.x + 0.5)) > 0.1) discard;
	float edge = clamp((p.x - stroke.x) / 4.0, 0.0, 1.0)
		* clamp((stroke.y - p.x + 1.0) / 4.0, 0.0, 1.0);
	float fade = pow(max(0.0, 1.0 - p.x / max(stroke.z, 0.001)), 0.34);
	COLOR = vec4(vec3(1.0), stroke.w * edge * fade * pulse * strength);
}
