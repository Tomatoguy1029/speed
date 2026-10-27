## 構えた尾そのものが後方の弧を掃く。頭から伸びる無関係な棒に判定を置かない。
extends RefCounted
const FORM = preload("res://scripts/bosses/draco_form.gd")
const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
var origin := Vector2.ZERO
var facing := 0.0
var base := PackedVector2Array()
var last := PackedVector2Array()
var prior := PackedVector2Array()
func _pose(a: BossActor, offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var reach := float(a.rule().reach)
	for j in 33:
		var t := float(j)/32.0
		var angle := facing+PI+offset*t*t
		points.append(origin+Vector2.from_angle(angle)*reach*t)
	return MOTION.fit_spine(points,base,true)
func begin(a: BossActor) -> void:
	origin=a.table.pos[a.body]
	facing=a.table.facing[a.body]
	base=a.neutral_body_points(origin,facing)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for j in 33:
		var angle := facing+PI+lerpf(-1.3,1.3,j/32.0)
		outer.append(origin+Vector2.from_angle(angle)*float(a.rule().reach))
		inner.append(origin+Vector2.from_angle(angle)*float(a.rule().reach)*0.55)
	a.telegraph_paths.assign([outer,inner,PackedVector2Array([inner[0],outer[0]]),PackedVector2Array([inner[-1],outer[-1]])])
	a.telegraph_widths.assign([a.body_width*0.5,a.body_width*0.5,a.body_width*0.5,a.body_width*0.5])
func windup(a: BossActor,_dt: float) -> void:
	MOTION.blend(a,base,_pose(a,-1.3),a.elapsed/float(a.rule().warn))
func tick(a: BossActor,_dt: float) -> void:
	MOTION.clear_tell(a)
	var points := _pose(a,lerpf(-1.3,1.3,clampf(a.elapsed/float(a.rule().active),0.0,1.0)))
	var fractions: PackedFloat32Array=FORM.fractions(points)
	for j in range(18,points.size()-1):
		var segment := PackedVector2Array([points[j],points[j+1]])
		var old := PackedVector2Array([prior[j],prior[j+1]]) if prior.size()==points.size() else PackedVector2Array()
		a.hit_segment(segment,a.body_width*0.5*FORM.taper((fractions[j]+fractions[j+1])*0.5),old)
	a.body_override=points
	prior=points
	a.attack_points.clear()
func end(a: BossActor,cancelled: bool) -> void:
	MOTION.clear_tell(a)
	a.attack_points.clear()
	last=a.body_override.duplicate()
	if cancelled:a.reset_pose()
func recover(a: BossActor,_dt: float) -> void:
	if not last.is_empty():MOTION.blend(a,last,a.neutral_body_points(origin,facing),a.elapsed/float(a.rule().recover))
