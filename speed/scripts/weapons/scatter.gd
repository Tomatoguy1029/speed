## W02 散弾砲：進む向きへ扇状に撃つ（一覧 docs/weapons.md）。描画中・なぞり中は休む。
extends WeaponBehavior

var _t := 0.0

func tick(dt: float, busy: bool) -> void:
	if busy:
		return
	_t += dt
	if _t < float(p("interval")) / rate_k():
		return
	_t = 0.0
	var n := tier() - 1
	var shots := 5 + n / 2
	var a := state.ship_heading.angle()
	var step: float = p("spread_step")
	for i in shots:
		build.projectiles.fire_shot(state.ship_pos, a + (i - (shots - 1) / 2.0) * step,
			atk() * dmg_k() * float(p("damage")),
			{"pierce_left": n / 3, "life": p("life"), "color": Color(p("color", "#ffb36b"))})
