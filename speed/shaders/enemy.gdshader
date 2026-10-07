// 敵（まとめた描画）：縁を明るくして、暗い背景でも輪郭が分かるようにする。
// メッシュは中心を含む三角形の扇なので、縁の頂点は UV がない代わりに中心からの距離で判断する。
shader_type canvas_item;

varying float rim;

void vertex() {
	rim = length(VERTEX);
}

void fragment() {
	float r = smoothstep(0.55, 1.0, rim);
	COLOR = vec4(COLOR.rgb * (0.82 + 0.45 * r), COLOR.a);
}
