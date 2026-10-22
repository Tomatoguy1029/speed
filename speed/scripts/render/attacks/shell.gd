## SHELLの弾の表示。
extends AttackVisual

func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	# ポンプ座の圧縮弾：後ろに尾を引く
	var u := pr.hostile_vel[i].normalized()
	var n := Vector2(-u.y, u.x) * pr.hostile_r[i] * 0.8
	c.draw_polygon(PackedVector2Array([pos + n, pos - u * pr.hostile_r[i] * 2.2, pos - n]),
		PackedColorArray([Color(0.85, 0.7, 1.0, 0.45), Color(0.85, 0.7, 1.0, 0.0), Color(0.85, 0.7, 1.0, 0.45)]))
	rm._draw_shell_ball(c, pos, pr.hostile_r[i], Color("#b78cff"), state.world_time)
	return true
