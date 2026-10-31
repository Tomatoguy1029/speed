// 自爆する雑魚の爆発。表示値はこのshaderと使用元の保存キーで独立して調整する。
// ドット単位の爆発。煙・火球と輪・燃えかす・火の粉を順に描く。
// 粒は小さな四角へ分け、軌道と寿命を頂点で計算する。fragment で全粒を走査しない。
// 火球は fire_burst と同じく、焼いた値ノイズで縁を崩し、密度で4段の色に分け、一番外を半透明にする。
// 長さはドット単位、時間は秒。粒の並びは seed から決まり、age だけで各時刻の絵が決まる。
// tuning の値は戦闘エフェクトツールで装備・攻撃ごとに上書きする（ShaderTuning）。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/burst_noise.gdshaderinc"
uniform float half_cells = 120.0;
uniform float radius = 38.0;
uniform float age = 0.0;
// 爆発の中心のドット座標と種（ノイズと粒の並びを爆発ごとに変える）
uniform vec2 origin = vec2(0.0);
uniform float seed = 0.0;
// 0: 火球・閃光・輪、1: 煙、2: 燃えかす、3: 火の粉。全パスで同じ調整値と種を使う。
uniform int pass_mode = 0;
varying vec2 burst_position;
varying flat vec4 particle_state;
varying flat vec4 particle_extra;
varying flat vec4 particle_color;
varying flat float max_reach;
group_uniforms tuning;
uniform vec4 c0 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 c1 : source_color = vec4(1.0, 0.949, 0.659, 1.0);
uniform vec4 c2 : source_color = vec4(1.0, 0.690, 0.188, 1.0);
uniform vec4 c3 : source_color = vec4(0.824, 0.275, 0.110, 1.0);
uniform vec4 smoke_dark : source_color = vec4(0.227, 0.165, 0.173, 1.0);
uniform vec4 smoke_mid : source_color = vec4(0.369, 0.275, 0.267, 1.0);
uniform vec4 smoke_light : source_color = vec4(0.541, 0.416, 0.369, 1.0);
uniform float noise_scale : hint_range(0.04, 0.5, 0.01) = 0.16;
uniform float roughness : hint_range(0.0, 2.0, 0.05) = 0.95;
uniform float outer_alpha : hint_range(0.0, 1.0, 0.05) = 0.5;
uniform float grow_seconds : hint_range(0.05, 0.6, 0.01) = 0.2;
uniform float start_size : hint_range(0.0, 1.0, 0.05) = 0.25;
uniform float fire_seconds : hint_range(0.2, 2.0, 0.05) = 0.75;
uniform float burn_speed : hint_range(0.0, 3.0, 0.05) = 0.85;
uniform float cool_speed : hint_range(0.0, 3.0, 0.05) = 0.8;
uniform float hole_size : hint_range(0.0, 0.9, 0.05) = 0.65;
uniform float flash_seconds : hint_range(0.0, 0.2, 0.01) = 0.04;
uniform float flash_size : hint_range(0.0, 1.5, 0.05) = 0.5;
uniform float ring_seconds : hint_range(0.05, 1.0, 0.01) = 0.3;
uniform float ring_size : hint_range(0.0, 2.5, 0.05) = 1.25;
uniform float ring_alpha : hint_range(0.0, 1.0, 0.05) = 0.95;
uniform float spark_count : hint_range(0.0, 64.0, 1.0) = 40.0;
uniform float spark_speed : hint_range(0.0, 3.0, 0.05) = 1.0;
uniform float spark_seconds : hint_range(0.1, 1.5, 0.05) = 0.5;
uniform float cinder_count : hint_range(0.0, 96.0, 1.0) = 60.0;
uniform float cinder_speed : hint_range(0.0, 3.0, 0.05) = 1.0;
uniform float cinder_seconds : hint_range(0.1, 1.5, 0.05) = 0.7;
uniform float smoke_count : hint_range(0.0, 24.0, 1.0) = 13.0;
uniform float smoke_alpha : hint_range(0.0, 1.0, 0.05) = 0.7;
uniform float smoke_seconds : hint_range(0.1, 2.0, 0.05) = 0.8;
group_uniforms;

#include "res://shaders/blast_burst_body.gdshaderinc"
