## 仮の伝説獲得。既存の部品図と名称だけを表示し、付与・セーブを行わない。
## 差替シーンの契約：setup(LegendaryModuleDef)、set_progress(0..1)、任意で
## set_timing(出現秒, 静止秒, 回収秒) / set_endpoints(出現位置, 機体位置)。位置は画面座標。
extends Control

const DESIGN := Vector2(640, 360)
const PREVIEW_SIZE := Vector2i(360, 220)
## 差し替え画像の外側でにじみ・上向きの流れを描く余白。画像自体の表示サイズは維持する。
const AURA_PADDING := Vector2i(48, 56)
@export var light_color := Color("#e2b96b")
@export_range(0.0, 1.0) var light_strength := 0.8
@export_range(0.0, 1.0) var background_dim := 0.97
@export_group("補助の後光")
@export_range(0.0, 4.0, 0.05) var white_core_strength := 3.6
@export_range(0.08, 0.35, 0.01) var white_core_radius := 0.22
@export_range(0.0, 4.0, 0.05) var broad_ray_strength := 1.2
@export_range(0.0, 4.0, 0.05) var fine_ray_strength := 0.75
@export_range(0.3, 2.0, 0.05) var backlight_reach := 1.0
@export_range(0.5, 2.0, 0.05) var backlight_width := 1.1
@export_range(0.0, 3.0, 0.05) var emergence_surge_strength := 0.12
@export_group("発光の崩れ")
@export_range(0.0, 1.0, 0.05) var core_distortion := 0.35
@export_range(0.0, 1.0, 0.05) var ray_turbulence := 0.3
@export_range(0.0, 1.0, 0.05) var ray_breakup := 0.25
@export_group("黒い影と後光")
@export_range(0.0, 3.0, 0.05) var radiance_strength := 1.25
@export_range(0.0, 1.0, 0.05) var aura_flow_strength := 0.4
@export_range(0.0, 2.0, 0.05) var aura_wisp_strength := 0.85
@export_range(0.0, 2.0, 0.05) var aura_dust_strength := 0.9
@export_range(0.0, 1.0, 0.05) var aura_surface_strength := 0.45
@export_range(0.0, 1.0, 0.05) var shadow_strength := 1.0
@export_range(0.0, 0.1, 0.005) var noise_strength := 0.025
## 出現区間のどこから影を解き、どこで姿を見せ終わるか。
@export_range(0.0, 1.0, 0.05) var shadow_release_start := 0.3
@export_range(0.0, 1.0, 0.05) var shadow_release_end := 1.0

var _definition: LegendaryModuleDef
var _progress := 0.0
var _duration := 4.35
var _appear := 0.22
var _collect := 0.78
var _source := DESIGN / 2.0
var _target := DESIGN / 2.0
var _canvas := Control.new()
var _image := TextureRect.new()
var _aura := TextureRect.new()
var _mantle := TextureRect.new()
var _occlusion := TextureRect.new()
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
	# preview_texture の透過画像を優先し、未指定時だけ図鑑の仮部品図を使う。
	# オーラ・金粉・遮蔽はこの共通のアルファを読むので、輪郭をコードへ固定しない。
	_viewport.size = PREVIEW_SIZE + AURA_PADDING * 2
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var preview := ModulePreview.new()
	preview.size = Vector2(PREVIEW_SIZE)
	preview.position = Vector2(AURA_PADDING)
	_viewport.add_child(preview)
	preview.setup(_definition, true)
	_image.texture = _viewport.get_texture()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.size = Vector2(_viewport.size)
	_image.pivot_offset = _image.size / 2.0
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _definition.preview_texture == null:
		var rust := ShaderMaterial.new()
		rust.shader = preload("res://shaders/legendary_placeholder_rust.gdshader")
		_image.material = rust
	_aura.texture = _image.texture
	_aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_aura.size = _image.size
	_aura.pivot_offset = _image.pivot_offset
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aura_material := ShaderMaterial.new()
	aura_material.shader = preload("res://shaders/legendary_radiance.gdshader")
	_aura.material = aura_material
	_canvas.add_child(_aura)
	_canvas.add_child(_image)
	_mantle.texture = _image.texture
	_mantle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mantle.size = _image.size
	_mantle.pivot_offset = _image.pivot_offset
	_mantle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mantle_material := ShaderMaterial.new()
	mantle_material.shader = preload("res://shaders/legendary_mantle.gdshader")
	_mantle.material = mantle_material
	_canvas.add_child(_mantle)
	_occlusion.texture = _image.texture
	_occlusion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_occlusion.size = _image.size
	_occlusion.pivot_offset = _image.pivot_offset
	_occlusion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = preload("res://shaders/legendary_occlusion.gdshader")
	_occlusion.material = shadow_material
	_canvas.add_child(_occlusion)
	_name.text = _definition.get_display_name()
	_name.position = Vector2(55, 262)
	_name.size = Vector2(530, 75)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_duration = total
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
	# 手前の本体は早期から不透明にし、影を解くことで姿を見せる。
	# 背面の強い光は本体の材質を透過せず、輪郭の外にだけ残る。
	_image.modulate.a = smoothstep(0.0, _appear * 0.2, _progress) * (1.0 - taking)
	var exposure := smoothstep(_appear * shadow_release_start,
		_appear * maxf(shadow_release_start + 0.01, shadow_release_end), _progress)
	for layer in [_aura, _mantle, _occlusion]:
		layer.position = _image.position
		layer.scale = _image.scale
		layer.modulate.a = smoothstep(_appear * 0.12, _appear * 0.55, _progress) * (1.0 - taking)
	_occlusion.modulate.a = _image.modulate.a
	_mantle.modulate.a = _image.modulate.a
	var aura_material := _aura.material as ShaderMaterial
	aura_material.set_shader_parameter("intensity", radiance_strength)
	aura_material.set_shader_parameter("exposure", exposure)
	aura_material.set_shader_parameter("motion_time", _progress * _duration)
	aura_material.set_shader_parameter("flow_strength", aura_flow_strength)
	aura_material.set_shader_parameter("radiance_color", light_color.lightened(0.25))
	aura_material.set_shader_parameter("wisp_strength", aura_wisp_strength)
	aura_material.set_shader_parameter("dust_strength", aura_dust_strength)
	var mantle_material := _mantle.material as ShaderMaterial
	mantle_material.set_shader_parameter("motion_time", _progress * _duration)
	mantle_material.set_shader_parameter("flow_strength", aura_flow_strength)
	mantle_material.set_shader_parameter("dust_strength", aura_dust_strength)
	mantle_material.set_shader_parameter("wisp_strength", aura_wisp_strength)
	mantle_material.set_shader_parameter("surface_strength", aura_surface_strength)
	mantle_material.set_shader_parameter("radiance_color", light_color.lightened(0.25))
	var shadow_material := _occlusion.material as ShaderMaterial
	shadow_material.set_shader_parameter("exposure", exposure)
	shadow_material.set_shader_parameter("shadow_strength", shadow_strength)
	shadow_material.set_shader_parameter("grain_strength", noise_strength)
	if _image.material != null:
		(_image.material as ShaderMaterial).set_shader_parameter("reveal", arrival)
		(_image.material as ShaderMaterial).set_shader_parameter("motion_time", _progress * _duration)
		(_image.material as ShaderMaterial).set_shader_parameter("flow_strength", aura_flow_strength)
	_name.modulate.a = smoothstep(_appear * 0.85, _appear + 0.07, _progress) * (1.0 - taking)
	_light_material.set_shader_parameter("center", center / DESIGN)
	_light_material.set_shader_parameter("intensity", light_strength * arrival * (1.0 - taking))
	_light_material.set_shader_parameter("light_color", light_color)
	_light_material.set_shader_parameter("arrival", arrival)
	_light_material.set_shader_parameter("exposure", exposure)
	_light_material.set_shader_parameter("core_strength", white_core_strength)
	_light_material.set_shader_parameter("core_radius", white_core_radius)
	_light_material.set_shader_parameter("broad_ray_strength", broad_ray_strength)
	_light_material.set_shader_parameter("fine_ray_strength", fine_ray_strength)
	_light_material.set_shader_parameter("ray_reach", backlight_reach)
	_light_material.set_shader_parameter("ray_width", backlight_width)
	_light_material.set_shader_parameter("surge_strength", emergence_surge_strength)
	_light_material.set_shader_parameter("motion_time", _progress * _duration)
	_light_material.set_shader_parameter("core_distortion", core_distortion)
	_light_material.set_shader_parameter("ray_turbulence", ray_turbulence)
	_light_material.set_shader_parameter("ray_breakup", ray_breakup)
	queue_redraw()

func _draw() -> void:
	var arrival := smoothstep(_appear * 0.18, _appear, _progress)
	var taking := smoothstep(_collect, 1.0, _progress)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.018, 0.03, background_dim * smoothstep(0.0, _appear * 0.28, _progress) * (1.0 - taking)))
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform((size - DESIGN * factor) / 2.0, 0, Vector2.ONE * factor)
	# 光の中の微粒子。固定した種で配置し、ゆっくり外へ運ぶ。
	for i in 32:
		var angle := i * 2.39996323
		var seed := fposmod(sin(i * 127.1 + 1.0) * 43758.5, 1.0)
		var radius := 42.0 + sqrt(seed) * 65.0 + _progress * (3.0 + seed * 4.0)
		var point := Vector2(320, 168) + Vector2.from_angle(angle) * Vector2(radius, radius * 0.72)
		point = point.snapped(Vector2.ONE)
		var ink := light_color.lightened(0.5 if i % 7 == 0 else 0.0)
		ink.a = arrival * (1.0 - taking) * (0.07 + seed * 0.2)
		draw_rect(Rect2(point, Vector2.ONE if i % 7 else Vector2(1, 2)), ink)
	draw_set_transform(Vector2.ZERO)
