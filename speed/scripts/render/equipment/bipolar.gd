extends WeaponVisual

func draw_objects(c: CanvasItem) -> void:
	var bipolar = behavior
	if bipolar.origin != null:
		var o: Vector2 = bipolar.origin
		var col := visual_color(Color(bipolar.p("color", "#69fff0")))
		c.draw_arc(o, 26.0, 0, TAU, 24, col, _px(3.0))
		c.draw_circle(o, 9.0, col)
		c.draw_line(o, state.ship_pos, Color(col, 0.25), _px(2.0))
