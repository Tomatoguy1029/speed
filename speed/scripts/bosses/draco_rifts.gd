## 左右二回の引っ掻きと、回復中も残る無害な裂け目。
extends RefCounted
const STAGING = preload("res://scripts/bosses/draco_screen_staging.gd")
var staging: Dictionary
var walls: Array[int] = []
var slashes: Array[int] = []
var sides := 0
var center := Vector2.ZERO
var ended := false
var paths: Array[PackedVector2Array] = []
func begin(a: BossActor) -> void:
	center = a.aim_target()
	staging = STAGING.side_entry(a, center)
	for side in [-1, 1]:
		for j in 3:
			var from := center + Vector2(side * 620.0, (j - 1) * 140.0)
			var to := center + Vector2(side * 130.0, (j - 1) * 140.0 + side * 75.0)
			paths.append(PackedVector2Array([from, to]))
			a.telegraph_paths.append(paths[-1])
			a.telegraph_widths.append(float(a.rule().get("scratch_width", 30.0)) * 0.5)
func windup(a: BossActor, _dt: float) -> void:
	STAGING.advance(a, staging, clampf(a.elapsed / float(a.rule().warn), 0.0, 1.0))
func tick(a: BossActor, _dt: float) -> void:
	var p: Dictionary = a.rule()
	var scratch_time := float(p.get("scratch_time", 0.32))
	var interval := float(p.interval)
	while sides < 2 and a.elapsed >= sides * interval:
		for j in 3:
			var points: PackedVector2Array = paths[sides * 3 + j]
			var delta := points[1] - points[0]
			var slash := a.ctx.projectiles.fire_wall(points[0], delta.angle(), 1.0, float(p.get("scratch_width", 30.0)), 0.0, scratch_time, float(p.damage) * a.ctx.cfg.atk_scale, Color("#e4cfff"))
			slashes.append(slash)
			a.ctx.projectiles.attach_hazard(slash, a.body)
			var h := a.ctx.projectiles.fire_wall(points[0], delta.angle(), 1.0, float(p.width), 0.0, float(p.active) + float(p.recover) + 1.0, 0.0, Color("#34224d"))
			a.ctx.projectiles.hazard_block[h] = 1
			a.ctx.projectiles.attach_hazard(h, a.body)
			walls.append(h)
			a.ctx.projectiles.hazard_style[h] = ProjectileSystem.HazardStyle.TRAIL
		sides += 1
	a.telegraph_paths.clear()
	a.telegraph_widths.clear()
	for index in paths.size():
		var side_index := index / 3
		var local_time: float = a.elapsed - side_index * interval
		if local_time < 0.0:
			a.telegraph_paths.append(paths[index])
			a.telegraph_widths.append(float(p.get("scratch_width", 30.0)) * 0.5)
			continue
		var path: PackedVector2Array = paths[index]
		var tip: Vector2 = path[0].lerp(path[1], clampf(local_time / scratch_time, 0.0, 1.0))
		var delta := tip - path[0]
		if index < slashes.size() and a.ctx.projectiles.owns_hazard(slashes[index], a.body, a.body_id):
			a.ctx.projectiles.move_hazard(slashes[index], path[0], delta.angle(), maxf(1.0, delta.length()))
		if index < walls.size() and a.ctx.projectiles.owns_hazard(walls[index], a.body, a.body_id):
			a.ctx.projectiles.move_hazard(walls[index], path[0], delta.angle(), maxf(1.0, delta.length()))
			var nearest := Geometry2D.get_closest_point_to_segment(a.run_state.ship_pos, path[0], tip)
			var away: Vector2 = a.run_state.ship_pos - nearest
			var margin := a.ctx.cfg.ship_radius + float(p.width) * 0.5 + 1.0
			if away.length() < margin:
				a.run_state.ship_pos = nearest + (away.normalized() if away.length() > 0.01 else delta.normalized().orthogonal()) * margin
func end(a: BossActor, cancelled: bool) -> void:
	if ended:
		if cancelled:
			for wall: Dictionary in a.closing_walls:
				if int(wall.h) in walls: wall.delay = 0.0
		return
	ended = true
	for h in slashes:
		if a.ctx.projectiles.owns_hazard(h, a.body, a.body_id): a.ctx.projectiles.release_hazard(h)
	for h in walls: a.close_wall(h, 0.3, 0.0 if cancelled else float(a.rule().recover))
	a.telegraph_paths.clear()
	a.telegraph_widths.clear()
