## 同時噛みつきの値と動き。
@tool
extends HydraTechnique

## bite_dmg
@export_range(0,100000,0.01) var bite_dmg := 16.0
## bite_radius
@export_range(0,100000,0.01) var bite_radius := 75.0
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cooldown := 14.0
## 北の首の飛行時間
@export_range(0,100000,0.01) var north_flight := 0.3
## 北の首の固定時間
@export_range(0,100000,0.01) var north_lock_time := 1.4
## north_spread
@export_range(0,100000,0.01) var north_spread := 120.0
## 実行時間（秒）
@export_range(0,100000,0.01) var performance_time := 1.2
## 技後の全体待ち（秒）
@export_range(0,100000,0.01) var tech_recovery := 1.5
## 予告（秒）
@export_range(0,100000,0.01) var warning_time := 2.4

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/hydra/technique_runner.gd":
	func _update_north_targets(host: Node) -> void:
		host.north_target = host.run_state.ship_pos
		var direction = (host.north_target-host.table.pos[host.body]).normalized()
		var side = direction.orthogonal()
		var center = host.table.pos[host.body]+direction*maxf(host.north_target.distance_to(host.table.pos[host.body]),host.table.r[host.body]+float(host.def.params.neck_rest))
		var ordered = host.participants.duplicate()
		ordered.sort_custom(func(a,b):return host._neck_base(a).dot(side) < host._neck_base(b).dot(side))
		for i in ordered.size():
			ordered[i].target = center+side*float(host.move_params(&"north").north_spread)*(i-1)

	func north_curl(host: Node) -> void:
		host._update_north_targets()
		host.north_aiming = false
		host._cue(&"target_locked", &"north", -1, {"target_position": host.north_target})

	func north_burst(host: Node) -> void:
		host.north_aiming = false
		host._north_duration = maxf(0.001, host._timeline_key_time(&"north", &"north_follow") - host._timeline_key_time(&"north", &"north_burst"))
		host._cue(&"attack_started")
		for neck in host.participants:
			if host._alive(neck):
				neck.strike_from = host._head_pos(neck)
				neck.strike_pos = neck.strike_from
				neck.mode = &"tech_lunge"
				neck.t = 0.0
				neck.angle = (neck.target - neck.strike_from).angle()
				host._cue(&"attack_started", &"north", host.necks.find(neck), {"target_position": neck.target})

	## 先端の移動区間にも判定を出し、粗い固定更新で標的位置を飛び越えない。

	func _north_step(host: Node, neck, fraction: float, dt: float) -> void:
		var previous = neck.strike_pos
		neck.strike_pos = neck.strike_from.lerp(neck.target, fraction)
		host._release_attack(neck)
		neck.glow = 1.0
		var delta = neck.strike_pos - previous
		neck.hazard = host.ctx.projectiles.fire_wall(previous, delta.angle(), delta.length(), float(host.move_params(&"north").bite_radius) * 2.0,
			0.0, maxf(dt, 0.001) + 0.001, float(host.move_params(&"north").bite_dmg), Color("#ff7a5a"))
		host.ctx.projectiles.attach_hazard(neck.hazard, neck.row)
		if fraction >= 1.0:
			neck.mode = &"tech_hold"

	## 世界の更新がキーをまたいでも、最後の区間を判定してから止める。

	func north_follow(host: Node) -> void:
		for neck in host.necks:
			if neck.mode == &"tech_lunge":
				host._north_step(neck, 1.0, host._sim_dt)

	## 瓦礫を砕き、破片を飛ばす。from が 0 でなければ、その向きを中心に飛ばす。
