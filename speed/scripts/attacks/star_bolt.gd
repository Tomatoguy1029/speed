extends HostileShape
func spawn(ps: ProjectileSystem, from: Vector2, angle: float, speed: float, damage: float) -> int:
	return ps._add_hostile(from, Vector2.from_angle(angle)*speed, speed, 9.0, 6.0, damage, 0.0, 0.0, ProjectileSystem.HostileKind.STAR_BOLT)
