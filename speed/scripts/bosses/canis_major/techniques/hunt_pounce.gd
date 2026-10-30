## 追い立てと飛びかかりの値と動き。
@tool
extends BossTechnique

## 最後の猟犬の発進から飛びかかりの予告まで（秒）
@export_range(0,100000,0.01) var gap := 0.1:
	set(value):
		gap = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 9.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var stream: RefCounted
	var jump: RefCounted
	var gap_time := 0.0

	func kind() -> StringName: return &"hunt_pounce"

	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		gap_time = float(r.gap)
		host.combo_pending = true
		host.used_at[&"stream"] = host.clock
		stream = host._moves[&"stream"].make_runner()
		stream._begin_windup(host, host._rules[&"stream"], 0.0)

	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		# 群れの突進が残っていても、本体の予告を始める。
		stream.step(host, dt)
		if host.combo_pending and stream.sent and host.clock >= stream.last_launch + gap_time:
			host.combo_pending = false
			host.used_at[&"pounce"] = host.clock
			jump = host._moves[&"pounce"].make_runner()
			jump.start_jump(host, host._rules[&"pounce"], 1)
		if jump != null and jump.step(host, dt):
			finish(host, float(host._rules[&"pounce"].recover))

	func cancel(host: CanisMajorBoss) -> void:
		if stream != null: stream.cancel(host)
		host.combo_pending = false

	func windup_progress(host: CanisMajorBoss) -> float:
		return jump.windup_progress(host) if jump != null else stream.windup_progress(host)

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return jump.body_pose(host) if jump != null else {"shout": host.mode == &"windup"}
