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
var graph := preload("res://tools/editor/boss_flow/technique_graph.gd").new()
var preview := preload("res://tools/editor/boss_flow/range_preview.gd").new()
var editing_rules := false
var flow: Resource
var flow_path := "res://data/bosses/ai/hydra_flow.tres"
var flow_graph := preload("res://tools/editor/boss_flow/flow_graph.gd").new()
var _selected_section := 0
var _coverage_group := ""
var editing_flow := false
var combo_editor := preload("res://tools/editor/boss_flow/combo_graph.gd").new()
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
var _parallel_toggle := CheckButton.new()
const GRAPH := preload("res://tools/editor/boss_flow/technique_graph.gd")
const SPIRAL_FIELDS := preload("res://tools/editor/boss_flow/technique_fields.gd")
const SPIRAL_LABELS := SPIRAL_FIELDS.SPIRAL_LABELS
const SPIRAL_TIPS := SPIRAL_FIELDS.SPIRAL_TIPS
const SPIRAL_BOUNDS := SPIRAL_FIELDS.SPIRAL_BOUNDS
const BOSS_IDS := ["hydra", "monoceros", "draco", "centaurus", "canis_major"]
const BOSS_TITLES := {"hydra": "うみへび座", "monoceros": "いっかくじゅう座", "draco": "りゅう座", "centaurus": "ケンタウルス座", "canis_major": "おおいぬ座"}
var _ordered_boss_ids: Array[String] = []
var _boss_selector: OptionButton
var _detail_scroll: ScrollContainer
var _expanded_section_categories: Dictionary = {}
const PARAM_LABELS := SPIRAL_FIELDS.PARAM_LABELS

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
	_boss_selector = bosses
	_ordered_boss_ids.clear()
	for entry in _boss_entries():
		_ordered_boss_ids.append(entry.id)
		bosses.add_item(entry.title)
	bosses.selected = _boss_index()
	bosses.item_selected.connect(func(index):
		var id: String = _ordered_boss_ids[index]
		if open_boss("res://data/bosses/ai/" + id + "_action_rules.tres", "res://data/bosses/ai/" + id + "_flow.tres") != OK:
			bosses.selected = _boss_index())
	toolbar.add_child(bosses)
	var add_technique := Button.new()
	add_technique.text = "＋ 技を追加"
	add_technique.pressed.connect(_show_add_technique)
	toolbar.add_child(add_technique)
	_parallel_toggle.text = "同時攻撃あり"
	_parallel_toggle.tooltip_text = "複数の通常技を同時に選ぶ。OFFは未登録扱い。コンボ内部の並列実行とは別。"
	_parallel_toggle.toggled.connect(_change_parallel)
	toolbar.add_child(_parallel_toggle)
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
	var add_rest := Button.new()
	add_rest.text = "＋ 休息を追加"
	add_rest.tooltip_text = "攻撃せずに休む区間を最後に足します。休む時間は「スタミナ・休息」で全区間共通に決めます。"
	add_rest.pressed.connect(_add_rest)
	flow_tools.add_child(add_rest)
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
		var flow_before: Array = flow.sections.duplicate(true)
		var flow_after: Array = flow.sections.duplicate(true)
		for section in flow_after:
			if not section.has("allowed_groups"): continue
			section.allowed_groups = section.allowed_groups.filter(func(group): return after.condition_groups.has(String(group)))
		history.create_action(title_text)
		history.add_do_method(_set_graph_state.bind(after))
		history.add_undo_method(_set_graph_state.bind(before))
		if flow_before != flow_after:
			history.add_do_method(_set_sections.bind(flow_after))
			history.add_undo_method(_set_sections.bind(flow_before))
		history.commit_action())
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = maxf(320.0, 205.0 * _scale)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(details)
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_heading)
	var scroll := ScrollContainer.new()
	_detail_scroll = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.resized.connect(_refresh_field_columns)
	details.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(_preview_frame)
	_preview_frame.add_child(preview)
	preview.split = true
	preview.custom_minimum_size = Vector2(160.0 * 2.0 * _scale + preview.SPLIT_GAP, 160.0 * _scale)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fields.columns = 1
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
	_heading.tooltip_text = ""
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
	_parallel_toggle.set_pressed_no_signal(rules.allow_parallel_attacks)
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
	if _boss_selector != null: _boss_selector.selected = _boss_index()
	return OK

func _boss_index() -> int:
	for i in _ordered_boss_ids.size():
		if _ordered_boss_ids[i] + "_action_rules" in rules_path: return i
	return 0

func _boss_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen := {}
	for number in range(1, 6):
		var path := "res://data/stages/stage_%d.tres" % number
		if not ResourceLoader.exists(path): continue
		var stage: Resource = ResourceLoader.load(path)
		if stage == null: continue
		var id := String(stage.boss_id)
		if id not in BOSS_IDS or seen.has(id): continue
		entries.append({"id": id, "title": "ステージ%d · %s" % [number, BOSS_TITLES[id]]})
		seen[id] = true
	for id in BOSS_IDS:
		if not seen.has(id): entries.append({"id": id, "title": "未配置 · " + BOSS_TITLES[id]})
	return entries

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
		_context(GRAPH.technique_title(rules, rules.source_for(id)) + " の発動条件", 1, true)
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
			field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_heading.text = GRAPH.technique_title(rules, combo_id) + " / " + {"wait": "待機", "action": "実行する技", "branch": "条件分岐", "sequence": "順番に実行", "parallel": "同時に実行"}.get(step.get("type", ""), "要素") + "の設定"
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
			choices.add_item(GRAPH.technique_title(rules, String(move.technique)))
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
	if current == null or not current.has_field(key): return
	var old: Variant = current.field(key)
	var next: Variant = int(value) if old is int else value
	if old == next: return
	history.create_action("技の " + key + " を変更")
	history.add_do_method(_assign.bind(current, key, next))
	history.add_undo_method(_assign.bind(current, key, old))
	history.commit_action()

func _assign(target: Resource, key: String, value: Variant) -> void:
	target.set_field(key, value)
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

func _set_post_gap(value: float) -> void:
	if current == null or is_equal_approx(current.post_gap, value): return
	history.create_action("技後の隙を変更")
	history.add_do_method(_assign_post_gap.bind(current, value))
	history.add_undo_method(_assign_post_gap.bind(current, current.post_gap))
	history.commit_action()

func _assign_post_gap(target: Resource, value: float) -> void:
	target.post_gap = value
	if not working.values().has(target): dirty_rules = true
	else:
		for path in working:
			if working[path] == target: _dirty_working[path] = true
	target.emit_changed()

## 技の欄の「タイミング」にまとめる値。この順で並べる。
const TIMING_KEYS := ["warn", "exit_duration", "coil_time", "pause", "shrink_time", "active", "hold", "return_speed", "recover", "cd", "touch_invuln"]

func _set_tracking(enabled: bool) -> void:
	if current == null or current.track_during_warn == enabled: return
	history.create_action("予告中の追尾を変更")
	history.add_do_method(_assign_tracking.bind(current, enabled))
	history.add_undo_method(_assign_tracking.bind(current, current.track_during_warn))
	history.commit_action()

func _assign_tracking(target: Resource, enabled: bool) -> void:
	target.track_during_warn = enabled
	if not working.values().has(target): dirty_rules = true
	else:
		for path in working:
			if working[path] == target: _dirty_working[path] = true
	target.emit_changed()
	if target == current: _refresh()

func _change_parallel(enabled: bool) -> void:
	if rules == null or rules.allow_parallel_attacks == enabled: return
	history.create_action("同時攻撃の有無を変更")
	history.add_do_method(_apply_parallel.bind(enabled))
	history.add_undo_method(_apply_parallel.bind(rules.allow_parallel_attacks))
	history.commit_action()

func _apply_parallel(enabled: bool) -> void:
	rules.allow_parallel_attacks = enabled
	dirty_rules = true
	_parallel_toggle.set_pressed_no_signal(enabled)
	if _inspector_mode == 2: _edit_section(_selected_section, _probability_previous)

func save_current() -> Error:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	for path in _dirty_working:
		if FileAccess.get_sha256(path) != _source_hashes.get(path, ""):
			_status.text = "外部で技の設定が変わっています。変更を保護するため保存を止めました: " + path
			return ERR_BUSY
		var move: Resource = working[path]
		var disk := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if disk == null or disk.values() != move.values() or not is_equal_approx(disk.post_gap, move.post_gap) or disk.track_during_warn != move.track_during_warn or disk.display_name != move.display_name or disk.visual != move.visual:
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
	call_deferred("_refresh_field_columns")

func _refresh_field_columns() -> void:
	if _detail_scroll == null or _fields == null: return
	# 欄は「名前・入力欄」の組で並べる。数が合わなければ、組の崩れた部品を足した箇所がある。
	if OS.is_debug_build() and _fields.get_child_count() % 2 != 0: push_warning("ボスAIの欄の数が奇数です。1マスだけの部品は _full_row で足してください。")
	var narrow := _detail_scroll.size.x < maxf(500.0, 320.0 * _scale)
	_fields.columns = 1 if narrow else 2
	# 発動条件と攻撃範囲の2枚が並ぶ幅を、詳細欄の幅に収める。
	var side := clampf((_detail_scroll.size.x - 16.0 - preview.SPLIT_GAP) * 0.5, 80.0 * _scale, 160.0 * _scale)
	preview.custom_minimum_size = Vector2(side * 2.0 + preview.SPLIT_GAP, side)
	for child in _fields.get_children():
		if child.get_class() == "Control" or child.get_meta("hide_when_narrow", false):
			child.visible = not narrow

func _refresh_flow() -> void:
	_selected_section = clampi(_selected_section, 0, maxi(0, flow.sections.size() - 1))
	flow_graph.show_flow(flow)

func _add_section() -> void:
	var copy: Array = flow.sections.duplicate(true)
	if not copy.is_empty() and copy[-1].get("next", 0) == 0: copy[-1].next = copy.size()
	var weights := {"single": 60.0, "parallel": 25.0, "combo": 15.0} if rules.allow_parallel_attacks else {"single": 85.0, "combo": 15.0}
	copy.append({"name": "区間" + str(copy.size() + 1), "request": "any", "allowed_categories": ["normal", "combo"], "action_count": 1, "action_interval": 0.0, "no_candidate_timeout": 0.5, "weights": weights, "next": 0})
	history.create_action("区間を追加")
	history.add_do_method(_set_sections.bind(copy))
	history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
	history.commit_action()
	_edit_section(copy.size() - 1)

func _add_rest() -> void:
	var copy: Array = flow.sections.duplicate(true)
	if not copy.is_empty() and copy[-1].get("next", 0) == 0: copy[-1].next = copy.size()
	copy.append({"name": "休息" + str(copy.size() + 1), "request": "rest", "next": 0})
	history.create_action("休息を追加")
	history.add_do_method(_set_sections.bind(copy))
	history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
	history.commit_action()
	_edit_section(copy.size() - 1)

## 区間を休息と攻撃の区間で切り替える。攻撃の設定は残し、戻したときに使う。
func _set_section_rest(i: int, rest: bool) -> void:
	var copy: Array = flow.sections.duplicate(true)
	if rest: copy[i].request = "rest"
	else:
		copy[i].request = "any"
		for key in ["allowed_categories", "action_count", "action_interval", "no_candidate_timeout", "weights"]:
			if not copy[i].has(key): copy[i][key] = {"allowed_categories": ["normal", "combo"], "action_count": 1, "action_interval": 0.0, "no_candidate_timeout": 0.5, "weights": {"single": 85.0, "combo": 15.0}}[key]
	history.create_action("休息の切り替え")
	history.add_do_method(_set_sections.bind(copy))
	history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
	history.commit_action()
	_edit_section(i)

func _set_sections(value: Array) -> void:
	dirty_flow = true
	flow.sections = value.duplicate(true)
	_refresh_flow()

func _edit_section(i: int, previous := "") -> void:
	_selected_section = i
	combo_editor.hide()
	_probability_previous = ""
	_context(flow.sections[i].get("name", "区間") + " の設定", 2)
	editing_flow = true
	_clear_fields()
	_status.text = ""
	_section_heading("進行")
	for key in ["name"]:
		var label := Label.new()
		label.text = "区間名"
		_fields.add_child(label)
		var field := LineEdit.new()
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var resting := CheckBox.new()
	resting.text = "休息の区間にする"
	resting.tooltip_text = "ONでは攻撃せず、「スタミナ・休息」で決めた時間だけ休んでから次の区間へ進みます。"
	resting.button_pressed = flow.sections[i].get("request", "normal") == "rest"
	resting.toggled.connect(func(value): _set_section_rest(i, value))
	_fields.add_child(resting)
	_fields.add_child(Control.new())
	if resting.button_pressed:
		var rest := Label.new()
		rest.text = "休息して次へ"
		_fields.add_child(rest)
		_fields.add_child(Control.new())
		return
	var count_field := _number_field("攻撃回数", float(flow.sections[i].get("action_count", 1)), func(value): _section_property(i, "action_count", int(value)), 1.0)
	count_field.step = 1.0
	count_field.rounded = true
	_number_field("攻撃間隔（秒）", float(flow.sections[i].get("action_interval", 0.0)), func(value): _section_property(i, "action_interval", value))
	_optional_section_number(i, "no_candidate_timeout", "候補なしで次へ（秒）", 0.5, 0.0)
	_section_heading("攻撃選択")
	_append_section_targets(i)
	_section_heading("選択確率")
	var weights: Dictionary = flow.sections[i].get("weights", {})
	var visible_categories: Array = _section_categories(i)
	for key in ["single", "parallel", "combo", "major"]:
		if key == "parallel" and (not rules.allow_parallel_attacks or "normal" not in visible_categories): continue
		if key != "parallel" and not ({"single": "normal", "combo": "combo", "major": "major"}[key] in visible_categories): continue
		var chance := _number_field({"single": "通常技の確率", "parallel": "同時攻撃の確率", "combo": "コンボ技の確率", "major": "大技の確率"}[key], float(weights.get(key, 0.0)), func(value): _section_weight(i, key, value))
		chance.tooltip_text = "成立した分類の値を合計した中での相対的な選択確率です。候補がない分類は除きます。"
	var avoid := CheckButton.new()
	avoid.text = "連発を抑える"
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
	_section_heading("スタミナ")
	_optional_section_number(i, "section_budget", "この区間で使える力", float(flow.maximum_stamina), 0.1)
	if rules.allow_parallel_attacks and "normal" in visible_categories:
		_section_heading("同時攻撃")
		_append_forbidden(i)

func _section_heading(title_text: String) -> void:
	_section_divider()
	var label := Label.new()
	label.text = title_text
	_fields.add_child(label)
	_fields.add_child(Control.new())

## 2列の欄で1行を使う部品。隣の入力欄の位置を空けて、後ろの欄をずらさない。
func _full_row(control: Control) -> void:
	_fields.add_child(control)
	_fields.add_child(Control.new())

func _section_divider() -> void:
	_fields.add_child(HSeparator.new())
	var second := HSeparator.new()
	second.set_meta("hide_when_narrow", true)
	_fields.add_child(second)

func _number_field(title_text: String, value: float, changed: Callable, minimum := 0.0, maximum := 100000.0) -> SpinBox:
	var label := Label.new()
	label.text = title_text
	_fields.add_child(label)
	var field := SpinBox.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.min_value = minimum
	field.max_value = maximum
	field.step = 0.1
	field.value = value
	field.value_changed.connect(changed)
	_fields.add_child(field)
	return field

func _optional_section_number(index: int, key: String, title_text: String, default_value: float, minimum: float) -> void:
	var enabled := CheckButton.new()
	enabled.text = title_text
	enabled.button_pressed = flow.sections[index].has(key)
	_fields.add_child(enabled)
	var field := SpinBox.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.min_value = minimum
	field.max_value = 100000.0
	field.step = 0.1
	field.value = float(flow.sections[index].get(key, default_value))
	field.value_changed.connect(func(value): _section_property(index, key, value))
	_fields.add_child(field)
	field.editable = enabled.button_pressed
	enabled.toggled.connect(func(value):
		field.editable = value
		_set_optional_section_property(index, key, value, field.value))

func _set_optional_section_property(index: int, key: String, enabled: bool, value: float) -> void:
	if flow.sections[index].has(key) == enabled: return
	var copy: Array = flow.sections.duplicate(true)
	if enabled: copy[index][key] = value
	else: copy[index].erase(key)
	history.create_action("区間の待機・予算を変更")
	history.add_do_method(_set_sections.bind(copy))
	history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
	history.commit_action()

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

func _section_categories(index: int) -> Array:
	var section: Dictionary = flow.sections[index]
	if not section.has("allowed_groups") and not section.has("allowed_categories"):
		return ["major"] if section.get("request", "normal") == "major" else ["normal", "combo"] if section.get("request", "normal") == "normal" else ["normal", "combo", "major"]
	var kinds: Array = section.get("allowed_categories", []).duplicate()
	for group in section.get("allowed_groups", []):
		var kind: String = rules.category_for_group(String(group))
		if not kind.is_empty() and kind not in kinds: kinds.append(kind)
	return kinds

func _effective_groups(section: Dictionary) -> Array:
	if section.get("request") == "rest": return []
	var selected: Array = section.get("allowed_groups", []).duplicate()
	var categories: Array = section.get("allowed_categories", [])
	if not section.has("allowed_groups") and not section.has("allowed_categories"):
		categories = ["major"] if section.get("request", "normal") == "major" else ["normal", "combo"] if section.get("request", "normal") == "normal" else ["normal", "combo", "major"]
	for group in rules.condition_groups:
		if rules.category_for_group(String(group)) in categories and group not in selected: selected.append(group)
	return selected

func _append_section_targets(index: int) -> void:
	var heading := Label.new()
	heading.text = "条件選択ノード"
	heading.tooltip_text = "この区間で使う条件選択ノードを個別に選びます。"
	_fields.add_child(heading)
	var section: Dictionary = flow.sections[index]
	var attached: Array = _effective_groups(section)
	var targets := PanelContainer.new()
	targets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets.tooltip_text = heading.tooltip_text
	var target_list := VBoxContainer.new()
	target_list.add_theme_constant_override("separation", int(3 * _scale))
	targets.add_child(target_list)
	for kind in ["normal", "combo", "major"]:
		var all_in_kind: Array = rules.condition_groups.keys().filter(func(group): return rules.category_for_group(String(group)) == kind)
		if all_in_kind.is_empty(): continue
		var rows := _append_collapsible_category(target_list, index, "targets", kind, all_in_kind.size())
		for group in rules.condition_groups:
			if rules.category_for_group(String(group)) != kind: continue
			_append_selection_row(rows, String(rules.condition_groups[group].get("title", group)), group in attached, false, func(value): _set_section_target(index, String(group), false, value))
	_fields.add_child(targets)
	_section_divider()
	var exclude := Label.new()
	exclude.text = "使わない技"
	exclude.tooltip_text = "選んだ技は、接続ノードで成立してもこの区間では使用しません。"
	_fields.add_child(exclude)
	var exclusions := PanelContainer.new()
	exclusions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var exclusion_list := VBoxContainer.new()
	exclusion_list.add_theme_constant_override("separation", int(3 * _scale))
	exclusions.add_child(exclusion_list)
	var technique_ids: Array = []
	for id in rules.node_ids():
		if rules.source_for(id) != id: continue
		technique_ids.append(id)
	for kind in ["normal", "combo", "major", "other"]:
		var in_kind: Array = technique_ids.filter(func(id): return kind in _section_technique_categories(String(id)))
		if in_kind.is_empty(): continue
		var rows := _append_collapsible_category(exclusion_list, index, "exclusions", kind, in_kind.size())
		for id in in_kind:
			var excluded: bool = id in section.get("excluded_techniques", []) or section.has("allowed_techniques") and id not in section.allowed_techniques
			_append_selection_row(rows, GRAPH.technique_title(rules, id), excluded, false, func(value): _set_section_exclusion(index, id, value))
	_fields.add_child(exclusions)

func _section_technique_categories(id: String) -> Array:
	var kinds: Array = []
	for entry in rules.active_gate_entries_for(id):
		var kind := String(entry.category)
		if kind in ["normal", "combo", "major"] and kind not in kinds: kinds.append(kind)
	if not kinds.is_empty(): return kinds
	if rules.combos.has(id): return ["combo"]
	for move in rules.techniques:
		if String(move.technique) == id:
			var kind := "normal" if move.category == &"single" else String(move.category)
			return [kind if kind in ["normal", "combo", "major"] else "other"]
	return ["other"]

func _append_collapsible_category(parent: VBoxContainer, index: int, list_kind: String, kind: String, count: int) -> VBoxContainer:
	if parent.get_child_count() > 0: parent.add_child(HSeparator.new())
	var category := VBoxContainer.new()
	category.name = list_kind + "_" + kind
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(category)
	var state_key := "%s:%d:%s:%s" % [rules_path, index, list_kind, kind]
	var expanded: bool = _expanded_section_categories.get(state_key, true)
	var header := Button.new()
	header.name = "Header"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.toggle_mode = true
	header.button_pressed = expanded
	var title_text: String = {"normal": "通常技", "combo": "コンボ技", "major": "大技", "other": "未分類"}[kind]
	header.text = ("▾ " if expanded else "▸ ") + title_text + "（%d）" % count
	category.add_child(header)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.visible = expanded
	category.add_child(rows)
	header.toggled.connect(func(value):
		_expanded_section_categories[state_key] = value
		rows.visible = value
		header.text = ("▾ " if value else "▸ ") + title_text + "（%d）" % count)
	return rows

func _append_selection_row(parent: VBoxContainer, title_text: String, checked: bool, disabled: bool, changed: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var choice := CheckBox.new()
	choice.button_pressed = checked
	choice.disabled = disabled
	choice.tooltip_text = title_text
	choice.toggled.connect(changed)
	row.add_child(choice)
	var title := Label.new()
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

func _set_section_target(index: int, id: String, by_category: bool, enabled: bool) -> void:
	var copy: Array = flow.sections.duplicate(true)
	var section: Dictionary = copy[index]
	var groups: Array = _effective_groups(section)
	var targets: Array = rules.condition_groups.keys().filter(func(group): return rules.category_for_group(String(group)) == id) if by_category else [id]
	for group in targets:
		if enabled and group not in groups: groups.append(group)
		if not enabled: groups.erase(group)
	section.allowed_groups = groups
	section.erase("allowed_categories")
	_migrate_section_whitelist(section)
	section.request = "any"
	_set_sections_edit(index, copy, "区間の条件選択を変更")

func _set_section_exclusion(index: int, id: String, excluded: bool) -> void:
	var copy: Array = flow.sections.duplicate(true)
	var section: Dictionary = copy[index]
	_migrate_section_whitelist(section)
	var ids: Array = section.get("excluded_techniques", []).duplicate()
	if excluded and id not in ids: ids.append(id)
	if not excluded: ids.erase(id)
	section.excluded_techniques = ids
	_set_sections_edit(index, copy, "区間で使わない技を変更")

func _migrate_section_whitelist(section: Dictionary) -> void:
	if not section.has("allowed_techniques"): return
	var denied: Array = section.get("excluded_techniques", []).duplicate()
	for id in rules.node_ids():
		var source: String = rules.source_for(id)
		if source not in section.allowed_techniques and source not in denied: denied.append(source)
	section.excluded_techniques = denied
	section.erase("allowed_techniques")

func _set_sections_edit(index: int, copy: Array, title_text: String) -> void:
	history.create_action(title_text)
	history.add_do_method(_set_sections.bind(copy))
	history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
	history.commit_action()
	_edit_section(index)

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
	var presentation := Button.new()
	presentation.text = "ボスの表示を開く"
	presentation.pressed.connect(func(): preload("res://tools/editor/boss_flow/technique_visual_fields.gd").open_scene(self, "res://scenes/bosses/" + String(rules.adapter) + "_presentation.tscn"))
	_full_row(presentation)
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
	heading.text = "禁止する組合せ"
	_fields.add_child(heading)
	_fields.add_child(Control.new())
	if not rules.allow_parallel_attacks:
		var off := Label.new()
		off.text = "登録なし"
		_fields.add_child(off)
		_fields.add_child(Control.new())
		return
	if flow.sections[index].get("forbidden", []).is_empty():
		var empty := Label.new()
		empty.text = "登録なし"
		_fields.add_child(empty)
		_fields.add_child(Control.new())
	for pair in flow.sections[index].get("forbidden", []):
		var label := Label.new()
		label.text = "%s × %s" % [GRAPH.technique_title(rules, pair[0]), GRAPH.technique_title(rules, pair[1])]
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
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.add_item("登録なし")
		choice.set_item_metadata(0, "")
		for move in rules.techniques:
			choice.add_item(GRAPH.technique_title(rules, String(move.technique)))
			choice.set_item_metadata(choice.item_count - 1, String(move.technique))
		choice.selected = 0
		choices.append(choice)
		_fields.add_child(choice)
	var add := Button.new()
	add.text = "禁止ペアを追加"
	add.disabled = true
	for choice in choices:
		choice.item_selected.connect(func(_selected):
			var left := String(choices[0].get_item_metadata(choices[0].selected))
			var right := String(choices[1].get_item_metadata(choices[1].selected))
			add.disabled = left.is_empty() or right.is_empty() or left == right)
	add.pressed.connect(func():
		var pair := [String(choices[0].get_item_metadata(choices[0].selected)), String(choices[1].get_item_metadata(choices[1].selected))]
		if pair[0].is_empty() or pair[1].is_empty() or pair[0] == pair[1]: return
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
		item.set_text(0, GRAPH.technique_title(rules, source))
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
	_heading.tooltip_text = "このノードに接続する技を管理します。各技の発動距離・方向は技ノードを選んで編集します。"
	if not selection.is_empty():
		_section_heading("基本")
		var label := Label.new()
		label.text = "ノード名"
		_fields.add_child(label)
		var name_field := LineEdit.new()
		name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_field.text = selection.title
		var original_name: String = selection.title
		name_field.text_submitted.connect(func(value): _rename_group(group, value, original_name))
		name_field.focus_exited.connect(func(): _rename_group(group, name_field.text, original_name))
		_fields.add_child(name_field)
		var category_label := Label.new()
		category_label.text = "この条件ノードの分類"
		_fields.add_child(category_label)
		var category := OptionButton.new()
		var kinds := ["normal", "combo", "major"]
		for title_text in ["通常技", "コンボ技", "大技"]: category.add_item(title_text)
		category.selected = maxi(0, kinds.find(rules.category_for_group(group)))
		category.item_selected.connect(func(value): _set_group_category(group, kinds[value]))
		_fields.add_child(category)
		_section_heading("つながっている技（チェックを外すと出さない）")
		var member_count := 0
		for id in rules.node_ids():
			if graph.hub_for(id) != group: continue
			var enabled := CheckBox.new()
			enabled.text = GRAPH.node_title(rules, id)
			enabled.tooltip_text = "チェックを外した技は、この条件選択から発動しなくなります。"
			enabled.button_pressed = rules.graph_nodes.get(id, {}).get("connected", true)
			enabled.toggled.connect(func(value): graph._connect(id, value))
			_fields.add_child(enabled)
			_fields.add_child(Control.new())
			member_count += 1
		if member_count == 0:
			var empty := Label.new()
			empty.text = "つながっている技はありません。グラフでこの条件選択から技へ線を引くと追加されます。"
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty.custom_minimum_size.x = 160.0 * _scale
			_fields.add_child(empty)
			_fields.add_child(Control.new())
	_section_heading("範囲図の確認（保存しない）")
	var simulation := CheckBox.new()
	simulation.text = "範囲図の戦闘状況"
	simulation.tooltip_text = "範囲図に使う仮の状況を設定します。実際の戦闘設定や発動条件は変更しません。"
	_fields.add_child(simulation)
	_fields.add_child(Control.new())
	var preview_start := _fields.get_child_count()
	var separated := CheckButton.new()
	separated.text = "分離形態"
	separated.tooltip_text = "オン：分離後の首の配置で範囲を確認します。オフ：合体中として確認します。"
	separated.button_pressed = preview_separated
	separated.toggled.connect(func(value): preview_separated = value; _analyze_coverage())
	if _is_hydra():
		_fields.add_child(separated)
		_fields.add_child(Control.new())
	else: separated.free()
	_number_field("残りスタミナ", preview_stamina, func(value): preview_stamina = value; _analyze_coverage()).tooltip_text = "この残量で使える技だけを範囲図に重ねます。"
	_number_field("表示半径（px）", preview_radius, func(value): preview_radius = value; _analyze_coverage(), 1.0).tooltip_text = "ボスの中心から、どこまでを範囲図に表示するかを指定します。技の射程は変わりません。"
	for kind in preview_heads:
		if _is_hydra():
			var field := _number_field({"bite": "噛みつき", "vortex": "渦", "debris": "瓦礫", "beam": "ビーム", "thunder": "雷"}[kind] + "首の生存数（本）", preview_heads[kind], func(value): preview_heads[kind] = int(value); _analyze_coverage(), 0.0, 2.0)
			field.step = 1.0
			field.tooltip_text = "範囲図で生存扱いにする首の本数です。首を失ったときに攻撃できる範囲を確認できます。"
	var preview_fields := _fields.get_children().slice(preview_start)
	for i in range(1, preview_fields.size()):
		if preview_fields[i] is SpinBox and preview_fields[i - 1] is Label: preview_fields[i - 1].tooltip_text = preview_fields[i].tooltip_text
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

func _set_group_category(group: String, category: String) -> void:
	if not rules.condition_groups.has(group) or rules.category_for_group(group) == category: return
	var before: Dictionary = graph.snapshot()
	var after: Dictionary = graph.snapshot()
	after.condition_groups[group].category = category
	history.create_action("条件選択ノードの分類を変更")
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
					snapshot.reach = move.range_info(definition.params.merged(move.values(), true))
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
	_section_heading("この技へ進む条件")
	var gate: Dictionary = {"min": 0.0, "max": 600.0, "angle": 0.0, "half_angle": 180.0}.merged(rules.conditions.get(id, {}), true)
	rules.conditions[id] = gate
	for key in ["min", "max", "angle", "half_angle"]:
		_number_field({"min": "最小距離", "max": "最大距離", "angle": "中心角度（度）", "half_angle": "半角（度）"}[key], float(gate[key]), func(value):
			history.create_action("発動条件を変更")
			history.add_do_method(_set_gate.bind(id, key, value))
			history.add_undo_method(_set_gate.bind(id, key, gate[key]))
			history.commit_action(), -180.0 if key == "angle" else 0.0, 180.0 if "angle" in key else 100000.0)

func _refresh() -> void:
	_context(GRAPH.technique_title(rules, String(current.technique)) + " · 技の性能と発動条件", 0, true)
	preview.coverage_mode = false
	preview.gate = rules.conditions.get(_selected_technique, {})
	preview.set_attack(current, "hydra" if _is_hydra() else String(rules.adapter))
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	_append_display_name()
	preload("res://tools/editor/boss_flow/technique_visual_fields.gd").append(self, current)
	# 時間に関わる値と、威力・範囲の値を分けて並べる。
	var timing: Array = []
	var others: Array = []
	for key in current.field_names():
		if current.technique == &"spiral" and key == "warn": continue
		if key != "arcs" and (key in ["cost", "major_cost"] or not (current.field(key) is float or current.field(key) is int)): continue
		if String(key).trim_suffix("_p2") in TIMING_KEYS: timing.append(key)
		else: others.append(key)
	timing.sort_custom(func(a, b): return TIMING_KEYS.find(String(a).trim_suffix("_p2")) < TIMING_KEYS.find(String(b).trim_suffix("_p2")))
	var combo_category := graph.category_for(_selected_technique) == "combo"
	if not timing.is_empty() or not combo_category: _section_heading("タイミング")
	for key in timing: _technique_field(key)
	if not combo_category:
		var gap := _number_field("技後の隙（秒）", current.post_gap, _set_post_gap)
		gap.step = 0.05
		gap.tooltip_text = "技の演出と回復動作が終わってから、次の攻撃選択まで待つ時間です。コンボ技には追加しません。"
	if not others.is_empty(): _section_heading("威力と範囲")
	for key in others:
		if key == "arcs": _append_arcs()
		else: _technique_field(key)
	_section_heading("狙いと消費スタミナ")
	if not rules.combos.has(String(current.technique)):
		var tracking := CheckBox.new()
		tracking.text = "予告の間、自機を追う"
		tracking.tooltip_text = "ONでは予告の間ずっと自機を追って狙いと向きを直します。OFFでは予告を始めた時の自機の位置へ撃ちます。"
		tracking.button_pressed = current.track_during_warn
		tracking.toggled.connect(_set_tracking)
		_fields.add_child(tracking)
		# 2列の欄で、隣の入力欄の位置を空けて後ろの欄をずらさない。
		_fields.add_child(Control.new())
	var id := String(current.technique)
	_number_field("消費スタミナ", float(rules.costs.get(id, 1.0)), func(value):
		history.create_action("技の消費を変更")
		history.add_do_method(_set_cost.bind(id, value))
		history.add_undo_method(_set_cost.bind(id, float(rules.costs.get(id, 1.0))))
		history.commit_action())
	_append_gate(_selected_technique)
	_status.text = "左の青：発動条件　右の橙：攻撃範囲。動的な照準・配置は実験場で確認できます。"
	call_deferred("_refresh_field_columns")

## 技の値1つ分の名前と入力欄。
func _technique_field(key: Variant) -> void:
	var label := Label.new()
	label.text = SPIRAL_FIELDS.label_for(current, String(key))
	label.tooltip_text = SPIRAL_FIELDS.tip_for(current, String(key))
	_fields.add_child(label)
	var field := SpinBox.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bounds := SPIRAL_FIELDS.bounds_for(current, String(key))
	field.min_value = bounds.x
	field.max_value = bounds.y
	field.step = SPIRAL_FIELDS.step_for(current, String(key))
	field.tooltip_text = label.tooltip_text
	field.value = SPIRAL_FIELDS.to_display(String(key), float(current.field(key)), current)
	field.set_meta("key", key)
	field.value_changed.connect(func(value): set_value(key, SPIRAL_FIELDS.from_display(String(key), value, current)))
	_fields.add_child(field)

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
	_context(GRAPH.technique_title(rules, id) + " の実行内容", 0, true)
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
	preview = preload("res://tools/editor/boss_flow/range_preview.gd").new()
	flow_graph = preload("res://tools/editor/boss_flow/flow_graph.gd").new()
	combo_editor = preload("res://tools/editor/boss_flow/combo_graph.gd").new()
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

func set_arc_value(index: int, property: String, value: float) -> void:
	if current==null or not current.has_field("arcs"): return
	var old: Array=current.field("arcs")
	if index<0 or index>=old.size(): return
	var next: Array=[]
	for arc: Resource in old: next.append(arc.duplicate(true))
	if property in ["offset_x","offset_y"]:
		var offset: Vector2=next[index].offset
		if property=="offset_x": offset.x=value
		else: offset.y=value
		next[index].offset=offset
	else: next[index].set(property,int(value) if property=="count" else value)
	history.create_action("吐き出しの弧を変更")
	history.add_do_method(_assign.bind(current,"arcs",next))
	history.add_undo_method(_assign.bind(current,"arcs",old))
	history.commit_action()

func _append_arcs() -> void:
	var arcs: Array=current.field("arcs")
	for index in arcs.size():
		var arc: Resource=arcs[index]
		var label := Label.new()
		label.text="彗星弾の弧 %d" % (index+1)
		_full_row(label)
		for property in ["offset_x","offset_y","radius","angle_degrees","spread_degrees","count"]:
			var value: float=arc.offset.x if property=="offset_x" else arc.offset.y if property=="offset_y" else float(arc.get(property))
			_number_field({"offset_x":"位置 X","offset_y":"位置 Y","radius":"半径","angle_degrees":"中心角度","spread_degrees":"広がり","count":"弾数"}[property],value,func(next): set_arc_value(index,property,next),-10000.0 if property in ["offset_x","offset_y","angle_degrees"] else 1.0)
		var remove := Button.new()
		remove.text="この弧を削除"
		remove.pressed.connect(func():
			var old: Array=current.field("arcs")
			var next:=old.duplicate()
			next.remove_at(index)
			history.create_action("吐き出しの弧を削除")
			history.add_do_method(_assign.bind(current,"arcs",next))
			history.add_undo_method(_assign.bind(current,"arcs",old))
			history.commit_action()
			_refresh())
		_full_row(remove)
	var button := Button.new()
	button.text="弧を追加"
	button.pressed.connect(func():
		var old: Array=current.field("arcs")
		var next := old.duplicate()
		next.append(preload("res://scripts/bosses/draco_exhale_arc.gd").new())
		history.create_action("吐き出しの弧を追加")
		history.add_do_method(_assign.bind(current,"arcs",next))
		history.add_undo_method(_assign.bind(current,"arcs",old))
		history.commit_action()
		_refresh())
	_full_row(button)

func _append_display_name() -> void:
	var label := Label.new()
	label.text = "表示名"
	_fields.add_child(label)
	var field := LineEdit.new()
	field.text = current.display_name
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var target := current
	field.text_changed.connect(func(value):
		history.create_action("技の表示名を変更", UndoRedo.MERGE_ENDS)
		history.add_do_method(_set_display_name.bind(target, value))
		history.add_undo_method(_set_display_name.bind(target, target.display_name))
		history.commit_action())
	_fields.add_child(field)

func _set_display_name(target: Resource, value: String) -> void:
	target.display_name = value
	_mark_move_dirty(target)
	for node in graph.get_children():
		if node is GraphNode and rules.source_for(String(node.name)) == String(target.technique): node.title = value if not value.is_empty() else String(target.technique)

func _mark_move_dirty(target: Resource) -> void:
	var found := false
	for path in working:
		if working[path] == target:
			_dirty_working[path] = true
			found = true
	if not found: dirty_rules = true
	target.emit_changed()

func _show_add_technique() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "技を追加"
	dialog.ok_button_text = "作成"
	dialog.cancel_button_text = "キャンセル"
	var fields := VBoxContainer.new()
	dialog.add_child(fields)
	var id := LineEdit.new()
	id.placeholder_text = "技ID（例：new_attack）"
	id.tooltip_text = "保存先と接続に使う、重複しないID"
	fields.add_child(id)
	var title_field := LineEdit.new()
	title_field.placeholder_text = "表示名"
	fields.add_child(title_field)
	var mode := OptionButton.new()
	mode.add_item("ひな形からスクリプトを作る")
	mode.add_item("既存の技スクリプトを選ぶ")
	fields.add_child(mode)
	var script_path := LineEdit.new()
	script_path.placeholder_text = "技スクリプト（res://… .gd）"
	script_path.editable = false
	fields.add_child(script_path)
	var browse := Button.new()
	browse.text = "スクリプトを選ぶ…"
	browse.disabled = true
	fields.add_child(browse)
	mode.item_selected.connect(func(index): script_path.editable = index == 1; browse.disabled = index == 0)
	browse.pressed.connect(func():
		var picker := FileDialog.new()
		picker.access = FileDialog.ACCESS_RESOURCES
		picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		picker.filters = PackedStringArray(["*.gd ; 技のスクリプト"])
		picker.file_selected.connect(func(path): script_path.text = path; picker.queue_free())
		picker.canceled.connect(picker.queue_free)
		dialog.add_child(picker)
		picker.popup_centered_ratio(0.6))
	var result := Label.new()
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(result)
	dialog.dialog_hide_on_ok = false
	dialog.confirmed.connect(func():
		if rules.node_ids().has(id.text): result.text = "同じIDの技がすでにあります。"; return
		var created: Dictionary = preload("res://tools/editor/boss_flow/technique_authoring.gd").create(String(rules.adapter), id.text, title_field.text, script_path.text, mode.selected == 0)
		result.text = created.message
		if created.error != OK: return
		var move: Resource = created.move
		rules.techniques.append(move)
		rules.graph_nodes[id.text] = {"connected": false}
		rules.costs[id.text] = 1.0
		dirty_rules = true
		graph.show_rules(rules)
		_refresh_techniques()
		_picked("technique", id.text)
		_status.text = created.message
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520 * _scale, 0))
	id.grab_focus()
