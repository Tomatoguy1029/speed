extends WeaponVisual
## フルバースト：満タンになった瞬間に砲口から光がはじけ、満タンの間は砲口のまわりに青い光のドットが残る。

var sparks := PixelSparks.new()

func on_event(ev: Dictionary) -> void:
	if ev.type == &"full_burst_ready":
		sparks.add(_nose(), 12, 0.0, TAU, 30.0, 90.0, 0.3, [Color.WHITE, Color("#7fd8ff"), Color("#d8f6ff")])

func tick(_dt: float) -> void:
	var p := painter()
	p.begin()
	if active:
		sparks.draw(p, world_dt())
		if behavior.active:
			var nose := p.cell(_nose())
			var phase := int(state.world_time * 10.0)
			for k in 10:
				if (k + phase) & 1: continue
				var a := k / 10.0 * TAU
				var r := 3.0 + k % 3
				p.fill(nose.x + cos(a) * r, nose.y + sin(a) * r, Color("#7fd8ff") if k % 2 else Color("#d8f6ff"))
	p.end()

func _nose() -> Vector2:
	return state.ship_pos + state.ship_heading * 16.0 * 1.82 * cfg.character_scale
