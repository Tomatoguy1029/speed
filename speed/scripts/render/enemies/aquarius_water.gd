## 元の水ノイズを、論理画素の位置で画面上に表示する。
extends Node2D

const SHADER := preload("res://shaders/aquarius_water_reference.gdshader")
var _points := PackedVector2Array()

func setup(noise: Texture2D) -> void:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("noise_tex", noise)
	material = m
	z_index = -2

func update(row: Dictionary, canvas, clock: float, color: Color, pixel_size: float, opacity: float, tail: bool, age := 0.0, timing := 1.0) -> void:
	var origin: Vector2 = row.pos
	var direction := Vector2.from_angle(float(row.angle))
	var normal := Vector2(-direction.y, direction.x)
	var length := float(row.length)
	var half0 := float(row.half_width)
	var slope := tan(float(row.spread))
	var half := (half0 + length * slope) * 1.12
	_points = PackedVector2Array([origin, origin + direction*length + normal*half, origin + direction*length - normal*half])
	var m := material as ShaderMaterial
	m.set_shader_parameter("base_color",color)
	m.set_shader_parameter("origin_logical",canvas.to_logical(origin))
	m.set_shader_parameter("direction",direction)
	m.set_shader_parameter("logical_pixel",pixel_size)
	m.set_shader_parameter("world_scale",canvas.world_scale)
	m.set_shader_parameter("beam_length",length)
	m.set_shader_parameter("half0",half0)
	m.set_shader_parameter("slope",slope)
	m.set_shader_parameter("seed",float((int(row.index)*7)%17)/17.0*97.0)
	m.set_shader_parameter("clock",clock)
	m.set_shader_parameter("opacity",opacity)
	m.set_shader_parameter("tail",tail)
	if tail:
		var collapse := clampf(1.0-age/(0.35*timing),0.0,1.0)
		var life := clampf(1.0-age/(1.4*timing),0.0,1.0)
		m.set_shader_parameter("collapse",collapse)
		m.set_shader_parameter("mist_life",life*(1.0-collapse*0.6))
	else:
		m.set_shader_parameter("strength",clampf(float(row.time)/float(row.delay),0.0,1.0))
	show()
	queue_redraw()

func _draw() -> void:
	if _points.size() >= 3:
		draw_colored_polygon(_points,Color.WHITE)
