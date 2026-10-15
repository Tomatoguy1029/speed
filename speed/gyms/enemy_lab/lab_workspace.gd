## 配置・編集を中心に、設定と履歴を必要なときだけ開く作業画面。
extends RefCounted
const UI := preload("res://gyms/enemy_lab/lab_ui.gd")
var lab
var settings: PanelContainer
var tools: Dictionary = {}
var palette_buttons: Dictionary = {}
var category: OptionButton
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
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_body)
	_palette(_body)
	_center = VBoxContainer.new()
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_center)
	_toolbar(_center)
	lab.canvas = lab.CANVAS.new()
	lab.canvas.session = lab.session
	lab.canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.add_child(lab.canvas)
	_hint_row(_center)
	_inspector(_body)
	_settings(_body)
	lab.resized.connect(_fit_panels)
	lab._right.visibility_changed.connect(_fit_panels)
	settings.visibility_changed.connect(_fit_panels)
	_transport(layout)
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
		if lab.session.selected >= 0: settings.hide(); lab._right.show())
	lab.canvas.route_edited.connect(func():
		lab.trial.cancel()
		lab._result.text = ""
		lab._result.hide())

func _header(parent: Node) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)
	UI.button(header, tr("common.back"), lab._leave, "back", true)
	UI.button(header, tr("lab.message_c811c512d0"), _toggle_palette, "grid", true)
	var title: Label = lab._label(header, tr("lab.message_922c39d8ac"))
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI.button(header, tr("lab.ui.conditions"), open_settings.bind(0), "settings")
	UI.button(header, tr("lab.ui.random"), open_settings.bind(3), "dice")
	UI.button(header, tr("lab.ui.files"), open_settings.bind(4), "save")
	UI.button(header, tr("lab.ui.help"), func(): lab._messages.text = tr("lab.ui.help_text"), "help", true)

func _palette(parent: Node) -> void:
	lab._left = PanelContainer.new()
	lab._left.custom_minimum_size.x = 196
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
	category = OptionButton.new()
	for key in ["lab.ui.all", "lab.message_bd3455e23b", "lab.message_0033dbf5f7", "lab.message_cab5ef8006"]: category.add_item(tr(key))
	category.item_selected.connect(func(_i): lab._fill_palette())
	box.add_child(category)
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
	var level_box := UI.fold(box, tr("lab.ui.placement_options"))
	var levels := HBoxContainer.new()
	level_box.add_child(levels)
	lab._label(levels, "Lv")
	lab._level = lab._spin(levels, 1, 100, 1)
	lab._level.value_changed.connect(func(v): lab.canvas.spawn_level = v)

func _toolbar(parent: Node) -> void:
	var bar := HFlowContainer.new()
	parent.add_child(bar)
	for item in [[0, "lab.ui.select", "pointer"], [2, "lab.ui.route", "pencil"], [3, "lab.ui.try", ""], [5, "lab.ui.range", "ruler"]]:
		var button := UI.button(bar, tr(item[1]), lab._set_mode.bind(item[0]), item[2])
		button.toggle_mode = true
		tools[item[0]] = button
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
	view.get_popup().id_pressed.connect(func(id):
		var on := not view.get_popup().is_item_checked(id)
		view.get_popup().set_item_checked(id, on)
		if id == 0: lab.canvas.show_ranges = on
		else: lab.canvas.show_ids = on)
	UI.button(bar, tr("lab.ui.center"), func(): lab.canvas.center = lab.session.run.state.ship_pos; lab.canvas.zoom = 0.6, "focus", true)
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
	UI.button(_route_actions, tr("lab.ui.evaluate"), lab._evaluate, "play")
	lab._result = lab._label(parent, "")
	lab._result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab._result.hide()

func _inspector(parent: Node) -> void:
	lab._right = PanelContainer.new()
	lab._right.custom_minimum_size.x = 292
	parent.add_child(lab._right)
	var box := VBoxContainer.new()
	lab._right.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title: Label = lab._label(header, tr("lab.ui.tune"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(header, tr("lab.ui.close"), func(): lab._right.hide(), "close", true)
	lab.inspector = lab.INSPECTOR.new()
	lab.inspector.session = lab.session
	lab.inspector.canvas = lab.canvas
	lab.inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(lab.inspector)
	lab._right.hide()

func _settings(parent: Node) -> void:
	settings = PanelContainer.new()
	settings.custom_minimum_size.x = 392
	parent.add_child(settings)
	var box := VBoxContainer.new()
	settings.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_settings_title = lab._label(header, tr("lab.message_69a0de30fa"))
	_settings_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(header, tr("lab.ui.close"), close_settings, "close", true)
	lab.controls = lab.CONTROLS.new()
	lab.controls.lab = lab
	lab.controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(lab.controls)
	settings.hide()

func environment(parent: Node) -> void:
	var box := UI.fold(parent, tr("lab.ui.field"), true)
	lab._stage = OptionButton.new()
	for n in range(1, ConfigManager.stage_count() + 1): lab._stage.add_item(tr("lab.message_c83172920b") % n, n)
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
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var bar := HBoxContainer.new()
	box.add_child(bar)
	UI.button(bar, tr("lab.message_e2ff3a1576"), func(): await lab.session.seek(0); lab._refresh(), "start", true)
	lab._play = UI.button(bar, tr("lab.ui.play"), lab._toggle_play, "play")
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
	_history_button = UI.button(bar, tr("lab.ui.history"), func(): _history.visible = not _history.visible, "clock")
	_history_button.toggle_mode = true
	lab._seek = HSlider.new()
	lab._seek.min_value = 0
	lab._seek.max_value = 1
	lab._seek.step = 1
	lab._seek.custom_minimum_size.y = 20
	box.add_child(lab._seek)
	lab._seek.drag_started.connect(func(): lab.session.playing = false; lab._scrubbing = true)
	lab._seek.drag_ended.connect(func(_change): lab._scrubbing = false; await lab.session.seek(roundi(lab._seek.value)); lab._refresh())
	_history = VBoxContainer.new()
	box.add_child(_history)
	lab._timeline = lab.TIMELINE.new()
	lab._timeline.session = lab.session
	_history.add_child(lab._timeline)
	lab._timeline.seek_requested.connect(func(t): await lab.session.seek(t); lab._refresh())
	lab._branch = OptionButton.new()
	_history.add_child(lab._branch)
	lab._branch.item_selected.connect(lab._select_branch)
	_history.hide()

func open_settings(page: int) -> void:
	lab.session.playing = false
	lab._right.hide()
	settings.show()
	lab.controls.current_tab = page

func close_settings() -> void:
	settings.hide()
	lab._right.visible = lab.session.selected >= 0
	lab.canvas.grab_focus()

func _fit_panels() -> void:
	if not is_instance_valid(settings): return
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

func sync() -> void:
	lab._play.icon = UI.icon("pause" if lab.session.playing else "play")
	lab._play.text = tr("lab.ui.pause" if lab.session.playing else "lab.ui.play")
	lab._play.tooltip_text = lab._play.text + " · Space"
	_cancel.visible = lab._busy or lab.session.seeking
	_history_button.set_pressed_no_signal(_history.visible)
	if _last_mode != lab.canvas.mode:
		_last_mode = lab.canvas.mode
		for mode in tools: tools[mode].set_pressed_no_signal(mode == _last_mode)
		var hints := {0: "lab.ui.select_hint", 1: "lab.ui.place_hint", 2: "lab.ui.route_hint", 3: "lab.ui.try_hint", 4: "lab.message_277d733b3c", 5: "lab.ui.range_hint"}
		_mode_hint.text = tr(hints.get(_last_mode, "lab.ui.select_hint"))
		_mode_hint.tooltip_text = _mode_hint.text
		for id in palette_buttons: palette_buttons[id].set_pressed_no_signal(id == lab.canvas.spawn_type and _last_mode == 1)
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
