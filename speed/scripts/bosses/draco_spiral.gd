## 発動時の画面と自機位置を固定した螺旋。表示と壁は同じ点列を使う。
extends RefCounted
var center := Vector2.ZERO
var extent := 1000.0
var points := PackedVector2Array()
var walls: Array[int] = []
var trapped := false
var trapped_hit := false
var original_radius := 0.0
var original_width := 92.0
func begin(a: BossActor) -> void:
	center=a.aim
	var short_half := minf(a.run_state.view_half.x,a.run_state.view_half.y)
	extent=short_half*float(a.rule().radius_factor)
	original_radius=a.table.r[a.body]
	original_width=a.body_width
	a.body_width=short_half*2.0*float(a.rule().body_ratio)
	a.head_scale=float(a.rule().head_scale)
	a.table.r[a.body]=original_radius*a.head_scale
	a.picaro.pause(true)
func tick(a: BossActor, _dt: float) -> void:
	var p: Dictionary = a.rule()
	var wrap := float(p.first_lap)+float(p.second_lap)
	var shrink_at := wrap+float(p.pause)
	var turns: float = a.elapsed/float(p.first_lap) if a.elapsed<float(p.first_lap) else 1.0+(a.elapsed-float(p.first_lap))/float(p.second_lap)
	turns=minf(2.0,turns)
	var shrink := clampf((a.elapsed-shrink_at)/float(p.shrink_time),0.0,1.0)
	var head_angle := -PI*0.5-turns*TAU
	var body_width: float=a.body_width
	var coil_turns := float(p.coil_turns)
	var pitch := body_width+a.ctx.cfg.ship_radius*2.0+12.0
	var outer_radius := extent*lerpf(1.15,1.0,turns*0.5)
	var base_radius := maxf(body_width*0.7,outer_radius-pitch*coil_turns)
	var radius_scale := 1.0-shrink*0.7
	points.clear()
	for j in 65:
		var t := float(j)/64.0
		var radius := (base_radius+pitch*coil_turns*t)*radius_scale
		points.append(center+Vector2.from_angle(head_angle+t*TAU*coil_turns)*radius)
	if a.elapsed>=shrink_at:
		if not trapped_hit and a.run_state.ship_pos.distance_to(center)<base_radius*radius_scale+body_width:
			trapped=true;trapped_hit=true
			a.ctx.ship.damage(float(p.damage)*a.ctx.cfg.atk_scale,0.0,&"spiral",&"draco")
			a.run_state.ship_invuln=maxf(a.run_state.ship_invuln,float(p.shrink_time)+1.0)
		points[0]+=Vector2.DOWN*shrink*extent*2.5
	a.table.facing[a.body]=(center-points[0]).angle() if a.elapsed<shrink_at else PI*0.5
	a.table.pos[a.body]=points[0]
	a.body_override=points
	while walls.size()<points.size()-1:
		var h := a.ctx.projectiles.fire_wall(center,0.0,1.0,body_width,0.0,float(p.active)+2.0,float(p.damage)*a.ctx.cfg.atk_scale,Color("#7560d9"))
		a.ctx.projectiles.hazard_style[h]=ProjectileSystem.HazardStyle.TRAIL
		a.ctx.projectiles.hazard_block[h]=1
		a.ctx.projectiles.attach_hazard(h,a.body)
		walls.append(h)
	for j in walls.size():
		var delta := points[j+1]-points[j]
		a.ctx.projectiles.move_hazard(walls[j],points[j],delta.angle(),delta.length())
		if trapped_hit: a.ctx.projectiles.hazard_dmg[walls[j]]=0.0
func end(a: BossActor, _cancelled: bool) -> void:
	for h in walls:
		if a.ctx.projectiles.owns_hazard(h,a.body,a.body_id): a.ctx.projectiles.release_hazard(h)
	a.body_override.clear()
	a.body_width=original_width
	a.head_scale=1.0
	a.table.r[a.body]=original_radius
	a.table.pos[a.body]=center+Vector2(600,-100)
