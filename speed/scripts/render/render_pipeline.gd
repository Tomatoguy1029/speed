## 描画の流れ（設計書 10）。層に分けて描き、シェーダーの段を重ねる。
##
## 豪華版（Forward+・Mobile）：2D の HDR と Godot のグローで光をにじませ、火花は GPU（コンピュート）で描く。
## 簡易版（Compatibility・ブラウザ）：光る層だけを描いた半分の大きさの絵（同じ世界を共有する SubViewport）を
## ぼかして足す。火花は CPU の粒で代える。
## 衝撃波の歪みは両方で使う。
class_name RenderPipeline
extends Node

## 光る層の番号（visibility_layer のビット）
const GLOW_LAYER := 2

var _overlay_layer := 1
var rich := false
var sparks: GpuSparks
var _world: Node2D
var _camera: Camera2D
var _glow_viewport: SubViewport
var _glow_camera: Camera2D
var _shock: ColorRect
var _ripple: ColorRect
## 震空の歪み：pos（世界）、radius（世界）、age、cell（世界の1ドット）
var _ripples: Array = []
## 衝撃波：pos、radius（世界）、life、max
var _waves: Array = []

## world の下の層のうち、光らせる層を glow_layers で渡す。
func setup(world: Node2D, camera: Camera2D, glow_layers: Array, overlay_layer := 1) -> void:
	_overlay_layer = overlay_layer
	_world = world
	_camera = camera
	rich = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	if rich:
		_setup_hdr_glow(glow_layers)
	else:
		_setup_bloom_pass(glow_layers)
	_setup_shockwave()
	_setup_sparks()

func _setup_hdr_glow(glow_layers: Array) -> void:
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	for layer in glow_layers:
		layer.modulate = Color(1.6, 1.6, 1.6)
	# 線の帯は面が大きいので、にじみを控えめにする
	if glow_layers.size() > 2:
		glow_layers[2].modulate = Color(1.15, 1.15, 1.15)

func _setup_bloom_pass(glow_layers: Array) -> void:
	for layer in glow_layers:
		layer.visibility_layer = 1 | GLOW_LAYER
	_glow_viewport = SubViewport.new()
	_glow_viewport.world_2d = get_viewport().world_2d
	_glow_viewport.transparent_bg = true
	_glow_viewport.canvas_cull_mask = GLOW_LAYER
	_glow_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_glow_camera = Camera2D.new()
	_glow_viewport.add_child(_glow_camera)
	add_child(_glow_viewport)
	var layer := CanvasLayer.new()
	layer.layer = _overlay_layer + 2
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = _glow_viewport.get_texture()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/bloom_blur.gdshader")
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)

func _setup_shockwave() -> void:
	var layer := CanvasLayer.new()
	layer.layer = _overlay_layer
	_shock = ColorRect.new()
	_shock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shock.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/shockwave.gdshader")
	_shock.material = mat
	_shock.visible = false
	layer.add_child(_shock)
	_ripple = ColorRect.new()
	_ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ripple.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ripple_mat := ShaderMaterial.new()
	ripple_mat.shader = load("res://shaders/space_ripple.gdshader")
	_ripple.material = ripple_mat
	_ripple.visible = false
	layer.add_child(_ripple)
	add_child(layer)

func _setup_sparks() -> void:
	var layer := CanvasLayer.new()
	layer.layer = _overlay_layer + 1
	sparks = GpuSparks.new()
	layer.add_child(sparks)
	add_child(layer)
	if not rich:
		sparks.rd = null

## 衝撃波の歪みを足す（ソニックブーム、大きな爆発など）。
func add_wave(pos: Vector2, radius: float, life := 0.5) -> void:
	_waves.append({"pos": pos, "radius": radius, "life": life, "max": life})
	if _waves.size() > 8:
		_waves.pop_front()

## 震空の空間の歪みを足す。触れた点へ 0.08 秒引き込み、そのあと 0.5 秒で radius まで押し広げる。
func add_ripple(pos: Vector2, radius: float, cell: float) -> void:
	_ripples.append({"pos": pos, "radius": radius, "age": 0.0, "cell": cell})
	if _ripples.size() > 8:
		_ripples.pop_front()

## 光る層の明るさ上げ（modulate）を打ち消す色。試作どおりの色で描く演出は、この色を自分の modulate にする。
static func plain_color(layer: CanvasItem, tint := Color.WHITE) -> Color:
	var m := layer.modulate
	return Color(tint.r / maxf(m.r, 0.001), tint.g / maxf(m.g, 0.001), tint.b / maxf(m.b, 0.001), tint.a)

## 震空の歪みの material（戦闘エフェクトツールの調整を当てる）。
func ripple_material() -> ShaderMaterial:
	return _ripple.material as ShaderMaterial

## 1フレームぶん進める。dt は演出の時間（ポーズ中は 0）。
func step(dt: float, view_center: Vector2, zoom: float) -> void:
	if _glow_viewport != null:
		var size := get_viewport().get_visible_rect().size
		_glow_viewport.size = Vector2i(size / 2.0)
		_glow_camera.position = _camera.position
		_glow_camera.zoom = _camera.zoom * 0.5
	_update_waves(dt, view_center, zoom)
	_update_ripples(dt, view_center, zoom)
	if sparks.available():
		sparks.step(dt, view_center, zoom)

func _update_waves(dt: float, view_center: Vector2, zoom: float) -> void:
	for w in _waves:
		w.life -= dt
	_waves = _waves.filter(func(w): return w.life > 0.0)
	_shock.visible = not _waves.is_empty()
	if _waves.is_empty():
		return
	var size := get_viewport().get_visible_rect().size
	var arr: Array[Vector4] = []
	for w in _waves:
		var k: float = 1.0 - w.life / w.max
		var screen: Vector2 = (w.pos - view_center) * zoom + size / 2.0
		arr.append(Vector4(screen.x / size.x, screen.y / size.y, w.radius * k * zoom / size.y, 1.0 - k))
	while arr.size() < 8:
		arr.append(Vector4.ZERO)
	var mat := _shock.material as ShaderMaterial
	mat.set_shader_parameter("count", _waves.size())
	mat.set_shader_parameter("waves", arr)
	mat.set_shader_parameter("aspect", size.x / size.y)

func _update_ripples(dt: float, view_center: Vector2, zoom: float) -> void:
	for r in _ripples:
		r.age += dt
	_ripples = _ripples.filter(func(r): return r.age < 0.58)
	_ripple.visible = not _ripples.is_empty()
	if _ripples.is_empty():
		return
	var size := get_viewport().get_visible_rect().size
	var arr: Array[Vector4] = []
	var cell := 1.0
	for r in _ripples:
		cell = float(r.cell) * zoom
		var screen: Vector2 = (r.pos - view_center) * zoom + size / 2.0
		var cells: float = float(r.radius) / float(r.cell)
		var radius := 0.0
		var amp := 0.0
		if r.age < 0.08:
			var k: float = r.age / 0.08
			radius = 3.0 + 9.0 * (1.0 - k)
			amp = -8.0 * (1.0 - k * 0.3)
		else:
			var q: float = (r.age - 0.08) / 0.5
			radius = 4.0 + (cells - 4.0) * (1.0 - pow(1.0 - q, 2.2))
			amp = 10.0 * (1.0 - q * 0.75)
		arr.append(Vector4(screen.x, screen.y, radius * cell, amp))
	while arr.size() < 8:
		arr.append(Vector4.ZERO)
	var mat := _ripple.material as ShaderMaterial
	mat.set_shader_parameter("count", _ripples.size())
	mat.set_shader_parameter("ripples", arr)
	mat.set_shader_parameter("cell", cell)
