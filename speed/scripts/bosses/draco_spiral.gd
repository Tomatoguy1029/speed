## 胴幅と頭の大きさは通常姿勢と共有し、巻き・収縮・下方離脱を点列でつなぐ。
extends RefCounted
const FORM = preload("res://scripts/bosses/draco_form.gd")
const STAGING = preload("res://scripts/bosses/draco_screen_staging.gd")
var staging: Dictionary
var center := Vector2.ZERO
var extent := 1000.0
var points := PackedVector2Array()
var walls: Array[int] = []
var trapped := false
var trapped_hit := false
var entry := PackedVector2Array()
var recovery_pose := PackedVector2Array()
func begin(a: BossActor) -> void:
	center = a.aim_target()
	var short_half := minf(a.run_state.view_half.x, a.run_state.view_half.y)
	extent = maxf(a.body_width * 2.1, short_half * float(a.rule().radius_factor))
	entry = _resample(a.body_points(), 65)
	a.picaro.pause(true)
	var gap: float = a.body_width + a.ctx.cfg.ship_radius * 2.0 + 12.0
	var inner := maxf(a.body_width * 0.7, extent - gap * float(a.rule().coil_turns))
	a.telegraph_points.clear()
	staging = STAGING.capture(a, center + Vector2(0, -a.run_state.view_half.y - a.body_width * 2.0), center + Vector2(0, -inner), PI * 0.5)
func windup(a: BossActor, _dt: float) -> void:
	STAGING.advance(a, staging, clampf(a.elapsed / float(a.rule().warn), 0.0, 1.0))
	entry = _resample(a.body_points(), 65)
func tick(a: BossActor, _dt: float) -> void:
	var p: Dictionary = a.rule()
	var wrap := float(p.first_lap) + float(p.second_lap)
	var shrink_at := wrap + float(p.pause)
	a.telegraph_paths.clear()
	a.telegraph_widths.clear()
	if a.elapsed >= wrap and a.elapsed < shrink_at:
		a.telegraph_paths.append(PackedVector2Array([a.table.pos[a.body], a.table.pos[a.body] + Vector2.DOWN * extent * 2.0]))
		a.telegraph_widths.append(a.body_width * 0.5)
	var turns: float = a.elapsed / float(p.first_lap) if a.elapsed < float(p.first_lap) else 1.0 + (a.elapsed - float(p.first_lap)) / float(p.second_lap)
	turns = minf(2.0, turns)
	var shrink := clampf((a.elapsed - shrink_at) / float(p.shrink_time), 0.0, 1.0)
	var head_angle := -PI * 0.5 - turns * TAU
	var coil_turns := float(p.coil_turns)
	var pitch: float = a.body_width + a.ctx.cfg.ship_radius * 2.0 + 12.0
	var outer_radius := extent * lerpf(1.15, 1.0, turns * 0.5)
	var base_radius := maxf(a.body_width * 0.7, outer_radius - pitch * coil_turns)
	var radius_scale := 1.0 - shrink * 0.7
	var exit_offset: Vector2 = Vector2.DOWN * pow(shrink, 2.0) * (extent * 2.0 + a.body_length)
	# 巻径を縮めても竜の長さは縮めない。余った尾は続く螺旋へ巻き込む。
	var coil := PackedVector2Array()
	var angle := 0.0
	var travelled := 0.0
	while travelled < a.body_length and coil.size() < 1024:
		var radius := (base_radius + pitch * angle / TAU) * radius_scale
		var point: Vector2 = center + Vector2.from_angle(head_angle + angle) * radius + exit_offset
		if not coil.is_empty(): travelled += coil[-1].distance_to(point)
		coil.append(point)
		angle += 0.04
	points = _fit_length(coil, a.body_length, 65)
	for j in points.size(): points[j] = entry[j].lerp(points[j], smoothstep(0.0, 0.45, a.elapsed))
	if shrink > 0.65:
		var straight: PackedVector2Array = _resample(a.neutral_body_points(points[0], PI * 0.5), 65)
		for j in points.size(): points[j] = points[j].lerp(straight[j], smoothstep(0.65, 1.0, shrink))
	points = _fit_length(points, a.body_length, 65)
	var fractions: PackedFloat32Array = FORM.fractions(points)
	if a.elapsed >= shrink_at:
		# 収縮中は共通hazardの反復ヒットを止め、接触を一度だけ受付する。
		for h in walls:
			if a.ctx.projectiles.owns_hazard(h, a.body, a.body_id): a.ctx.projectiles.hazard_dmg[h] = 0.0
		var touching := false
		for j in range(points.size() - 1):
			if Geometry2D.get_closest_point_to_segment(a.run_state.ship_pos, points[j], points[j + 1]).distance_to(a.run_state.ship_pos) <= a.body_width * 0.5 * FORM.taper((fractions[j] + fractions[j + 1]) * 0.5) + a.ctx.cfg.ship_radius:
				touching = true
				break
		if not trapped_hit and touching:
			trapped = true
			trapped_hit = true
			a.ctx.ship.damage(float(p.damage) * a.ctx.cfg.atk_scale, 0.0, &"spiral", &"draco")
			a.run_state.ship_invuln = maxf(a.run_state.ship_invuln, float(p.shrink_time) * (1.0 - shrink) + 1.0)
	a.table.facing[a.body] = (points[0] - points[1]).angle() if shrink < 0.65 else PI * 0.5
	a.table.pos[a.body] = points[0]
	a.body_override = points
	while walls.size() < points.size() - 1:
		var damage: float = 0.0 if a.elapsed >= shrink_at else float(p.damage) * a.ctx.cfg.atk_scale
		var h := a.ctx.projectiles.fire_wall(center, 0.0, 1.0, a.body_width, 0.0, float(p.active) + 2.0, damage, Color("#7560d9"))
		a.ctx.projectiles.hazard_style[h] = ProjectileSystem.HazardStyle.TRAIL
		a.ctx.projectiles.hazard_block[h] = 1
		a.ctx.projectiles.attach_hazard(h, a.body)
		walls.append(h)
	for j in walls.size():
		var delta := points[j + 1] - points[j]
		a.ctx.projectiles.move_hazard(walls[j], points[j], delta.angle(), delta.length())
		a.ctx.projectiles.hazard_width[walls[j]] = a.body_width * FORM.taper((fractions[j] + fractions[j + 1]) * 0.5)
	if a.elapsed >= shrink_at: a.telegraph_points.clear()
func end(a: BossActor, _cancelled: bool) -> void:
	for h in walls:
		if a.ctx.projectiles.owns_hazard(h, a.body, a.body_id): a.ctx.projectiles.release_hazard(h)
	recovery_pose = points.duplicate()
	a.telegraph_points.clear()
	a.telegraph_paths.clear()
	a.telegraph_widths.clear()
func recover(a: BossActor, _dt: float) -> void:
	if recovery_pose.is_empty(): return
	var neutral: PackedVector2Array = _resample(a.neutral_body_points(a.table.pos[a.body], a.table.facing[a.body]), recovery_pose.size())
	var blend := smoothstep(0.0, float(a.rule().recover), a.elapsed)
	var pose := PackedVector2Array()
	for j in recovery_pose.size(): pose.append(recovery_pose[j].lerp(neutral[j], blend))
	a.body_override = _fit_length(pose, a.body_length, pose.size())
func _resample(source: PackedVector2Array, count: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for j in count:
		var index := float(j) / float(count - 1) * float(source.size() - 1)
		var start := mini(source.size() - 2, int(index))
		result.append(source[start].lerp(source[start + 1], index - float(start)))
	return result

func _fit_length(source: PackedVector2Array, length: float, count: int) -> PackedVector2Array:
	var trimmed := PackedVector2Array([source[0]])
	var remaining := length
	for j in range(1, source.size()):
		var segment := source[j].distance_to(source[j - 1])
		if segment > remaining:
			trimmed.append(source[j - 1].lerp(source[j], remaining / segment))
			remaining = 0.0
			break
		trimmed.append(source[j])
		remaining -= segment
	if remaining > 0.01:
		var tangent := (source[-1] - source[-2]).normalized()
		if tangent.is_zero_approx(): tangent = Vector2.LEFT
		trimmed.append(trimmed[-1] + tangent * remaining)
	var result := PackedVector2Array()
	for j in count: result.append(FORM.sample(trimmed, float(j) / float(count - 1)))
	return result
