## 確定済みの報酬だけを順番に見せる。付与・抽選はゲーム側で完了している。
extends Control

signal active_changed(active: bool)

@export_range(0.3, 1.0, 0.05) var continuation_seconds := 0.55
@export_range(0.1, 0.8, 0.05) var continuation_tail_seconds := 0.25

## 正式なカットインは Control シーンとして差し替える。任意で setup(hero) / set_progress(0..1) を実装する。
@export var ult_cutin_scene: PackedScene = preload("res://scenes/run/ult_cutin.tscn")
@export_range(0.5, 3.0, 0.05) var ult_cutin_seconds := 1.15
@export_range(1.0, 8.0, 0.1) var ult_details_seconds := 3.0

const DESIGN_SIZE := Vector2(800, 450)
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _elapsed := 0.0
var _total_elapsed := 0.0
var _history: Array[String] = []
var _canvas: Control
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
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_light = ColorRect.new()
	_light.size = DESIGN_SIZE
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://assets/ui/rewards/continuation.gdshader")
	_light.material = _material
	_canvas.add_child(_light)
	_heading = _label(Rect2(100, 58, 600, 36), 20, Color("#b7eefa"))
	_count = _label(Rect2(100, 100, 600, 100), 78, Color("#fff5d8"))
	_detail = _label(Rect2(80, 227, 640, 48), 26, Color.WHITE)
	_trail = _label(Rect2(70, 300, 660, 90), 18, Color("#b9cbd5"))
	_build_ult_block()
	hide()

func _build_ult_block() -> void:
	_ult_block = PanelContainer.new()
	_ult_block.position = Vector2(80, 150)
	_ult_block.size = Vector2(640, 220)
	_ult_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.065, 0.98)
	style.border_color = Color("#e4bc6b")
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
	_ult_name.modulate = Color("#ffe4a6")
	_ult_desc.add_theme_font_size_override("font_size", 21)
	_ult_key.add_theme_font_size_override("font_size", 16)
	_ult_key.modulate = Color("#8eb7c6")
	_ult_block.hide()

func _label(area: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = area.position
	label.size = area.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.05, 0.95))
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(label)
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

func is_active() -> bool:
	return not _current.is_empty()

func _begin_next() -> void:
	if _cutin != null:
		_cutin.queue_free()
		_cutin = null
	_ult_block.hide()
	if _queue.is_empty():
		_current = {}
		hide()
		active_changed.emit(false)
		return
	_current = _queue.pop_front()
	_elapsed = 0.0
	show()
	active_changed.emit(true)
	var ult: bool = _current.type == &"hero_freed"
	for label in [_count, _detail, _trail]:
		label.visible = not ult
	_light.visible = not ult
	_heading.position.y = 58
	if ult:
		_begin_ult()
		return
	if int(_current.count) == 1:
		_history.clear()
	var step := int(_current.count) + 1
	var defs: Dictionary = ConfigManager.weapons if _current.kind == &"weapon" else ConfigManager.traits
	var definition: Resource = defs.get(_current.id)
	var title: String = definition.get_display_name() if definition != null else String(_current.id)
	var reward := "%s Lv%d" % [title, _current.level]
	_heading.text = tr("hud.continuation")
	_heading.add_theme_color_override("font_color", Color("#b7eefa"))
	_count.text = tr("hud.continuation_count").format({n = step})
	_detail.text = reward
	_history.append("%d  %s" % [step, reward])
	_trail.text = "\n".join(_history)
	_material.set_shader_parameter("chain_step", float(step))
	AudioManager.play(&"levelup", -5.0, 1.0 + 0.12 * (step - 2))

func _begin_ult() -> void:
	var definition: HeroDef = ConfigManager.heroes.get(_current.id)
	_heading.text = tr("hud.ult_granted")
	_heading.add_theme_color_override("font_color", Color("#ffe4a6"))
	_ult_name.text = "%s — %s" % [definition.display_name, tr("hero.%s.power" % definition.id)]
	_ult_desc.text = tr("hero.%s.desc" % definition.id)
	_ult_key.text = tr("hud.ult_key").format({key = OS.get_keycode_string(InputActions.key_of(&"hero"))})
	_cutin = ult_cutin_scene.instantiate() as Control
	_canvas.add_child(_cutin)
	if _cutin.has_method("setup"):
		_cutin.setup(definition)
	AudioManager.play(&"levelup", -4.0, 0.65)

func _process(delta: float) -> void:
	if not is_active():
		return
	_elapsed += delta
	_total_elapsed += delta
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_canvas.position = (size - DESIGN_SIZE * factor) * 0.5
	_canvas.scale = Vector2.ONE * factor
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
	var progress := clampf(_elapsed / continuation_seconds, 0.0, 1.0)
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("elapsed", _total_elapsed)
	_count.scale = Vector2.ONE * (1.0 + 0.08 * (1.0 - smoothstep(0.0, 0.4, progress)))
	_count.pivot_offset = _count.size * 0.5
	if _elapsed >= continuation_seconds + (continuation_tail_seconds if _queue.is_empty() else 0.0):
		_begin_next()
