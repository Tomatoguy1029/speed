// 経験値の結晶（仕様書 15）：紫の菱形に、明るい面と暗い紫の縁を付ける。
// メッシュは単位の大きさの菱形（上下 1.4、左右 1）。
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.224, 0.149, 0.369, 1.0);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	// 菱形の縁までの近さ（0 が中心、1 が縁）
	float edge = abs(local.x) + abs(local.y) / 1.4;
	vec3 base = COLOR.rgb;
	// 左上の面を明るく、右下の面を暗くする
	float facet = (local.x < 0.0 ? 0.25 : -0.12) + (local.y < 0.0 ? 0.18 : -0.08);
	vec3 col = base * (1.0 + facet);
	col = mix(col, outline_color.rgb, smoothstep(0.72, 0.9, edge));
	COLOR = vec4(col, COLOR.a);
}
