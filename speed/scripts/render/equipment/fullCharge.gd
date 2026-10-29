extends WeaponVisual
## ギアアップ：ブースト中、機体が炎をまとう。最初は弱く、進むほど指数関数的に炎が大きく激しくなり、後ろへたなびく。
## 粒は機体に対する位置で持ち、機体と一緒に動く（速さが変わっても炎の長さが試作と同じになる）。
## 機首から出る粒の一部は機体の上に重ねる。色は白→薄い黄→黄→橙→濃い橙→暗い赤。

const COLORS := [Color("#ffffff"), Color("#fff2a8"), Color("#ffd040"), Color("#ff9a1e"), Color("#e9561c"), Color("#9a2a14")]
var flames: Array[Dictionary] = []
var _acc := 0.0
var _top: PixelPainter

func dispose() -> void:
	if is_instance_valid(_top): _top.queue_free()
	super()

func tick(_dt: float) -> void:
	var dt := world_dt()
	var p := painter()
	if _top == null:
		_top = PixelPainter.new()
		_top.setup_painter(p.px)
		_top.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		rm._layers.top.add_child(_top)
	if active and state.tracing:
		var x := clampf(behavior.ctx.loadout.boost_distance / cfg.draw_length, 0.0, 1.0)
		var ex := (exp(3.0 * x) - 1.0) / (exp(3.0) - 1.0)
		_acc += dt * (40.0 + 600.0 * ex) * visual_number("particle_count_scale", 1.0)
		while _acc >= 1.0:
			_acc -= 1.0
			var a := PI + (randf() - 0.5) * (0.9 + 0.8 * ex)
			var nose := randf() < 0.55
			flames.append({
				"along": 9.0 if nose else 2.0 - randf() * 6.0,
				"side": (randf() - 0.5) * 2.0 if nose else (randf() - 0.5) * (5.0 + 10.0 * ex),
				# 試作は機体が毎秒213ドットで進み、粒は世界で毎秒215ドット後ろへ流れる。機体に対しては毎秒428ドット後ろへ。
				"va": cos(a) * (60.0 + 160.0 * ex) - 428.0,
				"vs": (randf() - 0.5) * 2.0 * (30.0 + 70.0 * ex) if nose else sin(a) * (40.0 + 90.0 * ex),
				"age": 0.0, "life": 0.1 + 0.24 * ex * randf() + 0.06,
				"size": 2 if randf() < 0.35 + 0.4 * ex else 1, "top": nose and randf() < 0.6})
	p.begin()
	_top.begin()
	var u := state.ship_heading
	var n := u.orthogonal()
	for f in flames:
		f.age += dt
		f.along += f.va * dt
		f.side += f.vs * dt
		var k: float = f.age / f.life
		if k >= 1.0: continue
		var cell := p.cell(state.ship_pos + u * f.along * p.px + n * f.side * p.px)
		if k > 0.7 and (int(cell.x) + int(cell.y)) % 2 != 0: continue
		var z := maxi(1, roundi(f.size * (1.0 - 0.5 * k)))
		(_top if f.top else p).fill(cell.x - z / 2.0, cell.y - z / 2.0, COLORS[mini(5, floori(k * 6.0))], z, z)
	flames = flames.filter(func(f): return f.age < f.life)
	p.end()
	_top.end()
