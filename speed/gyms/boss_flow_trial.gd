## 編集したボスと一つの技を、本番と同じ実験セッションで再生する。
extends "res://gyms/enemy_lab/enemy_lab.gd"
var preview_actor: BossActor
var preview_technique := ""

func _ready() -> void:
	await super._ready()
	var request: Dictionary = get_meta("preview_request", {})
	if request.is_empty() and FileAccess.file_exists("res://.content/boss_preview.json"):
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.content/boss_preview.json"))
		if loaded is Dictionary: request = loaded
	var boss_id: String = request.get("boss", "hydra")
	preview_technique = request.get("technique", "")
	var program_path: String = get_meta("preview_program", "res://.content/boss_preview.tres")
	var program: Resource = ResourceLoader.load(program_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if program == null:
		push_error("試遊データがありません。ボス行動画面から再生してください。")
		return
	await session.reset({"empty": true, "stage": 4 if boss_id == "hydra" else 1, "ship_pos": [500, 0], "invincible": true, "director": {"enabled": false}})
	session.perform("boss", {"type": boss_id, "pos": [0, 0]})
	preview_actor = session.run.bosses.actor
	if preview_actor == null: return
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
