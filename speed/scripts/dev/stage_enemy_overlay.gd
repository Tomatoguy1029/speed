## F4で開く、ゲームを止めずに動かせる敵調整パネル。
extends PanelContainer

const PANEL := preload("res://scripts/dev/stage_enemy_panel.gd")
var run: RunSimulation
var panel: Control
var _dragging := false
var _offset := Vector2.ZERO

func _ready() -> void:
	theme = Theme.new()
	theme.default_font_size = 16
	var box := VBoxContainer.new()
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "ステージ敵調整 [F4]  ⋮⋮"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(_drag)
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.pressed.connect(hide)
	header.add_child(close)
	panel = PANEL.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(panel)
	panel.bind_run(run.state.stage, run.cfg, run.enemies.stage_tuning)
	panel.tuning_changed.connect(func(values): run.enemies.update_stage_tuning(values))
	panel.saved.connect(func(stage):
		run.state.emit(&"enemy_tuning_saved", {"path": panel.stage_path, "values": stage.enemy_tuning.duplicate(true)}))
	get_viewport().size_changed.connect(_fit)
	minimum_size_changed.connect(func(): _fit.call_deferred())
	_fit()
	hide()

func _fit() -> void:
	var viewport := get_viewport_rect().size
	size = Vector2(minf(460, viewport.x - 32), minf(640, viewport.y - 48))
	position = Vector2(maxf(0, viewport.x - size.x - 16), 24)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		visible = not visible
		if visible: _fit.call_deferred()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and not event.pressed: _dragging = false
	if _dragging and event is InputEventMouseMotion:
		position = (get_global_mouse_position() - _offset).clamp(Vector2.ZERO, (get_viewport_rect().size - size).max(Vector2.ZERO))
		get_viewport().set_input_as_handled()

func _drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_offset = get_global_mouse_position() - position
