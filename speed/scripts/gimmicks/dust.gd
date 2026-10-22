extends FieldGimmick

func initialize() -> void:
	var rng := state.rng
	for i in cfg.dust_count:
		var a := rng.randf() * TAU
		var d := rng.randf_range(cfg.planet_radius + 600.0, cfg.field_radius - 200.0)
		field.dust.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(250.0, 620.0)))

func dust_drag_at(p: Vector2) -> float:
	for d in field.dust:
		if p.distance_squared_to(Vector2(d.x, d.y)) < d.z * d.z:
			return cfg.dust_drag
	return 0.0
