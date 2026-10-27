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

func configure_flow(program: Resource) -> void:
	action_rules = program.data.rules
	_moves.clear()
	for move in action_rules.techniques: _moves[move.technique] = move
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
		if mode == &"windup" and not locked: _aim(dt)
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
	presentation_advanced.emit(dt)

func on_body_threshold() -> void:
	if phase == 1 and table.hp[body] / table.max_hp[body] <= float(def.params.phase_threshold): phase_pending = true

func rule() -> Dictionary:
	return _moves[technique].parameters if _moves.has(technique) else {}

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
	if attack != &"kick":
		var r: Dictionary = _moves[attack].parameters
		var turn_window := maxf(0.0, float(r.warn) - float(def.params.lock_lead))
		if absf(Geom.angle_diff((run_state.ship_pos - table.pos[body]).angle(), table.facing[body])) > def.turn * turn_window: return "insufficient_turn_time"
	if table.pos[body].distance_to(_strike_aim(attack, float(_moves[attack].parameters.warn))) > _reach(attack): return "predicted_target_out_of_reach"
	return ""

func _gate_allows(gate: Dictionary) -> bool:
	return preload("res://scripts/bosses/flow/range_condition.gd").allows(gate, (run_state.ship_pos - table.pos[body]).rotated(-table.facing[body]))

func _reach(attack: StringName) -> float:
	var r: Dictionary = _moves[&"charge" if attack == &"combo" else attack].parameters
	return float(r.get("distance", 0.0)) + float(r.get("reach", horn_length())) + float(def.params.horn_width) * 0.5 + ctx.cfg.ship_radius

func _close_ready(attack: StringName) -> bool:
	if not _moves.has(attack): return false
	var gate: Dictionary = action_rules.conditions.get(String(attack), {})
	return clock >= float(cooldowns.get(attack, 0.0)) and phase >= int(gate.get("min_phase", 1)) and _gate_allows(gate) and table.pos[body].distance_to(_strike_aim(attack, float(_moves[attack].parameters.warn))) <= _reach(attack)

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
	var r: Dictionary = _moves[attack].parameters
	if not ctx.bosses.admit("boss:" + str(body_id), ["aimed"], body, float(r.warn) + float(r.active)):
		combat_trace.event("boss_action", {"step": "start_rejected", "requested_action": String(attack), "reason": "attack_budget", "origin": combat_origin, "action_id": null})
		return false
	combat_trace.begin(attack, combat_origin)
	technique = &"charge" if attack == &"combo" else attack
	cooldowns[attack] = clock + float(r.cd)
	combo_pending = attack == &"combo"
	passes_left = int(def.params.return_passes) if attack == &"return_charge" else 1
	_begin_pass()
	return true

func attack_playing() -> bool:
	return mode != &"idle"

func _begin_pass() -> void:
	mode = &"windup"
	locked = false
	attack_hit = false
	table.vel[body] = Vector2.ZERO
	aim_point = _strike_aim()
	direction = Vector2.from_angle(table.facing[body] + (PI if technique == &"kick" else 0.0))
	var r := rule()
	var anim := timeline.get_animation(&"attack")
	anim.length = float(r.warn) + float(r.active)
	while anim.track_get_key_count(0) > 0: anim.track_remove_key(0, 0)
	anim.track_insert_key(0, maxf(0.01, float(r.warn) - float(def.params.lock_lead)), {"method": &"lock_aim", "args": []})
	anim.track_insert_key(0, float(r.warn), {"method": &"launch_strike", "args": []})
	anim.track_insert_key(0, anim.length, {"method": &"end_strike", "args": []})
	timeline.play(&"attack")
	timeline.advance(0.0)
	_cue(&"telegraph")

func _aim(dt: float) -> void:
	aim_point = _strike_aim()
	if technique == &"kick":
		direction = (aim_point - table.pos[body]).normalized()
		return
	var wanted := (aim_point - table.pos[body]).angle()
	var prior := table.facing[body]
	table.facing[body] = rotate_toward(prior, wanted, def.turn * dt)
	turn_motion = Geom.angle_diff(table.facing[body], prior) / maxf(dt, 0.001)
	direction = Vector2.from_angle(table.facing[body])

func _strike_aim(attack: StringName = &"", lead := -1.0) -> Vector2:
	# ボス固有の捕捉。選択時・予告中だけ現在位置と速度から接触時点を狙う。
	if attack == &"": attack = technique
	if attack == &"combo": attack = &"charge"
	var velocity := run_state.ship_vel
	var target := run_state.ship_pos + velocity * (float(def.params.lock_lead) if lead < 0.0 else lead)
	if attack not in [&"charge", &"return_charge", &"lance"]: return target
	var r: Dictionary = _moves[attack].parameters
	var speed := float(r.distance) / float(r.active)
	var reach := float(r.get("reach", horn_length()))
	var offset := target - table.pos[body]
	var a := velocity.length_squared() - speed * speed
	var b := 2.0 * (offset.dot(velocity) - reach * speed)
	var c := offset.length_squared() - reach * reach
	var contact := 0.0
	if c > 0.0:
		contact = float(r.active)
		if absf(a) < 0.001:
			if b < -0.001: contact = -c / b
		else:
			var discriminant := b * b - 4.0 * a * c
			if discriminant >= 0.0:
				for root in [(-b - sqrt(discriminant)) / (2.0 * a), (-b + sqrt(discriminant)) / (2.0 * a)]:
					if root >= 0.0: contact = minf(contact, root)
	return target + velocity * clampf(contact, 0.0, float(r.active))

func lock_aim() -> void:
	if mode != &"windup" or locked: return
	# 固定後は再捕捉せず、予告で見せた方向へ発進する。
	# 蹴りは背後への攻撃なので本体の向きを保つ。
	if technique != &"kick" and not aim_point.is_equal_approx(table.pos[body]):
		table.facing[body] = (aim_point - table.pos[body]).angle()
	locked = true
	direction = (aim_point - table.pos[body]).normalized() if technique == &"kick" else Vector2.from_angle(table.facing[body])
	_cue(&"aim_locked")

func launch_strike() -> void:
	if mode != &"windup": return
	lock_aim()
	if table.pos[body].distance_to(aim_point) > _reach(technique) or (technique == &"kick" and absf(Geom.angle_diff(direction.angle(), table.facing[body] + PI)) > float(def.params.kick_trigger_arc)):
		combat_trace.finish("interrupted", "target_left_launch_range")
		# 予告中に届かない位置へ離れた自機へ、空の近接攻撃を出し続けない。
		timeline.stop()
		combo_pending = false
		passes_left = 0
		mode = &"recovery"
		recovery = float(rule().recover)
		_cue(&"recovery_started")
		return
	if technique in [&"charge", &"return_charge", &"lance"] and _path_blocked():
		combat_trace.finish("interrupted", "path_obstructed")
		combo_pending = false
		passes_left = 0
		timeline.stop()
		mode = &"idle"
		technique = &""
		reposition = float(def.params.reposition_time)
		var toward := (aim_point - table.pos[body]).normalized()
		var side := toward.orthogonal()
		var a := ctx.field.body_gap(table.pos[body] + side * 220.0, table.r[body])
		var b := ctx.field.body_gap(table.pos[body] - side * 220.0, table.r[body])
		reposition_direction = side if a >= b else -side
		_cue(&"reposition")
		return
	mode = &"active"
	previous_horn = horn_points()
	_cue(&"attack_started")

func _path_blocked() -> bool:
	var at := table.pos[body]
	var distance := maxf(float(def.params.near_clearance), minf(at.distance_to(aim_point), float(rule().distance)))
	# 狙いまでを確認する。かわされた先までの全突進経路は調べない。
	return ctx.field.first_body_hit(at, at + direction * distance, table.r[body]) != null

func _tick_strike(dt: float, prior: PackedVector2Array) -> void:
	if technique in [&"charge", &"return_charge", &"lance"]:
		var step := direction * float(rule().distance) / float(rule().active) * dt
		var from := table.pos[body]
		var to := from + step
		var horn_from := from + direction * horn_length()
		var hit = ctx.field.first_body_hit(horn_from, horn_from + step, float(def.params.horn_width) * 0.5) if technique != &"lance" else null
		var body_hit = ctx.field.first_body_hit(from, to, table.r[body])
		if hit != null and hit.body != null and hit.body.is_planet and (body_hit == null or float(hit.t) <= float(body_hit.t)):
			table.pos[body] = from.lerp(to, hit.t)
			_damage_shape(prior, horn_points())
			stuck_body = hit.body
			stuck_offset = table.pos[body] - stuck_body.pos
			stuck_time = float(def.params.stuck_time)
			combat_trace.finish("interrupted", "horn_stuck_in_planet")
			mode = &"stuck"
			combo_pending = false
			passes_left = 0
			table.vel[body] = Vector2.ZERO
			timeline.stop()
			_cue(&"horn_stuck")
			return
		if body_hit != null:
			combat_trace.stage("interruption", {"reason": "body_obstacle"})
			table.pos[body] = from.lerp(to, body_hit.t)
			_damage_shape(prior, horn_points())
			combo_pending = false
			passes_left = 0
			end_strike()
			return
		table.pos[body] = to
		table.vel[body] = step / dt
	if technique == &"sweep":
		# 頭の角度を小さく刻み、フレーム間の扇形も掃引する。
		var start := maxf(0.0, timeline.current_animation_position - float(rule().warn))
		var steps := maxi(1, ceili(dt / 0.008))
		for j in steps:
			var f := clampf((start + dt * float(j + 1) / steps) / float(rule().active), 0.0, 1.0)
			var next := horn_points(f)
			_damage_shape(prior, next)
			prior = next
	else:
		_damage_shape(prior, horn_points())

func end_strike() -> void:
	if mode != &"active": return
	timeline.stop()
	table.vel[body] = Vector2.ZERO
	previous_horn.clear()
	passes_left -= 1
	if technique == &"return_charge" and passes_left > 0:
		mode = &"turnaround"
		recovery = float(def.params.turnaround_time)
	elif combo_pending:
		mode = &"recovery"
		recovery = float(def.params.combo_gap)
	else:
		mode = &"recovery"
		recovery = float(rule().recover)
	_cue(&"recovery_started")

func _reposition_tick(dt: float) -> void:
	if reposition > 0.0:
		reposition = maxf(0.0, reposition - dt)
		_move_body(reposition_direction * def.speed * dt)
		var prior := table.facing[body]
		table.facing[body] = rotate_toward(prior, reposition_direction.angle(), def.turn * dt)
		turn_motion = Geom.angle_diff(table.facing[body], prior) / maxf(dt, 0.001)
	else:
		var toward := run_state.ship_pos - table.pos[body]
		var pursuit := toward
		var lead_close := false
		if _moves.has(&"sweep") and not _close_ready(&"kick") and toward.length() < float(action_rules.conditions.get("charge", {}).get("min", 300.0)):
			var forecast := _strike_aim(&"sweep", float(_moves[&"sweep"].parameters.warn)) - table.pos[body]
			if forecast.length() > _reach(&"sweep") - 10.0:
				pursuit = forecast
				lead_close = true
		var prior := table.facing[body]
		if not _close_ready(&"kick"):
			table.facing[body] = rotate_toward(prior, pursuit.angle(), def.turn * dt)
		turn_motion = Geom.angle_diff(table.facing[body], prior) / maxf(dt, 0.001)
		var closing := toward.length() > float(def.params.approach_range) or lead_close
		if not closing and _moves.has(&"charge"):
			closing = table.pos[body].distance_to(_strike_aim(&"charge", float(_moves[&"charge"].parameters.warn))) > _reach(&"charge")
		if closing:
			# 近接では現在の距離を保ちながら予告終了時の位置へ回り込み、それ以外は接近する。
			var alignment := maxf(0.0, Vector2.from_angle(table.facing[body]).dot(pursuit.normalized()))
			var step := Vector2.from_angle(table.facing[body]) * float(def.params.approach_speed) * alignment * dt
			if lead_close:
				var next_offset := table.pos[body] + step - run_state.ship_pos
				var clearance := minf(toward.length(), float(def.params.approach_range))
				if next_offset.length() < clearance:
					var radial := next_offset.normalized() if next_offset.length() > 0.001 else -toward.normalized()
					step = run_state.ship_pos + radial * clearance - table.pos[body]
			_move_body(step)
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
	var at := table.pos[body]
	var angle := table.facing[body]
	var reach := horn_length()
	var root := table.r[body] * 0.65
	if technique == &"kick":
		angle = direction.angle()
		reach = float(rule().reach)
	elif technique == &"lance":
		reach = float(rule().reach)
	elif technique == &"sweep":
		var f := sweep_fraction
		if f < 0.0: f = clampf((timeline.current_animation_position - float(rule().warn)) / float(rule().active), 0.0, 1.0)
		angle += lerpf(-float(rule().arc), float(rule().arc), f)
	var dir := Vector2.from_angle(angle)
	return PackedVector2Array([at + dir * root, at + dir * reach])

## 予告の細線は、移動後の角先までの直線を共有する。
func warning_points() -> PackedVector2Array:
	var points := horn_points()
	if technique in [&"charge", &"return_charge", &"lance"]:
		points[1] += direction * float(rule().distance)
	return points

func _damage_shape(prior: PackedVector2Array, points: PackedVector2Array) -> void:
	if attack_hit or mode != &"active": return
	combat_trace.evaluate()
	var radius := float(def.params.horn_width) * 0.5 + ctx.cfg.ship_radius
	var paths: Array[PackedVector2Array] = [points, prior]
	if prior.size() == 2:
		paths.append(PackedVector2Array([prior[0], points[0]]))
		paths.append(PackedVector2Array([prior[1], points[1]]))
		if Geometry2D.is_point_in_polygon(run_state.ship_pos, PackedVector2Array([prior[0], prior[1], points[1], points[0]])):
			_hit_ship()
	for line in paths:
		if line.size() != 2: continue
		if Geometry2D.segment_intersects_segment(previous_ship, run_state.ship_pos, line[0], line[1]) != null:
			_hit_ship()
		for pair in [[previous_ship,line[0],line[1]],[run_state.ship_pos,line[0],line[1]],[line[0],previous_ship,run_state.ship_pos],[line[1],previous_ship,run_state.ship_pos]]:
			if Geometry2D.get_closest_point_to_segment(pair[0], pair[1], pair[2]).distance_squared_to(pair[0]) <= radius * radius: _hit_ship()

func _hit_ship() -> void:
	if attack_hit: return
	combat_trace.damage(float(rule().damage) * ctx.cfg.atk_scale, 0.0, &"horn", &"monoceros")
	attack_hit = true

func _cue(cue: StringName) -> void:
	match cue:
		&"telegraph": combat_trace.stage("telegraph")
		&"aim_locked": combat_trace.stage("lock")
		&"attack_started": combat_trace.stage("execute")
		&"recovery_started": combat_trace.stage("recovery")
		&"phase_changed": combat_trace.event("boss_phase", {"reason": "hp_threshold"})
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
