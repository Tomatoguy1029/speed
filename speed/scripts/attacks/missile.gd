## 誘導弾：turn の速さで敵の狙いの方へ向きを変える。追いかけるので、画面の外へ出ても消さない。
extends HostileShape

func _init() -> void:
	leaves_view = false

func steer(ps: ProjectileSystem, i: int, vel: Vector2, aim: Vector2, dt: float) -> Vector2:
	var turn := ps.hostile_turn[i] * dt
	var cur := vel.angle()
	return Vector2.from_angle(cur + clampf(Geom.angle_diff((aim - ps.hostile_pos[i]).angle(), cur), -turn, turn)) * ps.hostile_speed[i]

func spawn(ps: ProjectileSystem, pos: Vector2, muzzle: float, angle: float, speed: float, values: Dictionary) -> void:
	var u := Vector2.from_angle(angle)
	ps._add_hostile(pos + u * muzzle, u * speed, speed, 9.0, 4.5,
		float(values.get("bullet_dmg", 7.0)), values.get("slow", 0.0), values.get("missile_turn", 0.0), ProjectileSystem.HostileKind.MISSILE)
