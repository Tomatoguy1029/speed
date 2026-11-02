## 通常入口の互換Runner。編集値とC++実行は別に持つ。
@tool
extends "res://scripts/data_types/boss_techniques/monoceros/lance.gd"

func make_runner() -> RefCounted:
	return Runner.new()

func attack_length() -> float:
	return warn + distance / maxf(speed, 0.001) + stop_time

func reach_limit(horn: float) -> float:
	return distance + horn + head_length

class Runner extends "res://scripts/bosses/monoceros/techniques/charge.gd".Runner:
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var form := 0.0
	var traveled := 0.0
	var boom_time := 0.0
	var v := 0.0
	var shattered := false

	func kind() -> StringName:
		return &"lance"

	func sequenced() -> bool:
		return true

	func horn_angle(host: MonocerosBoss) -> float:
		return host.table.facing[host.body]

	func horn_points(host: MonocerosBoss, _sweep_fraction := -1.0) -> PackedVector2Array:
		var at := host.table.pos[host.body]
		var u := Vector2.from_angle(host.table.facing[host.body])
		return PackedVector2Array([at + u * host.table.r[host.body] * 0.65, at + u * (host.horn_length() + float(host.rule().head_length) * form)])

	func hit_width(host: MonocerosBoss) -> float:
		return float(host.rule().width)

	func glow(host: MonocerosBoss) -> float:
		return glow_level if host.mode in [&"windup", &"active"] else 0.0

	func booster(_host: MonocerosBoss) -> float:
		return 0.55 + 0.45 * form if stage == &"gather" else 3.5 if stage == &"run" else 1.0

	func _begin_pass(host: MonocerosBoss) -> void:
		host.timeline.stop()
		host.mode = &"windup"
		host.locked = false
		host.attack_hit = false
		host.table.vel[host.body] = Vector2.ZERO
		host.aim_point = host._strike_aim()
		host.direction = Vector2.from_angle(host.table.facing[host.body])
		angle = host.table.facing[host.body]
		_enter(&"gather")
		host._cue(&"telegraph")

	func _enter(next: StringName) -> void:
		stage = next
		stage_time = 0.0

	func _launch(host: MonocerosBoss) -> void:
		if host._path_blocked():
			begin_reposition(host)
			return
		host.direction = Vector2.from_angle(host.table.facing[host.body])
		host.attack_hit = false
		host.previous_horn = host.horn_points()
		host.mode = &"active"
		form = 1.0
		_enter(&"run")
		host._cue(&"attack_started")
		host._cue(&"lance_launch")

	func _stop(host: MonocerosBoss) -> void:
		v = float(host.rule().speed)
		_enter(&"stop")

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		var prior := host.horn_points()
		stage_time += dt
		match stage:
			&"gather":
				if not host.locked:
					host.table.facing[host.body] = host.tracking_angle(rotate_toward(host.table.facing[host.body], (host.run_state.ship_pos - host.table.pos[host.body]).angle(), float(r.aim_turn) * dt))
					host.aim_point = host.tracking_target(host.run_state.ship_pos)
					if stage_time >= float(r.warn) - float(r.lock_time):
						host.locked = true
						host._cue(&"aim_locked")
				host.direction = Vector2.from_angle(host.table.facing[host.body])
				host._move_body(-host.direction * float(r.back_speed) * dt)
				var k := clampf(stage_time / maxf(float(r.warn), 0.001), 0.0, 1.0)
				form = 1.0 - (1.0 - k) * (1.0 - k)
				glow_level = form
				if stage_time >= float(r.warn): _launch(host)
			&"run":
				form = 1.0
				var step := host.direction * minf(float(r.speed) * dt, maxf(0.0, float(r.distance) - traveled))
				var outcome := advance_charge(host, dt, prior, step, false)
				if outcome == &"blocked":
					_stop(host)
					return
				traveled += step.length()
				boom_time += dt
				while boom_time >= maxf(float(r.boom_interval), 0.001):
					boom_time -= maxf(float(r.boom_interval), 0.001)
					host._cue(&"sonic_boom")
				if traveled >= float(r.distance): _stop(host)
			&"stop":
				v *= exp(-float(r.stop_decay) * dt)
				host._move_body(host.direction * v * dt)
				if not shattered and stage_time >= float(r.shatter_time):
					shattered = true
					form = 0.0
					glow_level = 0.0
					host._cue(&"lance_shatter")
				if stage_time >= float(r.stop_time): host.finish_sequence(float(r.recover))
