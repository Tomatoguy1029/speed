extends AttackKind

func spawn(ps: ProjectileSystem, i: int, vel: Vector2, dmg: float, radius_mult := 1.0, knock_mult := 1.0, life_mult := 1.0) -> void:
	var t := ps.combat.enemies.table
	ps._add_friend(ProjectileSystem.FriendKind.DEBRIS, &"corpse", t.pos[i], vel, maxf(10.0, t.r[i] * 0.6) * radius_mult, dmg, 0.9 * life_mult, true, 0,
		t.color[i], true, 250.0 * knock_mult, ps.state.rng.randf() * TAU, 10.0, t.id[i])
