## 選択は共通フロー、形態と技の実行は個別ロジックで進める。
## 予告・固定・発進・終了はAnimationPlayerで進め、本体は全方向から攻撃できる。
class_name MonocerosBoss
extends "res://scripts/bosses/boss_final_strike.gd"

signal presentation_event(event: Dictionary)
signal presentation_advanced(world_dt: float)
@export var presentation_scene: PackedScene

var phase := 1
var phase_pending := false
var mode: StringName = &"idle"
var technique: StringName = &""
var clock := 0.0
var recovery := 0.0
var phase_time := 0.0
var locked := false
var aim_point := Vector2.ZERO
var direction := Vector2.RIGHT
var passes_left := 0
var combo_pending := false
var cooldowns: Dictionary = {}
var stuck_body: FieldSystem.Body
var stuck_offset := Vector2.ZERO
var stuck_time := 0.0
var reposition := 0.0
var reposition_direction := Vector2.ZERO
var turn_motion := 0.0
var attack_hit := false
var previous_ship := Vector2.ZERO
var previous_horn := PackedVector2Array()
## 攻撃後の姿勢戻し。終わった姿勢で hold 秒止まり、return_speed で正面の姿勢へ戻ってから recover の隙に入る。
var settle_at := -1.0
var settle_hold := 0.0
var settle_return := 0.0
var _defeated := false
var _presentation: Node
var entrance_time := 0.0
var entrance_from := Vector2.ZERO
var entrance_target := Vector2.ZERO
var _cooldown := 0.0
var selection_enabled := true
var action_rules: Resource
var flow_runner := preload("res://scripts/bosses/flow/runner.gd").new()
var flow_adapter: RefCounted
var _moves := {}
var _move_kinds := {}
var _runner: RefCounted
var technique_visuals := preload("res://scripts/bosses/technique_visuals.gd").new()

func configure_flow(program: Resource) -> void:
	action_rules = program.data.rules
	_moves.clear()
	_move_kinds.clear()
	for move in action_rules.techniques:
		_moves[move.technique] = move
		_move_kinds[move.technique] = move.make_runner().kind()
	technique_visuals.configure(self, _moves)
	flow_runner.configure(program.data.flow)
	flow_runner.selector.random = run_state.rng
	flow_adapter = preload("res://scripts/bosses/flow/single_actor_adapter.gd").new(self)
	selection_enabled = true

func _on_bound() -> void:
	draws_self = true
	table.gate[body] = EnemyTable.Gate.NONE
	timeline.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	var library := timeline.get_animation_library("").duplicate(true) as AnimationLibrary
	timeline.remove_animation_library("")
	timeline.add_animation_library("", library)
	configure_flow(load("res://.content/boss_monoceros.tres"))
	previous_ship = run_state.ship_pos
	_cooldown = float(def.params.initial_wait)
	if presentation_scene != null:
		_presentation = presentation_scene.instantiate()
		add_child(_presentation)
		_presentation.bind_monoceros(self)
	_cue(&"spawned")
	if not run_state.lab_mode: begin_entrance()

func begin_entrance() -> void:
	entrance_target = table.pos[body]
	entrance_from = entrance_target - Vector2(maxf(1000.0, run_state.view_half.x * 2.0), 0.0)
	entrance_time = 0.0
	mode = &"entrance"
	table.pos[body] = entrance_from
	table.facing[body] = 0.0
	_cue(&"entering")

func on_body_damaged() -> void:
	if phase == 1 and table.hp[body] / table.max_hp[body] <= float(def.params.phase_threshold):
		phase_pending = true
	_cue(&"hit")

func handle_body_defeat(_opts: Dictionary) -> bool:
	_stop_combat()
	return false

func _stop_combat() -> void:
	if _defeated: return
	combat_trace.finish("interrupted", "defeated")
	_defeated = true
	if flow_adapter != null: flow_adapter.cancel()
	selection_enabled = false
	timeline.stop()
	mode = &"defeated"
	table.vel[body] = Vector2.ZERO
	table.charge[body] = 0.0
	previous_horn.clear()
	_cue(&"defeated")

func sim_tick(_real_dt: float, dt: float) -> void:
	if dt <= 0.0 or not body_alive(): return
	clock += dt
	table.flash[body] = maxf(0.0, table.flash[body] - dt)
	table.hit_cd[body] = maxf(0.0, table.hit_cd[body] - dt)
	turn_motion = 0.0
	if mode == &"entrance":
		entrance_time += dt
		var duration := maxf(0.05, float(def.params.get("entrance_time", 1.4)))
		var progress := clampf(entrance_time / duration, 0.0, 1.0)
		var before := table.pos[body]
		table.pos[body] = entrance_from.lerp(entrance_target, 1.0 - pow(1.0 - progress, 3.0))
		table.vel[body] = (table.pos[body] - before) / dt
		if progress >= 1.0:
			mode = &"idle"
			table.vel[body] = Vector2.ZERO
			_cue(&"entrance_finished")
	elif final_strike_t >= 0.0:
		_final_strike_tick(dt)
	elif mode == &"stuck":
		stuck_time -= dt
		table.pos[body] = stuck_body.pos + stuck_offset
		if stuck_time <= 0.0:
			mode = &"extract"
			recovery = float(def.params.extract_time)
			_cue(&"extracting")
	elif mode in [&"recovery", &"turnaround", &"extract"]:
		recovery = maxf(0.0, recovery - dt)
		if mode == &"turnaround": _aim(dt)
		if mode == &"extract":
			_move_body(-direction * float(def.params.extract_speed) * dt)
		if recovery <= 0.0:
			if mode == &"turnaround":
				_begin_pass()
			elif combo_pending:
				combo_pending = false
				# 仮連携も、突進後の現在位置から薙ぎが届く時だけ続ける。
				if _close_ready(&"sweep"):
					technique = &"sweep"
					cooldowns[technique] = clock + float(rule().cd)
					_begin_pass()
				else:
					mode = &"recovery"
					recovery = float(rule().recover)
			else:
				combat_trace.finish()
				mode = &"idle"
				technique = &""
	elif mode == &"phase":
		phase_time -= dt
		if phase_time <= 0.0: mode = &"idle"
	elif mode in [&"windup", &"active"]:
		if mode == &"windup" and not locked and _tracks_during_warn(): _aim(dt)
		var prior_mode := mode
		var prior_horn := horn_points()
		# 発進したフレームでは移動を次の固定更新まで待つ。
		if prior_mode == &"active":
			_tick_strike(dt, prior_horn)
		if timeline.is_playing(): timeline.advance(dt)
	else:
		on_body_threshold()
		if phase_pending:
			phase_pending = false
			phase = 2
			mode = &"phase"
			phase_time = float(def.params.phase_time)
			_cue(&"phase_changed")
		else:
			_cooldown = maxf(0.0, _cooldown - dt)
			_reposition_tick(dt)
			if selection_enabled: flow_runner.tick(dt, {"player": run_state.enemy_aim}, flow_adapter)
	table.charge[body] = clampf(timeline.current_animation_position / maxf(float(rule().get("warn", 1.0)), 0.001), 0.0, 1.0) if mode == &"windup" else 0.0
	previous_ship = run_state.ship_pos
	_sync_technique_visuals(dt)
	presentation_advanced.emit(dt)

func on_body_threshold() -> void:
	if phase == 1 and table.hp[body] / table.max_hp[body] <= float(def.params.phase_threshold): phase_pending = true

func rule() -> Dictionary:
	return _moves[technique].values() if _moves.has(technique) else {}

func technique_ready(attack: StringName, gate: Dictionary) -> bool:
	return technique_rejection(attack, gate).is_empty()

func technique_rejection(attack: StringName, gate: Dictionary) -> String:
	if not _moves.has(attack): return "unknown_technique"
	if mode != &"idle": return "busy"
	if _cooldown > 0.0: return "initial_wait"
	if reposition > 0.0: return "repositioning"
	if phase < int(gate.get("min_phase", 1)): return "phase"
	if clock < float(cooldowns.get(attack, 0.0)): return "cooldown"
	var distance := table.pos[body].distance_to(run_state.ship_pos)
	if distance < float(gate.get("min", 0.0)): return "distance_below_min"
	if distance > float(gate.get("max", INF)): return "distance_above_max"
	if distance > _reach(attack): return "out_of_reach"
	if not _gate_allows(gate): return "direction_or_range_gate"
	if tech_kind(attack) != &"kick":
		var r: Dictionary = _moves[attack].values()
		var turn_window := maxf(0.0, float(r.warn) - float(def.params.lock_lead))
		if absf(Geom.angle_diff((run_state.ship_pos - table.pos[body]).angle(), table.facing[body])) > def.turn * turn_window: return "insufficient_turn_time"
	if table.pos[body].distance_to(_strike_aim(attack, float(_moves[attack].values().warn))) > _reach(attack): return "predicted_target_out_of_reach"
	return ""

func _gate_allows(gate: Dictionary) -> bool:
	return preload("res://scripts/bosses/flow/range_condition.gd").allows(gate, (run_state.ship_pos - table.pos[body]).rotated(-table.facing[body]))

func _reach(attack: StringName) -> float:
	var r: Dictionary = _moves[&"charge" if tech_kind(attack) == &"combo" else attack].values()
	return float(r.get("distance", 0.0)) + float(r.get("reach", horn_length())) + float(def.params.horn_width) * 0.5 + ctx.cfg.ship_radius

func _close_ready(attack: StringName) -> bool:
	if not _moves.has(attack): return false
	var gate: Dictionary = action_rules.conditions.get(String(attack), {})
	return clock >= float(cooldowns.get(attack, 0.0)) and phase >= int(gate.get("min_phase", 1)) and _gate_allows(gate) and table.pos[body].distance_to(_strike_aim(attack, float(_moves[attack].values().warn))) <= _reach(attack)

func selection_blocked() -> bool:
	return not body_alive() or not selection_enabled or mode in [&"entrance", &"phase", &"final", &"defeated"]

func can_begin_sequence() -> bool:
	return mode == &"idle" and _cooldown <= 0.0 and reposition <= 0.0

func attack_failed() -> bool:
	return not body_alive() or reposition > 0.0

## 条件評価では攻撃枠を消費しない。
func can_select(attack: StringName, min_phase: int, min_range: float, max_range: float, rear_only: bool) -> bool:
	if mode != &"idle" or _cooldown > 0.0 or reposition > 0.0 or phase < min_phase: return false
	if clock < float(cooldowns.get(attack, 0.0)): return false
	var d := run_state.ship_pos - table.pos[body]
	if d.length() < min_range or d.length() > max_range: return false
	return not rear_only or absf(Geom.angle_diff(d.angle(), table.facing[body] + PI)) < float(def.params.kick_trigger_arc)

func start_attack(attack: StringName) -> bool:
	if mode != &"idle" or not _moves.has(attack):
		combat_trace.event("boss_action", {"step": "start_rejected", "requested_action": String(attack), "reason": "busy" if mode != &"idle" else "unknown_technique", "origin": combat_origin, "action_id": null})
		return false
	var r: Dictionary = _moves[attack].values()
	if not ctx.bosses.admit("boss:" + str(body_id), ["aimed"], body, _attack_length(attack)):
		combat_trace.event("boss_action", {"step": "start_rejected", "requested_action": String(attack), "reason": "attack_budget", "origin": combat_origin, "action_id": null})
		return false
	combat_trace.begin(attack, combat_origin)
	technique = &"charge" if tech_kind(attack) == &"combo" else attack
	cooldowns[attack] = clock + float(r.cd)
	combo_pending = tech_kind(attack) == &"combo"
	passes_left = int(def.params.return_passes) if tech_kind(attack) == &"return_charge" else 1
	_begin_pass()
	return true

## 攻撃予算に申告する長さ。コンボは中の突進・切り返し・薙ぎの予告と実行の合計。
func _attack_length(attack: StringName) -> float:
	if tech_kind(attack) == &"combo":
		var charge: Dictionary = _moves[&"charge"].values()
		var sweep: Dictionary = _moves[&"sweep"].values() if _moves.has(&"sweep") else {}
		return float(charge.warn) + float(charge.active) + float(def.params.combo_gap) + float(sweep.get("warn", 0.0)) + float(sweep.get("active", 0.0))
	var r: Dictionary = _moves[attack].values()
	return float(r.warn) + float(r.active)

func attack_playing() -> bool:
	return mode != &"idle"

func _begin_pass() -> void:
	_runner = _moves[technique].make_runner()
	_runner._begin_pass(self)

func _tracks_during_warn() -> bool:
	return not _moves.has(technique) or _moves[technique].track_during_warn

func _aim(dt: float) -> void:
	_runner_for()._aim(self, dt)

func _strike_aim(attack: StringName = &"", lead := -1.0) -> Vector2:
	return _runner_for()._strike_aim(self, attack, lead)

func lock_aim() -> void:
	_runner_for().lock_aim(self)

func launch_strike() -> void:
	_runner_for().launch_strike(self)

func _path_blocked() -> bool:
	return _runner_for()._path_blocked(self)

func _tick_strike(dt: float, prior: PackedVector2Array) -> void:
	_runner_for()._tick_strike(self, dt, prior)

func end_strike() -> void:
	_runner_for().end_strike(self)

func _begin_settle() -> float:
	return _runner_for()._begin_settle(self)

func settle_progress() -> float:
	if mode != &"recovery" or settle_at < 0.0: return 1.0
	var elapsed := clock - settle_at - settle_hold
	if elapsed < 0.0: return 0.0
	return clampf(elapsed / settle_return, 0.0, 1.0) if settle_return > 0.0 else 1.0

func _reposition_tick(dt: float) -> void:
	if reposition > 0.0:
		reposition = maxf(0.0, reposition - dt)
		_move_body(reposition_direction * def.speed * dt)
		var prior := table.facing[body]
		table.facing[body] = rotate_toward(prior, reposition_direction.angle(), def.turn * dt)
		turn_motion = Geom.angle_diff(table.facing[body], prior) / maxf(dt, 0.001)
	else:
		var toward := run_state.ship_pos - table.pos[body]
		var prior := table.facing[body]
		if not _close_ready(&"kick"):
			table.facing[body] = rotate_toward(prior, toward.angle(), def.turn * dt)
		turn_motion = Geom.angle_diff(table.facing[body], prior) / maxf(dt, 0.001)
		var keep := float(def.params.approach_range)
		var closing := toward.length() > keep
		if not closing and _moves.has(&"charge"):
			closing = table.pos[body].distance_to(_strike_aim(&"charge", float(_moves[&"charge"].values().warn))) > _reach(&"charge")
		if closing:
			# approach_range の距離まで寄って止まり、その内側では向きだけを合わせる。
			var alignment := maxf(0.0, Vector2.from_angle(table.facing[body]).dot(toward.normalized()))
			var travel := float(def.params.approach_speed) * alignment * dt
			if toward.length() > keep:
				travel = minf(travel, toward.length() - keep)
			_move_body(Vector2.from_angle(table.facing[body]) * travel)
		else:
			table.vel[body] = Vector2.ZERO

func _move_body(step: Vector2) -> void:
	var from := table.pos[body]
	table.pos[body] += step
	table.vel[body] = step / maxf(get_physics_process_delta_time(), 0.001)
	ctx.field.collide_enemy(body, from)

func horn_length() -> float:
	return table.r[body] * float(def.params.horn_length_ratio)

## 判定と表示が共有する角／蹄の線分。ワールド座標。
func horn_points(sweep_fraction := -1.0) -> PackedVector2Array:
	return _runner_for().horn_points(self, sweep_fraction)

func warning_points() -> PackedVector2Array:
	return _runner_for().warning_points(self)

func _damage_shape(prior: PackedVector2Array, points: PackedVector2Array) -> void:
	_runner_for()._damage_shape(self, prior, points)

func _hit_ship() -> void:
	_runner_for()._hit_ship(self)

func _cue(cue: StringName) -> void:
	match cue:
		&"telegraph": combat_trace.stage("telegraph")
		&"aim_locked": combat_trace.stage("lock")
		&"attack_started": combat_trace.stage("execute")
		&"recovery_started": combat_trace.stage("recovery")
		&"phase_changed": combat_trace.event("boss_phase", {"reason": "hp_threshold"})
	technique_visuals.event({"cue": cue, "technique": technique})
	presentation_event.emit({"cue": cue, "technique": technique, "phase": phase, "mode": mode,
		"position": table.pos[body], "angle": table.facing[body], "world_time": clock})

func begin_final_strike(charge: float) -> void:
	combat_trace.finish("interrupted", "final_strike_replay")
	combat_trace.stage("replay", {"origin": "final_strike_replay"})
	if flow_adapter != null: flow_adapter.cancel()
	selection_enabled = false
	combo_pending = false
	previous_horn.clear()
	mode = &"final"
	super(charge)
	_cue(&"final_strike")

func cancel_attack() -> void:
	combat_trace.finish("interrupted", "cancelled")
	timeline.stop()
	combo_pending = false
	passes_left = 0
	previous_horn.clear()
	recovery = 0.0
	mode = &"idle"

func _exit_tree() -> void:
	if flow_adapter != null: flow_adapter.cancel()

func _runner_for() -> RefCounted:
	if _runner != null: return _runner
	return preload("res://scripts/bosses/monoceros/technique_runner.gd").new()

func _sync_technique_visuals(dt: float) -> void:
	for node: Node2D in technique_visuals.nodes.values():
		if node.has_method("advance"): node.advance(dt)
	var key := "recover" if mode == &"recovery" else "warn" if mode == &"windup" else "active"
	var elapsed := clock - settle_at if mode == &"recovery" else (timeline.current_animation_position if timeline.is_playing() else 0.0) - (float(rule().get("warn", 0.0)) if mode == &"active" else 0.0)
	technique_visuals.sync(technique, mode, elapsed, float(rule().get(key, 1.0)))

func tech_kind(id: StringName) -> StringName:
	return _move_kinds.get(id, id)
