extends WeaponVisual
## 双極ビーム：なぞり始めの点に結晶を置き、機体まで2本の光の糸がねじれ合ってつながる。
## なぞり終えると周りから光が両端へ吸い込まれ、両端が膨らむ（溜め）。撃つ瞬間に画面が白く光って揺れ、
## 両端で青緑のピクセル炎がはじけ、二重の輪が広がる。太い光の帯（丸い両端）の中を2本の光がねじれて走り、
## 縁から火花が散る。しばらく保ってから細くなり、光の粒になって左右へ散る。帯に触れて倒れた敵は小さな炎の爆発で消える。

const TEAL := [Color.WHITE, Color("#cffff9"), Color("#69fff0"), Color("#1f7f86")]
const BEAM_SECONDS := 0.7
const CHARGE_SECONDS := 0.18
const SHADER := preload("res://shaders/bipolar_beam.gdshader")
var sparks := PixelSparks.new()
var charges: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var _crystal_since := -1.0
var _flash := 0.0
var _flash_rect: ColorRect

func on_event(ev: Dictionary) -> void:
	match ev.type:
		&"bipolar_charge":
			charges.append({"from": ev.from, "to": ev.to, "age": 0.0})
		&"beam":
			if ev.get("visual_key", "") != "weapon/bipolar": return
			_fire(ev)
		&"kill":
			if ev.get("cause", &"") != &"bipolar": return
			fires().add(ev.pos, 7.0, 0.5, TEAL, randf() * 0.08)
			var side: Vector2 = (ev.dir as Vector2).orthogonal()
			for sign_side in [-1.0, 1.0]:
				sparks.add(ev.pos, 4, (side * sign_side).angle(), 1.0, 40.0, 100.0, 0.3, [Color.WHITE, Color("#ff7a6b")])

func _fire(ev: Dictionary) -> void:
	var from: Vector2 = ev.from
	var to: Vector2 = ev.to
	var px := painter().px
	var node := MeshInstance2D.new()
	node.mesh = FireBursts._mesh()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	node.material = mat
	rm._layers.fx.add_child(node)
	var width := 16.0 * float(ev.get("width_scale", 1.0))
	var pad := Vector2.ONE * (width * 0.7 + 2.0) * px
	var center := (from + to) * 0.5
	var half := (to - from).abs() * 0.5 + pad
	node.position = center
	node.scale = half
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("half_size", half)
	mat.set_shader_parameter("cell", px)
	mat.set_shader_parameter("a", (from / px).round())
	mat.set_shader_parameter("b", (to / px).round())
	beams.append({"from": from, "to": to, "width": width, "age": 0.0, "node": node, "material": mat})
	_flash = 0.1
	rm.shake = maxf(rm.shake, 5.0)
	for pos in [from, to]:
		fires().add(pos, 20.0, 0.5, TEAL)
		sparks.add(pos, 16, 0.0, 7.0, 50.0, 140.0, 0.35, TEAL.slice(0, 3))
	var n := (to - from).normalized().orthogonal()
	for i in 70:
		var sign_side := 1.0 if randf() < 0.5 else -1.0
		motes.append({"pos": from.lerp(to, randf()), "vel": n * sign_side * (10.0 + randf() * 30.0),
			"age": -0.55, "life": 0.3 + randf() * 0.2})

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	p.begin()
	_tether(p)
	for c in charges:
		c.age += dt
		_charge(p, c)
	charges = charges.filter(func(c): return c.age < CHARGE_SECONDS)
	for bm in beams:
		bm.age += dt
		_beam(p, bm)
	for bm in beams:
		if bm.age >= BEAM_SECONDS: bm.node.queue_free()
	beams = beams.filter(func(bm): return bm.age < BEAM_SECONDS)
	for m in motes:
		m.age += dt
		if m.age < 0.0 or m.age >= m.life: continue
		m.pos += m.vel * p.px * dt
		var color: Color = Color("#cffff9") if m.age < m.life * 0.4 else Color("#69fff0")
		color.a = 1.0 - m.age / m.life
		p.dot(m.pos, color)
	motes = motes.filter(func(m): return m.age < m.life)
	sparks.draw(p, dt)
	fires().step(dt)
	p.end()
	_screen_flash(dt)

## 結晶（菱形）。g は 0〜1 の育ち。
func _crystal(p: PixelPainter, pos: Vector2, g: float) -> void:
	var c := p.cell(pos).round()
	var r := roundi(4.0 * g)
	for y in range(-r - 1, r + 2):
		var w := r + 1 - absi(y)
		p.fill(c.x - w, c.y + y, Color("#1f7f86"), w * 2 + 1, 1)
	for y in range(-r, r + 1):
		var w := r - absi(y)
		p.fill(c.x - w, c.y + y, Color("#69fff0"), w * 2 + 1, 1)
	p.fill(c.x - 1, c.y - 2, Color.WHITE, 1, 2)
	p.fill(c.x, c.y - 1, Color.WHITE)

## なぞっている間：結晶から機体まで、ねじれ合う2本の糸と、機体へ流れる白い粒。
func _tether(p: PixelPainter) -> void:
	var origin = behavior.origin
	if origin == null:
		_crystal_since = -1.0
		return
	if _crystal_since < 0.0: _crystal_since = state.world_time
	var t := state.world_time
	_crystal(p, origin, minf(1.0, (t - _crystal_since) / 0.1))
	var a := p.cell(origin)
	var d := p.cell(state.ship_pos) - a
	var length := maxf(d.length(), 1.0)
	var q := d.orthogonal() / length
	var i := 0.0
	while i < length:
		var w := 2.0 * sin(i * 0.25 - t * 12.0)
		var at := a + d * i / length
		p.fill(at.x + q.x * w, at.y + q.y * w, Color("#69fff0", 0.55))
		p.fill(at.x - q.x * w, at.y - q.y * w, Color("#cffff9", 0.55))
		i += 1.0
	for k in 4:
		var f := fposmod(t * 1.6 + k / 4.0, 1.0)
		p.fill(a.x + d.x * f, a.y + d.y * f, Color.WHITE)

## 溜め：結晶は残り、周りの光が両端へ吸い込まれ、両端が膨らむ。
func _charge(p: PixelPainter, c: Dictionary) -> void:
	var q: float = c.age / CHARGE_SECONDS
	_crystal(p, c.from, 1.0)
	for pos in [c.from, c.to]:
		for i in 14:
			var a := i / 14.0 * TAU + i * 0.7
			var d := 22.0 * (1.0 - q) * (0.6 + 0.4 * ((i * 37) % 10) / 10.0)
			p.dot(pos + Vector2.from_angle(a) * d * p.px, Color("#69fff0") if i % 2 else Color.WHITE)
		p.disk(pos, 2.0 + 4.0 * q, Color("#69fff0") if q < 0.5 else Color.WHITE)

func _beam(p: PixelPainter, bm: Dictionary) -> void:
	var a: float = bm.age
	var t := state.world_time
	var base: float = bm.width
	var width := base + 2.0 * sin(t * 60.0) if a < 0.3 else base * pow(maxf(0.0, 1.0 - (a - 0.3) / 0.4), 0.8)
	bm.material.set_shader_parameter("width", width)
	bm.material.set_shader_parameter("time", t)
	var from: Vector2 = bm.from
	var to: Vector2 = bm.to
	var n := (to - from).normalized().orthogonal()
	if a < 0.3 and randf() < 0.8:
		var sign_side := 1.0 if randf() < 0.5 else -1.0
		sparks.add(from.lerp(to, randf()) + n * sign_side * width * 0.5 * p.px, 2, (n * sign_side).angle(), 0.8, 30.0, 90.0, 0.2, TEAL.slice(0, 3))
	var q := a / 0.35
	if q < 1.0:
		for pos in [from, to]:
			p.ring(pos, 4.0 + 30.0 * q, Color.WHITE if q < 0.25 else Color("#69fff0"))
			if q > 0.15: p.ring(pos, 2.0 + 18.0 * q, Color("#cffff9"))

## 撃つ瞬間の白い光（0.1秒で消える）。
func _screen_flash(dt: float) -> void:
	_flash = maxf(0.0, _flash - dt)
	if _flash <= 0.0:
		if is_instance_valid(_flash_rect): _flash_rect.visible = false
		return
	if _flash_rect == null:
		_flash_rect = ColorRect.new()
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rm._layers.top.add_child(_flash_rect)
	var view := rm.view_rect().grow(400.0)
	_flash_rect.visible = true
	_flash_rect.position = view.position
	_flash_rect.size = view.size
	_flash_rect.color = Color("#e8fffd", 0.45 * _flash / 0.1)

func dispose() -> void:
	for bm in beams: if is_instance_valid(bm.node): bm.node.queue_free()
	if is_instance_valid(_flash_rect): _flash_rect.queue_free()
	super()
