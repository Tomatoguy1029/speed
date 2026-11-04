## みずがめ座の集光と6本の水流。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const JET := preload("res://scripts/render/enemies/aquarius_jet.gd")
const WATER := preload("res://scripts/render/enemies/aquarius_water.gd")
const STREAM := preload("res://scripts/render/enemies/aquarius_stream.gd")
var _settings: Dictionary = SETTINGS.for_id("G12-aquarius")
var _jet = JET.new()
var _parent: Node2D
var _noise: Texture2D
var _waters := {}
var _streams := {}
var _tails := {}
var _last_time := -1.0
var _epoch := -1
var _sequence := 0

func setup(parent: Node2D, scope: ContentResourceScope) -> void:
	_parent = parent
	_noise = scope.resources.get("res://assets/fx/water_noise.png") as Texture2D

func render(rows: Array, events: Array, canvas, clock: float) -> void:
	if _last_time >= 0.0 and clock < _last_time:
		_tails.clear()
		_sequence = 0
	_last_time = clock
	var color := Color(_settings.color)
	var intensity := float(_settings.intensity)
	var timing := float(_settings.timing)
	var pixel_size := _parent.get_viewport().get_visible_rect().size.y / 225.0
	var visible := {}
	for node in _waters.values(): node.hide()
	for node in _streams.values(): node.hide()
	for row: Dictionary in rows:
		var time := float(row.time)
		var delay := float(row.delay)
		var index := int(row.index)
		var id := int(row.order)
		var origin: Vector2 = row.pos
		var point: Vector2 = canvas.to_logical(origin)
		if time < delay:
			visible[id] = true
			_water(id).update(row,canvas,clock,color,pixel_size,minf(1.0,intensity),false)
			if index == 0:
				var k := clampf(time/delay, 0.0, 1.0)
				FX.gather(canvas.front, point, float(row.radius)*1.2*float(_settings.size)*canvas.world_scale, k*intensity, color, clock, 14, 4)
		elif time < delay + float(row.active):
			visible[id] = true
			_stream(id).update(row,canvas,clock,color,pixel_size,minf(1.0,intensity))
			_jet.draw_particles(canvas, origin, float(row.angle), float(row.length), float(row.half_width), tan(float(row.spread)), clock, 7+index*13, color, minf(1.0,intensity))
			if index == 0 and time-delay < 0.2:
				var palette: Array[Color] = _jet._ramp(color)
				canvas.front.glow(point.x,point.y,float(row.radius)*canvas.world_scale*3.0,palette[6],0.8*(1.0-(time-delay)/0.2)*intensity)
	for event: Dictionary in events:
		if event.get("type") != &"flood_end" or not bool(event.get("reference_aquarius", false)): continue
		var epoch := int(event.get("epoch",0))
		if epoch != _epoch:
			_epoch = epoch
			_sequence = 0
			_tails.clear()
		var sequence := int(event.get("sequence",0))
		if sequence > 0 and sequence <= _sequence: continue
		_sequence = sequence
		var row := {"pos":event.pos,"angle":event.angle,"length":event.length,"half_width":float(event.width)*0.5,"spread":event.spread,"index":event.index}
		_tails[int(event.id)] = {"row":row,"time":float(event.get("world_t",clock)),"age":float(event.age)}
	for id in _tails.keys():
		var tail: Dictionary = _tails[id]
		var age := maxf(0.0,clock-float(tail.time)+float(tail.age))
		if age >= 1.4*timing:
			_tails.erase(id)
		else:
			visible[id] = true
			_water(id).update(tail.row,canvas,clock,color,pixel_size,minf(1.0,intensity),true,age,timing)
	for id in _waters.keys():
		if not visible.has(id):
			_waters[id].queue_free()
			_waters.erase(id)

	for id in _streams.keys():
		if not visible.has(id) or not _streams[id].visible:
			_streams[id].queue_free()
			_streams.erase(id)

func _stream(id: int):
	if not _streams.has(id):
		var node = STREAM.new()
		_parent.add_child(node)
		_streams[id] = node
	return _streams[id]

func _water(id: int):
	if not _waters.has(id):
		var node = WATER.new()
		node.setup(_noise)
		_parent.add_child(node)
		_waters[id] = node
	return _waters[id]
