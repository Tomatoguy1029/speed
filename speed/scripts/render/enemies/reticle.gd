## レチクル座の見た目。
extends EnemyVisual

static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for n in range(0,values.size(),12): draw_view(c,Vector2(values[n],values[n+1]),values[n+2],values[n+3],values[n+4],Color(values[n+5],values[n+6],values[n+7]),values[n+8]>0,Vector2(values[n+9],values[n+10]),values[n+11],pixel)

static func draw_view(c: CanvasItem, p: Vector2, r: float, facing: float, k: float, col: Color, valid: bool, at: Vector2, rock_radius: float, pixel: float) -> void:
	var lens := p + Vector2.from_angle(facing) * r
	c.draw_circle(lens, maxf(pixel*1.5, r * 0.12), Color(col, 0.7))
	if not valid:
		return
	var size := rock_radius * (1.6 - 0.5 * k)
	var spin := PI / 4.0 * (1.0 - k)
	for q in 4:
		var a := spin + q * PI / 2.0
		var corner := at + Vector2.from_angle(a) * size * 1.41
		var u := Vector2.from_angle(a + PI * 0.75)
		var v := Vector2.from_angle(a - PI * 0.75)
		c.draw_line(corner, corner + u * size * 0.5, Color(col, 0.5 + 0.5 * k), maxf(pixel*2.0, 3.0))
		c.draw_line(corner, corner + v * size * 0.5, Color(col, 0.5 + 0.5 * k), maxf(pixel*2.0, 3.0))
	c.draw_line(at - Vector2(size * 0.3, 0), at + Vector2(size * 0.3, 0), Color(col, 0.6 * k), pixel*1.5)
	c.draw_line(at - Vector2(0, size * 0.3), at + Vector2(0, size * 0.3), Color(col, 0.6 * k), pixel*1.5)
	var gap := at - lens
	var steps := int(gap.length() / 18.0)
	for n in range(0, steps, 2):
		c.draw_line(lens + gap * (float(n) / steps), lens + gap * (float(n + 1) / steps), Color(col, 0.25 + 0.5 * k), pixel*1.5)
