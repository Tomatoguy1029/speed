extends WeaponVisual
## バリアシステム：殻が弾を受け止めると、当たった点から殻の上を左右へ光が回り込んで一周光り、一周光ったら
## 機体の中心から外へ六角形の輪が1段ずつ光って波動になる（外の段が光ると内の段は暗くなる）。
## 決まった回数目の1発では、波動が一番外の段まで届いたところで、その段のマスが白く光って欠片になって散る。
## 復活は、機体の前から左右へ回り込むようにマスが組み上がり、殻全体が一度光って消える。

const SPIN := 0.16
const STEP := 0.05
const HEX := 4.0
const FIRST_RING := 4
var hits: Array[Dictionary] = []
var restores: Array[Dictionary] = []
var shards: Array[Dictionary] = []
var crosses: Array[Dictionary] = []
var sparks := PixelSparks.new()
var _cells: Array[Vector2] = []
var _cells_radius := -1.0

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	overlay_order = 10
	overlay = load("res://assets/pixel/airship_armor.png")
	# 白い光と淡い青の段の違いが見えるよう、発光させない層へ描く。
	var p := painter()
	p.visibility_layer = 1
	p.reparent(rm._layers.top)

func on_event(ev: Dictionary) -> void:
	match ev.type:
		&"barrier_hit":
			hits.append({"angle": float(ev.angle), "age": 0.0, "broken": bool(ev.broken), "radius": float(ev.radius), "shattered": false})
			sparks.add(ev.hit, 8, float(ev.angle), 1.6, 20.0, 60.0, 0.3, [Color.WHITE, Color("#bfe0ff"), Color("#76aaff")])
		&"barrier_restore":
			restores.append({"age": 0.0})

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	p.begin()
	var center := state.ship_pos
	for h in hits:
		h.age += dt
		_hit(p, h, center)
	hits = hits.filter(func(h): return h.age < SPIN + STEP * (_last_ring(h.radius, p.px) - FIRST_RING + 2) + 0.1)
	for r in restores:
		r.age += dt
		_restore(p, r, center)
	restores = restores.filter(func(r): return r.age < 0.5)
	_shards(p, dt)
	sparks.draw(p, dt)
	p.end()

func _last_ring(radius: float, px: float) -> int:
	return maxi(FIRST_RING + 1, roundi(radius / px / (sqrt(3.0) * HEX)))

## 六角形の格子（中心からの位置、ドット）。波動の届く半径まで作り、半径が変わったときだけ作り直す。
func _lattice(radius_cells: float) -> Array[Vector2]:
	if absf(radius_cells - _cells_radius) < 0.5: return _cells
	_cells_radius = radius_cells
	_cells.clear()
	var w := sqrt(3.0) * HEX
	var rows := ceili(radius_cells / (HEX * 1.5)) + 1
	var cols := ceili(radius_cells / w) + 1
	for row in range(-rows, rows + 1):
		for col in range(-cols, cols + 1):
			var at := Vector2(col * w + (w / 2.0 if row % 2 != 0 else 0.0), row * HEX * 1.5)
			if at.length() < radius_cells: _cells.append(at)
	return _cells

func _hex(p: PixelPainter, center: Vector2, at: Vector2, color: Color) -> void:
	for i in 6:
		var a0 := PI / 6.0 + i * PI / 3.0
		var a1 := a0 + PI / 3.0
		p.line(center + (at + Vector2.from_angle(a0) * 3.6) * p.px, center + (at + Vector2.from_angle(a1) * 3.6) * p.px, color)

func _hit(p: PixelPainter, h: Dictionary, center: Vector2) -> void:
	var a: float = h.age
	var ring_width := sqrt(3.0) * HEX
	var last := _last_ring(h.radius, p.px)
	var cells := _lattice((last + 0.6) * ring_width)
	if a < SPIN + STEP:
		for at in cells:
			var d := at.length()
			if d < 13.0 or d > 24.0: continue
			var da := absf(angle_difference(at.angle(), h.angle))
			var lit := a - da / PI * SPIN
			if lit < 0.0: continue
			_hex(p, center, at, Color.WHITE if lit < 0.04 else Color("#9cc4ff"))
	if a < SPIN + STEP: return
	var k := FIRST_RING + floori((a - SPIN - STEP) / STEP)
	if k > last + 1: return
	for at in cells:
		var ring := roundi(at.length() / ring_width)
		if ring == k and k <= last: _hex(p, center, at, Color("#e6f3ff"))
		elif ring == k - 1 and k - 1 >= FIRST_RING: _hex(p, center, at, Color(Color("#76aaff"), 0.45))
	if h.broken and k == last + 1 and not h.shattered:
		h.shattered = true
		var outer: Array[Vector2] = []
		for at in cells:
			if roundi(at.length() / ring_width) == last:
				outer.append(at)
				_hex(p, center, at, Color.WHITE)
				crosses.append({"pos": center + at * p.px, "age": 0.0})
		for j in maxi(1, outer.size()) * 6:
			var pa := randf() * TAU
			var pr := (last - 0.6 + randf() * 1.1) * ring_width
			var da := pa + (randf() - 0.5) * 1.1
			var speed := 35.0 + pow(randf(), 1.6) * 110.0
			shards.append({"pos": center + Vector2.from_angle(pa) * pr * p.px, "vel": Vector2.from_angle(da) * speed,
				"age": -randf() * 0.05, "life": 0.25 + randf() * 0.3,
				"color": Color.WHITE if randf() < 0.4 else (Color("#bfe0ff") if randf() < 0.65 else Color("#76aaff")),
				"size": 3 if randf() < 0.25 else (2 if randf() < 0.7 else 1)})

## 欠片：外向きに散り、毎秒0.1倍に減速し、残り4割で市松に透けて消える。外周のマスに白い十字の閃光（0.1秒）。
func _shards(p: PixelPainter, dt: float) -> void:
	var damping := pow(0.1, dt)
	for s in shards:
		s.age += dt
		if s.age < 0.0 or s.age >= s.life: continue
		s.pos += s.vel * p.px * dt
		s.vel *= damping
		var cell := p.cell(s.pos)
		if s.age / s.life > 0.6 and (int(cell.x) + int(cell.y)) % 2 != 0: continue
		p.fill(cell.x, cell.y, s.color, s.size, s.size)
	shards = shards.filter(func(s): return s.age < s.life)
	for c in crosses:
		c.age += dt
		var q: float = c.age / 0.1
		if q >= 1.0: continue
		var l := 4 if q < 0.5 else 2
		var cell := p.cell(c.pos)
		var color := Color.WHITE if q < 0.5 else Color("#bfe0ff")
		p.fill(cell.x - l, cell.y, color, l * 2 + 1, 1)
		p.fill(cell.x, cell.y - l, color, 1, l * 2 + 1)
	crosses = crosses.filter(func(c): return c.age < 0.1)

func _restore(p: PixelPainter, r: Dictionary, center: Vector2) -> void:
	var a: float = r.age
	var heading := state.ship_heading.angle()
	for at in _lattice(maxf(_cells_radius, 25.0)):
		var d := at.length()
		if d < 13.0 or d > 24.0: continue
		var lit := a - absf(angle_difference(at.angle(), heading)) / PI * 0.3
		if lit < 0.0: continue
		if a < 0.3: _hex(p, center, at, Color.WHITE if lit < 0.06 else Color("#76aaff"))
		else:
			var q := (a - 0.3) / 0.2
			if q < 1.0: _hex(p, center, at, Color(Color("#e6f3ff") if q < 0.3 else Color("#9cc4ff"), 1.0 - q))
