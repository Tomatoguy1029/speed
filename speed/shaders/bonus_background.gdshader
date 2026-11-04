// ボーナスステージの背景。通常の背景に重ねて amount で現す。
// 金とマゼンタの星雲がゆっくり流れ、画面の上の外から柔らかい光の筋が差す。金の粒が上へ流れ、星がまたたく。
// 星雲・粒・星は世界座標に視差を掛けて置き、光の筋は画面に固定する。
// ドットは機体の絵と同じ大きさ（dot_world）に揃え、模様の大きさは画面の高さの 1/cells（unit_world）を単位に決める。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/warp_tunnel.gdshaderinc"

uniform float time = 0.0;
uniform float amount = 0.0;
uniform vec2 view_center = vec2(0.0);
// 1ドットの世界での大きさ
uniform float dot_world = 2.4;
// 模様の単位の世界での大きさ
uniform float unit_world = 8.0;
uniform float cells = 216.0;
uniform float aspect = 1.7778;
uniform float parallax = 0.35;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

float hash2(vec2 p, float k) {
	return wt_hash3(vec3(p, k));
}

void fragment() {
	float t = time;
	// 背景をドットに揃える
	vec2 m = (floor((world - view_center * (1.0 - parallax)) / dot_world) + 0.5) * dot_world / unit_world;
	vec2 sp = SCREEN_UV * vec2(cells * aspect, cells);
	float n = wt_fbm(vec3(m.x / 70.0 + t * 0.05, m.y / 70.0, t * 0.15));
	float n2 = wt_fbm(vec3(m.x / 35.0 + 7.0, m.y / 35.0 - t * 0.08, t * 0.2 + 9.0));
	vec3 col = vec3(0.20, 0.07, 0.16) * (1.2 - SCREEN_UV.y * 0.5);
	col += vec3(0.75, 0.28, 0.55) * wt_sm(0.35, 0.80, n) * 0.7;
	col += vec3(1.0, 0.72, 0.28) * wt_sm(0.45, 0.85, n2 * n * 1.7) * 0.9;
	// 光の筋：光源は画面のずっと上（画面外）。幅の広い筋がゆっくり揺れ、上ほど明るい。
	vec2 source = vec2(cells * aspect * 0.5 + sin(t * 0.25) * 60.0, -260.0);
	float ang = atan(sp.y - source.y, sp.x - source.x);
	float shaft = 0.5 + 0.5 * sin(ang * 22.0 + sin(t * 0.4) * 0.6 + wt_fbm(vec3(ang * 6.0, sp.y / 90.0, t * 0.3)) * 2.5);
	shaft = wt_sm(0.35, 1.0, shaft) * wt_sm(0.3, 0.75, wt_fbm(vec3(ang * 10.0 + 3.0, sp.y / 50.0 - t * 0.2, t * 0.25)));
	float fade = wt_sm(cells * 1.4, -20.0, sp.y);
	col += WT_GOLD * shaft * fade * 0.75 + vec3(1.0, 0.6, 0.4) * fade * 0.10;
	// またたく星
	if (hash2(floor(m), 11.0) > 0.988) {
		col += WT_CORE * 0.7 * (0.6 + 0.4 * sin(t * 4.0 + m.x));
	}
	// 上へ流れる金の粒：列ごとに速さを変え、区画ごとに1粒
	float column = floor(m.x / 36.0);
	float speed = 6.0 + 16.0 * hash2(vec2(column, 0.0), 21.0);
	vec2 rise = vec2(m.x, m.y + t * speed);
	vec2 cell = floor(rise / 36.0);
	float phase = hash2(cell, 22.0) * TAU;
	vec2 grain = cell * 36.0 + vec2(hash2(cell, 23.0), hash2(cell, 24.0)) * 36.0;
	grain.x += sin(t * 1.5 + phase) * 4.0;
	vec2 d = abs(floor(rise) + 0.5 - floor(grain) - 0.5);
	float glint = 0.5 + 0.5 * sin(t * 5.0 + phase);
	if (d.x < 0.5 && d.y < 0.5) {
		col += WT_GOLD * glint * 1.2;
	} else if (glint > 0.8 && d.x + d.y < 1.5) {
		col += WT_GOLD * 0.5;
	}
	COLOR = vec4(col, amount);
}
