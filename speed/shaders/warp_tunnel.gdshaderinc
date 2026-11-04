// ワープホールの金色トンネル。ワープホール本体とボーナスステージへ潜る演出で共有する。
// 穴の内側は奥行き z = 1/r の筒として描く。壁に銀河の腕を巻きつけ、金の輪を奥へ流し、出口を金と白で光らせる。

#include "res://shaders/burst_noise.gdshaderinc"

const vec3 WT_DEEP = vec3(0.10, 0.03, 0.06);
const vec3 WT_WALL1 = vec3(1.0, 0.55, 0.18);
const vec3 WT_WALL2 = vec3(1.0, 0.35, 0.50);
const vec3 WT_GOLD = vec3(1.0, 0.82, 0.36);
const vec3 WT_CORE = vec3(1.0, 0.98, 0.90);
const vec3 WT_RIM = vec3(1.0, 0.86, 0.45);

// e0 > e1 のときは逆向きに上がる smoothstep。
float wt_sm(float e0, float e1, float v) {
	float t = clamp((v - e0) / (e1 - e0), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

float wt_hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// 形の崩れ・星雲のノイズは、制作時に焼いた爆発と共通の64^3の格子（周期64）を1回の3D samplingで読む。
float wt_noise(vec3 x) {
	return vnoise(x);
}

float wt_fbm(vec3 x) {
	return 0.55 * wt_noise(x) + 0.3 * wt_noise(x * 2.1) + 0.15 * wt_noise(x * 4.3);
}

// 奥の中心のずれ（穴の半径を1とする）。奥ほど大きくずれて、筒が曲がって見える。
vec2 wt_sway(float t) {
	return vec2(cos(t * 0.9) * 0.125, sin(t * 1.3) * 0.104);
}

// p：穴の中心からの位置（穴の半径を1とする）。t：時刻（秒）。flow：奥へ流れる速さの倍率。
// rgb は穴の中の色、a は穴の内側の割合（縁で0へ落ちる）。
vec4 warp_tunnel(vec2 p, float t, float flow, vec2 sway) {
	float rr0 = length(p);
	float a0 = atan(p.y, p.x);
	float k = pow(1.0 - clamp(rr0, 0.0, 1.0), 1.5);
	vec2 q = p - sway * k;
	float rr = rr0 > 0.9 ? rr0 : length(q);
	float aa = rr0 > 0.9 ? a0 : atan(q.y, q.x);
	float inside = wt_sm(1.02, 0.94, rr0);
	float z = 1.0 / max(rr, 0.03);
	float fog = exp(-(z - 1.0) * 0.33);
	float ca = cos(aa);
	float sa = sin(aa);
	float tf = t * flow;
	float zf = z * 0.9 - tf * 1.4;
	float n1 = wt_fbm(vec3(ca * 2.2 + 5.0, sa * 2.2 + 5.0, zf));
	float n2 = wt_fbm(vec3(ca * 4.0 + 11.0, sa * 4.0 + 3.0, zf * 1.7 + 20.0));
	float n3 = wt_noise(vec3(ca * 14.0 + 1.0, sa * 14.0 + 7.0, zf * 5.0));
	// 銀河の腕：ノイズで縁を崩す。奥のもう1層は違う巻きと速さで回る。
	float u = aa * 2.0 + log(z) * 5.0 - tf * 1.6 + (n1 - 0.5) * 3.0;
	float arm = wt_sm(0.32, 0.70, (0.5 + 0.5 * sin(u)) * (0.5 + 0.9 * n2) + (n3 - 0.5) * 0.45);
	float u2 = aa * 2.0 + log(z) * 8.0 + tf * 0.9 + (n2 - 0.5) * 2.5;
	float arm2 = wt_sm(0.45, 0.9, (0.5 + 0.5 * sin(u2)) * n1 * 1.4 + (n3 - 0.5) * 0.35) * wt_sm(1.4, 3.0, z);
	float tint = clamp(0.5 + 0.5 * sin(aa + z * 0.4 + t * 0.6) + (n2 - 0.5) * 0.8, 0.0, 1.0);
	vec3 wall = mix(WT_WALL1, WT_WALL2, tint);
	// 筒の節：手前が明るく奥が暗い。左上から光が当たる。
	float rv = fract(z * 0.8 - tf * 2.2);
	float shade = (0.45 + 0.55 * pow(1.0 - rv, 1.3)) * (0.65 + 0.35 * cos(aa + 2.3));
	float ring = wt_sm(0.80, 0.95, rv) * (1.0 - wt_sm(0.95, 1.0, rv)) * wt_sm(0.25, 0.55, n1 + (n3 - 0.5) * 0.3);
	vec3 col = WT_DEEP * (0.6 + 0.8 * n1) * shade + wall * arm * 1.35 * shade + WT_WALL2 * arm2 * 0.7 + WT_GOLD * ring * 0.8;
	col *= fog;
	float lip = wt_sm(0.80, 0.97, rr0) * (1.0 - wt_sm(0.97, 1.0, rr0));
	col *= 1.0 - 0.6 * lip;
	col += WT_GOLD * exp(-pow(rr / 0.20, 2.0)) * 1.2 + WT_CORE * exp(-pow(rr / 0.07, 2.0)) * 1.5;
	float rim = exp(-pow((rr0 - 1.0) / 0.05, 2.0)) * (0.75 + 0.25 * sin(a0 * 8.0 - t * 6.0));
	col += WT_RIM * rim * 1.1;
	return vec4(col, inside);
}
