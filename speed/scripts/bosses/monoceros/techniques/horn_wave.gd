## 通常入口の互換Runner。編集値は専用Resourceに置く。
@tool
extends "res://scripts/data_types/boss_techniques/monoceros/horn_wave.gd"

func make_runner() -> RefCounted:
	return Runner.new()

func attack_length() -> float:
	return windup + 2.0 * swing_time + recharge + return_time

func reach_limit(_horn: float) -> float:
	return wave_max

class Runner extends "res://scripts/bosses/monoceros/technique_runner.gd":
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var dir := 1
	var released := false

	func kind() -> StringName:
		return &"horn_wave"

	func sequenced() -> bool:
		return true

	func horn_angle(_host: MonocerosBoss) -> float:
		return angle

	func glow(host: MonocerosBoss) -> float:
		return glow_level if host.mode in [&"windup", &"active"] else 0.0

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
		_enter(&"windup")
		host._cue(&"telegraph")

	func _enter(next: StringName) -> void:
		stage = next
		stage_time = 0.0
		released = false

	func _face_target(host: MonocerosBoss, dt: float, turn: float) -> void:
		if host.tracking_locked(): return
		var target := host.run_state.enemy_aim if host._tracks_during_warn() else host.aim_point
		host.table.facing[host.body] = rotate_toward(host.table.facing[host.body], (target - host.table.pos[host.body]).angle(), turn * dt)

	func _swing(host: MonocerosBoss) -> void:
		host.mode = &"active"
		_enter(&"swing")
		host._cue(&"attack_started")

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		stage_time += dt
		match stage:
			&"windup":
				_face_target(host, dt, float(r.windup_turn))
				var k := clampf(stage_time / maxf(float(r.windup), 0.001), 0.0, 1.0)
				glow_level = 1.0 - (1.0 - k) * (1.0 - k)
				angle = host.table.facing[host.body] - float(r.pull) * glow_level
				if stage_time >= float(r.windup): _swing(host)
			&"swing":
				_face_target(host, dt, float(r.swing_turn))
				var k := clampf(stage_time / maxf(float(r.swing_time), 0.001), 0.0, 1.0)
				var e := k * k * (3.0 - 2.0 * k)
				angle = host.table.facing[host.body] + dir * (-float(r.pull) + 2.0 * float(r.pull) * e)
				glow_level = 1.0 - e
				if not released and e >= (float(r.pull) + float(r.release_offset)) / maxf(2.0 * float(r.pull), 0.001):
					released = true
					host.horn_waves.append({"center": host.table.pos[host.body], "angle": angle, "radius": float(r.wave_start), "speed": float(r.wave_speed), "max": float(r.wave_max), "half": float(r.wave_half_angle), "width": float(r.wave_width), "damage": float(r.damage), "hit": false})
					host._cue(&"wave_release")
				if stage_time >= float(r.swing_time): _enter(&"recharge" if dir == 1 else &"return")
			&"recharge":
				var k := clampf(stage_time / maxf(float(r.recharge), 0.001), 0.0, 1.0)
				angle = host.table.facing[host.body] + float(r.pull)
				glow_level = k
				if stage_time >= float(r.recharge):
					dir = -1
					_swing(host)
			&"return":
				var k := clampf(stage_time / maxf(float(r.return_time), 0.001), 0.0, 1.0)
				angle = host.table.facing[host.body] - float(r.pull) * (1.0 - k * k * (3.0 - 2.0 * k))
				glow_level = 0.0
				if stage_time >= float(r.return_time): host.finish_sequence(float(r.recover))
