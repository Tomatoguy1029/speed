## 仮の伝説獲得。既存の部品図と名称だけを表示し、付与・セーブを行わない。
## 差替シーンの契約：setup(LegendaryModuleDef)、set_progress(0..1)、任意で
## set_timing(出現秒, 静止秒, 回収秒) / set_endpoints(出現位置, 機体位置)。位置は画面座標。
extends Control

const DESIGN := Vector2(640, 360)
@export var light_color := Color("#e2b96b")
@export_range(0.0, 1.0) var light_strength := 0.85
@export_range(0.0, 1.0) var background_dim := 0.9

var _definition: LegendaryModuleDef
var _progress := 0.0
var _appear := 0.22
var _collect := 0.78
var _source := DESIGN / 2.0
var _target := DESIGN / 2.0
var _canvas := Control.new()
var _image := TextureRect.new()
var _name := Label.new()
var _light := ColorRect.new()
var _light_material := ShaderMaterial.new()
var _viewport := SubViewport.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_light.size = DESIGN
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_material.shader = preload("res://shaders/legendary_reveal_light.gdshader")
	_light.material = _light_material
	_canvas.add_child(_light)
	# 図鑑の既存部品図を低解像度で描画する。専用素材も同じ差替口を使う。
	_viewport.size = Vector2i(360, 220)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var preview := ModulePreview.new()
	preview.size = Vector2(360, 220)
	_viewport.add_child(preview)
	preview.setup(_definition, true)
	_image.texture = _viewport.get_texture()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.size = Vector2(360, 220)
	_image.pivot_offset = _image.size / 2.0
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _definition.preview_texture == null:
		var rust := ShaderMaterial.new()
		rust.shader = preload("res://shaders/legendary_placeholder_rust.gdshader")
		_image.material = rust
	_canvas.add_child(_image)
	_name.text = _definition.get_display_name()
	_name.position = Vector2(55, 262)
	_name.size = Vector2(530, 45)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 22)
	_name.add_theme_color_override("font_color", Color("#ecd6a5"))
	_name.add_theme_color_override("font_shadow_color", Color.BLACK)
	_name.add_theme_constant_override("shadow_offset_y", 2)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_name)

func setup(definition: LegendaryModuleDef) -> void:
	_definition = definition

func set_timing(appear: float, hold: float, collect: float) -> void:
	var total := maxf(0.001, appear + hold + collect)
	_appear = maxf(0.001, appear / total)
	_collect = 1.0 - maxf(0.001, collect / total)

func set_endpoints(source: Vector2, target: Vector2) -> void:
	var factor := maxf(0.001, minf(size.x / DESIGN.x, size.y / DESIGN.y))
	var origin := (size - DESIGN * factor) / 2.0
	_source = ((source - origin) / factor).clamp(Vector2(80, 70), DESIGN - Vector2(80, 70))
	_target = ((target - origin) / factor).clamp(Vector2.ZERO, DESIGN)

func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	if not is_node_ready():
		return
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_canvas.position = (size - DESIGN * factor) / 2.0
	_canvas.scale = Vector2.ONE * factor
	var arrival := smoothstep(_appear * 0.18, _appear, _progress)
	var taking := smoothstep(_collect, 1.0, _progress)
	var center := _source.lerp(Vector2(320, 168), arrival).lerp(_target, taking)
	var swell := lerpf(0.82, 1.0, arrival) * lerpf(1.0, 0.04, taking)
	_image.position = center - _image.size / 2.0
	_image.scale = Vector2.ONE * swell
	_image.modulate.a = smoothstep(_appear * 0.3, _appear * 0.9, _progress) * (1.0 - taking)
	if _image.material != null:
		(_image.material as ShaderMaterial).set_shader_parameter("reveal", arrival)
	_name.modulate.a = smoothstep(_appear * 0.85, _appear + 0.07, _progress) * (1.0 - taking)
	_light_material.set_shader_parameter("center", center / DESIGN)
	_light_material.set_shader_parameter("intensity", light_strength * arrival * (1.0 - taking))
	_light_material.set_shader_parameter("light_color", light_color)
	_light_material.set_shader_parameter("arrival", arrival)
	queue_redraw()

func _draw() -> void:
	var arrival := smoothstep(_appear * 0.18, _appear, _progress)
	var taking := smoothstep(_collect, 1.0, _progress)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.018, 0.03, background_dim * arrival * (1.0 - taking)))
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform((size - DESIGN * factor) / 2.0, 0, Vector2.ONE * factor)
	# 仮部品を囲む少量の角形の光。乱数や世界の更新に依存しない。
	for i in 8:
		var angle := i * TAU / 8.0 + 0.04 * _progress
		var radius := 98.0 + (i % 3) * 14.0 - 30.0 * arrival
		var point := Vector2(320, 168) + Vector2.from_angle(angle) * Vector2(radius, radius * 0.65)
		point = point.snapped(Vector2(2, 2))
		var ink := light_color
		ink.a = arrival * (1.0 - taking) * (0.12 + 0.08 * sin(i * 2.3 + _progress * 2.0))
		draw_rect(Rect2(point, Vector2(1, 1) if i % 3 else Vector2(2, 2)), ink)
	draw_set_transform(Vector2.ZERO)
