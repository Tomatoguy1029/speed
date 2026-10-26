extends "res://scripts/bosses/draco_charge.gd"
var takeoff := Vector2.ZERO
func begin(a: BossActor) -> void:
	var side: float = -1.0 if a.run_state.rng.randf()<0.5 else 1.0
	origin = a.run_state.view_center+Vector2(side*maxf(600.0,a.run_state.view_half.x+200.0),0)
	takeoff = origin
	destination = a.aim
	a.direction = (destination-origin).normalized()
	a.table.pos[a.body] = origin
	a.table.facing[a.body] = a.direction.angle()
	a.telegraph_points = PackedVector2Array([destination])
func windup(a: BossActor,_dt: float) -> void:
	origin = takeoff+a.direction*60.0*clampf(a.elapsed/(float(a.rule().warn)*0.5),0.0,1.0)
	a.table.pos[a.body] = origin
func tick(a: BossActor,_dt: float) -> void:
	var f := clampf(a.elapsed/float(a.rule().active),0.0,1.0)
	a.table.pos[a.body] = origin.lerp(destination,f)
	a._presentation.scale = Vector2.ONE*(1.0+sin(f*PI)*0.35)
	if f>0.8:
		a.hit_segment(PackedVector2Array([destination-a.direction*70.0,destination+a.direction*100.0]),float(a.rule().width))
func end(a: BossActor,cancelled: bool) -> void:
	super(a,cancelled)
	a.telegraph_points.clear()
	a._presentation.scale = Vector2.ONE
