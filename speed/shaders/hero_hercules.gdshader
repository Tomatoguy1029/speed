// ヘルクレス座の火の隕石群。MultiMesh の1つずつが、ドットの格子にそろえた四角を描く。
// INSTANCE_CUSTOM：x は 種類×1000 ＋ 四角の半分のセル数、y は形の種、z は熱か進み（0〜1）、w は回転か落ちる向きの角度。
// 種類：0 焦げた岩（隕石と破片。z は熱、w は回転）、1 地表の焼け跡（z は残りの熱）、2 衝突の閃光（z は進み）、
// 3 煙（z は進み）、4 落下地点に落ちる影（z は近づき、w は岩の回転）、5 隕石の炎の尾（w は岩の半径のドット）、6 着弾の照り返し（z は進み）。
// 岩は暗い炭色で、赤熱した亀裂が走り、進む向き（w）の側が熱で焼けて光る。色は sRGB で求め、HDR の画面ではリニアへ直す。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/burst_noise.gdshaderinc"
#include "res://shaders/hero_color.gdshaderinc"
uniform bool linear_output = false;
uniform float time = 0.0;

const vec3 CHAR = vec3(0.075, 0.062, 0.058);
const vec3 STONE = vec3(0.20, 0.17, 0.155);
const vec3 STONE_LIT = vec3(0.32, 0.27, 0.24);
const vec3 EMBER_DEEP = vec3(0.45, 0.07, 0.03);
const vec3 EMBER = vec3(0.86, 0.24, 0.05);
const vec3 FLAME = vec3(1.0, 0.55, 0.12);
const vec3 HOT = vec3(1.0, 0.86, 0.48);
const vec3 WHITE_HOT = vec3(1.0, 0.97, 0.86);
const vec3 SMOKE = vec3(0.17, 0.155, 0.15);
const vec3 SCORCH = vec3(0.05, 0.035, 0.03);

varying flat vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

float bayer(vec2 cell) {
	ivec2 p = ivec2(mod(cell, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[p.x + p.y * 4]) + 0.5) / 16.0;
}

vec2 rot(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// 角度ごとに半径が揺れる、ごつごつした輪郭（種ごとに違う形）
float rock_edge(float angle, float seed) {
	vec2 q = vec2(cos(angle), sin(angle));
	float n = vnoise(vec3(q * 1.3, seed)) * 0.6 + vnoise(vec3(q * 3.1, seed + 7.0)) * 0.3 + vnoise(vec3(q * 6.0, seed + 3.0)) * 0.1;
	// 角ばった面にするため、半径を数段にそろえる
	return 0.62 + 0.38 * floor(n * 7.0 + 0.5) / 7.0;
}

vec4 rock(vec2 cell, float half, float seed, float heat, float angle) {
	vec2 p = rot(cell, -angle);
	float r = length(p) / half;
	float a = atan(p.y, p.x);
	float edge = rock_edge(a, seed);
	// 進む向き（四角の +x）の側
	float front = dot(normalize(cell + 0.001), vec2(1.0, 0.0));
	if (r > edge) {
		// 進む側の外へ、熱で焼けた薄い光の膜
		if (heat > 0.5 && r < edge + 2.0 / half && front > 0.55) return vec4(heat > 0.8 ? HOT : FLAME, step(bayer(cell), heat * 0.85));
		return vec4(0.0);
	}
	vec2 q = p / half;
	float lit = dot(normalize(cell + 0.001), vec2(-0.5, -0.7)) * 0.5 + 0.5;
	vec3 c = mix(CHAR, STONE, smoothstep(0.25, 0.9, lit + vnoise(vec3(q * 4.0, seed + 11.0)) * 0.4 - 0.2));
	if (lit > 0.85 && r < edge - 0.12) c = STONE_LIT;
	// 亀裂：尾根状のノイズの細い線が赤熱する。熱が残るほど明るい
	float n = vnoise(vec3(q * 2.6, seed + 5.0));
	float crack = 1.0 - abs(n * 2.0 - 1.0);
	float glow = heat * (0.55 + 0.45 * vnoise(vec3(q * 5.0, time * 2.0 + seed)));
	if (crack > 0.9) c = glow > 0.7 ? HOT : glow > 0.4 ? FLAME : glow > 0.15 ? EMBER : EMBER_DEEP;
	else if (crack > 0.82 && glow > 0.3) c = EMBER_DEEP;
	// 進む側のふちは熱で焼けて光る
	if (heat > 0.3 && front > 0.35 && r > edge - 1.6 / half) c = heat > 0.75 ? HOT : FLAME;
	else if (r > edge - 1.0 / half) c = CHAR * 0.7;
	return vec4(c, 1.0);
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// 割れた殻の模様：x は最寄りの割れ目の中心までの近さ（F2-F1）、yz は殻の板ごとの値
vec3 crust(vec2 x, float seed) {
	vec2 n = floor(x), f = fract(x);
	float f1 = 8.0, f2 = 8.0;
	vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g + seed * 13.0);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < f1) { f2 = f1; f1 = d; id = n + g; }
			else if (d < f2) f2 = d;
		}
	}
	return vec3(sqrt(f2) - sqrt(f1), hash2(id + seed));
}

float fbm(vec2 p, float seed) {
	return vnoise(vec3(p, seed)) * 0.55 + vnoise(vec3(p * 2.1, seed + 3.0)) * 0.3 + vnoise(vec3(p * 4.3, seed + 7.0)) * 0.15;
}

// 熱（0〜1）から溶岩の色。白熱した黄から橙、赤、暗い赤へ冷える
vec3 lava(float t) {
	return t > 0.82 ? WHITE_HOT : t > 0.66 ? HOT : t > 0.48 ? FLAME : t > 0.3 ? EMBER : t > 0.14 ? EMBER_DEEP : SCORCH;
}

// 地表の焼け跡：形はゆがめた（ドメインワープした）ノイズの塊で、中心も輪郭もはっきりした図形にしない。
// 中は冷えて割れた黒い溶岩の殻で、割れ目からマグマがのぞき、中心ほど割れ目が広く溶けた溜まりになる。
// マグマの明るさはゆっくり流れるノイズで変わり（ちらつかせない）、熱（heat）が下がると外から冷えて割れ目が細く暗くなり、最後に焦げ跡ごと薄れる
vec4 scorch(vec2 cell, float half, float seed, float heat) {
	vec2 q = cell / half;
	vec2 w = q + (vec2(fbm(q * 1.6, seed), fbm(q * 1.6, seed + 11.0)) - 0.5) * 0.7;
	float r = length(w);
	float edge = 0.5 + 0.42 * fbm(w * 1.7 + 3.0, seed + 5.0);
	float fade = smoothstep(0.0, 0.2, heat);
	if (r > edge * 1.4) return vec4(0.0);
	float k = r / edge;
	if (k > 1.0) {
		// 外：煤けた地面がまだらに薄れ、飛び散った溶岩の粒が少し残る
		float splat = vnoise(vec3(cell * 0.32, seed + 9.0));
		if (splat > 0.78 && k < 1.3) {
			float t = heat * 0.7 * (splat - 0.78) / 0.22 + heat * 0.25;
			return vec4(lava(t), step(bayer(cell), fade));
		}
		float soot = (1.4 - k) / 0.4 * (0.35 + 0.4 * fbm(cell * 0.12, seed + 2.0));
		return vec4(SCORCH, step(bayer(cell), soot * 0.7 * fade));
	}
	vec3 cr = crust(w * 4.2, seed);
	// 割れ目の幅：中心ほど広く、熱が残るほど広い。中心は溶けた溜まり
	float width = mix(0.42, 0.07, smoothstep(0.0, 1.0, k)) * (0.35 + 0.65 * heat);
	float pool = 0.22 * heat * (0.8 + 0.4 * fbm(w * 3.0, seed + 4.0));
	float flow = fbm(w * 2.6 + vec2(time * 0.07, -time * 0.05), seed + 8.0);
	if (cr.x < width || r < pool) {
		float depth = r < pool ? 1.0 : 1.0 - cr.x / max(width, 0.001) * 0.6;
		float t = heat * (1.05 - 0.55 * k) * depth * (0.7 + 0.5 * flow);
		return vec4(lava(t), step(bayer(cell), fade + 0.01));
	}
	// 殻の板：板ごとに少し明るさが違い、割れ目の近くは下のマグマに照らされて赤らむ
	vec3 c = mix(CHAR, STONE, cr.y * 0.6 + 0.15 * flow);
	if (cr.x < width * 1.7 && heat > 0.15) c = mix(c, EMBER_DEEP, 0.55 * heat);
	else if (cr.x < width * 2.4) c = CHAR * 0.8;
	return vec4(c, step(bayer(cell), fade * (0.95 - 0.25 * k)));
}

// 衝突の閃光：ゆがんだ白い光の塊が一瞬でしぼむ（とげや円の形を見せない）
vec4 flash(vec2 cell, float half, float seed, float k) {
	vec2 q = cell / half;
	vec2 w = q + (vec2(fbm(q * 2.0, seed), fbm(q * 2.0, seed + 5.0)) - 0.5) * 0.9;
	float r = length(w);
	float reach = (0.55 + 0.45 * fbm(w * 2.5, seed + 2.0)) * (1.0 - k * 0.55);
	if (r > reach) return vec4(0.0);
	float t = r / reach;
	vec3 c = t < 0.4 ? WHITE_HOT : t < 0.7 ? HOT : FLAME;
	return vec4(c, step(bayer(cell), (1.0 - k) * (1.15 - t * 0.6)));
}

// 着弾の熱の照り返し：地面が一瞬橙に照らされ、外へ広がりながら消える
vec4 glow(vec2 cell, float half, float seed, float k) {
	vec2 q = cell / half;
	float r = length(q + (vec2(fbm(q * 1.5, seed), fbm(q * 1.5, seed + 3.0)) - 0.5) * 0.6);
	float reach = 0.5 + 0.5 * k;
	if (r > reach) return vec4(0.0);
	float a = (1.0 - k) * (1.0 - r / reach) * 0.75;
	return vec4(r < reach * 0.4 ? FLAME : EMBER, step(bayer(cell), a));
}

// 隕石の炎：四角の +x が進む向きで、岩の中心は前の端から HEAD×岩の半径だけ後ろ。岩をまるごと包む炎の膜が、
// うしろへそのまま涙の形に伸びて尾になる（岩から炎が生えて見えないように、前と横も包む）。
// 尾は先ほど橙・赤と細くなり、煙に変わって薄れる。乱れは尾に沿って速く後ろへ流れる
const float HEAD = 1.6;
vec4 plume(vec2 cell, float half, float seed, float rock) {
	vec2 center = vec2(half - HEAD * rock, 0.0);
	vec2 p = cell - center;
	float turb = fbm(vec2(cell.x * 0.09 + time * 9.0, cell.y * 0.18), seed);
	float fray = 0.82 + 0.3 * vnoise(vec3(cell * 0.38 + vec2(time * 30.0, 0.0), seed + 21.0));
	// 岩を包む膜の半径。前ほど薄く岩に沿い、横からうしろへ厚くなる
	float wrap = rock * (1.18 + 0.12 * turb) * fray;
	float along = max(0.0, -p.x) / max(half * 2.0 - HEAD * rock, 1.0);
	if (along > 1.0) return vec4(0.0);
	float width = p.x >= 0.0 ? sqrt(max(wrap * wrap - p.x * p.x, 0.0)) : wrap * (1.0 + 0.18 * smoothstep(0.0, 0.15, along)) * pow(1.0 - along, 0.85) * (0.8 + 0.35 * turb);
	float side = abs(p.y);
	if (side > width) return vec4(0.0);
	float inner = 1.0 - side / max(width, 0.001);
	// 岩のすぐまわりと尾の芯ほど熱い
	float near = 1.0 - smoothstep(rock * 0.8, wrap, length(p));
	float t = max(inner * (1.0 - along * 0.9), near) * (0.75 + 0.4 * turb);
	vec3 c = along > 0.72 ? SMOKE : lava(t * 1.15 + 0.12);
	float a = along > 0.72 ? (1.0 - along) * 1.6 : 1.0 - smoothstep(0.55, 0.75, along) * 0.3;
	return vec4(c, step(bayer(cell), a * (0.6 + 0.4 * inner)));
}

// 煙：ゆっくり広がりながら薄れる、もこもことした暗い灰色のかたまり
vec4 smoke(vec2 cell, float half, float seed, float k) {
	float r = length(cell) / half;
	float n = vnoise(vec3(cell / half * 2.2, seed + k * 1.5));
	float reach = (0.45 + 0.4 * n) * (0.55 + 0.45 * k);
	if (r > reach) return vec4(0.0);
	float alpha = (1.0 - k) * 0.55 * (1.0 - r / reach * 0.6);
	return vec4(mix(SMOKE, STONE * 0.6, n), step(bayer(cell), alpha));
}

// 落下地点に落ちる影：近づくほど濃く小さくまとまり、中心がわずかに熱で赤らむ
vec4 shade(vec2 cell, float half, float seed, float k, float angle) {
	// 落ちてくる岩と同じ輪郭（同じ種・同じ回転）の赤黒い影が、小さく現れて着弾の瞬間に岩の大きさになる
	float grow = mix(0.18, 1.0, pow(k, 1.2));
	vec2 p = rot(cell, -angle) / grow;
	float r = length(p) / half;
	float edge = rock_edge(atan(p.y, p.x), seed);
	if (r > edge) return vec4(0.0);
	float t = r / edge;
	// ふちは暗い赤で、近づくほど赤く熱を帯びる。中は黒い
	vec3 c = t > 0.72 ? (k > 0.75 ? EMBER : EMBER_DEEP) : t > 0.45 ? mix(SCORCH, EMBER_DEEP, k * 0.6) : SCORCH;
	return vec4(c, step(bayer(cell), 0.45 + 0.45 * k));
}

void fragment() {
	float kind_half = v_custom.x;
	int kind = int(floor(kind_half / 1000.0 + 0.001));
	float half = kind_half - float(kind) * 1000.0;
	vec2 cell = floor((UV - 0.5) * 2.0 * half) + 0.5;
	float seed = v_custom.y, k = v_custom.z, w = v_custom.w;
	vec4 c;
	if (kind == 0) c = rock(cell, half, seed, k, w);
	else if (kind == 1) c = scorch(cell, half, seed, k);
	else if (kind == 2) c = flash(cell, half, seed, k);
	else if (kind == 3) c = smoke(cell, half, seed, k);
	else if (kind == 5) c = plume(cell, half, seed, w);
	else if (kind == 6) c = glow(cell, half, seed, k);
	else c = shade(cell, half, seed, k, w);
	if (c.a <= 0.001) discard;
	COLOR = vec4(linear_output ? to_linear(c.rgb) : c.rgb, c.a);
}
