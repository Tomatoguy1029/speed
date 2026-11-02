## 実際の役者・攻撃・被弾経路を進めるシナリオ行列。証拠はリポジトリ外へ保存する。
extends Node
const STEP := 1.0 / 120.0
const IDS: Array[StringName] = [&"bite", &"tail_sweep", &"star_fan", &"tail_slam", &"meteor", &"breath", &"charge", &"leap", &"rifts", &"picaro_wall", &"clones", &"inhale", &"spiral"]
var failures := 0
var rows: Array = []
var label := "current"
var only := ""
var output := "/tmp/draco-qa-evidence"
var snapshots: FileAccess
var stage_template: RuntimeStage
var identity_start: Dictionary

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-label="): label = arg.trim_prefix("--qa-label=")
		if arg.begins_with("--qa-only="): only = arg.trim_prefix("--qa-only=")
	DirAccess.make_dir_recursive_absolute(output)
	stage_template = ContentManager.runtime_stage(5)
	identity_start = _identity()
	snapshots = FileAccess.open(output.path_join(label + "-samples.jsonl"), FileAccess.WRITE)
	for id in IDS:
		if not only.is_empty() and String(id) != only: continue
		for angle in [0.0, PI * 0.5, PI, -PI * 0.5]:
			for dodge in [false, true]: _attack_case(id, angle, dodge)
		for distance_factor in [0.65, 1.3]:
			for dodge in [false, true]: _attack_case(id, PI * 0.25, dodge, distance_factor)
	if only.is_empty(): _phase_case()
	var file := FileAccess.open(output.path_join(label + "-matrix.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"label": label, "engine": Engine.get_version_info().string, "identity_start":identity_start, "identity_end":_identity(), "cases": rows, "failures": failures}, "\t"))
	file.close()
	if snapshots != null: snapshots.close()
	print("[draco_encounter_qa] ", label, " cases=", rows.size(), " failures=", failures, " output=", output)
	get_tree().quit(1 if failures > 0 else 0)

func _check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)

func _session(seed_value: int) -> RunSession:
	var stage: RuntimeStage = stage_template.duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 5, "seed": seed_value, "hud": false, "view_size": Vector2(1280,720)}, false)
	session.auto_step = false
	var sim := session.sim
	sim.field.bodies.clear()
	sim.field.rocks.clear()
	sim.state.phase = RunState.Phase.PLAY
	sim.state.ship_hp = 100000.0
	sim.state.ship_shield_t = 0.0
	sim.state.ship_invuln = 0.0
	sim.state.ship_vel = Vector2.ZERO
	sim.state.controls_locked = false
	sim.state.encounter_protected = false
	sim.state.view_center = Vector2.ZERO
	sim.state.camera_zoom = 720.0 / 1100.0
	sim.state.view_half = Vector2(1280,720) * 0.5 / sim.state.camera_zoom
	sim.ship.invincible = false
	sim.bosses.spawn(load("res://data/bosses/draco.tres"), Vector2.ZERO)
	var actor = sim.bosses.actor
	actor.selection_enabled = false
	actor.phase = 3
	return session

func _tick(sim: RunSimulation, velocity: Vector2) -> void:
	sim.state.time += STEP
	sim.state.world_time += STEP
	sim.state.sim_time += STEP
	sim.state.ship_invuln = maxf(0.0, sim.state.ship_invuln - STEP)
	sim.state.ship_hurt = maxf(0.0, sim.state.ship_hurt - STEP)
	sim.state.ship_vel = velocity
	sim.state.ship_pos += velocity * STEP
	sim.enemies.tick(STEP, STEP)
	sim.bosses.tick(STEP, STEP)
	sim.combat.rebuild_grid()
	sim.projectiles.tick(STEP, STEP)
	sim.enemies.cleanup()
	sim._update_camera(STEP)

func _point(value: Vector2) -> Array:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01)]

func _sample(sim: RunSimulation, id: StringName, key: String, time: float) -> void:
	if snapshots == null: return
	var actor = sim.bosses.actor
	var body: Array = []
	for point: Vector2 in actor.body_points(): body.append(_point(point))
	var tells: Array = []
	for point: Vector2 in actor.telegraph_points: tells.append(_point(point))
	var paths: Array = []
	var widths: Array = []
	if actor.get("telegraph_paths") != null:
		for path in actor.telegraph_paths:
			var line: Array = []
			for point: Vector2 in path: line.append(_point(point))
			paths.append(line)
		widths.assign(actor.telegraph_widths)
	var attack: Array = []
	for point: Vector2 in actor.attack_points: attack.append(_point(point))
	var hazards: Array = []
	for h in sim.projectiles.hazard_alive.size():
		if sim.projectiles.hazard_alive[h] == 0: continue
		hazards.append({"at": _point(sim.projectiles.hazard_pos[h]), "angle": sim.projectiles.hazard_angle[h], "width": sim.projectiles.hazard_width[h], "damage": sim.projectiles.hazard_dmg[h], "block": sim.projectiles.hazard_block[h], "age": sim.projectiles.hazard_t[h]})
	snapshots.store_line(JSON.stringify({"case": key, "id": id, "t": time, "mode": actor.mode, "head": _point(sim.enemies.table.pos[actor.body]), "ship": _point(sim.state.ship_pos), "hp": sim.state.ship_hp, "facing": sim.enemies.table.facing[actor.body], "body_width": actor.body_width, "head_scale": actor.head_scale, "presentation_scale": _point(actor._presentation.scale), "body": body, "tells": tells, "tell_paths": paths, "tell_half_widths": widths, "attack": attack, "hazards": hazards}))

func _attack_case(id: StringName, angle: float, dodge: bool, distance_factor := 1.0) -> void:
	var seed_value := 5100 + IDS.find(id) * 11
	var session := _session(seed_value)
	var sim := session.sim
	var actor = sim.bosses.actor
	var direction := Vector2.from_angle(angle)
	var distance := 300.0 if id in [&"bite", &"leap", &"charge", &"tail_slam"] else 650.0
	distance *= distance_factor
	var player := direction * distance
	if id == &"tail_sweep": player = -direction * 800.0 * distance_factor
	if id in [&"spiral", &"inhale", &"rifts", &"picaro_wall", &"clones"]: player = direction * 300.0 * distance_factor
	sim.state.ship_pos = player
	# 古い照準が現在位置と違うままでも、ボスが正しい自機を狙えるか。
	sim.state.enemy_aim = player + direction.orthogonal() * 600.0
	sim.enemies.table.facing[actor.body] = angle
	var start_ok: bool = actor.start_attack(id)
	var key := "%s_%d_%s_r%d" % [id, roundi(rad_to_deg(angle)), "dodge" if dodge else "hold", roundi(distance_factor * 100.0)]
	_check(start_ok, key + " starts")
	if not start_ok:
		rows.append({"case": key, "started": false})
		session.free()
		return
	var warn := float(actor.rule().warn)
	var active := float(actor.rule().active)
	var recover := float(actor.rule().recover)
	var start_hp := sim.state.ship_hp
	var hurts: Array = []
	var transform_changes := 0
	var prior_hp := start_hp
	var dodge_direction := direction.orthogonal()
	for frame in ceili((warn + active + recover + 2.0) / STEP):
		var time := frame * STEP
		var velocity := dodge_direction * 900.0 if dodge and time >= warn * 0.9 and time < warn + 1.0 else Vector2.ZERO
		_tick(sim, velocity)
		if sim.state.ship_hp < prior_hp:
			hurts.append({"t": time, "amount": prior_hp - sim.state.ship_hp, "at": _point(sim.state.ship_pos), "mode": actor.mode})
		prior_hp = sim.state.ship_hp
		if not actor._presentation.scale.is_equal_approx(Vector2.ONE): transform_changes += 1
		if frame % 12 == 0: _sample(sim, id, key, time)
	var hit_expected := not dodge and id in [&"bite", &"leap", &"charge", &"tail_slam", &"star_fan"]
	if hit_expected: _check(not hurts.is_empty(), key + " stationary ship is hit despite old enemy aim")
	_check(actor.mode == &"idle", key + " returns to idle")
	_check(actor._presentation.scale.is_equal_approx(Vector2.ONE), key + " restores presentation transform")
	rows.append({"case": key, "attack": id, "angle_degrees": roundi(rad_to_deg(angle)), "dodge": dodge, "distance_factor": distance_factor, "started": true, "damage": start_hp - sim.state.ship_hp, "hurts": hurts, "lifecycle_idle": actor.mode == &"idle", "presentation_scaled_frames": transform_changes, "stationary_hit_required": hit_expected})
	# 同じ技を再開し、予兆/実行/回復からの中断で状態を引きずらない。
	for interrupt_at in [warn * 0.5, warn + active * 0.5, warn + active + recover * 0.5]:
		actor.cancel_attack()
		actor.cycle.cancel()
		actor.picaro.clear()
		sim.projectiles.clear_hostile()
		sim.enemies.table.pos[actor.body] = Vector2.ZERO
		sim.enemies.table.facing[actor.body] = angle
		sim.state.ship_pos = player
		sim.state.enemy_aim = player
		_check(actor.start_attack(id), key + " repeats after previous completion/cancel")
		for frame in ceili(interrupt_at / STEP): _tick(sim, Vector2.ZERO)
		actor.cancel_attack()
		_check(actor.mode == &"idle" and actor._presentation.scale.is_equal_approx(Vector2.ONE), key + " cancel resets mode/scale")
		_check(actor.body_override.is_empty(), key + " cancel clears overridden pose")
	session.free()

func _phase_case() -> void:
	var session := _session(5199)
	var sim := session.sim
	var actor = sim.bosses.actor
	actor.phase = 1
	var maximum := sim.enemies.table.max_hp[actor.body]
	for phase in [2, 3]:
		actor.start_attack(&"leap")
		sim.combat.damage_enemy(actor.body, maximum * 10.0, {"cause": &"shot"})
		_check(actor.phase == phase, "large hit advances exactly one phase")
		var expected_hp := maximum * (0.7 if phase == 2 else 0.4)
		_check(is_equal_approx(sim.enemies.table.hp[actor.body], expected_hp), "phase clamps excess damage")
		if phase == 2: _check(sim.state.controls_locked, "first generation locks controls")
		else: _check(not sim.state.controls_locked, "later phase keeps controls")
		for frame in 1800: _tick(sim, Vector2.ZERO)
		_check(not sim.state.controls_locked and not sim.state.cinematic_camera, "phase camera/control ownership releases")
	rows.append({"case": "phase_thresholds", "phase": actor.phase, "hp": sim.enemies.table.hp[actor.body], "controls_locked": sim.state.controls_locked, "camera_owned": sim.state.cinematic_camera})
	session.free()

func _identity() -> Dictionary:
	var result := {"engine":Engine.get_version_info().string}
	for directory in ["res://scripts/bosses", "res://data/bosses/draco_moves", "res://data/bosses/ai"]:
		for file in DirAccess.get_files_at(directory):
			if file.ends_with(".uid"): continue
			if directory.ends_with("/bosses") and not (file.begins_with("draco") and file.ends_with(".gd")): continue
			if directory.ends_with("/ai") and not file.begins_with("draco"): continue
			var path: String = directory.path_join(file)
			result[path] = FileAccess.get_sha256(path)
	for path in ["res://data/bosses/draco.tres", "res://.content/boss_draco.tres", "res://scripts/render/run_presentation.gd", "res://scripts/runtime/run_simulation.gd", "res://scripts/ui/hud.gd"]: result[path] = FileAccess.get_sha256(path)
	return result
