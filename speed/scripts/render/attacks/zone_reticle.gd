## 照準の模様は、内側の輪が閉じる予告を描く。
extends "res://scripts/render/attacks/zone.gd"
func _charge(c: CanvasItem, p: Vector2, len: float, _t: float, k: float, col: Color) -> void:
	var a := 0.25 + 0.55 * k
	c.draw_arc(p, len, 0.0, TAU, 40, Color(col, a), _px(2.0))
	c.draw_arc(p, len * (1.0 - 0.7 * k), 0.0, TAU, 32, Color(col, a), _px(1.5))
	for q in 4:
		var u := Vector2.from_angle(q * PI / 2.0 + PI / 4.0)
		c.draw_line(p + u * len * 0.55, p + u * len * 1.15, Color(col, a), _px(2.0))
