extends FieldGimmick

func initialize() -> void:
	field.warp_gone = -1.0

func spawn_warp() -> void:
	for attempt in 8:
		var u := Vector2.from_angle(state.rng.randf() * TAU)
		var edge := minf(state.view_half.x / maxf(absf(u.x), 0.001), state.view_half.y / maxf(absf(u.y), 0.001))
		field.warp_pos = state.view_center + u * edge * 0.8
		if field.body_gap(field.warp_pos, cfg.warp_radius) > 50.0 and field.warp_pos.length() < cfg.field_radius - 200.0:
			break
	field.warp_gone = state.world_time + cfg.warp_life

func take_warp() -> bool:
	if field.warp_gone < 0.0:
		return false
	if state.world_time >= field.warp_gone:
		field.warp_gone = -1.0
		return false
	var reach := cfg.warp_radius + cfg.ship_radius
	if state.ship_pos.distance_squared_to(field.warp_pos) > reach * reach:
		return false
	field.warp_gone = -1.0
	return true
