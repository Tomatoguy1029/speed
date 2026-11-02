extends WeaponVisual
## 双極ビーム：なぞり始めの点に結晶を置き、機体まで2本の光の糸がねじれ合ってつながる。
## なぞり終えると周りから光が両端へ吸い込まれ、両端が膨らむ（溜め）。撃つ瞬間に画面が白く光って揺れ、
## 両端で青緑のピクセル炎がはじけ、二重の輪が広がる。太い光の帯（丸い両端）の中を2本の光がねじれて走り、
## 縁から火花が散る。しばらく保ってから細くなり、光の粒になって左右へ散る。帯に触れて倒れた敵は小さな炎の爆発で消える。

const TEAL := [Color.WHITE, Color("#cffff9"), Color("#69fff0"), Color("#1f7f86")]
const BEAM_SECONDS := 0.7
const CHARGE_SECONDS := 0.18
const SHADER := preload("res://shaders/bipolar_beam.gdshader")
## 戦闘エフェクトツールで調整する shader と、演出が渡す既定値
const TUNED_SHADERS := [preload("res://shaders/fire_burst.gdshader"), SHADER]
const SHADER_DEFAULTS := {"shader/fire_burst/c0": TEAL[0], "shader/fire_burst/c1": TEAL[1], "shader/fire_burst/c2": TEAL[2], "shader/fire_burst/c3": TEAL[3]}
var sparks := PixelSparks.new()
var charges: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var _crystal_since := -1.0
var _flash := 0.0
var _flash_rect: ColorRect

var _frame := {}
var _frame_ship := {}
var _frame_parent: Node2D
var _frame_top: Node2D
var _frame_view := Rect2()
var _frame_clock := 0.0
var _frame_seen := {}
func _effect_key() -> String: return "weapon/bipolar"
func setup_frame(parent: Node2D, top: Node2D, pixel: float) -> void:
	_frame_parent = parent
	_frame_top = top
	_painter = PixelPainter.new()
	_painter.setup_painter(pixel)
	parent.add_child(_painter)
	_fires = FireBursts.new()
	_fires.setup(pixel)
	_fires.key = "weapon/bipolar"
	parent.add_child(_fires)
func sync_frame(values: Dictionary, ship: Dictionary, clock: float, view: Rect2) -> void:
	_frame = values
	_frame_ship = ship
	_frame_clock = clock
	_frame_view = view
	charges.clear()
	for pending: Dictionary in values.pending: charges.append({"from":pending.from,"to":pending.to,"age":CHARGE_SECONDS-pending.delay})
	var alive := {}
	for beam: Dictionary in values.beams:
		alive[beam.id] = true
		if not _frame_seen.has(beam.id):
			_fire(beam)
			beams[-1].age = beam.age
			beams[-1].id = beam.id
			_flash = maxf(0.0,0.1-beam.age)
		for item: Dictionary in beams:
			if item.get("id",-1)==beam.id: item.age = beam.age
	_frame_seen = alive
func frame_event(event: Dictionary) -> void:
	if event.type==&"kill": on_event(event)
func frame_tick(dt: float) -> void:
	_draw_effects(dt)

func claims(ev: Dictionary) -> bool:
	if ev.type == &"kill": return ev.get("cause", &"") == &"bipolar"
	return ev.type in [&"ring", &"beam"] and ev.get("visual_key", "") == "weapon/bipolar"

func on_event(ev: Dictionary) -> void:
	match ev.type:
		&"bipolar_charge":
			charges.append({"from": ev.from, "to": ev.to, "age": 0.0})
		&"beam":
			if ev.get("visual_key", "") != "weapon/bipolar": return
			_fire(ev)
		&"kill":
			if ev.get("cause", &"") != &"bipolar": return
			(_fires if rm==null else fires()).add(ev.pos, 7.0, 0.5, TEAL, randf() * 0.08)
			var side: Vector2 = (ev.dir as Vector2).orthogonal()
			for sign_side in [-1.0, 1.0]:
				sparks.add(ev.pos, 4, (side * sign_side).angle(), 1.0, 40.0, 100.0, 0.3, [Color.WHITE, Color("#ff7a6b")])

func _fire(ev: Dictionary) -> void:
	var from: Vector2 = ev.from
	var to: Vector2 = ev.to
	var px: float = (_painter if rm==null else painter()).px
	var node := MeshInstance2D.new()
	node.mesh = FireBursts._mesh()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	node.material = mat
	node.modulate = RenderPipeline.plain_color(_frame_parent if rm==null else rm._layers.fx)
	(_frame_parent if rm==null else rm._layers.fx).add_child(node)
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
	if rm!=null: rm.shake = maxf(rm.shake, 5.0)
	for pos in [from, to]:
		(_fires if rm==null else fires()).add(pos, 20.0, 0.5, TEAL)
		sparks.add(pos, 16, 0.0, 7.0, 50.0, 140.0, 0.35, TEAL.slice(0, 3))
	var n := (to - from).normalized().orthogonal()
	for i in 70:
		var sign_side := 1.0 if randf() < 0.5 else -1.0
		motes.append({"pos": from.lerp(to, randf()), "vel": n * sign_side * (10.0 + randf() * 30.0),
			"age": -0.55, "life": 0.3 + randf() * 0.2})

func tick(_dt: float) -> void:
	_draw_effects(world_dt())

func _draw_effects(dt: float) -> void:
	var p: PixelPainter = _painter if rm==null else painter()
	p.begin()
	_tether(p)
	for c in charges:
		if rm!=null: c.age += dt
		_charge(p, c)
	charges = charges.filter(func(c): return c.age < CHARGE_SECONDS)
	for bm in beams:
		if rm!=null: bm.age += dt
		_beam(p, bm)
	for bm in beams:
		if bm.age >= BEAM_SECONDS: bm.node.queue_free()
	beams = beams.filter(func(bm): return bm.age < BEAM_SECONDS)
	var kept := 0
	for m in motes:
		m.age += dt
		if m.age < m.life:
			motes[kept] = m
			kept += 1
		if m.age < 0.0 or m.age >= m.life: continue
		m.pos += m.vel * p.px * dt
		var color: Color = Color("#cffff9") if m.age < m.life * 0.4 else Color("#69fff0")
		color.a = 1.0 - m.age / m.life
		p.dot(m.pos, color)
	motes.resize(kept)
	sparks.draw(p, dt)
	(_fires if rm==null else fires()).step(dt)
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
	var origin = (_frame.origin if _frame.active else null) if rm==null else behavior.origin
	if origin == null:
		_crystal_since = -1.0
		return
	if _crystal_since < 0.0: _crystal_since = _frame.started if rm==null else state.world_time
	var t: float = _frame_clock if rm==null else state.world_time
	_crystal(p, origin, minf(1.0, (t - _crystal_since) / 0.1))
	var a := p.cell(origin)
	var d := p.cell(_frame_ship.ship_pos if rm==null else state.ship_pos) - a
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
	var t: float = _frame_clock if rm==null else state.world_time
	var base: float = bm.width
	var width := base + 2.0 * sin(t * 60.0) if a < 0.3 else base * pow(maxf(0.0, 1.0 - (a - 0.3) / 0.4), 0.8)
	bm.material.set_shader_parameter("width", width)
	bm.material.set_shader_parameter("time", t)
	tune(bm.material)
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
		(_frame_top if rm==null else rm._layers.top).add_child(_flash_rect)
	var view: Rect2 = (_frame_view if rm==null else rm.view_rect()).grow(400.0)
	_flash_rect.visible = true
	_flash_rect.position = view.position
	_flash_rect.size = view.size
	_flash_rect.color = Color("#e8fffd", 0.45 * _flash / 0.1)

func dispose() -> void:
	for bm in beams: if is_instance_valid(bm.node): bm.node.queue_free()
	if is_instance_valid(_flash_rect): _flash_rect.queue_free()
	super()
