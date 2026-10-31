## W29 エンドブラスト：終点で爆発し、Lv3から外周の小さな爆発が続く。
extends WeaponBehavior
var pending: Array[Dictionary] = []
func _blast(pos: Vector2, radius: float, damage: float) -> void:
	ctx.combat.explode(pos, radius, damage, {"cause": &"endBlast", "knock": p("knock"), "life": 0.6})
func on_end() -> void:
	var radius := area(at_level("radius_by_level"))
	var damage := atk() * at_level("damage_by_level")
	_blast(state.ship_pos, radius, damage)
	var count := int(at_level("secondary_by_level"))
	var offset := state.rng.randf() * TAU
	for i in count:
		var a := i * TAU / count + offset
		pending.append({"pos": state.ship_pos + Vector2.from_angle(a) * radius * state.rng.randf_range(0.9, 1.1),
			"radius": radius * float(p("secondary_radius")), "damage": damage * float(p("secondary_damage")),
			"delay": float(p("secondary_delay")) + i * float(p("secondary_step"))})
func tick(dt: float, _busy: bool) -> void:
	for blast in pending:
		blast.delay -= dt
		if blast.delay <= 0.0: _blast(blast.pos, blast.radius, blast.damage)
	var kept := 0
	for blast in pending:
		if blast.delay > 0.0:
			pending[kept] = blast
			kept += 1
	pending.resize(kept)
