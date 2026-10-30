// 震空の空間の歪み（全画面の処理）：試作の ripple と同じ式。
// 歪みの帯（中心から半径 r、幅 ±8 ドット）の中で、外向きに読み位置をずらし、外側を明るく内側を少し暗くする。
// 帯の中はドットの格子にそろえて読む。最大 8 個。
// tuning の値は戦闘エフェクトツールで上書きする（ShaderTuning）。
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform int count = 0;
// x, y：中心（画面の画素）、z：半径（画面の画素）、w：ずれの強さ（ドット数。負は内向き）
uniform vec4 ripples[8];
// 1ドットの画面の画素数
uniform float cell = 2.0;
group_uniforms tuning;
uniform float band_cells : hint_range(2.0, 20.0, 0.5) = 8.0;
uniform float brighten : hint_range(0.0, 3.0, 0.05) = 0.9;
uniform float darken : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform vec4 highlight : source_color = vec4(0.149, 0.149, 0.171, 1.0);
group_uniforms;

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = SCREEN_UV * size;
	vec2 q = (floor(p / cell) + 0.5) * cell;
	vec4 color = texture(screen, SCREEN_UV);
	for (int i = 0; i < 8; i++) {
		if (i >= count) {
			break;
		}
		vec4 r = ripples[i];
		vec2 d = q - r.xy;
		float dist = length(d);
		float gap = dist - r.z;
		float band = band_cells * cell;
		if (abs(gap) > band || dist < 1.0) {
			continue;
		}
		float k = 1.0 - abs(gap) / band;
		vec2 at = q - d / dist * r.w * k * cell;
		vec3 c = texture(screen, at / size).rgb;
		float lit = gap > 0.0 ? 1.0 + brighten * k : 1.0 - darken * k;
		vec3 add = gap > 0.0 ? highlight.rgb * k * k : vec3(0.0);
		color = vec4(min(c * lit + add, vec3(1.0)), 1.0);
		break;
	}
	COLOR = color;
}
