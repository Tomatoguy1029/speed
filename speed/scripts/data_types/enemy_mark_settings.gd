@tool
## 敵の目印とエリートのピクセル演出。固定の素材値だけを保存する。
class_name EnemyMarkSettings
extends Resource

@export_range(16, 128, 1) var pixel_grid := 64
@export_range(0.15, 0.48, 0.01) var inner_radius := 0.30
@export_range(0.20, 0.70, 0.01) var outer_radius := 0.47
@export_range(1.0, 20.0, 0.5) var noise_scale := 9.0
@export_range(0.0, 5.0, 0.05) var motion_speed := 1.0
@export_range(0.0, 2.0, 0.05) var intensity := 0.9
@export var color := Color("#e9c872")
@export var highlight := Color("#fff0c6")
## 目印は画像空間の距離場を使い、本体と同じ倍率で表示する。
@export_range(1.0, 10.0, 0.25) var aura_width := 5.0
@export_range(0.0, 12.0, 0.25) var aura_variation := 6.25
@export_range(1.0, 4.0, 0.25) var pixel_size := 2.0
@export_range(0.25, 4.0, 0.05) var edge_falloff := 1.0
@export_range(0.5, 8.0, 0.25) var core_width := 3.0
@export_range(-180.0, 180.0, 1.0) var flow_angle := -90.0
@export_range(0.0, 1.0, 0.05) var flow_coherence := 1.0
@export_range(0.0, 170.0, 1.0) var flow_spread := 90.0
@export_range(0.1, 8.0, 0.1) var flow_field_scale := 1.0
@export_range(0.0, 2.0, 0.05) var flow_field_speed := 0.15
@export_range(8.0, 256.0, 1.0) var noise_span := 64.0
@export_range(0.1, 8.0, 0.05) var noise_frequency_1 := 1.2
@export_range(0.1, 8.0, 0.01) var noise_frequency_2 := 0.96
@export_range(0.0, 100.0, 0.5) var noise_speed_1 := 28.0
@export_range(0.0, 100.0, 0.5) var noise_speed_2 := 16.0
@export_range(0.0, 2.0, 0.05) var noise_weight_1 := 1.0
@export_range(0.0, 2.0, 0.05) var noise_weight_2 := 1.0
@export_range(-64.0, 64.0, 1.0) var noise_offset_x := 23.0
@export_range(-64.0, 64.0, 1.0) var noise_offset_y := 41.0
@export_range(0.0, 2.0, 0.05) var noise_bias := 0.5
@export_range(0.0, 4.0, 0.05) var noise_contrast := 1.0
@export_range(4.0, 128.0, 1.0) var breakup_span := 37.0
@export_range(0.0, 100.0, 0.5) var breakup_speed := 9.0
@export_range(0.0, 1.0, 0.05) var breakup_strength := 0.35
@export_range(-64.0, 64.0, 1.0) var breakup_offset_x := 17.0
@export_range(-64.0, 64.0, 1.0) var breakup_offset_y := 0.0
@export_range(0.0, 1.0, 0.05) var core_noise_threshold := 0.4
@export_range(0.0, 4.0, 0.05) var core_noise_gain := 1.6
@export_range(0.0, 1.0, 0.01) var edge_opacity := 0.8627451
@export_range(0.0, 1.0, 0.01) var core_opacity := 0.43137255
@export_range(0.0, 1.0, 0.01) var max_opacity := 0.89411765
@export_range(0.0, 0.5, 0.01) var pulse_amount := 0.07
@export_range(0.25, 12.0, 0.25) var pulse_seconds := 4.0
@export_range(1.0, 32.0, 1.0) var opacity_step := 12.0

## 編集名・説明とshader名の対応。内部の寸法・マスク参照・復号係数は含めない。
const AURA_GROUPS := ["輪郭", "動き・方向", "ノイズ", "発光・色"]
const AURA_FIELDS := {
	"aura_width": ["輪郭", "輪郭の幅", "輪郭から外へ広がる基礎幅。元画像の画素単位。", "aura_width"],
	"aura_variation": ["輪郭", "幅の揺らぎ", "ノイズで増やす外側の幅。", "aura_variation"],
	"pixel_size": ["輪郭", "ドット幅", "描画の格子幅。大きいほど粗いドット。", "pixel_scale"],
	"edge_falloff": ["輪郭", "外側の薄まり方", "大きいほど輪郭の近くへ光が集まり、外側が早く薄まる。", "lm_edge_falloff"],
	"core_width": ["輪郭", "明るい芯の幅", "船体に沿う明るい光の厚み。元画像の画素単位。", "lm_core_width"],
	"motion_speed": ["動き・方向", "全体の動きの速さ", "各ノイズ層と方向場の時間倍率。0で流れを止める。", "flicker_speed"],
	"flow_angle": ["動き・方向", "流れる向き（度）", "0は右、90は下、-90は上へ模様が流れる。船体の画像座標が基準。", "lm_flow_angle"],
	"flow_coherence": ["動き・方向", "方向の統一性", "1で全ノイズ層を指定方向へそろえる。0へ下げるほど各位置・層の方向場へ寄せる。", "lm_flow_coherence"],
	"flow_spread": ["動き・方向", "向きのばらつき（度）", "方向場が基準方向から曲がる最大角度。統一性1では作用しない。", "lm_flow_spread"],
	"flow_field_scale": ["動き・方向", "方向場の細かさ", "大きいほど細かい範囲で流れの向きが変わる。", "lm_flow_field_scale"],
	"flow_field_speed": ["動き・方向", "方向場の変化速度", "流れの向き自体が時間とともに変わる速さ。", "lm_flow_field_speed"],
	"noise_span": ["ノイズ", "ノイズの基礎サイズ", "大きいほど大きな模様になる。元画像の画素単位。", "lm_noise_span"],
	"noise_frequency_1": ["ノイズ", "第1層の周波数", "大きいほど第1層の模様が細かくなる。", "lm_noise_frequency_1"],
	"noise_frequency_2": ["ノイズ", "第2層の周波数", "大きいほど第2層の模様が細かくなる。", "lm_noise_frequency_2"],
	"noise_speed_1": ["ノイズ", "第1層の流速", "第1層の模様の移動速度。", "lm_noise_speed_1"],
	"noise_speed_2": ["ノイズ", "第2層の流速", "第2層の模様の移動速度。", "lm_noise_speed_2"],
	"noise_weight_1": ["ノイズ", "第1層の強さ", "幅の揺らぎへ混ぜる第1層の量。", "lm_noise_weight_1"],
	"noise_weight_2": ["ノイズ", "第2層の強さ", "幅の揺らぎへ混ぜる第2層の量。", "lm_noise_weight_2"],
	"noise_offset_x": ["ノイズ", "第2層の横ずれ", "第2層の模様の位相を横へずらす。", "lm_noise_offset_x"],
	"noise_offset_y": ["ノイズ", "第2層の縦ずれ", "第2層の模様の位相を縦へずらす。", "lm_noise_offset_y"],
	"noise_bias": ["ノイズ", "ノイズのしきい値", "大きいほど幅の盛り上がる場所が少なくなる。", "lm_noise_bias"],
	"noise_contrast": ["ノイズ", "ノイズのコントラスト", "幅の細い場所と広い場所の差を強める。", "lm_noise_contrast"],
	"breakup_span": ["ノイズ", "濃淡模様のサイズ", "幅とは独立して光の濃淡を作る模様の大きさ。", "lm_breakup_span"],
	"breakup_speed": ["ノイズ", "濃淡模様の流速", "濃淡だけを動かす層の速さ。", "lm_breakup_speed"],
	"breakup_strength": ["ノイズ", "濃淡模様の強さ", "0で均一。大きいほど光が途切れる。", "lm_breakup_strength"],
	"breakup_offset_x": ["ノイズ", "濃淡模様の横ずれ", "濃淡模様の位相を横へずらす。", "lm_breakup_offset_x"],
	"breakup_offset_y": ["ノイズ", "濃淡模様の縦ずれ", "濃淡模様の位相を縦へずらす。", "lm_breakup_offset_y"],
	"core_noise_threshold": ["ノイズ", "芯が光るしきい値", "大きいほど明るい芯が出る場所を絞る。", "lm_core_noise_threshold"],
	"core_noise_gain": ["ノイズ", "芯のノイズ強度", "しきい値を超えた場所の芯の光を強める。", "lm_core_noise_gain"],
	"intensity": ["発光・色", "全体の濃さ", "外側と芯の不透明度に掛ける倍率。", "aura_intensity"],
	"color": ["発光・色", "外側の色", "外へ薄まる部分の金色。", "aura_outer"],
	"highlight": ["発光・色", "輪郭の芯の色", "船体に近い光の金色。", "aura_core"],
	"edge_opacity": ["発光・色", "外側の濃さ", "ノイズと距離を掛ける前の外側の不透明度。", "lm_edge_opacity"],
	"core_opacity": ["発光・色", "芯の濃さ", "明るい芯が加える不透明度。", "lm_core_opacity"],
	"max_opacity": ["発光・色", "不透明度の上限", "濃淡を合成したあとに制限する最大の不透明度。", "lm_max_opacity"],
	"pulse_amount": ["発光・色", "明滅の振幅", "全体の光がゆっくり弱まる深さ。0で明滅を止める。", "lm_pulse_amount"],
	"pulse_seconds": ["発光・色", "明滅の周期（秒）", "全体の光が明滅する一周期の世界秒。", "lm_pulse_seconds"],
	"opacity_step": ["発光・色", "濃淡の段差", "255段階の不透明度を何段ずつ刻むか。大きいほど粗い濃淡。", "lm_opacity_step"],
}

func apply_aura_to(material: ShaderMaterial) -> void:
	material.set_shader_parameter("landmark_mode", true)
	material.set_shader_parameter("distance_scale", 1.0)
	for key in AURA_FIELDS:
		material.set_shader_parameter(AURA_FIELDS[key][3], get(key))

func apply_to(material: ShaderMaterial) -> void:
	material.set_shader_parameter("pixel_grid", pixel_grid)
	material.set_shader_parameter("inner_radius", inner_radius)
	material.set_shader_parameter("outer_radius", outer_radius)
	material.set_shader_parameter("noise_scale", noise_scale)
	material.set_shader_parameter("motion_speed", motion_speed)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("mark_color", color)
	material.set_shader_parameter("highlight_color", highlight)
