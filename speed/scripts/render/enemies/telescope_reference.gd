## ぼうえんきょう座の照射と、照射後に残る細い光。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const LIGHT := preload("res://scripts/render/enemies/telescope_light.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-telescope")
var _beams := {}
var _last_time := -1.0
var _parent: Node2D
var _cones := {}
var _ship_glows := {}

func setup(parent: Node2D) -> void:
	_parent = parent

func render(actors: Array, beams: Array, events: Array, canvas, clock: float) -> void:
	if _last_time >= 0.0 and clock < _last_time: _beams.clear()
	_last_time = clock
	var color := Color(_settings.color)
	var intensity := float(_settings.intensity)
	var timing := float(_settings.timing)
	for node in _cones.values(): node.hide()
	for node in _ship_glows.values(): node.hide()
	var visible_ids := {}
	for actor: Dictionary in actors:
		visible_ids[int(actor.id)] = true
		_draw_actor(actor, canvas, clock)
	for nodes in [_cones, _ship_glows]:
		for id in nodes.keys():
			if not visible_ids.has(id):
				nodes[id].queue_free()
				nodes.erase(id)
	var present := {}
	for row: Dictionary in beams:
		var id := int(row.order)
		present[id] = true
		_beams[id] = {"row": row, "clock": clock}
		var t := float(row.time) - float(row.delay)
		if t < 0: continue
		var active := float(row.active)
		var remaining := active - t
		var fade := (1.0 - clampf(t / active, 0.0, 1.0) * 0.6) * _smooth(0.0, minf(0.08, active), remaining)
		var head := minf(1.0, _smooth(0.0, 0.06 * timing, t)) * 0.999 + 0.001
		var direction := Vector2.from_angle(float(row.angle))
		var origin: Vector2 = canvas.to_logical(row.pos)
		var end: Vector2 = canvas.to_logical(row.pos + direction * float(row.length))
		FX.beam(canvas.front, origin, end, {"color": color, "w": float(row.half_width) * canvas.world_scale, "time": clock, "alpha": minf(1.0, fade * 1.3 * intensity), "to": head, "taper": 10.0 * float(_settings.size)})
		if t < 0.08: FX.flare(canvas.front, origin, 16.0 * float(_settings.size) * canvas.world_scale, color, clock, 1.0 - t / 0.08, 6)
	for event: Dictionary in events:
		if event.get("type") != &"attack_retired": continue
		var id := int(event.id)
		if not _beams.has(id): continue
		if event.reason != "lifetime":
			_beams.erase(id)
			continue
		var saved: Dictionary = _beams[id]
		var row: Dictionary = saved.row
		saved.end_time = float(saved.clock) - float(row.time) + float(row.delay) + float(row.active)
	for id in _beams.keys():
		if present.has(id): continue
		var saved: Dictionary = _beams[id]
		if not saved.has("end_time"): continue
		var elapsed := clock - float(saved.end_time)
		var duration := 0.3 * timing
		if elapsed >= duration:
			_beams.erase(id)
		elif elapsed > 0.0:
			var row: Dictionary = saved.row
			var origin: Vector2 = canvas.to_logical(row.pos)
			var end: Vector2 = canvas.to_logical(row.pos + Vector2.from_angle(float(row.angle)) * float(row.length))
			FX.warn_rail(canvas.back, origin, end, {"color": color, "k": 0.2, "time": clock, "seed": 6, "rail": 1, "intensity": (1.0 - elapsed / duration) * intensity})
			FX.sparks(canvas.front, origin, elapsed, 9, 8, color, 35, 0.3, float(row.angle), 0.6)

func _draw_actor(row: Dictionary, canvas, clock: float) -> void:
	var id := int(row.id)
	var angle := float(row.angle)
	var k := float(row.charge)
	var lens: Vector2 = row.pos + Vector2.from_angle(angle) * float(row.radius) * 0.9
	var logical: Vector2 = canvas.to_logical(lens)
	var length := float(row.length)
	var half := float(row.half)
	var intensity := float(_settings.intensity)
	var windup := bool(row.windup)
	var color := Color(lerpf(0.62, 1.0, k), lerpf(0.9, 0.22, k), lerpf(1.0, 0.2, k))
	var strength := (0.16 + 0.22 * k + (0.08 if bool(row.seen) else 0.0)) * intensity
	var progress := 0.0
	if windup:
		progress = 1.0 - clampf(float(row.timer) / float(row.laser_charge), 0.0, 1.0)
		var shrink := 1.0 - _smooth(0.0, 0.45, progress)
		half = float(row.band_narrow) * shrink
		strength = 0.38 * shrink * intensity
		color = Color(1.0, 0.22, 0.2)
	if half > 0.002:
		var pts := PackedVector2Array([lens])
		var uv := PackedVector2Array([Vector2(0.5, 0.5)])
		var rays: PackedFloat32Array = row.rays
		var base_half := float(row.half)
		for i in range(48):
			var a := angle - half + 2.0 * half * i / 47.0
			var offset := clampf((a - angle + base_half) / (2.0 * base_half) * 47.0, 0.0, 47.0)
			var index := mini(floori(offset), 46)
			var reach := lerpf(rays[index], rays[index+1], offset-index)
			var v := Vector2.from_angle(a) * reach
			pts.append(lens + v)
			uv.append(Vector2(0.5, 0.5) + v / (2.0 * length))
		var cone = _light(_cones, id, false)
		cone.set_shape(pts, uv, color, strength, angle, half)
		if not windup and bool(row.seen):
			var at: Vector2 = row.ship_pos
			var quad := PackedVector2Array([at + Vector2(-70,-70), at + Vector2(70,-70), at + Vector2(70,70), at + Vector2(-70,70)])
			var quad_uv := PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)])
			_light(_ship_glows, id, true).set_shape(quad, quad_uv, color, strength * 0.9)
		_dust(row, lens, angle, half, color, clock, canvas)
	if windup:
		var rays: PackedFloat32Array = row.rays
		var reach := lerpf(rays[23], rays[24], 0.5)
		var end: Vector2 = canvas.to_logical(lens + Vector2.from_angle(angle) * reach)
		var pulse := 0.5 + 0.5 * sin(clock * (30.0 + 40.0 * progress))
		FX.warn_rail(canvas.back, logical, end, {"color": Color(_settings.color), "k": (0.3 + 0.7 * progress) * (0.75 + 0.25 * pulse), "time": clock, "seed": 2, "intensity": intensity, "maxLv": 3})
		FX.gather(canvas.front, logical, float(row.radius) * 2.4 * float(_settings.size) * canvas.world_scale, (0.4 + 0.6 * progress) * intensity, Color(_settings.color), clock, 16, 8)
	else:
		var palette := FX.ramp(Color8(roundi(color.r*255), roundi(color.g*255), roundi(color.b*255)))
		canvas.front.px(logical.x, logical.y, palette[4])
		canvas.front.glow(logical.x, logical.y, 3 + 4 * k * float(_settings.size), palette[4], 0.6)
		canvas.front.glow(logical.x, logical.y, 8 + 10 * k, palette[2], 0.5)

func _light(nodes: Dictionary, id: int, glow: bool):
	if not nodes.has(id):
		var node = LIGHT.new()
		node.setup(glow)
		_parent.add_child(node)
		nodes[id] = node
	return nodes[id]

func _dust(row: Dictionary, lens: Vector2, angle: float, half: float, color: Color, clock: float, canvas) -> void:
	var palette := FX.ramp(Color8(roundi(color.r*255), roundi(color.g*255), roundi(color.b*255)))
	var origin: Vector2 = canvas.to_logical(lens)
	var length := float(row.length)
	var base_half := float(row.half)
	var rays: PackedFloat32Array = row.rays
	for i in range(46):
		var d := fposmod(FX.hash_value(i) + clock * 0.06 * (0.5 + FX.hash_value(i+3)), 1.0) * length
		var a := angle + (FX.hash_value(i*7) - 0.5) * 2.0 * half * 0.9
		var offset := clampf((a-angle+base_half)/(2.0*base_half)*47.0, 0.0, 47.0)
		var index := mini(floori(offset), 46)
		if d > lerpf(rays[index], rays[index+1], offset-index): continue
		var tw := 0.5 + 0.5 * sin(clock * (2.0 + FX.hash_value(i)*3.0) + i)
		canvas.back.dot(origin.x + cos(a) * d * canvas.world_scale, origin.y + sin(a) * d * canvas.world_scale, palette[3], 0.6 * tw * (1.0 - d/length))

func _smooth(a: float, b: float, value: float) -> float:
	var k := clampf((value - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)
