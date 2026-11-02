## 通常入口向けの互換Runner。編集値は専用Resourceを使う。
@tool
extends "res://scripts/data_types/boss_techniques/monoceros/sweep.gd"

func make_runner() -> RefCounted:
	return Runner.new()

func attack_length() -> float:
	return approach_max + stop_time + active + hold + return_time

func reach_limit(horn: float) -> float:
	var accelerated := minf(approach_max, maxf(0.0, approach_speed_max - approach_speed_start) / maxf(approach_accel, 0.001))
	return approach_speed_start * accelerated + 0.5 * approach_accel * accelerated * accelerated + approach_speed_max * maxf(0.0, approach_max - accelerated) + horn

class Runner extends "res://scripts/bosses/monoceros/technique_runner.gd":
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var side := 1
	var base := 0.0
	var v := 0.0

	func kind() -> StringName:
		return &"sweep"

	func sequenced() -> bool:
		return true

	func horn_angle(_host: MonocerosBoss) -> float:
		return angle

	func glow(host: MonocerosBoss) -> float:
		return glow_level if host.mode in [&"windup", &"active"] else 0.0

	func booster(host: MonocerosBoss) -> float:
		return 0.55 + 1.95 * v / maxf(float(host.rule().approach_speed_max), 0.001) if stage == &"approach" else 0.3 if stage == &"stop" else 0.55

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
		side = host.sweep_side
		angle = host.table.facing[host.body]
		v = float(host.rule().approach_speed_start)
		_enter(&"approach")
		host._cue(&"telegraph")

	func _enter(next: StringName) -> void:
		stage = next
		stage_time = 0.0

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		var prior := host.horn_points()
		var before := stage_time
		stage_time += dt
		match stage:
			&"approach":
				v = minf(float(r.approach_speed_max), v + float(r.approach_accel) * dt)
				var target := (host.run_state.ship_pos - host.table.pos[host.body]).angle()
				host.table.facing[host.body] = host.tracking_angle(rotate_toward(host.table.facing[host.body], target, float(r.approach_turn) * dt))
				host.direction = Vector2.from_angle(host.table.facing[host.body])
				host._move_body(host.direction * v * dt)
				var k := clampf(stage_time / maxf(float(r.twist_time), 0.001), 0.0, 1.0)
				angle = host.table.facing[host.body] - side * float(r.twist) * (1.0 - (1.0 - k) * (1.0 - k))
				glow_level = k
				if (host.table.pos[host.body].distance_to(host.run_state.ship_pos) < float(r.stop_range) and stage_time > float(r.approach_min)) or stage_time > float(r.approach_max):
					base = host.table.facing[host.body]
					host.locked = true
					_enter(&"stop")
					host._cue(&"sweep_stop")
					host._cue(&"aim_locked")
			&"stop":
				var k := clampf(stage_time / maxf(float(r.stop_time), 0.001), 0.0, 1.0)
				v = maxf(0.0, v - float(r.stop_decel) * dt)
				host._move_body(Vector2.from_angle(base) * v * dt)
				host.table.facing[host.body] = base
				angle = base - side * lerpf(float(r.twist), float(r.windup_twist), 1.0 - (1.0 - k) * (1.0 - k))
				if stage_time >= float(r.stop_time):
					host.mode = &"active"
					host.attack_hit = false
					host.previous_horn = host.horn_points()
					host.table.vel[host.body] = Vector2.ZERO
					_enter(&"swing")
					host._cue(&"attack_started")
			&"swing":
				var steps := maxi(1, ceili(dt / 0.008))
				for j in steps:
					var k := clampf((before + dt * float(j + 1) / steps) / maxf(float(r.active), 0.001), 0.0, 1.0)
					angle = base + side * (-float(r.windup_twist) + float(r.arc) * k * k * (1.6 - 0.6 * k))
					var next := host.horn_points()
					host._damage_shape(prior, next)
					prior = next
				if stage_time >= float(r.active):
					_enter(&"hold")
					host._cue(&"swing_end")
			&"hold":
				if stage_time >= float(r.hold): _enter(&"return")
			&"return":
				var k := clampf(stage_time / maxf(float(r.return_time), 0.001), 0.0, 1.0)
				angle = lerpf(base + side * (-float(r.windup_twist) + float(r.arc)), base, k * k * (3.0 - 2.0 * k))
				if stage_time >= float(r.return_time):
					host.sweep_side = -side
					host.finish_sequence(float(r.recover))
