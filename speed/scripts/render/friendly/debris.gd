extends AttackVisual
func draw_friend(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	if pr.friend_visual[i] == &"weapon/knockback": return
	var r := pr.friend_r[i]
	var trail := pr.friend_trail[i]
	var key := String(pr.friend_visual[i])
	var tint := EFFECT_SETTINGS.tinted(key, Color.WHITE)
	if trail.size() > 1:
		c.draw_polyline(trail, Color(1.0, 0.6, 0.25, 0.7) * tint,
			_px(3.0) * EFFECT_SETTINGS.number(key, "debris_trail_width", 1.0))
	var u := Vector2.from_angle(pr.friend_angle[i]) * r
	var v := Vector2(-u.y, u.x) * 0.6
	c.draw_colored_polygon(PackedVector2Array([pos + u, pos + v, pos - u * 0.7, pos - v]), Color("#aeb6c4") * tint)
	c.draw_polyline(PackedVector2Array([pos + u, pos + v, pos - u * 0.7, pos - v, pos + u]),
		Color("#ff9a3c") * tint, _px(1.5))
