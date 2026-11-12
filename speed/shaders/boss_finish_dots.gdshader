shader_type canvas_item;
render_mode unshaded, blend_add;
// ボス撃破の演出の光の粒。ボスの絵を格子状に読み、ある画素だけが崩れる時刻から粒になって飛ぶ。
// 粒の位置は時刻から計算し、毎フレームの受け渡しはしない。試作の parts と同じ式。
uniform sampler2D capture : filter_nearest, repeat_disable;
uniform sampler2D noise : filter_nearest, repeat_enable;
uniform vec2 capture_size = vec2(1.0);
uniform vec2 cap_x = vec2(1.0, 0.0);
uniform vec2 cap_y = vec2(0.0, 1.0);
uniform vec2 cap_o = vec2(0.0);
uniform bool linear_input = false;
uniform vec2 origin;
uniform vec2 impact;
uniform vec2 cut_dir = vec2(0.0, -1.0);
uniform float cs = 1.0;
uniform float max_r = 140.0;
uniform bool boost = true;
uniform int grid = 1;
uniform float spacing = 2.24;
uniform float since_burst = -1.0;
uniform float burst_time = 1.0;
uniform float settle = 0.0;
uniform bool gather = false;
uniform vec2 relic;
uniform vec2 shift;
uniform float dot_size = 2.0;
// 光の層：4粒に1粒を、試作の6ドット四方で描く。
uniform bool glow_layer = false;

varying vec4 tint;
varying float head;
varying float trail;

float pick(vec2 q, float k) { return textureLod(noise, (q + vec2(k * 37.0, k * 91.0)) / 252.0, 0.0).a; }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)); }

vec2 toward(vec2 from, vec2 target, float bend, float q) {
	float ge = q * q * q, an = bend * sin(ge * PI) * 0.9;
	vec2 o = from - target;
	return target + vec2(o.x * cos(an) - o.y * sin(an), o.x * sin(an) + o.y * cos(an)) * (1.0 - ge);
}

// 粒1つの位置と色を決める。描かない粒は false を返す。
bool place(int id, vec2 corner, out vec2 vertex, out vec4 color_out, out float head_out, out float trail_out) {
	vertex = vec2(0.0);
	color_out = vec4(0.0);
	head_out = 0.0;
	trail_out = 0.0;
	if (glow_layer && id % 4 != 0) return false;
	vec2 cell = (vec2(float(id % grid), float(id / grid)) - float(grid) * 0.5 + 0.5) * spacing;
	vec2 q = floor(cell + (vec2(pick(cell, 1.0), pick(cell, 2.0)) - 0.5) * spacing) + 0.5;
	vec2 uv = (cap_x * (origin + q * cs).x + cap_y * (origin + q * cs).y + cap_o) / capture_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return false;
	vec4 base = textureLod(capture, uv, 0.0);
	if (base.a < 0.5) return false;
	vec3 rgb = linear_input ? to_srgb(base.rgb) : base.rgb;
	float h = pick(q, 3.0), h2 = pick(q, 4.0), n2 = pick(q, 5.0);
	vec2 cut_pos = (origin + q * cs - impact) / cs;
	float d = cut_pos.x * cut_dir.y - cut_pos.y * cut_dir.x;
	float r = max(length(q), 1.0);
	vec4 n = textureLod(noise, q / 252.0, 0.0);
	float tf = boost ? 0.03 + 0.58 * (0.65 * abs(d) / max_r + 0.35 * r / max_r) : 0.03 + 0.62 * r / max_r;
	tf += 0.09 * n.b + 0.09 * n.g;
	float age = since_burst - tf * burst_time;
	if (age < 0.0) return false;
	vec2 side = vec2(cut_dir.y, -cut_dir.x) * (d > 0.0 ? 1.0 : -1.0);
	float mixing = 0.45 + 0.4 * pick(q, 6.0);
	vec2 v = normalize(side * (1.0 - mixing) + q / r * mixing);
	float ja = (pick(q, 7.0) - 0.5) * 1.1;
	v = vec2(v.x * cos(ja) - v.y * sin(ja), v.x * sin(ja) + v.y * cos(ja));
	vec2 vel = v * (70.0 + 640.0 * pow(pick(q, 8.0), 2.0)) * (0.6 + 0.8 * n2);
	float kd = 2.1 + 1.2 * h2, e = (1.0 - exp(-kd * age)) / kd;
	float sw = sin(age * (1.5 + 2.0 * h) + h * TAU) * (4.0 + 10.0 * h2) * min(1.0, age);
	vec2 at = shift / cs + q + vel * e + vec2(-vel.y, vel.x) / 200.0 * sw + vec2(0.0, -3.0 * age * age);
	vec3 color = pick(q, 9.0) < 0.35 ? vec3(1.0, 214.0 / 255.0, 120.0 / 255.0) : min(vec3(1.0), rgb * 1.7 + vec3(40.0, 60.0, 90.0) / 255.0);
	float alpha;
	vec2 from = at;
	if (gather && pick(q, 10.0) < 0.55) {
		float dl = 0.02 + 0.68 * (0.6 * h + 0.4 * pick(q, 11.0));
		float g = clamp((settle - dl) / 0.27, 0.0, 1.0);
		if (g >= 1.0) return false;
		vec2 target = (relic - origin) / cs;
		float bend = (h2 - 0.5) * 1.3;
		at = toward(from, target, bend, g);
		alpha = max(0.35, 0.55 + 0.45 * sin(age * (9.0 + 14.0 * h2) + h * 40.0));
		if (g > 0.12) {
			from = toward(from, target, bend, max(0.0, g - 0.09));
			trail_out = 1.0;
			alpha = 1.0;
		} else from = at;
	} else {
		float life = 0.7 + 1.5 * h2;
		if (age > life) return false;
		alpha = pow(1.0 - age / life, 1.4) * (0.6 + 0.4 * sin(age * (10.0 + 16.0 * h) + h2 * 40.0));
	}
	if (glow_layer) {
		color_out = vec4(color, alpha * 0.4);
		vertex = origin + (at + corner * 6.0) * cs;
		return true;
	}
	color_out = vec4(age < 0.12 ? vec3(1.0, 251.0 / 255.0, 230.0 / 255.0) : color, alpha * (age < 0.1 ? 1.0 : 0.7));
	vec2 axis = at - from;
	float length_ = length(axis) * cs;
	vec2 along = length_ > 0.001 ? normalize(axis) : vec2(1.0, 0.0);
	vec2 middle = origin + (at + from) * 0.5 * cs;
	float total = length_ + dot_size;
	head_out = dot_size / total;
	vertex = middle + along * corner.x * total + vec2(-along.y, along.x) * corner.y * dot_size;
	return true;
}

void vertex() {
	vec2 vertex_out;
	vec4 color_out;
	float head_out;
	float trail_out;
	if (place(INSTANCE_ID, VERTEX, vertex_out, color_out, head_out, trail_out)) {
		VERTEX = vertex_out;
		tint = color_out;
		head = head_out;
		trail = trail_out;
	} else {
		VERTEX = vec2(0.0);
		tint = vec4(0.0);
		head = 0.0;
		trail = 0.0;
	}
}

void fragment() {
	if (tint.a <= 0.0) discard;
	float a = tint.a;
	if (trail > 0.0 && UV.x < 1.0 - head) {
		if (abs(UV.y - 0.5) > 0.35) discard;
		a *= 0.6;
	}
	COLOR = vec4(tint.rgb, a);
}
