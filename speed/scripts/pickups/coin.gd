extends PickupEffect

func apply(_value: float, _pickup: Pickup) -> void:
	state.coins += 1
