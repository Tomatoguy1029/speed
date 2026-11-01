## ボスの表示パーツだけを編集する。本番への保存は明示操作で行う。
extends Window

const PARTS = preload("res://scenes/bosses/monoceros_parts.tscn")
const UI := preload("res://gyms/enemy_lab/lab_ui.gd")
var lab
var rig
var _values: Dictionary = {}
var _keys: Array[String] = []
var _selector: OptionButton
var _color: ColorPickerButton
var _x: SpinBox
var _y: SpinBox
var _status: Label
var _preview: SubViewportContainer
var _camera: Camera2D
var _highlight: Line2D
var _playing := true
var _updating := false


func open_editor(owner_lab) -> void:
	lab = owner_lab
	UI.edit_shortcuts(self, lab)
	title = tr("lab.boss_parts.title")
	min_size = Vector2i(640, 420)
	close_requested.connect(queue_free)
	_build()
	for key in rig.editable_parts:
		_keys.append(String(key))
		_selector.add_item(String(rig.editable_parts[key].get_meta("part_label")))
	_values = _definition().part_appearance.duplicate(true)
	rig.apply_appearance(_values)
	_sync_fields()
	refresh_saved_state()
	popup_centered_ratio(0.85)


func _definition() -> BossDef:
	return lab.session.run.bosses.definitions[&"monoceros"]


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var split := HSplitContainer.new()
	margin.add_child(split)
	_preview = SubViewportContainer.new()
	_preview.stretch = true
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(220, 240)
	split.add_child(_preview)
	var viewport := SubViewport.new()
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("#172130")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background_layer := CanvasLayer.new()
	background_layer.layer = -10
	viewport.add_child(background_layer)
	background_layer.add_child(background)
	var world := Node2D.new()
	viewport.add_child(world)
	rig = PARTS.instantiate()
	world.add_child(rig)
	_camera = Camera2D.new()
	world.add_child(_camera)
	_highlight = Line2D.new()
	_highlight.width = 1.0
	_highlight.default_color = Color("#ffd16c")
	_highlight.z_index = 100
	world.add_child(_highlight)
	_preview.resized.connect(_layout_preview)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 310
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 10)
	scroll.add_child(panel)
	_label(panel, tr("lab.boss_parts.help"))
	_selector = OptionButton.new()
	_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selector.item_selected.connect(func(_index: int): _sync_fields())
	panel.add_child(_selector)
	_label(panel, tr("lab.boss_parts.color"))
	_color = ColorPickerButton.new()
	_color.custom_minimum_size.y = 36
	_color.edit_alpha = false
	_color.color_changed.connect(_paint)
	panel.add_child(_color)
	UI.edit_shortcuts(_color.get_popup(), lab)
	_x = _number(panel, tr("lab.boss_parts.x"), -256, 256, 0, _move)
	_y = _number(panel, tr("lab.boss_parts.y"), -256, 256, 0, _move)
	_button(panel, tr("lab.boss_parts.reset_part"), _reset_part)
	_button(panel, tr("lab.boss_parts.reset_all"), func(): _values.clear(); _commit(); _sync_fields())
	var play := CheckButton.new()
	play.text = tr("lab.boss_parts.play")
	play.button_pressed = true
	play.toggled.connect(func(enabled: bool): _playing = enabled)
	panel.add_child(play)
	_number(panel, tr("lab.boss_parts.rotation"), -180, 180, 0,
		func(value: float): rig.rotation = deg_to_rad(value))
	_number(panel, tr("lab.boss_parts.normal_strength"), 0, 3, 1, _preview_normal_strength, 0.05)
	_label(panel, tr("lab.boss_parts.preview_only"))
	_button(panel, tr("lab.boss_parts.save"), _save)
	_button(panel, tr("lab.appearance.save_all"), _save_all)
	_status = _label(panel, "")
	_label(panel, tr("lab.boss_parts.collision_help"))


func _preview_normal_strength(value: float) -> void:
	for part in rig.editable_parts.values():
		if part is Sprite2D: part.material.set_shader_parameter("normal_strength", value)


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func _number(parent: Node, text: String, minimum: float, maximum: float, initial: float, action: Callable, step := 1.0) -> SpinBox:
	_label(parent, text)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = initial
	spin.value_changed.connect(action)
	parent.add_child(spin)
	return spin


func _sync_fields() -> void:
	if _keys.is_empty(): return
	_updating = true
	var key := _keys[_selector.selected]
	var part: Node2D = rig.editable_parts[key]
	var values: Dictionary = _values.get(key, {})
	_color.disabled = not part is Sprite2D
	_color.tooltip_text = tr("lab.boss_parts.layer_help") if _color.disabled else ""
	_color.color = Color.from_string(values.get("color", "ffffff"), Color.WHITE)
	var offset: Array = values.get("offset", [0, 0])
	_x.set_value_no_signal(offset[0])
	_y.set_value_no_signal(offset[1])
	_updating = false


func _paint(color: Color) -> void:
	if _updating: return
	var key := _keys[_selector.selected]
	var value: Dictionary = _values.get(key, {}).duplicate(true)
	value["color"] = color.to_html(false)
	_values[key] = value
	_commit()


func _move(_value: float) -> void:
	if _updating: return
	var key := _keys[_selector.selected]
	var value: Dictionary = _values.get(key, {}).duplicate(true)
	value["offset"] = [_x.value, _y.value]
	_values[key] = value
	_commit()


func _reset_part() -> void:
	_values.erase(_keys[_selector.selected])
	_commit()
	_sync_fields()


func _commit() -> void:
	lab.session.perform("boss_appearance", {"type": "monoceros", "parts": _values.duplicate(true)})
	rig.apply_appearance(_values)
	refresh_saved_state()


func _save() -> void:
	commit_fields()
	_status.text = lab.controls.save_appearance_targets([{"type": &"monoceros", "boss": true}])


func _save_all() -> void:
	lab.controls._save_all_appearance()
	_status.text = lab._messages.text


func commit_fields() -> void:
	_x.apply()
	_y.apply()


func refresh_saved_state() -> void:
	_status.text = tr("lab.boss_parts.unsaved") if _definition().part_appearance != ContentManager.bosses[&"monoceros"].part_appearance else tr("lab.boss_parts.saved")


func _layout_preview() -> void:
	var factor := clampf(minf((_preview.size.x - 40) / 320.0, (_preview.size.y - 40) / 320.0), 0.25, 4.0)
	_camera.zoom = Vector2.ONE * factor


func _process(delta: float) -> void:
	if rig == null or _keys.is_empty() or not is_instance_valid(lab.session.run): return
	var current: Dictionary = _definition().part_appearance
	if hash(current) != hash(_values):
		_values = current.duplicate(true)
		rig.apply_appearance(_values)
		_sync_fields()
		refresh_saved_state()
	rig.advance_gait(delta, _playing)
	var part: Node2D = rig.editable_parts[_keys[_selector.selected]]
	var rect := _part_bounds(part)
	var transform := part.global_transform
	_highlight.points = PackedVector2Array([transform * rect.position, transform * Vector2(rect.end.x, rect.position.y),
		transform * rect.end, transform * Vector2(rect.position.x, rect.end.y), transform * rect.position])


func _part_bounds(part: Node2D) -> Rect2:
	if part is Sprite2D: return part.get_rect()
	var rect := Rect2()
	var first := true
	var inverse := part.global_transform.affine_inverse()
	for sprite: Sprite2D in part.find_children("*", "Sprite2D", true, false):
		var local := inverse * sprite.global_transform
		var bounds := sprite.get_rect()
		for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
			var point: Vector2 = local * corner
			if first:
				rect = Rect2(point, Vector2.ZERO)
				first = false
			else: rect = rect.expand(point)
	return rect
