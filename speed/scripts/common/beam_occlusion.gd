## 光源基準の円で光線を切る。表示と命中が同じ距離を使う。
extends RefCounted
static func reach(direction: Vector2, length: float, blockers: PackedVector3Array) -> float:
	var result := length
	for blocker in blockers:
		var offset := Vector2(blocker.x,blocker.y)
		var along := offset.dot(direction)
		if along < -blocker.z: continue
		var perpendicular := offset.length_squared()-along*along
		if perpendicular <= blocker.z*blocker.z:
			result = minf(result,maxf(0.0,along-sqrt(maxf(0.0,blocker.z*blocker.z-perpendicular))))
	return result
