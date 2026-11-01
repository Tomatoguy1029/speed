extends WeaponVisual
## 星砕き：一撃で倒した敵が砕ける瞬間に大きな白い円、白から淡い紫へ変わる輪が広がり、細かいきらめきが散る。
## 星屑が当たった敵は白く光り、まわりに小さな光の点が開く。

var breaks: Array[Dictionary] = []
var hits: Array[Dictionary] = []

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	overlay_order = 10
	overlay = load("res://assets/pixel/airship_armor.png")

func on_event(ev: Dictionary) -> void:
	if String(ev.get("visual_key", "")) != "weapon/knockback": return
	if ev.type == &"hull_scatter":
		var glitter: Array[Dictionary] = []
		for i in 40: glitter.append({"a": randf() * TAU, "v": 30.0 + randf() * 90.0})
		breaks.append({"pos": ev.pos, "age": 0.0, "glitter": glitter})
		rm.shake = maxf(rm.shake, 4.0)
	elif ev.type == &"shot_hit":
		hits.append({"pos": ev.pos, "age": 0.0, "turn": randf() * TAU})

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	p.begin()
	for b in breaks:
		b.age += dt
		var a: float = b.age
		if a < 0.05: p.disk(b.pos, 10.0, Color.WHITE)
		elif a < 0.22:
			var q := (a - 0.05) / 0.17
			p.thick_ring(b.pos, 8.0 + 26.0 * q, 2 if q < 0.5 else 1, Color.WHITE if q < 0.5 else Color("#e8dcff"))
		if a < 0.8:
			var k := a / 0.8
			var phase := int(state.world_time * 30.0)
			for g in b.glitter:
				if (int(g.v) + phase) % 4 == 0 and k > 0.5: continue
				var d: float = g.v * (1.0 - pow(1.0 - k, 2.0))
				p.dot(b.pos + Vector2.from_angle(g.a) * d * p.px, Color.WHITE if k < 0.4 else Color("#fff2c8"))
	breaks = breaks.filter(func(b): return b.age < 0.8)
	for h in hits:
		h.age += dt
		var q: float = h.age / 0.3
		if q >= 1.0: continue
		if q < 0.25: p.disk(h.pos, 4.0, Color.WHITE)
		for j in 6:
			var a2: float = j / 6.0 * TAU + h.turn
			p.dot(h.pos + Vector2.from_angle(a2) * (3.0 + 10.0 * q) * p.px, Color("#fff6d8") if q < 0.5 else Color("#c9b4ff"))
	hits = hits.filter(func(h): return h.age < 0.3)
	p.end()
