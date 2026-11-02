extends WeaponVisual
## フルバースト：満タンになった瞬間に砲口から光がはじけ、満タンの間は砲口のまわりに青い光のドットが残る。

var sparks := PixelSparks.new()

func on_event(ev: Dictionary) -> void:
	if ev.type == &"full_burst_ready":
		_burst(_nose())

func _burst(pos: Vector2) -> void:
	sparks.add(pos, 12, 0.0, TAU, 30.0, 90.0, 0.3, [Color.WHITE, Color("#7fd8ff"), Color("#d8f6ff")])

func setup_frame(parent: Node2D, pixel: float) -> void:
	_painter = PixelPainter.new()
	_painter.setup_painter(pixel)
	parent.add_child(_painter)

func frame_event(ev: Dictionary, pos: Vector2, heading: Vector2, scale: float) -> void:
	if ev.type==&"full_burst_ready": _burst(pos+heading*16.0*1.82*scale)

func tick(_dt: float) -> void:
	frame_tick(world_dt(),_nose(),behavior.active,state.world_time,active)

func frame_tick(dt: float, nose_pos: Vector2, ready: bool, clock: float, enabled: bool) -> void:
	var p: PixelPainter = _painter if rm==null else painter()
	p.begin()
	if enabled:
		sparks.draw(p,dt)
		if ready:
			var nose := p.cell(nose_pos)
			var phase := int(clock*10.0)
			for k in 10:
				if (k+phase)&1: continue
				var a := k/10.0*TAU
				var r := 3.0+k%3
				p.fill(nose.x+cos(a)*r,nose.y+sin(a)*r,Color("#7fd8ff") if k%2 else Color("#d8f6ff"))
	p.end()

func _nose() -> Vector2:
	return state.ship_pos + state.ship_heading * 16.0 * 1.82 * cfg.character_scale
