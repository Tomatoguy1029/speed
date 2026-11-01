## RenderFrameの値だけを描画へ渡す。敵表や武器の実体は参照しない。
extends Node2D
const EFFECT_SETTINGS = preload("res://data/visuals/effect_settings.tres")
var visuals: Dictionary = {}
var batches: Dictionary = {}
var parts: Dictionary = {}
var enemy_frames: Dictionary = {}
var _layers: Dictionary = {}
var _lines: Array[Line2D] = []
var _scope: ContentResourceScope
var _pixel := 1.82
var _effects: PixelPainter
var _flashes := ShotFlashes.new()
var _queued_events: Array[Dictionary] = []
var _epoch := 0
var _jet_time := 0.0
var pipeline: RenderPipeline
var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _meteor_shards: Array[Dictionary] = []
var _zoom := 1.0
var _particle_canvas: Node2D
var _dim: Node2D
var _dim_strength := 0.0
var _dim_rect := Rect2()

var _flame: Sprite2D
var _spark: Sprite2D
var build_us := 0
var submit_us := 0

func setup(scope: ContentResourceScope, entries: Array[Dictionary], character_scale: float) -> void:
	_scope = scope
	_pixel = 1.82*character_scale
	for entry in entries: visuals[int(entry.id)] = entry
	_effects = PixelPainter.new()
	_effects.setup_painter(_pixel)
	_layer(14).add_child(_effects)
	_particle_canvas = Node2D.new()
	_layer(14).add_child(_particle_canvas)
	_particle_canvas.draw.connect(func():
		for ring: Dictionary in _rings:
			var k: float = ring.life/ring.max
			var color: Color = EFFECT_SETTINGS.tinted("",ring.color)
			color.a *= k
			_particle_canvas.draw_arc(ring.pos,ring.radius*(1.0+(1.0-k)*0.15),0.0,TAU,48,color,3.0*EFFECT_SETTINGS.number("","ring_width_scale",1.0)/maxf(_zoom,0.01))
		for p: Dictionary in _particles:
			var color: Color = p.color
			color.a = clampf(p.life/p.max,0.0,1.0)
			_particle_canvas.draw_circle(p.pos,maxf(1.0,roundf(p.size*0.6))*_pixel,color)
		for shard: Dictionary in _meteor_shards:
			_particle_canvas.draw_set_transform(shard.pos,shard.angle)
			_particle_canvas.draw_texture(shard.texture,-shard.texture.get_size()*0.5,Color(1,1,1,shard.life/0.65))
		_particle_canvas.draw_set_transform(Vector2.ZERO))
	_dim = Node2D.new()
	_layer(16).add_child(_dim)
	_dim.draw.connect(func():
		if _dim_strength>0.0: _dim.draw_rect(_dim_rect.grow(400.0),Color(0,0,0,_dim_strength)))
	_flame = _exhaust("res://assets/pixel/airship_flame.png",character_scale)
	_spark = _exhaust("res://assets/pixel/airship_spark.png",character_scale)
	_spark.modulate.a = 0.65

func _layer(layer: int) -> Node2D:
	if not _layers.has(layer):
		var node := Node2D.new()
		node.z_index = layer
		add_child(node)
		_layers[layer] = node
	return _layers[layer]

func _exhaust(path: String, factor: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _scope.resources.get(path)
	sprite.hframes = 3
	sprite.offset = Vector2(0.0,sprite.texture.get_height()*0.5-30.0)
	sprite.scale = Vector2.ONE*factor
	_layer(4).add_child(sprite)
	return sprite

func _batch(id: int, layer: int) -> InstanceBatch:
	if batches.has(id): return batches[id]
	var entry: Dictionary = visuals[id]
	var batch: InstanceBatch
	if entry.role==2:
		batch = PixelPainter.new()
		(batch as PixelPainter).setup_painter(_pixel)
	else:
		batch = InstanceBatch.new()
		if entry.role==4: batch.setup_polygon(InstanceBatch.circle_points(24))
		else:
			batch.setup_texture(_scope.resources.get(entry.path) as Texture2D,entry.get("rect",Rect2()))
			var material := ShaderMaterial.new()
			material.shader = load("res://shaders/xp_crystal.gdshader" if entry.role==3 else "res://shaders/pixel_sprite.gdshader")
			batch.material = material
	_layer(layer).add_child(batch)
	batches[id] = batch
	return batch

func _valid(frame: Dictionary) -> bool:
	if frame.get("schema_version")!=1 or not frame.get("batches") is Array or not frame.get("shapes") is Array or not frame.get("poses") is Array: return false
	for row in frame.batches:
		if not row is Dictionary or not visuals.has(row.get("visual_id")) or not row.get("ids") is PackedInt64Array or not row.get("transforms") is PackedFloat32Array or not row.get("colors") is PackedColorArray or not row.get("flags") is PackedInt32Array: return false
		var count: int = row.ids.size()
		if row.transforms.size()!=count*6 or row.colors.size()!=count or row.flags.size()!=count: return false
		if visuals[row.visual_id].role==6 and visuals[row.visual_id].get("biting",false):
			if not row.get("biter") is Dictionary: return false
			for key in ["modes","charges","timers","rests"]:
				if not row.biter.has(key) or row.biter[key].size()!=count: return false
		if row.has("glows"):
			if not row.glows is PackedFloat32Array or row.glows.size()%3!=0: return false
			for value: float in row.glows:
				if not is_finite(value): return false
		for flag: int in row.flags:
			if flag & ~1: return false
	for row in frame.shapes:
		if not row is Dictionary or row.get("kind")!=0 or not row.get("points") is PackedVector2Array or not row.get("offsets") is PackedInt32Array or not row.get("widths") is PackedFloat32Array or not row.get("colors") is PackedColorArray: return false
		if row.offsets.size()<2 or row.offsets[0]!=0 or row.offsets[-1]!=row.points.size() or row.widths.size()!=row.offsets.size()-1 or row.colors.size()!=row.widths.size(): return false
		for i in range(1,row.offsets.size()):
			if row.offsets[i]<row.offsets[i-1]: return false
	for row in frame.poses:
		if not row is Dictionary or not visuals.has(row.get("part_key")) or not row.get("transform") is Transform2D or not row.get("visible") is bool or not row.get("visual_state") is int: return false
	return true

func apply_frame(frame: Dictionary) -> bool:
	if not _valid(frame): return false
	var begin := Time.get_ticks_usec()
	for batch: InstanceBatch in batches.values(): batch.begin()
	for display: Node in enemy_frames.values(): display.begin()
	for node: Sprite2D in parts.values(): node.hide()
	for line in _lines: line.hide()
	var rows: Array = frame.batches.duplicate()
	rows.sort_custom(func(a,b): return a.layer<b.layer or (a.layer==b.layer and a.order<b.order))
	for row: Dictionary in rows:
		if visuals[row.visual_id].role==6:
			if not enemy_frames.has(row.visual_id):
				var display = preload("res://scripts/render/run_enemy_frame.gd").new()
				add_child(display)
				display.setup(_scope,visuals[row.visual_id])
				display.begin()
				enemy_frames[row.visual_id] = display
			enemy_frames[row.visual_id].apply_frame(row)
			continue
		var batch := _batch(row.visual_id,row.layer)
		if batch.get_parent()!=_layer(row.layer): batch.reparent(_layer(row.layer))
		batch.get_parent().move_child(batch,-1)
		if visuals[row.visual_id].role==2:
			for i in row.ids.size():
				var n: int = i*6
				(batch as PixelPainter).bolt(Vector2(row.transforms[n+4],row.transforms[n+5]),atan2(row.transforms[n+1],row.transforms[n]),17,2)
		else: batch.apply_frame(row.transforms,row.colors)
	for batch: InstanceBatch in batches.values(): batch.end()
	for display: Node in enemy_frames.values(): display.end()
	var line_index := 0
	for row: Dictionary in frame.shapes:
		for i in row.widths.size():
			if line_index==_lines.size():
				var line := Line2D.new()
				_layer(row.layer).add_child(line)
				_lines.append(line)
			var line := _lines[line_index]
			if line.get_parent()!=_layer(row.layer): line.reparent(_layer(row.layer))
			line.points = row.points.slice(row.offsets[i],row.offsets[i+1])
			line.width = row.widths[i]
			line.default_color = row.colors[i]
			line.show()
			line_index += 1
	for row: Dictionary in frame.poses:
		var key := "%d:%d" % [row.participant_id,row.part_key]
		if not parts.has(key):
			var sprite := Sprite2D.new()
			sprite.texture = _scope.resources.get(visuals[row.part_key].path)
			sprite.offset = Vector2(0.0,sprite.texture.get_height()*0.5-30.0)
			_layer(17 if visuals[row.part_key].role==5 else 18).add_child(sprite)
			parts[key] = sprite
		var sprite: Sprite2D = parts[key]
		sprite.transform = row.transform
		sprite.visible = row.visible
		sprite.modulate = Color("#ff6b5a") if row.visual_state & 1 else Color.WHITE
		if row.visual_state & 2: sprite.modulate.a = 0.5
	submit_us = Time.get_ticks_usec()-begin
	return true

## 固定更新の間に届いた通知を、次の表示まで保持する。
func receive_frame(frame: Dictionary) -> bool:
	if frame.epoch!=_epoch:
		_epoch = frame.epoch
		_queued_events.clear()
		_flashes = ShotFlashes.new()
		_particles.clear()
		_rings.clear()
		_meteor_shards.clear()
	for event: Dictionary in frame.events:
		var payload: Dictionary = event.payload.duplicate(true)
		payload["type"] = event.type
		_queued_events.append(payload)
	return true

func update_effects(frame: Dictionary, dt: float) -> void:
	_zoom = frame.camera.zoom
	for event: Dictionary in _queued_events:
		if event.type==&"kill" and event.get("enemy_type")==&"meteor":
			var frames: SpriteFrames = _scope.resources.get("res://.content/meteor_pieces.res")
			if frames!=null:
				var animation := StringName("meteor_%d" % (posmod(int(event.meteor_index),2)+1))
				for i in frames.get_frame_count(animation):
					var texture := frames.get_frame_texture(animation,i) as AtlasTexture
					var offset: Vector2 = (texture.get_meta("offset") as Vector2).rotated(event.facing)
					_meteor_shards.append({"texture":texture,"pos":event.pos+offset*0.35,"vel":offset.normalized()*100.0+event.dir*60.0,
						"angle":event.facing,"spin":-1.5 if i%2==0 else 1.5,"life":0.65})
		if event.type==&"ring":
			if _rings.size()>80: _rings.pop_front()
			var duration: float = event.life*EFFECT_SETTINGS.number("","visible_time_scale",1.0)
			_rings.append({"pos":event.pos,"radius":event.radius,"color":event.color,"life":duration,"max":duration})
		if event.type==&"ship_explode": _death_burst(event.pos)
		if event.type==&"weapon_fire" and event.get("id")==&"W01": _flashes.fire(event.angle)
		if event.type==&"shot_hit" and event.get("visual_key")=="weapon/forward": _flashes.hit(event.pos,event.dir,2)
	_queued_events.clear()
	var ui: Dictionary = frame.ui
	_dim_strength = float(ui.get("death_dim",0.0))
	_dim_rect = Rect2(frame.camera.center-frame.camera.half,frame.camera.half*2.0)
	_dim.queue_redraw()
	for display: Node in enemy_frames.values(): display.set_death_brightness(1.0-_dim_strength)
	var effect_dt := 0.0 if ui.get("presentation_frozen",not ui.input_enabled) else dt
	for p: Dictionary in _particles:
		p.pos += p.vel*effect_dt
		p.vel *= 1.0-2.5*effect_dt
		p.life -= effect_dt
	for shard: Dictionary in _meteor_shards:
		shard.pos += shard.vel*effect_dt
		shard.angle += shard.spin*effect_dt
		shard.life -= effect_dt
	_meteor_shards = _meteor_shards.filter(func(shard: Dictionary): return shard.life>0.0)
	for ring: Dictionary in _rings: ring.life -= effect_dt
	_rings = _rings.filter(func(ring: Dictionary): return ring.life>0.0)
	_particles = _particles.filter(func(p: Dictionary): return p.life>0.0)
	_particle_canvas.queue_redraw()
	var active: bool = ui.input_enabled
	var world_dt: float = dt*ui.world_scale if active else 0.0
	_effects.begin()
	_flashes.draw(_effects,world_dt,ui.ship.ship_pos+ui.ship.ship_heading*16.0*_pixel)
	_effects.end()
	if active and not ui.draw.drawing and ui.hitstop<=0.0:
		_jet_time += dt*clampf(ui.ship_vel.length()/ui.base_max_speed,0.0,3.0)
	for sprite in [_flame,_spark]:
		sprite.position = ui.ship.ship_pos
		sprite.rotation = ui.ship.ship_heading.angle()+PI/2.0
		sprite.frame = int(_jet_time*12.0)%3
		sprite.visible = ui.phase==0 or ui.phase==4

func _death_burst(at: Vector2) -> void:
	if pipeline!=null and pipeline.sparks.available():
		pipeline.sparks.burst(at,Color("#9fe8ff"),120,Vector2.ZERO,500.0,0.7,5.0)
		return
	if _particles.size()>500: return
	for i in 8:
		var angle := randf()*TAU
		var speed := 500.0*(0.3+randf())
		_particles.append({"pos":at,"vel":Vector2.from_angle(angle)*speed*0.6,"life":0.5+randf()*0.4,"max":0.9,"color":Color("#9fe8ff"),"size":2.0+randf()*4.0})
