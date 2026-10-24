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
var flow_bar := HBoxContainer.new()
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
var preview_separated := false
const GRAPH := preload("res://addons/boss_flow/technique_graph.gd")
const PARAM_LABELS := {"normal_charge": "予備動作（秒）", "normal_hold": "攻撃後の停止（秒）", "attack_cd": "技後の待ち（秒）", "normal_lunge": "踏み込み時間（秒）", "warning_time": "予告（秒）", "performance_time": "実行時間（秒）", "tech_recovery": "技後の全体待ち（秒）", "cooldown": "再使用待ち（秒）", "sweep_time": "薙ぎ時間（秒）", "sweep_reach": "薙ぎの長さ", "sweep_arc": "薙ぎの角度（rad）", "aim_tracking": "標的位置を追う時間（秒）"}

func _ready() -> void:
	saved_version = history.get_version()
	var toolbar := HFlowContainer.new()
	add_child(toolbar)
	_path.placeholder_text = "グラフで技を選択（ファイルパスからも開けます）"
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path.custom_minimum_size.x = 180
	toolbar.add_child(_path)
	for entry in [["開く", _open_path], ["保存", save_current], ["戻す", history.undo], ["やり直す", history.redo], ["共通設定", _edit_common], ["範囲確認", _edit_coverage], ["併用禁止", _edit_forbidden], ["＋コンボ", _new_combo], ["試遊", play_current]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		toolbar.add_child(button)
	add_child(_status)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var flow_scroll := ScrollContainer.new()
	flow_scroll.custom_minimum_size.y = 64
	flow_scroll.add_child(flow_bar)
	add_child(flow_scroll)
	flow = load(flow_path).duplicate(true) if ResourceLoader.exists(flow_path) else preload("res://scripts/data_types/boss_flow_def.gd").new()
	_refresh_flow()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	split.add_child(graph)
	graph.picked.connect(_picked)
	graph.layout_changed.connect(func(): dirty_rules = true)
	var details := VBoxContainer.new()
	split.add_child(details)
	details.custom_minimum_size.x = 260
	var preview_frame := AspectRatioContainer.new()
	preview_frame.ratio = 1.0
	preview_frame.custom_minimum_size = Vector2(180, 180)
	details.add_child(preview_frame)
	preview_frame.add_child(preview)
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
		rules = ResourceLoader.load(rules_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP).duplicate(false)
		rules.conditions = rules.conditions.duplicate(true)
		rules.techniques = rules.techniques.duplicate()
		rules.combos = rules.combos.duplicate(true)
		rules.costs = rules.costs.duplicate(true)
		rules.forbidden = rules.forbidden.duplicate(true)
		rules.layout = rules.layout.duplicate(true)
	else:
		rules = preload("res://scripts/data_types/boss_action_rules.gd").new()
		for filename in DirAccess.get_files_at("res://data/bosses/hydra_moves"):
			if filename.ends_with(".tres"): rules.techniques.append(load("res://data/bosses/hydra_moves/" + filename))
	graph.show_rules(rules)

func open_boss(action_path: String, section_path: String) -> Error:
	if not ResourceLoader.exists(action_path) or not ResourceLoader.exists(section_path): return ERR_FILE_NOT_FOUND
	if action_path == rules_path and section_path == flow_path: return OK
	if history.get_version() != saved_version or dirty_flow or dirty_rules:
		_status.text = "未保存の変更があります。「保存」してから別のボスを開いてください。"
		return ERR_BUSY
	rules_path = action_path
	flow_path = section_path
	working.clear()
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
	editing_flow = false
	combo_editor.hide()
	if kind == "coverage":
		_edit_coverage()
	elif kind == "technique":
		if rules.combos.has(id):
			_edit_custom(id)
			return
		for move in rules.techniques:
			if String(move.technique) == id:
				if move.resource_path.is_empty() or "::" in move.resource_path:
					current = move.duplicate(true)
					rules.techniques[rules.techniques.find(move)] = current
					source_path = rules_path
					_refresh()
				else: open_technique(move.resource_path)
				var button := Button.new()
				button.text = "コンボ内部を開く"
				button.pressed.connect(func():
					combo_id = id
					combo_editor.path.clear()
					editing_rules = true
					combo_editor.show()
					combo_editor.open(rules.combos.get(id, {"type": "sequence", "children": []}), rules.techniques))
				_fields.add_child(button)
				_fields.add_child(Control.new())
	elif kind == "condition":
		editing_rules = true
		preview.layers = []
		preview.coverage_mode = false
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
	dirty_rules = true
	rules.conditions[id][key] = value
	preview.queue_redraw()

func _set_combo(id: String, value: Dictionary) -> void:
	dirty_rules = true
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
	current = working.get(path, loaded.duplicate(true))
	working[path] = current
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
	target.emit_changed()
	_status.text = "未保存: " + source_path
	for node in _fields.get_children():
		if target == current and node is SpinBox and node.get_meta("key", "") == key:
			node.set_value_no_signal(float(value))

func save_current() -> Error:
	for path in working:
		var move: Resource = working[path]
		var error := ResourceSaver.save(move, path, ResourceSaver.FLAG_CHANGE_PATH)
		if error != OK: return error
		for i in rules.techniques.size():
			if rules.techniques[i].resource_path == path: rules.techniques[i] = move
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
		if not copy.is_empty() and copy[-1].get("next", 0) == 0: copy[-1].next = copy.size()
		copy.append({"name": "区間" + str(copy.size() + 1), "request": "normal", "cap": 2.0, "weights": {"single": 60.0, "parallel": 25.0, "combo": 15.0}, "next": 0})
		history.create_action("区間を追加")
		history.add_do_method(_set_sections.bind(copy))
		history.add_undo_method(_set_sections.bind(flow.sections.duplicate(true)))
		history.commit_action())
	flow_bar.add_child(add)

func _set_sections(value: Array) -> void:
	dirty_flow = true
	flow.sections = value.duplicate(true)
	_refresh_flow()

func _edit_section(i: int) -> void:
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
	for key in ["single", "parallel", "combo", "major"]:
		_number_field({"single": "単独の割合", "parallel": "同時の割合", "combo": "コンボの割合", "major": "大技の割合"}[key], float(flow.sections[i].get("weights", {}).get(key, 0.0)), func(value): _section_weight(i, key, value))
	for previous in ["single", "parallel", "combo", "major"]:
		var button := Button.new()
		button.text = "直前：%s の確率" % {"single": "単独", "parallel": "同時", "combo": "コンボ", "major": "大技"}[previous]
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
	dirty_rules = true
	rules.forbidden = value.duplicate(true)
	_edit_forbidden()

func _edit_coverage() -> void:
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
	refresh.text = "指定状況の範囲を重ねる"
	refresh.pressed.connect(_analyze_coverage)
	_fields.add_child(refresh)
	_analyze_coverage()

func _analyze_coverage() -> void:
	preview.coverage_mode = true
	if not _is_hydra():
		var layers: Array = []
		for move in rules.techniques:
			if float(rules.costs.get(String(move.technique), 1.0)) <= preview_stamina:
				var gate: Dictionary = rules.conditions.get(String(move.technique), {}).duplicate()
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
		var gate: Dictionary = rules.conditions.get(String(move.technique), {}).duplicate()
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
	_status.text = "編集中: " + source_path

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
	_edit_custom(id)

func _remove_combo(id: String) -> void:
	rules.combos.erase(id)
	rules.costs.erase(id)
	dirty_rules = true
	graph.show_rules(rules)
	combo_editor.hide()

func _edit_custom(id: String) -> void:
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

func _exit_tree() -> void:
	history.clear_history()
	history.free()
	working.clear()
