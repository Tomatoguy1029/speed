extends WeaponVisual

func draw_objects(c: CanvasItem) -> void:
	var vortex = behavior
	for v in vortex.vortexes:
		var k: float = v.life / v.max
		for i in 3:
			var a: float = state.time * visual_number("spin_speed", 4.0) + i * TAU / 3.0
			c.draw_arc(v.pos, v.radius * (0.3 + 0.2 * i), a, a + 2.0, 16,
				visual_color(Color(0.75, 0.45, 1.0, visual_number("arc_opacity", 0.6) * k)),
				_px(visual_number("arc_width", 3.0)))
