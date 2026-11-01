extends PickupEffect

func apply(_value: float, _pickup: Pickup) -> void:
	var xp := ctx.pickups.collect_all_gems(&"magnet")
	state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -45), "text": "XP +%d" % roundi(xp), "color": ring_color, "size": 22})
