## W02 スプレッドブラスター：短い光弾を広い扇へ撃つ。
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
	var count := shots(int(at_level("shots_by_level")))
	var a := state.ship_heading.angle()
	var origin := state.ship_pos + state.ship_heading * 16.0 * 1.82 * cfg.character_scale
	var spread := float(p("spread_step"))
	var damage := atk() * at_level("damage_by_level")
	var opts := {"life": p("life"), "knock": def.params.knock, "visual_key": "weapon/scatter"}
	for i in count:
		fire_shot(origin, a + (i - (count - 1) / 2.0) * spread, damage, opts)
	recoil = 0.07
	state.emit(&"weapon_fire", {"id": def.id, "pos": origin, "angle": a, "visual_key": "weapon/scatter"})
