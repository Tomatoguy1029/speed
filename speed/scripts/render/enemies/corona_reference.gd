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
var _raster := SpeedFxRaster.new()
var _noise = JET.new()
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
	if not owners.is_empty():
		_raster.begin(canvas.back.colors, PackedByteArray(), canvas.back.width, canvas.back.height, canvas.world_scale, canvas._camera_position)
		var flags := _raster.corona_vortex(owners, PackedColorArray(FX.ramp(Color("b6a2db"))), canvas.back.fade)
		canvas.back.colors = _raster.take_colors()
		canvas.back.has_color = canvas.back.has_color or (flags & 1) != 0
	var present := {}
	var palette := FX.ramp(Color(_settings.color))
	for row: Dictionary in selected:
		var id := int(row.id)
		present[id] = true
		var k := float(row.charge)
		var a: Vector2 = canvas.to_logical(row["from"])
		var b: Vector2 = canvas.to_logical(row.pos)
		var delta := b-a
		var normal := Vector2(-delta.y,delta.x)/maxf(delta.length(),0.000001)
		for i in range(14):
			var f := fposmod(FX.hash_value(i*3.1)+clock*2.6,1.0)
			var wave := (FX.hash_value(i*7.7)-0.5)*10.0*sin(PI*f)
			var point := a+delta*f+normal*wave
			canvas.front.dot(point.x,point.y,palette[4] if f>0.7 else palette[3],k*(0.4+0.6*f))
		canvas.front.glow(b.x,b.y,float(row.radius)*canvas.world_scale*1.4,palette[2],0.4*k*float(_settings.intensity))
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

func _draw_thrown(row: Dictionary, canvas, clock: float) -> void:
	var velocity: Vector2 = row.velocity
	if velocity.length_squared() <= 0.000001: return
	var direction := velocity.normalized()
	var normal := Vector2(-direction.y,direction.x)
	var age := float(row.age)
	var fade := 1.0
	var center: Vector2 = canvas.to_logical(row.pos)
	var trail: float = minf(age*velocity.length(),260.0)*canvas.world_scale
	var frame := floori(clock*30.0)
	var colors: Array[Color] = [Color("2a0a0a"),Color("5a1414"),Color(_settings.color),Color("ff7a2e"),Color("ffb347"),Color("ffd77a"),Color("fff1b0"),Color.WHITE]
	var d := 0.0
	while d <= trail:
		var q := d/maxf(trail,1.0)
		var heat: float = 1.0-pow(d/maxf(trail,1.0),0.8)+_noise._noise(d*0.12-clock*40.0,3,int(float(row.seed_angle)*9))*0.12
		var width := (0.6+2.6*pow(1.0-minf(1.0,q/0.35),1.4))*(1.0 if q<0.35 else 0.5)
		var point := center-direction*d
		if q <= 0.55 or FX.hash_value(floorf(d/3.0)*7.1+frame) >= (q-0.55)*1.6:
			var w := -width
			while w <= width:
				var edge := absf(w)/maxf(width,0.01)
				var color: Color
				if edge < 0.38:
					color = colors[7] if heat>0.8 else (colors[6] if heat>0.6 else (colors[4] if heat>0.42 else (colors[3] if heat>0.25 else colors[2])))
				else:
					color = colors[5] if heat>0.6 else (colors[3] if heat>0.35 else colors[2])
				var at := point+normal*w
				canvas.front.dot(at.x,at.y,color,fade*(1.0 if q<0.85 else (1.0-q)/0.15))
				w += 0.5
		d += 0.5
	var end := center-direction*trail*0.45
	canvas.front.glow_line(center.x,center.y,end.x,end.y,6,colors[4],0.35*fade)
	end = center-direction*trail*0.2
	canvas.front.glow_line(center.x,center.y,end.x,end.y,3,colors[7],0.3*fade)
	var seed := int(23.0+float(row.seed_angle)*10.0)
	for i in range(16):
		var g = JET.Rng.new(_noise._hash([seed,i,911]))
		var born: float = g.next()*0.4
		var lifetime: float = g.between(0.1,0.28)
		var elapsed := fposmod(age-born,0.4)
		while elapsed < lifetime:
			var r = JET.Rng.new(_noise._hash([seed,i]))
			var k := elapsed/lifetime
			var back: float = r.between(4,trail*0.5)
			var side: float = r.between(-1,1)*30.0*elapsed
			var point: Vector2 = center-direction*(back+40.0*elapsed*canvas.world_scale)+normal*side
			var start := point+direction*2.0
			canvas.front.line(start.x,start.y,point.x,point.y,func(u: float): return colors[7] if u>0.5 else colors[4],(1.0-k)*fade)
			elapsed += 0.4
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
