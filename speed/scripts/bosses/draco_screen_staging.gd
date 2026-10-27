## 画面基準技の退場と再入場。頭位置と向きを連続にし、描画だけの倍率を使わない。
extends RefCounted
static func side_entry(a: BossActor, target: Vector2) -> Dictionary:
	var side := -1.0 if a.run_state.rng.randf() < 0.5 else 1.0
	var outside: Vector2 = a.run_state.view_center + Vector2(side * (a.run_state.view_half.x + a.table.r[a.body] + 100.0), 0)
	var inside: Vector2 = a.run_state.view_center + Vector2(side * minf(700.0, a.run_state.view_half.x * 0.72), 0)
	return capture(a, outside, inside, (target - inside).angle())
static func capture(a: BossActor, outside: Vector2, inside: Vector2, facing: float) -> Dictionary:
	return {"from":a.table.pos[a.body], "outside":outside, "inside":inside, "angle":a.table.facing[a.body], "facing":facing}
static func advance(a: BossActor, staging: Dictionary, progress: float) -> void:
	var point: Vector2
	if progress < 0.4:
		point = staging.from.lerp(staging.outside, smoothstep(0.0, 0.4, progress))
	else:
		point = staging.outside.lerp(staging.inside, smoothstep(0.4, 1.0, progress))
	a.table.pos[a.body] = point
	a.table.facing[a.body] = lerp_angle(float(staging.angle), float(staging.facing), smoothstep(0.0, 0.65, progress))
