## RenderFrameの値だけを描画へ渡す。敵表や武器の実体は参照しない。
extends Node2D
const VISUAL_ROLE = preload("res://tools/content/generated/run_schema.gd").ENUMS.VisualRole
const SHAPE_KIND = preload("res://tools/content/generated/run_schema.gd").ENUMS.RenderShapeKind
const EFFECT_SETTINGS = preload("res://data/visuals/effect_settings.tres")
var perf := PerfLog.new()
var metrics_record := {}
var visuals: Dictionary = {}
var batches: Dictionary = {}
var parts: Dictionary = {}
var enemy_frames: Dictionary = {}
var _layers: Dictionary = {}
var _lines: Array[Line2D] = []
var _shape_displays: Dictionary = {}
var _wave_displays: Dictionary = {}
var _arrow_displays: Dictionary = {}
var _debris_displays: Dictionary = {}
var _flood_displays: Dictionary = {}
var _flood_tails: Array[Dictionary] = []
var _flood_world_time := -1.0
var _zone_displays: Dictionary = {}
var _zone_bursts: Dictionary = {}
var _zone_seen: Dictionary = {}
var _zone_world_time := -1.0
var _attack_ends: Array[Dictionary] = []
var _hull_displays: Dictionary = {}
var _debris_trails: Array[Dictionary] = []
var _scope: ContentResourceScope
var _pixel := 1.82
var _shot_transforms: Dictionary = {}
var _gunner := PackedFloat32Array()
var _beamer := PackedFloat32Array()
var _missile := PackedFloat32Array()
var _battleship := PackedFloat32Array()
var _soldier := PackedFloat32Array()
var _mutiny_beams: Array[Dictionary] = []
var _lynx := PackedFloat32Array()
var _dolphin := PackedFloat32Array()
var _sniper := PackedFloat32Array()
var _sniper_world_time := 0.0
var _telescope_beams: Array[Dictionary] = []
var _pulser_visual: EnemyVisual
var _pulser_parent: Node2D
var _marlin_visual: EnemyVisual
var _gunner_marks: DrawLayer
var _effects: PixelPainter
var _flashes := ShotFlashes.new()
var _scatter_flashes := ShotFlashes.new()
var _rear_flashes := ShotFlashes.new()
var _rear_shells: Array[Dictionary] = []
var _rear_world_time := -1.0
var _rear_canvas: DrawLayer
var _rear_frame: Dictionary = {}
var _barrier_visual: RefCounted
var _barrier_armor: Sprite2D
var _barrier_world_time := -1.0
var _full_charge_visual: RefCounted
var _full_charge_world_time := -1.0
var _rampage_visual: RefCounted
var _rampage_world_time := -1.0
var _full_burst_visual: RefCounted
var _full_burst_world_time := -1.0
var _duplicator_visual: RefCounted
var _duplicator_world_time := -1.0
var _scatter_world_time := -1.0
var _forward_world_time := -1.0
var _queued_events: Array[Dictionary] = []
var _epoch := 0
var _jet_time := 0.0
var pipeline: RenderPipeline
var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _meteor_shards: Array[Dictionary] = []
var _shield_transfers: Array[Dictionary] = []
var _shield_holder: Node2D
var _shield_transfer_canvas: DrawLayer
var _shield_layer := 2
var _ship_visible := true
var _ship_visual_position := Vector2.INF
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
	metrics_record = perf.open(&"metrics")
	_scope = scope
	_pixel = 1.82*character_scale
	for entry in entries: visuals[int(entry.id)] = entry
	for entry: Dictionary in entries:
		if entry.role==6: _shield_layer = maxi(_shield_layer,int(entry.id)-3)
	_barrier_armor = Sprite2D.new()
	_barrier_armor.texture = _scope.resources.get("res://assets/pixel/airship_armor.png")
	_barrier_armor.offset = Vector2(0.0,_barrier_armor.texture.get_height()*0.5-30.0) if _barrier_armor.texture!=null else Vector2.ZERO
	_barrier_armor.scale = Vector2.ONE*character_scale
	_barrier_armor.hide()
	_layer(18).add_child(_barrier_armor)
	_rear_canvas = DrawLayer.new()
	_layer(18).add_child(_rear_canvas)
	_rear_canvas.draw_fn = func(canvas: CanvasItem):
		if _rear_frame.is_empty() or not _rear_frame.rear.ready or not _ship_visible: return
		var ui: Dictionary = _rear_frame
		var color := Color("#ff6b5a") if ui.ship.ship_hurt>0.0 else Color.WHITE
		if ui.ship.ship_invuln>0.0 and fmod(ui.world_time*20.0,2.0)<1.0: color.a = 0.5
		preload("res://scripts/render/equipment/rear.gd").frame_extra(canvas,_scope.resources.get("res://assets/pixel/airship_turret_base.png"),_scope.resources.get("res://assets/pixel/airship_turret.png"),_ship_visual_position,ui.ship.ship_pos,ui.ship.ship_heading,ui.rear.mount,ui.rear.aim,ui.rear.recoil,ui.character_scale,color)
	var marlin_layer := CanvasLayer.new()
	marlin_layer.layer = _shield_layer+1
	marlin_layer.follow_viewport_enabled = true
	add_child(marlin_layer)
	var marlin_parent := Node2D.new()
	marlin_layer.add_child(marlin_parent)
	_marlin_visual = preload("res://scripts/render/enemies/marlin.gd").new()
	_marlin_visual.setup_frame(marlin_parent)
	_pulser_parent = marlin_parent
	_pulser_visual = preload("res://scripts/render/enemies/pulser.gd").new()
	_shield_holder = Node2D.new()
	_layer(18).add_child(_shield_holder)
	var transfer_layer := CanvasLayer.new()
	transfer_layer.layer = _shield_layer-1
	transfer_layer.follow_viewport_enabled = true
	add_child(transfer_layer)
	_shield_transfer_canvas = DrawLayer.new()
	transfer_layer.add_child(_shield_transfer_canvas)
	_shield_transfer_canvas.draw_fn = func(canvas: CanvasItem):
		for effect: Dictionary in _shield_transfers:
			preload("res://scripts/render/shield_visual.gd").transfer(canvas,effect,_ship_visual_position)

	_gunner_marks = DrawLayer.new()
	_gunner_marks.draw_fn = func(canvas: CanvasItem):
		var began := Time.get_ticks_usec() if perf.active else 0
		preload("res://scripts/render/enemies/gunner.gd").draw_frame(canvas,_gunner,_pixel)
		preload("res://scripts/render/enemies/beamer.gd").draw_frame(canvas,_beamer,_pixel)
		preload("res://scripts/render/enemies/missile.gd").draw_frame(canvas,_missile,_pixel)
		preload("res://scripts/render/enemies/battleship.gd").draw_frame(canvas,_battleship,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/soldier.gd").draw_frame(canvas,_soldier,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/lynx.gd").draw_frame(canvas,_lynx,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/dolphin.gd").draw_frame(canvas,_dolphin,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/sniper.gd").draw_frame(canvas,_sniper,_sniper_world_time,1.0/maxf(_zoom,0.01))
		perf.since(&"view_draw.attacks",began)
	_layer(9).add_child(_gunner_marks)
	_effects = PixelPainter.new()
	_effects.setup_painter(_pixel)
	_layer(14).add_child(_effects)
	_particle_canvas = Node2D.new()
	_layer(14).add_child(_particle_canvas)
	_particle_canvas.draw.connect(func():
		for beam: Dictionary in _mutiny_beams:
			var k: float = beam.life/beam.max
			var color: Color = EFFECT_SETTINGS.tinted("",beam.color)
			_particle_canvas.draw_line(beam.from,beam.to,Color(color,0.7*k),beam.width)
			_particle_canvas.draw_line(beam.from,beam.to,Color(1,1,1,k),beam.width*EFFECT_SETTINGS.number("","beam_core_ratio",0.3))
		for beam: Dictionary in _telescope_beams:
			var color := Color(1.0,0.3,0.22,beam.life/beam.max)
			_particle_canvas.draw_line(beam.from,beam.to,color,beam.width)
			_particle_canvas.draw_circle(beam.from,beam.width*0.5,color)
			_particle_canvas.draw_circle(beam.to,beam.width*0.5,color)

		for effect: Dictionary in _attack_ends:
			var fade: float = 1.0-effect.age/effect.duration
			var tint: Color = effect.tint*Color(1,1,1,fade)
			if effect.mesh!=null: _particle_canvas.draw_mesh(effect.mesh,null,Transform2D(0.0,effect.pos),tint)
			for piece: Dictionary in effect.sprites: _particle_canvas.draw_mesh(piece.mesh,piece.texture,Transform2D(0.0,effect.pos),tint)
		for trail: Dictionary in _debris_trails:
			if trail.points.size()>1: _particle_canvas.draw_polyline(trail.points,Color(1.0,0.6,0.25,0.6*trail.life/trail.max),3.0*_pixel/maxf(_zoom,0.01))
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
		batch = preload("res://scripts/render/attacks/friend_shot.gd").create_batch(_pixel)
	else:
		batch = InstanceBatch.new()
		if entry.role==4: batch.setup_polygon(InstanceBatch.circle_points(24))
		elif entry.role==11: preload("res://scripts/render/attacks/bullet.gd").setup_batch(batch)
		elif entry.role==12: batch.setup_polygon(InstanceBatch.circle_points(32))
		elif entry.role==VISUAL_ROLE.StarBolt: preload("res://scripts/render/attacks/star_bolt.gd").setup_batch(batch,_scope.resources.get(entry.path),entry.scene)
		elif entry.role==13: preload("res://scripts/render/attacks/reflected.gd").setup_batch(batch)
		elif entry.role==VISUAL_ROLE.EnemyPolygon: batch.setup_polygon(entry.points)
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
	if frame.has("pulser"):
		if not frame.pulser is PackedFloat64Array or frame.pulser.size()%6!=0: return false
		for value in frame.pulser:
			if not is_finite(value): return false
	if frame.has("marlin"):
		var data = frame.marlin
		if not data is Dictionary or not data.get("ids") is PackedInt64Array or not data.get("values") is PackedFloat64Array or not data.get("view") is Rect2 or data.values.size()!=data.ids.size()*14: return false
		for value: float in data.values:
			if not is_finite(value): return false
	for row in frame.batches:
		if not row is Dictionary or not visuals.has(row.get("visual_id")) or not row.get("ids") is PackedInt64Array or not row.get("transforms") is PackedFloat32Array or not row.get("colors") is PackedColorArray or not row.get("flags") is PackedInt32Array: return false
		var count: int = row.ids.size()
		if row.transforms.size()!=count*6 or row.colors.size()!=count or row.flags.size()!=count: return false
		if visuals[row.visual_id].role==6 and visuals[row.visual_id].get("biting",false):
			if not row.get("biter") is Dictionary: return false
			for key in ["modes","charges","timers","rests"]:
				if not row.biter.has(key) or row.biter[key].size()!=count: return false
		if row.has("beamer"):
			if not row.beamer is PackedFloat32Array or row.beamer.size()%10!=0: return false
			for value: float in row.beamer:
				if not is_finite(value): return false
		if row.has("soldier"):
			if not row.soldier is PackedFloat32Array or row.soldier.size()%7!=0: return false
			for value: float in row.soldier:
				if not is_finite(value): return false
		if row.has("lynx"):
			if not row.lynx is PackedFloat32Array or row.lynx.size()%6!=0: return false
			for value: float in row.lynx:
				if not is_finite(value): return false
		if row.has("dolphin"):
			if not row.dolphin is PackedFloat32Array or row.dolphin.size()%6!=0: return false
			for value: float in row.dolphin:
				if not is_finite(value): return false
		if row.has("sniper"):
			if not row.sniper is PackedFloat32Array or row.sniper.size()%59!=0: return false
			for value: float in row.sniper:
				if not is_finite(value): return false
		if row.has("battleship"):
			if not row.battleship is PackedFloat32Array or row.battleship.size()%6!=0: return false
			for value: float in row.battleship:
				if not is_finite(value): return false
		if row.has("missile"):
			if not row.missile is PackedFloat32Array or row.missile.size()%5!=0: return false
			for value: float in row.missile:
				if not is_finite(value): return false
		if row.has("gunner"):
			if not row.gunner is PackedFloat32Array or row.gunner.size()%5!=0: return false
			for value: float in row.gunner:
				if not is_finite(value): return false
		if row.has("glows"):
			if not row.glows is PackedFloat32Array or row.glows.size()%3!=0: return false
			for value: float in row.glows:
				if not is_finite(value): return false
		for flag: int in row.flags:
			if flag & ~1: return false
	for row in frame.shapes:
		if not row is Dictionary or row.get("kind") not in [SHAPE_KIND.Polyline,SHAPE_KIND.Circle,SHAPE_KIND.Wave,SHAPE_KIND.Blast,SHAPE_KIND.LightArrow,SHAPE_KIND.FriendDebris,SHAPE_KIND.FriendHull,SHAPE_KIND.Zone,SHAPE_KIND.Flood] or not row.get("points") is PackedVector2Array or not row.get("offsets") is PackedInt32Array or not row.get("widths") is PackedFloat32Array or not row.get("colors") is PackedColorArray: return false
		if not row.get("owner_id") is int or not row.get("layer") is int or not row.get("order") is int or row.owner_id<0: return false
		if row.offsets.size()<2 or row.offsets[0]!=0 or row.offsets[-1]!=row.points.size() or row.widths.size()!=row.offsets.size()-1 or row.colors.size()!=row.widths.size(): return false
		if row.kind==SHAPE_KIND.Flood:
			if row.points.size()!=1 or row.widths.size()!=1: return false
			for key in ["time","delay","active","angle","length","spread","margin"]:
				if not row.get(key) is float or not is_finite(row[key]): return false
		if row.kind==SHAPE_KIND.Zone:
			if row.points.size()!=1 or row.widths.size()!=1 or row.get("zone_style") not in range(8) or not row.get("tint") is Color or not row.get("arm_count") is int: return false
			for key in ["time","delay","active","glow_opacity","ring_opacity","ring_width","lightning_reach","lightning_width"]:
				if not row.get(key) is float or not is_finite(row[key]): return false
		if row.kind==SHAPE_KIND.FriendHull:
			if row.points.size()!=1 or row.widths.size()!=1 or not row.get("angle") is float or not row.get("saw") is bool or not row.get("visual_id") is int or not row.get("hull_points") is PackedVector2Array: return false
		if row.kind==SHAPE_KIND.FriendDebris:
			if row.points.size()!=1 or row.widths.size()!=1 or not row.get("trail") is PackedVector2Array or not row.get("velocity") is Vector2 or row.get("debris_style") not in [0,1,2]: return false
			for key in ["angle","age","life","clock","trail_width"]:
				if not row.get(key) is float or not is_finite(row[key]): return false
		if row.kind==SHAPE_KIND.LightArrow:
			if row.points.size()!=1 or row.widths.size()!=1 or not row.get("cosmic") is bool or not row.get("cosmic_star_count") is int: return false
			for key in ["angle","length","world_time","shot_length_scale","shot_width_scale","core_width","cosmic_speed"]:
				if not row.get(key) is float or not is_finite(row[key]): return false
			for key in ["arrow_color","cosmic_color_a","cosmic_color_b"]:
				if not row.get(key) is Color: return false
		if row.kind==SHAPE_KIND.Wave:
			if row.points.size()!=1 or row.widths.size()!=1 or row.get("wave_style") not in [0,1,2,3]: return false
			for key in ["radius","max_radius","angle","arc","gap","gap_arc","time","delay"]:
				if not row.get(key) is float or not is_finite(row[key]): return false
		for i in range(1,row.offsets.size()):
			if row.offsets[i]<row.offsets[i-1]: return false
	for row in frame.poses:
		if not row is Dictionary or not visuals.has(row.get("part_key")) or not row.get("transform") is Transform2D or not row.get("visible") is bool or not row.get("visual_state") is int: return false
	return true

func apply_frame(frame: Dictionary) -> bool:
	var begin := Time.get_ticks_usec()
	if not _valid(frame): return false
	var next_shots := {}
	for row: Dictionary in frame.batches:
		if visuals[row.visual_id].role==2: next_shots[row.visual_id] = row.transforms
	var unchanged_shots := {}
	for id in visuals:
		if visuals[id].role==2 and next_shots.get(id,PackedFloat32Array())==_shot_transforms.get(id,PackedFloat32Array()): unchanged_shots[id] = true
	_shot_transforms = next_shots
	for id in batches:
		if not unchanged_shots.has(id): batches[id].begin()
	for display: Node in enemy_frames.values(): display.begin()
	for node: Sprite2D in parts.values(): node.hide()
	for line in _lines: line.hide()
	var previous_gunner := _gunner
	var previous_beamer := _beamer
	var previous_missile := _missile
	var previous_battleship := _battleship
	var previous_soldier := _soldier
	var previous_lynx := _lynx
	var previous_dolphin := _dolphin
	var previous_sniper := _sniper
	_gunner = PackedFloat32Array()
	_beamer = PackedFloat32Array()
	_missile = PackedFloat32Array()
	_battleship = PackedFloat32Array()
	_soldier = PackedFloat32Array()
	_lynx = PackedFloat32Array()
	_dolphin = PackedFloat32Array()
	_sniper = PackedFloat32Array()
	for row: Dictionary in frame.batches:
		if row.has("gunner"): _gunner.append_array(row.gunner)
		if row.has("beamer"): _beamer.append_array(row.beamer)
		if row.has("missile"): _missile.append_array(row.missile)
		if row.has("battleship"): _battleship.append_array(row.battleship)
		if row.has("soldier"): _soldier.append_array(row.soldier)
		if row.has("lynx"): _lynx.append_array(row.lynx)
		if row.has("dolphin"): _dolphin.append_array(row.dolphin)
		if row.has("sniper"): _sniper.append_array(row.sniper)
	# 描画命令はCanvasItemが保持する。変わらない予告は再構築しない。
	if _gunner!=previous_gunner or _beamer!=previous_beamer or _missile!=previous_missile or _battleship!=previous_battleship or _sniper!=previous_sniper or _dolphin!=previous_dolphin or _lynx!=previous_lynx or _soldier!=previous_soldier: _gunner_marks.queue_redraw()
	var rows: Array = frame.batches.duplicate()
	rows.sort_custom(func(a,b): return a.layer<b.layer or (a.layer==b.layer and a.order<b.order))
	var packed_bytes := 0
	for row: Dictionary in rows:
		if perf.active:
			packed_bytes+=row.ids.size()*8+row.transforms.size()*4+row.colors.size()*16+row.flags.size()*4
			for key in ["gunner","beamer","missile","battleship","sniper","glows"]: packed_bytes+=row.get(key,PackedFloat32Array()).size()*4
			if row.has("biter"):
				for key in row.biter: packed_bytes+=row.biter[key].size()*4
		if visuals[row.visual_id].role==6:
			if not enemy_frames.has(row.visual_id):
				var display = preload("res://scripts/render/run_enemy_frame.gd").new()
				add_child(display)
				display.perf = perf
				display.setup(_scope,visuals[row.visual_id])
				display.begin()
				enemy_frames[row.visual_id] = display
			enemy_frames[row.visual_id].apply_frame(row)
			continue
		var batch := _batch(row.visual_id,row.layer)
		if batch.get_parent()!=_layer(row.layer): batch.reparent(_layer(row.layer))
		batch.get_parent().move_child(batch,-1)
		if visuals[row.visual_id].role==2:
			if unchanged_shots.has(row.visual_id): continue
			var began := Time.get_ticks_usec() if perf.active else 0
			preload("res://scripts/render/attacks/friend_shot.gd").apply_frame(batch as PixelPainter,row.transforms,row.flags)
			perf.since(&"view_geometry.attacks",began)
		else: batch.apply_frame(row.transforms,row.colors)
	for id in batches:
		if not unchanged_shots.has(id): batches[id].end()
	for display: Node in enemy_frames.values(): display.end()
	for display: Dictionary in _shape_displays.values():
		display.used = false
		display.previous_circles = display.circles.duplicate()
		display.circles.clear()
	for display: Node in _wave_displays.values(): display.hide()
	for display: Node in _arrow_displays.values(): display.hide()
	for display: Node in _debris_displays.values(): display.hide()
	for display: Node in _hull_displays.values(): display.hide()
	for display: Node in _zone_displays.values(): display.hide()
	for display: Dictionary in _flood_displays.values(): display.node.hide()
	var line_index := 0
	for row: Dictionary in frame.shapes:
		if perf.active: packed_bytes+=row.points.size()*8+row.offsets.size()*4+row.widths.size()*4+row.colors.size()*16
		var parent: Node2D = _layer(row.layer)
		if row.kind==SHAPE_KIND.Flood:
			var key := int(row.order)
			if not _flood_displays.has(key):
				var water: Dictionary = preload("res://scripts/render/attacks/flood.gd").frame_create(_scope)
				parent.add_child(water.node)
				if pipeline!=null and not pipeline.rich: water.node.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
				_flood_displays[key] = water
			var water: Dictionary = _flood_displays[key]
			if water.row.get("owner_id",0)!=row.owner_id: water.fired = false
			preload("res://scripts/render/attacks/flood.gd").frame_apply(water,row)
			water.node.show()
			if row.time>=row.delay and not water.fired:
				water.fired = true
				if pipeline!=null: pipeline.add_wave(row.points[0],800.0,0.7)
				_burst(row.points[0],row.colors[0].lightened(0.3),36,760.0)
			continue
		if row.kind==SHAPE_KIND.Zone:
			var key := int(row.order)
			if not _zone_displays.has(key):
				var node := DrawLayer.new()
				parent.add_child(node)
				_zone_displays[key] = node
			var node: DrawLayer = _zone_displays[key]
			node.draw_fn = func(c: CanvasItem): preload("res://scripts/render/attacks/zone.gd").draw_frame(c,row,1.0/maxf(_zoom,0.01))
			node.show()
			node.queue_redraw()
			_zone_burst(row)
			continue
		if row.kind==SHAPE_KIND.FriendHull:
			var key := int(row.order)
			if not _hull_displays.has(key):
				var hull := preload("res://scripts/render/attacks/friend_hull.gd").new()
				parent.add_child(hull)
				hull.setup(_scope,visuals)
				_hull_displays[key] = hull
			_hull_displays[key].apply_frame(row)
			_hull_displays[key].show()
			continue
		if row.kind==SHAPE_KIND.FriendDebris:
			var key := int(row.order)
			if not _debris_displays.has(key):
				var debris := preload("res://scripts/render/attacks/friend_debris.gd").new()
				parent.add_child(debris)
				debris.setup(_scope,_pixel)
				_debris_displays[key] = debris
			_debris_displays[key].apply_frame(row,_zoom)
			_debris_displays[key].show()
			continue
		if row.kind==SHAPE_KIND.LightArrow:
			var key := "%d:%d" % [row.layer,row.order]
			if not _arrow_displays.has(key):
				var arrow := preload("res://scripts/render/attacks/light_arrow.gd").new()
				parent.add_child(arrow)
				_arrow_displays[key] = arrow
			_arrow_displays[key].apply_frame(row)
			_arrow_displays[key].show()
			continue
		if row.kind==SHAPE_KIND.Wave:
			var key := "%d:%d" % [row.layer,row.order]
			if not _wave_displays.has(key):
				var wave := preload("res://scripts/render/attacks/wave.gd").new()
				parent.add_child(wave)
				_wave_displays[key] = wave
			var wave: Node2D = _wave_displays[key]
			parent.move_child(wave,-1)
			wave.apply_frame(row,1.0/maxf(_zoom,0.01))
			wave.show()
			continue
		var display: Dictionary = {}
		if int(row.owner_id)>0 or row.kind in [SHAPE_KIND.Circle,SHAPE_KIND.Blast]:
			var key := "%d:%d:%d" % [row.kind,row.layer,row.order]
			if not _shape_displays.has(key):
				var circles: Array = []
				var node: DrawLayer = preload("res://scripts/render/attacks/zone.gd").frame_group(circles,func(): return 1.0/maxf(_zoom,0.01)) if row.kind==SHAPE_KIND.Blast else preload("res://scripts/render/attacks/beam.gd").frame_group(circles)
				parent.add_child(node)
				_shape_displays[key] = {"node":node,"circles":circles,"used":false,"previous_circles":[]}
			display = _shape_displays[key]
			parent = display.node
			display.used = true
			if parent.get_index()!=parent.get_parent().get_child_count()-1: parent.get_parent().move_child(parent,-1)
		for i in row.widths.size():
			if row.kind in [SHAPE_KIND.Circle,SHAPE_KIND.Blast]:
				if display.is_empty() or row.offsets[i+1]-row.offsets[i]!=1: return false
				display.circles.append({"position":row.points[row.offsets[i]],"radius":row.widths[i],"color":row.colors[i]})
				continue
			if line_index==_lines.size():
				var line := Line2D.new()
				_layer(row.layer).add_child(line)
				_lines.append(line)
			var line := _lines[line_index]
			if line.get_parent()!=parent: line.reparent(parent)
			line.points = row.points.slice(row.offsets[i],row.offsets[i+1])
			line.z_index = -1 if row.get("behind_parent",false) else 0
			line.width = row.widths[i]
			line.default_color = row.colors[i]
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND if row.get("rounded",false) else Line2D.LINE_CAP_NONE
			line.end_cap_mode = line.begin_cap_mode
			line.show()
			line_index += 1
	for display: Dictionary in _shape_displays.values():
		display.node.visible = display.used
		if display.circles!=display.previous_circles: display.node.queue_redraw()
	if frame.has("pulser"): _pulser_visual.apply_frame(_pulser_parent,frame.pulser)
	if frame.has("marlin"): _marlin_visual.apply_frame(frame.marlin,_sniper_world_time,_zoom)
	for row: Dictionary in frame.poses:
		var key := "%d:%d" % [row.participant_id,row.part_key]
		if not parts.has(key):
			var sprite := Sprite2D.new()
			sprite.texture = _scope.resources.get(visuals[row.part_key].path)
			sprite.offset = Vector2(0.0,sprite.texture.get_height()*0.5-30.0)
			_layer(17 if visuals[row.part_key].role==5 else 18).add_child(sprite)
			parts[key] = sprite
		var sprite: Sprite2D = parts[key]
		if visuals[row.part_key].role==1:
			_ship_visual_position = row.transform.origin
			_ship_visible = row.visible
		sprite.transform = row.transform
		sprite.visible = row.visible
		sprite.modulate = Color("#ff6b5a") if row.visual_state & 1 else Color.WHITE
		if row.visual_state & 2: sprite.modulate.a = 0.5
	submit_us = Time.get_ticks_usec()-begin
	perf.add(&"view_submit",submit_us)
	perf.add(&"render_packed_bytes",packed_bytes)
	return true

## 固定更新の間に届いた通知を、次の表示まで保持する。
func receive_frame(frame: Dictionary) -> bool:
	if frame.epoch!=_epoch:
		_epoch = frame.epoch
		_queued_events.clear()
		_mutiny_beams.clear()
		_flashes = ShotFlashes.new()
		_forward_world_time = -1.0
		_scatter_flashes = ShotFlashes.new()
		_scatter_world_time = -1.0
		_rear_flashes = ShotFlashes.new()
		_rear_shells.clear()
		_rear_world_time = -1.0
		if _barrier_visual!=null: _barrier_visual.dispose()
		_barrier_visual = null
		_barrier_world_time = -1.0
		if _full_charge_visual!=null: _full_charge_visual.dispose()
		_full_charge_visual = null
		_full_charge_world_time = -1.0
		if _rampage_visual!=null: _rampage_visual.dispose()
		_rampage_visual = null
		_rampage_world_time = -1.0
		if _duplicator_visual!=null: _duplicator_visual.dispose()
		_duplicator_visual = null
		_duplicator_world_time = -1.0
		if _full_burst_visual!=null: _full_burst_visual.dispose()
		_full_burst_visual = null
		_full_burst_world_time = -1.0
		_particles.clear()
		_rings.clear()
		_debris_trails.clear()
		_attack_ends.clear()
		_zone_seen.clear()
		_flood_world_time = -1.0
		for tail: Dictionary in _flood_tails: tail.node.queue_free()
		_flood_tails.clear()
		_zone_world_time = -1.0
		for bursts: Node in _zone_bursts.values(): bursts.queue_free()
		_zone_bursts.clear()
		_meteor_shards.clear()
		_shield_transfers.clear()
	for event: Dictionary in frame.events:
		var payload: Dictionary = event.payload.duplicate(true)
		payload["type"] = event.type
		_queued_events.append(payload)
	return true

func update_effects(frame: Dictionary, dt: float) -> void:
	var equipped_forward: bool = frame.ui.get("weapon_levels",[]).any(func(item): return item.id=="W01")
	if not equipped_forward:
		_flashes = ShotFlashes.new()
		_forward_world_time = -1.0
	var equipped_scatter: bool = frame.ui.get("weapon_levels",[]).any(func(item): return item.id=="W02")
	if not equipped_scatter:
		_scatter_flashes = ShotFlashes.new()
		_scatter_world_time = -1.0
	var equipped_rear: bool = frame.ui.get("weapon_levels",[]).any(func(item): return item.id=="W23")
	if not equipped_rear:
		_rear_flashes = ShotFlashes.new()
		_rear_shells.clear()
		_rear_world_time = -1.0
	_rear_frame = frame.ui
	_rear_canvas.visible = equipped_rear and _ship_visible
	_rear_canvas.get_parent().move_child(_rear_canvas,-1)
	_rear_canvas.queue_redraw()
	var equipped_barrier: bool = frame.ui.get("weapon_levels",[]).any(func(item): return item.id=="W05")
	var barrier_from_state: bool = equipped_barrier and _barrier_visual==null
	if barrier_from_state:
		_barrier_visual = preload("res://scripts/render/equipment/barrier.gd").new()
		_barrier_visual.setup_frame(_layer(19),_pixel)
		for wave: Dictionary in frame.ui.barrier.waves:
			_barrier_visual.hits.append({"angle":wave.angle,"age":wave.age,"broken":wave.broken,"radius":wave.radius,"shattered":false})
		if frame.ui.barrier.restore_visual_age<0.5: _barrier_visual.restores.append({"age":frame.ui.barrier.restore_visual_age})
	if not equipped_barrier and _barrier_visual!=null:
		_barrier_visual.dispose()
		_barrier_visual = null
		_barrier_world_time = -1.0
	_barrier_armor.visible = equipped_barrier and _ship_visible
	_barrier_armor.position = _ship_visual_position
	_barrier_armor.rotation = frame.ui.ship.ship_heading.angle()+PI/2.0
	_barrier_armor.modulate = Color("#ff6b5a") if frame.ui.ship.ship_hurt>0.0 else Color.WHITE
	if frame.ui.ship.ship_invuln>0.0 and fmod(frame.ui.world_time*20.0,2.0)<1.0: _barrier_armor.modulate.a = 0.5
	_barrier_armor.get_parent().move_child(_barrier_armor,-1)
	_rear_canvas.get_parent().move_child(_rear_canvas,-1)
	var equipped_full_charge: bool = frame.ui.get("trait_levels",[]).any(func(item): return item.id=="T04")
	if equipped_full_charge and _full_charge_visual==null:
		_full_charge_visual = preload("res://scripts/render/equipment/fullCharge.gd").new()
		_full_charge_visual.setup_frame(_layer(18),_pixel)
	if not equipped_full_charge and _full_charge_visual!=null:
		_full_charge_visual.dispose()
		_full_charge_visual = null
		_full_charge_world_time = -1.0
	var equipped_rampage: bool = frame.ui.get("trait_levels",[]).any(func(item): return item.id=="T33")
	if equipped_rampage and _rampage_visual==null:
		_rampage_visual = preload("res://scripts/render/equipment/rampage.gd").new()
		_rampage_visual.setup_frame(_layer(18))
		_rampage_visual._aura.z_index = 1
	if not equipped_rampage and _rampage_visual!=null:
		_rampage_visual.dispose()
		_rampage_visual = null
		_rampage_world_time = -1.0
	var equipped_full_burst: bool = frame.ui.get("full_burst",false)
	if equipped_full_burst and _full_burst_visual==null:
		_full_burst_visual = preload("res://scripts/render/equipment/fullBurst.gd").new()
		_full_burst_visual.setup_frame(_layer(18),_pixel)
	if not equipped_full_burst and _full_burst_visual!=null:
		_full_burst_visual.dispose()
		_full_burst_visual = null
		_full_burst_world_time = -1.0
	var equipped_duplicator: bool = frame.ui.get("trait_levels",[]).any(func(item): return item.id=="T37")
	if equipped_duplicator and _duplicator_visual==null:
		_duplicator_visual = preload("res://scripts/render/equipment/duplicator.gd").new()
		_duplicator_visual.setup_frame(_layer(14),_pixel)
	if not equipped_duplicator and _duplicator_visual!=null:
		_duplicator_visual.dispose()
		_duplicator_visual = null
		_duplicator_world_time = -1.0
	_zoom = frame.camera.zoom
	_sniper_world_time = float(frame.ui.world_time)
	if not _sniper.is_empty(): _gunner_marks.queue_redraw()
	for event: Dictionary in _queued_events:
		if event.type==&"shield_stolen":
			_shield_transfers.append({"pos":event.pos,"facing":event.facing,"r":event.r,"arc":event.arc,"life":0.3,"max":0.3})
			_rings.append({"pos":event.pos,"radius":event.r*1.7,"color":Color("#65e8ff"),"life":0.3,"max":0.3})
		if event.type==&"shield_block":
			_rings.append({"pos":event.pos,"radius":float(frame.ui.ship_radius)*3.0,"color":Color("#bcefff"),"life":0.18,"max":0.18})
		if event.type==&"kill" and event.get("enemy_type")==&"meteor":
			var frames: SpriteFrames = _scope.resources.get("res://.content/meteor_pieces.res")
			if frames!=null:
				var animation := StringName("meteor_%d" % (posmod(int(event.meteor_index),2)+1))
				for i in frames.get_frame_count(animation):
					var texture := frames.get_frame_texture(animation,i) as AtlasTexture
					var offset: Vector2 = (texture.get_meta("offset") as Vector2).rotated(event.facing)
					_meteor_shards.append({"texture":texture,"pos":event.pos+offset*0.35,"vel":offset.normalized()*100.0+event.dir*60.0,
						"angle":event.facing,"spin":-1.5 if i%2==0 else 1.5,"life":0.65})
		if event.type==&"beam":
			var life: float = event.get("life",0.4)*EFFECT_SETTINGS.number("","visible_time_scale",1.0)
			_mutiny_beams.append({"from":event.from,"to":event.to,"width":event.width,"life":life,"max":life,"color":event.get("color",Color(1,0.95,0.6))})
		if event.type==&"telescope_charge": _rings.append({"pos":event.pos,"radius":30.0,"color":Color(1.0,0.4,0.3),"life":0.2,"max":0.2})
		if event.type==&"telescope_fire":
			var direction := Vector2.from_angle(event.angle)
			_telescope_beams.append({"from":event.pos,"to":event.pos+direction*event.length,"width":event.width*1.6,"life":0.28,"max":0.28})
			_rings.append({"pos":event.pos,"radius":40.0,"color":Color(1.0,0.75,0.6),"life":0.22,"max":0.22})
			_burst(event.pos,Color(1.0,0.5,0.35),10,500.0,direction)

		if event.type==&"flood_end":
			var tail: Dictionary = preload("res://scripts/render/attacks/flood.gd").frame_create(_scope)
			_layer(11).add_child(tail.node)
			if pipeline!=null and not pipeline.rich: tail.node.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
			preload("res://scripts/render/attacks/flood.gd").frame_apply(tail,{"points":PackedVector2Array([event.pos]),"widths":PackedFloat32Array([event.width]),"angle":event.angle,"length":event.length,"spread":event.spread,"order":event.row,"margin":event.margin})
			tail.tail = true
			tail.age = event.age
			tail.life = event.tail
			tail.collapse = event.collapse
			_flood_tails.append(tail)
		if event.type==&"attack_visual_end":
			var library: Resource = _scope.resources.get("res://.content/attack_visuals.res")
			if library!=null:
				var layers: Dictionary = library.get_meta("looks",{}).get(event.get("scene",""),{})
				var phase: String = event.phase
				_attack_ends.append({"mesh":layers.get(phase),"sprites":layers.get(phase+"_sprites",[]),"pos":event.pos,"duration":event.get("duration",0.25 if phase=="Hit" else 0.2),"age":0.0,"tint":event.get("tint",Color.WHITE)})
		if event.type==&"explode":
			_rings.append({"pos":event.pos,"radius":event.radius,"color":event.color,"life":event.life,"max":event.life})
			if event.radius>=150.0 and pipeline!=null: pipeline.add_wave(event.pos,event.radius,0.4)
		if event.type==&"debris_trail" and event.get("life",0.0)>0.0:
			_debris_trails.append({"points":event.points,"life":event.life,"max":event.life})
		if event.type==&"ring":
			if _rings.size()>80: _rings.pop_front()
			var duration: float = event.life*EFFECT_SETTINGS.number("","visible_time_scale",1.0)
			_rings.append({"pos":event.pos,"radius":event.radius,"color":event.color,"life":duration,"max":duration})
		if event.type==&"gem_burst":
			if _rings.size()>80: _rings.pop_front()
			var duration: float = 0.3*EFFECT_SETTINGS.number("","visible_time_scale",1.0)
			_rings.append({"pos":event.pos,"radius":event.r*2.4,"color":Color("#ffe27a"),"life":duration,"max":duration})
			_burst(event.pos,Color("#ffd23f"),14,360.0)
		if event.type==&"ship_explode": _death_burst(event.pos)
		if equipped_full_burst: _full_burst_visual.frame_event(event,frame.ui.ship.ship_pos,frame.ui.ship.ship_heading,frame.ui.character_scale)
		if equipped_duplicator and event.type==&"duplicate": _duplicator_visual.on_event(event)
		if equipped_barrier and not barrier_from_state and event.type in [&"barrier_hit",&"barrier_restore"]: _barrier_visual.on_event(event)
		if equipped_rear: preload("res://scripts/render/equipment/rear.gd").frame_event(_rear_flashes,_rear_shells,event,frame.ui.ship.ship_heading,frame.ui.rear.mount)
		if equipped_scatter: preload("res://scripts/render/equipment/scatter.gd").frame_event(_scatter_flashes,event)
		if equipped_forward: preload("res://scripts/render/equipment/forward.gd").frame_event(_flashes,event)
	_queued_events.clear()
	var ui: Dictionary = frame.ui
	_dim_strength = float(ui.get("death_dim",0.0))
	_dim_rect = Rect2(frame.camera.center-frame.camera.half,frame.camera.half*2.0)
	_dim.queue_redraw()
	for display: Node in enemy_frames.values(): display.set_death_brightness(1.0-_dim_strength)
	var effect_dt := 0.0 if ui.get("presentation_frozen",not ui.input_enabled) else dt
	var flood_dt: float = 0.0 if _flood_world_time<0.0 else maxf(0.0,ui.world_time-_flood_world_time)
	_flood_world_time = ui.world_time
	for tail: Dictionary in _flood_tails:
		tail.age += flood_dt
		tail.node.queue_redraw()
		if tail.age>=tail.life: tail.node.queue_free()
	_flood_tails = _flood_tails.filter(func(tail: Dictionary): return tail.age<tail.life)
	var zone_dt: float = 0.0 if _zone_world_time<0.0 else maxf(0.0,ui.world_time-_zone_world_time)
	_zone_world_time = ui.world_time
	for bursts: BlastBursts in _zone_bursts.values(): bursts.step(zone_dt)
	for effect: Dictionary in _attack_ends: effect.age += effect_dt
	_attack_ends = _attack_ends.filter(func(effect: Dictionary): return effect.age<effect.duration)
	for trail: Dictionary in _debris_trails: trail.life -= effect_dt
	_debris_trails = _debris_trails.filter(func(trail: Dictionary): return trail.life>0.0)
	for effect: Dictionary in _shield_transfers: effect.life -= effect_dt
	_shield_transfers = _shield_transfers.filter(func(effect: Dictionary): return effect.life>0.0)
	_shield_transfer_canvas.queue_redraw()
	var shield := {"remaining":ui.ship.ship_shield_t if _ship_visible else 0.0,"position":_ship_visual_position,
		"angle":(ui.ship.ship_heading as Vector2).angle(),"clock":ui.world_time,"ship_radius":ui.ship_radius,
		"scale":ui.character_scale,"layer":_shield_layer}
	var shield_key: int = ui.get("ship_shield_visual",0)
	if shield.remaining>0.0 and visuals.has(shield_key):
		var entry: Dictionary = visuals[shield_key]
		var look := _scope.resources.get(entry.path) as EnemyLook
		if look!=null:
			shield.paint = look.painted_armors[entry.paint]
			shield.settings = entry.settings.duplicate()
			shield.settings.brightness = 1.0-_dim_strength
		else: shield.remaining = 0.0
	else: shield.remaining = 0.0
	preload("res://scripts/render/shield_visual.gd").equipped_frame(_shield_holder,shield)

	for p: Dictionary in _particles:
		p.pos += p.vel*effect_dt
		p.vel *= 1.0-2.5*effect_dt
		p.life -= effect_dt
	for shard: Dictionary in _meteor_shards:
		shard.pos += shard.vel*effect_dt
		shard.angle += shard.spin*effect_dt
		shard.life -= effect_dt
	_meteor_shards = _meteor_shards.filter(func(shard: Dictionary): return shard.life>0.0)
	for beam: Dictionary in _mutiny_beams: beam.life -= effect_dt
	_mutiny_beams = _mutiny_beams.filter(func(beam: Dictionary): return beam.life>0.0)
	for beam: Dictionary in _telescope_beams: beam.life -= effect_dt
	_telescope_beams = _telescope_beams.filter(func(beam: Dictionary): return beam.life>0.0)
	for ring: Dictionary in _rings: ring.life -= effect_dt
	_rings = _rings.filter(func(ring: Dictionary): return ring.life>0.0)
	_particles = _particles.filter(func(p: Dictionary): return p.life>0.0)
	_particle_canvas.queue_redraw()
	var active: bool = ui.input_enabled
	var world_dt: float = 0.0 if _forward_world_time<0.0 else maxf(0.0,ui.world_time-_forward_world_time)
	_forward_world_time = ui.world_time if equipped_forward else -1.0
	var draw_start := Time.get_ticks_usec() if perf.active else 0
	_effects.begin()
	preload("res://scripts/render/equipment/forward.gd").frame_draw(_flashes,_effects,world_dt,ui.ship.ship_pos,ui.ship.ship_heading,equipped_forward)
	var scatter_dt: float = 0.0 if _scatter_world_time<0.0 else maxf(0.0,ui.world_time-_scatter_world_time)
	_scatter_world_time = ui.world_time if equipped_scatter else -1.0
	preload("res://scripts/render/equipment/scatter.gd").frame_draw(_scatter_flashes,_effects,scatter_dt,ui.ship.ship_pos,ui.ship.ship_heading,equipped_scatter)
	var full_burst_dt: float = 0.0 if _full_burst_world_time<0.0 else maxf(0.0,ui.world_time-_full_burst_world_time)
	_full_burst_world_time = ui.world_time if equipped_full_burst else -1.0
	if _full_burst_visual!=null: _full_burst_visual.frame_tick(full_burst_dt,ui.ship.ship_pos+ui.ship.ship_heading*16.0*1.82*ui.character_scale,ui.full_burst_active,ui.world_time,_ship_visible)
	var duplicator_dt: float = 0.0 if _duplicator_world_time<0.0 else maxf(0.0,ui.world_time-_duplicator_world_time)
	_duplicator_world_time = ui.world_time if equipped_duplicator else -1.0
	if _duplicator_visual!=null: _duplicator_visual.frame_tick(duplicator_dt)
	var rampage_dt: float = 0.0 if _rampage_world_time<0.0 else maxf(0.0,ui.world_time-_rampage_world_time)
	_rampage_world_time = ui.world_time if equipped_rampage else -1.0
	if _rampage_visual!=null: _rampage_visual.frame_tick(rampage_dt,ui.ship.ship_pos,ui.ship.ship_heading,ui.character_scale,ui.draw.tracing,ui.rampage,ui.world_time,_ship_visible)
	var full_charge_dt: float = 0.0 if _full_charge_world_time<0.0 else maxf(0.0,ui.world_time-_full_charge_world_time)
	_full_charge_world_time = ui.world_time if equipped_full_charge else -1.0
	if _full_charge_visual!=null: _full_charge_visual.frame_tick(full_charge_dt,ui.ship.ship_pos,ui.ship.ship_heading,ui.full_charge.distance/ui.base_draw_length,ui.draw.tracing and _ship_visible)
	var barrier_dt: float = 0.0 if _barrier_world_time<0.0 else maxf(0.0,ui.world_time-_barrier_world_time)
	_barrier_world_time = ui.world_time if equipped_barrier else -1.0
	if _barrier_visual!=null: _barrier_visual.frame_tick(barrier_dt,ui.ship.ship_pos,ui.ship.ship_heading)
	var rear_dt: float = 0.0 if _rear_world_time<0.0 else maxf(0.0,ui.world_time-_rear_world_time)
	_rear_world_time = ui.world_time if equipped_rear else -1.0
	preload("res://scripts/render/equipment/rear.gd").frame_draw(_rear_flashes,_rear_shells,_effects,rear_dt,ui.rear.mount,ui.rear.aim,equipped_rear)
	_effects.end()
	perf.since(&"view_geometry.attacks",draw_start)
	if active and not ui.draw.drawing and ui.hitstop<=0.0:
		_jet_time += dt*clampf(ui.ship_vel.length()/ui.base_max_speed,0.0,3.0)
	for sprite in [_flame,_spark]:
		sprite.position = ui.ship.ship_pos
		sprite.rotation = ui.ship.ship_heading.angle()+PI/2.0
		sprite.frame = int(_jet_time*12.0)%3
		sprite.visible = ui.phase==0 or ui.phase==4

func _death_burst(at: Vector2) -> void:
	_burst(at,Color("#9fe8ff"),60,500.0)

func _burst(at: Vector2,color: Color,count: int,speed: float,direction := Vector2.ZERO) -> void:
	if pipeline!=null and pipeline.sparks.available():
		pipeline.sparks.burst(at,color,count*2,direction,speed,0.7,5.0)
		return
	if _particles.size()>500: return
	for i in mini(count,8):
		var angle := randf()*TAU
		var velocity := speed*(0.3+randf())
		_particles.append({"pos":at,"vel":Vector2.from_angle(angle)*velocity*0.6+direction*speed*0.4,"life":0.5+randf()*0.4,"max":0.9,"color":color,"size":2.0+randf()*4.0})

func _timed_shape(canvas: CanvasItem, original: Callable) -> void:
	var began := Time.get_ticks_usec() if perf.active else 0
	original.call(canvas)
	perf.since(&"view_draw.attacks",began)

func _zone_burst(row: Dictionary) -> void:
	if row.zone_style<5 or row.time<row.delay or _zone_seen.get(row.order,0)==row.owner_id: return
	_zone_seen[row.order] = row.owner_id
	var style: int = row.zone_style
	var key: String = "enemy/phoenix" if style==5 else "res://scenes/attacks/zone_%s.tscn" % ("bomber" if style==6 else "pump")
	var fixed: Dictionary = preload("res://scripts/render/fx/burst_runtime.gd").profile(key,false)
	var effect_scale: float = float(fixed.get("effect_scale",1.0))
	if not _zone_bursts.has(style):
		var bursts := BlastBursts.new()
		bursts.key = key
		if style==6: bursts.shader = preload("res://shaders/bomber_burst.gdshader")
		bursts.setup(_pixel*float(fixed.get("pixel_scale",1.0)))
		bursts.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_layer(14).add_child(bursts)
		_zone_bursts[style] = bursts
	var bursts: BlastBursts = _zone_bursts[style]
	bursts.add(row.points[0],row.widths[0]/bursts.px*effect_scale,row.delay-row.time)
	bursts.step(0.0)
