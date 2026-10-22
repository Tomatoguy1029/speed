extends AttackKind

func spawn(ps: ProjectileSystem, i: int, dir: Vector2, speed: float, dmg: float, knock := -1.0) -> bool:
	var t := ps.combat.enemies.table
	var r := t.r[i]
	if r < ps.cfg.hull_debris_min_radius or t.meteor_index[i] >= 0 or t.is_boss[i] != 0 or t.hull_scattered[i] != 0:
		return false
	t.hull_scattered[i] = 1
	var pos := t.pos[i]
	var count := mini(ps.cfg.hull_debris_max_pieces, maxi(6, ceili(r / 12.0)))
	var directed := dir.length() > 0.01
	var base := dir.angle() if directed else t.facing[i]
	var spread := deg_to_rad(ps.cfg.hull_debris_spread) if directed else TAU
	for k in count:
		var a := base + ((float(k) / (count - 1) - 0.5) if directed else float(k) / count) * spread
		var u := Vector2.from_angle(a)
		var v := speed * (0.85 + (k % 3) * 0.12)
		ps._add_friend(ProjectileSystem.FriendKind.DEBRIS, &"hullDebris", pos + u * r * 0.3, u * v,
			clampf(r * 0.17, 10.0, 20.0), dmg, ps.cfg.hull_debris_life, true, 0, t.color[i], true,
			ps.cfg.hull_debris_knock if knock < 0.0 else knock, ps.state.rng.randf() * TAU,
			10.0 * (1.0 if k % 2 == 0 else -1.0), t.id[i])
	ps.state.emit(&"hull_scatter", {"pos": pos, "count": count})
	return true
