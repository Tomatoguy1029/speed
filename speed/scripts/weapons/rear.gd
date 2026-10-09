## W23 後方ブラスター：逃げながら進行方向の反対へ撃つ。
extends WeaponBehavior

var _t := 0.0

func tick(dt: float, busy: bool) -> void:
	if busy:
		return
	var index := clampi(level, 1, def.level_steps.size()) - 1
	var interval := float(p("interval_by_level")[index])
	_t += dt
	if _t < interval:
		return
	_t = fmod(_t, interval)
	var shots := int(p("shots_by_level")[index])
	var backwards := -state.ship_heading
	var origin := state.ship_pos + backwards * (cfg.ship_radius + 6.0)
	for i in shots:
		var angle := backwards.angle() + (i - (shots - 1) / 2.0) * float(p("spread_step"))
		build.projectiles.fire_shot(origin, angle, atk() * float(p("damage_by_level")[index]),
			{"life": p("life"), "color": Color(p("color"))})
	state.emit(&"weapon_fire", {"id": def.id})
