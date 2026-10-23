extends AttackKind

func spawn(ps: ProjectileSystem, i: int, vel: Vector2, dmg: float) -> void:
	var t := ps.combat.enemies.table
	ps._add_friend(ProjectileSystem.FriendKind.DEBRIS, &"corpse", t.pos[i], vel, maxf(10.0, t.r[i] * 0.6), dmg, 0.9, true, 0,
		t.color[i], true, 250.0, ps.state.rng.randf() * TAU, 10.0, t.id[i])
