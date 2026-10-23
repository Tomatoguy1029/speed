extends AttackVisual
func draw_friend(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	var r := pr.friend_r[i]
	var trail := pr.friend_trail[i]
	if trail.size() > 1:
		c.draw_polyline(trail, Color(1.0, 0.6, 0.25, 0.7), _px(3.0))
	var u := Vector2.from_angle(pr.friend_angle[i]) * r
	var v := Vector2(-u.y, u.x) * 0.6
	c.draw_colored_polygon(PackedVector2Array([pos + u, pos + v, pos - u * 0.7, pos - v]), Color("#aeb6c4"))
	c.draw_polyline(PackedVector2Array([pos + u, pos + v, pos - u * 0.7, pos - v, pos + u]), Color("#ff9a3c"), _px(1.5))
