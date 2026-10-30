extends WeaponVisual
## エンドホール：ブーストのあと、飛び続ける機体を中心に紫と白の粒が集まり（溜め）、真っ黒の暗黒が生まれて
## 重力レンズで周りの光を曲げる（機体のすぐ下で画面を読む hole_lens）。引き込みの瞬間は周りが暗い紫に沈み、
## 敵は紫の尾を引いて中心へ引きずられながら、その敵の色の細かい粒に砕けていく。暗黒は一気に縮んで消え、
## 消えきった瞬間に機体の周りへ緑のやわらかい光が広がり、緑の粒が舞い上がる。

const CHARGE := 0.15
const PULL := 0.07
const HOLD := 0.22
const COLLAPSE := 0.15
var holes: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var heals: Array[Dictionary] = []
var _add: PixelPainter

const LENS := preload("res://shaders/hole_lens.gdshader")
const GLOW := preload("res://shaders/soft_glow.gdshader")
## 戦闘エフェクトツールで調整する shader
const TUNED_SHADERS := [LENS]

func dispose() -> void:
	if is_instance_valid(_add): _add.queue_free()
	for h in holes: _free_lens(h)
	for g in heals:
		g.outer.queue_free()
		g.inner.queue_free()
	super()

func _free_lens(h: Dictionary) -> void:
	if is_instance_valid(h.lens): h.lens.queue_free()

## 引き込まれて倒れた敵は、砕けながら中心へ消える姿をここで描く。
func claims(ev: Dictionary) -> bool:
	return ev.type == &"kill" and ev.get("cause", &"") == &"vortex"

func on_event(ev: Dictionary) -> void:
	match ev.type:
		&"end_hole":
			var particles: Array[Dictionary] = []
			for i in 140:
				particles.append({"a": randf() * TAU, "r0": 40.0 + randf() * 140.0, "sw": (randf() - 0.5) * 1.6,
					"st": randf() * 0.18, "du": 0.08 + randf() * 0.16, "sz": 0.8 + randf() * 1.8, "white": randf() < 0.3})
			var lens := ColorRect.new()
			lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lens.material = ShaderMaterial.new()
			lens.material.shader = LENS
			lens.z_index = -1
			rm._layers.ship.add_child(lens)
			holes.append({"age": 0.0, "particles": particles, "lens": lens})
		&"hole_capture":
			var shards: Array[Dictionary] = []
			for i in 12: shards.append({"a": randf() * TAU, "v": 20.0 + randf() * 50.0, "s": 1 + randi() % 3, "o": randf()})
			captures.append({"from": ev.pos, "r": float(ev.radius), "color": ev.color, "age": 0.0,
				"delay": randf() * 0.08, "sw": (randf() - 0.5) * 1.2, "shards": shards})
		&"hole_recover":
			var dots: Array[Dictionary] = []
			for i in 14: dots.append({"a": randf() * TAU, "v": 14.0 + randf() * 26.0, "up": 10.0 + randf() * 22.0, "s": 1.2 + randf() * 1.6, "dl": randf() * 0.12})
			heals.append({"age": 0.0, "dots": dots, "outer": _glow_rect(), "inner": _glow_rect()})

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	if _add == null:
		_add = PixelPainter.new()
		_add.setup_painter(p.px)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_add.material = add
		rm._layers.top.add_child(_add)
	p.begin()
	_add.begin()
	var center := state.ship_pos
	for h in holes:
		h.age += dt
		_hole(h, center)
	for h in holes:
		if h.age >= CHARGE + HOLD + COLLAPSE: _free_lens(h)
	holes = holes.filter(func(h): return h.age < CHARGE + HOLD + COLLAPSE)
	for c in captures:
		c.age += dt
		_capture(p, c, center)
	captures = captures.filter(func(c): return c.age < 0.6)
	for g in heals:
		g.age += dt
		_heal(p, g, center)
	for g in heals:
		if g.age >= 0.7:
			g.outer.queue_free()
			g.inner.queue_free()
	heals = heals.filter(func(g): return g.age < 0.7)
	p.end()
	_add.end()

func _hole(h: Dictionary, center: Vector2) -> void:
	var a: float = h.age
	var px := _add.px
	var shadow := 0.0
	if a < CHARGE: shadow = 5.0 + 9.0 * a / CHARGE
	elif a < CHARGE + HOLD: shadow = 14.0
	else: shadow = maxf(0.0, 14.0 * (1.0 - (a - CHARGE - HOLD) / COLLAPSE))
	var dim := 0.0
	var glow_radius := 30.0 + 20.0 * a / CHARGE
	var glow := 0.35 + 0.4 * a / CHARGE
	if a >= CHARGE:
		var k := clampf((a - CHARGE) / (PULL + 0.3), 0.0, 1.0)
		dim = 0.5 * (1.0 - k)
		glow_radius = 110.0 * (1.0 - k * 0.6)
		glow = 0.85 * (1.0 - k)
	var reach := minf(shadow * 7.0, 120.0)
	var half := maxf(reach, maxf(115.0, glow_radius)) * px
	var lens: ColorRect = h.lens
	lens.position = center - Vector2(half, half)
	lens.size = Vector2(half, half) * 2.0
	var mat := lens.material as ShaderMaterial
	mat.set_shader_parameter("half_size", half)
	mat.set_shader_parameter("shadow", shadow * px)
	mat.set_shader_parameter("reach", reach * px)
	mat.set_shader_parameter("dim_radius", 115.0 * px)
	mat.set_shader_parameter("dim", dim)
	mat.set_shader_parameter("glow_radius", glow_radius * px)
	mat.set_shader_parameter("glow", glow)
	tune(mat)
	if a >= CHARGE and a < CHARGE + PULL + 0.12: rm.shake = maxf(rm.shake, 6.0 * (1.0 - (a - CHARGE) / (PULL + 0.12)))
	# 溜め：粒が中心へ集まる。中心に近いほど薄れて暗黒に消える
	for q in h.particles:
		var pr: float = (a - q.st) / q.du
		if pr < 0.0 or pr >= 1.0: continue
		var head := _particle(q, pr, center, px)
		var tail := _particle(q, maxf(0.0, pr - 0.18), center, px)
		var fade := clampf((head.distance_to(center) / px - 6.0) / 30.0, 0.0, 1.0) * (0.4 + 0.6 * pr)
		var color := Color(1, 1, 1, fade) if q.white else Color(190.0 / 255.0, 120.0 / 255.0, 1.0, fade)
		_add.line(tail, head, color, maxi(1, roundi(q.sz)))

func _particle(q: Dictionary, u: float, center: Vector2, px: float) -> Vector2:
	var radius: float = q.r0 * (1.0 - u * u * u) + 2.0
	return center + Vector2.from_angle(q.a + q.sw * u) * radius * px

## 引きずられる敵：紫の尾、縮んで薄れる本体、その敵の色の砕けた粒。
func _capture(p: PixelPainter, c: Dictionary, center: Vector2) -> void:
	var start: Vector2 = c.from
	var d0 := start.distance_to(center) / p.px
	var duration := 0.12 + d0 / 100.0 * 0.12
	var u := clampf((c.age - c.delay) / duration, 0.0, 1.0)
	var a0 := (start - center).angle()
	var at := func(v: float) -> Vector2:
		var e := v * v
		return center + Vector2.from_angle(a0 + c.sw * e) * (d0 * (1.0 - e) + 6.0 * e) * p.px
	var r: float = c.r / p.px * 0.55
	if u < 1.0:
		var prev: Vector2 = at.call(0.0)
		var v := 0.1
		while v <= u + 0.0001:
			var next: Vector2 = at.call(minf(v, u))
			p.line(prev, next, Color(200.0 / 255.0, 140.0 / 255.0, 1.0, 0.6 * (1.0 - u)), maxi(1, roundi(r * (1.0 - 0.5 * u))))
			prev = next
			v += 0.1
		var body: Color = c.color
		body.a = 1.0 - 0.85 * u
		p.disk(at.call(u), r * (1.0 - 0.65 * u), body)
	for s in c.shards:
		var ub: float = s.o * 0.95
		var start_time: float = c.delay + duration * ub
		var k := clampf((c.age - start_time) / (duration * (1.0 - ub) * 0.9 + 0.03), 0.0, 1.0)
		if c.age < start_time or k >= 1.0: continue
		var pos: Vector2 = at.call(ub + (1.0 - ub) * k) + Vector2.from_angle(s.a) * s.v * 0.18 * sin(k * PI) * p.px
		var fade := clampf((pos.distance_to(center) / p.px - 8.0) / 20.0, 0.0, 1.0)
		var shade: Color = (c.color as Color).lightened(0.2) if s.o < 0.33 else c.color if s.o < 0.66 else (c.color as Color).darkened(0.15)
		shade.a = fade
		p.dot(pos, shade, s.s)

## 回復：機体を中心に緑のやわらかい光が広がり（外の光と、白っぽい内の光）、緑の丸い粒が舞い上がる。
func _heal(p: PixelPainter, g: Dictionary, center: Vector2) -> void:
	var h: float = g.age / 0.7
	_glow(g.outer, center, (12.0 + 40.0 * h) * p.px, Color(110.0 / 255.0, 1.0, 170.0 / 255.0, 0.55 * (1.0 - h)))
	_glow(g.inner, center, (8.0 + 14.0 * h) * p.px, Color(220.0 / 255.0, 1.0, 230.0 / 255.0, 0.5 * (1.0 - h) * (1.0 - h)))
	for dot in g.dots:
		var k := clampf((h - dot.dl) / (1.0 - dot.dl), 0.0, 1.0)
		if k <= 0.0 or k >= 1.0: continue
		var pos: Vector2 = center + Vector2(cos(dot.a) * dot.v * k, sin(dot.a) * dot.v * k * 0.6 - dot.up * k) * p.px
		p.disk(pos, dot.s, Color(Color("#8fffbe"), 1.0 - k))

func _glow(rect: ColorRect, center: Vector2, radius: float, color: Color) -> void:
	rect.position = center - Vector2.ONE * radius
	rect.size = Vector2.ONE * radius * 2.0
	(rect.material as ShaderMaterial).set_shader_parameter("glow_color", color)

## 回復の光の面（機体の下に置く）。
func _glow_rect() -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = ShaderMaterial.new()
	rect.material.shader = GLOW
	rect.z_index = -1
	rm._layers.ship.add_child(rect)
	return rect
