extends AttackVisual
func draw_friend(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> void:
	var r := pr.friend_r[i]
	var key := String(pr.friend_visual[i])
	if pr.friend_cause[i] == &"interceptor":
		load("res://scripts/render/interceptor_visual.gd").shot(c, pos, pr.friend_vel[i].angle(),
			_px(EFFECT_SETTINGS.number("weapon/interceptor", "shot_pixel_scale", 1.0)),
			EFFECT_SETTINGS.tinted("weapon/interceptor", Color.WHITE))
	else:
		var dir := pr.friend_vel[i].normalized()
		var length_scale := EFFECT_SETTINGS.number(key, "shot_length_scale", 1.0)
		var width_scale := EFFECT_SETTINGS.number(key, "shot_width_scale", 1.0)
		c.draw_line(pos - dir * r * 2.2 * length_scale, pos + dir * r * 1.2 * length_scale,
			EFFECT_SETTINGS.tinted(key, Color("#9fe8ff")), maxf(_px(3.0), r * 0.9) * width_scale)
