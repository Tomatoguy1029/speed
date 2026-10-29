## 分離した通常の蛇の技。泳ぐ位置と、伸長・発射・持続する判定を分ける。
extends RefCounted

static func duration(id: StringName, p: Dictionary) -> float:
	match id:
		&"bite_thrust", &"thunder_headbutt": return float(p.normal_lunge)
		&"bite_sweep": return float(p.sweep_time)
		&"beam_fixed": return float(p.beam_time)
		&"wind_band": return float(p.wind_time)
		&"wind_blades": return 2.0 * float(p.blade_interval)
		&"thunder_drop": return float(p.thunder_flash)
	return 0.0

static func phase(a: Node, n) -> StringName:
	var p: Dictionary = a.move_params(n.mode)
	if n.t < float(p.normal_charge): return &"windup"
	return &"active" if n.t < float(p.normal_charge) + duration(n.mode, p) else &"hold"

static func tick(a: Node, n, dt: float) -> void:
	var id: StringName = n.mode
	var p: Dictionary = a.move_params(id)
	var charge := float(p.normal_charge)
	var elapsed: float = n.t - charge
	if a.tracks_during_warn(id) and n.t <= minf(float(p.get("aim_tracking", 0.0)), charge): n.target = a.run_state.ship_pos
	var stage := phase(a, n)
	if stage == &"hold" and n.motion.get("normal_phase", &"") != &"hold":
		a.SNAKE.watch_player(n, a.run_state.rng, a.def.params.squad, a.squad.profile(n))
	n.motion.normal_phase = stage
	if n.t < charge:
		a.aim_neck(n, (n.target - n.free_pos).angle(), dt)
		n.glow = n.t / maxf(charge, 0.001)
		if id == &"beam_fixed":
			var points := PackedVector2Array([n.free_pos, n.free_pos + Vector2.from_angle(n.look_angle) * float(p.beam_len)])
			if n.emission.is_empty(): n.emission = a.attack_field.add_shape(points, float(p.beam_width), charge - n.t, float(p.beam_time), float(p.beam_dmg), &"beam", n.row)
			else: n.emission.points = points
	if id == &"thunder_drop" and not n.locked:
		var points := PackedVector2Array([n.target, n.target + Vector2(0.1, 0)])
		if n.emission.is_empty(): n.emission = a.attack_field.add_shape(points, float(p.thunder_radius) * 2.0, maxf(0.0, charge - n.t), float(p.thunder_flash), float(p.beam_dmg), &"lightning", n.row)
		else: n.emission.points = points
		if n.t >= charge * float(p.target_lock_fraction):
			n.locked = true
			a._cue(&"target_locked", id, a.head_index(n))
	if elapsed >= 0.0:
		if n.step == 0:
			n.locked = true
			n.strike_from = n.free_pos
			n.strike_pos = n.free_pos
			n.sweep = n.look_angle
			n.step = 1
			a._cue(&"attack_started", id, a.head_index(n))
			match id:
				&"beam_bolt":
					var direction := Vector2.from_angle(n.sweep)
					a.attack_field.add_shape(PackedVector2Array([n.free_pos, n.free_pos + direction * float(p.bolt_length)]), float(p.bolt_width), 0.0, float(p.bolt_life), float(p.beam_dmg), &"bolt", n.row, direction * float(p.bolt_speed), true)
				&"rubble_lump", &"rubble_fan":
					var runner: RefCounted = a._moves[id].make_runner()
					if id == &"rubble_lump": runner.launch_rubble(a, n, n.sweep, float(p.lump_r))
					else:
						for i in int(p.rubble_count):
							var angle: float = n.sweep + float(p.rubble_spread) * (float(i) / maxf(1.0, float(p.rubble_count) - 1.0) - 0.5)
							runner.launch_rubble(a, n, angle, float(p.rubble_small_radius))
				&"wind_band":
					n.emission = a.attack_field.add_shape(PackedVector2Array([n.free_pos, n.free_pos + Vector2.from_angle(n.sweep) * float(p.wind_length)]), float(p.wind_width), 0.0, float(p.wind_time), 0.0, &"wind", n.row)
					n.emission.wind_force = float(p.wind_force)
		if stage == &"active": n.look_angle = n.sweep
		if id in [&"bite_thrust", &"bite_sweep", &"thunder_headbutt"]:
			_extend(a, n, p, elapsed)
		elif id == &"wind_blades":
			# 向きは狙い固定時の値を使い、放つ位置は毎回の頭に付ける。
			if n.step <= 3 and elapsed >= (n.step - 1) * float(p.blade_interval):
				var angle: float = n.sweep + ((n.step - 1) * 0.5 - 0.5) * float(p.blade_spread)
				var points := PackedVector2Array()
				for i in 13:
					var arc := -PI * 0.5 + PI * i / 12.0
					points.append(n.free_pos + Vector2(cos(arc) * float(p.blade_size) * 0.6, sin(arc) * float(p.blade_size)).rotated(angle))
				a.attack_field.add_shape(points, float(p.blade_width), 0.0, float(p.blade_life), float(p.bite_dmg), &"wind_blade", n.row, Vector2.from_angle(angle) * float(p.blade_speed), true)
				n.step += 1
		if id in [&"beam_fixed", &"wind_band"] and not n.emission.is_empty():
			var length := float(p.beam_len if id == &"beam_fixed" else p.wind_length)
			n.emission.points = PackedVector2Array([n.free_pos, n.free_pos + Vector2.from_angle(n.sweep) * length])
		n.glow = 0.0
	if elapsed >= duration(id, p) + float(p.normal_hold): a.finish_normal(n)

static func _extend(a: Node, n, p: Dictionary, elapsed: float) -> void:
	if n.motion.get("lunge_done", false): return
	var previous: Vector2 = a._head_pos(n)
	var fraction := clampf(elapsed / maxf(duration(n.mode, p), 0.001), 0.0, 1.0)
	if n.mode == &"bite_sweep":
		var angle: float = n.sweep + float(p.sweep_arc) * (fraction - 0.5)
		n.strike_pos = n.strike_from + Vector2.from_angle(angle) * float(p.sweep_reach)
		n.look_angle = angle
	else:
		n.strike_pos = n.strike_from.lerp(n.target, fraction)
		n.look_angle = (n.target - n.strike_from).angle()
	n.motion.extension = true
	n.free_pos = a._head_pos(n)
	n.strike_pos = n.free_pos
	if elapsed < duration(n.mode, p):
		a.attack_field.add_shape(PackedVector2Array([previous, n.free_pos]), float(p.bite_radius), 0.0, 0.1, float(p.bite_dmg), &"bite", n.row)
	else:
		if n.mode == &"thunder_headbutt": a.attack_field.add_shape(PackedVector2Array([n.free_pos, n.free_pos + Vector2(0.1, 0)]), float(p.thunder_radius) * 2.0, 0.0, float(p.thunder_flash), float(p.beam_dmg), &"lightning", n.row)
		n.motion.extension = false
		n.motion.lunge_done = true
		n.angle = n.look_angle
		n.velocity = Vector2.from_angle(n.angle) * float(a.def.params.squad.attack_speed) * float(a.def.params.squad.lunge_momentum)
