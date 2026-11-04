// ボーナスステージの画面効果（全画面の処理）。
// dive：ワープホールが画面中央へ寄りながら広がり、トンネルを潜って閃光になる（0〜1）。
// bonus：ボーナス中の光のにじみ・色収差・周辺減光の強さ（0〜1）。flash：入った直後と出るときの白い閃光（0〜1）。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/warp_tunnel.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float time = 0.0;
uniform float dive = 0.0;
// 潜り始めの穴の中心（画面の割合）と半径（画面の高さに対する割合）
uniform vec2 dive_from = vec2(0.5);
uniform float dive_radius = 0.15;
// 画面の高さのドット数（潜る演出のドットの粗さ）
uniform float cells = 216.0;
uniform float bonus = 0.0;
uniform float flash = 0.0;
uniform float aspect = 1.7778;
uniform float bloom = 1.4;
uniform float aberration = 0.012;
uniform float vignette = 0.55;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col;
	if (bonus > 0.0) {
		// 色収差：画面の端ほど赤と青がずれる
		float k = aberration * bonus;
		vec2 c = uv - 0.5;
		col = vec3(texture(screen, 0.5 + c * (1.0 - k)).r, texture(screen, uv).g, texture(screen, 0.5 + c * (1.0 + k)).b);
		// 光のにじみ：縮小した画面の明るい部分を足す
		vec3 soft = textureLod(screen, uv, 3.0).rgb * 0.5 + textureLod(screen, uv, 4.5).rgb * 0.5;
		col += max(soft - 0.55, vec3(0.0)) * bloom * bonus;
		float d = length(c * 2.0);
		col *= 1.0 - wt_sm(0.6, 1.4, d) * vignette * bonus;
	} else {
		col = texture(screen, uv).rgb;
	}
	if (dive > 0.0) {
		float p = wt_sm(0.0, 1.0, dive);
		vec2 grid = vec2(cells * aspect, cells);
		vec2 quv = (floor(uv * grid) + 0.5) / grid;
		vec2 center = mix(dive_from, vec2(0.5), p);
		float radius = dive_radius * (1.0 + p * p * 12.0);
		vec2 q = quv - center;
		q.x *= aspect;
		float dist = length(q);
		q /= radius;
		vec4 tunnel = warp_tunnel(q, time, 1.0 + p * 5.0, wt_sway(time));
		col = mix(col, tunnel.rgb, tunnel.a);
		// 速度の筋
		float ang = atan(q.y, q.x);
		float streak = wt_sm(0.92, 1.0, wt_noise(vec3(cos(ang) * 40.0, sin(ang) * 40.0, time * 3.0))) * wt_sm(0.09, 0.74, dist) * p;
		col += WT_CORE * streak * 0.8;
		col = mix(col, WT_CORE, wt_sm(0.75, 1.0, dive));
	}
	col = mix(col, WT_CORE, flash);
	COLOR = vec4(col, 1.0);
}
