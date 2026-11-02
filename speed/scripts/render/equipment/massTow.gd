extends WeaponVisual
## アンカーキャノン：牽引した船体（敵の絵のまま）の下に熱を帯びた橙の光がたまり、数が増えるほど広がる。
## 牽引した瞬間は小さな光の輪。房の船体は短い鎖でつながる。撃ち出すたびに砲口で白い光の玉とピクセル炎がはじけ、
## 大きな衝撃の輪が出て、塊は反動で後ろへ押される。撃った船体は白く焼けた色から橙に冷めながら飛び、
## 後ろへピクセルの炎を引き、敵を貫くたびに炎の爆発が起きる。

const TRAIL_EVERY := 0.012
## 戦闘エフェクトツールで調整する shader
const TUNED_SHADERS := [preload("res://shaders/fire_burst.gdshader")]
var captures: Array[Dictionary] = []
var shocks: Array[Dictionary] = []
var flames: Array[Dictionary] = []
var sparks := PixelSparks.new()
var recoil := 0.0
var _trail_clock := 0.0
var _under: PixelPainter

var _frame := {}
var _frame_ship := {}
var _frame_time := 0.0
func setup_frame(parent: Node2D, pixel: float) -> void:
	_painter = PixelPainter.new()
	_painter.setup_painter(pixel)
	parent.add_child(_painter)
	_under = PixelPainter.new()
	_under.setup_painter(pixel)
	_under.show_behind_parent = true
	parent.add_child(_under)
	_fires = FireBursts.new()
	_fires.setup(pixel)
	_fires.key = "weapon/massTow"
	parent.add_child(_fires)
func sync_frame(values: Dictionary, ship: Dictionary, clock: float) -> void:
	_frame = values
	_frame_ship = ship
	_frame_time = clock
func frame_tick(dt: float) -> void:
	_draw_effects(dt)
func frame_event(event: Dictionary) -> void:
	on_event(event)

func draw_objects(c: CanvasItem) -> void:
	var tow = behavior
	for j in mini(int(tow.p("visible")), tow.cargo.size()):
		var h: Dictionary = tow.cargo[j]
		rm._draw_hull(c, h.type, h.pos, h.angle, h.r, Color.TRANSPARENT, visual_color(Color.WHITE))

func on_event(ev: Dictionary) -> void:
	match ev.type:
		&"anchor_capture":
			captures.append({"pos": ev.pos, "age": 0.0})
			sparks.add(ev.pos, 5, (ev.to - ev.pos).angle(), 2.4, 20.0, 60.0, 0.2, [Color("#fff2c0"), Color("#ffbe65")])
		&"anchor_fire":
			var cells: float = ev.radius / (_painter if rm==null else painter()).px
			var dir: Vector2 = ev.dir
			var px: float = (_painter if rm==null else painter()).px
			shocks.append({"pos": ev.pos + dir * 4.0 * px, "muzzle": ev.pos + dir * (cells + 2.0) * px, "age": 0.0})
			(_fires if rm==null else fires()).add(ev.pos + dir * 7.0 * px, 14.0, 0.45)
			sparks.add(ev.pos, 9, dir.angle(), 1.1, 60.0, 150.0, 0.2, [Color.WHITE, Color("#fff2c0"), Color("#ffbe65")])
			recoil = 4.0
			if rm!=null: rm.shake = maxf(rm.shake, 3.0)
		&"shot_hit":
			if ev.get("visual_key", "") != "weapon/massTow": return
			(_fires if rm==null else fires()).add(ev.pos, 13.0, 0.45)
			sparks.add(ev.pos, 8, 0.0, 7.0, 30.0, 100.0, 0.25, [Color.WHITE, Color("#ffd9a0"), Color("#ffbe65")])
			if rm!=null: rm.shake = maxf(rm.shake, 4.0)

func tick(_dt: float) -> void:
	_draw_effects(world_dt())

func _draw_effects(dt: float) -> void:
	var p: PixelPainter = _painter if rm==null else painter()
	if _under == null:
		_under = PixelPainter.new()
		_under.setup_painter(p.px)
		_under.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_under.show_behind_parent = true
		_under.modulate = RenderPipeline.plain_color(rm._layers.fx)
		rm._layers.fx.add_child(_under)
	p.begin()
	_under.begin()
	recoil = maxf(0.0, recoil - dt * 30.0)
	_clump(p)
	for c in captures:
		c.age += dt
		var q: float = c.age / 0.14
		if q < 1.0: p.ring(c.pos, 2.0 + 7.0 * q, Color.WHITE if q < 0.4 else Color("#ffbe65"))
	captures = captures.filter(func(c): return c.age < 0.14)
	for s in shocks:
		s.age += dt
		var q: float = s.age / 0.16
		if q >= 1.0: continue
		p.ring(s.pos, 4.0 + 12.0 * q, Color.WHITE if q < 0.35 else Color("#ffbe65"))
		if q < 0.5: p.ring(s.pos, 3.0 + 7.0 * q, Color("#fff2c0"))
		if q < 0.35: p.disk(s.muzzle, 6.0 - 6.0 * q, Color.WHITE)
	shocks = shocks.filter(func(s): return s.age < 0.16)
	_hulls(p, dt)
	sparks.draw(p, dt)
	(_fires if rm==null else fires()).step(dt)
	p.end()
	_under.end()

## 塊の中心は機体の後ろ（牽引の動きと同じ式）。反動のぶん後ろへずらす。
func _clump(p: PixelPainter) -> void:
	var cargo: Array = _frame.cargo if rm==null else behavior.cargo
	var n: int = cargo.size()
	if n == 0:
		return
	var v: Vector2 = _frame_ship.ship_vel if rm==null else state.ship_vel
	var heading: Vector2 = _frame_ship.ship_heading if rm==null else state.ship_heading
	var ship_pos: Vector2 = _frame_ship.ship_pos if rm==null else state.ship_pos
	var clock: float = _frame_time if rm==null else state.world_time
	var u := v.normalized() if v.length() > 1.0 else heading
	var count := mini(int(_frame.visible if rm==null else behavior.p("visible")), n)
	var spacing := float(_frame.clump_spacing if rm==null else behavior.p("clump_spacing"))
	var center := ship_pos - u * (70.0 + spacing * sqrt(float(count)) * 0.6 + recoil * p.px)
	# 熱：中心は明るい橙、外は暗い橙を市松で。縁はノイズで崩す。広さは見えている船体の数で決める
	var radius := 4.0 + 3.0 * sqrt(float(count))
	var c := p.cell(center).round()
	var flicker := int(clock * 10.0)
	var big := ceili(radius)
	for y in range(-big, big + 1):
		for x in range(-big, big + 1):
			var d := sqrt(float(x * x + y * y)) / radius
			if d > 1.0: continue
			var nz := PixelPainter.vnoise((c.x + x) * 0.25, (c.y + y) * 0.25, clock * 3.0)
			if d + 0.35 * (nz - 0.5) > 0.85: continue
			if (x + y + flicker) & 1 and d > 0.45: continue
			_under.fill(c.x + x, c.y + y, Color("#ffbe65", 0.55) if d < 0.45 else Color("#c86a1e", 0.4))
	# 鎖：房の船体を、すでに並んだ中でいちばん近い船体（先頭は機体の後ろ）と短くつなぐ。撃ち出しを待つ間は明るく光る
	var link := Color("#fff2c0") if cargo[0].ready else Color("#ffbe65")
	for j in count:
		var hull: Vector2 = cargo[j].pos
		var near: Vector2 = ship_pos - u * 12.0 * p.px
		var near_r := 0.0
		for i in j:
			var other: Vector2 = cargo[i].pos
			if other.distance_squared_to(hull) < near.distance_squared_to(hull):
				near = other
				near_r = cargo[i].r * 0.7
		# 船体の縁から縁へつなぐ
		var dir := (hull - near).normalized()
		_chain(p, near + dir * near_r, hull - dir * float(cargo[j].r) * 0.7, link, j)

## 鎖の1区間：4ドットおきの輪（2ドット）を、細い線でつなぐ。輪は機体のほうへ流れる。
func _chain(p: PixelPainter, a: Vector2, b: Vector2, color: Color, seed: int) -> void:
	var cells := a.distance_to(b) / p.px
	if cells < 1.0: return
	p.line(a, b, Color(color, 0.35))
	var shift := fposmod((_frame_time if rm==null else state.world_time) * 12.0 + seed * 1.7, 4.0)
	var k := shift
	while k < cells:
		p.dot(b.lerp(a, k / cells), color, 2)
		k += 4.0

## 撃った船体：焼けた色と輪（白→橙）と、後ろへ引くピクセルの炎。
func _hulls(p: PixelPainter, dt: float) -> void:
	var shots: Array = _frame.shots if rm==null else _legacy_shots()
	_trail_clock += dt
	var emit := floori(_trail_clock / TRAIL_EVERY)
	_trail_clock -= emit * TRAIL_EVERY
	for shot: Dictionary in shots:
		var pos: Vector2 = shot.pos
		var cells: float = shot.r / p.px
		var hot: float = shot.age
		# 焼けた色：白 → 薄い橙 → 橙。冷めても橙の網目を重ねたまま飛ぶ
		var heat := Color(1, 1, 1, 0.85) if hot < 0.08 else Color("#ffd27a", 0.75) if hot < 0.18 else Color("#ff9a3c", 0.55)
		var c := p.cell(pos).round()
		var big := ceili(cells)
		for y in range(-big, big + 1):
			for x in range(-big, big + 1):
				if x * x + y * y > cells * cells: continue
				if hot >= 0.18 and (int(c.x) + x + int(c.y) + y) & 1: continue
				p.fill(c.x + x, c.y + y, heat)
		p.ring(pos, cells + (1.0 if hot < 0.18 else 0.0), Color.WHITE if hot < 0.18 else Color("#ffd27a"))
		var u: Vector2 = shot.vel.normalized()
		for k in emit:
			var back := pos - u * cells * p.px + u.orthogonal() * (randf() - 0.5) * cells * p.px
			var vel := -u * (30.0 + randf() * 30.0) + u.orthogonal() * (randf() - 0.5) * 20.0
			flames.append({"pos": back, "vel": vel, "age": 0.0, "life": 0.18 + randf() * 0.12})
	var kept := 0
	for f in flames:
		f.age += dt
		if f.age < f.life:
			flames[kept] = f
			kept += 1
		var q: float = f.age / f.life
		if q >= 1.0: continue
		f.pos += f.vel * p.px * dt
		var cell := p.cell(f.pos).round()
		if q > 0.7 and (int(cell.x) + int(cell.y)) & 1: continue
		var color := Color.WHITE if q < 0.2 else Color("#fff2a8") if q < 0.45 else Color("#ffb030") if q < 0.7 else Color("#d2461c")
		var size := 2 if q < 0.35 else 1
		p.fill(cell.x, cell.y, color, size, size)
	flames.resize(kept)

func _legacy_shots() -> Array:
	var pr: ProjectileSystem = behavior.ctx.projectiles
	var shots: Array = []
	for i in pr.friend_alive.size():
		if pr.friend_alive[i] != 0 and pr.friend_visual[i]==&"weapon/massTow": shots.append({"pos":pr.friend_pos[i],"vel":pr.friend_vel[i],"r":pr.friend_r[i],"age":pr.friend_age[i]})
	return shots

func dispose() -> void:
	if is_instance_valid(_under): _under.queue_free()
	super()
