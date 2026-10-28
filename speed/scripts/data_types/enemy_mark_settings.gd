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

func apply_to(material: ShaderMaterial) -> void:
	material.set_shader_parameter("pixel_grid", pixel_grid)
	material.set_shader_parameter("inner_radius", inner_radius)
	material.set_shader_parameter("outer_radius", outer_radius)
	material.set_shader_parameter("noise_scale", noise_scale)
	material.set_shader_parameter("motion_speed", motion_speed)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("mark_color", color)
	material.set_shader_parameter("highlight_color", highlight)
