## 通常入口の互換Runner。編集値は専用Resourceへ置く。
@tool
extends "res://scripts/data_types/boss_techniques/monoceros/return_charge.gd"

func attack_length(phase_values: Dictionary = {}) -> float:
	var r := values() if phase_values.is_empty() else phase_values
	return float(r.warn) + int(r.passes) * float(r.active) + (int(r.passes) - 1) * (float(r.brake_time) + float(r.turn_time))

func reach_limit(horn: float) -> float:
	return distance + horn

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/monoceros/techniques/charge.gd".Runner:
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var cdir := Vector2.RIGHT
	var travel := 0.0
	var traveled := 0.0
	var completed := 0
	var fa := 0.0
	var fd := 0.0

	func kind() -> StringName:
		return &"return_charge"

	func sequenced() -> bool:
		return true

	func horn_angle(_host: MonocerosBoss) -> float:
		return angle

	func glow(host: MonocerosBoss) -> float:
		return glow_level if host.mode in [&"windup", &"active"] else 0.0

	func booster(_host: MonocerosBoss) -> float:
		return 0.55 + 0.45 * glow_level if stage == &"aim" else 2.5 if stage == &"run" else 0.55

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

	func _launch(host: MonocerosBoss) -> void:
		if host._path_blocked():
			begin_reposition(host)
			return
		var r := host.rule()
		cdir = Vector2.from_angle(host.table.facing[host.body])
		host.direction = cdir
		travel = minf(float(r.distance), host.table.pos[host.body].distance_to(host.run_state.ship_pos) + float(r.overshoot))
		traveled = 0.0
		angle = host.table.facing[host.body]
		glow_level = 0.0
		host.attack_hit = false
		host.previous_horn = host.horn_points()
		host.mode = &"active"
		_enter(&"run")
		host._cue(&"attack_started")

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		var prior := host.horn_points()
		stage_time += dt
		match stage:
			&"aim":
				if not host.locked:
					if host._tracks_during_warn(): _aim(host, dt)
					if stage_time >= float(r.warn) - float(host.def.params.lock_lead): lock_aim(host)
				angle = host.table.facing[host.body]
				glow_level = clampf(stage_time / maxf(float(r.warn), 0.001), 0.0, 1.0)
				if stage_time >= float(r.warn): _launch(host)
			&"run":
				var step := cdir * minf(float(r.distance) / maxf(float(r.active), 0.001) * dt, maxf(0.0, travel - traveled))
				var outcome := advance_charge(host, dt, prior, step, true)
				if outcome == &"stuck": return
				if outcome == &"blocked":
					host.finish_sequence(float(r.recover))
					return
				traveled += step.length()
				if traveled >= travel:
					completed += 1
					if completed >= int(r.passes):
						host.finish_sequence(float(r.recover))
					else:
						host.locked = false
						_enter(&"brake")
						host._cue(&"brake")
			&"brake":
				var k := clampf(stage_time / maxf(float(r.brake_time), 0.001), 0.0, 1.0)
				var speed := float(r.distance) / maxf(float(r.active), 0.001) * float(r.brake_speed_ratio) * (1.0 - k)
				host._move_body(cdir * speed * dt)
				angle = host.table.facing[host.body]
				if stage_time >= float(r.brake_time):
					fa = host.table.facing[host.body]
					fd = wrapf((host.run_state.ship_pos - host.table.pos[host.body]).angle() - fa, -PI, PI)
					_enter(&"turn")
			&"turn":
				var target := (host.run_state.ship_pos - host.table.pos[host.body]).angle()
				var df := wrapf(target - fa, -PI, PI)
				if absf(df - fd) > PI: df += signf(fd - df) * TAU
				fd = df
				if not host.locked:
					var q := clampf(stage_time / maxf(float(r.turn_time) - float(r.turn_lock), 0.001), 0.0, 1.0)
					host.table.facing[host.body] = host.tracking_angle(fa + df * q * q * (3.0 - 2.0 * q))
					if not host.tracking_locked(): angle = host.table.facing[host.body] + clampf(wrapf(target - host.table.facing[host.body], -PI, PI), -float(r.head_lead), float(r.head_lead)) * sin(PI * q)
					host.aim_point = host.tracking_target(host.run_state.ship_pos)
					host.direction = Vector2.from_angle(host.table.facing[host.body])
					if stage_time >= float(r.turn_time) - float(r.turn_lock):
						host.locked = true
						host._cue(&"aim_locked")
				if host.locked: angle = host.table.facing[host.body]
				if stage_time >= float(r.turn_time): _launch(host)
