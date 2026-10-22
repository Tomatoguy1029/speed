// 時間切れの暗転。機体を中心にした円の外を黒く塗り、縁に暗い赤の帯を残す。
// 円の縁はゲームの画素の大きさにそろえる。
shader_type canvas_item;

// 画面上の機体の位置（ノードの座標）
uniform vec2 center = vec2(0.0);
// 円の半径（ノードの座標）
uniform float radius = 100000.0;
// ノードの大きさ
uniform vec2 rect_size = vec2(1280.0, 720.0);
// ゲームの1画素の大きさ
uniform float pixel = 2.0;
// 縁の帯の幅（画素の数）
uniform float rim_pixels = 2.0;
uniform vec4 rim_color : source_color = vec4(0.45, 0.06, 0.1, 1.0);

void fragment() {
	vec2 p = (floor(UV * rect_size / pixel) + 0.5) * pixel;
	float d = distance(p, center);
	float outside = step(radius, d);
	float rim = step(radius - rim_pixels * pixel, d) * (1.0 - outside);
	COLOR = vec4(rim_color.rgb * rim, max(outside, rim));
}
