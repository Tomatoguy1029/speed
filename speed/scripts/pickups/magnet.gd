extends PickupEffect

func apply(_value: float, _pickup: Pickup) -> void:
	var pickups := ctx.pickups
	var xp := 0.0
	for i in pickups.gem_alive.size():
		if pickups.gem_alive[i] != 0:
			xp += pickups.gem_value[i]
	pickups._clear_gems()
	ctx.loadout.add_xp(xp)
	state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -45), "text": "XP +%d" % roundi(xp), "color": ring_color, "size": 22})
