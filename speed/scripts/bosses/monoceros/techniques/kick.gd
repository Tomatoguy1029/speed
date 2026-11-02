## 通常入口向けの互換Runner。編集値は専用Resourceを使う。
@tool
extends "res://scripts/data_types/boss_techniques/monoceros/kick.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/monoceros/technique_runner.gd":
	var end_legs: Array[Dictionary] = []
	const REAR_LEGS := ["RearLeftLeg", "RearRightLeg"]
	const KICK_FOLD := 18.0
	const KICK_EXTEND := 0.4
	func body_pose(host: MonocerosBoss, parts: Node2D) -> Dictionary:
		var poses: Array[Dictionary] = []
		if host.mode == &"recovery" and end_legs.size() == REAR_LEGS.size():
			var back := host.settle_progress()
			for index in REAR_LEGS.size():
				var leg := parts.get_node(REAR_LEGS[index]) as Node2D
				var foot := leg.get_node("Foot") as Node2D
				var pose: Dictionary = end_legs[index]
				poses.append({"path": REAR_LEGS[index], "rotation": lerpf(pose.rotation, 0.0, back), "stretch": lerpf(pose.stretch, 1.0, back), "foot": lerpf(pose.foot, foot.position.y, back)})
			return {"neck": 0.0, "legs": poses}
		if host.mode not in [&"windup", &"active"]: return {"neck": 0.0, "legs": poses}
		end_legs.clear()
		var rule := host.rule()
		var warn := maxf(0.001, float(rule.warn))
		var elapsed := host.timeline.current_animation_position
		var tip := Vector2.from_angle(angle_difference(host.table.facing[host.body], host.direction.angle())) * float(rule.reach)
		var tip_in_parts := parts.transform.affine_inverse() * tip
		for path in REAR_LEGS:
			var leg := parts.get_node(path) as Node2D
			var foot := leg.get_node("Foot") as Node2D
			var hoof := foot.get_node("Sprite") as Node2D
			var hoof_art := hoof.get_node("Base") as Sprite2D
			var toward := tip_in_parts - leg.position
			var turn := wrapf(toward.angle() - PI * 0.5, -TAU, 0.0)
			var rest := foot.position.y
			var pose := {"path": path, "rotation": 0.0, "stretch": 1.0, "foot": rest}
			if host.mode == &"windup":
				var fold := clampf(elapsed / warn, 0.0, 1.0)
				pose.rotation = lerpf(0.0, turn, fold)
				pose.foot = lerpf(rest, KICK_FOLD, fold)
			else:
				var extend := clampf((elapsed - warn) / maxf(0.001, float(rule.active) * KICK_EXTEND), 0.0, 1.0)
				var natural := rest + hoof.position.y + hoof_art.texture.get_height()
				pose.rotation = turn
				pose.foot = lerpf(KICK_FOLD, rest, extend)
				pose.stretch = lerpf(1.0, maxf(1.0, toward.length() / natural), extend)
			poses.append(pose)
			end_legs.append(pose)
		return {"neck": 0.0, "legs": poses}

	func kind() -> StringName:
		return &"kick"

	func horn_points(host: MonocerosBoss, sweep_fraction := -1.0) -> PackedVector2Array:
		var at := host.table.pos[host.body]
		var angle := host.table.facing[host.body]
		var reach := host.horn_length()
		angle = host.direction.angle()
		reach = float(host.rule().reach)
		var direction := Vector2.from_angle(angle)
		return PackedVector2Array([at + direction * host.table.r[host.body] * 0.65, at + direction * reach])
