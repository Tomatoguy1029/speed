extends RefCounted
const STAR = preload("res://scripts/attacks/star_bolt.gd")
const STAR_VISUAL = preload("res://scripts/render/attacks/star_bolt.gd")
var positions := PackedVector2Array()
var angles: Array[float] = []
var fired := false
func begin(a: BossActor) -> void:
	var p: Dictionary = a.rule()
	for j in int(p.count):
		var angle: float = a.direction.angle() + lerpf(-float(p.arc),float(p.arc),float(j)/maxf(1.0,float(p.count)-1.0))
		angles.append(angle)
		positions.append(a.table.pos[a.body]+Vector2.from_angle(angle)*float(p.radius))
	a.telegraph_points = positions
func tick(a: BossActor, _dt: float) -> void:
	if fired: return
	fired = true
	for j in positions.size():
		a.ctx.projectiles.emit_attack(&"star_bolt",[positions[j],angles[j],float(a.rule().speed),float(a.rule().damage)*a.ctx.cfg.atk_scale])
	a.telegraph_points.clear()
func end(a: BossActor, _cancelled: bool) -> void:
	a.telegraph_points.clear()
