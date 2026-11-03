## 影で着地点を示し、予告の火の粉を専用shaderで描く。着地の炎は攻撃の表示（render/attacks/zone_phoenix.gd）が爆発で描く。
extends EnemyVisual

var flame_settings: Resource = preload("res://data/visuals/phoenix_flames.tres")
const COMPONENTS := preload("res://scripts/render/fx/visual_effect_components.gd")
var _flame_layer: DrawLayer

func _flame_quad(c: CanvasItem, center: Vector2, radius: float, age: float, seed: float, attack: bool) -> void:
	# 上へ立ち上がる先端だけ余白を増やし、消失時も四角形の端で切らない。
	var top := -1.2 - float(flame_settings.lift)
	var uv := PackedVector2Array([Vector2(-1.2, top), Vector2(1.2, top), Vector2(1.2, 1.2), Vector2(-1.2, 1.2)])
	var points := PackedVector2Array()
	for p in uv:
		points.append(center + p * radius)
	var payload := Color(age, seed, radius / 1000.0, 1.0 if attack else 0.25)
	c.draw_polygon(points, PackedColorArray([payload, payload, payload, payload]), uv)

var _frame_values := PackedFloat64Array()
var _frame_marks: DrawLayer
var _frame_flames: DrawLayer
var _frame_pixel := 1.0

func setup_frame(parent: Node2D) -> void:
	_frame_marks = DrawLayer.new()
	parent.add_child(_frame_marks)
	_frame_marks.draw_fn = _draw_frame_marks
	_frame_flames = DrawLayer.new()
	_frame_flames.name = "PhoenixFrameFlames"
	parent.add_child(_frame_flames)
	_frame_flames.draw_fn = _draw_frame_flames
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/phoenix_flames.gdshader")
	material.set_shader_parameter("noise_tex",preload("res://assets/fx/water_noise.png"))
	_frame_flames.material = material
	_frame_flames.visibility_layer = 1 | RenderPipeline.GLOW_LAYER

func apply_frame(values: PackedFloat64Array, clock: float, zoom: float) -> void:
	_frame_values = values
	_frame_pixel = 1.0/maxf(zoom,0.01)
	flame_settings = COMPONENTS.phoenix("enemy/phoenix",preload("res://data/visuals/phoenix_flames.tres"))
	var material := _frame_flames.material as ShaderMaterial
	for key in ["ember_color", "flame_color", "hot_color", "smoke_color", "amount", "speed", "pixel_size", "turbulence", "sparks", "opacity", "emission", "stretch", "lift"]:
		material.set_shader_parameter(key,flame_settings.get(key))
	material.set_shader_parameter("linear_colors",_frame_flames.get_viewport().use_hdr_2d)
	material.set_shader_parameter("clock",clock)
	_frame_marks.queue_redraw()
	_frame_flames.queue_redraw()

func _draw_frame_marks(c: CanvasItem) -> void:
	for i in range(0,_frame_values.size(),7):
		var center := Vector2(_frame_values[i],_frame_values[i+1])
		var r := _frame_values[i+2]
		var facing := _frame_values[i+3]
		var radius := _frame_values[i+4]
		var k := _frame_values[i+5]
		var col: Color = flame_settings.flame_color
		c.draw_circle(center,radius,Color(col,0.025+0.035*k))
		c.draw_arc(center,radius,0.0,TAU,64,Color(col,0.3+0.5*k),_frame_pixel*2.0)
		var shadow := PackedVector2Array()
		for point: Vector2 in [Vector2(0,-1),Vector2(0.28,-0.15),Vector2(1.2,0.4),Vector2(0.3,0.22),Vector2(0,0.9),Vector2(-0.3,0.22),Vector2(-1.2,0.4),Vector2(-0.28,-0.15)]:
			shadow.append(center+(point*r*(0.5+0.5*k)).rotated(facing+PI/2.0))
		c.draw_colored_polygon(shadow,Color(0.09,0.035,0.015,0.5+0.35*k))
		shadow.append(shadow[0])
		c.draw_polyline(shadow,Color(col,0.3+0.6*k),_frame_pixel*1.5)

func _draw_frame_flames(c: CanvasItem) -> void:
	for i in range(0,_frame_values.size(),7):
		_flame_quad(c,Vector2(_frame_values[i],_frame_values[i+1]),_frame_values[i+4],_frame_values[i+5],_frame_values[i+6],false)
