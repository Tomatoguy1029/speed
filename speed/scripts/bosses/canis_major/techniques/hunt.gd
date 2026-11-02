## 通常入口を切り替えるまで使う互換Runner。
@tool
extends "res://scripts/data_types/boss_techniques/canis_major/hunt.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var stream: RefCounted
	var aim: FlameAim
	var values: Dictionary
	func kind() -> StringName: return &"hunt"
	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		host.combo_pending = true
		host.used_at[&"stream"] = host.clock
		stream = host._moves[&"stream"].make_runner()
		stream._begin_windup(host,host._rules[&"stream"],0.0)
	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		stream.step(host,dt)
		if host.combo_pending and stream.sent and host.clock >= stream.last_launch + float(values.gap):
			host.combo_pending = false
			aim = FlameAim.new()
			aim.begin(host,{"warn": values.aim_warn, "lock": values.aim_lock, "lead": values.aim_lead, "turn": values.aim_turn, "length": values.beam_length, "width": values.beam_width, "time": values.beam_time, "damage": values.damage, "preset":values.flame_settings})
		if aim != null and aim.step(host,dt): finish(host,float(values.recover))
	func cancel(host: CanisMajorBoss) -> void:
		if stream != null: stream.cancel(host)
		host.sirius_effects.warnings.clear()
		host.combo_pending = false
	func windup_progress(host: CanisMajorBoss) -> float:
		return aim.progress() if aim != null else stream.windup_progress(host)
	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"shout": aim == null and host.mode == &"windup", "glow": aim.progress() if aim != null else 0.0}
