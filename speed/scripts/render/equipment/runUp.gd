extends WeaponVisual
## 助走：最初の敵に当たるまで、機体の後ろに長さ・太さ・色・位置・流れる速さが不揃いな線が16本流れ、
## 走った距離で指数関数的に長く・太く・明るく・広がる。当たった瞬間、尾の線が当たった所へ一気に押し込まれ、
## 光がはじけて短い衝撃の線が全方向へ広がる（爆発にはしない）。

var hits: Array[Dictionary] = []

func claims(ev: Dictionary) -> bool:
	return ev.type == &"explode" and ev.get("cause", &"") == &"runUp"

func on_event(ev: Dictionary) -> void:
	if ev.type != &"run_up_hit": return
	var rays: Array[Dictionary] = []
	for i in 24:
		rays.append({"a": randf() * TAU, "len": 7.0 + randf() * 25.0, "r0": 5.0 + randf() * 6.0,
			"w": 2 if randf() < 0.4 else 1, "c": randf(), "delay": randf() * 0.03})
	var tails: Array[Dictionary] = []
	for i in 10: tails.append({"off": (randf() - 0.5) * 14.0, "len": 8.0 + randf() * 22.0})
	hits.append({"pos": ev.pos, "dir": ev.dir if ev.dir != Vector2.ZERO else state.ship_heading, "age": 0.0, "rays": rays, "tails": tails})

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	p.begin()
	if active and state.tracing and behavior.first:
		_streaks(p)
	for h in hits:
		h.age += dt
		_hit(p, h)
	hits = hits.filter(func(h): return h.age < 0.4)
	p.end()

func _streaks(p: PixelPainter) -> void:
	var x := clampf(behavior.ctx.loadout.boost_distance / float(behavior.def.params.distance), 0.0, 1.0)
	var ke := (exp(3.0 * x) - 1.0) / (exp(3.0) - 1.0)
	var t := state.world_time
	var u := state.ship_heading
	var n := u.orthogonal()
	for i in 16:
		var h1 := float((i * 73) % 100) / 100.0
		var h2 := float((i * 37) % 100) / 100.0
		var ph := fmod(h1 + t * (1.8 + 2.6 * ke) * (0.7 + 0.6 * h2), 1.0)
		var reach := 3.0 + 12.0 * ke
		var spread := (h2 - 0.5) * (5.0 + 14.0 * ke) * (0.4 + 0.6 * absf(h1 - 0.5) * 2.0)
		var side := spread + sin(t * 14.0 + i * 2.3) * 1.2 * ke
		var length := (8.0 + 50.0 * ke) * (0.35 + h1 * 0.9) * (1.0 - 0.6 * absf(spread) / reach)
		var back := 5.0 + ph * (14.0 + 40.0 * ke)
		var alpha := (0.25 + 0.6 * ke) * (1.0 - ph) * (1.0 - 0.5 * absf(spread) / reach)
		var color := Color(1.0, 245.0 / 255.0, 200.0 / 255.0, alpha) if h2 < 0.35 else Color(1.0, (185.0 + roundf(h1 * 40.0)) / 255.0, (70.0 + roundf(h2 * 60.0)) / 255.0, alpha)
		var width := roundi(0.7 + 1.6 * ke * (1.0 - absf(spread) / reach) * (0.5 + h2 * 0.5))
		var start := state.ship_pos - u * back * p.px + n * side * p.px
		p.line(start, start - u * length * p.px, color, maxi(1, width))

func _hit(p: PixelPainter, h: Dictionary) -> void:
	var a: float = h.age
	var u: Vector2 = h.dir.normalized()
	var n := u.orthogonal()
	if a < 0.06:
		var k := a / 0.06
		for l in h.tails:
			var end: Vector2 = h.pos - u * 6.0 * p.px + n * l.off * (1.0 - k) * p.px
			var length: float = l.len * (1.0 - k)
			for d in range(int(length) + 1):
				p.dot(end - u * d * p.px, Color.WHITE if d < 3 else Color("#ffd45a"))
	if a >= 0.04 and a < 0.1: p.disk(h.pos, 8.0, Color("#fff6c8"))
	for r in h.rays:
		var q := clampf((a - 0.04 - r.delay) / 0.26, 0.0, 1.0)
		if q <= 0.0 or q >= 1.0: continue
		var grow := minf(1.0, q * 4.0)
		var dir := Vector2.from_angle(r.a)
		var r0: float = r.r0 + q * 8.0
		var length: float = r.len * grow * (1.0 - q * 0.6)
		var count := maxi(1, roundi(length))
		for i in range(count + 1):
			var k := float(i) / count
			if q > 0.6 and i % 2 == 1: continue
			var color := Color.WHITE if k < 0.25 else Color("#fff6c8") if r.c < 0.4 else Color("#ffd45a") if q < 0.5 else Color("#e0a030")
			var cell := p.cell(h.pos + dir * (r0 + length * k) * p.px)
			p.fill(cell.x, cell.y, color, r.w, r.w)
