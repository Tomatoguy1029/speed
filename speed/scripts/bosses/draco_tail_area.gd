## りゅう座の尻尾の薙ぎ払いが掃く範囲。戦闘の予告とボス行動エディターの範囲図が同じ形を使う。
extends RefCounted

## 尾の先ほど大きく振れるので、先が広く根元が細い扇になる。facing は頭の向きで、扇は後ろへ開く。
static func area(origin: Vector2, facing: float, reach: float, half: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for j in 25: points.append(origin+Vector2.from_angle(facing+PI-half*pow(j/24.0,2.0))*reach*j/24.0)
	# 境界の接点は前の列に含まれる。重複すると描画時の三角形分割が失敗する。
	for j in range(1,49): points.append(origin+Vector2.from_angle(facing+PI+lerpf(-half,half,j/48.0))*reach)
	for j in range(23,0,-1): points.append(origin+Vector2.from_angle(facing+PI+half*pow(j/24.0,2.0))*reach*j/24.0)
	return points
