## ボーナスステージの見た目。C++のボーナス残り時間の変化だけを見て、表示側で次を動かす。ゲームの進行は止めない。
## 入るとき：ワープホールが画面中央へ寄りながら広がり、トンネルを潜って金白の閃光になる。
## 中：背景に bonus_background.gdshader を重ね、画面に光のにじみ・色収差・周辺減光を掛ける。
## 出るとき：残り時間の最後に白く飛ばし、通常の画面へ戻す。
extends Node

## 潜る演出の実秒
const DIVE_TIME := 1.2
## 潜ったあと閃光が引く実秒
const REVEAL_TIME := 0.6
## 終わる前に白くなり始める残り秒
const EXIT_LEAD := 0.4
## 出たあと閃光が引く実秒
const EXIT_TIME := 0.8
## 背景と潜る演出のドットの粗さ（画面の高さのドット数）
const CELLS := 216.0
const NOISE := preload("res://assets/effects/build/burst_noise.tres")

var _screen: ColorRect
var _backdrop: DrawLayer
var _background: Node2D
var _inside := false
var _dive := -1.0
var _since_dive := -1.0
var _since_exit := -1.0
var _time := 0.0

## pipeline：画面効果の層を置く先。background：ステージ背景（地色の範囲を使い、その手前に星雲を描く）。
func setup(pipeline: RenderPipeline, background: Node2D) -> void:
	_background = background
	_screen = ColorRect.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	var screen_mat := ShaderMaterial.new()
	screen_mat.shader = preload("res://shaders/bonus_screen.gdshader")
	screen_mat.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	_screen.material = screen_mat
	_screen.visible = false
	var layer := CanvasLayer.new()
	layer.add_child(_screen)
	pipeline.add_screen_layer(layer, 2)
	_backdrop = DrawLayer.new()
	var back_mat := ShaderMaterial.new()
	back_mat.shader = preload("res://shaders/bonus_background.gdshader")
	back_mat.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	_backdrop.material = back_mat
	_backdrop.draw_fn = func(canvas: CanvasItem): canvas.draw_rect(_background.area, Color.WHITE)
	_backdrop.visible = false
	background.add_child(_backdrop)

## dt：演出の実秒（ポーズ中は0）。warp：最後に受けたワープホールの値。pixel：絵の1ドットの世界での大きさ。
func step(dt: float, ui: Dictionary, warp: Dictionary, view_center: Vector2, zoom: float, pixel: float) -> void:
	var remaining := float(ui.get("bonus_remaining", 0.0))
	var inside := remaining > 0.0
	var size := _screen.get_viewport_rect().size
	if inside and not _inside:
		_start_dive(ui, warp, view_center, zoom, size)
	elif not inside and _inside:
		_dive = -1.0
		_since_dive = -1.0
		_since_exit = 0.0
	_inside = inside
	_time = fmod(_time + dt, 1000.0)
	var bonus := 0.0
	var flash := 0.0
	var dive := 0.0
	if _dive >= 0.0:
		_dive += dt
		dive = minf(_dive / DIVE_TIME, 1.0)
		if _dive >= DIVE_TIME:
			_dive = -1.0
			_since_dive = 0.0
	elif _inside:
		bonus = 1.0
		if _since_dive >= 0.0:
			_since_dive += dt
			flash = 1.0 - smoothstep(0.0, REVEAL_TIME, _since_dive)
		flash = maxf(flash, 1.0 - smoothstep(0.0, EXIT_LEAD, remaining))
	if _since_exit >= 0.0:
		_since_exit += dt
		flash = maxf(flash, 1.0 - smoothstep(0.0, EXIT_TIME, _since_exit))
		if _since_exit >= EXIT_TIME: _since_exit = -1.0
	_screen.visible = dive > 0.0 or bonus > 0.0 or flash > 0.0
	_backdrop.visible = bonus > 0.0
	if _screen.visible:
		var mat := _screen.material as ShaderMaterial
		mat.set_shader_parameter("time", _time)
		mat.set_shader_parameter("dive", dive)
		mat.set_shader_parameter("bonus", bonus)
		mat.set_shader_parameter("flash", flash)
		mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
		mat.set_shader_parameter("cells", maxf(CELLS, size.y / maxf(pixel * zoom, 0.01)))
	if _backdrop.visible:
		var back := _backdrop.material as ShaderMaterial
		back.set_shader_parameter("time", _time)
		back.set_shader_parameter("amount", bonus)
		back.set_shader_parameter("view_center", view_center)
		back.set_shader_parameter("dot_world", pixel)
		back.set_shader_parameter("unit_world", size.y / CELLS / maxf(zoom, 0.01))
		back.set_shader_parameter("cells", CELLS)
		back.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
		_backdrop.queue_redraw()

## 潜り始めの穴は、触れたワープホールの位置と大きさに合わせる。値がなければ画面中央から始める。
func _start_dive(ui: Dictionary, warp: Dictionary, view_center: Vector2, zoom: float, size: Vector2) -> void:
	_dive = 0.0
	_since_dive = -1.0
	_since_exit = -1.0
	var from := Vector2(0.5, 0.5)
	var radius := 70.0
	if warp.get("position") is Vector2:
		var ship: Variant = ui.get("ship", {}).get("ship_pos")
		radius = float(warp.get("radius", radius))
		if not ship is Vector2 or (ship as Vector2).distance_to(warp.position) < radius * 4.0:
			from = ((warp.position - view_center) * zoom + size / 2.0) / size
	var mat := _screen.material as ShaderMaterial
	mat.set_shader_parameter("dive_from", from)
	mat.set_shader_parameter("dive_radius", radius * zoom / maxf(size.y, 1.0))
