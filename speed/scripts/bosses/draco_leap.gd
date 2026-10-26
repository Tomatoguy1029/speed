## 画面内で踏み込み、予告した口先の着地点へ飛ぶ。拡大率で遠近を代用しない。
extends RefCounted
const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var entry := Vector2.ZERO
var takeoff := Vector2.ZERO
var landed := Vector2.ZERO
var locked := false
func begin(a: BossActor) -> void:
	entry=a.table.pos[a.body]
	var side := -1.0 if entry.x<a.run_state.view_center.x else 1.0
	var half: Vector2=a.run_state.view_half
	origin=a.run_state.view_center+Vector2(side*half.x*0.62,-half.y*0.3)
	_lock(a)
	locked=false
func _lock(a: BossActor) -> void:
	a.aim=MOTION.predict(a,maxf(0.0,float(a.rule().warn)-a.elapsed)+float(a.rule().active),float(a.rule().get("lead_cap",900.0)))
	a.direction=(a.aim-origin).normalized()
	if a.direction.is_zero_approx():a.direction=Vector2.RIGHT
	a.table.facing[a.body]=a.direction.angle()
	takeoff=origin-a.direction*70.0
	destination=a.aim-a.direction*105.0*a.head_scale
	a.telegraph_points=PackedVector2Array([a.aim])
	MOTION.line_tell(a,takeoff+a.direction*105.0*a.head_scale,a.aim,float(a.rule().width))
func windup(a: BossActor,_dt: float) -> void:
	var setup_time := minf(0.2,float(a.rule().warn)*0.3)
	if not locked:
		_lock(a)
		locked=a.elapsed>=setup_time
	if a.elapsed<setup_time:
		a.table.pos[a.body]=entry.lerp(origin,MOTION.smooth(a.elapsed/setup_time))
	else:
		a.table.pos[a.body]=origin.lerp(takeoff,MOTION.smooth((a.elapsed-setup_time)/(float(a.rule().warn)-setup_time)))
func tick(a: BossActor,_dt: float) -> void:
	MOTION.clear_tell(a)
	var before := MOTION.mouth(a)
	var f := MOTION.smooth(a.elapsed/float(a.rule().active))
	a.table.pos[a.body]=takeoff.lerp(destination,f)
	a.hit_segment(PackedVector2Array([before,MOTION.mouth(a)]),float(a.rule().width))
	a.attack_points=PackedVector2Array([before,MOTION.mouth(a)])
func end(a: BossActor,_cancelled: bool) -> void:
	MOTION.clear_tell(a)
	a.attack_points.clear()
	landed=a.table.pos[a.body]
func recover(a: BossActor,_dt: float) -> void:
	a.table.pos[a.body]=landed-a.direction*60.0*MOTION.smooth(a.elapsed/float(a.rule().recover))
