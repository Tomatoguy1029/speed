## BOLTの弾の表示。
extends AttackVisual

func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	# ケフェウス座の兵の細長い光弾
	var u := pr.hostile_vel[i].normalized()
	c.draw_line(pos - u * 34.0, pos + u * 6.0, Color(0.75, 0.6, 1.0, 0.35), 14.0)
	c.draw_line(pos - u * 30.0, pos + u * 4.0, Color(0.85, 0.75, 1.0), 6.0)
	c.draw_line(pos - u * 24.0, pos + u * 2.0, Color(1, 1, 1, 0.95), 2.5)
	return true
