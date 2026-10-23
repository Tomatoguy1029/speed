extends AttackVisual
func draw_friend(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	rm._draw_hull(c, pr.friend_type[i], pos, pr.friend_vel[i].angle(), pr.friend_r[i], Color("#ffbe65"))
