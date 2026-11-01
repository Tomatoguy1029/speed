## RenderFrameの値だけを描画へ渡す。敵表や武器の実体は参照しない。
extends Node2D
var visuals: Dictionary = {}
var batches: Dictionary = {}
var parts: Dictionary = {}
var _layers: Dictionary = {}
var _lines: Array[Line2D] = []
var _scope: ContentResourceScope
var _pixel := 1.82
var _effects: PixelPainter
var _flashes := ShotFlashes.new()
var _event_count := 0
var _epoch := 0
var _jet_time := 0.0
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
			batch.setup_texture(_scope.resources.get(entry.path) as Texture2D)
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
	for node: Sprite2D in parts.values(): node.hide()
	for line in _lines: line.hide()
	var rows: Array = frame.batches.duplicate()
	rows.sort_custom(func(a,b): return a.layer<b.layer or (a.layer==b.layer and a.order<b.order))
	for row: Dictionary in rows:
		var batch := _batch(row.visual_id,row.layer)
		if batch.get_parent()!=_layer(row.layer): batch.reparent(_layer(row.layer))
		batch.get_parent().move_child(batch,-1)
		if visuals[row.visual_id].role==2:
			for i in row.ids.size():
				var n: int = i*6
				(batch as PixelPainter).bolt(Vector2(row.transforms[n+4],row.transforms[n+5]),atan2(row.transforms[n+1],row.transforms[n]),17,2)
		else: batch.apply_frame(row.transforms,row.colors)
	for batch: InstanceBatch in batches.values(): batch.end()
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

func update_effects(frame: Dictionary, dt: float) -> void:
	if frame.epoch!=_epoch:
		_epoch = frame.epoch
		_event_count = 0
		_flashes = ShotFlashes.new()
	if frame.events.size()<_event_count: _event_count = 0
	for i in range(_event_count,frame.events.size()):
		var event: Dictionary = frame.events[i]
		if event.type==&"weapon_fire" and event.get("id")==&"W01": _flashes.fire(event.angle)
		if event.type==&"shot_hit" and event.get("visual_key")=="weapon/forward": _flashes.hit(event.pos,event.dir,2)
	_event_count = frame.events.size()
	var ui: Dictionary = frame.ui
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
