extends AttackVisual
func draw_friend(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	var r := pr.friend_r[i]
	var pts := PackedVector2Array()
	for k in 24:
		pts.append(pos + Vector2.from_angle(pr.friend_angle[i] + TAU * k / 24.0) * r * (1.0 if k % 2 == 0 else 0.78))
	c.draw_colored_polygon(pts, Color("#d9dde6"))
