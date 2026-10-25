extends RefCounted
var stars := 0
var spent := false
var caught := false
var release_at := 0.0
var beam := -1
func begin(a: BossActor) -> void:
	a.picaro.pause(true)
func tick(a: BossActor, dt: float) -> void:
	var mouth: Vector2 = a.table.pos[a.body]+a.direction*100.0
	var inhale_time := float(a.rule().inhale_time)
	if a.elapsed<inhale_time:
		var toward: Vector2 = mouth-a.run_state.ship_pos
		if toward.length()<float(a.rule().pull_range) and not caught:
			a.run_state.ship_pos += toward.normalized()*float(a.rule().pull_speed)*dt
			if toward.length()<float(a.rule().mouth_radius):
				caught=true
				a.ctx.ship.damage(float(a.rule().bite_damage)*a.ctx.cfg.atk_scale,0.0,&"bite",&"draco")
				a.run_state.ship_pos=mouth+a.direction*140.0
				a.run_state.ship_vel=a.direction*1000.0
				a.run_state.ship_invuln=maxf(a.run_state.ship_invuln,1.2)
				a.run_state.steering_locked=true
				release_at=a.clock+0.8
		for member: Dictionary in a.picaro.alive():
			var delta: Vector2 = mouth-a.table.pos[member.row]
			a.table.pos[member.row]+=delta.normalized()*minf(delta.length(),float(a.rule().picaro_pull_speed)*dt)
			if delta.length()<80.0:
				stars+=int(member.stars)
				a.ctx.enemies.mark_dead(member.row)
		if caught and a.clock>=release_at: a.run_state.steering_locked=false
		return
	if a.run_state.steering_locked:
		if a.clock<release_at: return
		a.run_state.steering_locked=false
	if spent: return
	spent=true
	beam=a.ctx.projectiles.fire_beam(mouth,a.direction.angle(),float(a.rule().reach),float(a.rule().width),0.35,float(a.rule().beam_time),float(a.rule().damage)*a.ctx.cfg.atk_scale,Color("#d4bbff"))
	a.ctx.projectiles.attach_hazard(beam,a.body)
	if stars>0:
		var remaining := mini(int(a.rule().comet_cap),stars*int(a.rule().comets_per_star))
		var arcs: Array = a.rule().arcs
		for index in arcs.size():
			var arc: DracoExhaleArc = arcs[index]
			var quota := mini(arc.count,ceili(float(remaining)/float(arcs.size()-index)))
			for j in quota:
				var angle: float = a.direction.angle()+deg_to_rad(arc.angle_degrees+lerpf(-arc.spread_degrees,arc.spread_degrees,float(j)/maxf(1.0,float(quota)-1.0)))
				var origin: Vector2 = mouth+arc.offset.rotated(a.direction.angle())+Vector2.from_angle(angle)*arc.radius
				a.ctx.projectiles.fire_bolt(origin,angle,float(a.rule().comet_speed),float(a.rule().damage)*0.6*a.ctx.cfg.atk_scale)
			remaining-=quota
	stars=0
func end(a: BossActor, _cancelled: bool) -> void:
	if a.ctx.projectiles.owns_hazard(beam,a.body,a.body_id): a.ctx.projectiles.release_hazard(beam)
	a.run_state.steering_locked=false
	stars=0
