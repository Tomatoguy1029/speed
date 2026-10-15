## デバッグ専用の敵・ルート実験場。
extends Control

const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
const CANVAS := preload("res://gyms/enemy_lab/lab_canvas.gd")
const CARD := preload("res://gyms/enemy_lab/lab_candidate_card.gd")
const IO := preload("res://gyms/enemy_lab/lab_io.gd")
const CHECK := preload("res://scripts/encounters/route_constraints.gd")
const CONTROLS := preload("res://gyms/enemy_lab/lab_controls.gd")
const ICON := preload("res://gyms/enemy_lab/lab_icon.gd")
const TIMELINE := preload("res://gyms/enemy_lab/lab_timeline.gd")
const TRIAL := preload("res://gyms/enemy_lab/route_trial.gd")
const GENERATOR := preload("res://gyms/enemy_lab/encounter_pattern.gd")
const INSPECTOR := preload("res://gyms/enemy_lab/lab_inspector.gd")

var session
var controls
var trial
var generator
var comparisons: Array = []
var pattern: Dictionary = {}
var candidate_values: Array = []
var _timeline
var _evaluation_revision := -1
var _file_dialog: FileDialog
var canvas
var inspector
var _palette: VBoxContainer
var _filter: LineEdit
var _status: Label
var _result: Label
var _seek: HSlider
var _play: Button
var _seed: SpinBox
var _stage: OptionButton
var _empty: CheckButton
var _auto: CheckButton
var _terrain: CheckButton
var _rocks: CheckButton
var _gimmicks: CheckButton
var _count: SpinBox
var _level: SpinBox
var _updating := false
var _scrubbing := false
var _busy := false
var _branch: OptionButton
var _left: Control
var _right: Control
var _messages: Label

func _ready() -> void:
	if not OS.is_debug_build():
		GameManager.reset_to_main_menu()
		return
	theme = Theme.new()
	theme.default_font_size = 15
	session = SESSION.new()
	add_child(session)
	trial = TRIAL.new()
	add_child(trial)
	generator = GENERATOR.new()
	add_child(generator)
	_build_ui()
	trial.progress.connect(func(v): _messages.text = TranslationServer.translate("lab.message_7b47f8fa60") % roundi(v * 100))
	generator.progress.connect(func(n): _messages.text = TranslationServer.translate("lab.message_0db4675b27") % n)
	session.changed.connect(_refresh)
	session.seek_progress.connect(func(v): _messages.text = TranslationServer.translate("lab.message_7591fff9f2") % roundi(v * 100))
	await session.reset()
	_refresh()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _spin(parent: Node, minimum: float, maximum: float, value: float) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = minimum
	box.max_value = maximum
	box.value = value
	parent.add_child(box)
	return box

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#101825")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var top := HFlowContainer.new()
	layout.add_child(top)
	_button(top, TranslationServer.translate("lab.message_60a1005be6"), _leave)
	_label(top, TranslationServer.translate("lab.message_922c39d8ac"))
	_label(top, "Seed")
	_seed = _spin(top, 0, 2147483647, 932)
	_stage = OptionButton.new()
	for n in range(1, ConfigManager.stage_count() + 1):
		_stage.add_item(TranslationServer.translate("lab.message_c83172920b") % n, n)
	top.add_child(_stage)
	_empty = CheckButton.new()
	_empty.text = TranslationServer.translate("lab.message_528e1c7048")
	_empty.button_pressed = true
	top.add_child(_empty)
	_auto = CheckButton.new()
	_auto.text = TranslationServer.translate("lab.message_bb051fda3b")
	top.add_child(_auto)
	_terrain = CheckButton.new()
	_terrain.text = tr("lab.terrain")
	top.add_child(_terrain)
	_rocks = CheckButton.new()
	_rocks.text = tr("lab.rocks")
	top.add_child(_rocks)
	_gimmicks = CheckButton.new()
	_gimmicks.text = tr("lab.gimmicks")
	top.add_child(_gimmicks)
	_empty.toggled.connect(func(on): _terrain.button_pressed = not on; _rocks.button_pressed = not on; _gimmicks.button_pressed = not on)
	_button(top, TranslationServer.translate("lab.message_dfa32d64eb"), _reset)
	_button(top, tr("lab.reload_data"), _reload_data)
	var toolbar := HFlowContainer.new()
	layout.add_child(toolbar)
	_play = _button(toolbar, TranslationServer.translate("lab.message_bf1c2f34ef"), _toggle_play)
	_button(toolbar, TranslationServer.translate("lab.message_2555a92b57"), func(): session.playing = false)
	_button(toolbar, TranslationServer.translate("lab.message_87b386148b"), func(): session.playing = false; session.step(); _refresh())
	_button(toolbar, TranslationServer.translate("lab.message_e2ff3a1576"), func(): await session.seek(0); _refresh())
	var speeds := OptionButton.new()
	for value in [0.25, 0.5, 1.0, 2.0, 4.0]:
		speeds.add_item("×%s" % value)
	speeds.selected = 2
	speeds.item_selected.connect(func(i): session.speed = [0.25, 0.5, 1.0, 2.0, 4.0][i])
	toolbar.add_child(speeds)
	_button(toolbar, tr("lab.undo"), func():
		if canvas.mode == 2: canvas.undo_route()
		else: await session.undo_edit())
	_button(toolbar, tr("lab.redo"), func():
		if canvas.mode == 2: canvas.undo_route(true)
		else: await session.redo_edit())
	for item in [[TranslationServer.translate("lab.message_8e4350198b"), 0], [TranslationServer.translate("lab.message_7b82dc2a06"), 1], [TranslationServer.translate("lab.message_096f45921a"), 2], [TranslationServer.translate("lab.message_605c5bd311"), 3], [tr("lab.range_edit"), 5]]:
		_button(toolbar, item[0], _set_mode.bind(item[1]))
	_button(toolbar, TranslationServer.translate("lab.message_685d3cd5a7"), func(): canvas.clear_route())
	_button(toolbar, TranslationServer.translate("lab.message_31c4ccdbbf"), _evaluate)
	_button(toolbar, TranslationServer.translate("lab.message_67847e89ae"), func(): trial.cancel(); generator.cancelled = true; session.cancel_seek())
	_button(toolbar, TranslationServer.translate("lab.message_97c3c6246b"), func(): session.perform("clear"))
	var ranges := CheckButton.new()
	ranges.text = TranslationServer.translate("lab.message_fb93512f75")
	ranges.button_pressed = true
	ranges.toggled.connect(func(on): canvas.show_ranges = on)
	toolbar.add_child(ranges)
	var names := CheckButton.new()
	names.text = tr("lab.names")
	names.button_pressed = true
	names.toggled.connect(func(on): canvas.show_ids = on)
	toolbar.add_child(names)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(middle)
	_left = VBoxContainer.new()
	_left.custom_minimum_size.x = 210
	middle.add_child(_left)
	_filter = LineEdit.new()
	_filter.placeholder_text = TranslationServer.translate("lab.message_19e1e846a4")
	_filter.text_changed.connect(func(_v): _fill_palette())
	_left.add_child(_filter)
	var row := HBoxContainer.new()
	_left.add_child(row)
	_label(row, TranslationServer.translate("lab.message_da1f520c6f"))
	_count = _spin(row, 1, 10000, 1)
	_label(row, "Lv")
	_level = _spin(row, 1, 100, 1)
	_count.value_changed.connect(func(v): canvas.spawn_count = int(v))
	_level.value_changed.connect(func(v): canvas.spawn_level = v)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(scroll)
	_palette = VBoxContainer.new()
	_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_palette)
	canvas = CANVAS.new()
	canvas.session = session
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(canvas)
	_right = TabContainer.new()
	_right.custom_minimum_size.x = 330
	middle.add_child(_right)
	inspector = INSPECTOR.new()
	inspector.session = session
	inspector.canvas = canvas
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector.name = TranslationServer.translate("lab.message_4db93d1888")
	_right.add_child(inspector)
	controls = CONTROLS.new()
	controls.lab = self
	controls.name = TranslationServer.translate("lab.message_69a0de30fa")
	_right.add_child(controls)
	canvas.picked.connect(func(_i): inspector.refresh(true))
	canvas.route_edited.connect(func(): trial.cancel(); _result.text = TranslationServer.translate("lab.message_e2160dc29a"))
	var bottom := HBoxContainer.new()
	layout.add_child(bottom)
	_button(bottom, TranslationServer.translate("lab.message_c811c512d0"), func(): _left.visible = not _left.visible)
	_button(bottom, TranslationServer.translate("lab.message_2041b03309"), func(): _right.visible = not _right.visible)
	_status = _label(bottom, "")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_branch = OptionButton.new()
	bottom.add_child(_branch)
	_branch.item_selected.connect(_select_branch)
	_seek = HSlider.new()
	_seek.min_value = 0
	_seek.max_value = 1
	_seek.step = 1
	_seek.custom_minimum_size.y = 24
	layout.add_child(_seek)
	_timeline = TIMELINE.new()
	_timeline.session = session
	layout.add_child(_timeline)
	_timeline.seek_requested.connect(func(t): await session.seek(t); _refresh())
	_seek.drag_started.connect(func(): session.playing = false; _scrubbing = true)
	_seek.drag_ended.connect(func(_change): _scrubbing = false; await session.seek(roundi(_seek.value)); _refresh())
	_result = _label(layout, TranslationServer.translate("lab.message_25446d5b84"))
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_messages = _label(layout, TranslationServer.translate("lab.message_787af9549a"))
	_messages.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fill_palette()

func _fill_palette() -> void:
	for child in _palette.get_children():
		child.queue_free()
	var filter := _filter.text.to_lower()
	var definitions := ConfigManager.sorted(ConfigManager.enemies)
	definitions.append_array(ConfigManager.sorted(ConfigManager.bosses))
	definitions.sort_custom(func(a, b):
		var regular := ["drifter", "swarm", "darter", "armored", "gunner", "missile", "splitter", "splitling", "titan", "battleship"]
		var left := 2 if a is BossDef else (0 if String(a.id) in regular else 1)
		var right := 2 if b is BossDef else (0 if String(b.id) in regular else 1)
		return String(a.id) < String(b.id) if left == right else left < right)
	for def in definitions:
		if def is EnemyDef and def.behavior == &"part":
			continue
		var name: String = def.display_name
		var id := String(def.id)
		if not filter.is_empty() and not (id.to_lower().contains(filter) or name.to_lower().contains(filter)):
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(200, 62)
		button.tooltip_text = TranslationServer.translate("lab.message_2e31753d0b") % [name, id]
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		var picture = ICON.new()
		picture.texture = canvas.texture_for(id)
		picture.definition = def
		row.add_child(picture)
		var label := Label.new()
		var regular: bool = id in ["drifter", "swarm", "darter", "armored", "gunner", "missile", "splitter", "splitling", "titan", "battleship"]
		var category := TranslationServer.translate("lab.message_bd3455e23b") if regular else (TranslationServer.translate("lab.message_cab5ef8006") if def is BossDef else TranslationServer.translate("lab.message_0033dbf5f7"))
		label.text = TranslationServer.translate("lab.message_e6152035cf") % [name, id, category]
		label.add_theme_font_size_override("font_size", 13)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		button.pressed.connect(func(): canvas.spawn_type = id; canvas.mode = 1; _messages.text = name + TranslationServer.translate("lab.message_30308e98b5"))
		_palette.add_child(button)

func _set_mode(mode: int) -> void:
	canvas.mode = mode
	_messages.text = [TranslationServer.translate("lab.message_992b3b0d94"), TranslationServer.translate("lab.message_d01d58488a"), TranslationServer.translate("lab.message_6959dce1bf"), TranslationServer.translate("lab.message_e032c78766"), tr("lab.range_edit"), tr("lab.range_edit")][clampi(mode, 0, 5)]

func _toggle_play() -> void:
	session.playing = not session.playing
	_refresh()

func _reset() -> void:
	if _busy:
		return
	_busy = true
	await session.reset({"seed": int(_seed.value), "stage": _stage.selected + 1, "empty": _empty.button_pressed, "auto_spawn": _auto.button_pressed, "field": {"terrain": _terrain.button_pressed, "rocks": _rocks.button_pressed, "gimmicks": _gimmicks.button_pressed}})
	canvas.route.clear()
	canvas.selection.clear()
	canvas.result.clear()
	canvas.center = session.run.state.ship_pos
	_busy = false
	_refresh()

func _select_branch(index: int) -> void:
	if index == 0 or session.seeking:
		return
	var current := {"name": TranslationServer.translate("lab.message_549e9c3c03") % (session.branches.size() + 1), "history": session.history.duplicate(true), "end": session.furthest}
	var branch: Dictionary = session.branches[index - 1]
	session.current_branch = branch.name
	session.history.assign(branch.history)
	session.furthest = int(branch.end)
	session.branches[index - 1] = current
	await session.seek(session.furthest)
	_branch.select(0)
	_refresh()

func _evaluate() -> void:
	if _busy or session.seeking:
		return
	_busy = true
	session.playing = false
	var path: PackedVector2Array = canvas.route.duplicate()
	var revision: int = session.revision
	var result: Dictionary = await trial.evaluate(session, path, controls.draw_seconds.value)
	if is_instance_valid(self):
		if path != canvas.route: result.status = "stale"
		canvas.result = result
		_evaluation_revision = revision
		_show_result(result)
		comparisons.append({"route": path, "result": result.duplicate(true)})
		_update_comparisons()
	_busy = false

func _validate_route() -> void:
	canvas.result = CHECK.validate(session, canvas.route, controls.margin.value, controls.window_seconds.value, controls.draw_seconds.value, controls.exit_clearance.value)
	_evaluation_revision = session.revision
	_show_result(canvas.result)

func _show_result(value: Dictionary) -> void:
	_result.text = _status_title(value)
	if value.get("status") == "replayed":
		_result.text += TranslationServer.translate("lab.message_511972b218") % [value.kills, value.damage, value.gauge]
	elif value.has("blockers"):
		_result.text += TranslationServer.translate("lab.message_198ce2dd32") % [value.blockers.size(), float(value.margin)]
	if value.has("reason"):
		_result.text += "　" + String(value.reason)
	canvas.queue_redraw()

func _update_comparisons() -> void:
	controls.result_list.clear()
	for index in comparisons.size():
		var value: Dictionary = comparisons[index].result
		controls.result_list.add_item(TranslationServer.translate("lab.message_c93b3203d0") % [index + 1, value.get("status", TranslationServer.translate("lab.message_68dc5e1c46")), int(value.get("kills", 0))])
	canvas.comparisons = comparisons

func _generate_candidates() -> void:
	if _busy:
		return
	_busy = true
	session.playing = false
	candidate_values.clear()
	controls.candidates.clear()
	for child in controls.candidate_cards.get_children(): child.queue_free()
	for n in 3:
		var value: Dictionary = await generator.generate(session, pattern, int(_seed.value) + n)
		candidate_values.append(value)
		controls.candidates.add_item(TranslationServer.translate("lab.message_82b17798e4") % [n + 1, _status_title(value), int(_seed.value) + n])
		var index := candidate_values.size() - 1
		var card = CARD.new()
		card.value = value
		card.canvas = canvas
		card.caption = controls.candidates.get_item_text(index)
		card.pressed.connect(func(): controls.candidates.select(index); _preview_candidate(index))
		controls.candidate_cards.add_child(card)
		if generator.cancelled:
			break
	_busy = false
	_messages.text = TranslationServer.translate("lab.message_e3178fc873")

func _preview_candidate(index: int) -> void:
	if index < candidate_values.size():
		canvas.candidate = candidate_values[index]
		_messages.text = _status_title(canvas.candidate) + "　Seed " + str(canvas.candidate.get("seed", 0))
		var reasons := []
		for blocker in canvas.candidate.get("validation", {}).get("blockers", []):
			if not reasons.has(blocker.reason): reasons.append(blocker.reason)
		if not reasons.is_empty(): _messages.text += "　" + " / ".join(reasons)
		elif canvas.candidate.has("reason"): _messages.text += "　" + String(canvas.candidate.reason)
		canvas.queue_redraw()

func _apply_candidate() -> void:
	var indices: PackedInt32Array = controls.candidates.get_selected_items()
	if indices.is_empty():
		return
	var value: Dictionary = candidate_values[indices[0]]
	if not value.get("admitted", false) or not value.has("commands") or value.get("source_digest") != session.digest():
		_messages.text = TranslationServer.translate("lab.message_4949196244")
		return
	for command in value.commands:
		session.perform(command.kind, command.args)
	canvas.route = value.route.duplicate()
	canvas.candidate.clear()
	canvas.result.clear()
	_validate_route()

func _save(record_history: bool) -> void:
	var data := IO.record(session, canvas.route, pattern, comparisons, candidate_values) if record_history else IO.preset(session, canvas.route, pattern)
	var path := "%s/%s-%s.json" % [IO.ROOT, IO.safe_name(controls.name_field.text), "record" if record_history else "preset"]
	data["candidates"] = IO.plain(candidate_values)
	var error := IO.save_json(path, data)
	_messages.text = ProjectSettings.globalize_path(path) if error == OK else TranslationServer.translate("lab.message_e104208879") % error_string(error)

func _choose_file() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = PackedStringArray([TranslationServer.translate("lab.message_edf19cb8e9")])
		add_child(_file_dialog)
		_file_dialog.file_selected.connect(_load_file)
	DirAccess.make_dir_recursive_absolute(IO.ROOT)
	_file_dialog.current_dir = ProjectSettings.globalize_path(IO.ROOT)
	_file_dialog.popup_centered_ratio(0.7)

func _load_file(path: String) -> void:
	if _busy:
		return
	var data := IO.read_json(path)
	if data.has("error"):
		_messages.text = data.error
		return
	_busy = true
	await session.reset(data.spec)
	_seed.value = int(session.spec.seed)
	_stage.selected = int(session.spec.stage) - 1
	_empty.button_pressed = session.spec.get("empty", true)
	_auto.button_pressed = session.spec.get("auto_spawn", false)
	var flags: Dictionary = session.spec.get("field", {})
	_terrain.button_pressed = flags.get("terrain", not _empty.button_pressed)
	_rocks.button_pressed = flags.get("rocks", not _empty.button_pressed)
	_gimmicks.button_pressed = flags.get("gimmicks", not _empty.button_pressed)
	canvas.selection.clear()
	session.history.assign(data.history)
	session.branches.assign(data.get("branches", []))
	session.current_branch = String(data.get("branch_name", tr("lab.initial_branch")))
	session.branch_serial = int(data.get("branch_serial", session.branches.size()))
	session.furthest = int(data.get("end", 0))
	await session.seek(int(data.get("tick", 0)))
	canvas.route.clear()
	for point in data.get("route", []):
		canvas.route.append(session.vector(point))
	candidate_values.clear()
	controls.candidates.clear()
	for candidate in data.get("candidates", []):
		var points := PackedVector2Array()
		for point in candidate.get("route", []): points.append(session.vector(point))
		candidate["route"] = points
		if data.stale: candidate["source_digest"] = ""
		candidate_values.append(candidate)
		controls.candidates.add_item("%d %s" % [candidate_values.size(), _status_title(candidate)])
	pattern = data.get("pattern", {})
	canvas.pattern = pattern
	comparisons.clear()
	for comparison in data.get("results", []):
		var points := PackedVector2Array()
		for point in comparison.get("route", []): points.append(session.vector(point))
		comparisons.append({"route": points, "result": comparison.get("result", {})})
	canvas.result.clear()
	_update_comparisons()
	_messages.text = TranslationServer.translate("lab.message_10ccd95682") if data.stale else TranslationServer.translate("lab.message_0d4f7fc305")
	inspector.refresh(true)
	_busy = false

func _export() -> void:
	var targets := []
	for index in controls.export_targets.get_selected_items(): targets.append(controls.export_targets.get_item_metadata(index))
	var folder := "%s/exports/%s" % [IO.ROOT, IO.safe_name(controls.name_field.text)]
	var error := IO.save_json(folder + "/record.json", IO.record(session, canvas.route, pattern, comparisons, candidate_values))
	if error == OK:
		error = IO.save_json(folder + "/preset.json", IO.preset(session, canvas.route, pattern))
	if error == OK:
		error = IO.save_json(folder + "/changes.json", {"version": 1, "baseline": IO.baseline(), "enemy_overrides": IO.differences(session), "boss_overrides": IO.boss_differences(session), "selected_enemy_ids": targets, "target_stage": int(controls.export_stage.value), "target_phase": controls.export_phase.get_item_metadata(controls.export_phase.selected), "director": IO.plain(session.run.projectiles.director.settings), "director_enabled": session.run.projectiles.director.enabled, "pattern": IO.plain(pattern), "stage": int(session.spec.stage), "production_enabled": false})
	if error == OK:
		var director: Dictionary = session.run.projectiles.director.settings.duplicate(true)
		director["enabled"] = session.run.projectiles.director.enabled
		var phase: String = controls.export_phase.get_item_metadata(controls.export_phase.selected)
		error = IO.save_json(folder + "/adoption.json", {"enabled": false, "baseline": IO.adoption_baseline(), "phases": [] if phase.is_empty() else [phase], "director": director, "patterns": [] if pattern.is_empty() else [pattern], "interval": 5.0, "target_stage": int(controls.export_stage.value), "selected_enemy_ids": targets})
	if error == OK:
		await RenderingServer.frame_post_draw
		error = get_viewport().get_texture().get_image().save_png(folder + "/overview.png")
	_messages.text = TranslationServer.translate("lab.message_6d49e93edd") + ProjectSettings.globalize_path(folder) if error == OK else TranslationServer.translate("lab.message_f6f81b6554") + error_string(error)

func _refresh() -> void:
	if not is_instance_valid(session.run):
		return
	_play.text = TranslationServer.translate("lab.message_c2ddab60b8") if session.playing else TranslationServer.translate("lab.message_bf1c2f34ef")
	_seek.max_value = maxf(1, session.furthest)
	if not _scrubbing:
		_seek.set_value_no_signal(session.tick)
	_status.text = TranslationServer.translate("lab.message_15d10dbb3a") % [session.tick * session.DT, session.furthest * session.DT, session.run.state.world_time, session.run.enemies.count(), int(session.spec.seed)]
	if _branch.item_count != session.branches.size() + 1:
		_branch.clear()
		_branch.add_item(TranslationServer.translate("lab.message_98f82d7b9f"))
		for branch in session.branches:
			_branch.add_item(branch.name)
	_branch.set_item_text(0, TranslationServer.translate("lab.message_98f82d7b9f") + " " + session.current_branch)
	for index in session.branches.size():
		_branch.set_item_text(index + 1, String(session.branches[index].name))
	_status.text += "　" + tr("lab.route_length") % [CHECK.length(canvas.route), session.run.draw.budget(session.run.state.stats.capacity * session.run.state.gauge), 100 * CHECK.length(canvas.route) / maxf(0.01, session.run.draw.budget(session.run.state.stats.capacity * session.run.state.gauge))]
	canvas.queue_redraw()
	_timeline.queue_redraw()
	if not canvas.result.is_empty() and _evaluation_revision >= 0 and _evaluation_revision != session.revision:
		_result.text = TranslationServer.translate("lab.message_91f8bdc328")
	inspector.refresh()
	controls.sync_from_session()

func _process(_delta: float) -> void:
	if session != null and is_instance_valid(session.run):
		_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and session != null:
		session.playing = false
		if is_instance_valid(canvas):
			canvas.cancel_gesture()

func _select_comparison(index: int) -> void:
	var value: Dictionary = comparisons[index]
	canvas.route = value.route.duplicate()
	canvas.result = value.result.duplicate(true)
	if canvas.result.get("source_digest", canvas.result.get("digest", "")) != session.digest(): canvas.result.status = "stale"
	_evaluation_revision = session.revision
	_show_result(canvas.result)

func _status_title(value: Dictionary) -> String:
	var labels := {"static": TranslationServer.translate("lab.message_9ec7700849"), "window": TranslationServer.translate("lab.message_0df05349ff"), "unsupported": TranslationServer.translate("lab.message_af33e7e17b"), "unfound": TranslationServer.translate("lab.message_3aee526f77"), "invalid": TranslationServer.translate("lab.message_aa259c678f"), "replayed": TranslationServer.translate("lab.message_dd16bfc556") if value.get("success", false) else TranslationServer.translate("lab.message_b8f8f95d8c"), "cancelled": TranslationServer.translate("lab.message_67847e89ae"), "stale": TranslationServer.translate("lab.message_94deee7e2e")}
	return String(labels.get(value.get("status", ""), TranslationServer.translate("lab.message_68dc5e1c46")))

func _leave() -> void:
	trial.cancel()
	generator.cancelled = true
	session.cancel_seek()
	while _busy:
		await get_tree().process_frame
	GameManager.reset_to_main_menu()

func _reload_data() -> void:
	trial.cancel()
	generator.cancelled = true
	session.cancel_seek()
	while _busy: await get_tree().process_frame
	if ConfigManager.reload_experiment_data():
		await _reset()
		_fill_palette()
		_messages.text = tr("lab.data_reloaded")
	else:
		_messages.text = tr("lab.reload_failed")
