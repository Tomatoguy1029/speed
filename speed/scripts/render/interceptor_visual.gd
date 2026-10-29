## 迎撃型（ストライクウィング）の装甲・銃口。ゲームと図鑑で同じピクセル形状を使う。
extends RefCounted

const DRONE := preload("res://assets/pixel/drone.png")
const MINT := Color("#8fffe2")
const EDGE := Color("#3e9eaa")
const AMBER := Color("#ffc77c")

## flash：撃ってからの残り秒（0.06 から減る）。前半は白、後半はアンバーの光を砲口の先に出す。
static func drone(c: CanvasItem, pos: Vector2, angle: float, scale_value: float, flash: float, tint := Color.WHITE) -> void:
	c.draw_set_transform(pos, angle + PI / 2.0, Vector2.ONE * scale_value)
	var size := DRONE.get_size()
	c.draw_texture_rect(DRONE, Rect2(-size / 2.0, size), false, Color("#b5ffea") * tint)
	# 両翼の装甲と二連の砲口で追走型と区別する。
	for side in [-1.0, 1.0]:
		c.draw_rect(Rect2(Vector2(side * 7.0 - 2.0, -4.0), Vector2(4, 9)), Color("#153949") * tint)
		c.draw_rect(Rect2(Vector2(side * 7.0 - 1.0, -5.0), Vector2(2, 8)), EDGE * tint)
		c.draw_rect(Rect2(Vector2(side * 4.0 - 1.0, -9.0), Vector2(2, 5)), MINT * tint)
	c.draw_rect(Rect2(-2, 6, 4, 3), Color(MINT, 0.6) * tint)
	c.draw_set_transform(Vector2.ZERO)
