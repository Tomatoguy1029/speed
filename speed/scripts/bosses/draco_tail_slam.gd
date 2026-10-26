## 尾を持ち上げ、予告した着地点へ落とす。直撃と小さな波だけを判定にする。
extends RefCounted
const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
var target := Vector2.ZERO
var origin := Vector2.ZERO
var base := PackedVector2Array()
var lifted := PackedVector2Array()
var last := PackedVector2Array()
var fired := false
var locked := false
func _pose(a: BossActor, tip: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var backward := -Vector2.from_angle(a.table.facing[a.body])
	var side := backward.orthogonal()
	var control1 := origin+backward*float(a.def.params.get("body_length",1500.0))*0.7
	var control2 := tip+backward*220.0+side*float(a.def.params.get("body_length",1500.0))*0.35
	for j in 33:
		var t := float(j)/32.0
		points.append(origin*(1.0-t)*(1.0-t)*(1.0-t)+control1*3.0*(1.0-t)*(1.0-t)*t+control2*3.0*(1.0-t)*t*t+tip*t*t*t)
	return MOTION.fit_spine(points,base,true)
func begin(a: BossActor) -> void:
	origin=a.table.pos[a.body]
	base=a.neutral_body_points(origin,a.table.facing[a.body])
	_target(a)
func _target(a: BossActor) -> void:
	target=MOTION.predict(a,maxf(0.0,float(a.rule().warn)-a.elapsed)+float(a.rule().active)*0.65,float(a.rule().get("lead_cap",600.0)))
	var delta := target-origin
	if delta.length()>float(a.rule().reach):target=origin+delta.normalized()*float(a.rule().reach)
	lifted=_pose(a,target+Vector2.UP*180.0)
	a.telegraph_points=PackedVector2Array([target])
	# 円周そのものが着地半径。尾の移動経路は装飾で、予告外には攻撃を出さない。
	var ring := PackedVector2Array()
	for j in 49:ring.append(target+Vector2.from_angle(j*TAU/48.0)*float(a.rule().radius))
	a.telegraph_paths.assign([ring])
	a.telegraph_widths.assign([3.0])
func windup(a: BossActor,_dt: float) -> void:
	if not locked:
		_target(a)
		locked=a.elapsed>=minf(0.25,float(a.rule().warn)*0.35)
	MOTION.blend(a,base,lifted,a.elapsed/float(a.rule().warn))
func tick(a: BossActor,_dt: float) -> void:
	MOTION.clear_tell(a)
	var drop := MOTION.smooth(a.elapsed/(float(a.rule().active)*0.65))
	a.body_override=_pose(a,(target+Vector2.UP*180.0).lerp(target,drop))
	if fired or drop<1.0:return
	fired=true
	a.ctx.projectiles.fire_zone(target,float(a.rule().radius),0.0,float(a.rule().damage)*a.ctx.cfg.atk_scale)
	a.ctx.projectiles.fire_wave(target,0.0,PI,float(a.rule().radius)*1.6,330.0,18.0,0.0,float(a.rule().damage)*0.5*a.ctx.cfg.atk_scale)
	a.presentation_event.emit({"cue":&"tail_impact","pos":target,"radius":float(a.rule().radius)})
func end(a: BossActor,cancelled: bool) -> void:
	MOTION.clear_tell(a)
	a.attack_points.clear()
	last=a.body_override.duplicate()
	if cancelled:a.reset_pose()
func recover(a: BossActor,_dt: float) -> void:
	if not last.is_empty():MOTION.blend(a,last,a.neutral_body_points(origin,a.table.facing[a.body]),a.elapsed/float(a.rule().recover))
