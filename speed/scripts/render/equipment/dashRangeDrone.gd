extends WeaponVisual
## エスコートウィング：今の編隊と光跡。展開の瞬間に機体から各機へ光が走って十字に光り、貫いた敵に短い斬り筋と光片。

var deploys: Array[Dictionary] = []
var slashes: Array[Dictionary] = []
var sparks := PixelSparks.new()
var _frame_node: Node2D
func setup_frame(parent: Node2D, effects: Node2D, pixel: float) -> void:
	_frame_node = preload("res://scripts/render/dash_range_drone.gd").new()
	parent.add_child(_frame_node)
	_painter = PixelPainter.new()
	_painter.setup_painter(pixel)
	effects.add_child(_painter)
func frame_tick(values: Dictionary, scale_value: float, zoom: float, ship: Dictionary, tracing: bool, dt: float) -> void:
	_frame_node.step_frame(values,scale_value,zoom,ship,tracing,dt)
	_draw_effects(_painter,dt)
func dispose() -> void:
	if is_instance_valid(_frame_node): _frame_node.queue_free()
	super()


func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	attach("res://scripts/render/dash_range_drone.gd", "DashRangeDrone", 0)

func on_event(ev: Dictionary) -> void:
	match ev.type:
		&"escort_deploy":
			for target in ev.targets: deploys.append({"from": ev.pos, "to": target, "age": 0.0})
		&"escort_slash":
			slashes.append({"pos": ev.pos, "dir": ev.dir, "age": 0.0})
			var side := 1.0 if randf() < 0.5 else -1.0
			sparks.add(ev.pos, 5, ev.dir.angle() + PI * 0.5 * side, 1.4, 25.0, 70.0, 0.2, [Color.WHITE, Color("#7ff3ff"), Color("#3fd0e8")])

func tick(_dt: float) -> void:
	var dt := world_dt()
	node.step(behavior if active else null, cfg, rm.cam_zoom, state, dt)
	_draw_effects(painter(),dt)

func _draw_effects(p: PixelPainter, dt: float) -> void:
	p.begin()
	for d in deploys:
		d.age += dt
		var q: float = d.age / 0.12
		if q >= 1.0: continue
		var white := Color(1, 1, 1, 1.0 - q)
		p.line(d.from, d.to, Color(1, 1, 1, 1.0 - q) if q < 0.4 else Color(Color("#7ff3ff"), 1.0 - q))
		var c := p.cell(d.to)
		var l := 3 if q < 0.5 else 2
		p.fill(c.x - l, c.y, white, l * 2 + 1, 1)
		p.fill(c.x, c.y - l, white, 1, l * 2 + 1)
	deploys = deploys.filter(func(d): return d.age < 0.12)
	for s in slashes:
		s.age += dt
		var q: float = s.age / 0.16
		if q >= 1.0: continue
		var length := roundf(5.0 + 4.0 * q)
		var u: Vector2 = s.dir.normalized()
		var n := u.orthogonal()
		for k in range(-int(length) - 2, int(length) + 3):
			var at: Vector2 = s.pos + u * k * p.px
			if absf(k) <= length:
				p.dot(at + n * p.px, Color(Color("#7ff3ff"), 1.0 - q))
				p.dot(at - n * p.px, Color(Color("#7ff3ff"), 1.0 - q))
			p.dot(at, Color(1, 1, 1, 1.0 - q))
	slashes = slashes.filter(func(s): return s.age < 0.16)
	sparks.draw(p, dt)
	p.end()
