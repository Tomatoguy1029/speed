extends WeaponVisual
const DRONE := preload("res://assets/pixel/drone.png")

func draw_objects(c: CanvasItem) -> void:
	var drones = behavior
	for d in drones.drones:
		var size := DRONE.get_size() * cfg.character_scale
		var outward: Vector2 = d.pos - state.ship_pos
		var angle := outward.angle() + PI / 2.0 if not outward.is_zero_approx() else state.ship_heading.angle() + PI / 2.0
		c.draw_set_transform(d.pos, angle)
		c.draw_texture_rect(DRONE, Rect2(-size / 2.0, size), false)
		c.draw_set_transform(Vector2.ZERO)
