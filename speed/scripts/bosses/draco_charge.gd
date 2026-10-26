extends RefCounted
var origin := Vector2.ZERO
var destination := Vector2.ZERO
func begin(a: BossActor) -> void:
	var angle: float = a.run_state.rng.randf()*TAU
	var distance := maxf(700.0,a.run_state.view_half.length()*1.2)
	origin = a.run_state.view_center+Vector2.from_angle(angle)*distance
	a.direction = (a.aim-origin).normalized()
	destination = a.aim+a.direction*distance
	a.table.pos[a.body] = origin
	a.table.facing[a.body] = a.direction.angle()
	a.attack_points = PackedVector2Array([origin,destination])
func tick(a: BossActor, _dt: float) -> void:
	var before: Vector2 = a.table.pos[a.body]
	var f := clampf(a.elapsed/float(a.rule().active),0.0,1.0)
	a.table.pos[a.body] = origin.lerp(destination,f)
	a.hit_segment(PackedVector2Array([before+a.direction*110.0,a.table.pos[a.body]+a.direction*110.0]),float(a.rule().width))
	a.attack_points = PackedVector2Array([a.table.pos[a.body],a.table.pos[a.body]+a.direction*200.0])
func end(a: BossActor, _cancelled: bool) -> void:
	a.attack_points.clear()
