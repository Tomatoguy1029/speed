// エンドホールの暗黒と重力レンズ：試作の lens と同じ式。機体より下の層に置き、それまでに描いた画面を読む。
// 長さはすべて世界の単位で、四角の中心が暗黒の中心。暗黒の半径 shadow の内側は真っ黒。
// 外側は読み位置を r − shadow²/r へ寄せて光を曲げ、レンズの届く範囲 reach の外側4割でなめらかに元へ戻す。
// 引き込みの瞬間は、周りを暗い紫に沈め、紫の光を中心から外へ薄れるように足す。沈みと光は試作のキャンバスと同じく
// 画面の色（sRGB）のまま混ぜて足す。
// tuning の値は戦闘エフェクトツールで上書きする（ShaderTuning）。
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float half_size = 1.0;
uniform float shadow = 0.0;
uniform float reach = 0.0;
uniform float dim_radius = 0.0;
uniform float dim = 0.0;
uniform float glow_radius = 0.0;
uniform float glow = 0.0;
group_uniforms tuning;
uniform vec4 dim_color : source_color = vec4(0.078, 0.0, 0.157, 1.0);
uniform vec4 glow_color : source_color = vec4(0.569, 0.196, 1.0, 1.0);
uniform float lens_return : hint_range(0.2, 0.95, 0.05) = 0.6;
group_uniforms;

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * half_size;
	float r = length(p);
	// 世界の1単位あたりの画面 UV（四角は回さないので軸ごとに求める）
	vec2 per = vec2(dFdx(SCREEN_UV.x) / dFdx(p.x), dFdy(SCREEN_UV.y) / dFdy(p.y));
	vec4 color = texture(screen, SCREEN_UV);
	if (shadow > 0.0 && r < reach) {
		if (r <= shadow) {
			color = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			float t = clamp((r / reach - lens_return) / (1.0 - lens_return), 0.0, 1.0);
			float blend = t * t * (3.0 - 2.0 * t);
			float sr = (r - shadow * shadow / r) * (1.0 - blend) + r * blend;
			color = texture(screen, SCREEN_UV + (p / r * sr - p) * per);
		}
	}
	vec3 shown = to_srgb(color.rgb);
	if (dim > 0.0 && r < dim_radius && r > shadow) {
		shown = mix(shown, to_srgb(dim_color.rgb), dim);
	}
	if (glow > 0.0 && r < glow_radius && r > shadow) {
		shown += to_srgb(glow_color.rgb) * glow * (1.0 - r / glow_radius);
	}
	COLOR = vec4(to_linear(min(shown, vec3(1.0))), 1.0);
}
