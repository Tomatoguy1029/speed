// しし座の獅子のモーションブラー：獅子の一部（本体だけ、またはオーラだけ）を1ドット＝1テクセルで描いた絵
// （leo_lion.gd の小さな画面）から、進む向きの後ろへ流れる半透明のぶれだけを描く。元の形そのものは描かない
// （本体とオーラは、ぶらさずに別に描く）。本体とオーラは、それぞれ別の絵からぶれをつくる。
// 絵は HDR を使わない画面に sRGB の色のまま、色に濃さを掛けた形（透明の黒に重ねた形）で描いてあり、
// 表示先が HDR ならリニアへ直す。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/hero_color.gdshaderinc"
uniform sampler2D painted : filter_nearest;
uniform bool linear_output = false;
// 絵の一辺のドット数
uniform float cells = 190.0;
// 進む向き（世界の向き。絵の格子は世界にそろっている）
uniform vec2 forward = vec2(1.0, 0.0);
// ぶれの長さ（ドット）。0 ならぶれない
uniform float smear = 10.0;
// ぶれの、元の形のすぐ後ろでの濃さ
uniform float density = 0.5;

const int TAPS = 26;

void fragment() {
	vec2 cell = floor(UV * cells) + 0.5;
	// 元の形がある所には、ぶれを描かない
	if (texture(painted, cell / cells).a > 0.3) discard;
	// 進む向きをさかのぼり、元の形に当たるまでの距離と、当たった所から先の色を拾う
	vec3 sum = vec3(0.0);
	float hits = 0.0;
	float first = -1.0;
	for (int i = 1; i < TAPS; i++) {
		float t = float(i) / float(TAPS - 1);
		vec2 at = (cell + forward * t * smear) / cells;
		if (at.x < 0.0 || at.y < 0.0 || at.x > 1.0 || at.y > 1.0) continue;
		vec4 c = texture(painted, at);
		if (c.a > 0.3) {
			if (first < 0.0) first = t;
			sum += c.rgb / c.a;
			hits += 1.0;
		}
	}
	if (first < 0.0) discard;
	// ぶれの濃さは元の形のふちからの距離で決め、離れるほどなめらかに薄れて消える。ドット絵らしく段で区切る
	float alpha = floor(pow(1.0 - first, 1.3) * density * 10.0 + 0.5) / 10.0;
	if (alpha <= 0.0) discard;
	vec3 rgb = sum / hits;
	COLOR = vec4(linear_output ? to_linear(rgb) : rgb, alpha);
}
