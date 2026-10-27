## 攻撃姿勢は共通寸法の点列を曲げる。表示用倍率を変えず、判定も同じ点列に従う。
extends RefCounted
static func smooth(value: float) -> float:
	var f := clampf(value,0.0,1.0)
	return f*f*(3.0-2.0*f)
static func mouth(a: BossActor) -> Vector2:
	return a.mouth_pos()
static func neck_pose(a: BossActor, base: PackedVector2Array, head: Vector2) -> void:
	var offset := head-base[0]
	var points := PackedVector2Array()
	for j in base.size():
		var t := float(j)/maxf(1.0,float(base.size()-1))
		points.append(base[j]+offset*(1.0-smooth(t/0.4)))
	a.table.pos[a.body]=head
	a.body_override=fit_spine(points,base)
static func blend(a: BossActor, from: PackedVector2Array, to: PackedVector2Array, progress: float) -> void:
	var points := PackedVector2Array()
	for j in from.size():
		var k := roundi(float(j)*float(to.size()-1)/maxf(1.0,float(from.size()-1)))
		points.append(from[j].lerp(to[k],smooth(progress)))
	a.body_override=fit_spine(points,to)
	a.table.pos[a.body]=points[0]
static func line_tell(a: BossActor, from: Vector2, to: Vector2, half_width: float) -> void:
	a.telegraph_paths.clear()
	a.telegraph_paths.append(PackedVector2Array([from,to]))
	a.telegraph_widths.clear()
	a.telegraph_widths.append(half_width)
static func clear_tell(a: BossActor) -> void:
	a.telegraph_paths.clear()
	a.telegraph_widths.clear()
	a.telegraph_points.clear()

## 各節の長さを保ったまま曲げる。尾を着地点へ置く技だけ両端を固定する。
static func fit_spine(desired: PackedVector2Array, reference: PackedVector2Array, anchor_tip := false) -> PackedVector2Array:
	if desired.size()<2 or reference.size()!=desired.size():return desired
	var lengths := PackedFloat32Array()
	var total := 0.0
	for j in range(reference.size()-1):
		var length := reference[j].distance_to(reference[j+1])
		lengths.append(length);total+=length
	var points := desired.duplicate()
	var head := desired[0]
	var tip := desired[-1]
	var both := anchor_tip and head.distance_to(tip)<total-1.0
	for iteration in (24 if both else 1):
		if both:
			points[-1]=tip
			for j in range(points.size()-2,-1,-1):
				var delta := points[j]-points[j+1]
				if delta.is_zero_approx():delta=Vector2.LEFT
				points[j]=points[j+1]+delta.normalized()*lengths[j]
		points[0]=head
		for j in range(1,points.size()):
			var delta := points[j]-points[j-1]
			if delta.is_zero_approx():delta=Vector2.LEFT
			points[j]=points[j-1]+delta.normalized()*lengths[j-1]
	return points

static func predict(a: BossActor, seconds: float, cap: float) -> Vector2:
	if a.run_state.tracing:
		return a.run_state.enemy_aim
	var travel: Vector2=a.run_state.ship_vel*maxf(0.0,seconds)
	return a.run_state.ship_pos+travel.limit_length(cap)
