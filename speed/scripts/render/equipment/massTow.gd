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

func on_event(ev: Dictionary) -> void:
	match ev.type:
		&"anchor_capture":
			captures.append({"pos": ev.pos, "age": 0.0})
			sparks.add(ev.pos, 5, (ev.to - ev.pos).angle(), 2.4, 20.0, 60.0, 0.2, [Color("#fff2c0"), Color("#ffbe65")])
		&"anchor_fire":
			var cells: float = ev.radius / (_painter).px
			var dir: Vector2 = ev.dir
			var px: float = (_painter).px
			shocks.append({"pos": ev.pos + dir * 4.0 * px, "muzzle": ev.pos + dir * (cells + 2.0) * px, "age": 0.0})
			(_fires).add(ev.pos + dir * 7.0 * px, 14.0, 0.45)
			sparks.add(ev.pos, 9, dir.angle(), 1.1, 60.0, 150.0, 0.2, [Color.WHITE, Color("#fff2c0"), Color("#ffbe65")])
			recoil = 4.0

		&"shot_hit":
			if ev.get("visual_key", "") != "weapon/massTow": return
			(_fires).add(ev.pos, 13.0, 0.45)
			sparks.add(ev.pos, 8, 0.0, 7.0, 30.0, 100.0, 0.25, [Color.WHITE, Color("#ffd9a0"), Color("#ffbe65")])


func _draw_effects(dt: float) -> void:
	var p: PixelPainter = _painter
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
	(_fires).step(dt)
	p.end()
	_under.end()

## 塊の中心は機体の後ろ（牽引の動きと同じ式）。反動のぶん後ろへずらす。
func _clump(p: PixelPainter) -> void:
	var cargo: Array = _frame.cargo
	var n: int = cargo.size()
	if n == 0:
		return
	var v: Vector2 = _frame_ship.ship_vel
	var heading: Vector2 = _frame_ship.ship_heading
	var ship_pos: Vector2 = _frame_ship.ship_pos
	var clock: float = _frame_time
	var u := v.normalized() if v.length() > 1.0 else heading
	var count := mini(int(_frame.visible), n)
	var spacing := float(_frame.clump_spacing)
	var center := ship_pos - u * (70.0 + spacing * sqrt(float(count)) * 0.6 + recoil * p.px)
	# 熱と鎖は同じ画素の順序で一括生成する。位置・半径・時刻は現在のフレームを使う。
	_under.geometry_begin().mass_tow_heat(p.cell(center).round(), count, clock)
	_under.geometry_end()
	p.geometry_begin().mass_tow_chains(cargo, ship_pos, u, count, clock)
	p.geometry_end()

## 撃った船体：焼けた色と輪（白→橙）と、後ろへ引くピクセルの炎。
func _hulls(p: PixelPainter, dt: float) -> void:
	var shots: Array = _frame.shots
	_trail_clock += dt
	var emit := floori(_trail_clock / TRAIL_EVERY)
	_trail_clock -= emit * TRAIL_EVERY
	p.geometry_begin().mass_tow_hulls(shots)
	p.geometry_end()
	for shot: Dictionary in shots:
		var pos: Vector2 = shot.pos
		var cells: float = shot.r / p.px
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

func dispose() -> void:
	if is_instance_valid(_under): _under.queue_free()
	super()
