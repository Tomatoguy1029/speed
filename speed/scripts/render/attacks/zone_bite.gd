## 噛みつきは、上下のあごが閉じる輪を描く。
extends "res://scripts/render/attacks/zone.gd"
func _burst(c: CanvasItem, _pr: ProjectileSystem, _i: int, p: Vector2, len: float, f: float, col: Color) -> void:
	var shut := 1.0 - f
	for side: float in [-1.0, 1.0]:
		var a0 := PI / 2.0 * side * (1.0 - shut * 0.8)
		c.draw_arc(p, len * 0.75, a0 - 0.9, a0 + 0.9, 10, Color(1, 1, 1, f), _px(3.0))
	c.draw_circle(p, len * 0.4, Color(col, 0.35 * f))
