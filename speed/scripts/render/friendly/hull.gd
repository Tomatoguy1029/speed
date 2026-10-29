extends AttackVisual
func draw_friend(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	var key := String(pr.friend_visual[i])
	rm._draw_hull(c, pr.friend_type[i], pos, pr.friend_vel[i].angle(), pr.friend_r[i],
		EFFECT_SETTINGS.tinted(key, Color("#ffbe65")), EFFECT_SETTINGS.tinted(key, Color.WHITE))
