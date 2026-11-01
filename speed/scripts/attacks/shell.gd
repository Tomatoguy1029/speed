## ポンプ座の圧縮弾：直進し、届く距離を飛ぶか何かに当たると、その場で大きく破裂する（破裂が当たる）。
extends HostileShape

func _damage_ship(_ps: ProjectileSystem, _i: int) -> void:
	pass

func on_end(ps: ProjectileSystem, i: int, at: Vector2, _reached: bool) -> void:
	if ps.hostile_life[i] > 0.0:
		var zone: int = ps.fire_zone(at, ps.hostile_burst[i], 0.0, ps.hostile_dmg[i], ProjectileSystem.HazardStyle.BLAST, Color("#4ee591"))
		ps.hazard_visual[zone] = &"res://scenes/attacks/zone_pump.tscn"

func spawn(ps: ProjectileSystem, i: int, angle: float, speed: float, r: float, range: float, burst: float, dmg: float, contents: PackedStringArray = PackedStringArray()) -> void:
	var t := ps.combat.enemies.table
	var u := Vector2.from_angle(angle)
	var h := ps._add_hostile(t.pos[i] + u * (t.r[i] + r), u * speed, speed, r, range / maxf(speed, 1.0), dmg, 0.0, 0.0,
		ProjectileSystem.HostileKind.SHELL)
	ps.hostile_burst[h] = burst
	var mouth_radius := 18.5 * (1.25 if t.elite[i] != 0 else 1.0) * ps.cfg.character_scale * t.def[i].visual_value("scale", 1.0)
	ps.pump_shells[h] = {"types": contents.duplicate(), "full": clampf(float(contents.size()) / maxf(float(t.def[i].params.get("store_max", 1)), 1.0), 0.0, 1.0),
		"mouth": t.pos[i] + u * mouth_radius * 0.85}
	ps.state.emit(&"shoot", {"pos": t.pos[i], "kind": &"shell"})
