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
var combo_editor := preload("res://addons/boss_flow/combo_graph.gd").new()
var combo_id := ""
var preview_stamina := 8.0
var preview_radius := 1800.0
var preview_heads := {"bite": 2, "vortex": 2, "debris": 1, "beam": 2, "thunder": 1}

func _ready() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	_path.placeholder_text = "技Resourceのパス（res://…）"
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_path)
	for entry in [["開く", _open_path], ["保存", save_current], ["戻す", history.undo], ["やり直す", history.redo], ["共通設定", _edit_common], ["範囲確認", _edit_coverage], ["併用禁止", _edit_forbidden], ["試遊", play_current]]:
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
	add_child(combo_editor)
	combo_editor.hide()
	combo_editor.inspected.connect(_edit_combo_step)
	combo_editor.changed.connect(func(value):
		history.create_action("コンボ内部を変更")
		history.add_do_method(_set_combo.bind(combo_id, value))
		history.add_undo_method(_set_combo.bind(combo_id, rules.combos.get(combo_id, {"type": "sequence", "children": []}).duplicate(true)))
		history.commit_action())

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
	combo_editor.hide()
	if kind == "technique":
		for move in rules.techniques:
			if String(move.technique) == id:
				open_technique(move.resource_path)
				var button := Button.new()
				button.text = "コンボ内部を開く"
				button.pressed.connect(func():
					combo_id = id
					editing_rules = true
					combo_editor.show()
					combo_editor.open(rules.combos.get(id, {"type": "sequence", "children": []}), rules.techniques))
				_fields.add_child(button)
				_fields.add_child(Control.new())
	elif kind == "condition":
		editing_rules = true
		preview.layers = []
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

func _set_combo(id: String, value: Dictionary) -> void:
	rules.combos[id] = value.duplicate(true)
	combo_editor.open(rules.combos[id], rules.techniques)

func _edit_combo_step(path: Array) -> void:
	_clear_fields()
	var step: Dictionary = rules.combos[combo_id]
	for index in path: step = step.children[index]
	_status.text = "コンボ内部: " + String(step.get("type", "action"))
	if step.type == "wait":
		_number_field("待機（秒）", step.seconds, func(value): _combo_field(path, "seconds", value))
	elif step.type == "branch":
		_status.text += "（子の左が成立、右が不成立）"
		for key in ["min", "max", "angle", "half_angle"]:
			_number_field(key, step.condition.get(key, 0.0), func(value): _combo_field(path, key, value, true), -180.0 if key == "angle" else 0.0)
	elif step.type == "action":
		var label := Label.new()
		label.text = "技（技間で再判定）"
		_fields.add_child(label)
		var choices := OptionButton.new()
		for move in rules.techniques:
			choices.add_item(String(move.technique))
			if String(move.technique) == step.id: choices.selected = choices.item_count - 1
		choices.item_selected.connect(func(index): _combo_field(path, "id", choices.get_item_text(index)))
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
	var avoid := CheckButton.new()
	avoid.text = "可能なら直前と同じ組み合わせを避ける"
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
	_number_field("今回の消費上限", float(flow.sections[i].get("cap", 2.0)), func(value):
		var copy: Array = flow.sections.duplicate(true)
		copy[i].cap = value
		history.create_action("消費上限を変更")
		history.add_do_method(_set_sections.bind(copy))
		history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
		history.commit_action())
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

func _edit_common() -> void:
	editing_flow = true
	_clear_fields()
	_status.text = "全区間から不足時に休息へ入ります"
	for key in ["maximum_stamina", "partial_rest", "empty_rest"]:
		_number_field({"maximum_stamina": "最大スタミナ", "partial_rest": "残量ありの休息（秒）", "empty_rest": "枯渇時の休息（秒）"}[key], flow.get(key), func(value):
			history.create_action("休息・スタミナを変更")
			history.add_do_property(flow, key, value)
			history.add_undo_property(flow, key, flow.get(key))
			history.commit_action())

func _edit_forbidden() -> void:
	editing_flow = false
	editing_rules = true
	_clear_fields()
	_status.text = "同時に使わない技の組（逆順も同じ設定）"
	for pair in rules.forbidden:
		var label := Label.new()
		label.text = "%s × %s" % [pair[0], pair[1]]
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
		for move in rules.techniques: choice.add_item(String(move.technique))
		choices.append(choice)
		_fields.add_child(choice)
	var add := Button.new()
	add.text = "禁止ペアを追加"
	add.pressed.connect(func():
		var pair := [choices[0].get_item_text(choices[0].selected), choices[1].get_item_text(choices[1].selected)]
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
	rules.forbidden = value.duplicate(true)
	_edit_forbidden()

func _edit_coverage() -> void:
	_clear_fields()
	_number_field("確認する残量", preview_stamina, func(value): preview_stamina = value)
	_number_field("確認領域の半径", preview_radius, func(value): preview_radius = value, 1.0)
	for kind in preview_heads:
		_number_field(kind + "の生存数", preview_heads[kind], func(value): preview_heads[kind] = int(value), 0.0, 2.0)
	var refresh := Button.new()
	refresh.text = "指定状況の範囲を重ねる"
	refresh.pressed.connect(_analyze_coverage)
	_fields.add_child(refresh)
	_analyze_coverage()

func _analyze_coverage() -> void:
	var layers: Array = []
	for move in rules.techniques:
		if float(rules.costs.get(String(move.technique), 1.0)) > preview_stamina: continue
		if move.head_kind != &"" and int(preview_heads.get(String(move.head_kind), 0)) == 0: continue
		var gate: Dictionary = rules.conditions.get(String(move.technique), {}).duplicate()
		gate.max = minf(float(gate.get("max", preview_radius)), preview_radius)
		# 本体を基準とした条件領域。個別の配置成立・照準の時間変化は実行側で再判定する。
		layers.append(gate)
	preview.radius = preview_radius
	preview.layers = layers
	var result: Dictionary = preview.analyze(layers, preview_radius)
	preview.gaps = result.points
	preview.queue_redraw()
	_status.text = "条件領域: %d技 / 未カバー %dサンプル（橙）。部位の配置・実到達の確認は試遊で行います。" % [layers.size(), result.holes]

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
