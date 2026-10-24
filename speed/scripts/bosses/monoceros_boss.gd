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

func on_body_damaged() -> void:
	if phase == 1 and table.hp[body] / table.max_hp[body] <= float(def.params.phase_threshold):
		phase_pending = true
	_cue(&"hit")

func handle_body_defeat(_opts: Dictionary) -> bool:
	_stop_combat()
	return false

func _stop_combat() -> void:
	if _defeated: return
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
	if final_strike_t >= 0.0:
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
		if mode == &"extract":
			_move_body(-direction * float(def.params.extract_speed) * dt)
		if recovery <= 0.0:
			if mode == &"turnaround":
				_begin_pass()
			elif combo_pending:
				combo_pending = false
				technique = &"sweep"
				_begin_pass()
			else:
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
	if not can_select(attack, int(gate.get("min_phase", 1)), float(gate.get("min", 0.0)), float(gate.get("max", INF)), false): return false
	return preload("res://scripts/bosses/flow/range_condition.gd").allows(gate, (run_state.enemy_aim - table.pos[body]).rotated(-table.facing[body]))

func selection_blocked() -> bool:
	return not body_alive() or not selection_enabled or mode in [&"phase", &"final", &"defeated"]

func can_begin_sequence() -> bool:
	return mode == &"idle" and _cooldown <= 0.0 and reposition <= 0.0

func attack_failed() -> bool:
	return not body_alive() or reposition > 0.0

## 条件評価では攻撃枠を消費しない。
func can_select(attack: StringName, min_phase: int, min_range: float, max_range: float, rear_only: bool) -> bool:
	if mode != &"idle" or _cooldown > 0.0 or reposition > 0.0 or phase < min_phase: return false
	if clock < float(cooldowns.get(attack, 0.0)): return false
	var d := run_state.enemy_aim - table.pos[body]
	if d.length() < min_range or d.length() > max_range: return false
	return not rear_only or absf(Geom.angle_diff(d.angle(), table.facing[body] + PI)) < float(def.params.kick_trigger_arc)

func start_attack(attack: StringName) -> bool:
	if mode != &"idle" or not _moves.has(attack): return false
	var r: Dictionary = _moves[attack].parameters
	if not ctx.bosses.admit("boss:" + str(body_id), ["aimed"], body, float(r.warn) + float(r.active)): return false
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
	aim_point = run_state.enemy_aim
	direction = Vector2.from_angle(table.facing[body])
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
	# 共通の遅延照準をそのまま使い、未来位置を予測しない。
	aim_point = run_state.enemy_aim
	if technique == &"kick": return
	var wanted := (aim_point - table.pos[body]).angle()
	var prior := table.facing[body]
	table.facing[body] = rotate_toward(prior, wanted, def.turn * dt)
	turn_motion = Geom.angle_diff(table.facing[body], prior) / maxf(dt, 0.001)
	direction = Vector2.from_angle(table.facing[body])

func lock_aim() -> void:
	if mode != &"windup": return
	locked = true
	direction = Vector2.from_angle(table.facing[body])
	_cue(&"aim_locked")

func launch_strike() -> void:
	if mode != &"windup": return
	lock_aim()
	if technique in [&"charge", &"return_charge", &"lance"] and _path_blocked():
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
			mode = &"stuck"
			combo_pending = false
			passes_left = 0
			table.vel[body] = Vector2.ZERO
			timeline.stop()
			_cue(&"horn_stuck")
			return
		if body_hit != null:
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
	elif table.pos[body].distance_to(run_state.enemy_aim) > float(def.params.approach_range):
		var toward := (run_state.enemy_aim - table.pos[body]).normalized()
		var prior := table.facing[body]
		table.facing[body] = rotate_toward(prior, toward.angle(), def.turn * dt)
		turn_motion = Geom.angle_diff(table.facing[body], prior) / maxf(dt, 0.001)
		_move_body(Vector2.from_angle(table.facing[body]) * def.speed * dt)
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
		angle += PI
		reach = float(rule().reach)
	elif technique == &"lance":
		reach = float(rule().reach)
	elif technique == &"sweep":
		var f := sweep_fraction
		if f < 0.0: f = clampf((timeline.current_animation_position - float(rule().warn)) / float(rule().active), 0.0, 1.0)
		angle += lerpf(-float(rule().arc), float(rule().arc), f)
	var dir := Vector2.from_angle(angle)
	return PackedVector2Array([at + dir * root, at + dir * reach])

func _damage_shape(prior: PackedVector2Array, points: PackedVector2Array) -> void:
	if attack_hit or mode != &"active": return
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
	ctx.ship.damage(float(rule().damage) * ctx.cfg.atk_scale, 0.0, &"horn", &"monoceros")
	attack_hit = true

func _cue(cue: StringName) -> void:
	presentation_event.emit({"cue": cue, "technique": technique, "phase": phase, "mode": mode,
		"position": table.pos[body], "angle": table.facing[body], "world_time": clock})

func begin_final_strike(charge: float) -> void:
	if flow_adapter != null: flow_adapter.cancel()
	selection_enabled = false
	combo_pending = false
	previous_horn.clear()
	mode = &"final"
	super(charge)
	_cue(&"final_strike")

func cancel_attack() -> void:
	timeline.stop()
	combo_pending = false
	passes_left = 0
	previous_horn.clear()
	recovery = 0.0
	mode = &"idle"

func _exit_tree() -> void:
	if flow_adapter != null: flow_adapter.cancel()
