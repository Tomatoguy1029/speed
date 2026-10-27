## W08 ソニックブーム：駆け抜け始めと、普段の移動中は一定間隔で、進路ごと大きな衝撃波（一覧 docs/game/catalog/weapons.md）。
extends WeaponBehavior

var _t := 0.0
var _first_launch_ready := true

func _interval() -> float:
	return interval(float(p("interval")) / rate_k())

func _fire() -> void:
	var damage_by_level: Array = p("damage_by_level")
	var index := clampi(level, 1, damage_by_level.size()) - 1
	ctx.projectiles.attached_attack(&"sonic").fire(&"sonic", float(p("radius")) * radius_k(), atk() * float(damage_by_level[index]), p("knock"), p("travel"))
	_t = 0.0
	_first_launch_ready = false

func on_launch(_full: bool) -> void:
	if not _first_launch_ready and _t < _interval():
		return
	_fire()

func tick(dt: float, busy: bool) -> void:
	if busy:
		return
	_t += dt
	if _t < _interval():
		return
	_fire()
