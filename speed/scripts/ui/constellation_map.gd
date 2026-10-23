extends Control

signal back_requested
signal rotation_changed(radians: float)

const CYAN := Color("5bc8db")
const ORIGIN := Vector2(198, 195)
const CONSTELLATION_RADIUS := 84.0
const SYMBOL_ANGLES := [90.0, 180.0, 270.0, 0.0]
const DRAG_THRESHOLD := 4.0
const REVEAL_SETTINGS := preload("res://data/map_reveal_settings.tres")
const TEXTURES := [
	preload("res://assets/ui/map/constellations_unicorn.png"),
	preload("res://assets/ui/map/constellations_centeur.png"),
	preload("res://assets/ui/map/constellations_dog.png"),
	preload("res://assets/ui/map/constellations_snake.png"),
]
var _stars: Array[TextureButton] = []
var _inner1: Sprite2D
var _inner2: Sprite2D
var _preview: TextureRect
var _heading: Label
var _status: Label
var _launch: Button
var _back: Button
var _final_stage: Button
var _launch_requested := false
var _selected := 0
var _angle := 0.0
var _turn: Tween
var _projection: Node2D
var _origin := ORIGIN
var _flatten := 0.5
var _details: Control
var _detail_fade: Tween
var _detail_material: ShaderMaterial
var _monitor_material: ShaderMaterial
var _line_progress := 0.0
# プレビューでは複製した Resource を渡し、本番の調整値を保存せず比較できる。
var reveal_settings: Resource = REVEAL_SETTINGS
var _transition_progress := 0.0
var _dragging := false
var _pointer_down := false
var _press_position := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _last_drag_angle := 0.0
var _radial_drag := true
var _pressed_star := -1

func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := _artwork(preload("res://assets/ui/map/selection_screen_ui.png"), self)
	var frame_material := ShaderMaterial.new()
	frame_material.shader = preload("res://assets/ui/map/selection_frame.gdshader")
	frame.material = frame_material
	var projection := Node2D.new()
	_projection = projection
	projection.position = ORIGIN
	projection.scale = Vector2(1, 0.5)
	add_child(projection)
	_inner1 = _ring(projection, preload("res://assets/ui/map/ui_inner_circle1.png"))
	_inner1.offset = Vector2(48, 1)
	_inner2 = _ring(projection, preload("res://assets/ui/map/ui_inner_circle2.png"))
	_inner2.offset = Vector2(61, 35)
	_inner2.scale = Vector2.ONE * 0.7
	for i in TEXTURES.size():
		var star := TextureButton.new()
		star.name = "Constellation%d" % (i + 1)
		star.texture_normal = TEXTURES[i]
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.tooltip_text = tr("stage.%d.name" % (i + 1))
		star.pressed.connect(select_constellation.bind(i))
		star.draw.connect(_draw_star_focus.bind(star))
		star.focus_entered.connect(star.queue_redraw)
		star.focus_exited.connect(star.queue_redraw)
		star.focus_entered.connect(_on_stage_focus.bind(i))
		add_child(star)
		_stars.append(star)
	var back_fill := Polygon2D.new()
	back_fill.polygon = PackedVector2Array([Vector2(9, 9), Vector2(46, 9), Vector2(74, 34), Vector2(9, 34)])
	back_fill.color = Color("1f323d")
	add_child(back_fill)
	back_fill.hide()
	_artwork(preload("res://assets/ui/map/selection_screen_back_button.png"), self)
	var back := _button("", Vector2(7, 7), Vector2(74, 30))
	_back = back
	back.tooltip_text = tr("common.back")
	_transparent_button(back)
	back.mouse_entered.connect(back_fill.show)
	back.mouse_exited.connect(back_fill.hide)
	back.focus_entered.connect(back_fill.show)
	back.focus_exited.connect(back_fill.hide)
	back.pressed.connect(func(): back_requested.emit())
	_details = Control.new()
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.size = size
	add_child(_details)
	var detail_art := _artwork(preload("res://assets/ui/map/selection_screen_decorations.png"), self)
	_detail_material = ShaderMaterial.new()
	_detail_material.shader = preload("res://assets/ui/map/information_reveal.gdshader")
	detail_art.material = _detail_material
	_preview = TextureRect.new()
	_preview.position = Vector2(451, 88)
	_preview.size = Vector2(135, 82)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(_preview)
	_heading = _label(Vector2(444, 188), Vector2(152, 38), 14)
	_status = _label(Vector2(444, 235), Vector2(152, 24), 10)
	_launch = _button(tr("stage_select.launch"), Vector2(431, 293), Vector2(175, 34))
	_transparent_button(_launch)
	for content: Control in [_heading, _status, _launch]:
		content.reparent(_details)
	_launch.pressed.connect(_start)
	if ContentManager.stage_count() > 4:
		var final_stage := _button(tr("stage.5.name"), Vector2(224, 333), Vector2(150, 16))
		_final_stage = final_stage
		final_stage.add_theme_font_size_override("font_size", 11)
		_transparent_button(final_stage)
		final_stage.size = Vector2(150, 16)
		final_stage.pressed.connect(select_constellation.bind(4))
		final_stage.focus_entered.connect(_on_stage_focus.bind(4))
	get_window().focus_exited.connect(func():
		if _dragging:
			select_constellation(posmod(roundi(-_angle / 90.0), 4))
		_cancel_drag()
	)
	var monitor := ColorRect.new()
	monitor.size = size
	monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor.z_index = 100
	_monitor_material = ShaderMaterial.new()
	_monitor_material.shader = preload("res://assets/ui/map/monitor.gdshader")
	monitor.material = _monitor_material
	add_child(monitor)
	_select(0)
	_apply_rotation(0.0)
	_hide_details()
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_cancel_drag()
			_hide_details()
	)

func _artwork(texture: Texture2D, parent: Control) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = Vector2(640, 360)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _transparent_button(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_hover_color", CYAN)

func _hide_details() -> void:
	if _detail_fade != null:
		_detail_fade.kill()
	_set_detail_line(0.0)
	_set_detail_light(0.0)

func _reveal_details() -> void:
	if _transition_progress < 1.0 or not is_visible_in_tree():
		return
	_hide_details()
	_apply_reveal_settings()
	_detail_fade = create_tween()
	_detail_fade.tween_method(_set_detail_line, 0.0, 1.0, reveal_settings.line_duration)
	_detail_fade.tween_interval(reveal_settings.information_delay)
	_detail_fade.tween_method(_set_detail_light, 0.0, 1.0, reveal_settings.fade_duration)

func _apply_reveal_settings() -> void:
	for parameter: String in ["spectrum_speed", "spectrum_base_height", "spectrum_motion", "spectrum_correlation", "spectrum_peak_frequency", "spectrum_peak_strength", "orbit_speed"]:
		_detail_material.set_shader_parameter(parameter, reveal_settings.get(parameter))
	_monitor_material.set_shader_parameter("crt_strength", reveal_settings.crt_strength)

func _set_detail_line(progress: float) -> void:
	_line_progress = 1.0 - pow(1.0 - progress, reveal_settings.line_ease)
	_detail_material.set_shader_parameter("line_progress", _line_progress)
	queue_redraw()

func _set_detail_light(progress: float) -> void:
	var alpha := smoothstep(0.0, 1.0, progress)
	var glow: float = sin(progress * PI) * reveal_settings.glow_strength
	_details.modulate = Color(1.0 + glow, 1.0 + glow, 1.0 + glow, alpha)
	_detail_material.set_shader_parameter("information_alpha", alpha)
	_detail_material.set_shader_parameter("glow", glow)

func _draw() -> void:
	if _line_progress <= 0.0:
		return
	var selected: Control = _stars[_selected] if _selected < _stars.size() else _final_stage
	if selected == null:
		return
	var source := selected.position + selected.size * selected.scale * Vector2(1.0, 0.5)
	var points := PackedVector2Array([source.round(), Vector2(396, source.y).round(), Vector2(423, 210), Vector2(430, 210)])
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	var remaining := total * _line_progress
	for i in range(1, points.size()):
		var length := points[i - 1].distance_to(points[i])
		if length > 0.0:
			draw_line(points[i - 1], points[i - 1].lerp(points[i], minf(remaining / length, 1.0)).round(), Color("859b9f"), 1.0)
		remaining -= length
		if remaining <= 0.0:
			break

func _ring(parent: Node2D, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite

func _button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 16)
	add_child(button)
	return button

func _label(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func select_constellation(index: int) -> void:
	if _turn != null:
		_turn.kill()
	_hide_details()
	_select(index)
	_focus_selected()
	if index >= TEXTURES.size():
		_reveal_details()
		return
	var target := _angle + wrapf(90.0 - SYMBOL_ANGLES[index] - _angle, -180.0, 180.0)
	_turn = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_turn.tween_method(_apply_rotation, _angle, target, 0.65)
	_turn.tween_callback(_reveal_details)

func _on_stage_focus(index: int) -> void:
	if not _pointer_down and index != _selected:
		select_constellation(index)

## 回転中の星座と、円の外の最終ステージを実際の左右位置でたどる。
func _horizontal_neighbor(direction: int) -> int:
	var buttons: Array[Control] = []
	buttons.assign(_stars)
	if _final_stage != null:
		buttons.append(_final_stage)
	var from_x := buttons[_selected].get_global_rect().get_center().x
	var nearest := _selected
	var nearest_distance := INF
	var wrapped := _selected
	var wrap_edge := INF
	for i in buttons.size():
		if i == _selected:
			continue
		var x := buttons[i].get_global_rect().get_center().x
		var distance := (x - from_x) * direction
		# 同じ縦軸の星座を、浮動小数の誤差で左右の隣と見なさない。
		if distance > 0.5 and distance < nearest_distance:
			nearest = i
			nearest_distance = distance
		if x * direction < wrap_edge:
			wrapped = i
			wrap_edge = x * direction
	return nearest if nearest != _selected else wrapped

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _transition_progress < 1.0:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	# 左右は表示位置、上下は従来どおりのステージ順に選ぶ。
	if event.is_action(&"ui_left") or event.is_action(&"ui_up") or event.is_action(&"ui_right") or event.is_action(&"ui_down"):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			_cancel_drag()
			if event.is_action(&"ui_left") or event.is_action(&"ui_right"):
				select_constellation(_horizontal_neighbor(-1 if event.is_action(&"ui_left") else 1))
			else:
				var step := -1 if event.is_action(&"ui_up") else 1
				select_constellation(posmod(_selected + step, mini(ContentManager.stage_count(), 5)))
		return
	# 戻るにフォーカスがあるときは標準の決定を使い、それ以外は選択中の出撃。
	if event.is_action(&"ui_accept") and focus != _back:
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			_start()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			var star := _star_at(point)
			var offset := (point - _origin) / Vector2(1.0, _flatten)
			if star < 0 and offset.length() > 175.5:
				return
			_pointer_down = true
			_dragging = false
			_pressed_star = star
			_press_position = point
			_last_pointer = point
			_last_drag_angle = offset.angle()
			_radial_drag = offset.length() >= 20.0
			if star >= 0:
				_stars[star].grab_focus()
		elif _pointer_down:
			if _dragging:
				select_constellation(posmod(roundi(-_angle / 90.0), 4))
			elif _pressed_star >= 0 and _star_at(point) == _pressed_star:
				select_constellation(_pressed_star)
			_cancel_drag()
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pointer_down:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if not _dragging and point.distance_to(_press_position) >= DRAG_THRESHOLD:
			_dragging = true
			if _turn != null:
				_turn.kill()
			_hide_details()
		if _dragging:
			var offset := (point - _origin) / Vector2(1.0, _flatten)
			var delta_angle := (point.x - _last_pointer.x) * 0.7
			if _radial_drag:
				delta_angle = rad_to_deg(wrapf(offset.angle() - _last_drag_angle, -PI, PI)) if offset.length() >= 20.0 else 0.0
			var angle := _angle + delta_angle
			_select(posmod(roundi(-angle / 90.0), 4))
			_apply_rotation(angle)
			_last_drag_angle = offset.angle()
			_last_pointer = point
		get_viewport().set_input_as_handled()

func _star_at(point: Vector2) -> int:
	var found := -1
	for i in _stars.size():
		var star := _stars[i]
		if Rect2(star.position, star.size * star.scale).has_point(point):
			if found < 0 or star.z_index > _stars[found].z_index:
				found = i
	return found

func _cancel_drag() -> void:
	_pointer_down = false
	_dragging = false
	_pressed_star = -1

func _select(index: int) -> void:
	_selected = index
	var stage := index + 1
	var unlocked := OS.is_debug_build() or SaveManager.is_stage_unlocked(stage)
	_heading.text = tr("stage.%d.name" % stage)
	_preview.texture = TEXTURES[index] if index < TEXTURES.size() else null
	_launch.disabled = not unlocked
	_status.text = tr("stage_select.debug") if OS.is_debug_build() else (tr("stage_select.available") if unlocked else tr("stage_select.locked").format({n = stage}))
	_apply_rotation(_angle)

func _apply_rotation(degrees: float) -> void:
	_angle = degrees
	var radians := deg_to_rad(degrees)
	rotation_changed.emit(radians)
	_inner1.position = Vector2(0, -48).rotated(-radians)
	_inner1.rotation = -radians * 5.0
	_inner2.position = _inner1.position + Vector2(-40, 38).rotated(radians)
	_inner2.rotation = radians * 35.0 / 30.0
	for i in _stars.size():
		var angle := deg_to_rad(degrees + SYMBOL_ANGLES[i])
		var depth := sin(angle)
		var factor := 0.85 + depth * 0.15
		var star := _stars[i]
		star.scale = Vector2.ONE * factor
		star.position = _origin + Vector2(cos(angle), depth * _flatten) * CONSTELLATION_RADIUS - TEXTURES[i].get_size() * factor * 0.5
		star.z_index = roundi(10 + depth * 4)
		star.modulate = Color.WHITE if i == _selected else Color(0.55, 0.55, 0.55)
	if _final_stage != null:
		_final_stage.add_theme_color_override("font_color", CYAN if _selected == 4 else Color.WHITE)

func _draw_star_focus(star: TextureButton) -> void:
	if star.has_focus():
		star.draw_rect(Rect2(Vector2.ZERO, star.size), CYAN, false, 1.0)

func set_transition(progress: float) -> void:
	_transition_progress = progress
	if progress < 1.0:
		_cancel_drag()
		_hide_details()
	_origin = Vector2(462, 176).lerp(ORIGIN, progress)
	_flatten = lerpf(1.0, 0.5, progress)
	_projection.position = _origin
	_projection.scale.y = _flatten
	_apply_rotation(_angle)

func focus_selection() -> void:
	_launch_requested = false
	_focus_selected()
	_reveal_details()

func _focus_selected() -> void:
	if _selected < _stars.size():
		_stars[_selected].grab_focus()
	elif _final_stage != null:
		_final_stage.grab_focus()

func _start() -> void:
	if _launch_requested or GameManager.screen_transition_active:
		return
	if OS.is_debug_build() or SaveManager.is_stage_unlocked(_selected + 1):
		_launch_requested = true
		AudioManager.play(&"ui")
		GameManager.start_run(_selected + 1)
