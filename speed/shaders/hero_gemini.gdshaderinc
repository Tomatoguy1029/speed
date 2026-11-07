// ふたご座の光と影の機体の材質。機体の絵（airship.png）の1ドット＝1セルで読み、セルは絵の左上を原点にした整数の位置で渡す。
// 光と影は対になる2機で、どちらも機体の形だけを残して材質を変える（本物の機体は run_frame_view が隠す）。
// 光の機体は、白〜黄金に光る物質で輪郭が鮮明、まわりを金の光のオーラが後ろへ流れる。
// 影の機体は、黒〜深紫の物質でできた同じ形の機体で、輪郭がうねり、まわりに暗いオーラがくすぶる。
#include "res://shaders/burst_noise.gdshaderinc"
#include "res://shaders/hero_color.gdshaderinc"
uniform sampler2D ship_tex : filter_nearest;
// 絵の外のセルの、絵までの距離（R × PAD）。絵のまわりへ PAD セルずつ広げてある
uniform sampler2D sdf_tex : filter_nearest;
uniform bool linear_output = false;
uniform float time = 0.0;

const vec2 SHIP = vec2(31.0, 70.0);
const float PAD = 16.0;

const vec3 SHADOW_DEEP = vec3(0.035, 0.012, 0.07);
const vec3 SHADOW_BODY = vec3(0.16, 0.06, 0.27);
const vec3 SHADOW_RIM = vec3(0.56, 0.30, 0.86);
const vec3 SHADOW_GLINT = vec3(0.80, 0.52, 1.0);
const vec3 LIGHT_CORE = vec3(1.0, 0.99, 0.9);
const vec3 LIGHT_MID = vec3(1.0, 0.85, 0.42);
const vec3 LIGHT_OUT = vec3(0.98, 0.6, 0.16);
const vec3 LIGHT_DEEP = vec3(0.93, 0.6, 0.16);
const vec3 LIGHT_BODY = vec3(1.0, 0.82, 0.36);

float bayer(vec2 cell) {
	ivec2 p = ivec2(mod(cell, 4.0));
	int i = p.x + p.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

// 透明度を4×4の網点でドットごとの有無へ落とす
float dither(float a, vec2 cell) {
	return step(bayer(cell), a);
}

vec4 ship_at(vec2 cell) {
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= SHIP.x || cell.y >= SHIP.y) return vec4(0.0);
	return texelFetch(ship_tex, ivec2(cell), 0);
}

float ship_dist(vec2 cell) {
	vec2 t = cell + PAD;
	if (t.x < 0.0 || t.y < 0.0 || t.x >= SHIP.x + 2.0 * PAD || t.y >= SHIP.y + 2.0 * PAD) return PAD;
	return texelFetch(sdf_tex, ivec2(t), 0).r * PAD;
}

float luma(vec3 c) {
	return dot(c, vec3(0.3, 0.55, 0.15));
}

// 影の輪郭は、ゆっくりうねるずれで読む位置を動かして不規則にする
vec2 shadow_wobble(vec2 cell, float seed, float amount) {
	vec3 q = vec3(cell * 0.16, time * 1.3 + seed);
	return cell + floor((vec2(vnoise(q), vnoise(q + vec3(17.0, 5.0, 3.0))) - 0.5) * 2.0 * amount + 0.5);
}

// 影の機体の体（a は 0 か 1）。crumble は崩れる割合（0 で崩れない）
vec4 shadow_body(vec2 cell, float seed, float crumble) {
	vec2 w = shadow_wobble(cell, seed, 1.6);
	if (ship_at(w).a < 0.5) return vec4(0.0);
	if (crumble > 0.0) {
		float n = vnoise(vec3(cell * 0.21, seed * 3.0));
		if (n < crumble * 1.15 - 0.08) return vec4(0.0);
		if (n < crumble * 1.15) return vec4(SHADOW_GLINT, 1.0);
	}
	bool rim = ship_at(w + vec2(1.0, 0.0)).a < 0.5 || ship_at(w - vec2(1.0, 0.0)).a < 0.5 || ship_at(w + vec2(0.0, 1.0)).a < 0.5 || ship_at(w - vec2(0.0, 1.0)).a < 0.5;
	if (rim) return vec4(SHADOW_RIM, 1.0);
	float l = luma(ship_at(cell).rgb);
	// 体の中をゆっくり渦巻く紫の筋
	float swirl = vnoise(vec3(cell.x * 0.14, cell.y * 0.07 - time * 0.9, seed + 4.0));
	vec3 c = mix(SHADOW_DEEP, SHADOW_BODY, smoothstep(0.15, 0.85, l * 0.8 + swirl * 0.5));
	if (swirl > 0.72) c = mix(c, SHADOW_RIM, 0.45);
	return vec4(c, 1.0);
}

// 光の機体の体：絵の明暗を金の濃淡に置きかえ、体の中を光の筋が前から後ろへ流れる。ふちは白く鮮明に光る
vec4 light_body(vec2 cell, float seed) {
	if (ship_at(cell).a < 0.5) return vec4(0.0);
	bool rim = ship_at(cell + vec2(1.0, 0.0)).a < 0.5 || ship_at(cell - vec2(1.0, 0.0)).a < 0.5 || ship_at(cell + vec2(0.0, 1.0)).a < 0.5 || ship_at(cell - vec2(0.0, 1.0)).a < 0.5;
	if (rim) return vec4(LIGHT_CORE, 1.0);
	float l = luma(ship_at(cell).rgb);
	float stream = vnoise(vec3(cell.x * 0.2, cell.y * 0.09 - time * 2.6, seed + 4.0));
	vec3 c = mix(LIGHT_DEEP, LIGHT_BODY, smoothstep(0.1, 0.8, l * 0.9 + stream * 0.45));
	if (stream > 0.7) c = mix(c, LIGHT_CORE, 0.7);
	return vec4(c, 1.0);
}

// 影のまわりにくすぶる暗いオーラ。後ろ（絵の下）へゆっくり流れる
vec4 shadow_aura(vec2 cell, float seed, float strength) {
	vec2 w = shadow_wobble(cell, seed + 9.0, 3.0);
	float d = ship_dist(w);
	if (d <= 0.0) return vec4(0.0);
	float back = clamp((cell.y - SHIP.y * 0.3) / SHIP.y, 0.0, 1.0);
	float n = vnoise(vec3(cell.x * 0.22, (cell.y - time * 9.0) * 0.12, seed + 2.0));
	float reach = (2.0 + 5.5 * n + 5.0 * back * n) * strength;
	if (d > reach) return vec4(0.0);
	float k = d / max(reach, 0.01);
	vec3 c = k < 0.4 ? SHADOW_BODY : SHADOW_DEEP;
	// ふちに時々紫の光が走り、背景の暗さに溶けないようにする
	if (k > 0.75 && vnoise(vec3(cell * 0.4, time * 3.0 + seed)) > 0.68) c = SHADOW_RIM;
	float a = (k < 0.4 ? 0.8 : 0.55) * (1.0 - k * 0.5);
	return vec4(c, dither(a, cell));
}

// 光の機体のまわりを後ろへ流れる光のオーラ
vec4 light_aura(vec2 cell, float seed, float strength) {
	float d = ship_dist(cell);
	if (d <= 0.0) return vec4(0.0);
	float back = clamp((cell.y - SHIP.y * 0.25) / SHIP.y, 0.0, 1.0);
	float n = vnoise(vec3(cell.x * 0.3, (cell.y - time * 34.0) * 0.1, seed));
	float reach = (1.5 + 3.5 * n + 8.0 * back * n * n) * strength;
	if (d > reach) return vec4(0.0);
	float k = d / max(reach, 0.01);
	vec3 c = k < 0.3 ? LIGHT_CORE : k < 0.65 ? LIGHT_MID : LIGHT_OUT;
	float a = k < 0.3 ? 0.9 : k < 0.65 ? 0.6 : 0.35;
	return vec4(c, dither(a, cell));
}

vec4 finish(vec4 c) {
	return vec4(linear_output ? to_linear(c.rgb) : c.rgb, c.a);
}
