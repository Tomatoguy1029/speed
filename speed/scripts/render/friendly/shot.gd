extends AttackVisual
func draw_friend(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	var r := pr.friend_r[i]
	if pr.friend_cause[i] == &"interceptor":
		load("res://scripts/render/interceptor_visual.gd").shot(c, pos, pr.friend_vel[i].angle(), _px(1.0))
	else:
		var dir := pr.friend_vel[i].normalized()
		c.draw_line(pos - dir * r * 2.2, pos + dir * r * 1.2, Color("#9fe8ff"), maxf(_px(3.0), r * 0.9))
