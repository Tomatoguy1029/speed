## 通常入口の互換Runner。編集値は専用Resourceへ置く。
@tool
extends "res://scripts/data_types/boss_techniques/monoceros/horn_dance.gd"

func make_runner() -> RefCounted:
	return Runner.new()

func attack_length() -> float:
	return aim_time + passes * 0.6 + (passes - 1) * circle_late_time + end_time

func reach_limit(_horn: float) -> float:
	return INF

class Runner extends "res://scripts/bosses/monoceros/techniques/charge.gd".Runner:
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var run_speed := 0.0
	var travel := 0.0
	var traveled := 0.0
	var completed := 0
	var heading := 0.0
	var v := 0.0

	func kind() -> StringName:
		return &"horn_dance"

	func sequenced() -> bool:
		return true

	func horn_angle(_host: MonocerosBoss) -> float:
		return angle

	func glow(host: MonocerosBoss) -> float:
		return glow_level if host.mode in [&"windup", &"active"] else 0.0

	func booster(_host: MonocerosBoss) -> float:
		return 0.55 + 0.45 * glow_level if stage == &"aim" else 2.5 if stage == &"run" else 1.2 if stage == &"circle" else 0.55

	func body_pose(host: MonocerosBoss, _parts: Node2D) -> Dictionary:
		return {"neck": angle_difference(host.table.facing[host.body], angle), "legs": []}

	func _begin_pass(host: MonocerosBoss) -> void:
		host.timeline.stop()
		host.mode = &"windup"
		host.locked = false
		host.attack_hit = false
		host.table.vel[host.body] = Vector2.ZERO
		host.aim_point = host._strike_aim()
		host.direction = Vector2.from_angle(host.table.facing[host.body])
		angle = host.table.facing[host.body]
		_enter(&"aim")
		host._cue(&"telegraph")

	func _enter(next: StringName) -> void:
		stage = next
		stage_time = 0.0

	func _path_blocked(host: MonocerosBoss) -> bool:
		# 乱舞は固定のdistanceを持たず、狙いまでの経路を各発進時に調べる。
		var at := host.table.pos[host.body]
		var distance := maxf(float(host.def.params.near_clearance), at.distance_to(host.aim_point))
		return host.ctx.field.first_body_hit(at, at + Vector2.from_angle(host.table.facing[host.body]) * distance, host.table.r[host.body]) != null

	func _launch(host: MonocerosBoss, speed: float, from_circle: bool) -> void:
		if host._path_blocked():
			begin_reposition(host)
			return
		if from_circle: host.table.facing[host.body] = host.tracking_angle((host.run_state.ship_pos - host.table.pos[host.body]).angle())
		host.direction = Vector2.from_angle(host.table.facing[host.body])
		var r := host.rule()
		travel = maxf(float(r.min_run), host.table.pos[host.body].distance_to(host.run_state.ship_pos) + float(r.overshoot))
		traveled = 0.0
		run_speed = speed
		host.attack_hit = false
		angle = host.table.facing[host.body]
		host.previous_horn = host.horn_points()
		glow_level = 0.0
		host.mode = &"active"
		_enter(&"run")
		host._cue(&"attack_started")

	func _end(host: MonocerosBoss) -> void:
		v = run_speed
		_enter(&"end")
		host._cue(&"dance_end")

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		var prior := host.horn_points()
		stage_time += dt
		match stage:
			&"aim":
				if not host.locked:
					host.table.facing[host.body] = host.tracking_angle(rotate_toward(host.table.facing[host.body], (host.run_state.ship_pos - host.table.pos[host.body]).angle(), float(r.aim_turn) * dt))
					host.aim_point = host.tracking_target(host.run_state.ship_pos)
					if stage_time >= float(r.aim_time) - float(r.aim_lock):
						host.locked = true
						host._cue(&"aim_locked")
				angle = host.table.facing[host.body]
				glow_level = clampf(stage_time / maxf(float(r.aim_time), 0.001), 0.0, 1.0)
				if stage_time >= float(r.aim_time): _launch(host, float(r.speed), false)
			&"run":
				var step := host.direction * minf(run_speed * dt, maxf(0.0, travel - traveled))
				var outcome := advance_charge(host, dt, prior, step, true)
				if outcome == &"stuck": return
				if outcome == &"blocked":
					_end(host)
					return
				traveled += step.length()
				if traveled >= travel:
					completed += 1
					if completed >= int(r.passes):
						_end(host)
					else:
						heading = host.table.facing[host.body]
						v = run_speed
						_enter(&"circle")
						host._cue(&"dance_circle")
			&"circle":
				heading -= float(r.circle_turn) * dt
				var target_speed := float(r.circle_speed_late) if stage_time > float(r.circle_late_time) else float(r.circle_speed)
				v += clampf(target_speed - v, -float(r.circle_decel) * dt, float(r.circle_accel) * dt)
				host._move_body(Vector2.from_angle(heading) * v * dt)
				host.table.facing[host.body] = heading
				var target := host.run_state.ship_pos - host.table.pos[host.body]
				var off := wrapf(target.angle() - heading, -PI, PI)
				if not host.tracking_locked(): angle = heading + clampf(off, -float(r.head_lead), float(r.head_lead))
				glow_level = maxf(0.0, 1.0 - absf(off) / maxf(float(r.glow_angle), 0.001))
				if absf(off) < float(r.align_angle) and target.length() > float(r.align_min_distance) and stage_time > float(r.align_min_time):
					host.aim_point = host.tracking_target(host.run_state.ship_pos)
					host._cue(&"aim_locked")
					_launch(host, maxf(float(r.speed), v), true)
				elif stage_time > float(r.circle_max_time): _end(host)
			&"end":
				v *= exp(-float(r.end_decay) * dt)
				host._move_body(host.direction * v * dt)
				angle = host.table.facing[host.body]
				glow_level = 0.6 * minf(1.0, stage_time / 0.3)
				if stage_time >= float(r.end_time): host.finish_sequence(float(r.recover))
