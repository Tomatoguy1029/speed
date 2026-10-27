## 技ごとの避け方を実際のダメージ経路で検証する。横移動だけを全技の正解にしない。
extends "res://tests/draco_encounter_qa.gd"
var current_path := ""
var current_attack: StringName = &""
var sample_counter := 0
func _ready() -> void:
	stage_template = ContentManager.runtime_stage(5)
	identity_start = _identity()
	DirAccess.make_dir_recursive_absolute(output)
	snapshots = FileAccess.open(output.path_join("designed-path-samples.jsonl"), FileAccess.WRITE)
	for angle in [0.0, PI * 0.25, PI * 0.5]:
		for id in [&"charge", &"leap", &"tail_slam", &"star_fan"]: _course(id, angle)
	_tail_escape()
	_fan_escape()
	_leap_escape()
	_breath_cover(false)
	_breath_cover(true)
	_rift_paths()
	_arrows(false)
	_arrows(true)
	_inhale(false)
	_inhale(true)
	_spiral(false)
	_spiral(true)
	var file := FileAccess.open(output.path_join("designed-paths.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"identity_start":identity_start,"identity_end":_identity(),"cases":rows,"failures":failures},"\t"))
	file.close()
	if snapshots != null: snapshots.close()
	print("[draco_encounter_paths] cases=", rows.size(), " failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)

func _begin(id: StringName, player: Vector2, angle := 0.0) -> RunSession:
	current_path = "%s_%d" % [id,rows.size()]
	current_attack = id
	sample_counter = 0
	var session := _session(5307)
	var sim := session.sim
	var a = sim.bosses.actor
	sim.state.ship_pos = player
	sim.state.enemy_aim = player + Vector2(600,600)
	a.table.facing[a.body] = angle
	_check(a.start_attack(id), String(id) + " starts for designed path")
	return session

func _finish(session: RunSession, key: String, before: float, expect_hit: bool) -> void:
	var damage := before - session.sim.state.ship_hp
	_check((damage > 0.0) == expect_hit, key + (" must hit" if expect_hit else " must permit intended escape"))
	rows.append({"case":key,"damage":damage,"expect_hit":expect_hit,"sample_case":current_path})
	session.free()

func _course(id: StringName, angle: float) -> void:
	current_path = "%s_straight500_%d" % [id,roundi(rad_to_deg(angle))]
	current_attack = id
	sample_counter = 0
	var direction := Vector2.from_angle(angle)
	var session := _session(5311)
	var sim := session.sim
	var a = sim.bosses.actor
	sim.state.ship_pos = direction * (650.0 if id == &"star_fan" else 300.0)
	sim.state.ship_vel = direction.orthogonal() * 500.0
	sim.state.enemy_aim = sim.state.ship_pos + direction * 600.0
	a.table.facing[a.body] = angle
	a.start_attack(id)
	var duration := float(a.rule().warn) + float(a.rule().active) + float(a.rule().recover) + 1.2
	var before := sim.state.ship_hp
	for frame in ceili(duration / STEP): _tick(sim, direction.orthogonal() * 500.0)
	_finish(session, "%s_straight500_%d" % [id,roundi(rad_to_deg(angle))], before, true)

func _tail_escape() -> void:
	var session := _begin(&"tail_sweep",Vector2(-800,0))
	var a = session.sim.bosses.actor
	var warn := float(a.rule().warn)
	var duration := warn + float(a.rule().active) + float(a.rule().recover)
	var before := session.sim.state.ship_hp
	for frame in ceili(duration / STEP):
		var t := frame * STEP
		_tick(session.sim, Vector2.RIGHT * 1800.0 if t >= warn * 0.45 and t < warn + 0.7 else Vector2.ZERO)
	_finish(session,"tail_sweep_forward_escape",before,false)

func _fan_escape() -> void:
	var session := _begin(&"star_fan",Vector2(650,0))
	var a = session.sim.bosses.actor
	var warn := float(a.rule().warn)
	var duration := warn + float(a.rule().active) + float(a.rule().recover) + 1.2
	var before := session.sim.state.ship_hp
	for frame in ceili(duration / STEP):
		var t := frame * STEP
		_tick(session.sim, Vector2.LEFT * 1800.0 if t >= warn * 0.5 and t < warn + 0.6 else Vector2.ZERO)
	_finish(session,"star_fan_cross_behind_committed_head",before,false)

func _leap_escape() -> void:
	var session := _begin(&"leap",Vector2(300,0))
	var a = session.sim.bosses.actor
	var warn := float(a.rule().warn)
	var duration := warn + float(a.rule().active) + float(a.rule().recover)
	var before := session.sim.state.ship_hp
	for frame in ceili(duration / STEP):
		var t := frame * STEP
		var escape: Vector2 = (a._driver.destination-a._driver.takeoff).normalized().orthogonal() if a._driver != null else Vector2.UP
		_tick(session.sim, escape * 1200.0 if t >= warn * 0.8 and t < warn + 0.7 else Vector2.ZERO)
	_finish(session,"leap_perpendicular_to_committed_path",before,false)

func _breath_cover(destroy: bool) -> void:
	var session := _begin(&"breath",Vector2(750,0))
	var sim := session.sim
	var a = sim.bosses.actor
	var warn := float(a.rule().warn)
	for frame in ceili((warn + STEP) / STEP): _tick(sim,Vector2.ZERO)
	var driver = a._driver
	var rock = driver.rocks[1]
	sim.state.ship_pos = sim.enemies.table.pos[rock.row] + a.direction * 240.0
	if destroy:
		for entry in driver.rocks: sim.combat.damage_enemy(entry.row,100000.0,{"cause":&"shot"})
	var before := sim.state.ship_hp
	for frame in ceili(float(a.rule().active) / STEP): _tick(sim,Vector2.ZERO)
	_finish(session,"breath_" + ("cover_destroyed" if destroy else "behind_surviving_cover"),before,destroy)

func _rift_paths() -> void:
	for cross in [false,true]:
		var session := _begin(&"rifts",Vector2.ZERO)
		var sim := session.sim
		var a = sim.bosses.actor
		for frame in 1200:
			if a.mode == &"active": break
			_tick(sim,Vector2.ZERO)
		_check(a.mode == &"active", "rifts warning follows full-body staging")
		var path: PackedVector2Array = a._driver.paths[0]
		var cross_point: Vector2 = path[0].lerp(path[1], 0.35)
		var before := sim.state.ship_hp
		if cross: sim.state.ship_pos = cross_point
		for frame in ceili(0.85 / STEP): _tick(sim,Vector2.ZERO)
		var scratch_damage := before - sim.state.ship_hp
		_check((scratch_damage>0.0)==cross,"rifts scratch crossing vs center gap")
		sim.state.ship_invuln = 0.0
		sim.state.ship_pos = cross_point
		var residual_hp := sim.state.ship_hp
		for frame in 120: _tick(sim,Vector2.ZERO)
		_check(is_equal_approx(residual_hp,sim.state.ship_hp),"rifts residual blocks without damage")
		rows.append({"case":"rifts_cross" if cross else "rifts_safe_gap","scratch_damage":scratch_damage,"residual_damage":residual_hp-sim.state.ship_hp})
		session.free()

func _arrows(evade: bool) -> void:
	var session := _begin(&"picaro_wall",Vector2(300,0))
	var sim := session.sim
	var a = sim.bosses.actor
	a.picaro.pause(true) # 矢の予告だけを独立して確かめる。
	var duration := float(a.rule().warn) + float(a.rule().active) + float(a.rule().recover)
	var before := sim.state.ship_hp
	var warnings := false
	for frame in ceili(duration / STEP):
		if a._driver != null:
			for impact in a._driver.impacts:
				if impact.pos != Vector2.INF: warnings = true
		_tick(sim,Vector2.DOWN * 700.0 if evade and warnings else Vector2.ZERO)
	_check(warnings,"arrows actually shows fixed landing warnings")
	_finish(session,"arrows_" + ("leave_each_shown_warning" if evade else "hold_shown_warning"),before,not evade)

func _inhale(evade: bool) -> void:
	var session := _begin(&"inhale",Vector2(650,0))
	var sim := session.sim
	var a = sim.bosses.actor
	var duration := float(a.rule().warn) + float(a.rule().active) + float(a.rule().recover)
	var before := sim.state.ship_hp
	for frame in ceili(duration / STEP):
		var away: Vector2 = (sim.state.ship_pos - a.mouth_pos()).normalized()
		_tick(sim,away * 1200.0 if evade else Vector2.ZERO)
	_finish(session,"inhale_" + ("recurrent_boost_away" if evade else "no_boost"),before,not evade)

func _spiral(evade: bool) -> void:
	var session := _begin(&"spiral",Vector2.ZERO)
	var sim := session.sim
	var a = sim.bosses.actor
	var duration := float(a.rule().warn) + float(a.rule().active) + float(a.rule().recover)
	var before := sim.state.ship_hp
	var escaped := false
	for frame in ceili(duration / STEP):
		var can_escape: bool = a.mode == &"active" and a.elapsed >= a._driver.coil_time + 0.05 and not sim.state.controls_locked
		var move: bool = evade and can_escape and sim.state.ship_pos.x < 220.0
		_tick(sim,Vector2.RIGHT * 1700.0 if move else Vector2.ZERO)
		if evade and can_escape and sim.state.ship_pos.x >= 220.0: escaped = true
	if evade: _check(escaped,"spiral releases controls and leaves time to reach the inner escape lane")
	_finish(session,"spiral_" + ("reach_inner_gap_before_shrink" if evade else "wait_for_squeeze"),before,not evade)
	rows[-1]["escape_distance_x"] = 220.0 if evade else 0.0

func _tick(sim: RunSimulation, velocity: Vector2) -> void:
	super._tick(sim, velocity)
	if sample_counter % 12 == 0: _sample(sim, current_attack, current_path, sample_counter * STEP)
	sample_counter += 1
