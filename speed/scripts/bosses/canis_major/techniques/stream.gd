## 通常入口を切り替えるまで使う互換Runner。
@tool
extends "res://scripts/data_types/boss_techniques/canis_major/stream.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var started := 0.0
	var sent := false
	var values: Dictionary = {}

	func kind() -> StringName: return &"stream"

	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		started = host.clock
		host.mode = &"windup"
		host.table.vel[host.body] = Vector2.ZERO
		host._cue(&"stream_windup")

	func step(host: CanisMajorBoss, dt: float) -> bool:
		if not sent:
			host._face(host.run_state.enemy_aim, host.def.turn, dt)
			if host.clock - started < float(values.warn): return false
			sent = true
			begin_sequence(host, shuffled_pack(host), host.clock, float(values.interval), float(values.each_warn))
			host.mode = &"active"
		tick_sequence(host, values, "stream")
		tick_lunges(host)
		return host.clock >= last_launch + float(values.lunge_time)

	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		host.table.vel[host.body] = Vector2.ZERO
		if step(host, dt): finish(host, float(values.recover))

	func windup_progress(host: CanisMajorBoss) -> float:
		return clampf((host.clock - started) / maxf(float(values.warn), 0.001), 0, 1)

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"shout": host.mode == &"windup"}
