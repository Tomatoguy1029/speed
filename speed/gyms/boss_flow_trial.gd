## 敵・ルート・ボスを同じ実験場で扱う。旧ボス試遊シーンもこの画面をボス選択済みで開く。
extends "res://gyms/enemy_lab/enemy_lab.gd"

const MANUAL := preload("res://gyms/boss_technique_debug.gd")
const TECHNIQUE_GRAPH := preload("res://tools/editor/boss_flow/technique_graph.gd")
const TECHNIQUE_FIELDS := preload("res://tools/editor/boss_flow/technique_fields.gd")

var preview_actor: BossActor
var manual: RefCounted
var _target_id := ""
var _target_boss := false
var _current_program_path := ""
var _target_picker: OptionButton
var _phase_picker: OptionButton
var _move_picker: OptionButton
var _execute: Button
var _manual_status: Label
var _manual_message: Label
var _technique_row: Control
var _switching := false
var _switch_serial := 0
var _tuning_panel: PanelContainer
var _tuning_toggle: Button
var _tuning_title: Label
var _tuning_status: Label
var _tuning_save_button: Button
var _tuning_fields: VBoxContainer
var _tuning_revert_dialog: ConfirmationDialog
var _drafts := {}
var _saved := {}
var _source_paths := {}
var _source_hashes := {}
var _rules_paths := {}
var _rules_hashes := {}
var _prefer_preview_values := false
## 再生中の技。終わるたびに同じ技を撃ち直し、技・ボスの選び直し・リセット・通常AIへ戻すで止める。
var _repeat_id := ""
var _repeat_wait := 0.0
## 技が終わってから撃ち直すまでの間（秒）
const REPEAT_GAP := 0.6

func _ready() -> void:
	await super._ready()
	if not OS.is_debug_build() or not is_instance_valid(session.run): return
	_build_trial_ui()
	if scene_file_path == "res://gyms/boss_flow_trial.tscn":
		var request := _editor_preview_request()
		var id := String(request.get("boss", "monoceros"))
		var path := String(get_meta("preview_program", "res://.content/boss_preview.tres" if not request.is_empty() else ""))
		await _activate_boss(id, String(request.get("technique", "")), path)

func _editor_preview_request() -> Dictionary:
	var request: Dictionary = get_meta("preview_request", {})
	if request.is_empty() and FileAccess.file_exists("res://.content/boss_preview.json"):
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.content/boss_preview.json"))
		if loaded is Dictionary: request = loaded
	return request

func _build_trial_ui() -> void:
	var layout: VBoxContainer = workspace._vertical_split.get_parent()
	var panel := VBoxContainer.new()
	layout.add_child(panel)
	layout.move_child(panel, workspace._vertical_split.get_index())
	var target_row := HFlowContainer.new()
	panel.add_child(target_row)
	_label(target_row, "敵・ボス")
	_target_picker = OptionButton.new()
	_target_picker.custom_minimum_size.x = 180
	_target_picker.fit_to_longest_item = false
	_target_picker.clip_text = true
	_target_picker.add_item("自由配置")
	_target_picker.set_item_metadata(0, {"id": "", "boss": false})
	_target_picker.add_separator("通常敵・強敵・生成敵")
	for def: EnemyDef in ContentManager.sorted(ContentManager.enemies):
		var index := _target_picker.item_count
		_target_picker.add_item("%s (%s)" % [def.display_name, def.id])
		_target_picker.set_item_metadata(index, {"id": String(def.id), "boss": false})
	_target_picker.add_separator("ボス")
	for def: BossDef in ContentManager.sorted(ContentManager.bosses):
		var index := _target_picker.item_count
		_target_picker.add_item("%s (%s)" % [def.display_name, def.id])
		_target_picker.set_item_metadata(index, {"id": String(def.id), "boss": true})
	target_row.add_child(_target_picker)
	_target_picker.item_selected.connect(_switch_target)
	_technique_row = HBoxContainer.new()
	target_row.add_child(_technique_row)
	_phase_picker = OptionButton.new()
	_phase_picker.tooltip_text = "ボスの形態"
	_technique_row.add_child(_phase_picker)
	_move_picker = OptionButton.new()
	_move_picker.custom_minimum_size.x = 190
	_move_picker.fit_to_longest_item = false
	_move_picker.clip_text = true
	_move_picker.tooltip_text = "実行するボス技"
	_technique_row.add_child(_move_picker)
	_move_picker.item_selected.connect(func(_index): _repeat_id = ""; _manual_message.hide(); _refresh_tuning_selection())
	_phase_picker.item_selected.connect(func(_index): _manual_message.hide())
	_execute = _button(_technique_row, "技を再生", _execute_selected)
	_button(_technique_row, "通常AIへ戻す", _return_to_ai)
	_tuning_toggle = _button(_technique_row, "技を調整", _toggle_tuning_panel)
	_tuning_toggle.tooltip_text = "選択した技の値を画面を見ながら調整します。次の再生から反映します。"
	_tuning_toggle.hide()
	_manual_status = _label(target_row, "")
	_manual_message = _label(target_row, "")
	_manual_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_manual_message.custom_minimum_size.x = 0
	_technique_row.hide()
	_manual_status.hide()
	_manual_message.hide()
	_build_tuning_panel()

func _build_tuning_panel() -> void:
	_tuning_panel = PanelContainer.new()
	_tuning_panel.custom_minimum_size.x = 316
	_tuning_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace._right_dock.add_child(_tuning_panel)
	_tuning_panel.hide()
	var body := VBoxContainer.new()
	_tuning_panel.add_child(body)
	_tuning_title = _label(body, "技の調整")
	_tuning_title.add_theme_font_size_override("font_size", 17)
	var hint := _label(body, "値を変えたら「技を再生」で確認")
	hint.tooltip_text = "進行中の技には途中から反映しません。次の再生で新しい値を使います。"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_tuning_fields = VBoxContainer.new()
	_tuning_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tuning_fields)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	_tuning_save_button = _button(actions, "変更を保存", _save_tuning)
	_button(actions, "元に戻す", _request_tuning_revert)
	_tuning_status = _label(body, "")
	_tuning_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tuning_revert_dialog = ConfirmationDialog.new()
	_tuning_revert_dialog.title = "技の変更を元に戻す"
	_tuning_revert_dialog.dialog_text = "選択した技の未保存の変更を破棄し、保存済みの値を読み直しますか？"
	_tuning_revert_dialog.confirmed.connect(_revert_tuning)
	_tuning_panel.add_child(_tuning_revert_dialog)

func _source_move(boss: String, id: String) -> Resource:
	var path := "res://data/bosses/ai/%s_action_rules.tres" % boss
	var rules: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if rules == null or not rules.get("techniques") is Array: return null
	for move: Resource in rules.techniques:
		if String(move.technique) == id: return move
	return null

func _rules_path(boss: String) -> String:
	return "res://data/bosses/ai/%s_action_rules.tres" % boss

func _capture_conditions(rules: Resource, id: String) -> Dictionary:
	var values := {}
	if rules == null or not rules.get("conditions") is Dictionary: return values
	var gate: Dictionary = rules.conditions.get(id, {})
	for field in ["min", "max", "angle", "half_angle"]:
		if gate.get(field) is float or gate.get(field) is int:
			values["condition_" + field] = gate[field]
	return values

func _normalize_preview_program(program: Resource, boss: String) -> String:
	var rules: Resource = program.data.rules
	var source_rules: Resource = ResourceLoader.load("res://data/bosses/ai/%s_action_rules.tres" % boss, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if source_rules == null or not source_rules.get("techniques") is Array: return "保存済みの技定義を読めません。"
	var sources := {}
	for source: Resource in source_rules.techniques: sources[String(source.technique)] = source
	for move: Resource in rules.techniques:
		var id := String(move.technique)
		if not sources.has(id): return "技の保存元がありません: " + id
		var source: Resource = sources[id]
		if not source.has_method("values") or not move.has_method("values"):
			return "技の値が壊れています: " + id
		for required in TECHNIQUE_FIELDS.REQUIRED.get(id, []):
			if not source.has_field(required): return "技の保存元に必要な値がありません: %s / %s" % [id, required]
		if not move.is_scripted():
			var values: Dictionary = move.parameters.duplicate(true)
			for key in source.parameters:
				if not values.has(key): values[key] = source.parameters[key]
			move.parameters = values
	return ""

func _capture_editable(move: Resource) -> Dictionary:
	var values := {}
	for key in TECHNIQUE_FIELDS.editable_keys(move): values[key] = move.field(key)
	if move.field("arcs") is Array:
		var arcs := []
		for arc: Resource in move.field("arcs"):
			arcs.append({"offset_x": arc.offset.x, "offset_y": arc.offset.y,
				"radius": arc.radius, "angle_degrees": arc.angle_degrees,
				"spread_degrees": arc.spread_degrees, "count": arc.count})
		values["arcs"] = arcs
	return values

func _move_key(boss: String, id: String) -> String:
	return boss + "/" + id

func _selected_technique() -> String:
	return String(_move_picker.get_selected_metadata()) if _move_picker != null and _move_picker.selected >= 0 else ""

func _current_tuning_key() -> String:
	return _move_key(_target_id, _selected_technique())

func _tuning_dirty(key: String) -> bool:
	return _drafts.has(key) and _drafts[key] != _saved[key]

func _first_dirty_key() -> String:
	for key in _drafts:
		if _tuning_dirty(key): return key
	return ""

func _ensure_tuning_state(boss: String, id: String, preview_move: Resource = null) -> bool:
	var key := _move_key(boss, id)
	if _drafts.has(key): return true
	var source: Resource = _source_move(boss, id)
	if source == null or not source.get("parameters") is Dictionary:
		_tuning_status.text = "技の保存元を開けません: " + key
		return false
	var path := source.resource_path
	if path.is_empty() or "::" in path or not path.begins_with("res://"):
		_tuning_status.text = "この技には単独の保存先がありません: " + key
		return false
	var saved := _capture_editable(source)
	var rules_path := _rules_path(boss)
	var source_rules: Resource = ResourceLoader.load(rules_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if source_rules == null:
		_tuning_status.text = "技の発動条件を開けません: " + key
		return false
	saved.merge(_capture_conditions(source_rules, id))
	if saved.is_empty():
		_tuning_status.text = "この技に調整できる数値がありません: " + key
		return false
	var draft: Dictionary = saved.duplicate(true)
	if _prefer_preview_values and preview_move != null:
		var preview_values := _capture_editable(preview_move)
		preview_values.merge(_capture_conditions(preview_actor.action_rules, id))
		for field in saved:
			if preview_values.has(field): draft[field] = preview_values[field]
	_saved[key] = saved
	_drafts[key] = draft
	_source_paths[key] = path
	_source_hashes[key] = FileAccess.get_sha256(path)
	_rules_paths[key] = rules_path
	_rules_hashes[key] = FileAccess.get_sha256(rules_path)
	return true

func _selected_move() -> Resource:
	if not is_instance_valid(preview_actor): return null
	var id := _selected_technique()
	if id.is_empty() or preview_actor.action_rules.combos.has(id): return null
	return preview_actor._moves.get(StringName(id))

func _refresh_tuning_selection() -> void:
	if _tuning_toggle == null: return
	var move := _selected_move()
	_tuning_toggle.visible = _target_boss and move != null
	if move == null:
		workspace.hide_tuning()
		return
	var key := _current_tuning_key()
	if not _ensure_tuning_state(_target_id, _selected_technique(), move):
		_tuning_toggle.disabled = true
		_tuning_toggle.tooltip_text = _tuning_status.text
		workspace.hide_tuning()
		return
	_tuning_toggle.disabled = false
	_tuning_title.text = TECHNIQUE_GRAPH.technique_title(preview_actor.action_rules if is_instance_valid(preview_actor) else null, _selected_technique()) + "を調整"
	_rebuild_tuning_fields(key, move)
	_update_tuning_status(key)

func _rebuild_tuning_fields(key: String, move: Resource) -> void:
	for child in _tuning_fields.get_children():
		_tuning_fields.remove_child(child)
		child.queue_free()
	var draft: Dictionary = _drafts[key]
	if move.technique == &"inhale" and is_instance_valid(preview_actor) and "lab_inhale_stars" in preview_actor:
		# 実験場には吸い込むピカロがいないので、吐き出す彗星弾の数を確かめるための星の数を決める。保存しない。
		_add_tuning_field("吸い込んだ星の数（試遊用）", float(preview_actor.lab_inhale_stars), Vector2(0.0, 200.0), 1.0,
			"実験場で吸い込んだことにする星の数です。星1つにつき彗星弾の数が増え、弧ごとの弾数と全体の上限で止まります。保存しません。",
			func(value: float): preview_actor.lab_inhale_stars = int(value))
	for field in ["min", "max", "angle", "half_angle"]:
		var condition: String = "condition_" + field
		if not draft.has(condition): continue
		var bounds := Vector2(-180.0, 180.0) if field == "angle" else Vector2(0.0, 180.0) if field == "half_angle" else Vector2(0.0, 100000.0)
		var title: String = {"min": "発動の最小距離", "max": "発動の最大距離", "angle": "発動の中心角度", "half_angle": "発動の左右角度"}[field]
		_add_tuning_field(title, float(draft[condition]), bounds, 0.01, "この技を発動する自機との位置・方向の条件です。", _change_tuning_value.bind(key, condition))
	for field in TECHNIQUE_FIELDS.editable_keys(move):
		if not draft.has(field): continue
		var bounds: Vector2 = TECHNIQUE_FIELDS.bounds_for(move, field)
		var step := 1.0 if move.field(field) is int else 0.01
		_add_tuning_field(TECHNIQUE_FIELDS.label_for(move, field, true), TECHNIQUE_FIELDS.to_display(field, float(draft[field])), bounds, step,
			TECHNIQUE_FIELDS.tip_for(move, field), func(value: float): _change_tuning_value(TECHNIQUE_FIELDS.from_display(field, value), key, field))
	if draft.has("arcs"):
		var arcs: Array = draft.arcs
		for index in arcs.size():
			var heading := HBoxContainer.new()
			_tuning_fields.add_child(heading)
			_label(heading, "彗星弾の弧 %d" % (index + 1))
			_button(heading, "削除", _remove_tuning_arc.bind(key, index))
			for field in TECHNIQUE_FIELDS.ARC_KEYS:
				_add_tuning_field(TECHNIQUE_FIELDS.ARC_LABELS[field], float(arcs[index][field]),
					TECHNIQUE_FIELDS.arc_bounds(field), 1.0 if field == "count" else 0.01,
					"彗星弾の弧 %d の%s" % [index + 1, TECHNIQUE_FIELDS.ARC_LABELS[field]],
					_change_tuning_arc.bind(key, index, field))
		_button(_tuning_fields, "弧を追加", _add_tuning_arc.bind(key))

func _add_tuning_field(label_text: String, value: float, bounds: Vector2, step: float, tip: String, changed: Callable) -> void:
	var row := HBoxContainer.new()
	_tuning_fields.add_child(row)
	var caption := _label(row, label_text)
	caption.custom_minimum_size.x = 183
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.tooltip_text = tip
	var input := SpinBox.new()
	input.custom_minimum_size.x = 91
	input.min_value = bounds.x
	input.max_value = bounds.y
	input.step = step
	input.tooltip_text = tip
	input.value = value
	input.value_changed.connect(changed)
	row.add_child(input)

func _change_tuning_value(value: float, key: String, field: String) -> void:
	var draft: Dictionary = _drafts[key]
	draft[field] = int(value) if _saved[key][field] is int else value
	_drafts[key] = draft
	_update_tuning_status(key)

func _change_tuning_arc(value: float, key: String, index: int, field: String) -> void:
	var draft: Dictionary = _drafts[key]
	var arcs: Array = draft.arcs
	var arc: Dictionary = arcs[index]
	arc[field] = int(value) if field == "count" else value
	arcs[index] = arc
	draft.arcs = arcs
	_drafts[key] = draft
	_update_tuning_status(key)

func _add_tuning_arc(key: String) -> void:
	var draft: Dictionary = _drafts[key]
	var arcs: Array = draft.arcs
	var arc: Resource = preload("res://scripts/bosses/draco_exhale_arc.gd").new()
	arcs.append({"offset_x": arc.offset.x, "offset_y": arc.offset.y,
		"radius": arc.radius, "angle_degrees": arc.angle_degrees,
		"spread_degrees": arc.spread_degrees, "count": arc.count})
	draft.arcs = arcs
	_drafts[key] = draft
	_rebuild_tuning_fields(key, _selected_move())
	_update_tuning_status(key)

func _remove_tuning_arc(key: String, index: int) -> void:
	var draft: Dictionary = _drafts[key]
	var arcs: Array = draft.arcs
	arcs.remove_at(index)
	draft.arcs = arcs
	_drafts[key] = draft
	_rebuild_tuning_fields(key, _selected_move())
	_update_tuning_status(key)

func _update_tuning_status(key: String) -> void:
	_tuning_save_button.disabled = not _tuning_dirty(key)
	_tuning_toggle.text = "技を調整（未保存）" if _tuning_dirty(key) else "技を調整"
	_tuning_toggle.tooltip_text = "未保存の変更は次の再生から反映します。" if _tuning_dirty(key) else "選択した技の値を画面を見ながら調整します。"
	_tuning_status.text = "未保存。次の再生から反映します。" if _tuning_dirty(key) else "保存済みの値です。"
	_tuning_save_button.tooltip_text = String(_source_paths[key]) + " に保存します。"

func _toggle_tuning_panel() -> void:
	if _tuning_panel.visible: workspace.hide_tuning()
	else: workspace.show_tuning(_tuning_panel)

func _move_with_draft(move: Resource, draft: Dictionary) -> Resource:
	var copy: Resource = move.duplicate(true)
	var values: Dictionary = copy.values().duplicate(true)
	for field in draft:
		if field.begins_with("condition_"): continue
		if field == "arcs":
			var previous: Array = values.get("arcs", [])
			var arcs := []
			for index in draft.arcs.size():
				var arc: Resource = previous[index].duplicate(true) if index < previous.size() else preload("res://scripts/bosses/draco_exhale_arc.gd").new()
				var entry: Dictionary = draft.arcs[index]
				arc.offset = Vector2(entry.offset_x, entry.offset_y)
				for property in ["radius", "angle_degrees", "spread_degrees", "count"]: arc.set(property, entry[property])
				arcs.append(arc)
			values.arcs = arcs
		else: values[field] = draft[field]
	copy.assign_values(values)
	return copy

func _apply_tuning_preview() -> void:
	var move := _selected_move()
	var key := _current_tuning_key()
	if move == null or not _drafts.has(key): return
	var copy := _move_with_draft(move, _drafts[key])
	preview_actor._moves[StringName(_selected_technique())] = copy
	for index in preview_actor.action_rules.techniques.size():
		if String(preview_actor.action_rules.techniques[index].technique) == _selected_technique():
			preview_actor.action_rules.techniques[index] = copy
	var gate: Dictionary = preview_actor.action_rules.conditions.get(_selected_technique(), {}).duplicate(true)
	for field in ["min", "max", "angle", "half_angle"]:
		if _drafts[key].has("condition_" + field): gate[field] = _drafts[key]["condition_" + field]
	preview_actor.action_rules.conditions[_selected_technique()] = gate

func _save_tuning() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and _tuning_panel.is_ancestor_of(focus): focus.release_focus()
	var key := _current_tuning_key()
	if not _tuning_dirty(key): return
	var path: String = _source_paths[key]
	if FileAccess.get_sha256(path) != _source_hashes[key] or FileAccess.get_sha256(_rules_paths[key]) != _rules_hashes[key]:
		_tuning_status.text = "外部でこの技の設定が変わりました。保存を止めました。"
		return
	var draft: Dictionary = _drafts[key]
	if draft.has("condition_min") and draft.has("condition_max") and float(draft.condition_min) > float(draft.condition_max):
		_tuning_status.text = "発動の最小距離が最大距離を超えています。"
		return
	var move: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if move == null or not move.get("parameters") is Dictionary:
		_tuning_status.text = "保存用の技の設定を開けません。"
		return
	var saved: Resource = _move_with_draft(move, _drafts[key])
	var rules: Resource = ResourceLoader.load(_rules_paths[key], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if rules == null:
		_tuning_status.text = "発動条件を保存用に開けません。"
		return
	var id := _selected_technique()
	var gate: Dictionary = rules.conditions.get(id, {}).duplicate(true)
	var condition_changed := false
	var move_changed := false
	for field in draft:
		if not String(field).begins_with("condition_") and draft[field] != _saved[key][field]: move_changed = true
	for field in ["min", "max", "angle", "half_angle"]:
		if draft.has("condition_" + field):
			gate[field] = draft["condition_" + field]
			condition_changed = condition_changed or draft["condition_" + field] != _saved[key]["condition_" + field]
	if condition_changed:
		rules.conditions[id] = gate
		var rules_error := ResourceSaver.save(rules, _rules_paths[key])
		if rules_error != OK:
			_tuning_status.text = "発動条件を保存できません: " + error_string(rules_error)
			return
	if move_changed:
		var error := ResourceSaver.save(saved, path)
		if error != OK:
			_tuning_status.text = "技の値を保存できません: " + error_string(error)
			return
	_saved[key] = _drafts[key].duplicate(true)
	_source_hashes[key] = FileAccess.get_sha256(path)
	_rules_hashes[key] = FileAccess.get_sha256(_rules_paths[key])
	_update_tuning_status(key)
	_tuning_status.text = "保存しました。次の再生から反映します。"

func _request_tuning_revert() -> void:
	if _tuning_dirty(_current_tuning_key()): _tuning_revert_dialog.popup_centered()
	else: _revert_tuning()

func _revert_tuning() -> void:
	var key := _current_tuning_key()
	if not _source_paths.has(key): return
	var path: String = _source_paths[key]
	var move: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if move == null or not move.get("parameters") is Dictionary:
		_tuning_status.text = "保存済みの技を読み直せません。"
		return
	var values := _capture_editable(move)
	var rules: Resource = ResourceLoader.load(_rules_paths[key], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if rules == null:
		_tuning_status.text = "保存済みの発動条件を読み直せません。"
		return
	values.merge(_capture_conditions(rules, _selected_technique()))
	_saved[key] = values
	_drafts[key] = values.duplicate(true)
	_source_hashes[key] = FileAccess.get_sha256(path)
	_rules_hashes[key] = FileAccess.get_sha256(_rules_paths[key])
	_rebuild_tuning_fields(key, _selected_move())
	_update_tuning_status(key)
	_tuning_status.text = "保存済みの値を読み直しました。次の再生から反映します。"

func _switch_target(index: int) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and _tuning_panel.is_ancestor_of(focus): focus.release_focus()
	var target: Dictionary = _target_picker.get_item_metadata(index)
	var id := String(target.get("id", ""))
	var dirty := _first_dirty_key()
	if not dirty.is_empty() and (id != _target_id or not bool(target.get("boss", false))):
		_select_target(_target_id, _target_boss)
		for move_index in _move_picker.item_count:
			if String(_move_picker.get_item_metadata(move_index)) == dirty.get_slice("/", 1):
				_move_picker.select(move_index)
				break
		_refresh_tuning_selection()
		workspace.show_tuning(_tuning_panel)
		_tuning_status.text = "未保存の技があります。保存か「元に戻す」を選んでください。"
		return
	if id.is_empty():
		await _activate_enemy_mode()
	elif not target.get("boss", false):
		await _activate_enemy(id)
	else:
		await _activate_boss(id)

func _activate_enemy_mode() -> void:
	_switch_serial += 1
	_switching = true
	_finish_manual()
	_target_id = ""
	_target_boss = false
	preview_actor = null
	_technique_row.hide()
	_manual_status.hide()
	_manual_message.hide()
	workspace.hide_tuning()
	_tuning_toggle.hide()
	await session.reset()
	_target_picker.select(0)
	_set_mode(1)
	_switching = false
	_refresh()

func _activate_enemy(id: String) -> void:
	if not ContentManager.enemies.has(StringName(id)): return
	_switch_serial += 1
	var serial := _switch_serial
	_switching = true
	_finish_manual()
	_target_id = ""
	_target_boss = false
	preview_actor = null
	_technique_row.hide()
	_manual_status.hide()
	_manual_message.hide()
	workspace.hide_tuning()
	_tuning_toggle.hide()
	await session.reset({"empty": true, "stage": int(session.spec.get("stage", 1)), "invincible": true,
		"director": {"enabled": false}})
	if serial != _switch_serial: return
	session.perform("spawn", {"type": id, "pos": [0, 0]})
	_target_id = id
	_select_target(id, false)
	_switching = false
	_set_mode(3)
	_refresh()

func _activate_boss(id: String, selected := "", preview_program := "") -> void:
	if not ContentManager.bosses.has(StringName(id)):
		_manual_message.text = "登録されていないボスです: " + id
		_manual_message.show()
		return
	_switch_serial += 1
	var serial := _switch_serial
	_switching = true
	workspace.hide_tuning()
	_finish_manual()
	_target_id = ""
	_target_boss = false
	preview_actor = null
	if selected.is_empty(): _repeat_id = ""
	var stage: int = {"hydra": 4, "draco": 5, "centaurus": 2, "canis_major": 3}.get(id, 1)
	var settings := {"empty": true, "stage": stage, "ship_pos": [400, 0] if id == "hydra" else [500, 0],
		"invincible": true, "director": {"enabled": false}}
	if id == "hydra":
		settings["hero"] = "hercules"
		settings["config"] = {"base_attack": ContentManager.base.base_attack * 6.0}
	await session.reset(settings)
	if serial != _switch_serial: return
	var path := preview_program if not preview_program.is_empty() else "res://.content/boss_%s.tres" % id
	if not ResourceLoader.exists(path):
		_manual_message.text = "実行用のボスデータがありません: " + path
		_manual_message.show()
		_switching = false
		return
	var program: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if program == null or program.get("data") is not Dictionary or program.data.get("rules") == null or program.data.get("flow") == null:
		_manual_message.text = "実行用の技・フローリソースがありません。"
		_manual_message.show()
		_switching = false
		return
	var adapter := String(program.data.rules.adapter)
	if adapter != id and not (id == "hydra" and adapter.is_empty()):
		_manual_message.text = "選択ボスと実行用データが一致しません。"
		_manual_message.show()
		_switching = false
		return
	var data_error := _normalize_preview_program(program, id)
	if not data_error.is_empty():
		_manual_message.text = data_error
		_manual_message.show()
		_switching = false
		return
	var combo_request: bool = not selected.is_empty() and program.data.rules.combos.has(selected)
	if combo_request: _single_candidate_program(program, selected)
	session.perform("boss", {"type": id, "pos": [0, 0]})
	preview_actor = session.run.bosses.actor
	if preview_actor == null:
		_switching = false
		return
	preview_actor.configure_flow(program)
	_prefer_preview_values = not preview_program.is_empty() and not path.ends_with("boss_%s.tres" % id)
	if combo_request and id == "monoceros": _prepare_monoceros_combo(program.data.rules, selected)
	_current_program_path = path
	if id != "hydra":
		var debugger := MANUAL.new()
		if debugger.bind(preview_actor): manual = debugger
	_target_id = id
	_target_boss = true
	_select_target(id, true)
	_populate_moves(selected)
	_technique_row.visible = id == "hydra" or manual != null
	_manual_status.hide()
	_manual_message.hide()
	_phase_picker.visible = id != "hydra"
	_refresh_tuning_selection()
	_execute.tooltip_text = "選択した技を最初から再生します。変更は試遊中だけです。"
	_switching = false
	_set_mode(3)
	_refresh()
	if not selected.is_empty() and not combo_request: _execute_selected()
	elif combo_request: _manual_message.hide()

func _select_target(id: String, boss: bool) -> void:
	for index in _target_picker.item_count:
		var target: Variant = _target_picker.get_item_metadata(index)
		if target is Dictionary and String(target.get("id", "")) == id and bool(target.get("boss", false)) == boss:
			_target_picker.select(index)
			return

func _single_candidate_program(program: Resource, selected: String) -> void:
	# ボス行動エディターのコンボ試遊と同じ一候補フロー。生成物だけを変える。
	var rules: Resource = program.data.rules
	for id in rules.node_ids():
		var source: String = rules.source_for(id)
		var binding: Dictionary = rules.graph_nodes.get(id, {}).duplicate()
		binding.source = source
		binding.connected = source == selected
		rules.graph_nodes[id] = binding
	var flow: Resource = program.data.flow
	flow.maximum_stamina = maxf(20.0, float(rules.costs.get(selected, 1.0)))
	flow.sections = [{"name": "選択した技", "request": "any", "cap": flow.maximum_stamina, "next": 1,
		"weights": {"single": 100.0, "combo": 100.0, "major": 100.0}},
		{"name": "再生完了", "request": "any", "cap": flow.maximum_stamina, "next": 1, "weights": {}}]

func _first_combo_action(step: Dictionary) -> String:
	if step.get("type", "") == "action": return String(step.get("id", ""))
	for child in step.get("children", []):
		if child is Dictionary:
			var action := _first_combo_action(child)
			if not action.is_empty(): return action
	return ""

func _prepare_monoceros_combo(rules: Resource, selected: String) -> void:
	var first := _first_combo_action(rules.combos[selected])
	if first.is_empty(): return
	var combo_gate: Dictionary = rules.conditions.get(selected, {})
	var first_gate: Dictionary = rules.conditions.get(first, {})
	var minimum := maxf(float(combo_gate.get("min", 0.0)), float(first_gate.get("min", 0.0)))
	var maximum := minf(float(combo_gate.get("max", INF)), float(first_gate.get("max", INF)))
	if maximum < minimum: return
	var distance := (minimum + maxf(minimum, minf(maximum, 1400.0))) * 0.5
	var angle := deg_to_rad(float(first_gate.get("angle", combo_gate.get("angle", 0.0))))
	var origin: Vector2 = preview_actor.table.pos[preview_actor.body]
	var point := origin + Vector2.from_angle(preview_actor.table.facing[preview_actor.body] + angle) * distance
	preview_actor.phase = maxi(int(combo_gate.get("min_phase", 1)), int(first_gate.get("min_phase", 1)))
	preview_actor._cooldown = 0.0
	preview_actor.reposition = 0.0
	session.pinned = point
	session.run.state.ship_pos = point
	session.run.state.enemy_aim = point
	session.run.state.view_center = point

func _finish_manual() -> void:
	if manual != null: manual.finish()
	manual = null

func _populate_moves(selected := "") -> void:
	_phase_picker.clear()
	for phase in (3 if _target_id == "draco" else 2):
		_phase_picker.add_item("形態 %d" % (phase + 1), phase + 1)
	_move_picker.clear()
	if preview_actor.action_rules == null: return
	for move in preview_actor.action_rules.techniques:
		var id := String(move.technique)
		var index := _move_picker.item_count
		_move_picker.add_item(TECHNIQUE_GRAPH.technique_title(preview_actor.action_rules if is_instance_valid(preview_actor) else null, id) + " · " + id)
		_move_picker.set_item_metadata(index, id)
		if id == selected:
			_move_picker.select(index)
			_phase_picker.select(clampi(int(preview_actor.action_rules.conditions.get(id, {}).get("min_phase", 1)) - 1, 0, _phase_picker.item_count - 1))
	for id in preview_actor.action_rules.combos:
		var index := _move_picker.item_count
		_move_picker.add_item("コンボ · " + String(id))
		_move_picker.set_item_metadata(index, String(id))
		if id == selected: _move_picker.select(index)
	if _move_picker.item_count > 0 and selected.is_empty(): _move_picker.select(0)

func _execute_selected() -> void:
	if _switching or _move_picker.selected < 0 or not is_instance_valid(preview_actor): return
	_clear_trial_input()
	var id := String(_move_picker.get_selected_metadata())
	if _target_boss and not preview_actor.action_rules.combos.has(id):
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null and _tuning_panel.is_ancestor_of(focus): focus.release_focus()
		_apply_tuning_preview()
	if preview_actor.action_rules.combos.has(id):
		await _activate_boss(_target_id, id, _current_program_path)
		_repeat_id = id if is_instance_valid(preview_actor) else ""
		_repeat_wait = REPEAT_GAP
		return
	# 手動実行に対応していないボスは、通常AIの試遊を続ける。
	if _target_id != "hydra" and manual == null:
		_manual_message.text = "この技は手動再生できません。"
		_manual_message.show()
		return
	var started := false
	if _target_id == "hydra":
		started = _execute_hydra(id)
	elif manual != null:
		started = manual.execute(id, _phase_picker.get_selected_id())
	if started:
		session.playing = true
		_manual_message.hide()
		_repeat_id = id
		_repeat_wait = REPEAT_GAP
	else:
		_repeat_id = ""
		_manual_message.text = "実行できません: " + id if _target_id == "hydra" else manual.message
		_manual_message.show()

## 再生した技が終わったら、少し間を置いて同じ技を最初から撃ち直す。
func _tick_repeat(delta: float) -> void:
	if _repeat_id.is_empty() or not session.playing: return
	if not _repeat_finished():
		_repeat_wait = REPEAT_GAP
		return
	_repeat_wait -= delta
	if _repeat_wait > 0.0: return
	_repeat_wait = REPEAT_GAP
	if preview_actor.action_rules.combos.has(_repeat_id):
		var combo := _repeat_id
		await _activate_boss(_target_id, combo, _current_program_path)
		_repeat_id = combo if is_instance_valid(preview_actor) else ""
		return
	if _repeat_id == _selected_technique(): _apply_tuning_preview()
	var started: bool = _execute_hydra(_repeat_id) if _target_id == "hydra" else manual != null and manual.execute(_repeat_id, _phase_picker.get_selected_id())
	if not started:
		_manual_message.text = "繰り返しを止めました: " + (_repeat_id if _target_id == "hydra" or manual == null else manual.message)
		_manual_message.show()
		_repeat_id = ""

func _repeat_finished() -> bool:
	if preview_actor.action_rules.combos.has(_repeat_id):
		var adapter = preview_actor.flow_adapter
		return preview_actor.flow_runner.index >= 1 and not preview_actor.attack_playing() and (adapter == null or not adapter.running())
	if _target_id == "hydra":
		return not preview_actor.busy and preview_actor.necks.all(func(n): return n.mode == &"idle")
	return not preview_actor.attack_playing()

func _execute_hydra(id: String) -> bool:
	var actor = preview_actor
	if not actor.has_body() or actor.action_rules == null: return false
	actor.interrupt_tech()
	actor._set_count(8)
	actor._tech_cd = 0.0
	actor.combo_wait = 0.0
	actor.recovery_t = 0.0
	if id in ["grid", "swarm"] and not actor.separated: actor.begin_separation()
	for neck in actor.necks: neck.cd = 0.0
	_position_for_hydra(id)
	var move: Resource = actor._moves.get(StringName(id))
	if move == null: return false
	var started := false
	if move.head_kind != &"":
		var neck = actor._first(move.head_kind)
		started = neck != null and actor.start_normal(actor.necks.find(neck), StringName(id))
	else:
		started = actor.try_start_tech(StringName(id), 1.0)
	if started: actor.hsm.set_active(false)
	return started

func _position_for_hydra(id: String) -> void:
	var actor = preview_actor
	var gate: Dictionary = actor.action_rules.conditions.get(id, {})
	var distance := (float(gate.get("min", 0.0)) + minf(1400.0, float(gate.get("max", 600.0)))) * 0.5
	var origin := Vector2.ZERO
	var move: Resource = actor._moves.get(StringName(id))
	if move != null and move.head_kind != &"":
		var neck = actor._first(move.head_kind)
		if neck != null:
			actor.table.facing[actor.body] = -neck.base_angle
			neck.angle = 0.0
			neck.length = float(actor.def.params.neck_rest)
			origin = actor._head_pos(neck) if int(gate.get("distance_origin", 0)) == 1 else actor._neck_base(neck)
	var point := origin + Vector2.from_angle(deg_to_rad(float(gate.get("angle", 0.0)))) * distance
	session.pinned = point
	session.run.state.ship_pos = point
	session.run.state.enemy_aim = point
	session.run.state.view_center = point
	session.run.loadout.reset_loadout()

func _return_to_ai() -> void:
	_repeat_id = ""
	_finish_manual()
	if _target_id == "hydra" and is_instance_valid(preview_actor):
		preview_actor.interrupt_tech()
		preview_actor.hsm.set_active(true)
	if StringName(_target_id) in MANUAL.BOSSES and is_instance_valid(preview_actor):
		manual = MANUAL.new()
		manual.bind(preview_actor)
	_clear_trial_input()
	_manual_message.hide()

func _clear_trial_input() -> void:
	if not is_instance_valid(session.run): return
	session.run.input.cancel_gesture()
	session._intent = Intent.new()
	session._route_play.clear()

func _hitstop_target() -> Dictionary:
	if not _target_id.is_empty():
		return {"id": _target_id, "boss": _target_boss}
	return super._hitstop_target()

func _reset() -> void:
	if not _target_id.is_empty():
		if _target_boss: await _activate_boss(_target_id)
		else: await _activate_enemy(_target_id)
	else:
		await super._reset()

func _process(delta: float) -> void:
	super(delta)
	if _target_id.is_empty() or not _target_boss or _switching or not is_instance_valid(preview_actor): return
	if _target_id != "hydra" and manual == null: return
	_tick_repeat(delta)
	if manual != null:
		var selected := String(_move_picker.get_selected_metadata()) if _move_picker.selected >= 0 else ""
		var reason: String = "" if preview_actor.action_rules.combos.has(selected) else manual.unavailable(selected, _phase_picker.get_selected_id()) if not selected.is_empty() else "登録技なし"
		_execute.disabled = not reason.is_empty()
		_manual_status.text = manual.status() + (" / 再生中" if session.playing else " / 停止中")
		_execute.tooltip_text = reason if not reason.is_empty() else _manual_status.text
	else:
		_execute.disabled = _move_picker.selected < 0 or not preview_actor.has_body()
		_manual_status.text = "Hydra / %s / %s" % ["再生中" if session.playing else "停止中", String(preview_actor.tech)]
		_execute.tooltip_text = _manual_status.text

func _exit_tree() -> void:
	_finish_manual()
