## 構えた尾そのものが後方の扇を掃く。頭から伸びる無関係な棒に判定を置かない。
extends RefCounted
const FORM = preload("res://scripts/bosses/draco_form.gd")
const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
const AREA = preload("res://scripts/bosses/draco_tail_area.gd")
var origin := Vector2.ZERO
var facing := 0.0
var base := PackedVector2Array()
var last := PackedVector2Array()
var prior := PackedVector2Array()
func _half(a: BossActor) -> float:
	return float(a.rule().get("half_angle",1.3))

func _pose(a: BossActor, offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var reach := float(a.rule().reach)
	for j in a.body_segments + 1:
		var t := float(j) / float(a.body_segments)
		var angle := facing+PI+offset*t*t
		points.append(origin+Vector2.from_angle(angle)*reach*t)
	return MOTION.fit_spine(points,base,true)
func begin(a: BossActor) -> void:
	origin=a.table.pos[a.body]
	facing=a.table.facing[a.body]
	base=a.neutral_body_points(origin,facing)
	a.telegraph_areas.assign([{"center": origin, "polygon": AREA.area(origin,facing,float(a.rule().reach),_half(a))}])
func windup(a: BossActor,_dt: float) -> void:
	MOTION.blend(a,base,_pose(a,-_half(a)),a.elapsed/float(a.rule().warn))
func tick(a: BossActor,_dt: float) -> void:
	MOTION.clear_tell(a)
	var points := _pose(a,lerpf(-_half(a),_half(a),clampf(a.elapsed/float(a.rule().active),0.0,1.0)))
	var fractions: PackedFloat32Array=FORM.fractions(points)
	# 予告の扇と同じく、尾の根元から先まで当たる。
	for j in range(1,points.size()-1):
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
