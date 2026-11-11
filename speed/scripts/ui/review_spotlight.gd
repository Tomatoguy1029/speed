## 審査版の操作場所を示す。実際の画面座標へ追従し、終了時に表示を解放する。
extends Control
signal finished
var target: Control
var message := ""
var action := false
var _box: PanelContainer
var _hole := Rect2()
var _skip_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = PanelContainer.new()
	add_child(_box)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101b2c")
	style.border_color = Color("5bc8db")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_box.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_box.add_child(column)
	var label := Label.new()
	label.text = tr(message)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	column.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(row)
	var next := Button.new()
	next.text = tr("review.guide.next")
	next.visible = not action
	next.pressed.connect(_finish)
	row.add_child(next)
	var skip := Button.new()
	skip.text = tr("review.guide.skip")
	skip.pressed.connect(func():
		set_meta("skipped", true)
		_finish())
	add_child(skip)
	_skip_button = skip
	if not action: next.grab_focus()
	if action and target is Button:
		target.pressed.connect(_finish, CONNECT_ONE_SHOT)

func _process(_delta: float) -> void:
	_hole = Rect2()
	_skip_button.position = size - _skip_button.size - Vector2(24, 24)
	if is_instance_valid(target) and target.is_visible_in_tree():
		var transform := get_screen_transform().affine_inverse() * target.get_screen_transform()
		_hole = (transform * Rect2(Vector2.ZERO, target.size)).grow(10)
	_box.size = Vector2(minf(540, size.x - 32), 0)
	var edge := Vector2(16, 16)
	var limit := size - _box.size - Vector2(16, 80)
	if _hole.size == Vector2.ZERO:
		_box.position = (size - _box.size) * 0.5
	elif _hole.end.x + 24 + _box.size.x <= size.x - 16:
		_box.position = Vector2(_hole.end.x + 24, clampf(_hole.position.y, 16, maxf(16, limit.y)))
	elif _hole.position.x - 24 - _box.size.x >= 16:
		_box.position = Vector2(_hole.position.x - 24 - _box.size.x, clampf(_hole.position.y, 16, maxf(16, limit.y)))
	else:
		var below := _hole.end.y + 24
		var top := below if below <= limit.y else _hole.position.y - _box.size.y - 24
		_box.position = Vector2(clampf(_hole.position.x, edge.x, maxf(edge.x, limit.x)), clampf(top, edge.y, maxf(edge.y, limit.y)))
	queue_redraw()

func _draw() -> void:
	var shade := Color(0, 0, 0, 0.67)
	if _hole.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, size), shade)
		return
	draw_rect(Rect2(0, 0, size.x, maxf(0, _hole.position.y)), shade)
	draw_rect(Rect2(0, _hole.end.y, size.x, maxf(0, size.y - _hole.end.y)), shade)
	draw_rect(Rect2(0, _hole.position.y, maxf(0, _hole.position.x), _hole.size.y), shade)
	draw_rect(Rect2(_hole.end.x, _hole.position.y, maxf(0, size.x - _hole.end.x), _hole.size.y), shade)
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color.TRANSPARENT
	outline.border_color = Color("5bc8db")
	outline.set_border_width_all(2)
	outline.set_corner_radius_all(10)
	draw_style_box(outline, _hole)

func _has_point(point: Vector2) -> bool:
	return not (action and _hole.has_point(point))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if action and event.is_action_pressed("pause") and target == null:
			_finish()
		elif not action and event.is_action_pressed("ui_accept"):
			_finish()
		elif action and target is Button and event.is_action_pressed("ui_accept"):
			target.pressed.emit()
		elif event.is_action_pressed("ui_cancel"):
			set_meta("skipped", true)
			_finish()
		get_viewport().set_input_as_handled()

func _finish() -> void:
	finished.emit()
