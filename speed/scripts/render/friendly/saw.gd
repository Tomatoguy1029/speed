extends AttackVisual
static func unit_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 24: points.append(Vector2.from_angle(TAU*k/24.0)*(1.0 if k%2==0 else 0.78))
	return points
