## F4で開く、移動・リサイズ可能な敵調整パネル。
extends PanelContainer

const PANEL := preload("res://scripts/dev/stage_enemy_panel.gd")
static var saved_rect := Rect2()
var run: RunSimulation
var panel: Control
var _mode := ""
var _start_rect := Rect2()
var _start_mouse := Vector2.ZERO
var _grip: Control
var _placed := false
var _restored := Rect2()

func _ready() -> void:
	hide()
	visibility_changed.connect(func():
		if visible: _ensure_contents())
	get_viewport().size_changed.connect(_constrain)
	resized.connect(_place_grip)
	item_rect_changed.connect(_place_grip)
	minimum_size_changed.connect(func(): _constrain.call_deferred())

## 出撃時にはノードも定義も作らず、最初に開くときだけ組み立てる。
func _ensure_contents() -> void:
	if panel != null: return
	theme = Theme.new()
	theme.default_font_size = 15
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17202c")
	style.border_color = Color("#42566e")
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "ステージ敵調整  [F4]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title.tooltip_text = "ドラッグで移動 / 右下のハンドルでリサイズ"
	title.gui_input.connect(_begin_drag.bind("move"))
	header.add_child(title)
	var expand := Button.new()
	expand.text = "□"
	expand.tooltip_text = "画面内に広げる / 元のサイズ"
	expand.pressed.connect(_maximize)
	header.add_child(expand)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "閉じる（未保存の試行は保持）"
	close.pressed.connect(_close)
	header.add_child(close)
	panel = PANEL.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.bind_run(run.state.stage, run.cfg, run.enemies.stage_tuning)
	box.add_child(panel)
	panel.tuning_changed.connect(func(values): run.enemies.update_stage_tuning(values))
	panel.saved.connect(func(stage):
		run.state.emit(&"enemy_tuning_saved", {"path": panel.stage_path, "values": stage.enemy_tuning.duplicate(true)}))
	_grip = Control.new()
	_grip.top_level = true
	_grip.size = Vector2(22, 22)
	_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_grip.tooltip_text = "ドラッグしてサイズを変更"
	_grip.gui_input.connect(_begin_drag.bind("resize"))
	_grip.draw.connect(func():
		for n in [6, 11, 16]: _grip.draw_line(Vector2(n, 20), Vector2(20, n), Color("#a7b8cc"), 1.0))
	add_child(_grip)
	_fit.call_deferred()

func _exit_tree() -> void:
	if _placed: _remember()

func _remember() -> void:
	saved_rect = Rect2(position, size)

func _fit() -> void:
	if not _placed:
		var view := get_viewport_rect().size
		var preferred := Vector2(minf(940, view.x - 32), minf(580, view.y - 48))
		var rect := saved_rect if saved_rect.has_area() else Rect2(Vector2(view.x - preferred.x - 16, 24), preferred)
		size = rect.size
		position = rect.position
		_placed = true
	_constrain()

func _constrain() -> void:
	if not _placed: return
	var view := get_viewport_rect().size
	size = size.clamp(Vector2(300, 250).min(view), (view - Vector2(8, 8)).max(Vector2.ONE))
	position = position.clamp(Vector2.ZERO, (view - size).max(Vector2.ZERO))
	_place_grip()

func _place_grip() -> void:
	if _grip != null: _grip.position = global_position + size - _grip.size

func _close() -> void:
	_remember()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	_mode = ""
	hide()

func _maximize() -> void:
	if _restored.has_area():
		position = _restored.position
		size = _restored.size
		_restored = Rect2()
	else:
		_restored = Rect2(position, size)
		position = Vector2(4, 4)
		size = get_viewport_rect().size - Vector2(8, 8)
	_constrain()
	_remember()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		if visible: _close()
		else:
			show()
			_fit.call_deferred()
		get_viewport().set_input_as_handled()
		return
	if not visible: return
	var focus := get_viewport().gui_get_focus_owner()
	if event is InputEventKey and focus != null and is_ancestor_of(focus) and event.keycode == KEY_ESCAPE:
		if event.pressed: _close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and not get_global_rect().has_point(event.position) and focus != null and is_ancestor_of(focus): focus.release_focus()
	if _mode.is_empty(): return
	if event is InputEventMouseMotion:
		var delta: Vector2 = event.position - _start_mouse
		if _mode == "move": position = _start_rect.position + delta
		else:
			size = _start_rect.size + delta
			_restored = Rect2()
		_constrain()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and not event.pressed:
		_mode = ""
		_remember()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if visible and focus != null and is_ancestor_of(focus): get_viewport().set_input_as_handled()

func _begin_drag(event: InputEvent, kind: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_mode = kind
		_start_rect = Rect2(position, size)
		_start_mouse = event.global_position
		get_viewport().set_input_as_handled()
