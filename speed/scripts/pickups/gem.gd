extends PickupEffect

func apply(value: float, _pickup: Pickup) -> void:
	ctx.loadout.add_crystal_xp(value)
