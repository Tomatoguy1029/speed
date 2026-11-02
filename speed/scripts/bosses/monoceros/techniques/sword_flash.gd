## 通常入口の互換Runner。編集値は専用Resourceへ置く。
@tool
extends "res://scripts/data_types/boss_techniques/monoceros/sword_flash.gd"

func make_runner() -> RefCounted:
	return Runner.new()

func attack_length() -> float:
	return first_windup + (cuts - 1) * windup + cuts * (swing_time + cut_gap) + return_time

func reach_limit(_horn: float) -> float:
	return slash_max + slash_length * 0.5

class Runner extends "res://scripts/bosses/monoceros/technique_runner.gd":
	var stage: StringName
	var stage_time := 0.0
	var angle := 0.0
	var glow_level := 0.0
	var i := 0
	var side := 1
	var target := Vector2.ZERO
	var base := 0.0
	var v := 0.0
	var released := false
	var released_at := 0.0

	func kind() -> StringName:
		return &"sword_flash"

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
		target = host.tracking_target(host.run_state.ship_pos)
		angle = host.table.facing[host.body]
		_enter(&"aim")
		host._cue(&"telegraph")

	func _enter(next: StringName) -> void:
		stage = next
		stage_time = 0.0

	func _release(host: MonocerosBoss) -> void:
		var r := host.rule()
		var center := host.table.pos[host.body] + Vector2.from_angle(base) * clampf(host.table.pos[host.body].distance_to(target), float(r.slash_min), float(r.slash_max))
		var u := Vector2.from_angle(base + side * float(r.slash_angle))
		host.last_slash = PackedVector2Array([center - u * float(r.slash_length) * 0.5, center + u * float(r.slash_length) * 0.5])
		host.attack_hit = false
		released = true
		released_at = stage_time
		glow_level = 0.0
		host._cue(&"slash_release")

	func _hit_slash(host: MonocerosBoss) -> void:
		if host.attack_hit: return
		var line := host.last_slash
		var ship := host.run_state.ship_pos
		var prior := host.previous_ship
		var radius := float(host.rule().slash_width) * 0.5 + host.ctx.cfg.ship_radius
		if Geometry2D.segment_intersects_segment(prior, ship, line[0], line[1]) != null:
			host._hit_ship()
		for pair in [[ship, line[0], line[1]], [prior, line[0], line[1]], [line[0], prior, ship], [line[1], prior, ship]]:
			if Geometry2D.get_closest_point_to_segment(pair[0], pair[1], pair[2]).distance_squared_to(pair[0]) <= radius * radius: host._hit_ship()

	func advance_sequence(host: MonocerosBoss, dt: float) -> void:
		var r := host.rule()
		stage_time += dt
		match stage:
			&"aim":
				var duration := float(r.first_windup) if i == 0 else float(r.windup)
				var k := clampf(stage_time / maxf(duration, 0.001), 0.0, 1.0)
				if not host.locked:
					host.table.facing[host.body] = host.tracking_angle(rotate_toward(host.table.facing[host.body], (host.run_state.ship_pos - host.table.pos[host.body]).angle(), float(r.aim_turn) * dt))
					target = host.tracking_target(host.run_state.ship_pos)
					if stage_time >= duration - float(r.lock_time):
						host.locked = true
						host._cue(&"aim_locked")
				glow_level = 1.0 - (1.0 - k) * (1.0 - k)
				angle = host.table.facing[host.body] - side * float(r.pull) * glow_level
				if stage_time >= duration:
					base = host.table.facing[host.body]
					v = float(r.lunge_speed)
					released = false
					host.mode = &"active"
					_enter(&"swing")
					host._cue(&"attack_started")
			&"swing":
				var k := clampf(stage_time / maxf(float(r.swing_time), 0.001), 0.0, 1.0)
				var e := k * k * (3.0 - 2.0 * k)
				angle = base + side * (-float(r.pull) + 2.0 * float(r.pull) * e)
				v *= exp(-float(r.lunge_decay) * dt)
				host._move_body(Vector2.from_angle(base) * v * dt)
				if not released and e >= 0.5: _release(host)
				if released and stage_time - released_at <= float(r.slash_hit_time): _hit_slash(host)
				if k >= 1.0 and released and stage_time - released_at >= float(r.slash_hit_time):
					host.table.vel[host.body] = Vector2.ZERO
					_enter(&"gap" if i + 1 < int(r.cuts) else &"return")
					if stage == &"gap": host.locked = false
			&"gap":
				if stage_time >= float(r.cut_gap):
					i += 1
					side = 1 if i % 2 == 0 else -1
					target = host.tracking_target(host.run_state.ship_pos)
					_enter(&"aim")
			&"return":
				var k := clampf(stage_time / maxf(float(r.return_time), 0.001), 0.0, 1.0)
				angle = lerpf(base + side * float(r.pull), host.table.facing[host.body], k * k * (3.0 - 2.0 * k))
				if stage_time >= float(r.return_time): host.finish_sequence(float(r.recover))
