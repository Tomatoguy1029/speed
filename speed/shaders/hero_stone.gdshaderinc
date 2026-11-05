// pixelfx の status/petrified を元にした、ペルセウス座で石になった敵の色。敵のベースと装甲の shader で共有する。
// インスタンスの色の b に石になってからの秒（0 なら石ではない）を受け、元の絵の色を石の灰色へ置き換える。
// 石は絵の中心から外へ広がり、広がる縁は白くちらつく。灰色の段は元の明るさとドットのまだらで選び、
// 砕ける直前には中心から放射状のひびが走る。ノイズ画像は使わず、ドットごとの乱数だけで描く。
const vec3 HERO_STONE[8] = vec3[](vec3(0.086, 0.078, 0.110), vec3(0.165, 0.153, 0.200), vec3(0.263, 0.247, 0.302), vec3(0.373, 0.353, 0.416),
	vec3(0.490, 0.471, 0.537), vec3(0.635, 0.616, 0.671), vec3(0.804, 0.784, 0.824), vec3(0.941, 0.929, 0.953));
const float HERO_STONE_CREEP = 0.12;
const float HERO_STONE_CRACK_FROM = 0.35;
const float HERO_STONE_CRACK_TIME = 0.25;

#include "res://shaders/hero_color.gdshaderinc"

float hero_stone_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 hero_stone_srgb(vec3 src, vec2 uv, vec2 size, float since, float time) {
	vec2 px = floor(uv * size);
	vec2 rel = (px + 0.5) / size - 0.5;
	float from_center = length(rel) / 0.7071;
	float ang = atan(rel.y, rel.x);
	float creep = clamp(since / HERO_STONE_CREEP, 0.0, 1.0);
	float wobble = 0.08 * (hero_stone_hash(vec2(floor(ang * 4.0), 3.0)) - 0.5);
	float gap = creep * 1.25 - 0.05 + wobble - from_center;
	if (gap < 0.0) return src;
	if (creep < 1.0 && gap < 0.05) return hero_stone_hash(px + floor(time * 24.0)) < 0.5 ? HERO_STONE[7] : HERO_STONE[6];
	float tone = clamp((dot(src, vec3(0.299, 0.587, 0.114)) - 0.06) / 0.78, 0.0, 1.0);
	float mottle = hero_stone_hash(px * 0.37 + 5.0) * 2.0 - 1.0;
	float level = 1.0 + round(tone * 4.6 + mottle * 1.1);
	// ひび：中心から6本、少しずつ曲がりながら外へ伸びる。ひびの片側の1ドットは欠けて明るい
	float crack = clamp((since - HERO_STONE_CRACK_FROM) / HERO_STONE_CRACK_TIME, 0.0, 1.0);
	if (crack > 0.0) {
		float d = length(rel) * size.x;
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			if (from_center > crack * mix(0.7, 1.05, hero_stone_hash(vec2(fi, 9.0)))) continue;
			float base = fi / 6.0 * 6.2831853 + hero_stone_hash(vec2(fi, 2.0)) * 0.7;
			float bend = sin(d * 0.35 + fi * 1.7) * 0.25;
			float sd = (mod(ang - base - bend + 3.14159265, 6.2831853) - 3.14159265) * d;
			if (abs(sd) < 0.6) return HERO_STONE[0];
			if (sd > 0.0 && sd < 1.5) level = max(level, 6.0);
		}
	}
	// 石の表面にまれに走るきらめき
	if (hero_stone_hash(px * 1.3 + floor(time * 2.0)) > 0.994) level = 7.0;
	return HERO_STONE[int(clamp(level, 0.0, 7.0))];
}

// src は元の色、uv は絵の UV、size は絵のドット数、since は石になってからの秒、time はちらつきの時計、
// linear は HDR の画面へ描くとき true（元の明るさを sRGB で測り、石の色をリニアで返す）
vec3 hero_stone(vec3 src, vec2 uv, vec2 size, float since, float time, bool linear) {
	if (since <= 0.0) return src;
	vec3 stone = hero_stone_srgb(linear ? to_srgb(src) : src, uv, size, since, time);
	return linear ? to_linear(stone) : stone;
}
