## 通常入口を切り替えるまで使う互換Runner。
@tool
extends "res://scripts/data_types/boss_techniques/canis_major/sirius.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var aim: FlameAim
	var values: Dictionary
	var shot := 0
	var gap_left := 0.0
	var trailed := false
	func kind() -> StringName: return &"sirius"
	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		start_shot(host)
	func start_shot(host: CanisMajorBoss) -> void:
		aim = FlameAim.new()
		trailed = false
		aim.begin(host, {"warn": values.warn, "lock": values.lock, "lead": values.lead, "turn": values.aim_turn, "length": values.beam_length, "width": values.beam_width, "time": values.beam_time, "damage": values.damage, "preset":values.flame_settings})
	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		host.table.vel[host.body] = Vector2.ZERO
		if gap_left > 0.0:
			gap_left -= dt
			if gap_left <= 0.0: start_shot(host)
			return
		var done := aim.step(host, dt)
		if aim.fired and not trailed:
			trailed = true
			host.sirius_effects.add_trail(aim.result, values)
		if not done: return
		shot += 1
		if shot >= int(values.shots): finish(host, float(values.recover))
		else: gap_left = maxf(0.001, float(values.shot_gap))
	func windup_progress(_host: CanisMajorBoss) -> float: return aim.progress() if aim != null else 0.0
	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"glow": windup_progress(host), "gather": host.mode == &"windup"}
