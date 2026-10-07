## W08 ソニックブーム：駆け抜け始めと、普段の移動中は一定間隔で、進路ごと大きな衝撃波（一覧 docs/weapons.md）。
extends WeaponBehavior

var _t := 0.0

func _fire() -> void:
	build.run_sonic(&"sonic", float(p("radius")) * radius_k(), atk() * float(p("damage")) * dmg_k(), p("knock"), p("travel"))

func on_launch(_full: bool) -> void:
	_fire()

func tick(dt: float, busy: bool) -> void:
	if busy:
		return
	_t += dt
	if _t < float(p("interval")) / rate_k():
		return
	_t = 0.0
	_fire()
