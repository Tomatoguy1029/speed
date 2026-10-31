extends WeaponVisual
## マインランチャー：ブーストの終点から機雷が飛び出し（後ろに青白い軌跡）、着地すると小さな輪が光り、
## 中心の灯りが点滅して待つ。敵が踏むとドット単位の爆発と、外へ飛ぶ白い破片が出る。

## 戦闘エフェクトツールで調整する shader
const TUNED_SHADERS := [preload("res://shaders/mine_burst.gdshader")]
var booms: Array[Dictionary] = []

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	overlay_order = 30
	overlay = load("res://assets/pixel/airship_mine.png")

func claims(ev: Dictionary) -> bool:
	return ev.type == &"explode" and ev.get("cause", &"") == &"mine"

func on_event(ev: Dictionary) -> void:
	if not claims(ev): return
	var px := painter().px
	# 試作は踏まれた範囲 28 ドットに半径 23 の炎
	blasts(TUNED_SHADERS[0]).add(ev.pos, float(ev.radius) / px * 23.0 / 28.0)
	var debris: Array[Dictionary] = []
	for i in 14: debris.append({"dir": Vector2.from_angle(randf() * TAU), "v": 40.0 + randf() * 70.0})
	booms.append({"pos": ev.pos, "age": 0.0, "debris": debris})

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	p.begin()
	var t := state.world_time
	for mine in behavior.mines:
		var age: float = mine.age
		var pos: Vector2 = mine.pos
		if age < 0.3: _trail(p, mine, t)
		var armed := age >= 0.14
		_mine(p, pos, armed and int(t * 6.0 + float(mine.id) * 0.37) % 2 == 0)
		if armed and age < 0.22: p.thick_ring(pos, 6.0, 1, Color("#cfeaff"))
	for b in booms:
		b.age += dt
		var q: float = b.age / 0.4
		if q >= 1.0: continue
		for d in b.debris:
			p.dot(b.pos + d.dir * d.v * q * p.px, Color.WHITE if q < 0.5 else Color("#8fb8ff"))
	booms = booms.filter(func(b): return b.age < 0.4)
	blasts(TUNED_SHADERS[0]).step(dt)
	p.end()

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
