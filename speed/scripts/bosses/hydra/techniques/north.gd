extends "res://scripts/data_types/boss_techniques/hydra/north.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func _update_north_targets(host: Node) -> void:
		host.north_target = host.tracking_target(host.run_state.ship_pos)
		var direction = (host.north_target-host.table.pos[host.body]).normalized()
		var side = direction.orthogonal()
		var center = host.table.pos[host.body]+direction*maxf(host.north_target.distance_to(host.table.pos[host.body]),host.table.r[host.body]+float(host.def.params.neck_rest))
		var ordered = host.participants.duplicate()
		ordered.sort_custom(func(a,b):return host._neck_base(a).dot(side) < host._neck_base(b).dot(side))
		for i in ordered.size():
			ordered[i].target = host.neck_tracking_target(ordered[i], center+side*float(host.move_params(host.tech).north_spread)*(i-1))

	func north_curl(host: Node) -> void:
		host._update_north_targets()
		host.north_aiming = false
		host._cue(&"target_locked", host.tech, -1, {"target_position": host.north_target})

	func north_burst(host: Node) -> void:
		host.north_aiming = false
		host._north_duration = maxf(0.001, host._timeline_key_time(host.tech, &"north_follow") - host._timeline_key_time(host.tech, &"north_burst"))
		host._cue(&"attack_started")
		for neck in host.participants:
			if host._alive(neck):
				neck.strike_from = host._head_pos(neck)
				neck.strike_pos = neck.strike_from
				neck.mode = &"tech_lunge"
				neck.t = 0.0
				neck.target = host.neck_tracking_target(neck, neck.target)
				neck.angle = (neck.target - neck.strike_from).angle()
				host._cue(&"attack_started", host.tech, host.necks.find(neck), {"target_position": neck.target})

	## 先端の移動区間にも判定を出し、粗い固定更新で標的位置を飛び越えない。

	func _north_step(host: Node, neck, fraction: float, dt: float) -> void:
		var previous = neck.strike_pos
		neck.strike_pos = neck.strike_from.lerp(neck.target, fraction)
		host._release_attack(neck)
		neck.glow = 1.0
		var delta = neck.strike_pos - previous
		neck.hazard = host.ctx.projectiles.fire_wall(previous, delta.angle(), delta.length(), float(host.move_params(host.tech).bite_radius) * 2.0,
			0.0, maxf(dt, 0.001) + 0.001, float(host.move_params(host.tech).bite_dmg), Color("#ff7a5a"))
		host.ctx.projectiles.attach_hazard(neck.hazard, neck.row)
		if fraction >= 1.0:
			neck.mode = &"tech_hold"

	## 世界の更新がキーをまたいでも、最後の区間を判定してから止める。

	func north_follow(host: Node) -> void:
		for neck in host.necks:
			if neck.mode == &"tech_lunge":
				host._north_step(neck, 1.0, host._sim_dt)

	## 瓦礫を砕き、破片を飛ばす。from が 0 でなければ、その向きを中心に飛ばす。

	func kind() -> StringName:
		return &"north"
