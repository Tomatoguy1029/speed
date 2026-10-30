## W01 ブラスター：前方へ1発ずつ。追加の弾数は射撃特性で増やす。
extends WeaponBehavior
var _t := 0.0
var recoil := 0.0

func tick(dt: float, busy: bool) -> void:
	recoil = maxf(0.0, recoil - dt)
	if busy: return
	_t += dt
	var delay := shooting_interval(at_level("interval_by_level"))
	if _t < delay: return
	_t = fmod(_t, delay)
	var count := shots(1)
	var a := state.ship_heading.angle()
	var origin := state.ship_pos + state.ship_heading * 16.0 * 1.82 * cfg.character_scale
	for i in count:
		fire_shot(origin, a + (i - (count - 1) / 2.0) * float(p("spread_step")), atk() * at_level("damage_by_level"),
			{"pierce_left": int(at_level("pierce_by_level")), "life": p("life"), "knock": def.params.knock, "visual_key": "weapon/forward"})
	recoil = 0.12
	state.emit(&"weapon_fire", {"id": def.id, "pos": origin, "angle": a, "visual_key": "weapon/forward"})
