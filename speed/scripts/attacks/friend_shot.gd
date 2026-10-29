extends FriendShape

## たて座の正面に当たった弾を消し、一定間隔で危険な反射弾へ変える。貫通弾も盾で止まる。
func reflect(ps: ProjectileSystem, shot: int, enemy: int, impact: Vector2) -> bool:
	var t := ps.combat.enemies.table
	var vel := ps.friend_vel[shot]
	if not ps.combat.enemies.blocks_front(enemy, impact, vel):
		return false
	if t.fire_t[enemy] > 0.0:
		return true
	var p: Dictionary = t.def[enemy].params
	var normal := (impact - t.pos[enemy]).normalized()
	if normal.is_zero_approx():
		normal = Vector2.from_angle(t.facing[enemy])
	var dir := (vel - normal * 2.0 * vel.dot(normal)).normalized()
	var speed := float(p.reflect_speed)
	ps._add_hostile(impact + normal * 2.0, dir * speed, speed, clampf(ps.friend_r[shot], 5.0, 10.0),
		float(p.reflect_life), float(p.reflect_dmg),
		0.0, 0.0, ProjectileSystem.HostileKind.REFLECTED)
	t.fire_t[enemy] = maxf(0.01, float(p.reflect_interval))
	t.flash[enemy] = 0.1
	ps.state.emit(&"shield_reflect", {"pos": impact, "normal": normal})
	return true

func spawn(ps: ProjectileSystem, from: Vector2, angle: float, dmg: float, opts := {}) -> void:
	var speed: float = opts.get("speed", 1300.0)
	var i := ps._add_friend(ProjectileSystem.FriendKind.SHOT, StringName(opts.get("cause", &"shot")), from, Vector2.from_angle(angle) * speed,
		opts.get("r", 5.0), dmg, opts.get("life", 0.9), false, opts.get("pierce_left", 0),
		opts.get("color", Color("#ffe46b")), false, float(opts.get("knock", 250.0)), 0.0, 0.0, -1)
	ps.friend_on_hit[i] = opts.get("on_hit", Callable())
