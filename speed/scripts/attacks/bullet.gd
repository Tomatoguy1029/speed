## ふつうの弾：直進する。
extends HostileShape

func spawn(ps: ProjectileSystem, pos: Vector2, muzzle: float, angle: float, speed: float, values: Dictionary) -> void:
	var u := Vector2.from_angle(angle)
	ps._add_hostile(pos + u * muzzle, u * speed, speed, 7.0, 4.0,
		float(values.get("bullet_dmg", 7.0)), values.get("slow", 0.0), values.get("missile_turn", 0.0), ProjectileSystem.HostileKind.BULLET)
