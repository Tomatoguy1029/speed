extends AttackKind

func spawn(ps: ProjectileSystem, center: Vector2, angle: float, length: float, width: float, delay: float, active: float, dmg: float,
		color := Color("#ffe0a0")) -> PackedInt32Array:
	var rows := PackedInt32Array()
	for k in 4:
		rows.append(ps.fire_beam(center, angle + k * PI / 2.0, length, width, delay, active, dmg, color))
	return rows
