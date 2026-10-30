extends WeaponVisual
## アンカーキャノン：牽引した船体（敵の絵のまま）の下に熱を帯びた橙の光がたまり、数が増えるほど広がる。
## 牽引した瞬間は小さな光の輪と、塊へ向かう光の線と粒。撃ち出すたびに砲口で白い光の玉とピクセル炎がはじけ、
## 大きな衝撃の輪が出て、塊は反動で後ろへ押される。撃った船体は白く焼けた色から橙に冷めながら飛び、
## 後ろへピクセルの炎を引き、敵を貫くたびに炎の爆発が起きる。

const TRAIL_EVERY := 0.012
## 戦闘エフェクトツールで調整する shader
const TUNED_SHADERS := [preload("res://shaders/fire_burst.gdshader")]
var captures: Array[Dictionary] = []
var catches: Dictionary = {}
var shocks: Array[Dictionary] = []
var flames: Array[Dictionary] = []
var sparks := PixelSparks.new()
var recoil := 0.0
var _trail_clock := 0.0
var _under: PixelPainter

func draw_objects(c: CanvasItem) -> void:
	var tow = behavior
	for j in mini(int(tow.p("visible")), tow.cargo.size()):
		var h: Dictionary = tow.cargo[j]
		rm._draw_hull(c, h.type, h.pos, h.angle, h.r, Color.TRANSPARENT, visual_color(Color.WHITE))

func on_event(ev: Dictionary) -> void:
	match ev.type:
		&"anchor_capture":
			captures.append({"pos": ev.pos, "age": 0.0})
			if not behavior.cargo.is_empty(): catches[behavior.cargo[-1].source_id] = state.world_time
			sparks.add(ev.pos, 5, (ev.to - ev.pos).angle(), 2.4, 20.0, 60.0, 0.2, [Color("#fff2c0"), Color("#ffbe65")])
		&"anchor_fire":
			var cells: float = ev.radius / painter().px
			var dir: Vector2 = ev.dir
			var px := painter().px
			shocks.append({"pos": ev.pos + dir * 4.0 * px, "muzzle": ev.pos + dir * (cells + 2.0) * px, "age": 0.0})
			fires().add(ev.pos + dir * 7.0 * px, 14.0, 0.45)
			sparks.add(ev.pos, 9, dir.angle(), 1.1, 60.0, 150.0, 0.2, [Color.WHITE, Color("#fff2c0"), Color("#ffbe65")])
			recoil = 4.0
			rm.shake = maxf(rm.shake, 3.0)
		&"shot_hit":
			if ev.get("visual_key", "") != "weapon/massTow": return
			fires().add(ev.pos, 13.0, 0.45)
			sparks.add(ev.pos, 8, 0.0, 7.0, 30.0, 100.0, 0.25, [Color.WHITE, Color("#ffd9a0"), Color("#ffbe65")])
			rm.shake = maxf(rm.shake, 4.0)

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	if _under == null:
		_under = PixelPainter.new()
		_under.setup_painter(p.px)
		_under.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_under.show_behind_parent = true
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
	fires().step(dt)
	p.end()
	_under.end()

## 塊の中心は機体の後ろ（牽引の動きと同じ式）。反動のぶん後ろへずらす。
func _clump(p: PixelPainter) -> void:
	var tow = behavior
	var n: int = tow.cargo.size()
	if n == 0:
		catches.clear()
		return
	var v := state.ship_vel
	var u := v.normalized() if v.length() > 1.0 else state.ship_heading
	var count := mini(int(tow.p("visible")), n)
	var spacing := float(tow.p("clump_spacing"))
	var center := state.ship_pos - u * (70.0 + spacing * sqrt(float(count)) * 0.6 + recoil * p.px)
	# 熱：中心は明るい橙、外は暗い橙を市松で。縁はノイズで崩す。広さは見えている船体の数で決める
	var radius := 4.0 + 3.0 * sqrt(float(count))
	var c := p.cell(center).round()
	var flicker := int(state.world_time * 10.0)
	var big := ceili(radius)
	for y in range(-big, big + 1):
		for x in range(-big, big + 1):
			var d := sqrt(float(x * x + y * y)) / radius
			if d > 1.0: continue
			var nz := PixelPainter.vnoise((c.x + x) * 0.25, (c.y + y) * 0.25, state.world_time * 3.0)
			if d + 0.35 * (nz - 0.5) > 0.85: continue
			if (x + y + flicker) & 1 and d > 0.45: continue
			_under.fill(c.x + x, c.y + y, Color("#ffbe65", 0.55) if d < 0.45 else Color("#c86a1e", 0.4))
	# 牽引したばかりの船体から塊へ、光の線と流れる粒
	for j in count:
		var h: Dictionary = tow.cargo[j]
		var since: float = state.world_time - float(catches.get(h.source_id, -9.0))
		if since >= 0.45: continue
		var target := center + Vector2.from_angle(j * tow.GOLDEN_ANGLE) * spacing * 0.6 * sqrt(float(j))
		if h.pos.distance_to(target) < 3.0 * p.px: continue
		p.line(h.pos, target, Color("#ffbe65", 0.45))
		for k in 3:
			var q := fposmod(state.world_time * 3.0 + k / 3.0 + j * 0.13, 1.0)
			p.dot(h.pos.lerp(target, q), Color("#fff2c0"))

## 撃った船体：焼けた輪（白→橙）と、後ろへ引くピクセルの炎。
func _hulls(p: PixelPainter, dt: float) -> void:
	var pr: ProjectileSystem = behavior.ctx.projectiles
	_trail_clock += dt
	var emit := floori(_trail_clock / TRAIL_EVERY)
	_trail_clock -= emit * TRAIL_EVERY
	for i in pr.friend_alive.size():
		if pr.friend_alive[i] == 0 or pr.friend_visual[i] != &"weapon/massTow": continue
		var pos := pr.friend_pos[i]
		var cells := pr.friend_r[i] / p.px
		var hot := pr.friend_age[i]
		p.ring(pos, cells + (1.0 if hot < 0.18 else 0.0), Color.WHITE if hot < 0.18 else Color("#ffd27a"))
		var u := pr.friend_vel[i].normalized()
		for k in emit:
			var back := pos - u * cells * p.px + u.orthogonal() * (randf() - 0.5) * cells * p.px
			var vel := -u * (30.0 + randf() * 30.0) + u.orthogonal() * (randf() - 0.5) * 20.0
			flames.append({"pos": back, "vel": vel, "age": 0.0, "life": 0.18 + randf() * 0.12})
	for f in flames:
		f.age += dt
		var q: float = f.age / f.life
		if q >= 1.0: continue
		f.pos += f.vel * p.px * dt
		var cell := p.cell(f.pos).round()
		if q > 0.7 and (int(cell.x) + int(cell.y)) & 1: continue
		var color := Color.WHITE if q < 0.2 else Color("#fff2a8") if q < 0.45 else Color("#ffb030") if q < 0.7 else Color("#d2461c")
		var size := 2 if q < 0.35 else 1
		p.fill(cell.x, cell.y, color, size, size)
	flames = flames.filter(func(f): return f.age < f.life)

func dispose() -> void:
	if is_instance_valid(_under): _under.queue_free()
	super()
