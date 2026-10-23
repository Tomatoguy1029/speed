extends PickupEffect

func apply(_value: float, _pickup: Pickup) -> void:
	var pickups := ctx.pickups
	var xp := 0.0
	var gems := []
	var recording := pickups.records_xp()
	for i in pickups.gem_alive.size():
		if pickups.gem_alive[i] != 0:
			xp += pickups.gem_value[i]
			if recording: gems.append([pickups.gem_seq[i], pickups.gem_value[i]])
	if recording: pickups.record_xp({"type": "xp_collect", "method": "beacon", "xp": xp, "gems": gems})
	pickups._clear_gems()
	ctx.loadout.add_xp(xp)
	state.emit(&"text", {"pos": state.ship_pos + Vector2(0, -45), "text": "XP +%d" % roundi(xp), "color": ring_color, "size": 22})
