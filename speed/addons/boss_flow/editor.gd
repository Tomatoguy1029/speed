@tool
extends VBoxContainer

var current: Resource
var source_path := ""
var history := UndoRedo.new()
var _fields := GridContainer.new()
var _status := Label.new()
var _path := LineEdit.new()
var rules: Resource
var rules_path := "res://data/bosses/hydra_action_rules.tres"
var graph := preload("res://addons/boss_flow/technique_graph.gd").new()
var preview := preload("res://addons/boss_flow/range_preview.gd").new()
var editing_rules := false
var flow: Resource
var flow_path := "res://data/bosses/hydra_flow.tres"
var flow_bar := HBoxContainer.new()
var editing_flow := false

func _ready() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	_path.placeholder_text = "技Resourceのパス（res://…）"
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_path)
	for entry in [["開く", _open_path], ["保存", save_current], ["戻す", history.undo], ["やり直す", history.redo], ["試遊", play_current]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		toolbar.add_child(button)
	add_child(_status)
	var flow_scroll := ScrollContainer.new()
	flow_scroll.custom_minimum_size.y = 64
	flow_scroll.add_child(flow_bar)
	add_child(flow_scroll)
	flow = load(flow_path).duplicate(true) if ResourceLoader.exists(flow_path) else preload("res://scripts/data_types/boss_flow_def.gd").new()
	_refresh_flow()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	split.add_child(graph)
	graph.picked.connect(_picked)
	var details := VBoxContainer.new()
	split.add_child(details)
	details.custom_minimum_size.x = 260
	details.add_child(preview)
	details.add_child(scroll)
	_fields.columns = 2
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_fields)
	_status.text = "技を開いて編集します。保存では実行データを生成しません。"
	_load_rules()

func _load_rules() -> void:
	if ResourceLoader.exists(rules_path):
		rules = load(rules_path).duplicate(false)
		rules.conditions = rules.conditions.duplicate(true)
	else:
		rules = preload("res://scripts/data_types/boss_action_rules.gd").new()
		for filename in DirAccess.get_files_at("res://data/bosses/hydra_moves"):
			if filename.ends_with(".tres"): rules.techniques.append(load("res://data/bosses/hydra_moves/" + filename))
	graph.show_rules(rules)

func _picked(kind: String, id: String) -> void:
	editing_flow = false
	if kind == "technique":
		for move in rules.techniques:
			if String(move.technique) == id: open_technique(move.resource_path)
	elif kind == "condition":
		editing_rules = true
		for child in _fields.get_children():
			_fields.remove_child(child)
			child.queue_free()
		var gate: Dictionary = rules.conditions.get(id, {"min": 0.0, "max": 600.0, "angle": 0.0, "half_angle": 180.0})
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
		_status.text = id + " の発動条件（区間と独立）"

func _set_gate(id: String, key: String, value: float) -> void:
	rules.conditions[id][key] = value
	preview.queue_redraw()

func _open_path() -> void:
	open_technique(_path.text)

func open_technique(path: String) -> Error:
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not loaded.get("parameters") is Dictionary:
		_status.text = "技の設定を開けません: " + path
		return ERR_INVALID_DATA
	current = loaded.duplicate(true)
	editing_rules = false
	editing_flow = false
	source_path = path
	_path.text = path
	history.clear_history()
	_refresh()
	return OK

func set_value(key: String, value: float) -> void:
	if current == null or not current.parameters.has(key): return
	var old: Variant = current.parameters[key]
	var next: Variant = int(value) if old is int else value
	if old == next: return
	history.create_action("技の " + key + " を変更")
	history.add_do_method(_assign.bind(key, next))
	history.add_undo_method(_assign.bind(key, old))
	history.commit_action()

func _assign(key: String, value: Variant) -> void:
	current.parameters[key] = value
	current.emit_changed()
	_status.text = "未保存: " + source_path
	for node in _fields.get_children():
		if node is SpinBox and node.get_meta("key", "") == key:
			node.set_value_no_signal(float(value))

func save_current() -> Error:
	if editing_flow: return ResourceSaver.save(flow, flow_path)
	if editing_rules:
		var result := ResourceSaver.save(rules, rules_path)
		_status.text = "発動条件を保存しました" if result == OK else error_string(result)
		return result
	if current == null or source_path.is_empty(): return ERR_UNCONFIGURED
	var error := ResourceSaver.save(current, source_path)
	_status.text = "保存済み（実行データは試遊前に生成）" if error == OK else error_string(error)
	return error

func _clear_fields() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()

func _refresh_flow() -> void:
	for child in flow_bar.get_children():
		flow_bar.remove_child(child)
		child.queue_free()
	for i in flow.sections.size():
		var button := Button.new()
		button.text = "%s →" % flow.sections[i].get("name", "区間" + str(i + 1))
		button.pressed.connect(_edit_section.bind(i))
		flow_bar.add_child(button)
	var add := Button.new()
	add.text = "＋ 区間"
	add.pressed.connect(func():
		var copy: Array = flow.sections.duplicate(true)
		copy.append({"name": "区間" + str(copy.size() + 1), "request": "normal", "cap": 2.0, "weights": {"single": 60.0, "parallel": 25.0, "combo": 15.0}, "next": 0})
		history.create_action("区間を追加")
		history.add_do_method(_set_sections.bind(copy))
		history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
		history.commit_action())
	flow_bar.add_child(add)

func _set_sections(value: Array) -> void:
	flow.sections = value.duplicate(true)
	_refresh_flow()

func _edit_section(i: int) -> void:
	editing_flow = true
	_clear_fields()
	_status.text = "共通フローの区間（技定義は全区間で共通）"
	for key in ["name", "request", "next"]:
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
		_fields.add_child(field)
	for key in ["single", "parallel", "combo", "major"]:
		_number_field({"single": "単独の割合", "parallel": "同時の割合", "combo": "コンボの割合", "major": "大技の割合"}[key], float(flow.sections[i].get("weights", {}).get(key, 0.0)), func(value): _section_weight(i, key, value))
	for previous in ["single", "parallel", "combo", "major"]:
		var button := Button.new()
		button.text = "直前が「%s」の確率を編集" % previous
		button.pressed.connect(_edit_probability.bind(i, previous))
		_fields.add_child(button)
		_fields.add_child(Control.new())

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

func play_current() -> void:
	if save_current() != OK: return
	var result = preload("res://tools/content/build_boss_program.gd").compile({"techniques": [current]}, "res://.content/boss_preview.tres")
	if result.error != OK:
		_status.text = "生成失敗: " + error_string(result.error)
		return
	if Engine.is_editor_hint(): EditorInterface.play_custom_scene("res://gyms/boss_flow_trial.tscn")

func _refresh() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	for key in current.parameters:
		var label := Label.new()
		label.text = String(key)
		_fields.add_child(label)
		var field := SpinBox.new()
		field.min_value = 0
		field.max_value = 100000
		field.step = 1 if current.parameters[key] is int else 0.01
		field.value = float(current.parameters[key])
		field.set_meta("key", key)
		field.value_changed.connect(func(value): set_value(key, value))
		_fields.add_child(field)
	_status.text = "編集中: " + source_path
