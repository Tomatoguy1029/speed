extends WeaponVisual

func draw_objects(c: CanvasItem) -> void:
	var tow = behavior
	for j in mini(int(tow.p("visible")), tow.cargo.size()):
		var h: Dictionary = tow.cargo[j]
		rm._draw_hull(c, h.type, h.pos, h.angle, h.r, Color.TRANSPARENT)
