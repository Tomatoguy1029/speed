// 英雄の星座の獲得演出で、星座に重ねる星図の線画。線画は白い線と透明な背景で、色はここで英雄ごとに乗せる。
// 描き出し（reveal）：最初の星から遠い所へ、ぎざぎざの先端で線画が現れる。先端は白く光る。
// 散り（dissolve）：ノイズの順に線画の画素が抜ける（抜けた所から粒が機体へ流れる。hero_acquire.gd）。
// HDR の画面ではリニアへ直して出す。
shader_type canvas_item;
render_mode blend_add;

#include "res://shaders/burst_noise.gdshaderinc"
#include "res://shaders/hero_color.gdshaderinc"
// 描き出しの進み（0〜1）、散りの進み（0〜1）、光の強さ
uniform float reveal = 0.0;
uniform float dissolve = 0.0;
uniform float glow = 1.0;
// 描き出しを始める画像の位置（UV）と、そこから一番遠い所までの距離（画像の高さを1とした長さ）
uniform vec2 origin = vec2(0.5);
uniform float reach = 1.0;
// 画像の幅÷高さ
uniform float aspect = 1.0;
uniform vec4 tint = vec4(1.0, 0.85, 0.5, 1.0);
uniform vec4 hot = vec4(1.0, 1.0, 0.9, 1.0);
uniform bool linear_output = false;

void fragment() {
	float line = texture(TEXTURE, UV).a;
	vec2 p = vec2(UV.x * aspect, UV.y);
	float d = distance(p, vec2(origin.x * aspect, origin.y)) / max(reach, 0.001);
	float n = vnoise(vec3(p * 24.0, 3.0)) * 0.6 + vnoise(vec3(p * 70.0, 9.0)) * 0.4;
	// 描き出しの先端までの距離（正なら現れている）
	float front = reveal * 1.15 - (d + (n - 0.5) * 0.12);
	float shown = step(0.0, front);
	float edge = 1.0 - smoothstep(0.0, 0.06, front);
	// 散り：ノイズの低い所から抜ける
	float kept = step(dissolve, n * 0.9 + 0.05);
	vec3 c = mix(tint.rgb * glow, hot.rgb * 1.6, edge * shown);
	float a = line * shown * kept;
	COLOR = vec4(linear_output ? to_linear(c) : c, a);
}
