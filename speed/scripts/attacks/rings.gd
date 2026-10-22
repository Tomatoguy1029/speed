extends AttackKind

func spawn(ps: ProjectileSystem, center: Vector2, layers: int, interval: float, radius: float, speed: float, width: float, delay: float,
		dmg: float, gap: float, gap_w: float, gap_step: float, color := Color("#9ad8ff")) -> void:
	for k in layers:
		ps.fire_wave(center, 0.0, PI, radius, speed, width, delay + k * interval, dmg, gap + k * gap_step, gap_w, color)
