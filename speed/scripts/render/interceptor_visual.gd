## 迎撃型の装甲・銃口・弾。ゲームと図鑑で同じピクセル形状を使う。
extends RefCounted

const DRONE := preload("res://assets/pixel/drone.png")
const MINT := Color("#8fffe2")
const EDGE := Color("#3e9eaa")
const AMBER := Color("#ffc77c")

static func drone(c: CanvasItem, pos: Vector2, angle: float, scale_value: float, flash: float) -> void:
	c.draw_set_transform(pos, angle + PI / 2.0, Vector2.ONE * scale_value)
	var size := DRONE.get_size()
	c.draw_texture_rect(DRONE, Rect2(-size / 2.0, size), false, Color("#b5ffea"))
	# 両翼の装甲と二連の砲口で追走型と区別する。
	for side in [-1.0, 1.0]:
		c.draw_rect(Rect2(Vector2(side * 7.0 - 2.0, -4.0), Vector2(4, 9)), Color("#153949"))
		c.draw_rect(Rect2(Vector2(side * 7.0 - 1.0, -5.0), Vector2(2, 8)), EDGE)
		c.draw_rect(Rect2(Vector2(side * 4.0 - 1.0, -9.0), Vector2(2, 5)), MINT)
		if flash > 0.0:
			c.draw_rect(Rect2(Vector2(side * 4.0 - 2.0, -14.0), Vector2(4, 5)), AMBER)
			c.draw_rect(Rect2(Vector2(side * 4.0 - 1.0, -16.0), Vector2(2, 7)), Color.WHITE)
	c.draw_rect(Rect2(-2, 6, 4, 3), Color(MINT, 0.6))
	c.draw_set_transform(Vector2.ZERO)

static func shot(c: CanvasItem, pos: Vector2, angle: float, pixel: float) -> void:
	c.draw_set_transform(pos, angle, Vector2.ONE * pixel)
	c.draw_rect(Rect2(-9, -3, 13, 6), Color(MINT, 0.12))
	c.draw_rect(Rect2(-7, -2, 10, 4), Color(MINT, 0.4))
	c.draw_rect(Rect2(-5, -1, 8, 2), MINT)
	c.draw_rect(Rect2(0, -1, 3, 2), Color.WHITE)
	c.draw_set_transform(Vector2.ZERO)
