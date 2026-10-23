extends PickupEffect

func _init() -> void:
	ring_radius = 70.0
	ring_color = Color("#67e8b1")

func can_collect(_pickup: Pickup) -> bool:
	return state.ship_hp < state.stats.max_hp

func apply(_value: float, _pickup: Pickup) -> void:
	var before := state.ship_hp
	ctx.ship.heal(state.stats.max_hp * cfg.meteor_heal_frac)
	state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -40), "text": "HP +%d" % roundi(state.ship_hp - before), "color": ring_color, "size": 18})
