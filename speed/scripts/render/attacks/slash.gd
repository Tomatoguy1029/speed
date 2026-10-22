## SLASHの弾の表示。
extends AttackVisual

const SHAPE := preload("res://scripts/attacks/slash.gd")

func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	draw_claws(c, pos, pr.hostile_vel[i].angle(), pr.hostile_r[i], pr.hostile_turn[i], 1.0)
	return true

func draw_claws(c: CanvasItem, pos: Vector2, travel: float, size: float, side: float, a: float) -> void:
	var thick := SHAPE.SLASH_THICK * size
	for k in 3:
		var pts := SHAPE.slash_points(pos, travel, size, side, k)
		c.draw_polyline(pts, Color(1.0, 0.45, 0.15, 0.28 * a), thick * 2.2)
		c.draw_polyline(pts, Color(1.0, 0.55, 0.22, 0.95 * a), thick)
		c.draw_polyline(pts.slice(1, pts.size() - 1), Color(1.0, 0.95, 0.85, a), maxf(_px(1.5), thick * 0.3))
