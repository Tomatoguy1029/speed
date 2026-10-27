## 吸引→噛み付き反発→方向を示した吐き出し。ロック後の光線は追尾しない。
extends RefCounted
const STAGING = preload("res://scripts/bosses/draco_screen_staging.gd")
var staging: Dictionary
var stars := 0
var spent := false
var caught := false
var release_at := 0.0
var beam := -1
var beam_direction := Vector2.RIGHT
func begin(a: BossActor) -> void:
	a.picaro.pause(true)
	beam_direction = (a.aim_target() - a.table.pos[a.body]).normalized()
	if beam_direction.is_zero_approx(): beam_direction = Vector2.from_angle(a.table.facing[a.body])
	a.direction = beam_direction
	a.table.facing[a.body] = beam_direction.angle()
	staging = STAGING.side_entry(a, a.aim_target())
func windup(a: BossActor, _dt: float) -> void:
	STAGING.advance(a, staging, clampf(a.elapsed / float(a.rule().warn), 0.0, 1.0))
	a.direction = Vector2.from_angle(a.table.facing[a.body])
func tick(a: BossActor, dt: float) -> void:
	var mouth: Vector2 = a.mouth_pos()
	var inhale_time := float(a.rule().inhale_time)
	if a.elapsed < inhale_time:
		if not caught: a.combat_trace.evaluate()
		var toward: Vector2 = mouth - a.run_state.ship_pos
		if toward.length() < float(a.rule().pull_range) and not caught:
			a.run_state.ship_pos += toward.normalized() * minf(toward.length(), float(a.rule().pull_speed) * dt)
			if toward.length() < float(a.rule().mouth_radius) + a.ctx.cfg.ship_radius:
				caught = true
				a.combat_trace.damage(float(a.rule().bite_damage) * a.ctx.cfg.atk_scale, 0.0, &"bite", &"draco")
				a.run_state.ship_pos = mouth + a.direction * (a.head_scale * 100.0)
				a.run_state.ship_vel = a.direction * 1000.0
				a.run_state.ship_invuln = maxf(a.run_state.ship_invuln, 1.2)
				a.run_state.steering_locked = true
				release_at = a.clock + 0.8
		for member: Dictionary in a.picaro.alive():
			var delta: Vector2 = mouth - a.table.pos[member.row]
			a.table.pos[member.row] += delta.normalized() * minf(delta.length(), float(a.rule().picaro_pull_speed) * dt)
			if delta.length() < a.head_scale * 80.0:
				stars += int(member.stars)
				a.ctx.enemies.mark_dead(member.row)
		if caught and a.clock >= release_at: a.run_state.steering_locked = false
		return
	if a.run_state.steering_locked:
		if a.clock < release_at:
			a.elapsed = inhale_time
			return
		a.run_state.steering_locked = false
	if spent: return
	spent = true
	# 吐き出す時点の現在位置へ向くが、警告を見せた後は一切追わない。
	beam_direction = (a.aim_target() - a.table.pos[a.body]).normalized()
	if beam_direction.is_zero_approx(): beam_direction = a.direction
	a.direction = beam_direction
	a.table.facing[a.body] = a.direction.angle()
	mouth = a.mouth_pos()
	a.combat_trace.stage("lock", {"scope": "exhale", "aim": [a.aim_target().x, a.aim_target().y]})
	beam = a.ctx.projectiles.fire_beam(mouth, a.direction.angle(), float(a.rule().reach), float(a.rule().width), float(a.rule().get("beam_warn", 0.5)), float(a.rule().beam_time), float(a.rule().damage) * a.ctx.cfg.atk_scale, Color("#d4bbff"))
	a.ctx.projectiles.attach_hazard(beam, a.body)
	if stars > 0:
		var remaining := mini(int(a.rule().comet_cap), stars * int(a.rule().comets_per_star))
		var arcs: Array = a.rule().arcs
		for index in arcs.size():
			var arc: DracoExhaleArc = arcs[index]
			var quota := mini(arc.count, ceili(float(remaining) / float(arcs.size() - index)))
			for j in quota:
				var angle: float = a.direction.angle() + deg_to_rad(arc.angle_degrees + lerpf(-arc.spread_degrees, arc.spread_degrees, float(j) / maxf(1.0, float(quota) - 1.0)))
				var origin: Vector2 = mouth + arc.offset.rotated(a.direction.angle()) + Vector2.from_angle(angle) * arc.radius
				a.ctx.projectiles.fire_bolt(origin, angle, float(a.rule().comet_speed), float(a.rule().damage) * 0.6 * a.ctx.cfg.atk_scale)
			remaining -= quota
	stars = 0
func end(a: BossActor, _cancelled: bool) -> void:
	if a.ctx.projectiles.owns_hazard(beam, a.body, a.body_id): a.ctx.projectiles.release_hazard(beam)
	a.run_state.steering_locked = false
	stars = 0
