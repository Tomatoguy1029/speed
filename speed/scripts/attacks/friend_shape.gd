## 味方の弾の種類ごとの動き。行と当たり判定の共通管理はProjectileSystemが受け持つ。
class_name FriendShape
extends RefCounted

func advance(ps: ProjectileSystem, i: int, _pos: Vector2, dt: float) -> void:
	ps.friend_angle[i] += ps.friend_spin[i] * dt

func reflect(_ps: ProjectileSystem, _i: int, _enemy: int, _impact: Vector2) -> bool:
	return false

func on_end(_ps: ProjectileSystem, _i: int) -> void:
	pass
