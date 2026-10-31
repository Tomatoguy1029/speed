## ポンプ座の圧縮弾：直進し、届く距離を飛ぶか何かに当たると、その場で大きく破裂する（破裂が当たる）。
extends HostileShape

func _damage_ship(_ps: ProjectileSystem, _i: int) -> void:
	pass

func on_end(ps: ProjectileSystem, i: int, at: Vector2, _reached: bool) -> void:
	if ps.hostile_life[i] > 0.0:
		var zone: int = ps.fire_zone(at, ps.hostile_burst[i], 0.0, ps.hostile_dmg[i], ProjectileSystem.HazardStyle.BLAST, Color("#4ee591"))
		ps.hazard_visual[zone] = &"res://scenes/attacks/zone_pump.tscn"

func spawn(ps: ProjectileSystem, i: int, angle: float, speed: float, r: float, range: float, burst: float, dmg: float) -> void:
	var t := ps.combat.enemies.table
	var u := Vector2.from_angle(angle)
	var h := ps._add_hostile(t.pos[i] + u * (t.r[i] + r), u * speed, speed, r, range / maxf(speed, 1.0), dmg, 0.0, 0.0,
		ProjectileSystem.HostileKind.SHELL)
	ps.hostile_burst[h] = burst
	ps.state.emit(&"shoot", {"pos": t.pos[i], "kind": &"shell"})
