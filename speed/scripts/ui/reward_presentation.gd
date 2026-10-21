## 確定済みの報酬だけを順番に見せる。付与・抽選はゲーム側で完了している。
extends Control

signal active_changed(active: bool)

@export_range(0.3, 1.0, 0.05) var continuation_seconds := 0.55
@export_range(0.1, 0.8, 0.05) var continuation_tail_seconds := 0.25

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
	hide()

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

func is_active() -> bool:
	return not _current.is_empty()

func _begin_next() -> void:
	if _queue.is_empty():
		_current = {}
		hide()
		active_changed.emit(false)
		return
	_current = _queue.pop_front()
	_elapsed = 0.0
	show()
	active_changed.emit(true)
	var step := int(_current.count) + 1
	var defs: Dictionary = ConfigManager.weapons if _current.kind == &"weapon" else ConfigManager.traits
	var definition: Resource = defs.get(_current.id)
	var title: String = definition.get_display_name() if definition != null else String(_current.id)
	var reward := "%s Lv%d" % [title, _current.level]
	_heading.text = tr("hud.continuation")
	_count.text = tr("hud.continuation_count").format({n = step})
	_detail.text = reward
	_history.append("%d  %s" % [step, reward])
	_trail.text = "\n".join(_history)
	_material.set_shader_parameter("chain_step", float(step))
	AudioManager.play(&"levelup", -5.0, 1.0 + 0.12 * (step - 2))

func _process(delta: float) -> void:
	if not is_active():
		return
	_elapsed += delta
	_total_elapsed += delta
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_canvas.position = (size - DESIGN_SIZE * factor) * 0.5
	_canvas.scale = Vector2.ONE * factor
	var progress := clampf(_elapsed / continuation_seconds, 0.0, 1.0)
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("elapsed", _total_elapsed)
	_count.scale = Vector2.ONE * (1.0 + 0.08 * (1.0 - smoothstep(0.0, 0.4, progress)))
	_count.pivot_offset = _count.size * 0.5
	if _elapsed >= continuation_seconds + (continuation_tail_seconds if _queue.is_empty() else 0.0):
		_begin_next()
