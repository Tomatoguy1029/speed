## 照射中の画素と加算光を論理画素ごとに描く。
extends Node2D

const BODY := preload("res://shaders/aquarius_stream_reference.gdshader")
const LIGHT := preload("res://shaders/aquarius_stream_light.gdshader")

class LightPass extends Node2D:
	var points := PackedVector2Array()
	func _draw() -> void:
		if points.size() == 4: draw_colored_polygon(points, Color.WHITE)

var _points := PackedVector2Array()
var _copy := BackBufferCopy.new()
var _light := LightPass.new()

func _init() -> void:
	var body := ShaderMaterial.new()
	body.shader = BODY
	material = body
	z_index = 19
	_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_copy)
	var light := ShaderMaterial.new()
	light.shader = LIGHT
	_light.material = light
	add_child(_light)

func update(row: Dictionary, canvas, clock: float, color: Color, pixel_size: float, opacity: float) -> void:
	var origin: Vector2 = row.pos
	var logical_origin: Vector2 = canvas.to_logical(origin)
	var size := Vector2(canvas.front.width, canvas.front.height)
	var top_left: Vector2 = origin - logical_origin / canvas.world_scale
	var extent: Vector2 = size / canvas.world_scale
	_points = PackedVector2Array([top_left, top_left+Vector2(extent.x,0), top_left+extent, top_left+Vector2(0,extent.y)])
	_light.points = _points
	for node: Node2D in [self, _light]:
		var shader := node.material as ShaderMaterial
		shader.set_shader_parameter("base_color",Vector4(color.r,color.g,color.b,color.a))
		shader.set_shader_parameter("origin_logical",logical_origin)
		shader.set_shader_parameter("direction",Vector2.from_angle(float(row.angle)))
		shader.set_shader_parameter("logical_size",size)
		shader.set_shader_parameter("logical_pixel",pixel_size)
		shader.set_shader_parameter("world_scale",canvas.world_scale)
		shader.set_shader_parameter("beam_length",float(row.length))
		shader.set_shader_parameter("half0",float(row.half_width))
		shader.set_shader_parameter("slope",tan(float(row.spread)))
		shader.set_shader_parameter("seed",7+int(row.index)*13)
		shader.set_shader_parameter("clock",clock)
		shader.set_shader_parameter("opacity",opacity)
		shader.set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
	show()
	queue_redraw()
	_light.queue_redraw()

func _draw() -> void:
	if _points.size() == 4: draw_colored_polygon(_points, Color.WHITE)
