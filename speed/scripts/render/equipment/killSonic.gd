extends WeaponVisual
## チェインショック：倒れた敵の位置から衝撃波。最初に白い円、途切れない太い輪（白→水色→青）が広がりながら細くなり、
## 内側に細い輪と、流れる青い点。連鎖するたびに小さく細くなる。点線の円は使わない。

var waves: Array[Dictionary] = []
var _rings: PixelShapes

func on_event(ev: Dictionary) -> void:
	if ev.type == &"chain_shock":
		waves.append({"pos": ev.pos, "radius": float(ev.radius), "life": float(ev.life), "g": int(ev.get("generation", 0)), "age": 0.0})

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	if _rings == null:
		_rings = PixelShapes.new()
		_rings.setup(p.px, PixelShapes.Shape.THICK_RING, false)
		_rings.visibility_layer = p.visibility_layer
		_rings.modulate = RenderPipeline.plain_color(rm._layers.fx)
		rm._layers.fx.add_child(_rings)
	p.begin()
	_rings.begin()
	for w in waves:
		w.age += dt
		var k: float = w.age / w.life
		if k >= 1.0: continue
		var radius: float = w.radius / p.px * (1.0 - pow(1.0 - k, 3.0))
		var g: int = w.g
		var th := maxi(1, roundi((6.0 - g * 1.3) * (1.0 - k * 0.7)))
		if k < 0.08: p.disk(w.pos, 10.0 - g, Color.WHITE)
		if radius > 6.0:
			var n := ceili(radius * 6.0)
			var phase := int(state.world_time * 50.0)
			for i in n:
				if (i + phase) % 3 != 0: continue
				var a := float(i) / n * TAU
				var rr := radius - th - 2 - (i * 7) % 4
				p.dot(w.pos + Vector2.from_angle(a) * rr * p.px, Color("#4f86cc"))
		var color := Color.WHITE if k < 0.35 else Color("#a8e0ff") if k < 0.7 else Color("#5f9be0")
		_rings.add_thick_ring(w.pos, radius, th, color, 0.05)
		if k < 0.5: _rings.add_thick_ring(w.pos, radius - th, 1, Color("#e0f6ff"), 0.05)
	waves = waves.filter(func(w): return w.age < w.life)
	p.end()
	_rings.end()

func dispose() -> void:
	if is_instance_valid(_rings): _rings.queue_free()
	super()
