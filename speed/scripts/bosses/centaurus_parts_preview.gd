## 基礎ポーズを複製し、攻撃用のコマを手付けする制作画面。
extends Node2D

const CLIP_NAMES := {"shower_windup": "降り注ぐ矢：構え", "shower": "降り注ぐ矢：降下", "shower_recovery": "降り注ぐ矢：戻し", "fan_windup": "一斉射撃：引き絞り", "fan_release": "一斉射撃：発射", "fan_recovery": "一斉射撃：戻し", "stomp_windup": "前脚の踏みつけ：構え", "stomp": "前脚の踏みつけ", "stomp_recovery": "前脚の踏みつけ：戻し", "leap": "跳び退き", "run": "離脱"}
const CLIPS := ["idle", "shot_windup", "shot_release", "shot_recovery", "rain_windup", "rain", "rain_recovery", "shower_windup", "shower", "shower_recovery", "fan_windup", "fan_release", "fan_recovery", "stomp_windup", "stomp", "stomp_recovery", "leap", "run"]
const DATA_PATH := "res://data/visuals/centaurus_animation.tres"
var _source_path := DATA_PATH
var _source_hash := ""
var _data: Resource
var _parts: Array[Node2D] = []
var _pose_key := "neutral"
var _clip_key := ""
var _frame_index := 0
var _playing := false
var _play_time := 0.0
var _zoom := 1.0
var _dragging := false
var _panning := false
var _pan_button := MOUSE_BUTTON_MIDDLE
var _pan_offset := Vector2.ZERO
var _drag_start := Vector2.ZERO
var _part_start := Vector2.ZERO
var _panel: PanelContainer
var _pose_selector: OptionButton
var _clip_selector: OptionButton
var _frame_selector: OptionButton
var _selector: OptionButton
var _pose_name: LineEdit
var _timeline: PanelContainer
var _frame_box: VBoxContainer
var _duration: SpinBox
var _interpolate: CheckBox
var _loop: CheckBox
var _play: Button
var _x: SpinBox
var _y: SpinBox
var _angle: SpinBox
var _scale_x: SpinBox
var _scale_y: SpinBox
var _depth: SpinBox
var _zoom_field: SpinBox
var _visible: CheckBox
var _bow: OptionButton
var _bow_label: Label
var _status: Label
var _highlight: Line2D
var _file_dialog: FileDialog
var _rig_mode := 0
var _rig_side := "right"
var _joint_drag := ""
var _joint_grab_offset := Vector2.ZERO
var _pivot_drag := ""
var _pivot_fixed := Vector2.ZERO
var _pivot_start_rotation := 0.0
var _pivot_start_mouse := 0.0
var _pivot_box: VBoxContainer
var _pivot_enabled: CheckBox
var _pivot_setup: CheckBox
var _pivot_help: Label
var _rig_mode_selector: OptionButton
var _rig_box: VBoxContainer
var _rig_pose_box: VBoxContainer
var _rig_connected: CheckBox
var _joint_angles: Array[SpinBox] = []
var _rig_bow: OptionButton
var _joint_overlay: Control

func _ready() -> void:
	_data = $Parts.animation_data.duplicate(true)
	$Parts.animation_data = _data
	_source_hash = FileAccess.get_sha256(_source_path)
	_collect($Parts)
	_build_controls()
	_refresh_poses()
	_refresh_parts()
	_apply_current()
	get_viewport().size_changed.connect(_fit)
	_fit()

func _collect(parent: Node) -> void:
	for child in parent.get_children():
		if child is Node2D and child.has_meta("part_label"): _parts.append(child)
		_collect(child)

func _button(parent: Node, key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, key: String) -> Label:
	var label := Label.new()
	label.text = tr(key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _option(parent: Node) -> OptionButton:
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.clip_text = true
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(option)
	return option

func _number(parent: Node, key: String, minimum: float, maximum: float, step: float, action: Callable) -> SpinBox:
	var label := _label(parent, key)
	if parent is HFlowContainer: label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value_changed.connect(action)
	parent.add_child(field)
	return field

func _build_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_panel = PanelContainer.new()
	canvas.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	_label(column, "centaurus.anim.title")
	_button(column, "centaurus.anim.save", _save)
	_status = _label(column, "centaurus.anim.saved")
	_label(column, "centaurus.anim.base_pose")
	_pose_selector = _option(column)
	_pose_selector.item_selected.connect(_select_pose)
	_pose_name = LineEdit.new()
	_pose_name.placeholder_text = tr("centaurus.anim.pose_name")
	column.add_child(_pose_name)
	_button(column, "centaurus.anim.create_pose", _create_pose)
	_label(column, "centaurus.anim.target")
	_clip_selector = _option(column)
	_clip_selector.add_item(tr("centaurus.anim.pose_mode"))
	for clip in CLIPS: _clip_selector.add_item(CLIP_NAMES.get(clip, tr("centaurus.anim." + clip)))
	_clip_selector.item_selected.connect(_select_clip)
	_build_timeline(canvas)
	_build_joint_controls(column)
	_label(column, "centaurus.anim.part")
	_selector = _option(column)
	_selector.item_selected.connect(func(_index: int):
		_stop_play()
		_pivot_drag = ""
		_pivot_setup.set_pressed_no_signal(false)
		_sync_fields())
	_build_pivot_controls(column)
	_visible = CheckBox.new()
	_visible.text = tr("centaurus.anim.visible")
	_visible.toggled.connect(_edit)
	column.add_child(_visible)
	_bow_label = _label(column, "centaurus.anim.bow")
	_bow = _option(column)
	for variant in $Parts.BOW_VARIANT_ORDER: _bow.add_item(tr("centaurus.anim.bow_" + str(variant)), variant)
	_bow.item_selected.connect(func(index: int): _edit_bow(_bow.get_item_id(index)))
	var fields := GridContainer.new()
	fields.columns = 2
	column.add_child(fields)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(right)
	_x = _number(left, "centaurus.anim.x", -2000, 2000, 1, _edit)
	_y = _number(right, "centaurus.anim.y", -2000, 2000, 1, _edit)
	_scale_x = _number(left, "centaurus.anim.scale_x", 0.05, 8, 0.05, _edit)
	_scale_y = _number(right, "centaurus.anim.scale_y", 0.05, 8, 0.05, _edit)
	_angle = _number(left, "centaurus.anim.rotation", -360, 360, 1, _edit)
	_depth = _number(right, "centaurus.anim.depth", -100, 100, 1, _edit)
	_button(column, "centaurus.anim.duplicate_part", _duplicate_part)
	_button(column, "centaurus.anim.add_png", func(): _stop_play(); _file_dialog.popup_centered_ratio(0.7))
	_zoom_field = _number(column, "centaurus.parts.zoom", 0.25, 4, 0.25, func(value: float): _zoom = value; _fit())
	_zoom_field.value = 1
	_button(column, "centaurus.anim.reset_view", func(): _pan_offset = Vector2.ZERO; _zoom_field.value = 1.0; _fit())
	_label(column, "centaurus.anim.help")
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.png ; PNG"])
	_file_dialog.file_selected.connect(_add_png)
	canvas.add_child(_file_dialog)
	_joint_overlay = Control.new()
	_joint_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joint_overlay.z_index = -1
	_joint_overlay.draw.connect(_draw_joints)
	canvas.add_child(_joint_overlay)
	_highlight = Line2D.new()
	_highlight.default_color = Color("#ffd16c")
	_highlight.width = 0.75
	_highlight.z_index = 1000
	add_child(_highlight)

func _build_pivot_controls(column: VBoxContainer) -> void:
	_pivot_box = VBoxContainer.new()
	column.add_child(_pivot_box)
	_pivot_enabled = CheckBox.new()
	_pivot_enabled.text = tr("centaurus.pivot.enabled")
	_pivot_enabled.clip_text = true
	_pivot_enabled.tooltip_text = _pivot_enabled.text
	_pivot_box.add_child(_pivot_enabled)
	_pivot_enabled.toggled.connect(func(enabled: bool):
		_stop_play()
		_pivot_drag = ""
		var path := String($Parts.get_path_to(_selected()))
		_data.set_part_pivot(path, Vector2.ZERO if enabled else null)
		_commit_pose()
		_sync_fields())
	_pivot_setup = CheckBox.new()
	_pivot_setup.text = tr("centaurus.pivot.setup")
	_pivot_setup.clip_text = true
	_pivot_setup.tooltip_text = _pivot_setup.text
	_pivot_setup.toggled.connect(func(_enabled: bool): _pivot_drag = ""; _stop_play())
	_pivot_box.add_child(_pivot_setup)
	_pivot_help = _label(_pivot_box, "centaurus.pivot.help")

func _sync_pivot_controls() -> void:
	var path := String($Parts.get_path_to(_selected()))
	var enabled: bool = _data.part_pivots.has(path)
	_pivot_enabled.set_pressed_no_signal(enabled)
	_pivot_enabled.disabled = not $Parts.arm_rig.side_for(_selected()).is_empty() or _selected().has_meta("bow_variant")
	_pivot_setup.disabled = not enabled
	_pivot_setup.visible = enabled
	_pivot_help.visible = enabled
	if not enabled: _pivot_setup.set_pressed_no_signal(false)

func _preserve_part_pivot(part: Node2D, world: Vector2) -> void:
	var parent := part.get_parent() as Node2D
	var point: Vector2 = _data.part_pivots[String($Parts.get_path_to(part))]
	var offset := part.transform * point - part.position
	part.position = parent.to_local(world) - offset

func _part_pivot_screen() -> Vector2:
	var part := _selected()
	var point: Vector2 = _data.part_pivots[String($Parts.get_path_to(part))]
	return get_canvas_transform() * part.to_global(point)

func _draw_part_pivot() -> void:
	if not _data.part_pivots.has(String($Parts.get_path_to(_selected()))): return
	var at := _part_pivot_screen()
	var handle := at + Vector2(30, 0).rotated(_selected().global_rotation)
	var color := Color("#94e7ac")
	_joint_overlay.draw_line(at, handle, color, 1.5)
	_joint_overlay.draw_circle(at, 5.0, color)
	_joint_overlay.draw_arc(at, 9.0, 0.0, TAU, 24, color, 1.0)
	_joint_overlay.draw_circle(handle, 5.0, color)
	_joint_overlay.draw_string(ThemeDB.fallback_font, at + Vector2(10, -12), tr("centaurus.pivot.point"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	_joint_overlay.draw_string(ThemeDB.fallback_font, handle + Vector2(8, 15), tr("centaurus.pivot.rotate"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _begin_part_rotation(world: Vector2) -> void:
	var part := _selected()
	var path := String($Parts.get_path_to(part))
	_pivot_fixed = part.to_global(_data.part_pivots[path])
	if world.distance_to(_pivot_fixed) * $Camera2D.zoom.x < 4.0: return
	var parent := part.get_parent() as Node2D
	_pivot_start_mouse = (parent.to_local(world) - parent.to_local(_pivot_fixed)).angle()
	_pivot_start_rotation = part.rotation
	_dragging = false
	_pivot_drag = "rotate"

func _begin_part_pivot_drag(screen: Vector2) -> bool:
	var part := _selected()
	var path := String($Parts.get_path_to(part))
	if not _data.part_pivots.has(path): return false
	var world: Vector2 = get_canvas_transform().affine_inverse() * screen
	if _pivot_setup.button_pressed:
		_pivot_drag = "place"
		_dragging = false
		_move_part_pivot(world)
		return true
	var handle := _part_pivot_screen() + Vector2(30, 0).rotated(part.global_rotation)
	if screen.distance_to(handle) > 12.0: return false
	_begin_part_rotation(world)
	return true

func _move_part_pivot(world: Vector2) -> void:
	var part := _selected()
	if _pivot_drag == "place":
		_data.set_part_pivot(String($Parts.get_path_to(part)), part.to_local(world))
	else:
		var parent := part.get_parent() as Node2D
		var angle := (parent.to_local(world) - parent.to_local(_pivot_fixed)).angle()
		part.rotation = _pivot_start_rotation + wrapf(angle - _pivot_start_mouse, -PI, PI)
		_preserve_part_pivot(part, _pivot_fixed)
	_commit_pose()
	_sync_fields()

func _build_joint_controls(column: VBoxContainer) -> void:
	_label(column, "centaurus.rig.mode")
	_rig_mode_selector = _option(column)
	for mode in ["parts", "setup", "pose"]: _rig_mode_selector.add_item(tr("centaurus.rig." + mode))
	_rig_mode_selector.item_selected.connect(_set_rig_mode)
	_rig_box = VBoxContainer.new()
	_rig_box.visible = false
	column.add_child(_rig_box)
	var side := _option(_rig_box)
	side.add_item(tr("centaurus.rig.right"))
	side.add_item(tr("centaurus.rig.left"))
	side.item_selected.connect(func(index: int):
		_rig_side = "right" if index == 0 else "left"
		_joint_drag = ""
		_sync_joint_controls())
	_button(_rig_box, "centaurus.rig.reset", func():
		_stop_play()
		$Parts.arm_rig.reset_definition(_rig_side)
		_commit_pose()
		_sync_fields())
	_rig_pose_box = VBoxContainer.new()
	_rig_box.add_child(_rig_pose_box)
	_rig_connected = CheckBox.new()
	_rig_connected.text = tr("centaurus.rig.connected")
	_rig_connected.toggled.connect(func(enabled: bool):
		_stop_play()
		$Parts.arm_rig.set_connected(_rig_side, enabled)
		_commit_pose()
		_sync_fields())
	_rig_pose_box.add_child(_rig_connected)
	var angles := GridContainer.new()
	angles.columns = 3
	_rig_pose_box.add_child(angles)
	for index in 3:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		angles.add_child(box)
		var joint_index := index
		_joint_angles.append(_number(box, "centaurus.rig." + ["shoulder", "elbow", "wrist"][index], -360, 360, 1,
			func(value: float):
				_stop_play()
				$Parts.arm_rig.set_rotation(_rig_side, joint_index, deg_to_rad(value))
				_commit_pose()
				_sync_fields()))
	_button(_rig_pose_box, "centaurus.rig.flip", func():
		_stop_play()
		var target: Vector2 = $Parts.arm_rig.points(_rig_side).grip
		$Parts.arm_rig.definition(_rig_side).bend *= -1.0
		if $Parts.arm_rig.solve(_rig_side, target): _commit_pose()
		else: _status.text = tr("centaurus.rig.invalid")
		_sync_fields())
	_label(_rig_pose_box, "centaurus.rig.bow")
	_rig_bow = _option(_rig_pose_box)
	_button(_rig_pose_box, "centaurus.rig.bind", func():
		if _rig_bow.selected < 0: return
		_stop_play()
		var bow := $Parts.get_node(NodePath(_rig_bow.get_item_metadata(_rig_bow.selected))) as Node2D
		$Parts.arm_rig.bind_bow(bow, _rig_side)
		_commit_pose()
		_sync_fields())
	_button(_rig_pose_box, "centaurus.rig.unbind", func():
		if _rig_bow.selected < 0: return
		_stop_play()
		var bow := $Parts.get_node(NodePath(_rig_bow.get_item_metadata(_rig_bow.selected))) as Node2D
		bow.set_meta("bow_hand", "")
		_commit_pose()
		_sync_fields())
	_label(_rig_box, "centaurus.rig.help")

func _set_rig_mode(mode: int) -> void:
	_stop_play()
	_joint_drag = ""
	_dragging = false
	_rig_mode = mode
	_pivot_drag = ""
	_pivot_setup.set_pressed_no_signal(false)
	_pivot_box.visible = mode == 0
	_rig_box.visible = mode > 0
	_rig_pose_box.visible = mode == 2
	if mode > 0 and $Parts.arm_rig.ensure_definitions(): _changed()
	if mode != 1: $Parts.apply_pose(_current_pose())
	_sync_joint_controls()
	_joint_overlay.queue_redraw()

func _sync_joint_controls() -> void:
	if _rig_mode == 0: return
	var rig: RefCounted = $Parts.arm_rig
	_rig_connected.set_pressed_no_signal(rig.connected(_rig_side))
	var nodes: Array = [rig.upper(_rig_side), rig.lower(_rig_side), rig.hand(_rig_side)]
	for index in 3: _joint_angles[index].set_value_no_signal(rad_to_deg(nodes[index].rotation))
	var selected := "Bow"
	if _rig_bow.selected >= 0: selected = String(_rig_bow.get_item_metadata(_rig_bow.selected))
	if _selected().has_meta("bow_variant"): selected = String($Parts.get_path_to(_selected()))
	_rig_bow.clear()
	for part in _parts:
		if not part.has_meta("bow_variant"): continue
		var path := String($Parts.get_path_to(part))
		_rig_bow.add_item(path)
		_rig_bow.set_item_metadata(_rig_bow.item_count - 1, path)
		if path == selected: _rig_bow.select(_rig_bow.item_count - 1)
	if _rig_bow.selected < 0 and _rig_bow.item_count > 0: _rig_bow.select(0)
	_joint_overlay.queue_redraw()

func _joint_screen_points() -> Dictionary:
	var result := {}
	if _rig_mode == 0: return result
	var points: Dictionary = $Parts.arm_rig.points(_rig_side)
	for key in points: result[key] = get_canvas_transform() * points[key]
	return result

func _draw_joints() -> void:
	if _rig_mode == 0:
		_draw_part_pivot()
		return
	var points := _joint_screen_points()
	var color := Color("#70dcff") if _rig_side == "right" else Color("#ffd373")
	var names := ["shoulder", "elbow", "wrist", "grip"]
	var offsets := {"shoulder": Vector2(10, -10), "elbow": Vector2(10, -10), "wrist": Vector2(10, 16), "grip": Vector2(-28, 18)}
	for index in range(3): _joint_overlay.draw_line(points[names[index]], points[names[index + 1]], Color(color, 0.85), 1.5)
	for joint in names:
		_joint_overlay.draw_circle(points[joint], 6.0 if joint == "grip" else 4.0, color)
		_joint_overlay.draw_arc(points[joint], 8.0, 0.0, TAU, 20, Color("#19202d"), 1.0)
		_joint_overlay.draw_string(ThemeDB.fallback_font, points[joint] + offsets[joint], tr("centaurus.rig." + joint), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _begin_joint_drag(screen: Vector2) -> void:
	var points := _joint_screen_points()
	var nearest := ""
	var distance := 12.0
	for joint in points:
		var current: float = screen.distance_to(points[joint])
		if current < distance:
			nearest = joint
			distance = current
	if nearest.is_empty(): return
	var rig: RefCounted = $Parts.arm_rig
	var world: Vector2 = get_canvas_transform().affine_inverse() * screen
	_joint_grab_offset = rig.points(_rig_side)[nearest] - world
	_joint_drag = nearest
	if _rig_mode == 1: return
	var part: Node2D = {"shoulder": rig.upper(_rig_side), "elbow": rig.lower(_rig_side), "wrist": rig.hand(_rig_side), "grip": rig.hand(_rig_side)}[nearest]
	_selector.select(_parts.find(part))
	_sync_fields()

func _flow(parent: Node) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	parent.add_child(row)
	return row

func _build_timeline(canvas: CanvasLayer) -> void:
	_timeline = PanelContainer.new()
	canvas.add_child(_timeline)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 10)
	_timeline.add_child(margin)
	_frame_box = VBoxContainer.new()
	_frame_box.add_theme_constant_override("separation", 6)
	margin.add_child(_frame_box)
	var navigation := HBoxContainer.new()
	_frame_box.add_child(navigation)
	_frame_selector = _option(navigation)
	_frame_selector.item_selected.connect(_select_frame)
	_button(navigation, "centaurus.anim.previous", func(): _select_frame(maxi(0, _frame_index - 1)))
	_button(navigation, "centaurus.anim.next", func(): _select_frame(mini(_frames().size() - 1, _frame_index + 1)))
	var actions := _flow(_frame_box)
	_button(actions, "centaurus.anim.duplicate_frame", _duplicate_frame)
	_button(actions, "centaurus.anim.delete_frame", _delete_frame)
	_button(actions, "centaurus.anim.from_pose", _apply_base_pose)
	var timing := _flow(_frame_box)
	_button(timing, "centaurus.anim.move_before", func(): _move_frame(-1))
	_button(timing, "centaurus.anim.move_after", func(): _move_frame(1))
	_duration = _number(timing, "centaurus.anim.duration", 20, 10000, 10, _edit_frame)
	_duration.tooltip_text = tr("centaurus.anim.timing_help")
	var playback := _flow(_frame_box)
	_interpolate = CheckBox.new()
	_interpolate.text = tr("centaurus.anim.interpolate")
	_interpolate.toggled.connect(_edit_frame)
	playback.add_child(_interpolate)
	_play = _button(playback, "centaurus.anim.play", _toggle_play)
	_loop = CheckBox.new()
	_loop.text = tr("centaurus.anim.loop")
	_loop.button_pressed = true
	playback.add_child(_loop)

func _refresh_poses() -> void:
	_pose_selector.clear()
	for key in _data.poses:
		_pose_selector.add_item(tr("centaurus.anim." + key) if key in ["neutral", "aim", "up"] else key)
	_pose_selector.select(_data.poses.keys().find(_pose_key))

func _refresh_parts() -> void:
	var selected_path := ""
	if not _parts.is_empty() and _selector.selected >= 0:
		selected_path = String($Parts.get_path_to(_parts[_selector.selected]))
	_parts.clear()
	_collect($Parts)
	_selector.clear()
	for part in _parts:
		var path := String($Parts.get_path_to(part))
		_selector.add_item(tr("centaurus.pivot.head") if path == "LowerBody" else path)
		if path == selected_path: _selector.select(_selector.item_count - 1)
	if _selector.selected < 0: _selector.select(0)

func _frames() -> Array:
	return _data.clips[_clip_key]

func _current_pose() -> Dictionary:
	return _data.poses[_pose_key] if _clip_key.is_empty() else _frames()[_frame_index].pose

func _commit_pose() -> void:
	if _rig_mode != 1:
		$Parts.arm_rig.connect_active()
		$Parts.arm_rig.follow_bows()
	$Parts.sort_bases()
	var pose: Dictionary = $Parts.capture_pose()
	if _clip_key.is_empty(): _data.poses[_pose_key] = pose
	else: _frames()[_frame_index].pose = pose
	_changed()

func _changed() -> void:
	_status.text = tr("centaurus.anim.unsaved")

func _apply_current() -> void:
	$Parts.apply_pose(_current_pose())
	_timeline.visible = not _clip_key.is_empty()
	if not _clip_key.is_empty(): _refresh_frames()
	_fit()
	_sync_fields()

func _refresh_frames() -> void:
	_frame_selector.clear()
	var frames := _frames()
	for index in frames.size():
		_frame_selector.add_item("%02d  •  %d ms" % [index + 1, roundi(float(frames[index].duration) * 1000)])
	_frame_selector.select(_frame_index)
	_duration.set_value_no_signal(float(frames[_frame_index].duration) * 1000)
	_interpolate.set_pressed_no_signal(bool(frames[_frame_index].get("interpolate", false)))

func _select_pose(index: int) -> void:
	_stop_play()
	_pose_key = _data.poses.keys()[index]
	if _clip_key.is_empty(): _apply_current()

func _select_clip(index: int) -> void:
	_stop_play()
	_clip_key = "" if index == 0 else CLIPS[index - 1]
	_frame_index = 0
	if not _clip_key.is_empty() and _frames().is_empty():
		_frames().append({"duration": 0.15, "interpolate": false, "pose": _data.poses[_pose_key].duplicate(true)})
		_changed()
	_apply_current()

func _create_pose() -> void:
	_stop_play()
	var key := _pose_name.text.strip_edges()
	if key.is_empty() or _data.poses.has(key):
		_status.text = tr("centaurus.anim.unique_name")
		return
	_data.poses[key] = $Parts.capture_pose()
	_pose_key = key
	_pose_name.clear()
	_refresh_poses()
	_changed()

func _select_frame(index: int) -> void:
	_stop_play()
	_frame_index = index
	_apply_current()

func _duplicate_frame() -> void:
	_stop_play()
	_frames().insert(_frame_index + 1, _frames()[_frame_index].duplicate(true))
	_frame_index += 1
	_changed()
	_apply_current()

func _delete_frame() -> void:
	if _frames().size() <= 1: return
	_stop_play()
	_frames().remove_at(_frame_index)
	_frame_index = mini(_frame_index, _frames().size() - 1)
	_changed()
	_apply_current()

func _apply_base_pose() -> void:
	_stop_play()
	_frames()[_frame_index].pose = _data.poses[_pose_key].duplicate(true)
	_changed()
	_apply_current()

func _move_frame(direction: int) -> void:
	var next := _frame_index + direction
	if next < 0 or next >= _frames().size(): return
	_stop_play()
	var frame: Dictionary = _frames()[_frame_index]
	_frames().remove_at(_frame_index)
	_frames().insert(next, frame)
	_frame_index = next
	_changed()
	_apply_current()

func _edit_frame(_value: Variant) -> void:
	_stop_play()
	_frames()[_frame_index].duration = _duration.value / 1000.0
	_frames()[_frame_index].interpolate = _interpolate.button_pressed
	_refresh_frames()
	_changed()

func _selected() -> Node2D:
	return _parts[_selector.selected]

func _sync_fields() -> void:
	var part := _selected()
	_x.set_value_no_signal(part.position.x)
	_y.set_value_no_signal(part.position.y)
	_angle.set_value_no_signal(rad_to_deg(part.rotation))
	_scale_x.set_value_no_signal(part.scale.x)
	_scale_y.set_value_no_signal(part.scale.y)
	_depth.set_value_no_signal(part.z_index)
	_visible.set_pressed_no_signal(part.visible)
	var variant := int(part.get_meta("bow_variant", -1))
	_bow.visible = variant >= 0
	_bow_label.visible = variant >= 0
	if variant >= 0: _bow.select($Parts.BOW_VARIANT_ORDER.find(variant))
	_sync_joint_controls()
	_sync_pivot_controls()
	_update_highlight()

func _edit(_value: Variant) -> void:
	_stop_play()
	var part := _selected()
	var side: String = $Parts.arm_rig.side_for(part)
	var keep_pivot: bool = not side.is_empty() and not $Parts.arm_rig.definition(side).is_empty() and $Parts.arm_rig.connected(side)
	var part_path := String($Parts.get_path_to(part))
	var custom_pivot: bool = _data.part_pivots.has(part_path)
	var pivot := Vector2.ZERO
	if custom_pivot: pivot = part.to_global(_data.part_pivots[part_path])
	elif keep_pivot: pivot = part.to_global($Parts.arm_rig.pivot_for(side, part))
	var rotating := not is_equal_approx(part.rotation, deg_to_rad(_angle.value))
	var scaling := not part.scale.is_equal_approx(Vector2(_scale_x.value, _scale_y.value))
	part.position = Vector2(_x.value, _y.value)
	part.rotation = deg_to_rad(_angle.value)
	part.scale = Vector2(_scale_x.value, _scale_y.value)
	part.z_index = roundi(_depth.value)
	part.visible = _visible.button_pressed
	if custom_pivot and (rotating or scaling): _preserve_part_pivot(part, pivot)
	elif keep_pivot and (rotating or scaling): $Parts.arm_rig.preserve_pivot(side, part, pivot)
	if not String(part.get_meta("bow_hand", "")).is_empty(): $Parts.arm_rig.update_bow_offset(part)
	_commit_pose()
	_sync_fields()

func _edit_bow(variant: int) -> void:
	_stop_play()
	$Parts._set_bow_variant(_selected(), variant)
	_commit_pose()
	_update_highlight()

func _duplicate_part() -> void:
	_stop_play()
	var source := _selected()
	var path := String(source.get_meta("source_template", String($Parts.get_path_to(source))))
	var definition := {"name": _new_part_name(), "template": path}
	var part: Node2D = $Parts.add_extra(definition)
	part.global_transform = source.global_transform
	_register_extra(definition, part)

func _new_part_name() -> String:
	var index: int = _data.extra_parts.size() + 1
	while $Parts.has_node("Extra" + str(index)): index += 1
	return "Extra" + str(index)

func _add_png(path: String) -> void:
	var texture := load(path) as Texture2D
	if texture == null: return
	var definition := {"name": _new_part_name(), "texture": texture}
	var part: Node2D = $Parts.add_extra(definition)
	part.global_position = _selected().global_position
	_register_extra(definition, part)

func _register_extra(definition: Dictionary, part: Node2D) -> void:
	_data.extra_parts.append(definition)
	var pose: Dictionary = $Parts.capture_pose()
	var root_path := String($Parts.get_path_to(part))
	var new_paths: Array = []
	for path in pose:
		if path == root_path or path.begins_with(root_path + "/"): new_paths.append(path)
	var all_poses: Array = _data.poses.values()
	for frames: Array in _data.clips.values():
		for frame: Dictionary in frames: all_poses.append(frame.pose)
	for target: Dictionary in all_poses:
		for path in new_paths:
			target[path] = pose[path].duplicate(true)
		target[root_path].visible = false
	_commit_pose()
	_refresh_parts()
	_selector.select(_parts.find(part))
	_sync_fields()

func _save() -> void:
	_stop_play()
	if FileAccess.get_sha256(_source_path) != _source_hash:
		_status.text = tr("centaurus.anim.conflict")
		return
	var problem := ResourceSaver.save(_data, _source_path)
	if problem != OK:
		_status.text = tr("centaurus.parts.failed")
		return
	_source_hash = FileAccess.get_sha256(_source_path)
	_status.text = tr("centaurus.anim.saved")

func _toggle_play() -> void:
	if _playing: _stop_play(); return
	_playing = true
	_play_time = 0.0
	_play.text = tr("centaurus.anim.stop")

func _stop_play() -> void:
	if not _playing: return
	_playing = false
	_play.text = tr("centaurus.anim.play")
	$Parts.apply_pose(_current_pose())
	_update_highlight()

func _process(delta: float) -> void:
	_joint_overlay.queue_redraw()
	if not _playing: return
	_play_time += delta
	var length: float = _data.duration(_clip_key)
	if _play_time >= length and not _loop.button_pressed:
		_stop_play()
		_sync_fields()
		return
	$Parts.apply_pose(_data.sample(_clip_key, fmod(_play_time, maxf(0.02, length))))
	_update_highlight()

func _sprites(parent: Node) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for child in parent.get_children():
		if child is Sprite2D: result.append(child)
		result.append_array(_sprites(child))
	return result

func _update_highlight() -> void:
	var part := _selected()
	var points := PackedVector2Array()
	for sprite in _sprites(part):
		var rect := sprite.get_rect()
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			points.append(to_local(sprite.to_global(corner)))
	_highlight.visible = not points.is_empty() and part.is_visible_in_tree()
	if points.is_empty(): return
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	_highlight.points = PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y), bounds.position])

func _input(event: InputEvent) -> void:
	# キャンバスのSpace操作を、直前に押したボタンの再実行へ渡さない。
	if event is InputEventKey and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		if not _file_dialog.visible and not _over_controls(get_viewport().get_mouse_position()):
			get_viewport().set_input_as_handled()
			return
	if not _pivot_drag.is_empty():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_pivot_drag = ""
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseMotion:
			if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_pivot_drag = ""
				return
			_move_part_pivot(get_canvas_transform().affine_inverse() * event.position)
			get_viewport().set_input_as_handled()
			return
	if not _joint_drag.is_empty():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_joint_drag = ""
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseMotion:
			if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_joint_drag = ""
				return
			var world: Vector2 = $Parts.get_canvas_transform().affine_inverse() * event.position + _joint_grab_offset
			if _rig_mode == 1:
				$Parts.arm_rig.set_point(_rig_side, _joint_drag, world)
			elif not $Parts.arm_rig.move_joint(_rig_side, _joint_drag, world):
				_status.text = tr("centaurus.rig.invalid")
				return
			_commit_pose()
			_sync_fields()
			get_viewport().set_input_as_handled()
			return
	if not _panning: return
	if event is InputEventMouseButton and event.button_index == _pan_button and not event.pressed:
		_panning = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var held := MOUSE_BUTTON_MASK_MIDDLE if _pan_button == MOUSE_BUTTON_MIDDLE else MOUSE_BUTTON_MASK_LEFT
		if not event.button_mask & held:
			_panning = false
			return
		_pan_offset -= event.relative / $Camera2D.zoom
		_fit()
		get_viewport().set_input_as_handled()

func _over_controls(point: Vector2) -> bool:
	return _panel.get_global_rect().has_point(point) or (_timeline.visible and _timeline.get_global_rect().has_point(point))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _over_controls(event.position): return
		if event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_physical_key_pressed(KEY_SPACE)):
			_dragging = false
			_joint_drag = ""
			_pivot_drag = ""
			_panning = true
			_pan_button = event.button_index
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
		_dragging = false
		_joint_drag = ""
		_pivot_drag = ""
		_zoom_field.value = clampf(_zoom + direction * _zoom_field.step, _zoom_field.min_value, _zoom_field.max_value)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = false
		if not event.pressed: return
		_stop_play()
		if _rig_mode == 0 and _begin_part_pivot_drag(event.position):
			get_viewport().set_input_as_handled()
			return
		if _rig_mode > 0:
			_begin_joint_drag(event.position)
			get_viewport().set_input_as_handled()
			return
		var mouse: Vector2 = get_canvas_transform().affine_inverse() * event.position
		for index in range(_parts.size() - 1, -1, -1):
			if not _parts[index].is_visible_in_tree(): continue
			var hit := false
			for sprite in _sprites(_parts[index]):
				if sprite.is_visible_in_tree() and sprite.get_rect().has_point(sprite.to_local(mouse)): hit = true; break
			if not hit: continue
			_selector.select(index)
			_sync_fields()
			if _data.part_pivots.has(String($Parts.get_path_to(_selected()))) and not _pivot_setup.button_pressed:
				_begin_part_rotation(mouse)
				return
			_drag_start = (_selected().get_parent() as Node2D).to_local(mouse)
			_part_start = _selected().position
			_dragging = true
			break
	elif event is InputEventMouseMotion and _dragging:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_dragging = false
			return
		var mouse: Vector2 = get_canvas_transform().affine_inverse() * event.position
		mouse = (_selected().get_parent() as Node2D).to_local(mouse)
		_selected().position = (_part_start + mouse - _drag_start).round()
		_commit_pose()
		_sync_fields()

func _fit() -> void:
	var size := get_viewport_rect().size
	var width := minf(370.0, maxf(260.0, size.x * 0.34))
	_panel.position = Vector2(maxf(8.0, size.x - width - 12), 12)
	_panel.size = Vector2(width, maxf(80.0, size.y - 24))
	_timeline.position = Vector2(12, size.y - 220)
	_timeline.size = Vector2(maxf(240.0, size.x - width - 36), 208)
	var available := Vector2(maxf(100.0, size.x - width - 48), maxf(100.0, size.y - (270.0 if _timeline.visible else 48.0)))
	var factor := maxf(0.25, minf(available.x / 180.0, available.y / 320.0)) * _zoom
	$Camera2D.zoom = Vector2.ONE * factor
	$Camera2D.position = Vector2(width / (2.0 * factor), (110.0 if _timeline.visible else 0.0) / factor - 5) + _pan_offset

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pivot_drag = ""
		_joint_drag = ""
		_panning = false
		_dragging = false
