extends WeaponVisual
const BASE := preload("res://assets/pixel/airship_turret_base.png")
const TURRET := preload("res://assets/pixel/airship_turret.png")
func draw_extra(c: CanvasItem, ship_pos: Vector2, color: Color) -> void:
	c.draw_set_transform(ship_pos, state.ship_heading.angle() + PI / 2.0)
	c.draw_texture_rect(BASE, Rect2(Vector2(-BASE.get_width() / 2.0, -20.0) * cfg.character_scale,
		BASE.get_size() * cfg.character_scale), false, color)
	var mount: Vector2 = behavior.mount_position() + (ship_pos - state.ship_pos)
	var aim: Vector2 = behavior.aim_direction()
	c.draw_set_transform(mount, aim.angle() - PI / 2.0)
	c.draw_texture_rect(TURRET, Rect2(-behavior.MOUNT_PIXEL * cfg.character_scale,
		rm._ship_visual.AIRSHIP.get_size() * cfg.character_scale), false, color)
	c.draw_set_transform(Vector2.ZERO)
