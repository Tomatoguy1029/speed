## 首を引いて予告し、固定した方向へ歯先を伸ばす。戻る頭が反撃の隙になる。
extends RefCounted
const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
var origin := Vector2.ZERO
var retracted := Vector2.ZERO
var strike := Vector2.ZERO
var base := PackedVector2Array()
var landed := PackedVector2Array()
func begin(a: BossActor) -> void:
	origin=a.table.pos[a.body]
	a.aim=MOTION.predict(a,float(a.rule().warn)+float(a.rule().active)*0.55,float(a.rule().get("lead_cap",440.0)))
	a.direction=(a.aim-origin).normalized()
	if a.direction.is_zero_approx(): a.direction=Vector2.RIGHT
	a.table.facing[a.body]=a.direction.angle()
	base=a.neutral_body_points(origin,a.direction.angle())
	retracted=origin-a.direction*float(a.rule().get("retract",110.0))
	strike=origin+a.direction*float(a.rule().reach)
	MOTION.line_tell(a,origin,strike+a.direction*105.0*a.head_scale,float(a.rule().width))
func windup(a: BossActor,_dt: float) -> void:
	MOTION.neck_pose(a,base,origin.lerp(retracted,MOTION.smooth(a.elapsed/float(a.rule().warn))))
func tick(a: BossActor,_dt: float) -> void:
	MOTION.clear_tell(a)
	var before := MOTION.mouth(a)
	var progress := MOTION.smooth(a.elapsed/float(a.rule().active))
	MOTION.neck_pose(a,base,retracted.lerp(strike,progress))
	var after := MOTION.mouth(a)
	a.attack_points=PackedVector2Array([before,after])
	a.hit_segment(a.attack_points,float(a.rule().width))
func end(a: BossActor,cancelled: bool) -> void:
	MOTION.clear_tell(a)
	a.attack_points.clear()
	landed=a.body_override.duplicate()
	if cancelled:
		a.table.pos[a.body]=origin
		a.reset_pose()
func recover(a: BossActor,_dt: float) -> void:
	if landed.is_empty():return
	MOTION.blend(a,landed,a.neutral_body_points(origin,a.direction.angle()),a.elapsed/float(a.rule().recover))
