## 敵・ルート・ボスを同じ実験場で扱う。旧ボス試遊シーンもこの画面をボス選択済みで開く。
extends "res://gyms/enemy_lab/enemy_lab.gd"

const MANUAL := preload("res://gyms/boss_technique_debug.gd")
const TECHNIQUE_GRAPH := preload("res://tools/editor/boss_flow/technique_graph.gd")

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
	_label(target_row, "試遊対象")
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
	_technique_row = HFlowContainer.new()
	panel.add_child(_technique_row)
	_label(_technique_row, "ボス技")
	_phase_picker = OptionButton.new()
	_technique_row.add_child(_phase_picker)
	_move_picker = OptionButton.new()
	_move_picker.custom_minimum_size.x = 190
	_move_picker.fit_to_longest_item = false
	_move_picker.clip_text = true
	_technique_row.add_child(_move_picker)
	_execute = _button(_technique_row, "選択した技を実行", _execute_selected)
	_button(_technique_row, "通常AIへ戻す", _return_to_ai)
	_manual_status = _label(panel, "")
	_manual_message = _label(panel, "")
	for label in [_manual_status, _manual_message]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_technique_row.hide()
	_manual_status.hide()
	_manual_message.hide()

func _switch_target(index: int) -> void:
	var target: Dictionary = _target_picker.get_item_metadata(index)
	var id := String(target.get("id", ""))
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
	if not ContentManager.bosses.has(StringName(id)): return
	_switch_serial += 1
	var serial := _switch_serial
	_switching = true
	_finish_manual()
	_target_id = ""
	_target_boss = false
	preview_actor = null
	var stage := 4 if id == "hydra" else 5 if id == "draco" else 1
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
	var combo_request: bool = not selected.is_empty() and program.data.rules.combos.has(selected)
	if combo_request: _single_candidate_program(program, selected)
	session.perform("boss", {"type": id, "pos": [0, 0]})
	preview_actor = session.run.bosses.actor
	if preview_actor == null:
		_switching = false
		return
	preview_actor.configure_flow(program)
	_current_program_path = path
	if id != "hydra":
		manual = MANUAL.new()
		manual.bind(preview_actor)
	_target_id = id
	_target_boss = true
	_select_target(id, true)
	_populate_moves(selected)
	_technique_row.show()
	_manual_status.show()
	_manual_message.show()
	_phase_picker.visible = id != "hydra"
	_manual_message.text = "選択した技を実行できます。変更は試遊中だけです。"
	_switching = false
	_set_mode(3)
	_refresh()
	if not selected.is_empty() and not combo_request: _execute_selected()
	elif combo_request: _manual_message.text = "選択コンボを通常AIで再生中: " + selected

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

func _finish_manual() -> void:
	if manual != null: manual.finish()
	manual = null

func _populate_moves(selected := "") -> void:
	_phase_picker.clear()
	for phase in (2 if _target_id == "monoceros" else 3):
		_phase_picker.add_item("形態 %d" % (phase + 1), phase + 1)
	_move_picker.clear()
	if preview_actor.action_rules == null: return
	for move in preview_actor.action_rules.techniques:
		var id := String(move.technique)
		var index := _move_picker.item_count
		_move_picker.add_item(TECHNIQUE_GRAPH.title_for(id) + " · " + id)
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
	if preview_actor.action_rules.combos.has(id):
		await _activate_boss(_target_id, id, _current_program_path)
		return
	var started := false
	if _target_id == "hydra":
		started = _execute_hydra(id)
	elif manual != null:
		started = manual.execute(id, _phase_picker.get_selected_id())
	if started:
		session.playing = true
		_manual_message.text = "実行: " + id
	else:
		_manual_message.text = "実行できません: " + id if _target_id == "hydra" else manual.message

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
	if move.head_kind != &"":
		var neck = actor._first(move.head_kind)
		return neck != null and actor.start_normal(actor.necks.find(neck), StringName(id))
	return actor.try_start_tech(StringName(id), 1.0)

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
	_finish_manual()
	if _target_id in ["monoceros", "draco"] and is_instance_valid(preview_actor):
		manual = MANUAL.new()
		manual.bind(preview_actor)
	_clear_trial_input()
	_manual_message.text = "通常AIへ戻しました。"

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
	if manual != null:
		var selected := String(_move_picker.get_selected_metadata()) if _move_picker.selected >= 0 else ""
		var reason: String = "" if preview_actor.action_rules.combos.has(selected) else manual.unavailable(selected, _phase_picker.get_selected_id()) if not selected.is_empty() else "登録技なし"
		_execute.disabled = not reason.is_empty()
		_manual_status.text = manual.status() + (" / 再生中" if session.playing else " / 停止中")
		if not reason.is_empty(): _manual_message.text = reason
	else:
		_execute.disabled = _move_picker.selected < 0 or not preview_actor.has_body()
		_manual_status.text = "Hydra / %s / %s" % ["再生中" if session.playing else "停止中", String(preview_actor.tech)]

func _exit_tree() -> void:
	_finish_manual()
