## ケフェウス座の兵の細長い光弾。直進し、追尾しない。
extends HostileShape

func spawn(ps: ProjectileSystem, from: Vector2, angle: float, speed: float, dmg: float) -> void:
	ps._add_hostile(from, Vector2.from_angle(angle) * speed, speed, 7.0, 4.0, dmg, 0.0, 0.0, ProjectileSystem.HostileKind.BOLT)
	ps.state.emit(&"shoot", {"pos": from, "kind": &"bolt"})
