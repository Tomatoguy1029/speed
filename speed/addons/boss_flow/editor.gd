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
	if editing_rules:
		var result := ResourceSaver.save(rules, rules_path)
		_status.text = "発動条件を保存しました" if result == OK else error_string(result)
		return result
	if current == null or source_path.is_empty(): return ERR_UNCONFIGURED
	var error := ResourceSaver.save(current, source_path)
	_status.text = "保存済み（実行データは試遊前に生成）" if error == OK else error_string(error)
	return error

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
