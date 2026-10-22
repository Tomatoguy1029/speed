extends WeaponVisual

func draw_objects(c: CanvasItem) -> void:
	var vortex = behavior
	for v in vortex.vortexes:
		var k: float = v.life / v.max
		for i in 3:
			var a: float = state.time * 4.0 + i * TAU / 3.0
			c.draw_arc(v.pos, v.radius * (0.3 + 0.2 * i), a, a + 2.0, 16, Color(0.75, 0.45, 1.0, 0.6 * k), _px(3.0))
