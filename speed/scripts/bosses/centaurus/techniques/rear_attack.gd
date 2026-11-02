## 通常入口を切り替えるまで使う互換Runner。編集値は専用Resourceへ置く。
@tool
extends "res://scripts/data_types/boss_techniques/centaurus/rear_attack.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	func strike_on(host: CentaurusBoss) -> void:
		if host.mode != &"windup": return
		host.mode = &"strike"
		host.attack_hit = false
		host._cue(&"strike")

	## 背後攻撃の範囲の中心。背中から back_offset だけ後ろ。

	func rear_center(host: CentaurusBoss, r: Dictionary) -> Vector2:
		return host.table.pos[host.body] - Vector2.from_angle(host.table.facing[host.body]) * float(r.back_offset)

	func _strike_tick(host: CentaurusBoss) -> void:
		if host.attack_hit: return
		host.combat_trace.evaluate()
		var r := host.rule()
		var center := host.rear_center(r)
		var reach := float(r.range_radius) + host.ctx.cfg.ship_radius
		if Geometry2D.get_closest_point_to_segment(center, host._previous_ship, host.run_state.ship_pos).distance_to(center) <= reach:
			host.attack_hit = true
			host.combat_trace.damage(float(r.damage) * host.ctx.cfg.atk_scale, 0.0, &"rear_attack", &"centaurus")

	## 背後攻撃を共通フローが今すぐ選べるか。選べる間は離脱より背後攻撃を優先する。

	func kind() -> StringName:
		return &"rear_attack"

	func body_pose(host: CentaurusBoss) -> Dictionary:
		var result := super(host)
		if host.mode in [&"windup", &"strike"]:
			var blink := 1.0 if host.mode == &"strike" else 0.5 + 0.5 * sin(host.clock * TAU * 6.0)
			result.tint = Color.WHITE.lerp(Color(1.9, 0.35, 0.35), blink)
		return result
