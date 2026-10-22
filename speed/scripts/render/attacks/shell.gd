## SHELLの弾の表示。
extends AttackVisual

func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	# ポンプ座の圧縮弾：後ろに尾を引く
	var u := pr.hostile_vel[i].normalized()
	var n := Vector2(-u.y, u.x) * pr.hostile_r[i] * 0.8
	c.draw_polygon(PackedVector2Array([pos + n, pos - u * pr.hostile_r[i] * 2.2, pos - n]),
		PackedColorArray([Color(0.85, 0.7, 1.0, 0.45), Color(0.85, 0.7, 1.0, 0.0), Color(0.85, 0.7, 1.0, 0.45)]))
	draw_ball(c, pos, pr.hostile_r[i], Color("#b78cff"), state.world_time)
	return true

func draw_ball(c: CanvasItem, at: Vector2, r: float, base: Color, now: float) -> void:
	var pulse := 0.5 + 0.5 * sin(now * 14.0)
	c.draw_circle(at, r * (1.25 + 0.08 * pulse), Color(base.lightened(0.5), 0.22))
	c.draw_circle(at, r, base.darkened(0.45))
	var kinds: Array[StringName] = [&"drifter", &"swarm", &"drifter", &"splitling", &"swarm", &"drifter", &"swarm"]
	for k in kinds.size():
		var ring := 0.0 if k == 0 else 0.55
		var a := now * (1.5 if k % 2 == 0 else -1.1) + k * TAU / 6.0
		var q := at + Vector2.from_angle(a) * r * ring
		var tex := rm._enemy_texture(kinds[k])
		var size := r * (0.62 if k == 0 else 0.5)
		if tex == null:
			c.draw_circle(q, size * 0.5, base)
			continue
		var ext := tex.get_size() / maxf(tex.get_width(), tex.get_height()) * size
		c.draw_set_transform(q, a * 2.0)
		c.draw_texture_rect(tex, Rect2(-ext / 2.0, ext), false, Color(1, 1, 1, 0.9))
		c.draw_set_transform(Vector2.ZERO)
	c.draw_circle(at, r, Color(base.lightened(0.3), 0.18))
	c.draw_arc(at, r, 0, TAU, 40, Color("#fff0c8", 0.75 + 0.25 * pulse), maxf(_px(1.5), r * 0.1))
