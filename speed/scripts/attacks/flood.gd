extends AttackKind

func spawn(ps: ProjectileSystem, from: Vector2, angle: float, length: float, width: float, spread: float, delay: float, active: float,
		dmg: float, color := Color("#8fd0ff")) -> int:
	return ps._add_hazard(ProjectileSystem.HazardKind.BEAM, ProjectileSystem.HazardStyle.FLOOD, from, angle, length, width, delay, active, dmg, color,
		0.0, spread)
