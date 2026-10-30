// 双極ビームの帯（試作の wbipolar）。世界のドットの格子で、始点 a から終点 b へ伸びる丸い両端の帯を描く。
// 中心から白・青緑・暗い青緑（市松）。帯の幅は波打ち、中を2本の光がねじれて走る。長さはドット単位。
// tuning の値は戦闘エフェクトツールで上書きする（ShaderTuning）。
shader_type canvas_item;
render_mode unshaded;

uniform vec2 center = vec2(0.0);
uniform vec2 half_size = vec2(1.0);
uniform float cell = 2.366;
uniform vec2 a = vec2(0.0);
uniform vec2 b = vec2(1.0, 0.0);
uniform float width = 16.0;
uniform float time = 0.0;
group_uniforms tuning;
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(0.412, 1.0, 0.941, 1.0);
uniform vec4 edge_color : source_color = vec4(0.122, 0.498, 0.525, 1.0);
uniform vec4 helix_color : source_color = vec4(0.812, 1.0, 0.976, 1.0);
uniform float core_ratio : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform float mid_ratio : hint_range(0.0, 1.0, 0.05) = 0.7;
uniform float wobble : hint_range(0.0, 0.5, 0.01) = 0.14;
uniform float wobble_speed : hint_range(0.0, 100.0, 1.0) = 40.0;
uniform float helix_width : hint_range(0.0, 0.5, 0.01) = 0.32;
uniform float helix_speed : hint_range(0.0, 100.0, 1.0) = 30.0;
group_uniforms;
varying vec2 world;

void vertex() {
	world = center + VERTEX * half_size;
}

void fragment() {
	vec2 p = floor(world / cell);
	vec2 d = b - a;
	float len = length(d);
	vec2 u = d / max(len, 0.001);
	vec2 n = vec2(-u.y, u.x);
	vec2 rel = p - a;
	float i = dot(rel, u);
	float s = dot(rel, n);
	float e = i < 0.0 ? -i : (i > len ? i - len : 0.0);
	float ic = clamp(i, 0.0, len);
	float hw = width * 0.5 * (1.0 + wobble * sin(ic * 0.45 - time * wobble_speed));
	float rr = length(vec2(e, s));
	vec4 color = vec4(0.0);
	if (rr <= hw) {
		float k = rr / max(hw, 0.01);
		if (k < core_ratio) {
			color = core_color;
		} else if (k < mid_ratio) {
			color = mid_color;
		} else if (mod(p.x + p.y, 2.0) < 1.0) {
			color = edge_color;
		}
	}
	if (i >= 0.0 && i <= len) {
		float hx = width * helix_width * sin(i * 0.12 - time * helix_speed);
		if (abs(s - hx) < 0.5) {
			color = helix_color;
		} else if (abs(s + hx) < 0.5) {
			color = edge_color;
		}
	}
	if (color.a <= 0.0) {
		discard;
	}
	COLOR = color;
}
