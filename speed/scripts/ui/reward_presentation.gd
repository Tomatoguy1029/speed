## 確定済みの報酬だけを順番に見せる。付与・抽選はゲーム側で完了している。
extends Control

signal active_changed(active: bool)

## クリック後の光の動きの長さ。結果は次の押下まで保持する。
@export_range(0.3, 1.0, 0.05) var continuation_seconds := 0.55
## 継続シールが貼り付くまでの長さ。次のクリックはこの途中でも即座に受け付ける。
@export_range(0.12, 0.4, 0.01) var continuation_stamp_seconds := 0.22

## 正式なカットインは Control シーンとして差し替える。任意で setup(hero) / set_progress(0..1) を実装する。
@export var ult_cutin_scene: PackedScene
@export_file("*.tscn") var ult_cutin_path := "res://scenes/run/ult_cutin.tscn"
@export_range(0.5, 3.0, 0.05) var ult_cutin_seconds := 1.15
@export_range(1.0, 8.0, 0.1) var ult_details_seconds := 3.0

const DESIGN_SIZE := Vector2(800, 450)
const BONUS_SIZE := Vector2(640, 360)
const STAMP_POSITION := Vector2(388, 76)
const STAMP_ANGLE := 0.18
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _elapsed := 0.0
var _history: Array[String] = []
var _canvas: Control
var _ult_viewport: SubViewport
var _ult_output: TextureRect
var _bonus_viewport: SubViewport
var _bonus_output: TextureRect
var _bonus_canvas: Control
var _bonus_heading: Label
var _bonus_hint: Label
var _bonus_icon: Control
var _bonus_level: Label
var _bonus_stamp: Panel
var _stamp_style: StyleBoxFlat
var _stamp_trim: Panel
## HUD の実アイコン追加処理を受け取り、表示先だけを継続画面へ変える。
var add_module_icon: Callable
var _light: ColorRect
var _material: ShaderMaterial
var _count: Label
var _heading: Label
var _detail: Label
var _trail: Label
var _cutin: Control
var _ult_block: PanelContainer
var _ult_name: Label
var _ult_desc: Label
var _ult_key: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.045, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_build_ult_canvas()
	_heading = _label(Rect2(100, 58, 600, 36), 20, Color("#efcb70"))
	_build_bonus()
	_build_ult_block()
	hide()

func _build_ult_canvas() -> void:
	# 800×450 の差し替え契約を保ち、HUDと同じ画素密度へ描いてから最近傍拡大する。
	_ult_viewport = SubViewport.new()
	_ult_viewport.size = Vector2i(BONUS_SIZE)
	_ult_viewport.transparent_bg = true
	_ult_viewport.world_2d = World2D.new()
	_ult_viewport.use_hdr_2d = get_viewport().use_hdr_2d
	_ult_viewport.gui_disable_input = true
	_ult_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_ult_viewport)
	_canvas = Control.new()
	_canvas.size = DESIGN_SIZE
	_canvas.scale = BONUS_SIZE / DESIGN_SIZE
	_canvas.theme = get_theme()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_viewport.add_child(_canvas)
	_ult_output = TextureRect.new()
	_ult_output.texture = _ult_viewport.get_texture()
	_ult_output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ult_output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ult_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ult_output)
	_ult_output.hide()

func _build_bonus() -> void:
	# タイトル画面と同じ低解像度描画＋最近傍拡大。文字も光も同じピクセル幅で見せる。
	_bonus_viewport = SubViewport.new()
	_bonus_viewport.size = Vector2i(BONUS_SIZE)
	_bonus_viewport.transparent_bg = true
	_bonus_viewport.world_2d = World2D.new()
	_bonus_viewport.use_hdr_2d = get_viewport().use_hdr_2d
	_bonus_viewport.gui_disable_input = true
	_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_bonus_viewport)
	_bonus_canvas = Control.new()
	_bonus_canvas.size = BONUS_SIZE
	_bonus_canvas.theme = get_theme()
	_bonus_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bonus_viewport.add_child(_bonus_canvas)
	_light = ColorRect.new()
	_light.size = BONUS_SIZE
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://assets/ui/rewards/continuation.gdshader")
	_light.material = _material
	_bonus_canvas.add_child(_light)
	_bonus_heading = _label(Rect2(80, 26, 480, 18), 10, Color("#a6b4cb"), _bonus_canvas)
	_bonus_icon = Control.new()
	_bonus_icon.position = Vector2(273, 83)
	_bonus_icon.size = Vector2(94, 94)
	_bonus_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus_canvas.add_child(_bonus_icon)
	_detail = _label(Rect2(80, 185, 480, 40), 24, Color("#efcb70"), _bonus_canvas)
	_detail.add_theme_color_override("font_outline_color", Color("#efcb70"))
	_detail.add_theme_constant_override("outline_size", 1)
	_bonus_level = _label(Rect2(80, 227, 480, 22), 14, Color("#d5dbea"), _bonus_canvas)
	_trail = _label(Rect2(100, 273, 440, 40), 10, Color("#a6b4cb"), _bonus_canvas)
	_bonus_hint = _label(Rect2(80, 327, 480, 18), 10, Color("#5bc8db"), _bonus_canvas)
	_bonus_hint.text = tr("hud.continuation_next")
	# アイコンの右上に重なる紙片。文字も輪郭も同じ低解像度の中で回転する。
	_bonus_stamp = Panel.new()
	_bonus_stamp.size = Vector2(136, 42)
	_bonus_stamp.pivot_offset = _bonus_stamp.size * 0.5
	_bonus_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp_style = StyleBoxFlat.new()
	_stamp_style.bg_color = Color("#efcb70")
	_stamp_style.border_color = Color("#9c804b")
	_stamp_style.set_border_width_all(2)
	_stamp_style.anti_aliasing = false
	_bonus_stamp.add_theme_stylebox_override("panel", _stamp_style)
	_bonus_canvas.add_child(_bonus_stamp)
	_stamp_trim = Panel.new()
	_stamp_trim.position = Vector2(5, 5)
	_stamp_trim.size = _bonus_stamp.size - Vector2(10, 10)
	_stamp_trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trim_style := StyleBoxFlat.new()
	trim_style.draw_center = false
	trim_style.border_color = Color("#9c804b")
	trim_style.set_border_width_all(1)
	trim_style.anti_aliasing = false
	_stamp_trim.add_theme_stylebox_override("panel", trim_style)
	_bonus_stamp.add_child(_stamp_trim)
	_count = _label(Rect2(4, 8, 128, 27), 17, Color("#0f1424"), _bonus_stamp)
	_count.add_theme_constant_override("shadow_offset_y", 0)
	_update_continuation_stamp()
	_bonus_output = TextureRect.new()
	_bonus_output.texture = _bonus_viewport.get_texture()
	_bonus_output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bonus_output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bonus_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bonus_output)
	_bonus_output.hide()

func _build_ult_block() -> void:
	_ult_block = PanelContainer.new()
	_ult_block.position = Vector2(80, 150)
	_ult_block.size = Vector2(640, 220)
	_ult_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f1424")
	style.border_color = Color("#efcb70")
	style.anti_aliasing = false
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_ult_block.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_ult_block)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 14)
	_ult_block.add_child(column)
	_ult_name = Label.new()
	_ult_desc = Label.new()
	_ult_key = Label.new()
	for label in [_ult_name, _ult_desc, _ult_key]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	_ult_name.add_theme_font_size_override("font_size", 30)
	_ult_name.add_theme_color_override("font_color", Color("#efcb70"))
	_ult_desc.add_theme_font_size_override("font_size", 21)
	_ult_desc.add_theme_color_override("font_color", Color("#d5dbea"))
	_ult_key.add_theme_font_size_override("font_size", 16)
	_ult_key.add_theme_color_override("font_color", Color("#5bc8db"))
	_ult_block.hide()

func _label(area: Rect2, font_size: int, color: Color, parent: Control = null) -> Label:
	var label := Label.new()
	label.position = area.position
	label.size = area.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.05, 0.95))
	label.add_theme_constant_override("shadow_offset_y", 1 if parent != null else 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_canvas if parent == null else parent).add_child(label)
	return label

func enqueue_bonus(event: Dictionary) -> void:
	_queue.append(event.duplicate())
	if _current.is_empty():
		_history.clear()
		_begin_next()

func enqueue_ult(event: Dictionary) -> void:
	# 同じフレームで複数の報酬があっても通知順を維持し、付与処理には触れない。
	_queue.append(event.duplicate())
	if _current.is_empty():
		_begin_next()

## 最終勝利への切替用。獲得済みの報酬には触れず、表示だけを閉じる。
func cancel() -> void:
	_queue.clear()
	_current = {}
	if _cutin != null:
		_cutin.queue_free()
		_cutin = null
	_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_ult_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()
	active_changed.emit(false)

## 結果の次送りは HUD が新しい押下として受けた時だけ呼ぶ。
func is_bonus_active() -> bool:
	return not _current.is_empty() and _current.type == &"level_bonus"

func advance_bonus() -> void:
	if is_bonus_active():
		_begin_next()

func is_active() -> bool:
	return not _current.is_empty()

func _begin_next() -> void:
	if _cutin != null:
		_cutin.queue_free()
		_cutin = null
	_ult_block.hide()
	if _queue.is_empty():
		_current = {}
		_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_ult_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		hide()
		active_changed.emit(false)
		return
	_current = _queue.pop_front()
	_elapsed = 0.0
	show()
	active_changed.emit(true)
	var ult: bool = _current.type == &"hero_freed"
	_canvas.visible = ult
	_ult_output.visible = ult
	_ult_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if ult else SubViewport.UPDATE_DISABLED
	_bonus_output.visible = not ult
	_bonus_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if ult else SubViewport.UPDATE_ALWAYS
	_material.set_shader_parameter("progress", 0.0)
	if ult:
		_begin_ult()
		return
	if int(_current.count) == 1:
		_history.clear()
	var step := int(_current.count) + 1
	var defs: Dictionary = ContentManager.weapons if _current.kind == &"weapon" else ContentManager.traits
	var definition: Resource = defs.get(_current.id)
	var title: String = definition.get_display_name() if definition != null else String(_current.id)
	var reward := "%s Lv%d" % [title, _current.level]
	_bonus_heading.text = tr("hud.continuation")
	_count.text = tr("hud.continuation_count").format({n = step})
	_stamp_style.bg_color = Color("#5bc8db") if step == 2 else Color("#efcb70") if step == 3 else Color("#d5dbea")
	_stamp_style.border_color = Color("#0f1424") if step == 2 else Color("#9c804b")
	_stamp_style.set_border_width_all(2 if step < 4 else 3)
	_stamp_trim.visible = step >= 3
	var trim_style := _stamp_trim.get_theme_stylebox("panel") as StyleBoxFlat
	trim_style.border_color = Color("#d5dbea") if step == 3 else Color("#9c804b")
	_detail.text = title
	_bonus_level.text = "Lv%d → Lv%d" % [int(_current.level) - 1, int(_current.level)]
	for child in _bonus_icon.get_children():
		_bonus_icon.remove_child(child)
		child.queue_free()
	if add_module_icon.is_valid():
		add_module_icon.call(_bonus_icon, definition, Rect2(Vector2.ZERO, _bonus_icon.size))
	_history.append("%d  %s" % [step, reward])
	_trail.text = "\n".join(_history)
	_update_continuation_stamp()
	_material.set_shader_parameter("chain_step", float(step))
	AudioManager.play(&"levelup", -5.0, 1.0 + 0.12 * (step - 2))

func _update_continuation_stamp() -> void:
	var t := clampf(_elapsed / continuation_stamp_seconds, 0.0, 1.0)
	var landing := 1.0 - pow(1.0 - minf(t / 0.65, 1.0), 3.0)
	# 上から素早く貼り、短い押し込みから静止する。点滅・待機・次送りを伴わない。
	var scale_factor := lerpf(1.28, 0.94, landing) if t < 0.65 else lerpf(0.94, 1.0, (t - 0.65) / 0.35)
	_bonus_stamp.position = (STAMP_POSITION + Vector2(10, -42) * (1.0 - landing)).round()
	_bonus_stamp.rotation = STAMP_ANGLE - 0.14 * (1.0 - landing)
	_bonus_stamp.scale = Vector2.ONE * scale_factor

func _begin_ult() -> void:
	var definition: HeroDef = ContentManager.heroes.get(_current.id)
	_heading.text = tr("hud.ult_granted")
	_heading.add_theme_color_override("font_color", Color("#efcb70"))
	_ult_name.text = "%s — %s" % [definition.display_name, tr("hero.%s.power" % definition.id)]
	_ult_desc.text = tr("hero.%s.desc" % definition.id)
	_ult_key.text = tr("hud.ult_key").format({key = OS.get_keycode_string(InputActions.key_of(&"hero"))})
	var scene: PackedScene = ult_cutin_scene if ult_cutin_scene != null else load(ult_cutin_path)
	_cutin = scene.instantiate() as Control
	_canvas.add_child(_cutin)
	if _cutin.has_method("setup"):
		_cutin.setup(definition)
	AudioManager.play(&"levelup", -4.0, 0.65)

func _process(delta: float) -> void:
	if not is_active():
		return
	_elapsed += delta
	if is_bonus_active():
		var factor := minf(size.x / BONUS_SIZE.x, size.y / BONUS_SIZE.y)
		_bonus_output.position = (size - BONUS_SIZE * factor) * 0.5
		_bonus_output.size = BONUS_SIZE * factor
		var progress := clampf(_elapsed / continuation_seconds, 0.0, 1.0)
		_material.set_shader_parameter("progress", progress)
		_update_continuation_stamp()
		return
	var factor := minf(size.x / BONUS_SIZE.x, size.y / BONUS_SIZE.y)
	_ult_output.position = ((size - BONUS_SIZE * factor) * 0.5).round()
	_ult_output.size = BONUS_SIZE * factor
	if _current.type == &"hero_freed":
		var cutin_progress := clampf(_elapsed / ult_cutin_seconds, 0.0, 1.0)
		if _cutin.has_method("set_progress"):
			_cutin.set_progress(cutin_progress)
		_cutin.visible = _elapsed < ult_cutin_seconds
		_ult_block.visible = not _cutin.visible
		_ult_block.modulate.a = smoothstep(ult_cutin_seconds, ult_cutin_seconds + 0.22, _elapsed)
		if _elapsed >= ult_cutin_seconds + ult_details_seconds:
			_begin_next()
		return
