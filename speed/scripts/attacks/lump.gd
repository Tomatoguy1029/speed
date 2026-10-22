extends AttackKind

func spawn(ps: ProjectileSystem, i: int, angle: float, speed: float, r: float, dmg: float) -> void:
	var t := ps.combat.enemies.table
	var u := Vector2.from_angle(angle)
	ps._add_hostile(t.pos[i] + u * (t.r[i] + r), u * speed, speed, r, 4.0, dmg, 0.0, 0.0, ProjectileSystem.HostileKind.BULLET)
	ps.state.emit(&"shoot", {"pos": t.pos[i], "kind": &"lump"})
