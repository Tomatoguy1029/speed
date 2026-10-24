@tool
extends VBoxContainer

var current: Resource
var source_path := ""
var history := UndoRedo.new()
var _fields := GridContainer.new()
var _status := Label.new()
var _path := LineEdit.new()
var rules: Resource
var rules_path := "res://data/bosses/ai/hydra_action_rules.tres"
var graph := preload("res://addons/boss_flow/technique_graph.gd").new()
var preview := preload("res://addons/boss_flow/range_preview.gd").new()
var editing_rules := false
var flow: Resource
var flow_path := "res://data/bosses/ai/hydra_flow.tres"
var flow_bar := TabBar.new()
var editing_flow := false
var combo_editor := preload("res://addons/boss_flow/combo_graph.gd").new()
var combo_id := ""
var preview_stamina := 8.0
var preview_radius := 1800.0
var preview_heads := {"bite": 2, "vortex": 2, "debris": 1, "beam": 2, "thunder": 1}
var dirty_flow := false
var dirty_rules := false
var saved_version := 0
var working: Dictionary = {}
var _dirty_working := {}
var _source_hashes := {}
var _embedded_working := {}
var preview_separated := false
var _settings := OptionButton.new()
var _techniques := OptionButton.new()
var _heading := Label.new()
var _preview_frame := CenterContainer.new()
var _split := HSplitContainer.new()
var _selected_technique := "bite_thrust"
var _last_combo_path: Array = []
var _probability_previous := ""
var _scale := 1.0
var _file_dialog := FileDialog.new()
const GRAPH := preload("res://addons/boss_flow/technique_graph.gd")
const PARAM_LABELS := {"normal_charge": "予備動作（秒）", "normal_hold": "攻撃後の停止（秒）", "attack_cd": "技後の待ち（秒）", "normal_lunge": "踏み込み時間（秒）", "warning_time": "予告（秒）", "performance_time": "実行時間（秒）", "tech_recovery": "技後の全体待ち（秒）", "cooldown": "再使用待ち（秒）", "sweep_time": "薙ぎ時間（秒）", "sweep_reach": "薙ぎの長さ", "sweep_arc": "薙ぎの角度（rad）", "aim_tracking": "標的位置を追う時間（秒）"}

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	saved_version = history.get_version()
	add_child(_path)
	_path.hide()
	_scale = maxf(1.0, float(get_theme_default_font_size()) / 14.0)
	add_theme_constant_override("separation", int(6 * _scale))
	var toolbar := HFlowContainer.new()
	add_child(toolbar)
	var title := Label.new()
	title.text = "ボス行動の調整"
	toolbar.add_child(title)
	var files := MenuButton.new()
	files.text = "ファイル"
	files.get_popup().add_item("技の設定ファイルを開く…", 0)
	files.get_popup().id_pressed.connect(func(_id): _file_dialog.popup_centered_ratio(0.65))
	toolbar.add_child(files)
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.tres ; 技の設定"])
	_file_dialog.file_selected.connect(open_technique)
	add_child(_file_dialog)
	for entry in [["変更を保存", save_current], ["保存して試遊", play_current], ["元に戻す", undo_edit], ["やり直す", redo_edit]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		toolbar.add_child(button)
	var help := Label.new()
	help.text = "上段：戦闘の流れ　／　技ノード：性能　／　接続線：発動条件"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	var flow_row := HBoxContainer.new()
	add_child(flow_row)
	var flow_label := Label.new()
	flow_label.text = "戦闘の区間"
	flow_row.add_child(flow_label)
	flow_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_bar.tab_changed.connect(_edit_section)
	flow_row.add_child(flow_bar)
	var add_section := Button.new()
	add_section.text = "区間を追加"
	add_section.pressed.connect(_add_section)
	flow_row.add_child(add_section)
	flow = load(flow_path).duplicate(true) if ResourceLoader.exists(flow_path) else preload("res://scripts/data_types/boss_flow_def.gd").new()
	_refresh_flow()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_split)
	var graph_column := VBoxContainer.new()
	graph_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(graph_column)
	var graph_tools := HFlowContainer.new()
	graph_column.add_child(graph_tools)
	var graph_label := Label.new()
	graph_label.text = "技と発動条件"
	graph_tools.add_child(graph_label)
	var add_combo := Button.new()
	add_combo.text = "コンボを追加"
	add_combo.pressed.connect(_new_combo)
	graph_tools.add_child(add_combo)
	var zoom_label := Label.new()
	zoom_label.text = "図の拡大率"
	graph_tools.add_child(zoom_label)
	var zoom := HSlider.new()
	zoom.min_value = 0.35
	zoom.max_value = 1.5
	zoom.step = 0.05
	zoom.value = 1.0
	zoom.custom_minimum_size.x = 90 * _scale
	zoom.value_changed.connect(func(value): graph.zoom = value)
	graph.gui_input.connect(func(_event): zoom.set_value_no_signal(graph.zoom))
	graph_tools.add_child(zoom)
	graph_column.add_child(graph)
	graph_tools.add_child(graph.make_display_bar())
	graph.picked.connect(_picked)
	graph.layout_changed.connect(func(): dirty_rules = true)
	graph.edit_requested.connect(func(before, after, title_text):
		history.create_action(title_text)
		history.add_do_method(_set_graph_state.bind(after))
		history.add_undo_method(_set_graph_state.bind(before))
		history.commit_action())
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 290 * _scale
	details.size_flags_horizontal = Control.SIZE_FILL
	_split.add_child(details)
	for pair in [["編集する内容", _settings], ["対象の技", _techniques]]:
		var label := Label.new()
		label.text = pair[0]
		details.add_child(label)
		pair[1].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_child(pair[1])
	for text in ["技の性能", "発動条件", "区間の選択割合", "スタミナと休息", "同時攻撃の禁止", "攻撃範囲の確認"]: _settings.add_item(text)
	_settings.item_selected.connect(_select_settings)
	_techniques.item_selected.connect(func(index):
		var id: String = _techniques.get_item_metadata(index)
		_picked("condition" if _settings.selected == 1 else "technique", id)
		graph.focus_technique(id))
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_heading)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(_preview_frame)
	_preview_frame.add_child(preview)
	preview.custom_minimum_size = Vector2(150, 150) * _scale
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fields.columns = 2
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_fields)
	add_child(_status)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_rules()
	add_child(combo_editor)
	combo_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combo_editor.hide()
	combo_editor.inspected.connect(_edit_combo_step)
	combo_editor.changed.connect(func(value):
		history.create_action("コンボ内部を変更")
		history.add_do_method(_set_combo.bind(combo_id, value))
		history.add_undo_method(_set_combo.bind(combo_id, rules.combos.get(combo_id, {"type": "sequence", "children": []}).duplicate(true)))
		history.commit_action())
	_picked("technique", _selected_technique)
	set_meta("boss_layout_revision", 2)

func _select_settings(index: int) -> void:
	combo_editor.hide()
	match index:
		0: _picked("technique", _selected_technique)
		1: _picked("condition", _selected_technique)
		2: _edit_section(maxi(0, flow_bar.current_tab))
		3: _edit_common()
		4: _edit_forbidden()
		5: _edit_coverage()

func _context(title_text: String, mode: int, show_preview := false) -> void:
	_heading.text = title_text
	_settings.select(mode)
	_techniques.disabled = mode not in [0, 1]
	_preview_frame.visible = show_preview

func _refresh_techniques() -> void:
	_techniques.clear()
	var ids: Array[String] = rules.node_ids()
	for id in ids:
		_techniques.add_item(GRAPH.node_title(rules, id))
		_techniques.set_item_metadata(_techniques.item_count - 1, id)
	if not ids.has(_selected_technique) and not ids.is_empty(): _selected_technique = ids[0]

func _set_graph_state(value: Dictionary) -> void:
	for key in value: rules.set(key, value[key].duplicate(true))
	dirty_rules = true
	graph.show_rules(rules)
	_refresh_techniques()
	if rules.node_ids().has(_selected_technique): _picked("condition" if _settings.selected == 1 else "technique", _selected_technique)
	else:
		_clear_fields()
		_context("技がありません。元に戻すで復元できます。", 0)

func _input(event: InputEvent) -> void:
	if _file_dialog.visible or not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if focus != null and not is_ancestor_of(focus): return
	var command_key: bool = event.is_command_or_control_pressed()
	if command_key and event.keycode == KEY_Z:
		if event.shift_pressed: redo_edit()
		else: undo_edit()
		get_viewport().set_input_as_handled()
	elif command_key and event.keycode in [KEY_C, KEY_V, KEY_X, KEY_D]:
		var action: String = {KEY_C: "copy", KEY_V: "paste", KEY_X: "cut", KEY_D: "duplicate"}[event.keycode]
		if focus != null and combo_editor.is_ancestor_of(focus): combo_editor.command(action)
		else: graph.command(action)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		if focus != null and combo_editor.is_ancestor_of(focus): combo_editor.command("delete")
		else: graph.command("delete")
		get_viewport().set_input_as_handled()

func undo_edit() -> void:
	history.undo()
	_refresh_inspector()

func redo_edit() -> void:
	history.redo()
	_refresh_inspector()

func _refresh_inspector() -> void:
	if _settings.selected == 0 and combo_editor.visible and rules.combos.has(combo_id):
		var step: Dictionary = rules.combos[combo_id]
		var valid := not _last_combo_path.is_empty()
		for index in _last_combo_path:
			if index < 0 or index >= step.get("children", []).size():
				valid = false
				break
			step = step.children[index]
		if valid: _edit_combo_step(_last_combo_path.duplicate())
		else: _edit_custom(combo_id)
	elif _settings.selected == 2: _edit_section(maxi(0, flow_bar.current_tab), _probability_previous)
	else: _select_settings(_settings.selected)

func _load_rules() -> void:
	_embedded_working.clear()
	if ResourceLoader.exists(rules_path):
		rules = ResourceLoader.load(rules_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP).duplicate(false)
		rules.conditions = rules.conditions.duplicate(true)
		rules.techniques = rules.techniques.duplicate()
		rules.combos = rules.combos.duplicate(true)
		rules.costs = rules.costs.duplicate(true)
		rules.forbidden = rules.forbidden.duplicate(true)
		rules.layout = rules.layout.duplicate(true)
		rules.graph_nodes = rules.graph_nodes.duplicate(true)
	else:
		rules = preload("res://scripts/data_types/boss_action_rules.gd").new()
		for filename in DirAccess.get_files_at("res://data/bosses/hydra_moves"):
			if filename.ends_with(".tres"): rules.techniques.append(load("res://data/bosses/hydra_moves/" + filename))
	graph.show_rules(rules)
	_refresh_techniques()

func open_boss(action_path: String, section_path: String) -> Error:
	if not ResourceLoader.exists(action_path) or not ResourceLoader.exists(section_path): return ERR_FILE_NOT_FOUND
	if action_path == rules_path and section_path == flow_path: return OK
	if history.get_version() != saved_version or dirty_flow or dirty_rules:
		_status.text = "未保存の変更があります。「保存」してから別のボスを開いてください。"
		return ERR_BUSY
	rules_path = action_path
	flow_path = section_path
	working.clear()
	_dirty_working.clear()
	_source_hashes.clear()
	current = null
	history.clear_history()
	saved_version = history.get_version()
	flow = ResourceLoader.load(flow_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP).duplicate(true)
	_load_rules()
	_refresh_flow()
	_clear_fields()
	_status.text = "ボスの技定義と戦闘フローを開きました"
	return OK

func _is_hydra() -> bool: return rules.adapter == &"hydra" or "hydra_action_rules" in rules_path

func _picked(kind: String, id: String) -> void:
	if not id.is_empty():
		_selected_technique = id
		for i in _techniques.item_count:
			if _techniques.get_item_metadata(i) == id: _techniques.select(i)
	editing_flow = false
	combo_editor.hide()
	if kind == "coverage":
		_edit_coverage()
	elif kind == "technique":
		var source: String = rules.source_for(id)
		if rules.combos.has(source):
			_edit_custom(source)
			return
		for move in rules.techniques:
			if String(move.technique) == source:
				if move.resource_path.is_empty() or "::" in move.resource_path:
					if not _embedded_working.has(source):
						_embedded_working[source] = move.duplicate(true)
						rules.techniques[rules.techniques.find(move)] = _embedded_working[source]
					current = _embedded_working[source]
					source_path = rules_path
					_refresh()
				else: open_technique(move.resource_path)
				var button := Button.new()
				button.text = "技の順序・同時実行を編集"
				button.pressed.connect(func():
					combo_id = id
					combo_editor.path.clear()
					editing_rules = true
					combo_editor.show()
					combo_editor.open(rules.combos.get(id, {"type": "sequence", "children": []}), rules.techniques))
				_fields.add_child(button)
				_fields.add_child(Control.new())
	elif kind == "condition":
		_context(GRAPH.title_for(rules.source_for(id)) + " の発動条件", 1, true)
		editing_rules = true
		preview.layers = []
		preview.coverage_mode = false
		for child in _fields.get_children():
			_fields.remove_child(child)
			child.queue_free()
		var gate: Dictionary = {"min": 0.0, "max": 600.0, "angle": 0.0, "half_angle": 180.0}.merged(rules.conditions.get(id, {}), true)
		rules.conditions[id] = gate
		preview.gate = gate
		preview.queue_redraw()
		for key in ["min", "max", "angle", "half_angle"]:
			var label := Label.new()
			label.text = {"min": "最小距離", "max": "最大距離", "angle": "中心角度（度）", "half_angle": "半角（度）"}[key]
			_fields.add_child(label)
			var field := SpinBox.new()
			field.min_value = -180 if key == "angle" else 0
			field.max_value = 180 if "angle" in key else 100000
			field.value = gate[key]
			field.value_changed.connect(func(value):
				history.create_action("発動条件を変更")
				history.add_do_method(_set_gate.bind(id, key, value))
				history.add_undo_method(_set_gate.bind(id, key, gate[key]))
				history.commit_action())
			_fields.add_child(field)
		_status.text = "距離と角度を変えると、上の範囲図へ反映されます。"

func _set_gate(id: String, key: String, value: float) -> void:
	dirty_rules = true
	rules.conditions[id][key] = value
	preview.queue_redraw()

func _set_combo(id: String, value: Dictionary) -> void:
	dirty_rules = true
	rules.combos[id] = value.duplicate(true)
	combo_editor.open(rules.combos[id], rules.techniques)

func _edit_combo_step(path: Array) -> void:
	_last_combo_path = path.duplicate()
	_clear_fields()
	var step: Dictionary = rules.combos[combo_id]
	for index in path: step = step.children[index]
	_heading.text = GRAPH.title_for(combo_id) + " / " + {"wait": "待機", "action": "実行する技", "branch": "条件分岐", "sequence": "順番に実行", "parallel": "同時に実行"}.get(step.get("type", ""), "要素") + "の設定"
	_status.text = "内部の要素を編集しています。「内部編集を閉じる」で技の図へ戻れます。"
	if step.type == "wait":
		_number_field("待機（秒）", step.seconds, func(value): _combo_field(path, "seconds", value))
	elif step.type == "branch":
		_status.text += "（子の左が成立、右が不成立）"
		for key in ["min", "max", "angle", "half_angle"]:
			_number_field(key, step.condition.get(key, 0.0), func(value): _combo_field(path, key, value, true), -180.0 if key == "angle" else 0.0)
	elif step.type == "action":
		var label := Label.new()
		label.text = "実行する技"
		_fields.add_child(label)
		var choices := OptionButton.new()
		for move in rules.techniques:
			choices.add_item(GRAPH.title_for(String(move.technique)))
			choices.set_item_metadata(choices.item_count - 1, String(move.technique))
			if String(move.technique) == step.id: choices.selected = choices.item_count - 1
		choices.item_selected.connect(func(index): _combo_field(path, "id", choices.get_item_metadata(index)))
		_fields.add_child(choices)

func _combo_field(path: Array, key: String, value: Variant, condition := false) -> void:
	var copy: Dictionary = rules.combos[combo_id].duplicate(true)
	var step := copy
	for index in path: step = step.children[index]
	if condition: step.condition[key] = value
	else: step[key] = value
	history.create_action("コンボの技間条件・待機を変更")
	history.add_do_method(_set_combo.bind(combo_id, copy))
	history.add_undo_method(_set_combo.bind(combo_id, rules.combos[combo_id].duplicate(true)))
	history.commit_action()

func _open_path() -> void:
	open_technique(_path.text)

func open_technique(path: String) -> Error:
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not loaded.get("parameters") is Dictionary:
		_status.text = "技の設定を開けません: " + path
		return ERR_INVALID_DATA
	current = working.get(path, loaded.duplicate(true))
	working[path] = current
	if not _source_hashes.has(path): _source_hashes[path] = FileAccess.get_sha256(path)
	editing_rules = false
	editing_flow = false
	source_path = path
	_path.text = path
	_refresh()
	return OK

func set_value(key: String, value: float) -> void:
	if current == null or not current.parameters.has(key): return
	var old: Variant = current.parameters[key]
	var next: Variant = int(value) if old is int else value
	if old == next: return
	history.create_action("技の " + key + " を変更")
	history.add_do_method(_assign.bind(current, key, next))
	history.add_undo_method(_assign.bind(current, key, old))
	history.commit_action()

func _assign(target: Resource, key: String, value: Variant) -> void:
	target.parameters[key] = value
	if not working.values().has(target): dirty_rules = true
	else:
		for path in working:
			if working[path] == target: _dirty_working[path] = true
	target.emit_changed()
	_status.text = "変更があります。「変更を保存」で確定できます。"
	for node in _fields.get_children():
		if target == current and node is SpinBox and node.get_meta("key", "") == key:
			node.set_value_no_signal(float(value))

func save_current() -> Error:
	for path in _dirty_working:
		if FileAccess.get_sha256(path) != _source_hashes.get(path, ""):
			_status.text = "外部で技の設定が変わっています。変更を保護するため保存を止めました: " + path
			return ERR_BUSY
		var move: Resource = working[path]
		var disk := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if disk == null or disk.parameters != move.parameters:
			var error := ResourceSaver.save(move, path)
			if error != OK: return error
		_source_hashes[path] = FileAccess.get_sha256(path)
		for i in rules.techniques.size():
			if rules.techniques[i].resource_path == path: rules.techniques[i] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_dirty_working.clear()
	if dirty_rules:
		var error := ResourceSaver.save(rules, rules_path)
		if error != OK: return error
	if dirty_flow:
		var error := ResourceSaver.save(flow, flow_path)
		if error != OK: return error
	dirty_rules = false
	dirty_flow = false
	saved_version = history.get_version()
	_status.text = "保存済み（実行データは生成していません）"
	return OK

func _clear_fields() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()

func _refresh_flow() -> void:
	var selected := flow_bar.current_tab
	flow_bar.set_block_signals(true)
	flow_bar.clear_tabs()
	for i in flow.sections.size(): flow_bar.add_tab("%d. %s" % [i + 1, flow.sections[i].get("name", "区間")])
	if not flow.sections.is_empty(): flow_bar.current_tab = clampi(selected, 0, flow.sections.size() - 1)
	flow_bar.set_block_signals(false)

func _add_section() -> void:
	var copy: Array = flow.sections.duplicate(true)
	if not copy.is_empty() and copy[-1].get("next", 0) == 0: copy[-1].next = copy.size()
	copy.append({"name": "区間" + str(copy.size() + 1), "request": "normal", "cap": 2.0, "weights": {"single": 60.0, "parallel": 25.0, "combo": 15.0}, "next": 0})
	history.create_action("区間を追加")
	history.add_do_method(_set_sections.bind(copy))
	history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
	history.commit_action()
	_edit_section(copy.size() - 1)

func _set_sections(value: Array) -> void:
	dirty_flow = true
	flow.sections = value.duplicate(true)
	_refresh_flow()

func _edit_section(i: int, previous := "") -> void:
	_probability_previous = previous
	_context(flow.sections[i].get("name", "区間") + " の選択割合", 2)
	editing_flow = true
	_clear_fields()
	_status.text = "共通フローの区間（技定義は全区間で共通）"
	var avoid := CheckButton.new()
	avoid.text = "連発を避ける"
	avoid.tooltip_text = "別候補があるとき、直前と同じ技の組み合わせを避けます。"
	avoid.button_pressed = flow.sections[i].get("avoid_repeat", true)
	avoid.toggled.connect(func(value):
		var copy: Array = flow.sections.duplicate(true)
		copy[i].avoid_repeat = value
		history.create_action("連発回避を変更")
		history.add_do_method(_set_sections.bind(copy))
		history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
		history.commit_action())
	_fields.add_child(avoid)
	_fields.add_child(Control.new())
	for key in ["name"]:
		var label := Label.new()
		label.text = {"name": "区間名", "request": "要求 normal / major / rest", "next": "次の区間番号（0から）"}[key]
		_fields.add_child(label)
		var field := LineEdit.new()
		field.text = str(flow.sections[i].get(key, 0 if key == "next" else "normal"))
		field.text_submitted.connect(func(value):
			var copy: Array = flow.sections.duplicate(true)
			copy[i][key] = int(value) if key == "next" else value
			history.create_action("区間を変更")
			history.add_do_method(_set_sections.bind(copy))
			history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
			history.commit_action())
		field.focus_exited.connect(func(): _section_property(i, key, field.text))
		_fields.add_child(field)
	var request_label := Label.new()
	request_label.text = "要求する攻撃"
	_fields.add_child(request_label)
	var request := OptionButton.new()
	var requests := ["normal", "major", "rest", "any"]
	for j in requests.size(): request.add_item(["通常・同時・コンボ", "大技", "休息", "全候補"][j])
	request.selected = maxi(0, requests.find(flow.sections[i].get("request", "normal")))
	request.item_selected.connect(func(j): _section_property(i, "request", requests[j]))
	_fields.add_child(request)
	var next_label := Label.new()
	next_label.text = "次の区間"
	_fields.add_child(next_label)
	var next := OptionButton.new()
	for section in flow.sections: next.add_item(section.get("name", "区間"))
	next.selected = clampi(int(flow.sections[i].get("next", 0)), 0, flow.sections.size() - 1)
	next.item_selected.connect(func(j): _section_property(i, "next", j))
	_fields.add_child(next)
	_number_field("今回の消費上限", float(flow.sections[i].get("cap", 2.0)), func(value):
		var copy: Array = flow.sections.duplicate(true)
		copy[i].cap = value
		history.create_action("消費上限を変更")
		history.add_do_method(_set_sections.bind(copy))
		history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
		history.commit_action())
	var probability_label := Label.new()
	probability_label.text = "割合を使う条件"
	_fields.add_child(probability_label)
	var probability := OptionButton.new()
	var previous_types := ["", "single", "parallel", "combo", "major"]
	for title_text in ["基本の割合", "直前が単独攻撃", "直前が同時攻撃", "直前がコンボ", "直前が大技"]: probability.add_item(title_text)
	probability.selected = maxi(0, previous_types.find(previous))
	probability.item_selected.connect(func(index): _edit_section(i, previous_types[index]))
	_fields.add_child(probability)
	var weights: Dictionary = flow.sections[i].get("weights", {})
	for rule in flow.sections[i].get("probability_rules", []):
		if rule.previous == previous: weights = rule.weights
	for key in ["single", "parallel", "combo", "major"]:
		_number_field({"single": "単独攻撃の割合", "parallel": "同時攻撃の割合", "combo": "コンボの割合", "major": "大技の割合"}[key], float(weights.get(key, 0.0)), func(value): _section_weight(i, key, value, previous))

func _number_field(title_text: String, value: float, changed: Callable, minimum := 0.0, maximum := 100000.0) -> SpinBox:
	var label := Label.new()
	label.text = title_text
	_fields.add_child(label)
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = 0.1
	field.value = value
	field.value_changed.connect(changed)
	_fields.add_child(field)
	return field

func _section_property(index: int, key: String, value: Variant) -> void:
	if flow.sections[index].get(key) == value: return
	var copy: Array = flow.sections.duplicate(true)
	copy[index][key] = value
	history.create_action("区間を変更")
	history.add_do_method(_set_sections.bind(copy))
	history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
	history.commit_action()

func _section_weight(index: int, key: String, value: float, previous := "") -> void:
	var copy: Array = flow.sections.duplicate(true)
	if previous.is_empty():
		if not copy[index].has("weights"): copy[index].weights = {}
		copy[index].weights[key] = value
	else:
		if not copy[index].has("probability_rules"): copy[index].probability_rules = []
		var found := false
		for rule in copy[index].probability_rules:
			if rule.previous == previous:
				rule.weights[key] = value
				found = true
		if not found: copy[index].probability_rules.append({"previous": previous, "weights": copy[index].weights.duplicate().merged({key: value}, true)})
	history.create_action("選択確率を変更")
	history.add_do_method(_set_sections.bind(copy))
	history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
	history.commit_action()

func _edit_probability(index: int, previous: String) -> void:
	_clear_fields()
	_status.text = "直前が「%s」の場合の区間確率" % previous
	var weights: Dictionary = flow.sections[index].get("weights", {})
	for rule in flow.sections[index].get("probability_rules", []):
		if rule.previous == previous: weights = rule.weights
	for key in ["single", "parallel", "combo", "major"]:
		_number_field(key, float(weights.get(key, 0.0)), func(value): _section_weight(index, key, value, previous))

func _edit_common() -> void:
	_context("全区間で共有するスタミナと休息", 3)
	editing_flow = true
	_clear_fields()
	_status.text = "全区間から不足時に休息へ入ります"
	for key in ["maximum_stamina", "partial_rest", "empty_rest"]:
		_number_field({"maximum_stamina": "最大スタミナ", "partial_rest": "残量ありの休息（秒）", "empty_rest": "枯渇時の休息（秒）"}[key], flow.get(key), func(value):
			history.create_action("休息・スタミナを変更")
			history.add_do_property(flow, key, value)
			history.add_undo_property(flow, key, flow.get(key))
			history.add_do_method(_dirty_flow)
			history.add_undo_method(_dirty_flow)
			history.commit_action())

func _dirty_flow() -> void: dirty_flow = true

func _edit_forbidden() -> void:
	_context("同時に実行しない技の組み合わせ", 4)
	editing_flow = false
	editing_rules = true
	_clear_fields()
	_status.text = "同時に使わない技の組（逆順も同じ設定）"
	for pair in rules.forbidden:
		var label := Label.new()
		label.text = "%s と %s" % [GRAPH.title_for(pair[0]), GRAPH.title_for(pair[1])]
		_fields.add_child(label)
		var remove := Button.new()
		remove.text = "削除"
		remove.pressed.connect(func():
			var copy: Array = rules.forbidden.duplicate(true)
			copy.erase(pair)
			_set_forbidden_undo(copy))
		_fields.add_child(remove)
	var choices: Array[OptionButton] = []
	for side in 2:
		var choice := OptionButton.new()
		for move in rules.techniques:
			choice.add_item(GRAPH.title_for(String(move.technique)))
			choice.set_item_metadata(choice.item_count - 1, String(move.technique))
		choices.append(choice)
		_fields.add_child(choice)
	var add := Button.new()
	add.text = "禁止ペアを追加"
	add.pressed.connect(func():
		var pair := [choices[0].get_item_metadata(choices[0].selected), choices[1].get_item_metadata(choices[1].selected)]
		pair.sort()
		var copy: Array = rules.forbidden.duplicate(true)
		if not copy.has(pair): copy.append(pair)
		_set_forbidden_undo(copy))
	_fields.add_child(add)

func _set_forbidden_undo(value: Array) -> void:
	history.create_action("併用禁止を変更")
	history.add_do_method(_set_forbidden.bind(value))
	history.add_undo_method(_set_forbidden.bind(rules.forbidden.duplicate(true)))
	history.commit_action()

func _set_forbidden(value: Array) -> void:
	dirty_rules = true
	rules.forbidden = value.duplicate(true)
	_edit_forbidden()

func _edit_coverage() -> void:
	_context("指定した状況の範囲を重ねて確認", 5, true)
	_clear_fields()
	var separated := CheckButton.new()
	separated.text = "分離後の状況"
	separated.button_pressed = preview_separated
	separated.toggled.connect(func(value): preview_separated = value)
	if _is_hydra():
		_fields.add_child(separated)
		_fields.add_child(Control.new())
	else: separated.free()
	_number_field("確認する残量", preview_stamina, func(value): preview_stamina = value)
	_number_field("確認領域の半径", preview_radius, func(value): preview_radius = value, 1.0)
	for kind in preview_heads:
		if _is_hydra(): _number_field({"bite": "噛みつき", "vortex": "渦", "debris": "瓦礫", "beam": "ビーム", "thunder": "雷"}[kind] + "の生存数", preview_heads[kind], func(value): preview_heads[kind] = int(value), 0.0, 2.0)
	var refresh := Button.new()
	refresh.text = "この状況の攻撃範囲を表示"
	refresh.pressed.connect(_analyze_coverage)
	_fields.add_child(refresh)
	_analyze_coverage()

func _analyze_coverage() -> void:
	preview.coverage_mode = true
	if not _is_hydra():
		var layers: Array = []
		for move in rules.techniques:
			if float(rules.costs.get(String(move.technique), 1.0)) <= preview_stamina:
				for condition in rules.active_gates_for(String(move.technique)):
					var gate: Dictionary = condition.duplicate()
					gate.max = minf(float(gate.get("max", preview_radius)), preview_radius)
					layers.append(gate)
		preview.radius = preview_radius
		preview.layers = layers
		var result: Dictionary = preview.analyze(layers, preview_radius)
		preview.gaps = result.points
		preview.queue_redraw()
		_status.text = "条件範囲の未カバー: %dサンプル（橙）" % result.holes
		return
	var layers: Array = []
	var definition = load("res://data/bosses/hydra.tres")
	var motion = preload("res://scripts/bosses/hydra_normals.gd")
	var total := 0
	for kind in preview_heads: total += preview_heads[kind]
	var count := 3 if total <= 3 else 5 if total <= 5 else 8
	var kinds: Array = load("res://scripts/bosses/hydra_boss.gd").NECKS[count]
	var used := {}
	var heads: Array = []
	for i in kinds.size():
		var kind := String(kinds[i])
		if int(used.get(kind, 0)) >= int(preview_heads.get(kind, 0)): continue
		used[kind] = int(used.get(kind, 0)) + 1
		var angle := TAU * i / kinds.size()
		var base: Vector2 = Vector2.from_angle(angle) * float(definition.radius)
		heads.append({"kind": kind, "base": base, "head": base + Vector2.from_angle(angle) * float(definition.params.neck_rest), "base_angle": angle})
	for move in rules.techniques:
		if float(rules.costs.get(String(move.technique), 1.0)) > preview_stamina: continue
		if move.head_kind == &"":
			if String(move.technique) in ["north", "sequence", "curve"] and (preview_separated or total < 5): continue
			if String(move.technique) in ["grid", "swarm"] and not preview_separated: continue
			var required: Array = {"tornado": ["vortex", "debris"], "debris_shatter": ["debris", "beam"], "beam_pincer": ["beam", "beam"]}.get(String(move.technique), [])
			var available := preview_heads.duplicate()
			var possible := true
			for kind in required:
				available[kind] -= 1
				if available[kind] < 0: possible = false
			if not possible: continue
		for condition in rules.active_gates_for(String(move.technique)):
			var gate: Dictionary = condition.duplicate()
			gate.max = minf(float(gate.get("max", preview_radius)), preview_radius)
			if move.head_kind == &"": layers.append({"gate": gate})
			else:
				for head in heads:
					if head.kind != String(move.head_kind): continue
					var snapshot: Dictionary = head.duplicate()
					snapshot.gate = gate
					snapshot.separated = preview_separated
					snapshot.reach = motion.reach(move.technique, definition.params.merged(move.parameters, true))
					layers.append(snapshot)
	preview.radius = preview_radius
	preview.layers = layers
	var result: Dictionary = preview.analyze(layers, preview_radius)
	preview.gaps = result.points
	preview.queue_redraw()
	_status.text = "基準姿勢の条件・到達上限: %d候補 / 未カバー %dサンプル（橙）。戦闘中の姿勢・配置で変化します。" % [layers.size(), result.holes]

func preview_scene() -> String:
	return rules.trial_scene if not rules.trial_scene.is_empty() else "res://gyms/boss_flow_trial.tscn" if _is_hydra() else ""

func play_current() -> void:
	var scene := preview_scene()
	if scene.is_empty() or not ResourceLoader.exists(scene):
		_status.text = "このボスの試遊シーンを技定義の Trial Scene に設定してください。"
		return
	if save_current() != OK: return
	var result = preload("res://tools/content/build_boss_program.gd").compile({"rules": rules, "flow": flow}, "res://.content/boss_preview.tres")
	if result.error != OK:
		_status.text = "生成失敗: " + "; ".join(result.get("errors", [error_string(result.error)]))
		return
	if Engine.is_editor_hint(): EditorInterface.play_custom_scene(scene)

func _refresh() -> void:
	_context(GRAPH.title_for(String(current.technique)) + " の性能と時間", 0)
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	for key in current.parameters:
		if key in ["cost", "major_cost"]: continue
		var label := Label.new()
		var description: Array = BossDef.PARAMS_DOCS.get(key, [])
		label.text = PARAM_LABELS.get(key, description[0] if not description.is_empty() else String(key))
		if description.size() > 1: label.tooltip_text = description[1]
		_fields.add_child(label)
		var field := SpinBox.new()
		field.min_value = 0
		field.max_value = 100000
		field.step = 1 if current.parameters[key] is int else 0.01
		field.value = float(current.parameters[key])
		field.set_meta("key", key)
		field.value_changed.connect(func(value): set_value(key, value))
		_fields.add_child(field)
	var id := String(current.technique)
	_number_field("消費スタミナ", float(rules.costs.get(id, 1.0)), func(value):
		history.create_action("技の消費を変更")
		history.add_do_method(_set_cost.bind(id, value))
		history.add_undo_method(_set_cost.bind(id, float(rules.costs.get(id, 1.0))))
		history.commit_action())
	_status.text = "数値を変更したら「変更を保存」、動きを確認するときは「保存して試遊」を押します。"

func _set_cost(id: String, value: float) -> void:
	rules.costs[id] = value
	dirty_rules = true

func _new_combo() -> void:
	var i := 1
	while rules.combos.has("combo_" + str(i)): i += 1
	var id := "combo_" + str(i)
	history.create_action("コンボを追加")
	history.add_do_method(_add_combo.bind(id))
	history.add_undo_method(_remove_combo.bind(id))
	history.commit_action()

func _add_combo(id: String) -> void:
	rules.combos[id] = {"type": "sequence", "children": []}
	rules.costs[id] = 2.0
	dirty_rules = true
	graph.show_rules(rules)
	_refresh_techniques()
	_picked("technique", id)

func _remove_combo(id: String) -> void:
	rules.combos.erase(id)
	rules.costs.erase(id)
	dirty_rules = true
	graph.show_rules(rules)
	_refresh_techniques()
	combo_editor.hide()

func _edit_custom(id: String) -> void:
	_last_combo_path.clear()
	_context(GRAPH.title_for(id) + " の実行内容", 0)
	combo_id = id
	editing_rules = true
	editing_flow = false
	combo_editor.path.clear()
	combo_editor.show()
	combo_editor.open(rules.combos[id], rules.techniques)
	_clear_fields()
	_status.text = id + "（コンボ全体で一回だけ消費）"
	_number_field("消費スタミナ", rules.costs.get(id, 2.0), func(value):
		history.create_action("コンボ消費を変更")
		history.add_do_method(_set_cost.bind(id, value))
		history.add_undo_method(_set_cost.bind(id, float(rules.costs.get(id, 2.0))))
		history.commit_action())

func rebuild_ui() -> void:
	# 見た目だけを作り直す。履歴は同じControlへ結び付いているため保持する。
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	var kept := {"rules": rules, "flow": flow, "current": current, "source_path": source_path, "saved": saved_version, "dirty_rules": dirty_rules, "dirty_flow": dirty_flow, "selected": _selected_technique}
	var embedded: Dictionary = _embedded_working.duplicate()
	var graph_clipboard: Array = graph.clipboard
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_fields = GridContainer.new()
	_status = Label.new()
	_path = LineEdit.new()
	graph = GRAPH.new()
	preview = preload("res://addons/boss_flow/range_preview.gd").new()
	flow_bar = TabBar.new()
	combo_editor = preload("res://addons/boss_flow/combo_graph.gd").new()
	_settings = OptionButton.new()
	_techniques = OptionButton.new()
	_heading = Label.new()
	_preview_frame = CenterContainer.new()
	_split = HSplitContainer.new()
	_file_dialog = FileDialog.new()
	_ready()
	rules = kept.rules
	flow = kept.flow
	current = kept.current
	source_path = kept.source_path
	saved_version = kept.saved
	dirty_rules = kept.dirty_rules
	dirty_flow = kept.dirty_flow
	_selected_technique = kept.selected
	_embedded_working = embedded
	graph.clipboard = graph_clipboard
	graph.show_rules(rules)
	_refresh_techniques()
	_refresh_flow()
	if rules.node_ids().has(_selected_technique): _picked("technique", _selected_technique)

func _exit_tree() -> void:
	history.clear_history()
	history.free()
	working.clear()
