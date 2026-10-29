extends AttackKind

func spawn(ps: ProjectileSystem, i: int, dir: Vector2, speed: float, dmg: float, knock := -1.0, radius_mult := 1.0, life_mult := 1.0) -> bool:
	var t := ps.combat.enemies.table
	var r := t.r[i]
	if t.meteor_index[i] >= 0 or t.is_boss[i] != 0:
		return false
	t.hull_scattered[i] = 1
	var pos := t.pos[i]
	var rank: int = t.def[i].rank if t.def[i] != null else 0
	var count := mini(16, maxi(2, rank * 2))
	count = mini(count, 200 - ps.debris_count())
	if count <= 0: return false
	var directed := dir.length() > 0.01
	var base := dir.angle() if directed else t.facing[i]
	var spread := deg_to_rad(ps.cfg.hull_debris_spread) if directed else TAU
	for k in count:
		var a := base + ((float(k) / (count - 1) - 0.5 if count>1 else 0.0) if directed else float(k) / count) * spread
		var u := Vector2.from_angle(a)
		var v := speed * (0.85 + (k % 3) * 0.12)
		ps._add_friend(ProjectileSystem.FriendKind.DEBRIS, &"hullDebris", pos + u * r * 0.3, u * v,
			4.0 * 1.82 * ps.cfg.character_scale * radius_mult, dmg, ps.cfg.hull_debris_life * life_mult, true, 0, t.color[i], true,
			ps.cfg.hull_debris_knock if knock < 0.0 else knock, ps.state.rng.randf() * TAU,
			10.0 * (1.0 if k % 2 == 0 else -1.0), t.id[i], &"", &"weapon/knockback", &"W03")
	ps.state.emit(&"hull_scatter", {"pos": pos, "count": count, "visual_key": "weapon/knockback"})
	return true
