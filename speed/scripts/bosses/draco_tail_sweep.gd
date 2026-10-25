extends RefCounted
var prior := PackedVector2Array()
func begin(a: BossActor) -> void:
	prior.clear()
func tick(a: BossActor, _dt: float) -> void:
	var f := clampf(a.elapsed / float(a.rule().active),0.0,1.0)
	var angle: float = a.direction.angle() + PI + lerpf(-1.3,1.3,f)
	var points := PackedVector2Array([a.table.pos[a.body], a.table.pos[a.body] + Vector2.from_angle(angle) * float(a.rule().reach)])
	a.hit_segment(points, float(a.rule().width), prior)
	prior = points
	a.attack_points = points
func end(a: BossActor, _cancelled: bool) -> void:
	a.attack_points.clear()
