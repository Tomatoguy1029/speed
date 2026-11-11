## みなみのかんむり座の渦と、選ばれた個体へ流れる光。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const WHITE := preload("res://shaders/cepheus_summon_white.gdshader")
const JET := preload("res://scripts/render/enemies/aquarius_jet.gd")
const EDGES := preload("res://assets/effects/reference/edges.tres")
var _settings: Dictionary = SETTINGS.for_id("G12-corona")
var _parent: Node2D
var _scope: ContentResourceScope
var _visuals: Dictionary
var _flashes := {}
var _bodies := {}
var _impacts: Array[Dictionary] = []
var _last_clock := -1.0
var _noise = JET.new()
var _raster := SpeedFxRaster.new()
var _edges: Dictionary = EDGES.get_meta("edges")

func setup(parent: Node2D, scope: ContentResourceScope, visuals: Dictionary) -> void:
	_parent = parent
	_scope = scope
	_visuals = visuals

func render(owners: PackedFloat64Array, selected: Array, thrown: Array, events: Array, canvas, clock: float) -> void:
	if _last_clock>=0.0 and clock<_last_clock: _impacts.clear()
	_last_clock = clock
	for event: Dictionary in events:
		# RetireReason::CoronaThrowEnd。通常の退却や撃破には使わない。
		if event.get("type") == &"enemy_retire" and int(event.get("reason",-1))==6:
			_impacts.append({"pos":event.pos,"id":int(event.id),"time":float(event.get("world_t",clock))})
	for impact: Dictionary in _impacts.duplicate():
		var age := clock-float(impact.time)
		if age>=0.35: _impacts.erase(impact)
		elif age>=0.0: FX.sparks(canvas.front,canvas.to_logical(impact.pos),age,40+int(impact.id),10,Color(_settings.color),40,0.35)
	_draw_vortices(owners, canvas)
	var present := {}
	var palette := FX.ramp(Color(_settings.color))
	for row: Dictionary in selected:
		var id := int(row.id)
		present[id] = true
		var k := float(row.charge)
		var a: Vector2 = canvas.to_logical(row["from"])
		var b: Vector2 = canvas.to_logical(row.pos)
		_raster.begin_painter(canvas.front, float(canvas.world_scale), canvas._camera_position, true, true)
		_raster.corona_selection(a, b, k, float(row.radius) * canvas.world_scale * 1.4, float(_settings.intensity), PackedColorArray(palette), clock)
		_finish_raster(canvas.front)
		_flash(row,k*(0.35+0.35*sin(clock*30.0)))
	for id in _flashes.keys():
		if not present.has(id):
			_flashes[id].queue_free()
			_flashes.erase(id)
	var flying := {}
	for row: Dictionary in thrown:
		flying[int(row.id)] = true
		_draw_thrown(row,canvas,clock)
	for id in _bodies.keys():
		if not flying.has(id):
			_bodies[id].queue_free()
			_bodies.erase(id)

func _draw_vortices(owners: PackedFloat64Array, canvas) -> void:
	if owners.is_empty(): return
	_raster.begin_painter(canvas.back, float(canvas.world_scale), canvas._camera_position, true, false)
	_raster.corona_vortices(owners, PackedColorArray(FX.ramp(Color("b6a2db"))))
	canvas.back.colors = _raster.take_colors()
	canvas.back.has_color = canvas.back.has_color or _raster.has_color()

func _finish_raster(painter) -> void:
	painter.colors = _raster.take_colors()
	painter.lights = _raster.take_lights()
	painter.has_color = painter.has_color or _raster.has_color()
	painter.has_light = painter.has_light or _raster.has_light()

func _draw_thrown(row: Dictionary, canvas, clock: float) -> void:
	var velocity: Vector2 = row.velocity
	if velocity.length_squared() <= 0.000001: return
	var direction := velocity.normalized()
	var age := float(row.age)
	var fade := 1.0
	var center: Vector2 = canvas.to_logical(row.pos)
	var trail: float = minf(age*velocity.length(),260.0)*canvas.world_scale
	var colors: Array[Color] = [Color("2a0a0a"),Color("5a1414"),Color(_settings.color),Color("ff7a2e"),Color("ffb347"),Color("ffd77a"),Color("fff1b0"),Color.WHITE]
	_raster.begin_painter(canvas.front, float(canvas.world_scale), canvas._camera_position, true, true)
	_raster.corona_trail(center, direction, trail, age, clock, float(row.seed_angle), PackedColorArray(colors))
	_finish_raster(canvas.front)
	_draw_body(row,fade,canvas,clock,direction,center,colors)
	canvas.front.glow(center.x,center.y,float(row.radius)*canvas.world_scale*2.0,colors[4],0.5*fade*float(_settings.intensity))

func _draw_body(row: Dictionary, fade: float, canvas, clock: float, direction: Vector2, _center: Vector2, colors: Array[Color]) -> void:
	if bool(row.polygon): return
	var visual_id := int(row.visual_id)
	if not _visuals.has(visual_id): return
	var entry: Dictionary = _visuals[visual_id]
	var look := _scope.resources.get(entry.path) as EnemyLook
	var preview: String = entry.get("hull_preview", "")
	if look == null or not look.previews.has(preview): return
	var texture := look.previews[preview] as Texture2D
	if texture == null: return
	var id := int(row.id)
	if not _bodies.has(id):
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 0
		_parent.add_child(sprite)
		_bodies[id] = sprite
	var sprite: Sprite2D = _bodies[id]
	var angle := look.angle if look.fixed_angle else float(row.angle)+look.angle
	sprite.texture = texture
	sprite.position = row.pos
	sprite.rotation = angle
	sprite.scale = Vector2.ONE*(2.0*float(row.sprite_radius)/maxf(texture.get_width(),texture.get_height()))
	sprite.modulate = Color(1,1,1,fade)
	if not _edges.has(look.source_path): return
	var edge: Dictionary = _edges[look.source_path]
	var points: PackedVector2Array = edge.points
	if points.is_empty(): return
	var dimensions: Vector2i = edge.size
	var scale := 2.0*float(row.sprite_radius)/maxi(dimensions.x,dimensions.y)
	var frame := floori(clock*30.0)
	for i in range(26):
		var r = JET.Rng.new(i*17+frame*3+1)
		var point: Vector2 = canvas.to_logical(row.pos + points[mini(points.size()-1,floori(r.next()*points.size()))].rotated(angle)*scale)
		var length: float = r.between(2,6)
		var k: float = r.next()
		var end := point-direction*length+Vector2(r.between(-1,1),r.between(-1,1))
		canvas.front.line(point.x,point.y,end.x,end.y,func(u: float): return colors[7] if u<0.3 else (colors[5] if u<0.6 else colors[3]),fade*(0.6+0.4*k))

func _flash(row: Dictionary, alpha: float) -> void:
	var visual_id := int(row.visual_id)
	if not _visuals.has(visual_id): return
	var entry: Dictionary = _visuals[visual_id]
	var look := _scope.resources.get(entry.path) as EnemyLook
	var preview: String = entry.get("hull_preview", "")
	if look == null or not look.previews.has(preview): return
	var texture := look.previews[preview] as Texture2D
	if texture == null: return
	var id := int(row.id)
	if not _flashes.has(id):
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = WHITE
		sprite.material = mat
		sprite.z_index = 0
		_parent.add_child(sprite)
		_flashes[id] = sprite
	var sprite: Sprite2D = _flashes[id]
	sprite.texture = texture
	sprite.position = row.pos
	sprite.rotation = look.angle if look.fixed_angle else float(row.angle)+look.angle
	sprite.scale = Vector2.ONE*(2.0*float(row.sprite_radius)/maxf(texture.get_width(),texture.get_height()))
	sprite.modulate = Color(1,1,1,alpha)
