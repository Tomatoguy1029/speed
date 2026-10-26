## 編集したボスと一つの技を、本番と同じ実験セッションで再生する。
extends "res://gyms/enemy_lab/enemy_lab.gd"
var preview_actor: BossActor
var preview_technique := ""
var manual: RefCounted
var _boss_picker: OptionButton
var _phase_picker: OptionButton
var _move_picker: OptionButton
var _execute: Button
var _manual_status: Label
var _manual_message: Label
var _switching := false

func _ready() -> void:
	await super._ready()
	var request: Dictionary = get_meta("preview_request", {})
	if request.is_empty() and FileAccess.file_exists("res://.content/boss_preview.json"):
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.content/boss_preview.json"))
		if loaded is Dictionary: request = loaded
	var boss_id: String = request.get("boss", "monoceros")
	preview_technique = request.get("technique", "")
	var program_path: String = get_meta("preview_program", "res://.content/boss_preview.tres" if not request.is_empty() else "res://.content/boss_monoceros.tres")
	if not ResourceLoader.exists(program_path):
		_messages.text = "実行用のボスデータがありません。ボス行動画面から再生してください。"
		return
	var program: Resource = ResourceLoader.load(program_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if program == null:
		push_error("試遊データがありません。ボス行動画面から再生してください。")
		return
	if program.get("data") is not Dictionary or program.data.get("rules") == null or program.data.get("flow") == null:
		_messages.text = "実行用の技・フローリソースがありません。"
		return
	var adapter := String(program.data.rules.adapter)
	if adapter != boss_id and not (boss_id == "hydra" and adapter.is_empty()):
		_messages.text = "選択ボスと実行用データが一致しません。ボス行動画面から再生成してください。"
		return
	await session.reset({"empty": true, "stage": 4 if boss_id == "hydra" else 5 if boss_id == "draco" else 1, "ship_pos": [500, 0], "invincible": true, "director": {"enabled": false}})
	session.perform("boss", {"type": boss_id, "pos": [0, 0]})
	preview_actor = session.run.bosses.actor
	if preview_actor == null: return
	if boss_id in ["monoceros", "draco"] and not program.data.rules.combos.has(preview_technique):
		preview_actor.configure_flow(program)
		manual = preload("res://gyms/boss_technique_debug.gd").new()
		manual.bind(preview_actor)
		_build_manual_ui(boss_id)
		_populate_moves(preview_technique)
		_set_mode(3)
		if not preview_technique.is_empty(): _execute_selected()
		set_meta("preview_ready", true)
		return
	if not preview_technique.is_empty():
		# 編集元を変更せず、選んだ技だけが一度候補になる実験用フローを作る。
		var rules: Resource = program.data.rules
		for id in rules.node_ids():
			var source: String = rules.source_for(id)
			var binding: Dictionary = rules.graph_nodes.get(id, {}).duplicate()
			binding.source = source
			binding.connected = source == preview_technique
			rules.graph_nodes[id] = binding
		var flow: Resource = program.data.flow
		flow.maximum_stamina = maxf(20.0, float(rules.costs.get(preview_technique, 1.0)))
		flow.sections = [{"name": "選択した技", "request": "any", "cap": flow.maximum_stamina, "next": 1, "weights": {"single": 100.0, "combo": 100.0, "major": 100.0}}, {"name": "再生完了", "request": "any", "cap": flow.maximum_stamina, "next": 1, "weights": {}}]
	preview_actor.configure_flow(program)
	if not preview_technique.is_empty(): _position_for_technique(boss_id, program.data.rules)
	_set_mode(3)
	_refresh()
	set_meta("preview_ready", true)

func _position_for_technique(boss_id: String, rules: Resource) -> void:
	var gate: Dictionary = rules.conditions.get(preview_technique, {})
	var distance := (float(gate.get("min", 0.0)) + minf(1400.0, float(gate.get("max", 600.0)))) * 0.5
	var angle := deg_to_rad(float(gate.get("angle", 0.0)))
	var origin := Vector2.ZERO
	if boss_id == "hydra":
		preview_actor._set_count(8)
		preview_actor._tech_cd = 0.0
		preview_actor.combo_wait = 0.0
		if preview_technique in ["grid", "swarm"]: preview_actor.begin_separation()
		for neck in preview_actor.necks: neck.cd = 0.0
		var move: Resource = preview_actor._moves.get(StringName(preview_technique))
		if move != null and move.head_kind != &"":
			var neck = preview_actor._first(move.head_kind)
			preview_actor.table.facing[preview_actor.body] = -neck.base_angle
			neck.angle = 0.0
			neck.length = float(preview_actor.def.params.neck_rest)
			origin = preview_actor._head_pos(neck) if int(gate.get("distance_origin", 0)) == 1 else preview_actor._neck_base(neck)
	else:
		preview_actor.phase = int(gate.get("min_phase", 1))
		preview_actor._cooldown = 0.0
	var point := origin + Vector2.from_angle(angle) * distance
	session.pinned = point
	session.run.state.ship_pos = point
	session.run.state.enemy_aim = point
	session.run.state.view_center = point
	session.run.loadout.reset_loadout()

func _build_manual_ui(boss_id: String) -> void:
	_boss_picker = OptionButton.new()
	_phase_picker = OptionButton.new()
	_move_picker = OptionButton.new()
	_execute = Button.new()
	_manual_status = Label.new()
	_manual_message = Label.new()
	get_window().title = "SPEED — ボス技テスト"
	var layout: Node = workspace._vertical_split.get_parent()
	var panel := VBoxContainer.new()
	layout.add_child(panel)
	layout.move_child(panel, 1)
	var row := HFlowContainer.new()
	panel.add_child(row)
	_label(row, "ボス技テスト")
	_boss_picker.add_item("Stage 1 · Monoceros")
	_boss_picker.add_item("Stage 5 · Draco")
	_boss_picker.select(0 if boss_id == "monoceros" else 1)
	row.add_child(_boss_picker)
	_boss_picker.item_selected.connect(_switch_boss)
	row.add_child(_phase_picker)
	row.add_child(_move_picker)
	_execute.text = "実行"
	_execute.pressed.connect(_execute_selected)
	row.add_child(_execute)
	_button(row, "停止 / 再開", func():
		session.playing = not session.playing
		_clear_trial_input())
	_button(row, "通常AIへ戻す", func():
		manual.finish()
		_clear_trial_input())
	_button(row, "終了", func():
		manual.finish()
		get_tree().quit())
	panel.add_child(_manual_status)
	panel.add_child(_manual_message)
	_manual_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_manual_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint := _label(panel, "実行で現在の技を中断し、射程内へ配置して再生。抽選・CDを省略／実際の命中判定／自機無敵（実験場設定）")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 単独試遊では配置・履歴操作を閉じ、手動実行の状態と巻き戻しを混在させない。
	layout.get_child(0).hide()
	_left.hide()
	_right.hide()
	workspace._left_toggle.hide()
	workspace._right_toggle.hide()
	workspace._center.get_child(0).hide()
	workspace._transport_panel.hide()
	workspace._transport_tab.hide()
	_move_picker.item_selected.connect(func(_index): _clear_trial_input())
	_phase_picker.item_selected.connect(func(_index): _clear_trial_input())
	# ポーズ中・UI操作中の押下を次のゲーム更新へ持ち越さない。
	session.live_input = func():
		if not game_frame.get_global_rect().has_point(get_global_mouse_position()) or get_viewport().gui_get_focus_owner() != game_frame:
			session.run.input.cancel_gesture()
			return Intent.new()
		return session.run.input.poll()

func _populate_moves(selected := "") -> void:
	_phase_picker.clear()
	for phase in (2 if preview_actor.def.id == &"monoceros" else 3):
		_phase_picker.add_item("形態 %d" % (phase + 1), phase + 1)
	_move_picker.clear()
	for move in manual.moves():
		var id := String(move.technique)
		_move_picker.add_item(preload("res://tools/editor/boss_flow/technique_graph.gd").title_for(id) + " · " + id)
		_move_picker.set_item_metadata(_move_picker.item_count - 1, id)
		if id == selected:
			_move_picker.select(_move_picker.item_count - 1)
			_phase_picker.select(int(preview_actor.action_rules.conditions.get(id, {}).get("min_phase", 1)) - 1)
	if not selected.is_empty() and not manual.moves().any(func(move): return String(move.technique) == selected):
		_move_picker.add_item("未登録: " + selected)
		_move_picker.set_item_metadata(_move_picker.item_count - 1, selected)
		_move_picker.select(_move_picker.item_count - 1)

func _switch_boss(index: int) -> void:
	if _switching: return
	_switching = true
	session.playing = false
	manual.finish()
	var id := "monoceros" if index == 0 else "draco"
	var path := "res://.content/boss_%s.tres" % id
	if not ResourceLoader.exists(path):
		manual.message = "実行用データなし: " + path
		_boss_picker.select(0 if preview_actor.def.id == &"monoceros" else 1)
		_switching = false
		return
	await session.reset({"empty": true, "stage": 1 if index == 0 else 5, "ship_pos": [500, 0], "invincible": true, "director": {"enabled": false}})
	session.perform("boss", {"type": id, "pos": [0, 0]})
	preview_actor = session.run.bosses.actor
	preview_actor.configure_flow(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP))
	_boss_picker.select(index)
	manual = preload("res://gyms/boss_technique_debug.gd").new()
	manual.bind(preview_actor)
	_populate_moves()
	_switching = false
	_clear_trial_input()

func _clear_trial_input() -> void:
	session.run.input.cancel_gesture()
	session._intent = Intent.new()
	session._route_play.clear()

func _execute_selected() -> void:
	if _switching or _move_picker.selected < 0: return
	_clear_trial_input()
	if manual.execute(String(_move_picker.get_selected_metadata()), _phase_picker.get_selected_id()):
		session.playing = true

func _process(delta: float) -> void:
	super(delta)
	if manual == null or _switching: return
	if not session.playing: _clear_trial_input()
	var reason: String = manual.unavailable(String(_move_picker.get_selected_metadata()), _phase_picker.get_selected_id()) if _move_picker.selected >= 0 else "登録技なし"
	_execute.disabled = not reason.is_empty()
	_manual_status.text = manual.status() + (" / 再生中" if session.playing else " / 停止中")
	_manual_message.text = reason if not reason.is_empty() else manual.message

func _exit_tree() -> void:
	if manual != null: manual.finish()
