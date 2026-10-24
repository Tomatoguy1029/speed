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
var flow_graph := preload("res://addons/boss_flow/flow_graph.gd").new()
var _selected_section := 0
var _coverage_group := ""
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
var _inspector_mode := 0
var _heading := Label.new()
var _preview_frame := CenterContainer.new()
var _split := HSplitContainer.new()
var _selected_technique := "bite_thrust"
var _last_combo_path: Array = []
var _probability_previous := ""
var _scale := 1.0
var _file_dialog := FileDialog.new()
const GRAPH := preload("res://addons/boss_flow/technique_graph.gd")
const PARAM_LABELS := {"warn": "予告（秒）", "active": "実行時間（秒）", "recover": "技後の待ち（秒）", "cd": "再使用待ち（秒）", "damage": "ダメージ", "distance": "移動距離", "reach": "届く長さ", "arc": "薙ぐ角度（rad）", "normal_charge": "予備動作（秒）", "normal_hold": "攻撃後の停止（秒）", "attack_cd": "技後の待ち（秒）", "normal_lunge": "踏み込み時間（秒）", "warning_time": "予告（秒）", "performance_time": "実行時間（秒）", "tech_recovery": "技後の全体待ち（秒）", "cooldown": "再使用待ち（秒）", "sweep_time": "薙ぎ時間（秒）", "sweep_reach": "薙ぎの長さ", "sweep_arc": "薙ぎの角度（rad）", "aim_tracking": "標的位置を追う時間（秒）"}

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	saved_version = history.get_version()
	_scale = maxf(1.0, float(get_theme_default_font_size()) / 14.0)
	add_theme_constant_override("separation", int(6 * _scale))
	for legacy in [_path]:
		add_child(legacy)
		legacy.hide()
	var toolbar := HFlowContainer.new()
	add_child(toolbar)
	var files := MenuButton.new()
	files.text = "ファイル"
	files.get_popup().add_item("技の設定ファイルを開く…")
	files.get_popup().id_pressed.connect(func(_id): _file_dialog.popup_centered_ratio(0.65))
	toolbar.add_child(files)
	var bosses := OptionButton.new()
	for title_text in ["うみへび座", "いっかくじゅう座"]: bosses.add_item(title_text)
	bosses.selected = 0 if "hydra" in rules_path else 1
	bosses.item_selected.connect(func(index):
		var id: String = ["hydra", "monoceros"][index]
		if open_boss("res://data/bosses/ai/" + id + "_action_rules.tres", "res://data/bosses/ai/" + id + "_flow.tres") != OK:
			bosses.selected = 0 if "hydra" in rules_path else 1)
	toolbar.add_child(bosses)
	for entry in [["変更を保存", save_current], ["保存して戦闘を試す", play_current], ["元に戻す", undo_edit], ["やり直す", redo_edit]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		toolbar.add_child(button)
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.tres ; 技の設定"])
	_file_dialog.file_selected.connect(open_technique)
	add_child(_file_dialog)
	var help := Label.new()
	help.text = "上：区間を選んで戦闘の流れを編集　下：技を選んで性能と発動条件を編集"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	flow = ResourceLoader.load(flow_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP).duplicate(true)
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_split)
	var workspace := VSplitContainer.new()
	workspace.name = "BattleAndTechniqueSplit"
	workspace.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(workspace)
	var flow_area := VBoxContainer.new()
	flow_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flow_area.size_flags_stretch_ratio = 0.35
	workspace.add_child(flow_area)
	var flow_tools := HFlowContainer.new()
	flow_area.add_child(flow_tools)
	var flow_label := Label.new()
	flow_label.text = "戦闘の区間"
	flow_tools.add_child(flow_label)
	var add_section := Button.new()
	add_section.text = "＋ 区間を追加"
	add_section.pressed.connect(_add_section)
	flow_tools.add_child(add_section)
	var align_sections := Button.new()
	align_sections.text = "区間を整列"
	align_sections.pressed.connect(func(): flow_graph.command("align"))
	flow_tools.add_child(align_sections)
	flow_area.add_child(flow_graph)
	flow_graph.picked.connect(_edit_section)
	flow_graph.shared_settings_requested.connect(_edit_common)
	flow_graph.edit_requested.connect(func(before, after, title_text):
		history.create_action(title_text)
		history.add_do_method(_set_flow_state.bind(after))
		history.add_undo_method(_set_flow_state.bind(before))
		history.commit_action())
	_refresh_flow()
	workspace.add_child(graph)
	graph.make_toolbar(_new_combo)
	graph.picked.connect(_picked)
	graph.play_requested.connect(play_technique)
	graph.edit_requested.connect(func(before, after, title_text):
		history.create_action(title_text)
		history.add_do_method(_set_graph_state.bind(after))
		history.add_undo_method(_set_graph_state.bind(before))
		history.commit_action())
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 300 * _scale
	details.size_flags_horizontal = Control.SIZE_FILL
	_split.add_child(details)
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(_preview_frame)
	_preview_frame.add_child(preview)
	preview.custom_minimum_size = Vector2(160, 160) * _scale
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
	set_meta("boss_layout_revision", 4)

func _set_flow_state(value: Dictionary) -> void:
	flow.sections = value.sections.duplicate(true)
	flow.layout = value.layout.duplicate(true)
	dirty_flow = true
	_refresh_flow()
	if _inspector_mode == 2: _edit_section(_selected_section, _probability_previous)

func _select_settings(index: int) -> void:
	combo_editor.hide()
	match index:
		0: _picked("technique", _selected_technique)
		1: _picked("condition", _selected_technique)
		2: _edit_section(_selected_section)
		3: _edit_common()
		4: _edit_forbidden()
		5: _edit_coverage(_coverage_group)

func _context(title_text: String, mode: int, show_preview := false) -> void:
	_heading.text = title_text
	_inspector_mode = mode
	_preview_frame.visible = show_preview

func _refresh_techniques() -> void:
	var ids: Array[String] = rules.node_ids()
	if not ids.has(_selected_technique) and not ids.is_empty(): _selected_technique = ids[0]

func _set_graph_state(value: Dictionary) -> void:
	var coverage := _inspector_mode == 5
	for key in value: rules.set(key, value[key].duplicate(true))
	dirty_rules = true
	graph.show_rules(rules)
	_refresh_techniques()
	if coverage: _edit_coverage(_coverage_group if rules.condition_groups.has(_coverage_group) else "")
	elif rules.node_ids().has(_selected_technique): _picked("condition" if _inspector_mode == 1 else "technique", _selected_technique)
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
		if focus != null and (focus == flow_graph or flow_graph.is_ancestor_of(focus)): flow_graph.command(action)
		elif focus != null and combo_editor.is_ancestor_of(focus): combo_editor.command(action)
		else: graph.command(action)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		if focus != null and (focus == flow_graph or flow_graph.is_ancestor_of(focus)): flow_graph.command("delete")
		elif focus != null and combo_editor.is_ancestor_of(focus): combo_editor.command("delete")
		else: graph.command("delete")
		get_viewport().set_input_as_handled()

func undo_edit() -> void:
	history.undo()
	_refresh_inspector()

func redo_edit() -> void:
	history.redo()
	_refresh_inspector()

func _refresh_inspector() -> void:
	if _inspector_mode == 0 and combo_editor.visible and rules.combos.has(combo_id):
		var step: Dictionary = rules.combos[combo_id]
		var valid := not _last_combo_path.is_empty()
		for index in _last_combo_path:
			if index < 0 or index >= step.get("children", []).size():
				valid = false
				break
			step = step.children[index]
		if valid: _edit_combo_step(_last_combo_path.duplicate())
		else: _edit_custom(combo_id)
	elif _inspector_mode == 2: _edit_section(_selected_section, _probability_previous)
	else: _select_settings(_inspector_mode)

func _load_rules() -> void:
	_embedded_working.clear()
	if ResourceLoader.exists(rules_path):
		rules = ResourceLoader.load(rules_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP).duplicate(false)
		rules.conditions = rules.conditions.duplicate(true)
		rules.techniques = rules.techniques.duplicate()
		rules.combos = rules.combos.duplicate(true)
		rules.costs = rules.costs.duplicate(true)
		rules.layout = rules.layout.duplicate(true)
		rules.condition_groups = rules.condition_groups.duplicate(true)
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
	_picked("technique", _selected_technique)
	_status.text = "ボスの技定義と戦闘フローを開きました"
	return OK

func _is_hydra() -> bool: return rules.adapter == &"hydra" or "hydra_action_rules" in rules_path

func _picked(kind: String, id: String) -> void:
	if not id.is_empty() and kind != "coverage":
		_selected_technique = id
	editing_flow = false
	combo_editor.hide()
	if kind == "coverage":
		_edit_coverage(id)
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
	elif kind == "condition":
		preview.attack = {}
		for move in rules.techniques:
			if String(move.technique) == rules.source_for(id): preview.set_attack(move, "hydra" if _is_hydra() else String(rules.adapter))
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
	for node in graph.get_children():
		if node is GraphNode and String(node.name) == id:
			var diagram = node.get_child(0)
			diagram.gate = rules.conditions[id]
			diagram.queue_redraw()

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
	if target == current:
		preview.set_attack(current, "hydra" if _is_hydra() else String(rules.adapter))
	for node in graph.get_children():
		if node is GraphNode and not String(node.name).begins_with("choose_") and rules.source_for(String(node.name)) == String(target.technique):
			node.get_child(0).set_attack(target, "hydra" if _is_hydra() else String(rules.adapter))
	_status.text = "変更があります。「変更を保存」で確定できます。"
	for node in _fields.get_children():
		if target == current and node is SpinBox and node.get_meta("key", "") == key:
			node.set_value_no_signal(float(value))

func save_current() -> Error:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
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
	_selected_section = clampi(_selected_section, 0, maxi(0, flow.sections.size() - 1))
	flow_graph.show_flow(flow)

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
	_selected_section = i
	combo_editor.hide()
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
	_append_forbidden(i)
	_append_section_techniques(i)

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
	_edit_section(_selected_section)

func _append_forbidden(index: int) -> void:
	var heading := Label.new()
	heading.text = "同時攻撃の禁止"
	_fields.add_child(heading)
	_fields.add_child(Control.new())
	for pair in flow.sections[index].get("forbidden", []):
		var label := Label.new()
		label.text = "%s × %s" % [GRAPH.title_for(pair[0]), GRAPH.title_for(pair[1])]
		_fields.add_child(label)
		var remove := Button.new()
		remove.text = "この禁止ペアを削除"
		remove.pressed.connect(func():
			var copy: Array = flow.sections[index].get("forbidden", []).duplicate(true)
			copy.erase(pair)
			_set_section_forbidden(index, copy))
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
		var copy: Array = flow.sections[index].get("forbidden", []).duplicate(true)
		if not copy.has(pair): copy.append(pair)
		_set_section_forbidden(index, copy))
	_fields.add_child(add)
	_fields.add_child(Control.new())

func _set_section_forbidden(index: int, pairs: Array) -> void:
	_section_property(index, "forbidden", pairs.duplicate(true))
	_edit_section(index)

func _append_section_techniques(index: int) -> void:
	var all := CheckBox.new()
	all.text = "全技を候補にする"
	all.button_pressed = not flow.sections[index].has("allowed_techniques")
	_fields.add_child(all)
	_fields.add_child(Control.new())
	var label := Label.new()
	label.text = "この区間で使える技"
	_fields.add_child(label)
	var choices := Tree.new()
	choices.hide_root = true
	choices.custom_minimum_size = Vector2(160, 170) * _scale
	var root := choices.create_item()
	var allowed: Array = flow.sections[index].get("allowed_techniques", [])
	var groups := {}
	for id in rules.node_ids():
		var source: String = rules.source_for(id)
		if groups.has(source): continue
		groups[source] = true
		var item := choices.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_text(0, GRAPH.title_for(source))
		item.set_metadata(0, source)
		item.set_editable(0, not all.button_pressed)
		item.set_checked(0, all.button_pressed or source in allowed)
	_fields.add_child(choices)
	all.toggled.connect(func(value): _set_section_techniques(index, value, groups.keys()))
	choices.item_edited.connect(func():
		var selected: Array = []
		for item in root.get_children():
			if item.is_checked(0): selected.append(item.get_metadata(0))
		_set_section_techniques(index, false, selected))

func _set_section_techniques(index: int, all: bool, ids: Array) -> void:
	var copy: Array = flow.sections.duplicate(true)
	if all: copy[index].erase("allowed_techniques")
	else: copy[index].allowed_techniques = ids.duplicate()
	history.create_action("区間の候補技を変更")
	history.add_do_method(_set_sections.bind(copy))
	history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
	history.commit_action()
	_edit_section(index)

func _edit_coverage(group := "") -> void:
	_coverage_group = group
	var selection: Dictionary = rules.condition_groups.get(group, {})
	_context(selection.get("title", "全技") + " · 条件のカバー", 5, true)
	_clear_fields()
	var purpose := Label.new()
	purpose.text = "このノードにつなぐ技をまとめます。距離・方向の発動条件は、各技を選んで編集します。"
	purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	purpose.custom_minimum_size.x = 160 * _scale
	_fields.add_child(purpose)
	_fields.add_child(Control.new())
	if not selection.is_empty():
		var label := Label.new()
		label.text = "条件選択の名前"
		_fields.add_child(label)
		var name_field := LineEdit.new()
		name_field.text = selection.title
		var original_name: String = selection.title
		name_field.text_submitted.connect(func(value): _rename_group(group, value, original_name))
		name_field.focus_exited.connect(func(): _rename_group(group, name_field.text, original_name))
		_fields.add_child(name_field)
		var members_label := Label.new()
		members_label.text = "候補にする技\nチェックで有効／無効"
		_fields.add_child(members_label)
		var members := VBoxContainer.new()
		_fields.add_child(members)
		for id in rules.node_ids():
			if graph.hub_for(id) != group: continue
			var enabled := CheckBox.new()
			enabled.text = GRAPH.node_title(rules, id)
			enabled.button_pressed = rules.graph_nodes.get(id, {}).get("connected", true)
			enabled.toggled.connect(func(value): graph._connect(id, value))
			members.add_child(enabled)
		var move_label := Label.new()
		move_label.text = "技をここへ移す"
		_fields.add_child(move_label)
		var choices := OptionButton.new()
		choices.fit_to_longest_item = false
		choices.add_item("移す技を選ぶ…")
		for id in rules.node_ids():
			if graph.hub_for(id) == group: continue
			choices.add_item(GRAPH.node_title(rules, id))
			choices.set_item_metadata(choices.item_count - 1, id)
		choices.item_selected.connect(func(index):
			if index > 0: graph.assign_group(choices.get_item_metadata(index), group))
		_fields.add_child(choices)
	var simulation := CheckBox.new()
	simulation.text = "範囲図の確認条件"
	_fields.add_child(simulation)
	_fields.add_child(Control.new())
	var preview_start := _fields.get_child_count()
	var explanation := Label.new()
	explanation.text = "以下は範囲図だけに使う仮の状況です。戦闘のスタミナ・首の数・発動条件は変更しません。"
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.custom_minimum_size.x = 160 * _scale
	_fields.add_child(explanation)
	_fields.add_child(Control.new())
	var separated := CheckButton.new()
	separated.text = "分離した状態で確認"
	separated.button_pressed = preview_separated
	separated.toggled.connect(func(value): preview_separated = value; _analyze_coverage())
	if _is_hydra():
		_fields.add_child(separated)
		_fields.add_child(Control.new())
	else: separated.free()
	_number_field("仮の残りスタミナ", preview_stamina, func(value): preview_stamina = value; _analyze_coverage())
	_number_field("範囲図に表示する距離", preview_radius, func(value): preview_radius = value; _analyze_coverage(), 1.0)
	for kind in preview_heads:
		if _is_hydra():
			var field := _number_field("仮の" + {"bite": "噛みつき", "vortex": "渦", "debris": "瓦礫", "beam": "ビーム", "thunder": "雷"}[kind] + "首（本）", preview_heads[kind], func(value): preview_heads[kind] = int(value); _analyze_coverage(), 0.0, 2.0)
			field.step = 1.0
	var preview_fields := _fields.get_children().slice(preview_start)
	for field in preview_fields: field.hide()
	simulation.toggled.connect(func(expanded):
		for field in preview_fields: field.visible = expanded)
	_analyze_coverage()

func _rename_group(group: String, text: String, original_name: String) -> void:
	if not rules.condition_groups.has(group) or rules.condition_groups[group].title != original_name or text.strip_edges().is_empty() or original_name == text.strip_edges(): return
	var before: Dictionary = graph.snapshot()
	var after: Dictionary = graph.snapshot()
	after.condition_groups[group].title = text.strip_edges()
	history.create_action("条件選択の名前を変更")
	history.add_do_method(_set_graph_state.bind(after))
	history.add_undo_method(_set_graph_state.bind(before))
	history.commit_action()

func _coverage_gates(id: String) -> Array:
	if _coverage_group.is_empty(): return rules.active_gates_for(id)
	var gates: Array = []
	for node in rules.node_ids():
		if rules.source_for(node) == id and graph.hub_for(node) == _coverage_group and rules.graph_nodes.get(node, {}).get("connected", true): gates.append(rules.conditions.get(node, {}))
	return gates

func _analyze_coverage() -> void:
	preview.coverage_mode = true
	if not _is_hydra():
		var layers: Array = []
		for move in rules.techniques:
			if float(rules.costs.get(String(move.technique), 1.0)) <= preview_stamina:
				for condition in _coverage_gates(String(move.technique)):
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
		for condition in _coverage_gates(String(move.technique)):
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

func play_technique(id: String) -> void:
	_prepare_trial(rules.source_for(id))

func play_current() -> void:
	_prepare_trial("")

func _prepare_trial(id: String) -> void:
	var scene := preview_scene()
	if scene.is_empty() or not ResourceLoader.exists(scene):
		_status.text = "このボスには試遊シーンが設定されていません。"
		return
	if save_current() != OK: return
	var result = preload("res://tools/content/build_boss_program.gd").compile({"rules": rules, "flow": flow}, "res://.content/boss_preview.tres")
	if result.error != OK:
		_status.text = "生成失敗: " + "; ".join(result.get("errors", [error_string(result.error)]))
		return
	var config := FileAccess.open("res://.content/boss_preview.json", FileAccess.WRITE)
	config.store_string(JSON.stringify({"boss": "hydra" if _is_hydra() else String(rules.adapter), "technique": id}))
	config.close()
	if Engine.is_editor_hint(): EditorInterface.play_custom_scene(scene)

func _append_gate(id: String) -> void:
	var heading := Label.new()
	heading.text = "この技へ進む条件"
	_fields.add_child(heading)
	_fields.add_child(Control.new())
	var gate: Dictionary = {"min": 0.0, "max": 600.0, "angle": 0.0, "half_angle": 180.0}.merged(rules.conditions.get(id, {}), true)
	rules.conditions[id] = gate
	for key in ["min", "max", "angle", "half_angle"]:
		_number_field({"min": "最小距離", "max": "最大距離", "angle": "中心角度（度）", "half_angle": "半角（度）"}[key], float(gate[key]), func(value):
			history.create_action("発動条件を変更")
			history.add_do_method(_set_gate.bind(id, key, value))
			history.add_undo_method(_set_gate.bind(id, key, gate[key]))
			history.commit_action(), -180.0 if key == "angle" else 0.0, 180.0 if "angle" in key else 100000.0)

func _refresh() -> void:
	_context(GRAPH.title_for(String(current.technique)) + " · 技の性能と発動条件", 0, true)
	preview.coverage_mode = false
	preview.gate = rules.conditions.get(_selected_technique, {})
	preview.set_attack(current, "hydra" if _is_hydra() else String(rules.adapter))
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
	_append_gate(_selected_technique)
	_status.text = "青：発動条件　橙：基準の射程。動的な照準・配置は実験場で確認できます。"

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
	_context(GRAPH.title_for(id) + " の実行内容", 0, true)
	preview.coverage_mode = false
	preview.gate = rules.conditions.get(id, {})
	preview.attack = {"dynamic": true}
	preview.queue_redraw()
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
	_append_gate(id)

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
	flow_graph = preload("res://addons/boss_flow/flow_graph.gd").new()
	combo_editor = preload("res://addons/boss_flow/combo_graph.gd").new()
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
