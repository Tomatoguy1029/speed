extends WeaponVisual
## 閃光斬：ブースト中に当てた敵へ、何もない空間から光の針が一定の速さで飛んできて刺さる（飛んでいる間は見えず、
## 刺さる直前に針と後ろの細い光の線が現れる）。ブーストが終わると針が光って脈打ち、線の始点から終点へ両端の尖った
## 光の筋（白い芯・紫）が順に出る。光は足し合わせて描く。

const FLY := 0.06
const FAR := 170.0
var needles: Dictionary = {}
var streaks: Array[Dictionary] = []
var _released := -1.0
var _add: PixelPainter
var _streaks: PixelShapes

func dispose() -> void:
	if is_instance_valid(_add): _add.queue_free()
	if is_instance_valid(_streaks): _streaks.queue_free()
	super()

func on_event(ev: Dictionary) -> void:
	match ev.type:
		&"slash_mark":
			needles[ev.id] = {"row": ev.row, "angle": float(ev.angle), "r": float(ev.radius), "age": 0.0}
		&"slash_release":
			_released = 0.0
			var path: Array = Array(ev.path)
			if path.size() < 2: return
			for i in int(ev.count):
				var f := randf()
				var index := mini(path.size() - 2, floori(f * (path.size() - 1)))
				var dir: Vector2 = (path[index + 1] - path[index]).normalized()
				var at: Vector2 = path[index].lerp(path[index + 1], fmod(f * (path.size() - 1), 1.0))
				var off := (randf() - 0.5) * (24.0 if randf() < 0.7 else 80.0)
				streaks.append({"pos": at + dir.orthogonal() * off * 1.82 * cfg.character_scale,
					"angle": dir.angle() + (randf() - 0.5) * (0.7 if randf() < 0.6 else 2.6),
					"len": 30.0 + randf() * (180.0 if randf() < 0.25 else 80.0), "w": 1.4 + randf() * 2.2,
					"age": -float(ev.pause) - f * float(ev.sweep)})
		&"flash_slash":
			streaks.append({"pos": ev.pos, "angle": float(ev.angle), "len": 120.0 + randf() * 60.0, "w": float(ev.width), "age": 0.0})
			needles.erase(ev.get("id", -1))
		&"kill":
			needles.erase(ev.get("id", -1))

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
		_streaks = PixelShapes.new()
		_streaks.setup(p.px, PixelShapes.Shape.SPINDLE)
		rm._layers.top.add_child(_streaks)
	_add.begin()
	_streaks.begin()
	if _released >= 0.0: _released += dt
	var t: EnemyTable = behavior.ctx.enemies.table
	for id in needles.keys():
		var nd: Dictionary = needles[id]
		if not behavior.ctx.enemies.is_same(nd.row, id) or t.dead[nd.row] != 0:
			needles.erase(id)
			continue
		nd.age += dt
		_needle(_add, t.pos[nd.row], nd)
	for s in streaks:
		s.age += dt
		var k: float = s.age / 0.7
		if k < 0.0 or k >= 1.0: continue
		_streaks.add_spindle(s.pos, s.angle, s.len, s.w * (1.0 - k * 0.5), 1.0 if k < 0.25 else 1.0 - (k - 0.25) / 0.75)
	streaks = streaks.filter(func(s): return s.age < 0.7)
	if needles.is_empty() and streaks.is_empty(): _released = -1.0
	_add.end()
	_streaks.end()

func _needle(p: PixelPainter, enemy: Vector2, nd: Dictionary) -> void:
	var r: float = nd.r / p.px * 0.55
	var k := minf(1.0, nd.age / FLY)
	var u := Vector2.from_angle(nd.angle)
	var pulse := 0.6 + 0.4 * sin(_released * 30.0) if _released >= 0.0 else 0.0
	var at := enemy + u * (r * 0.6 + FAR * (1.0 - k)) * p.px
	var ts: float = (nd.age - FLY) / 0.08
	var appear := clampf((k - 0.6) / 0.4, 0.0, 1.0) if k < 1.0 else maxf(0.0, 1.0 - ts)
	if appear > 0.0:
		var tail := 60.0 if k < 1.0 else 60.0 * (1.0 - ts)
		var width := roundi(2.2 * appear + 0.4)
		p.line(at + u * tail * p.px, at, Color(200.0 / 255.0, 160.0 / 255.0, 1.0, 0.55 * appear), maxi(1, width))
		p.line(at + u * tail * p.px, at, Color(1, 1, 1, 0.7 * appear))
	var length := r * 3.2 * (1.0 + 0.25 * pulse)
	_streaks.add_spindle(at, nd.angle, length, 1.6 + 1.2 * pulse, (0.85 + 0.15 * pulse) * (appear if k < 1.0 else 1.0))
