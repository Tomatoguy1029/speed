extends AttackVisual
func draw_shot(c: CanvasItem, _pr: ProjectileSystem, _i: int, pos: Vector2) -> bool:
	var points := PackedVector2Array()
	for j in 8:
		points.append(pos + Vector2.from_angle(j * TAU / 8.0) * (12.0 if j % 2 == 0 else 4.0))
	c.draw_colored_polygon(points,Color("#a5baff"))
	c.draw_rect(Rect2(pos-Vector2(2,2),Vector2(4,4)),Color.WHITE)
	return true
