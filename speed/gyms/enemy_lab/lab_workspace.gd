## 配置・編集を中心に、設定と履歴を必要なときだけ開く作業画面。
extends RefCounted
const UI := preload("res://gyms/enemy_lab/lab_ui.gd")
var lab
var settings: PanelContainer
var tools: Dictionary = {}
var palette_buttons: Dictionary = {}
var category: OptionButton
var stars: OptionButton
var _mode_hint: Label
var _route_actions: HBoxContainer
var _cancel: Button
var _history: VBoxContainer
var _history_button: Button
var _settings_title: Label
var _body: HBoxContainer
var _center: VBoxContainer
var _notice: HBoxContainer
var _budget: ProgressBar
var _route_cost: Label
var _palette_auto_hidden := false
var _last_mode := -1
var _left_split: HSplitContainer
var _right_split: HSplitContainer
var _vertical_split: VSplitContainer
var _right_dock: VBoxContainer
var _left_toggle: Button
var _right_toggle: Button
var _right_collapsed := false
var _restore_settings := true
var _restore_page := 0
var _history_offset := 0
var _zoom_label: Label
var _track_scroll: HScrollBar
var _route_tool: OptionButton
var _pin: Button
var _transport_panel: PanelContainer
var _transport_tab: Button
var _transport_offset := 0

func build(owner: Control) -> void:
	lab = owner
	lab.theme = UI.theme()
	var background := ColorRect.new()
	background.color = Color("#0c1420")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	lab.add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	_header(layout)
	_vertical_split = VSplitContainer.new()
	_vertical_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vertical_split.add_theme_constant_override("separation", 12)
	layout.add_child(_vertical_split)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vertical_split.add_child(_body)
	_left_toggle = _edge_button(_body, _toggle_palette)
	_left_split = HSplitContainer.new()
	_left_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_split.add_theme_constant_override("separation", 12)
	_body.add_child(_left_split)
	_palette(_left_split)
	_right_split = HSplitContainer.new()
	_right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_split.add_theme_constant_override("separation", 12)
	_left_split.add_child(_right_split)
	_center = VBoxContainer.new()
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_split.add_child(_center)
	_toolbar(_center)
	# 本番のランをそのまま映す表示枠と、その上に重ねる編集用の層
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(300, 240)
	stage.clip_contents = true
	_center.add_child(stage)
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frame_material := ShaderMaterial.new()
	frame_material.shader = preload("res://shaders/lab_viewport.gdshader")
	frame.material = frame_material
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.focus_mode = Control.FOCUS_ALL
	stage.add_child(frame)
	var viewport := SubViewport.new()
	viewport.handle_input_locally = false
	viewport.audio_listener_enable_2d = true
	frame.add_child(viewport)
	lab.session.viewport = viewport
	lab.game_frame = frame
	lab.canvas = lab.CANVAS.new()
	lab.canvas.session = lab.session
	lab.canvas.field_lookup = lab.field_item
	lab.canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(lab.canvas)
	_hint_row(_center)
	_right_dock = VBoxContainer.new()
	_right_split.add_child(_right_dock)
	_inspector(_right_dock)
	_settings(_right_dock)
	_right_dock.hide()
	_right_toggle = _edge_button(_body, _toggle_right)
	lab.resized.connect(_fit_panels)
	lab._right.visibility_changed.connect(_fit_panels)
	settings.visibility_changed.connect(_fit_panels)
	_transport(_vertical_split)
	for splitter in [_left_split, _right_split, _vertical_split]:
		splitter.add_theme_constant_override("autohide", 0)
		splitter.add_theme_constant_override("minimum_grab_thickness", 12)
		var line := StyleBoxLine.new()
		line.color = Color("#30435b")
		line.thickness = 1
		line.vertical = not splitter.vertical
		splitter.add_theme_stylebox_override("split_bar_background", line)
		splitter.get_drag_area_controls()[0].tooltip_text = tr("lab.ui.resize_panel")
	_vertical_split.dragged.connect(func(_offset):
		if not _history.visible: _history.show()
		_history_offset = _offset)
	_notice = HBoxContainer.new()
	layout.add_child(_notice)
	lab._messages = lab._label(_notice, "")
	lab._messages.add_theme_color_override("font_color", UI.MUTED)
	lab._messages.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lab._messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab._messages.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.button(_notice, tr("lab.ui.close"), func(): lab._messages.text = "", "close", true)
	lab.canvas.picked.connect(func(_row):
		lab.inspector.refresh(true)
		if lab.session.selected >= 0:
			_restore_settings = false
			settings.hide()
			if not _right_collapsed: lab._right.show())
	lab.canvas.route_edited.connect(func():
		lab.trial.cancel()
		lab._result.text = ""
		lab._result.hide())

func _header(parent: Node) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)
	UI.button(header, tr("common.back"), lab._leave, "back", true)
	var title: Label = lab._label(header, tr("lab.message_922c39d8ac"))
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI.button(header, tr("lab.ui.conditions"), open_settings.bind(0), "settings")
	UI.button(header, tr("lab.ui.random"), open_settings.bind(3), "dice")
	UI.button(header, tr("lab.ui.files"), open_settings.bind(4), "save")
	UI.button(header, tr("lab.appearance.title"), open_settings.bind(5), "eye")
	UI.button(header, tr("lab.ui.help"), func(): lab._messages.text = tr("lab.ui.help_text"), "help", true)

func _edge_button(parent: Node, action: Callable) -> Button:
	var button := UI.button(parent, "", action, "chevron_left", true)
	button.custom_minimum_size = Vector2(24, 48)
	button.add_theme_constant_override("icon_max_width", 16)
	button.add_theme_stylebox_override("normal", UI.style(Color("#152131"), Color.TRANSPARENT, 3))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button

func _palette(parent: Node) -> void:
	lab._left = PanelContainer.new()
	lab._left.custom_minimum_size.x = 196
	lab._left.size_flags_horizontal = Control.SIZE_FILL
	parent.add_child(lab._left)
	var box := VBoxContainer.new()
	lab._left.add_child(box)
	var title: Label = lab._label(box, tr("lab.ui.enemies"))
	title.add_theme_font_size_override("font_size", 16)
	lab._filter = LineEdit.new()
	lab._filter.placeholder_text = tr("lab.ui.search")
	lab._filter.right_icon = UI.icon("search")
	lab._filter.text_changed.connect(func(_v): lab._fill_palette())
	box.add_child(lab._filter)
	# 区分（星の数で決まる）と星の数で絞り込む
	var filters := HBoxContainer.new()
	box.add_child(filters)
	category = OptionButton.new()
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in ["lab.ui.all", "lab.ui.class_fodder", "lab.ui.class_tough", "lab.ui.class_strong", "lab.ui.class_big", "lab.ui.class_field", "lab.ui.class_boss", "lab.ui.class_other"]:
		category.add_item(tr(key))
	category.item_selected.connect(func(_i): lab._fill_palette())
	filters.add_child(category)
	stars = OptionButton.new()
	stars.add_item(tr("lab.ui.stars_all"))
	for n in range(1, 6): stars.add_item("★%d" % n)
	stars.add_item("★6〜10")
	stars.tooltip_text = tr("lab.ui.stars_help")
	stars.item_selected.connect(func(_i): lab._fill_palette())
	filters.add_child(stars)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	lab._palette = GridContainer.new()
	lab._palette.columns = 2
	lab._palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab._palette.add_theme_constant_override("h_separation", 4)
	lab._palette.add_theme_constant_override("v_separation", 4)
	scroll.add_child(lab._palette)
	var hint: Label = lab._label(box, tr("lab.ui.drag_hint"))
	hint.add_theme_color_override("font_color", UI.MUTED)
	hint.add_theme_font_size_override("font_size", 12)
	var row := HBoxContainer.new()
	box.add_child(row)
	lab._label(row, tr("lab.message_da1f520c6f"))
	lab._count = lab._spin(row, 1, 10000, 1)
	lab._count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab._count.value_changed.connect(func(v): lab.canvas.spawn_count = int(v))

func _toolbar(parent: Node) -> void:
	var bar := HFlowContainer.new()
	parent.add_child(bar)
	for item in [[0, "lab.ui.select", "pointer"], [2, "lab.ui.route", "pencil"], [3, "lab.ui.try", ""], [5, "lab.ui.range", "ruler"]]:
		var button := UI.button(bar, tr(item[1]), lab._set_mode.bind(item[0]), item[2])
		button.toggle_mode = true
		tools[item[0]] = button
	_route_tool = OptionButton.new()
	_route_tool.add_item(tr("lab.ui.freehand"))
	_route_tool.add_item(tr("lab.ui.edit_points"))
	_route_tool.tooltip_text = tr("lab.ui.route_tool_help")
	_route_tool.item_selected.connect(func(index):
		lab.canvas.finish_route()
		lab.canvas.cancel_gesture()
		lab.canvas.route_tool = index
		lab.canvas.grab_focus())
	bar.add_child(_route_tool)
	UI.button(bar, tr("lab.undo"), func():
		if lab.canvas.mode == 2: lab.canvas.undo_route()
		else: await lab.session.undo_edit(), "undo", true)
	UI.button(bar, tr("lab.redo"), func():
		if lab.canvas.mode == 2: lab.canvas.undo_route(true)
		else: await lab.session.redo_edit(), "redo", true)
	var view := MenuButton.new()
	view.icon = UI.icon("eye")
	view.tooltip_text = tr("lab.ui.view")
	view.custom_minimum_size = Vector2(36, 36)
	bar.add_child(view)
	view.get_popup().add_check_item(tr("lab.message_fb93512f75"), 0)
	view.get_popup().set_item_checked(0, true)
	view.get_popup().add_check_item(tr("lab.names"), 1)
	view.get_popup().add_separator()
	view.get_popup().add_check_item(tr("lab.ui.show_hud"), 2)
	view.get_popup().add_check_item(tr("lab.ui.show_minimap"), 3)
	view.get_popup().add_check_item(tr("lab.ui.show_background"), 4)
	view.get_popup().id_pressed.connect(func(id):
		var index := view.get_popup().get_item_index(id)
		var on := not view.get_popup().is_item_checked(index)
		view.get_popup().set_item_checked(index, on)
		var key: String = ["show_ranges", "show_ids", "show_hud", "show_minimap", "show_background"][id]
		lab.canvas.set(key, on))
	UI.button(bar, tr("lab.ui.center"), func(): lab.canvas.center = lab.session.run.state.ship_pos; lab.canvas.zoom = lab.game_zoom(), "focus", true)
	var more := MenuButton.new()
	more.icon = UI.icon("more")
	more.tooltip_text = tr("lab.ui.edit_more")
	more.custom_minimum_size = Vector2(36, 36)
	bar.add_child(more)
	more.get_popup().add_icon_item(UI.icon("trash"), tr("lab.message_685d3cd5a7"), 0)
	more.get_popup().add_icon_item(UI.icon("trash"), tr("lab.message_97c3c6246b"), 1)
	more.get_popup().id_pressed.connect(func(id):
		if id == 0: lab.canvas.clear_route()
		else: lab.session.perform("clear"))

func _hint_row(parent: Node) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_mode_hint = lab._label(row, "")
	_mode_hint.add_theme_color_override("font_color", UI.MUTED)
	_mode_hint.add_theme_font_size_override("font_size", 12)
	_mode_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_route_actions = HBoxContainer.new()
	row.add_child(_route_actions)
	_budget = ProgressBar.new()
	_budget.custom_minimum_size = Vector2(72, 8)
	_budget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_budget.show_percentage = false
	_budget.add_theme_stylebox_override("background", UI.style(Color("#29394c"), Color.TRANSPARENT, 0))
	_budget.add_theme_stylebox_override("fill", UI.style(UI.ACCENT, Color.TRANSPARENT, 0))
	_route_actions.add_child(_budget)
	_route_cost = lab._label(_route_actions, "")
	UI.button(_route_actions, tr("lab.ui.clear_route"), func():
		lab.canvas.clear_route()
		lab.canvas.grab_focus(), "trash")
	UI.button(_route_actions, tr("lab.ui.evaluate"), lab._try_route, "play")
	lab._result = lab._label(parent, "")
	lab._result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab._result.hide()

func _inspector(parent: Node) -> void:
	lab._right = PanelContainer.new()
	lab._right.custom_minimum_size.x = 292
	lab._right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(lab._right)
	var box := VBoxContainer.new()
	lab._right.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title: Label = lab._label(header, tr("lab.ui.tune"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(header, tr("lab.ui.collapse_right"), _toggle_right, "chevron_right", true)
	lab.inspector = lab.INSPECTOR.new()
	lab.inspector.session = lab.session
	lab.inspector.canvas = lab.canvas
	lab.inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(lab.inspector)
	lab._right.hide()

func _settings(parent: Node) -> void:
	settings = PanelContainer.new()
	settings.custom_minimum_size.x = 392
	settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(settings)
	var box := VBoxContainer.new()
	settings.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_settings_title = lab._label(header, tr("lab.message_69a0de30fa"))
	_settings_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(header, tr("lab.ui.collapse_right"), _toggle_right, "chevron_right", true)
	lab.controls = lab.CONTROLS.new()
	lab.controls.lab = lab
	lab.controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(lab.controls)
	settings.hide()

func environment(parent: Node) -> void:
	var box := UI.fold(parent, tr("lab.ui.field"), true)
	lab._stage = OptionButton.new()
	for n in range(1, ContentManager.stage_count() + 1): lab._stage.add_item(tr("lab.message_c83172920b") % n, n)
	box.add_child(lab._stage)
	var seed_row := HBoxContainer.new()
	box.add_child(seed_row)
	lab._label(seed_row, "Seed")
	lab._seed = lab._spin(seed_row, 0, 2147483647, 932)
	lab._seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab._empty = _check(box, "lab.message_528e1c7048", true)
	lab._auto = _check(box, "lab.message_bb051fda3b")
	var field_options := UI.fold(box, tr("lab.ui.field_objects"))
	lab._terrain = _check(field_options, "lab.terrain")
	lab._rocks = _check(field_options, "lab.rocks")
	lab._gimmicks = _check(field_options, "lab.gimmicks")
	lab._empty.toggled.connect(func(on): lab._terrain.button_pressed = not on; lab._rocks.button_pressed = not on; lab._gimmicks.button_pressed = not on)
	UI.button(box, tr("lab.message_dfa32d64eb"), func(): await lab._reset(); close_settings(), "plus")
	var advanced := UI.fold(box, tr("lab.ui.data"))
	UI.button(advanced, tr("lab.reload_data"), lab._reload_data)

func _check(parent: Node, key: String, on := false) -> CheckButton:
	var check := CheckButton.new()
	check.text = tr(key)
	check.button_pressed = on
	parent.add_child(check)
	return check

func _transport(parent: Node) -> void:
	var panel := PanelContainer.new()
	_transport_panel = panel
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var bar := HBoxContainer.new()
	box.add_child(bar)
	UI.button(bar, tr("lab.ui.reset"), func():
		lab.canvas.cancel_gesture()
		await lab.session.back_to_play_start()
		lab._refresh(), "reset").tooltip_text = tr("lab.ui.reset_help")
	UI.button(bar, tr("lab.message_e2ff3a1576"), func(): await lab.session.seek(0); lab._refresh(), "start", true)
	lab._play = UI.button(bar, tr("lab.ui.play"), lab._toggle_play, "play")
	_pin = UI.button(bar, tr("lab.ui.pin_ship"), func():
		var on: bool = lab.session.pinned == null
		var at: Vector2 = lab.session.run.state.ship_pos
		lab.session.perform("pin", {"value": on, "pos": [at.x, at.y]})
		lab._refresh(), "lock")
	_pin.toggle_mode = true
	_pin.tooltip_text = tr("lab.ui.pin_ship_help")
	UI.button(bar, tr("lab.message_87b386148b"), func(): lab.session.playing = false; lab.session.step(); lab._refresh(), "step", true)
	var speeds := OptionButton.new()
	for value in [0.25, 0.5, 1.0, 2.0, 4.0]: speeds.add_item("×%s" % value)
	speeds.selected = 2
	speeds.item_selected.connect(func(i): lab.session.speed = [0.25, 0.5, 1.0, 2.0, 4.0][i])
	bar.add_child(speeds)
	lab._status = lab._label(bar, "")
	lab._status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab._status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_cancel = UI.button(bar, tr("lab.message_67847e89ae"), func(): lab.trial.cancel(); lab.generator.cancelled = true; lab.session.cancel_seek(), "close")
	_history_button = UI.button(bar, tr("lab.ui.history"), func(): _set_history(not _history.visible), "clock")
	_history_button.toggle_mode = true
	UI.button(bar, tr("lab.ui.collapse_bottom"), _toggle_transport, "chevron", true)
	_transport_tab = UI.button(lab, tr("lab.ui.expand_bottom"), _toggle_transport, "chevron_up", true)
	_transport_tab.custom_minimum_size = Vector2(48, 24)
	_transport_tab.add_theme_constant_override("icon_max_width", 16)
	_transport_tab.add_theme_stylebox_override("normal", UI.style(UI.SURFACE, Color("#30435b"), 3))
	_transport_tab.anchor_left = 0.5
	_transport_tab.anchor_right = 0.5
	_transport_tab.anchor_top = 1
	_transport_tab.anchor_bottom = 1
	_transport_tab.offset_left = -24
	_transport_tab.offset_right = 24
	_transport_tab.offset_top = -24
	_transport_tab.offset_bottom = 0
	_transport_tab.hide()
	lab._seek = HSlider.new()
	lab._seek.min_value = 0
	lab._seek.max_value = 1
	lab._seek.step = 1
	lab._seek.custom_minimum_size.y = 20
	box.add_child(lab._seek)
	lab._seek.drag_started.connect(func(): lab.session.playing = false; lab._scrubbing = true)
	lab._seek.drag_ended.connect(func(_change): lab._scrubbing = false; await lab.session.seek(roundi(lab._seek.value)); lab._refresh())
	_history = VBoxContainer.new()
	_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_history)
	lab._timeline = lab.TIMELINE.new()
	lab._timeline.session = lab.session
	lab._timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history.add_child(lab._timeline)
	lab._timeline.seek_requested.connect(func(t): await lab.session.seek(t); lab._refresh())
	_track_scroll = HScrollBar.new()
	_track_scroll.step = 1
	_track_scroll.value_changed.connect(func(value): lab._timeline.view_start = value; lab._timeline.queue_redraw())
	_history.add_child(_track_scroll)
	var track_tools := HBoxContainer.new()
	_history.add_child(track_tools)
	lab._branch = OptionButton.new()
	lab._branch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_tools.add_child(lab._branch)
	lab._branch.item_selected.connect(lab._select_branch)
	UI.button(track_tools, tr("lab.ui.zoom_out"), func(): lab._timeline.zoom_at(1.0 / 1.5), "minus", true)
	_zoom_label = lab._label(track_tools, "")
	UI.button(track_tools, tr("lab.ui.zoom_in"), func(): lab._timeline.zoom_at(1.5), "plus", true)
	UI.button(track_tools, tr("lab.ui.show_all"), func(): lab._timeline.reset_view(), "focus", true)
	_history.hide()

func _toggle_transport() -> void:
	lab.canvas.finish_route()
	if _transport_panel.visible:
		_transport_offset = _vertical_split.split_offsets[0]
		_transport_panel.hide()
		_transport_tab.show()
	else:
		_transport_panel.show()
		_transport_tab.hide()
		_vertical_split.split_offsets = PackedInt32Array([_transport_offset])
	lab.canvas.grab_focus()

func _set_history(open: bool) -> void:
	if _history.visible and not open: _history_offset = _vertical_split.split_offsets[0]
	_history.visible = open
	_vertical_split.split_offsets = PackedInt32Array([_history_offset if open else 0])

func open_settings(page: int) -> void:
	lab.session.playing = false
	_right_collapsed = false
	_restore_settings = true
	_restore_page = page
	lab._right.hide()
	settings.show()
	lab.controls.current_tab = page

func close_settings() -> void:
	settings.hide()
	lab._right.visible = lab.session.selected >= 0
	lab.canvas.grab_focus()

func _fit_panels() -> void:
	if not is_instance_valid(settings): return
	_right_dock.visible = settings.visible or lab._right.visible
	var narrow: bool = lab.size.x < 1000 and (settings.visible or lab._right.visible)
	if narrow and lab._left.visible:
		_palette_auto_hidden = true
		lab._left.hide()
	elif not narrow and _palette_auto_hidden:
		_palette_auto_hidden = false
		lab._left.show()

func _toggle_palette() -> void:
	var show: bool = not lab._left.visible
	_palette_auto_hidden = false
	if show and lab.size.x < 1000:
		settings.hide()
		lab._right.hide()
	lab._left.visible = show

func _toggle_right() -> void:
	if _right_dock.visible:
		_right_collapsed = true
		_restore_settings = settings.visible
		_restore_page = lab.controls.current_tab
		settings.hide()
		lab._right.hide()
	else:
		_right_collapsed = false
		if _restore_settings: open_settings(_restore_page)
		elif lab.session.selected >= 0: lab._right.show()
		else: open_settings(0)

func sync() -> void:
	_pin.set_pressed_no_signal(lab.session.pinned != null)
	lab._play.icon = UI.icon("pause" if lab.session.playing else "play")
	lab._play.text = tr("lab.ui.pause" if lab.session.playing else "lab.ui.play")
	lab._play.tooltip_text = lab._play.text + " · Space"
	_cancel.visible = lab._busy or lab.session.seeking
	_history_button.set_pressed_no_signal(_history.visible)
	_left_toggle.icon = UI.icon("chevron_left" if lab._left.visible else "chevron_right")
	_left_toggle.tooltip_text = tr("lab.ui.collapse_left" if lab._left.visible else "lab.ui.expand_left")
	_right_toggle.icon = UI.icon("chevron_right" if _right_dock.visible else "chevron_left")
	_right_toggle.tooltip_text = tr("lab.ui.collapse_right" if _right_dock.visible else "lab.ui.expand_right")
	lab._timeline.sync_view(lab.session.playing)
	_zoom_label.text = "×%.1f" % lab._timeline.zoom
	var span: float = lab._timeline.visible_span()
	_track_scroll.max_value = maxf(1, lab.session.furthest)
	_track_scroll.page = span
	_track_scroll.set_value_no_signal(lab._timeline.view_start)
	_track_scroll.visible = lab._timeline.zoom > 1
	if _last_mode != lab.canvas.mode:
		_last_mode = lab.canvas.mode
		for mode in tools: tools[mode].set_pressed_no_signal(mode == _last_mode)
		var hints := {0: "lab.ui.select_hint", 1: "lab.ui.place_hint", 2: "lab.ui.route_hint", 3: "lab.ui.try_hint", 4: "lab.message_277d733b3c", 5: "lab.ui.range_hint"}
		_mode_hint.text = tr(hints.get(_last_mode, "lab.ui.select_hint"))
		_mode_hint.tooltip_text = _mode_hint.text
		for id in palette_buttons: palette_buttons[id].set_pressed_no_signal(id == lab.canvas.spawn_type and _last_mode == 1)
	_route_tool.visible = lab.canvas.mode == 2
	if lab.canvas.mode == 2:
		_mode_hint.text = tr("lab.ui.drawing_route" if lab.canvas._freehand else ("lab.ui.freehand_hint" if lab.canvas.route_tool == 0 else "lab.ui.route_hint"))
		_mode_hint.tooltip_text = _mode_hint.text
	_route_actions.visible = lab.canvas.route.size() >= 2
	var length: float = lab.CHECK.length(lab.canvas.route)
	var limit: float = lab.session.run.draw.budget(lab.session.run.state.stats.capacity * lab.session.run.state.gauge)
	var cost := 100 * length / maxf(0.01, limit)
	_budget.value = cost
	_budget.modulate = Color("#ff9c83") if cost > 100 else Color.WHITE
	_budget.tooltip_text = tr("lab.route_length") % [length, limit, cost]
	_route_cost.text = "%.0f%%" % cost
	_route_cost.tooltip_text = _budget.tooltip_text
	if lab.session.selected < 0: lab._right.hide()
	_notice.visible = not lab._messages.text.is_empty()
	lab._messages.tooltip_text = lab._messages.text
