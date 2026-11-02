## 通常入口を切り替えるまで使う互換Runner。
@tool
extends "res://scripts/data_types/boss_techniques/canis_major/sirius_flame.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var values: Dictionary
	var age := 0.0
	var emit_left := 0.0
	var started := false
	func kind() -> StringName: return &"sirius_flame"
	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		host.mode = &"windup"
		host.table.vel[host.body] = Vector2.ZERO
		host._cue(&"flame_windup")
	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		age += dt
		if not started:
			if host._moves[kind()].track_during_warn: host._face(host.run_state.enemy_aim, host.def.turn, dt)
			host.table.vel[host.body] = Vector2.ZERO
			emit_left += dt * 18.0
			while emit_left >= 1.0:
				emit_left -= 1.0
				host.sirius_effects.flame_particle(host.mouth(), host.table.facing[host.body], values, false)
			if age < float(values.warn): return
			started = true
			age = 0.0
			emit_left = 0.0
			host.mode = &"active"
			host._cue(&"flame_start")
		host._face(host.run_state.ship_pos, float(values.turn), dt)
		if host.table.pos[host.body].distance_to(host.run_state.ship_pos) > float(values.advance_until):
			host._move_body(Vector2.from_angle(host.table.facing[host.body]) * float(values.advance) * dt, dt)
		else: host.table.vel[host.body] = Vector2.ZERO
		emit_left += dt * float(values.emit_rate)
		while emit_left >= 1.0:
			emit_left -= 1.0
			host.sirius_effects.flame_particle(host.mouth(), host.table.facing[host.body], values, true)
		if age >= float(values.duration): finish(host, float(values.recover))
	func windup_progress(_host: CanisMajorBoss) -> float:
		return clampf(age / maxf(float(values.warn), 0.001), 0, 1) if not started else 1.0
	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"flame": host.mode in [&"windup", &"active"], "glow": windup_progress(host) if host.mode in [&"windup", &"active"] else 0.0}
