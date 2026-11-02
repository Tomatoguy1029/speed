extends WeaponVisual
## マインランチャー：ブーストの終点から機雷が飛び出し（後ろに青白い軌跡）、着地すると小さな輪が光り、
## 中心の灯りが点滅して待つ。敵が踏むとドット単位の爆発と、外へ飛ぶ白い破片が出る。

## 戦闘エフェクトツールで調整する shader
const TUNED_SHADERS := [preload("res://shaders/mine_burst.gdshader")]
const EFFECT_KEY := "weapon/mines"
const BURST_RUNTIME := preload("res://scripts/render/fx/burst_runtime.gd")
var booms: Array[Dictionary] = []
var _frame_parent: Node2D
var _frame_seen := {}

func _effect_key() -> String: return EFFECT_KEY

func setup_frame(parent: Node2D, pixel: float) -> void:
	_frame_parent = parent
	_painter = PixelPainter.new()
	_painter.setup_painter(pixel)
	parent.add_child(_painter)

func blasts(shader: Shader = null) -> BlastBursts:
	if rm!=null: return super.blasts(shader)
	if _blasts==null:
		_blasts = BlastBursts.new()
		_blasts.shader = shader
		_blasts.setup(_painter.px)
		_blasts.key = EFFECT_KEY
		_frame_parent.add_child(_blasts)
	return _blasts

func sync_frame(values: Array) -> void:
	var alive := {}
	for value: Dictionary in values:
		alive[value.id] = true
		if _frame_seen.has(value.id): continue
		on_event({"type":&"explode","cause":&"mine","pos":value.pos,"radius":value.radius})
		booms[-1].age = value.age
		_blasts._items[-1].age = value.age
	_frame_seen = alive

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	overlay_order = 30
	overlay = load("res://assets/pixel/airship_mine.png")

func claims(ev: Dictionary) -> bool:
	return ev.type == &"explode" and ev.get("cause", &"") == &"mine"

func on_event(ev: Dictionary) -> void:
	if not claims(ev): return
	var px: float = (_painter if rm==null else painter()).px
	# 試作は踏まれた範囲 28 ドットに半径 23 の炎
	blasts(TUNED_SHADERS[0]).add(ev.pos, blast_radius(ev.radius, px))
	var debris := explosion_debris()
	booms.append({"pos": ev.pos, "age": 0.0, "debris": debris})
	if booms.size() > 96: booms.pop_front()

func tick(_dt: float) -> void:
	frame_tick(world_dt(),behavior.mines,state.world_time)

func frame_tick(dt: float, mines: Array, clock: float) -> void:
	var fixed := BURST_RUNTIME.profile(EFFECT_KEY)
	var time_scale := float(fixed.time_scale) if not fixed.is_empty() else ShaderTuning.burst_time_scale(EFFECT_KEY)
	var energy := float(fixed.glow_energy) if not fixed.is_empty() else visual_number("glow_energy", 1.0)
	var p: PixelPainter = _painter if rm==null else painter()
	p.begin()
	var t := clock
	for mine in mines:
		var age: float = mine.age
		var pos: Vector2 = mine.pos
		if age < 0.3: _trail(p, mine, t)
		var armed := age >= 0.14
		_mine(p, pos, armed and int(t * 6.0 + float(mine.id) * 0.37) % 2 == 0)
		if armed and age < 0.22: p.thick_ring(pos, 6.0, 1, Color("#cfeaff"))
	for b in booms:
		b.age += dt
		draw_explosion_debris(p, b.pos, b.debris, b.age, time_scale, energy)
	if not ShaderTuning.previewing(): booms = booms.filter(func(b): return b.age / time_scale < 0.4)
	blasts(TUNED_SHADERS[0]).step(dt)
	p.end()

func visual_color(original: Color) -> Color:
	var fixed := BURST_RUNTIME.profile(EFFECT_KEY)
	return original * (fixed.effect_tint as Color) if not fixed.is_empty() else super.visual_color(original)

## 単体プレビューも同じ半径・破片を使う。
static func blast_radius(radius: float, cell: float) -> float:
	return radius / cell * 23.0 / 28.0

static func explosion_debris(rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var debris: Array[Dictionary] = []
	for i in 14:
		var angle := (rng.randf() if rng != null else randf()) * TAU
		var speed := 40.0 + (rng.randf() if rng != null else randf()) * 70.0
		debris.append({"dir": Vector2.from_angle(angle), "v": speed})
	return debris

static func draw_explosion_debris(p: PixelPainter, at: Vector2, debris: Array, age: float, time_scale: float, energy: float) -> void:
	var q := age / time_scale / 0.4
	if q < 0.0 or q >= 1.0: return
	var color: Color = (Color.WHITE if q < 0.5 else Color("#8fb8ff")) * Color(energy, energy, energy, 1.0)
	for d in debris: p.dot(at + d.dir * d.v * q * p.px, color)

## 機雷の絵（試作の pmine）。紺の十字の胴、4本の突起、中心の灯り。
func _mine(p: PixelPainter, pos: Vector2, lit: bool) -> void:
	var c := p.cell(pos).round()
	p.fill(c.x - 2, c.y - 1, Color("#2b3550"), 5, 3)
	p.fill(c.x - 1, c.y - 2, Color("#2b3550"), 3, 5)
	p.fill(c.x, c.y - 4, Color("#5b6a90"), 1, 2)
	p.fill(c.x, c.y + 3, Color("#5b6a90"), 1, 2)
	p.fill(c.x - 4, c.y, Color("#5b6a90"), 2, 1)
	p.fill(c.x + 3, c.y, Color("#5b6a90"), 2, 1)
	p.fill(c.x, c.y, Color("#8fe0ff") if lit else Color("#35628a"))

## 飛び出した直後の軌跡。途中から3ドットに1つ欠ける。
func _trail(p: PixelPainter, mine: Dictionary, t: float) -> void:
	var age: float = mine.age
	var ease := 1.0 - pow(1.0 - minf(1.0, age / 0.14), 3.0)
	var start: Vector2 = mine.from.lerp(mine.to, maxf(0.0, ease - 0.5))
	var count := ceili(start.distance_to(mine.pos) / p.px)
	var fading := age / 0.3 > 0.4
	for i in count:
		if fading and (i + int(t * 60.0)) % 3 == 0: continue
		p.dot(start.lerp(mine.pos, float(i) / maxi(1, count)), Color("#cfeaff") if age / 0.3 < 0.5 else Color("#6fa8e8"))
