// ヘルクレス座の力が効いている間の画面：噴火のさなかにいるように、画面の縁の一周から低い炎がゆらゆら立ち、画面には陽炎がかかる。
// 発動の瞬間は、機体を中心にぎざぎざの熾火の線（先が白熱し、後ろへ黄・橙・赤へ冷える）が画面の外まで燃え広がる（pixelFX の burn away の技法）。
// 線の手前の画面は熱に照らされ、線が通った跡は暗くせず元の画面に戻る。線が縁へ届くころ、縁から普段の炎が伸びる。
// 赤系は縁の炎と発動の熾火にとどめる。炎は隕石の炎と同じ色の並びで、網点のドットで描く。
// 陽炎は画面を整数の画素だけずらして拾い、画素どうしを混ぜない（色を変えない）。足す色だけ機体の1ドットの格子で求める。
// HDR の画面ではリニアのまま扱い、足す色だけリニアへ直す。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/burst_noise.gdshaderinc"
#include "res://shaders/hero_color.gdshaderinc"
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float strength = 0.0;
uniform float time = 0.0;
// 発動からの秒（発動の炎の輪の進み）
uniform float since = 100.0;
// 熾火が燃え広がり始める画面の位置（画面の幅・高さを 1 とした機体の位置）
uniform vec2 origin = vec2(0.5);
// 画面での1ドットの大きさ（画素）
uniform float cell_px = 2.0;
uniform bool linear_output = false;
group_uniforms tuning;
// 炎の色（隕石の炎と同じ並び）：白熱から暗い赤へ
uniform vec4 flame_0 = vec4(1.0, 0.965, 0.847, 1.0);
uniform vec4 flame_1 = vec4(1.0, 0.824, 0.478, 1.0);
uniform vec4 flame_2 = vec4(1.0, 0.541, 0.141, 1.0);
uniform vec4 flame_3 = vec4(0.847, 0.251, 0.055, 1.0);
uniform vec4 flame_4 = vec4(0.478, 0.110, 0.031, 1.0);
// 縁から立つ炎の高さ（ドット）
uniform float flame_height : hint_range(0.0, 160.0, 1.0) = 60.0;
// 炎の濃さ
uniform float flame_amount : hint_range(0.0, 1.0, 0.01) = 0.85;
// 陽炎の揺れ（画素）
uniform float haze_px : hint_range(0.0, 8.0, 0.1) = 3.0;
group_uniforms;

// 発動の熾火が画面の外まで燃え広がりきる秒
const float BURN_IN = 0.85;
// 熾火の線のまわりを照らす光の届く距離（ドット）
const float HALO = 24.0;
const float POOL = 48.0;
// 熾火の色の並び（pixelFX の burn away と同じ9段）：暗い赤から白熱へ
const vec3 EMBER[9] = vec3[](vec3(0.290, 0.090, 0.071), vec3(0.541, 0.122, 0.090), vec3(0.788, 0.157, 0.122), vec3(0.949, 0.337, 0.114), vec3(1.0, 0.541, 0.165), vec3(1.0, 0.761, 0.239), vec3(1.0, 0.886, 0.420), vec3(1.0, 0.953, 0.651), vec3(1.0, 1.0, 1.0));
const vec3 SCORCH = vec3(0.16, 0.09, 0.06);
const vec3 WARM = vec3(1.0, 0.62, 0.2);

vec3 lin(vec3 c) {
	return linear_output ? to_linear(c) : c;
}

float bayer(vec2 cell) {
	ivec2 g = ivec2(mod(cell, 4.0));
	const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (BAYER[g.y * 4 + g.x] + 0.5) / 16.0;
}

float fbm(vec2 p, float seed) {
	return vnoise(vec3(p, seed)) * 0.55 + vnoise(vec3(p * 2.1, seed + 3.0)) * 0.3 + vnoise(vec3(p * 4.3, seed + 7.0)) * 0.15;
}

// 炎の色：熱（0〜1）を5段に区切り、段の境は網点でぼかす
vec3 flame_color(float t, vec2 cell) {
	float k = clamp(t * 5.0 + bayer(cell) - 0.5, 0.0, 4.99);
	int i = int(k);
	return i >= 4 ? flame_0.rgb : i == 3 ? flame_1.rgb : i == 2 ? flame_2.rgb : i == 1 ? flame_3.rgb : flame_4.rgb;
}

// 縁から立つ炎：along は縁にそった位置（ドット）、depth は縁からの距離（ドット）。炎なら熱（0〜1）、なければ負
float flame(float along, float depth, float height, float seed) {
	if (height <= 0.0) return -1.0;
	// 炎の舌：ゆっくり大きく伸び縮みし、細かくゆらめく
	float tongue = vnoise(vec3(along * 0.06, time * 0.9, seed)) * 0.65 + vnoise(vec3(along * 0.22, time * 3.2, seed + 4.0)) * 0.35;
	float h = height * (0.25 + 0.95 * tongue);
	// 上へ行くほど揺れて千切れる
	float lick = vnoise(vec3(along * 0.15, depth * 0.12 - time * 2.4, seed + 9.0));
	float reach = h * (0.75 + 0.5 * lick);
	if (depth > reach) return -1.0;
	return 1.0 - depth / max(reach, 0.001);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cells = size / cell_px;
	vec2 cell = floor(FRAGCOORD.xy / cell_px);
	vec2 uv = (cell + 0.5) / cells;
	vec2 q = (uv - 0.5) * 2.0;
	q.x *= size.x / size.y * 0.8;
	float edge = smoothstep(0.6, 1.5, length(q));
	// 普段の炎と陽炎は、熾火の線が縁へ届くころに現れる
	float settle = smoothstep(BURN_IN * 0.55, BURN_IN * 1.1, since);
	// 陽炎：上へゆらゆら立ちのぼる揺れで、縁の方ほど大きくうねる。細かい揺れに大きなうねりを重ね、整数の画素だけずらす
	vec2 wobble = vec2(vnoise(vec3(cell * 0.06 + vec2(0.0, time * 1.4), 1.0)), vnoise(vec3(cell * 0.06 + vec2(time * 0.9, time * 1.4), 4.0))) - 0.5;
	vec2 swell = vec2(vnoise(vec3(cell * 0.018 + vec2(0.0, time * 0.7), 21.0)), vnoise(vec3(cell * 0.018 + vec2(time * 0.5, time * 0.7), 24.0))) - 0.5;
	vec2 shift = floor((wobble * (0.3 + 0.7 * edge) + swell * 2.0 * edge) * 2.0 * haze_px * strength * settle + 0.5);
	vec3 col = texture(screen, SCREEN_UV + shift / size).rgb;
	// 炎：縁の一周（下・上・左・右）から内へ立つ。現れるときは縁から高さが伸びる
	float height = flame_height * settle;
	float heat = flame(cell.x, cells.y - 1.0 - cell.y, height, 1.0);
	heat = max(heat, flame(cell.x, cell.y, height, 31.0));
	heat = max(heat, flame(cell.y, cell.x, height, 11.0));
	heat = max(heat, flame(cell.y, cells.x - 1.0 - cell.x, height, 21.0));
	if (heat >= 0.0 && step(bayer(cell + 1.0), flame_amount * strength * (0.4 + 0.6 * heat)) > 0.0) col = lin(flame_color(heat, cell));
	// 発動の熾火：機体からの距離（画面の形に合わせた丸み）に大きなうねりと細かなぎざぎざを足した場で、熾火の線がどこまで来たかを決める。形は燃え広がる火のように崩れる
	if (since < BURN_IN + 0.1 && strength > 0.0) {
		float half_cells = min(cells.x, cells.y) * 0.5;
		vec2 o = origin * cells;
		// 位置をうねりでずらしてから距離をとり、丸みが残らないよう大きく崩す
		vec2 warp = vec2(fbm(cell / 60.0, 17.0), fbm(cell / 60.0, 23.0)) - 0.5;
		vec2 u = (cell + warp * 90.0 - o) / (cells * 0.5);
		float m = pow(pow(abs(u.x), 2.5) + pow(abs(u.y), 2.5), 0.4);
		float f = m * half_cells * 0.75 + 64.0 * (fbm(cell / 80.0, 3.0) - 0.5) * 2.0 + 20.0 * (fbm(cell / 26.0, 7.0) - 0.5) * 2.0 + 2.4 * (fbm(cell / 7.0, 12.0) - 0.5) * 2.0;
		// 線の後ろの端まで、画面の一番遠い角の外へ出るところまで広がる。線が画面の中で消えて見えないようにする
		float far = 0.0;
		for (int c = 0; c < 4; c++) {
			vec2 corner = (vec2(float(c & 1), float(c >> 1)) * cells - o) / (cells * 0.5);
			far = max(far, pow(pow(abs(corner.x), 2.5) + pow(abs(corner.y), 2.5), 0.4) * half_cells * 0.75);
		}
		far += 130.0;
		// 線の位置：機体から勢いよく燃え広がり、少しずつ勢いを落とす。戻らない
		float k = mix(-8.0, far, 1.0 - pow(1.0 - clamp(since / BURN_IN, 0.0, 1.0), 1.5));
		float e = k - f;
		float hv = vnoise(vec3(cell / 13.0, 41.0 + time * 0.8));
		if (e < 0.0) {
			// 線の手前：熱に照らされ、すぐそばは焦げる
			if (e > -2.5) col = mix(col, lin(SCORCH), 0.5 * (1.0 + e / 2.5));
			float a = max(0.0, 1.0 + e / HALO), b = max(0.0, 1.0 + e / POOL);
			col += lin(WARM) * (0.3 * a * a + 0.12 * b * b) * (0.75 + 0.25 * sin(time * 7.0 + hv * 9.0));
		} else {
			// 線：先が白熱し、後ろへ冷える。線が通った跡は元の画面のまま
			float th = 0.6 + 0.6 * hv;
			float s = e / th;
			if (s < 6.4) {
				int i = s < 0.9 ? (hv > 0.6 ? 8 : 7) : s < 1.7 ? 6 : s < 2.4 ? 5 : s < 3.1 ? 4 : s < 3.8 ? 3 : s < 4.6 ? 2 : s < 5.5 ? 1 : 0;
				col = lin(EMBER[i]);
				if (s < 4.6) col += lin(WARM) * 0.45 * (1.0 - s / 4.6) * (0.7 + 0.3 * hv);
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
