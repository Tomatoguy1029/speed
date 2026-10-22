## ポンプ座の圧縮弾：直進し、届く距離を飛ぶか何かに当たると、その場で大きく破裂する（破裂が当たる）。
extends HostileShape

func _damage_ship(_ps: ProjectileSystem, _i: int) -> void:
	pass

func on_end(ps: ProjectileSystem, i: int, at: Vector2, _reached: bool) -> void:
	if ps.hostile_life[i] > 0.0:
		ps.fire_zone(at, ps.hostile_burst[i], 0.0, ps.hostile_dmg[i], ProjectileSystem.HazardStyle.BLAST, Color("#c9a6ff"))
