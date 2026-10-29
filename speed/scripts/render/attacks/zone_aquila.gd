## 雷の予告と放電は、実際の円形当たり判定の内側に収める。
extends "res://scripts/render/attacks/zone_reticle.gd"

func _burst(c: CanvasItem, pr: ProjectileSystem, i: int, p: Vector2, radius: float, fade: float, col: Color) -> void:
	c.draw_circle(p, radius, Color(col, 0.16 * fade))
	c.draw_arc(p, radius, 0.0, TAU, 40, Color(col, 0.75 * fade), _px(3.0))
	var age := pr.hazard_t[i] - pr.hazard_delay[i]
	var shape := int(age / PIXEL_LIGHTNING.SHAPE_INTERVAL)
	for arm in 5:
		var ray := Vector2.from_angle(float(arm) * TAU / 5.0 + float(i % 7)) * radius * 0.65
		PIXEL_LIGHTNING.draw(c, p, p + ray, _px(2.0), i * 7919 + arm * 313 + shape * 101,
			PIXEL_LIGHTNING.intensity(age, pr.hazard_active[i]) * fade, col)
