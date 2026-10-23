extends FieldGimmick
const Body = FieldSystem.Body

func initialize() -> void:
	var rng := state.rng
	for i in cfg.moon_count:
		var m := Body.new()
		m.orbit = rng.randf_range(1500.0, cfg.field_radius - 600.0)
		m.a0 = float(i) / cfg.moon_count * TAU + rng.randf_range(-0.3, 0.3)
		m.dir = -1.0 if rng.randf() < 0.5 else 1.0
		m.r = rng.randf_range(110.0, 180.0)
		field.moons.append(m)
		field.bodies.append(m)
	field._build_moon_bands()
	field.body_speed_max = 0.0
	for m in field.moons:
		field.body_speed_max = maxf(field.body_speed_max, absf(cfg.moon_orbit_speed) * m.orbit)

func tick(_real_dt: float, _world_dt: float) -> void:
	update()

func update() -> void:
	for m in field.moons:
		var a := m.a0 + m.dir * cfg.moon_orbit_speed * state.world_time
		m.pos = Vector2(cos(a), sin(a)) * m.orbit
	field._update_body_grid()
