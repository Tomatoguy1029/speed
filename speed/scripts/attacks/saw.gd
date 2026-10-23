extends AttackKind

func spawn(ps: ProjectileSystem, pos: Vector2, vel: Vector2, r: float, dmg: float, life: float) -> void:
	ps._add_friend(ProjectileSystem.FriendKind.HULL, &"saw", pos, vel, r, dmg, life, true, 0, Color("#d9dde6"), true, 300.0,
		vel.angle(), 14.0, -1, &"saw")
