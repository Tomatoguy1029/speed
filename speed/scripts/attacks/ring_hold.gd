extends AttackKind

func spawn(ps: ProjectileSystem, i: int, n: int, radius: float, wait: float, speed: float, dmg: float) -> void:
	var c := ps.combat.enemies.table.pos[i]
	for k in n:
		var u := Vector2.from_angle(TAU * k / float(n))
		var h := ps._add_hostile(c + u * radius, u * speed, speed, 8.0, 4.0 + wait, dmg, 0.0, 0.0, ProjectileSystem.HostileKind.BULLET)
		ps.hostile_wait[h] = wait
