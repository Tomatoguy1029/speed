extends AttackKind

func spawn(ps: ProjectileSystem, pos: Vector2, count: int, speed: float, dmg: float, color: Color, source_id: int) -> void:
	for k in count:
		var u := Vector2.from_angle(TAU * k / float(count) + ps.state.rng.randf() * 0.4)
		ps._add_friend(ProjectileSystem.FriendKind.DEBRIS, &"hullDebris", pos + u * 10.0, u * speed * (0.8 + 0.3 * ps.state.rng.randf()),
			12.0, dmg, ps.cfg.hull_debris_life, true, 0, color, true, ps.cfg.hull_debris_knock, ps.state.rng.randf() * TAU,
			10.0 * (1.0 if k % 2 == 0 else -1.0), source_id)
	ps.state.emit(&"hull_scatter", {"pos": pos, "count": count})
