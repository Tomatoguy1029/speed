## ケンタウルス座。選択は共通フロー、距離取り・離脱・射撃・矢の雨は個別ロジックで進める。
## 予告・発射前の警告・発射・終了はAnimationPlayerで進め、本体は全方向から攻撃できる。
## 矢の雨は、円が弧を走ったトレースの中へ、円を追って矢を降らせる。矢は円が通ってから drop_delay 後に落とし始め、さらに fall 遅れて着く。
## 背後攻撃は、背後へ回った機体へ、背中の後ろの円で当たる。範囲の円は実験場だけが描く。
## 第2形態では、技と本体の数値のうち `_p2` を付けた値が同じ名前の値を置き換える。
class_name CentaurusBoss
extends "res://scripts/bosses/boss_final_strike.gd"

signal presentation_event(event: Dictionary)
signal presentation_advanced(world_dt: float)
@export var presentation_scene: PackedScene
## 刺さった矢の雨の矢が消えるまでの時間
const RAIN_OUT := 0.15

var phase := 1
## HPが第2形態の境目を切った。今の技が終わって待機へ戻ると移る。
var phase_pending := false
## 帆を広げる移行の残り時間
var phase_time := 0.0
var mode: StringName = &"idle"
var technique: StringName = &""
var clock := 0.0
var recovery := 0.0
## 強弓の発射直前の警告中か
var alerting := false
var cooldowns: Dictionary = {}
var retreat_time := 0.0
var retreat_ready_at := 0.0
var turn_time := 0.0
## 近くの守る雑魚の中心。足りなければ Vector2.INF
var guard_point := Vector2.INF
var turn_motion := 0.0
var _guard_scan := 0.0
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
var technique_pose := {}
var _support_runners := {}
var _runner: RefCounted
var technique_visuals := preload("res://scripts/bosses/technique_visuals.gd").new()
## 予告の間に自機を追わない技の狙い。予告を始めた時の位置。
var warn_aim := Vector2.ZERO
## 今の形態の技の性能。技のID → 性能
var _rules := {}
## 矢の雨のトレース。start・dir・turn（曲がる向き ±1）・t0（走り始めの clock）・next_drop・landed・hit を持つ
var rain_traces: Array[Dictionary] = []
## 矢の雨の矢。x・y が着弾点、z が落とし始めの clock（時刻順）
var rain_arrows := PackedVector3Array()
var _rain_left := 0
var _rain_next_at := 0.0
## 背後攻撃が当たったか（1回の攻撃で1回だけ当てる）
var attack_hit := false
var _previous_ship := Vector2.ZERO

func configure_flow(program: Resource) -> void:
	action_rules = program.data.rules
	_moves.clear()
	for move in action_rules.techniques: _moves[move.technique] = move
	_apply_phase()
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
	configure_flow(load("res://.content/boss_centaurus.tres"))
	_cooldown = float(def.params.initial_wait)
	if presentation_scene != null:
		_presentation = presentation_scene.instantiate()
		add_child(_presentation)
		_presentation.bind_centaurus(self)
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
	_check_phase()
	_cue(&"hit")

func _check_phase() -> void:
	if phase == 1 and table.hp[body] / table.max_hp[body] <= float(def.params.phase_threshold): phase_pending = true

func handle_body_defeat(_opts: Dictionary) -> bool:
	_stop_combat()
	return false

func _stop_combat() -> void:
	if _defeated: return
	_defeated = true
	if flow_adapter != null: flow_adapter.cancel()
	selection_enabled = false
	timeline.stop()
	_clear_rain()
	mode = &"defeated"
	table.vel[body] = Vector2.ZERO
	table.charge[body] = 0.0
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
	elif mode == &"phase":
		phase_time -= dt
		table.vel[body] = Vector2.ZERO
		_face(run_state.enemy_aim, def.turn, dt)
		if phase_time <= 0.0: mode = &"idle"
	elif mode == &"retreat":
		_retreat_tick(dt)
	elif mode == &"turn":
		turn_time -= dt
		table.vel[body] = Vector2.ZERO
		_face(run_state.enemy_aim, def.turn, dt)
		if turn_time <= 0.0: mode = &"idle"
	elif mode == &"recovery":
		recovery = maxf(0.0, recovery - dt)
		table.vel[body] = Vector2.ZERO
		if recovery <= 0.0:
			mode = &"idle"
			technique = &""
	elif mode == &"rain":
		_rain_tick(dt)
	elif mode in [&"windup", &"shooting", &"strike"]:
		table.vel[body] = Vector2.ZERO
		# 強弓は引き絞りの間、機体の今の位置へ向きを合わせ続ける。背後攻撃は背中を向けたまま構える。
		if mode == &"windup" and not _tracks_during_warn():
			if _runner_for().kind() != &"rear_attack": _face(warn_aim, def.turn, dt)
		elif _runner_for().kind() == &"power_shot": table.facing[body] = (run_state.ship_pos - table.pos[body]).angle()
		elif _runner_for().kind() != &"rear_attack": _face(run_state.enemy_aim, def.turn, dt)
		if mode == &"strike": _strike_tick()
		if timeline.is_playing(): timeline.advance(dt)
	else:
		_check_phase()
		if phase_pending:
			_begin_phase_two()
		else:
			_cooldown = maxf(0.0, _cooldown - dt)
			if clock >= retreat_ready_at and table.pos[body].distance_to(run_state.ship_pos) < float(def.params.retreat_trigger) and not _rear_ready():
				_begin_retreat()
			else:
				_position_tick(dt)
				if selection_enabled: flow_runner.tick(dt, {"player": run_state.enemy_aim}, flow_adapter)
	table.charge[body] = clampf(timeline.current_animation_position / maxf(float(rule().get("warn", 1.0)), 0.001), 0.0, 1.0) if mode == &"windup" else 0.0
	_previous_ship = run_state.ship_pos
	_sync_technique_visuals()
	presentation_advanced.emit(dt)

func rule() -> Dictionary:
	return _rules.get(technique, {})

## 本体の数値。第2形態では `_p2` を付けた値があればそれを使う。
func param(key: String) -> Variant:
	if phase >= 2 and def.params.has(key + "_p2"): return def.params[key + "_p2"]
	return def.params[key]

## 技の性能を今の形態の値にそろえる。技の途中では変えない。
func _apply_phase() -> void:
	_rules.clear()
	for id in _moves:
		var base: Dictionary = _moves[id].values()
		var values := {}
		for key: String in base:
			if not key.ends_with("_p2"): values[key] = base[key]
		if phase >= 2:
			for key: String in base:
				if key.ends_with("_p2"): values[key.trim_suffix("_p2")] = base[key]
		_rules[id] = values

## 止まって帆を広げ、第2形態の値へ切り替える。
func _begin_phase_two() -> void:
	phase_pending = false
	phase = 2
	_apply_phase()
	mode = &"phase"
	phase_time = float(def.params.phase_time)
	table.vel[body] = Vector2.ZERO
	_cue(&"phase_changed")

# ── 共通フローへの入口 ─────────────────────────────────────────

func technique_ready(attack: StringName, gate: Dictionary) -> bool:
	if not can_select(attack, int(gate.get("min_phase", 1)), float(gate.get("min", 0.0)), float(gate.get("max", INF))): return false
	return preload("res://scripts/bosses/flow/range_condition.gd").allows(gate, (_target_of(attack) - table.pos[body]).rotated(-table.facing[body]))

## 技の条件を測る位置。背後攻撃は背後へ回り込んだ機体の今の位置、ほかは共通の遅延照準。
func _target_of(attack: StringName) -> Vector2:
	return run_state.ship_pos if attack == &"rear_attack" else run_state.enemy_aim

func selection_blocked() -> bool:
	return not body_alive() or not selection_enabled or mode in [&"entrance", &"phase", &"retreat", &"turn", &"final", &"defeated"]

func can_begin_sequence() -> bool:
	return mode == &"idle" and _cooldown <= 0.0

func attack_failed() -> bool:
	return not body_alive()

## 条件評価では攻撃枠を消費しない。
func can_select(attack: StringName, min_phase: int, min_range: float, max_range: float) -> bool:
	if mode != &"idle" or phase_pending or _cooldown > 0.0 or phase < min_phase: return false
	if clock < float(cooldowns.get(attack, 0.0)): return false
	var distance := _target_of(attack).distance_to(table.pos[body])
	return distance >= min_range and distance <= max_range

func start_attack(attack: StringName) -> bool:
	if mode != &"idle" or not _rules.has(attack): return false
	var r: Dictionary = _rules[attack]
	var length := _attack_length(attack, r)
	if not ctx.bosses.admit("boss:" + str(body_id), ["aimed"], body, length): return false
	technique = attack
	_runner = _moves[attack].make_runner()
	_support_runners[attack] = _runner
	cooldowns[attack] = clock + float(r.cd)
	_begin_windup(r, length)
	return true

func attack_playing() -> bool:
	return mode in [&"windup", &"shooting", &"strike", &"rain", &"recovery"]

func cancel_attack() -> void:
	timeline.stop()
	_clear_rain()
	alerting = false
	recovery = 0.0
	technique = &""
	if mode in [&"windup", &"shooting", &"strike", &"rain", &"recovery"]: mode = &"idle"

# ── 射撃 ──────────────────────────────────────────────────

func _attack_length(attack: StringName, r: Dictionary) -> float:
	if _moves[attack].make_runner().kind() == &"volley": return float(r.warn) + float(r.interval) * (int(r.count) - 1) + 0.05
	if _moves[attack].make_runner().kind() == &"rear_attack": return float(r.warn) + float(r.active) + 0.05
	if _moves[attack].make_runner().kind() == &"rain":
		var traces := int(r.traces)
		return float(r.warn) + traces * _trace_duration(r) + maxi(traces - 1, 0) * float(r.trace_gap) + float(r.get("drop_delay", 0.0)) + float(r.fall) + float(r.linger) + 0.3
	return float(r.warn) + 0.05

func _tracks_during_warn() -> bool:
	return not _moves.has(technique) or _moves[technique].track_during_warn

func _begin_windup(r: Dictionary, length: float) -> void:
	_runner_for()._begin_windup(self, r, length)

func alert() -> void:
	_runner_id(&"power_shot").alert(self)

func bow_mouth() -> Vector2:
	return table.pos[body] + Vector2.from_angle(table.facing[body]) * table.r[body] * float(def.params.bow_reach)

## 速射は1本ごとに共通の遅延照準を狙う。強弓は発射の瞬間の機体の位置へ射る。矢は敵をすり抜ける。
## 強弓が複数本なら、真ん中を機体へ向け、残りを左右へ spread ずつ開いて同時に射る。
func release() -> void:
	_runner_for().release(self)

func power_offsets() -> Array[float]:
	return _runner_id(&"power_shot").power_offsets(self)

func end_attack() -> void:
	_runner_for().end_attack(self)

func strike_on() -> void:
	_runner_id(&"rear_attack").strike_on(self)

func rear_center(r: Dictionary) -> Vector2:
	return _runner_id(&"rear_attack").rear_center(self, r)

func _strike_tick() -> void:
	_runner_id(&"rear_attack")._strike_tick(self)

func _rear_ready() -> bool:
	if action_rules == null or not _rules.has(&"rear_attack"): return false
	if flow_runner.rest_remaining > 0.0 or flow_runner.stamina < float(action_rules.costs.get("rear_attack", 1.0)): return false
	return action_rules.active_gates_for("rear_attack").any(func(gate): return technique_ready(&"rear_attack", gate))

## 実験場だけが描く攻撃範囲。center・radius・active（当たりが有効か）を持つ。
## with_idle なら、構えていない間も背後攻撃の範囲を返す。
func lab_ranges(with_idle := false) -> Array[Dictionary]:
	var ranges: Array[Dictionary] = []
	if _runner_for().kind() == &"rear_attack" and mode in [&"windup", &"strike"]:
		ranges.append({"center": rear_center(rule()), "radius": float(rule().range_radius), "active": mode == &"strike"})
	elif with_idle and _rules.has(&"rear_attack"):
		var r: Dictionary = _rules[&"rear_attack"]
		ranges.append({"center": rear_center(r), "radius": float(r.range_radius), "active": false})
	return ranges

# ── 矢の雨 ────────────────────────────────────────────────

func begin_rain() -> void:
	_runner_id(&"rain").begin_rain(self)

func _clear_rain() -> void:
	_runner_id(&"rain")._clear_rain(self)

func _trace_duration(r: Dictionary) -> float:
	return _runner_id(&"rain")._trace_duration(self, r)

func trace_point(trace: Dictionary, s: float) -> Vector2:
	return _runner_id(&"rain").trace_point(self, trace, s)

func _start_trace(r: Dictionary) -> void:
	_runner_id(&"rain")._start_trace(self, r)

func _rain_tick(dt: float) -> void:
	_runner_id(&"rain")._rain_tick(self, dt)

func _begin_retreat() -> void:
	mode = &"retreat"
	retreat_time = 0.0
	_cue(&"retreat")

## 機体から真っすぐ離れる。フィールドの外縁では縁に沿って走る。
func _retreat_tick(dt: float) -> void:
	retreat_time += dt
	var at := table.pos[body]
	var away := at - run_state.ship_pos
	var direction := away.normalized() if away.length_squared() > 1.0 else -Vector2.from_angle(table.facing[body])
	if at.length() > ctx.cfg.field_radius - 400.0 and direction.dot(at) > 0.0:
		var along := direction.slide(at.normalized())
		direction = along.normalized() if along.length_squared() > 0.01 else at.normalized().orthogonal()
	_face(at + direction, def.turn * 2.0, dt)
	_move_body(direction * float(param("run_speed")) * dt, dt)
	if away.length() >= float(def.params.retreat_far) or retreat_time >= float(def.params.retreat_max):
		mode = &"turn"
		turn_time = float(def.params.retreat_turn)
		retreat_ready_at = clock + turn_time + float(def.params.retreat_cd)
		_cue(&"retreat_finished")

## 好む距離を保つ。守る雑魚が近くに集まっていれば、機体から見てその集まりの側へ回る。
## 距離は好む範囲だけで決める（集まりの奥へ下がると、ボスの前へ並び直す雑魚を追って下がり続けるため）。
func _position_tick(dt: float) -> void:
	_scan_guards(dt)
	var aim := run_state.enemy_aim
	var at := table.pos[body]
	var offset := at - aim
	var distance := offset.length()
	var direction := offset / maxf(distance, 1.0)
	if guard_point != Vector2.INF and guard_point.distance_squared_to(aim) > 1.0:
		direction = (guard_point - aim).normalized()
	var target := aim + direction * clampf(distance, float(def.params.keep_min), float(def.params.keep_max))
	var step := target - at
	if step.length() > 24.0:
		_move_body(step.limit_length(def.speed * dt), dt)
	else:
		table.vel[body] = Vector2.ZERO
	_face(aim, def.turn, dt)

func _scan_guards(dt: float) -> void:
	_guard_scan -= dt
	if _guard_scan > 0.0: return
	_guard_scan = float(def.params.guard_scan)
	var t := table
	var at := t.pos[body]
	var reach := float(def.params.guard_search)
	var sum := Vector2.ZERO
	var count := 0
	for row in t.alive.size():
		if t.alive[row] == 0 or t.dead[row] != 0 or t.type[row] != &"defender": continue
		if t.pos[row].distance_squared_to(at) > reach * reach: continue
		sum += t.pos[row]
		count += 1
	guard_point = sum / count if count >= int(def.params.guard_min) else Vector2.INF

func _face(point: Vector2, rate: float, dt: float) -> void:
	var prior := table.facing[body]
	table.facing[body] = rotate_toward(prior, (point - table.pos[body]).angle(), rate * dt)
	turn_motion = Geom.angle_diff(table.facing[body], prior) / maxf(dt, 0.001)

func _move_body(step: Vector2, dt: float) -> void:
	var from := table.pos[body]
	table.pos[body] += step
	table.vel[body] = step / maxf(dt, 0.001)
	ctx.field.collide_enemy(body, from)

func _cue(cue: StringName) -> void:
	presentation_event.emit({"cue": cue, "technique": technique, "phase": phase, "mode": mode,
		"position": table.pos[body], "angle": table.facing[body], "world_time": clock})

func begin_final_strike(charge: float) -> void:
	if flow_adapter != null: flow_adapter.cancel()
	selection_enabled = false
	mode = &"final"
	super(charge)
	_cue(&"final_strike")

func _exit_tree() -> void:
	if flow_adapter != null: flow_adapter.cancel()

func _runner_for() -> RefCounted:
	if _runner != null: return _runner
	return preload("res://scripts/bosses/centaurus/technique_runner.gd").new()

func _runner_id(id: StringName) -> RefCounted:
	if _runner != null and _runner.kind() == id: return _runner
	if not _support_runners.has(id): _support_runners[id] = _moves[id].make_runner()
	return _support_runners[id]

func _sync_technique_visuals() -> void:
	technique_pose = _runner_for().body_pose(self)
	var key := "recover" if mode == &"recovery" else "warn" if mode == &"windup" else "active"
	var elapsed := float(rule().get("recover", 0.0)) - recovery if mode == &"recovery" else timeline.current_animation_position if timeline.is_playing() else 0.0
	technique_visuals.sync(technique, mode, elapsed, float(rule().get(key, 1.0)))
