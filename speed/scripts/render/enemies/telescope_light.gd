## 48本の遮蔽距離で切った、画面解像度のサーチライト。
extends Node2D

const SHADER := preload("res://shaders/telescope_cone.gdshader")
var points := PackedVector2Array()
var uvs := PackedVector2Array()

func setup(glow: bool) -> void:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("ship_glow", glow)
	material = m
	z_index = -2

func set_shape(new_points: PackedVector2Array, new_uvs: PackedVector2Array, color: Color, strength: float, facing := 0.0, half := 0.0) -> void:
	points = new_points
	uvs = new_uvs
	var m := material as ShaderMaterial
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("facing", facing)
	m.set_shader_parameter("half_angle", half)
	show()
	queue_redraw()

func _draw() -> void:
	if points.size() >= 3:
		draw_polygon(points, PackedColorArray([Color.WHITE]), uvs)
