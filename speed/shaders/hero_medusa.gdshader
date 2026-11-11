// ペルセウス座の発動：機体の上に、深淵から睨むようなメドゥーサの目が半透明ににじんで浮かぶ。
// 目は閉じたまま、空間に急に現れた黒い線がだんだん太くなって現れ、重いまぶたが途中でつかえながら7割まで開き、
// 数コマ止まって勢いよく見開く。
// 開ききった瞬間に虹彩の奥が鈍く光る（このとき画面全体へオーラが広がり、敵が石になる）。瞳孔は真ん中が少しふくらんだ蛇の目で、
// 眼球（虹彩と瞳孔）は目の中でわずかに動く。
// 色は濃い毒緑で、縁は闇へ溶ける。長さはドット単位で、四角の中心が機体。目は機体の手前に重なる。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/burst_noise.gdshaderinc"
#include "res://shaders/hero_color.gdshaderinc"
uniform float half_cells = 64.0;
uniform float age = 0.0;
uniform float life = 3.8;
uniform float seed = 0.0;
// HDR の画面へ描くときは true（色は sRGB で求め、最後にリニアへ直す）
uniform bool linear_output = false;
// 線が太くなり終える時刻、まぶたが開き始める時刻、開ききる時刻（秒）
uniform float line_to = 0.5;
uniform float open_from = 0.6;
uniform float open_to = 2.0;
group_uniforms tuning;
uniform vec4 abyss = vec4(0.000910581, 0.008568126, 0.004024717, 1.0);
uniform vec4 murk = vec4(0.005181517, 0.059511238, 0.023153366, 1.0);
uniform vec4 moss = vec4(0.008023193, 0.274677312, 0.072271851, 1.0);
uniform vec4 venom = vec4(0.039546235, 0.708375780, 0.124771818, 1.0);
uniform vec4 pale = vec4(0.434153636, 1.000000000, 0.191201683, 1.0);
uniform float eye_size : hint_range(8.0, 80.0, 1.0) = 42.0;
uniform float opacity : hint_range(0.2, 1.0, 0.05) = 1.0;
group_uniforms;

varying vec2 v_cell;

void vertex() {
	v_cell = (UV - 0.5) * 2.0 * half_cells;
}

vec4 paint(vec2 c) {
	float t = age;
	if (t >= life) return vec4(0.0, 0.0, 0.0, -1.0);
	float close = smoothstep(life - 0.8, life - 0.05, t);
	// まぶたの開き：重いまぶたが途中でつかえながら7割までゆっくり開き、数コマ止まって、勢いよく見開く
	float hold = 0.15;
	float k = clamp((t - open_from) / (open_to - hold - open_from), 0.0, 1.0);
	float ease = 1.0 - pow(1.0 - k * k * (3.0 - 2.0 * k), 1.6);
	float hitch = 0.06 * sin(k * 6.2831853 * 2.0) * (1.0 - k) * k * 4.0;
	float kl = clamp((t - open_from - 0.18) / (open_to - hold - open_from), 0.0, 1.0);
	float ease_low = 1.0 - pow(1.0 - kl * kl * (3.0 - 2.0 * kl), 1.6);
	float snap_t = t - open_to;
	float sk = clamp(snap_t / 0.12, 0.0, 1.0);
	float wide = snap_t < 0.0 ? 0.0 : 1.0 - pow(1.0 - sk, 3.0) + 0.06 * exp(-10.0 * max(snap_t - 0.12, 0.0)) * sin(max(snap_t - 0.12, 0.0) * 30.0) * step(0.12, snap_t);
	float lift = 0.7 * clamp(ease - hitch, 0.0, 1.0) + 0.3 * wide;
	float open = lift * (1.0 - close);
	float open_low = (0.7 * clamp(ease_low - hitch * 0.7, 0.0, 1.0) + 0.3 * wide) * (1.0 - close);
	float since = t - open_to;
	float w = eye_size;
	float h = eye_size * 0.42;
	vec2 q = vec2(c.x / w, c.y / h);
	float lens = max(0.0, 1.0 - q.x * q.x);
	// 閉じた目の線：急に現れ、だんだん太くなる。両端は細い
	float seam = mix(0.4, 2.0, smoothstep(0.0, line_to, t)) * pow(lens, 0.75);
	float tremble = (vnoise(vec3(t * 6.0, c.x * 0.05, seed)) - 0.5) * 0.05 * (open + 0.3 * step(0.01, t));
	float upper = h * 1.3 * lens * max(open + tremble, 0.0);
	float lower = h * 0.55 * lens * max(open_low - tremble * 0.4, 0.0);
	float lid = c.y < 0.0 ? upper : lower;
	float present = 1.0 - close * close;
	float haze = vnoise(vec3(c * 0.12 + vec2(t * 1.5, 0.0), 2.0));
	if (abs(q.x) >= 1.0) return vec4(0.0, 0.0, 0.0, -1.0);
	// まぶたの際：閉じた線から開いた目のふちへ続く黒い帯。太さの端数は半透明にして段差を出さない
	float edge = abs(c.y) - lid;
	if (edge > 0.0 && edge < seam + 1.0) {
		float cover = clamp(seam - edge + 0.5, 0.0, 1.0);
		if (cover > 0.05) return vec4(abyss.rgb, opacity * present * cover);
	}
	if (edge >= seam) {
		// まぶたの外へ、闇が煙のように淡くにじむ
		float a = (1.0 - smoothstep(0.0, 4.0 + haze * 4.0, edge - seam)) * present * smoothstep(0.0, 0.3, t);
		a = floor(a * 4.0) / 4.0;
		if (a <= 0.0) return vec4(0.0, 0.0, 0.0, -1.0);
		return vec4(mix(abyss.rgb, murk.rgb, haze), a * 0.5 * opacity);
	}
	// 眼球：虹彩と瞳孔はいっしょに、目の中でわずかに動く
	float ir = h * 0.9;
	vec2 look = vec2(sin(t * 0.9 + seed) * 0.14 + sin(t * 2.1) * 0.04, (upper - lower) * -0.5 / h + cos(t * 0.7) * 0.05) * h * vec2(1.0, 1.0);
	look *= k;
	vec2 ic = c - look;
	float d = length(ic);
	float glow = (since < 0.0 ? 0.0 : exp(-2.0 * since)) + 0.2 * k * (0.5 + 0.5 * sin(t * 2.5));
	float lid_dark = 1.0 - smoothstep(0.0, 3.5, lid - abs(c.y));
	// 瞳孔：縦長で真ん中が少しふくらんだ蛇の目
	vec3 col;
	float pw = ir * mix(0.13, 0.2, k);
	float ph = ir * 0.88;
	bool pupil = abs(ic.y) < ph && abs(ic.x) < pw * (1.0 - pow(ic.y / ph, 2.0));
	if (pupil) {
		col = abyss.rgb;
	} else if (d < ir) {
		// 虹彩：外へなめらかに闇へ溶け、瞳孔のまわりだけが毒の緑に鈍く光る
		float a = atan(c.y, c.x);
		float fiber = vnoise(vec3(cos(a) * 5.0, sin(a) * 5.0, d * 0.1 + seed));
		float r = d / ir + (fiber - 0.5) * 0.35;
		vec3 inner = mix(venom.rgb, pale.rgb, glow * 0.8);
		col = mix(inner, moss.rgb, smoothstep(0.4, 0.75, r));
		col = mix(col, murk.rgb, smoothstep(0.75, 1.05, r));
		if (abs(ic.x) < pw * 1.8 * (1.0 - pow(ic.y / ph, 2.0)) && abs(ic.y) < ph) col = mix(col, pale.rgb, 0.2 + 0.5 * glow);
	} else {
		// 白目：濁った暗い緑で、目尻へ闇になる
		col = mix(murk.rgb, moss.rgb, (1.0 - abs(q.x)) * 0.6 + haze * 0.2);
	}
	col = mix(col, abyss.rgb, lid_dark * 0.8);
	float alpha = opacity * present * (0.75 + 0.25 * (1.0 - lid_dark));
	// 色は sRGB の値で16段に丸める（HDR ではこのあとリニアへ直す）
	return vec4(floor(col * 16.0) / 16.0, floor(alpha * 6.0) / 6.0);
}

void fragment() {
	vec4 painted = paint(floor(v_cell) + 0.5);
	if (painted.a < 0.0) discard;
	COLOR = vec4(linear_output ? to_linear(painted.rgb) : painted.rgb, painted.a);
}
