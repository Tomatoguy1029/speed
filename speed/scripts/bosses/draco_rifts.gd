extends RefCounted
var walls: Array[int] = []
var slashes: Array[int] = []
var sides := 0
var center := Vector2.ZERO
func begin(a: BossActor) -> void:
	center = a.run_state.enemy_aim
func tick(a: BossActor, _dt: float) -> void:
	var wanted := mini(2,1+int(a.elapsed/float(a.rule().interval)))
	while sides < wanted:
		var side := -1.0 if sides == 0 else 1.0
		for j in 3:
			var from := center+Vector2(side*620.0,(j-1)*140.0)
			var to := center+Vector2(side*130.0,(j-1)*140.0+side*75.0)
			var delta := to-from
			var slash := a.ctx.projectiles.fire_wall(from,delta.angle(),delta.length(),30.0,0.0,0.35,float(a.rule().damage)*a.ctx.cfg.atk_scale,Color("#e4cfff"))
			slashes.append(slash)
			a.ctx.projectiles.attach_hazard(slash,a.body)
			var h := a.ctx.projectiles.fire_wall(from,delta.angle(),delta.length(),float(a.rule().width),0.0,float(a.rule().active)+1.0,0.0,Color("#34224d"))
			a.ctx.projectiles.hazard_block[h] = 1
			a.ctx.projectiles.attach_hazard(h,a.body)
			walls.append(h)
			var nearest := Geometry2D.get_closest_point_to_segment(a.run_state.ship_pos,from,to)
			var away: Vector2 = a.run_state.ship_pos-nearest
			var margin := a.ctx.cfg.ship_radius+float(a.rule().width)*0.5+1.0
			if away.length()<margin:
				a.run_state.ship_pos = nearest+(away.normalized() if away.length()>0.01 else delta.normalized().orthogonal())*margin
		sides += 1
func end(a: BossActor, _cancelled: bool) -> void:
	for h in slashes:
		if a.ctx.projectiles.owns_hazard(h,a.body,a.body_id): a.ctx.projectiles.release_hazard(h)
	for h in walls: a.close_wall(h,0.3)
