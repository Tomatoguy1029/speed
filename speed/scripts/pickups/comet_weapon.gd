extends PickupEffect

func _init() -> void:
	ring_color = Color("#ffd24a")

func apply(_value: float, pickup: Pickup) -> void:
	state.pending_comet_weapons.append(pickup.weapon_id)
