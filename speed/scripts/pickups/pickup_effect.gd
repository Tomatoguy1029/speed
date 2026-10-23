## 回収物を取得したときの効果。行の移動・寿命・再利用はPickupSystemが管理する。
class_name PickupEffect
extends RunSystem
var ring_radius := 120.0
var ring_color := Color("#b8a0ff")
func can_collect(_pickup: Pickup) -> bool:
	return true
func apply(_value: float, _pickup: Pickup) -> void:
	pass
