## 共通ピクセル炎の外観。攻撃判定と独立したデザイン座標で調整する。
class_name PixelFlameSettings
extends Resource

@export_group("粒子と形")
@export_range(20.0, 140.0, 1.0) var birth_rate := 76.0
@export_range(16.0, 100.0, 1.0) var source_width := 64.0
@export_range(6.0, 26.0, 0.5) var particle_radius := 17.0
@export_range(0.4, 1.8, 0.02) var outer_lifetime := 1.16
@export_range(0.2, 1.3, 0.02) var inner_lifetime := 0.76
@export_range(0.1, 0.8, 0.02) var core_lifetime := 0.4
@export_range(30.0, 160.0, 1.0) var rise_speed := 78.0
@export_range(-40.0, 40.0, 1.0) var wind := 0.0
@export_range(0.0, 20.0, 0.5) var sway := 9.0
@export_group("輪郭と動き")
@export_range(0.1, 0.9, 0.01) var density_threshold := 0.43
@export_range(0.01, 0.2, 0.01) var edge_softness := 0.055
@export_range(0.0, 6.0, 0.1) var distortion := 2.3
@export_range(1.0, 6.0, 1.0) var pixel_size := 2.0
## 0 は連続時間。粒子の位置とshaderの変形を同じ時計で離散化する。
@export_range(0.0, 30.0, 1.0) var animation_fps := 12.0
@export_range(0.2, 2.0, 0.05) var speed := 1.0
@export_group("色と発光")
@export var outline_color := Color("c93220")
@export var outer_color := Color("fa6925")
@export var inner_color := Color("ffb938")
@export var core_color := Color("fff0b0")
@export_range(0.0, 0.6, 0.01) var glow_strength := 0.18
@export_range(0.0, 1.0, 0.01) var opacity := 0.98

func apply(material: ShaderMaterial) -> void:
	for key in ["density_threshold", "edge_softness", "distortion", "pixel_size",
			"outline_color", "outer_color", "inner_color", "core_color", "glow_strength", "opacity"]:
		material.set_shader_parameter(key, get(key))
