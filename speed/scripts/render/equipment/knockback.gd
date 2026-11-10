extends WeaponVisual
## 星砕き：一撃で倒した敵が砕ける瞬間に大きな白い円、白から淡い紫へ変わる輪が広がり、細かいきらめきが散る。
## 星屑が当たった敵は白く光り、まわりに小さな光の点が開く。

var breaks: Array[Dictionary] = []
var hits: Array[Dictionary] = []
var _frame_seen := {}
var frame_shake := 0.0

func setup_frame(parent: Node2D, pixel: float) -> void:
	_painter = PixelPainter.new()
	_painter.setup_painter(pixel)
	parent.add_child(_painter)

func sync_frame(values: Array, dt: float) -> void:
	var alive := {}
	for value: Dictionary in values:
		alive[value.id] = true
		if _frame_seen.has(value.id): continue
		on_event({"type":&"shot_hit" if value.hit else &"hull_scatter","visual_key":"weapon/knockback","pos":value.pos})
		if value.hit: hits[-1].age = value.age-dt
		else: breaks[-1].age = value.age-dt
	_frame_seen = alive

func on_event(ev: Dictionary) -> void:
	if String(ev.get("visual_key", "")) != "weapon/knockback": return
	if ev.type == &"hull_scatter":
		var glitter: Array[Dictionary] = []
		for i in 40: glitter.append({"a": randf() * TAU, "v": 30.0 + randf() * 90.0})
		breaks.append({"pos": ev.pos, "age": 0.0, "glitter": glitter})
		frame_shake = maxf(frame_shake,4.0)

	elif ev.type == &"shot_hit":
		hits.append({"pos": ev.pos, "age": 0.0, "turn": randf() * TAU})

func frame_tick(dt: float, clock: float) -> void:
	var p: PixelPainter = _painter
	p.begin()
	for b in breaks: b.age += dt
	for h in hits: h.age += dt
	p.geometry_begin().knockback(breaks, hits, clock)
	p.geometry_end()
	breaks = breaks.filter(func(b): return b.age < 0.8)
	hits = hits.filter(func(h): return h.age < 0.3)
	p.end()
