## RenderFrameの値だけを描画へ渡す。敵表や武器の実体は参照しない。
extends Node2D
const VISUAL_ROLE = preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.VisualRole
const SHAPE_KIND = preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.RenderShapeKind
const EFFECT_SETTINGS = preload("res://data/visuals/effect_settings.tres")
const COMET_VISUAL := preload("res://scripts/render/comet_visual.gd")
var perf := PerfLog.new()
var boss_hit_feedback := preload("res://scripts/bosses/boss_hit_feedback.gd").new()
var metrics_record := {}
var visuals: Dictionary = {}
var _elite_deaths := preload("res://scripts/render/elite_deaths.gd").new()
var batches: Dictionary = {}
var parts: Dictionary = {}
var enemy_frames: Dictionary = {}
var _layers: Dictionary = {}
var _lines: Array[Line2D] = []
var _shape_displays: Dictionary = {}
var _wave_displays: Dictionary = {}
var _arrow_displays: Dictionary = {}
var _draco_beam_displays := {}
var _debris_displays: Dictionary = {}
var _critical_lances: Node2D
var _lance_flashes: Array = []
var _lance_hits: Array = []
var ruler_shake:=0.0
var _ruler:=PackedFloat64Array()
var _triangle_star := PackedFloat64Array()
var _cepheus := {"values":PackedFloat64Array(),"marks":PackedFloat64Array()}
var _hero_fire_canvas: DrawLayer
var _hero_power_visual: Node2D
var _hero_canvas: DrawLayer
var _hero_frame := {}
var _hero_aura: MeshInstance2D
var _hero_material: ShaderMaterial
var _corona := PackedFloat64Array()
var _corona_members := PackedFloat64Array()
var _aquila := PackedFloat64Array()
var _aquila_view := Rect2()
var _crab := PackedFloat32Array()
var _bomber := PackedFloat32Array()
var _cross := PackedFloat32Array()
var _aquarius := PackedFloat32Array()
var _flood_groups: Dictionary = {}
var _shell_displays: Dictionary = {}
var _lance_effects := {}
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
var _enemy_health := PackedFloat32Array()
var _enemy_weak := PackedFloat32Array()
var _gunner := PackedFloat32Array()
var _beamer := PackedFloat32Array()
var _missile := PackedFloat32Array()
var _battleship := PackedFloat32Array()
var _crows := {}
var _crow_canvas: DrawLayer
var _comets := {}
var _capsules := {}
var _comet_canvas: DrawLayer
var _capsule_canvas: DrawLayer
var _warp := {}
var _gravity := {}
var _gravity_canvas: DrawLayer
var _reticle := PackedFloat32Array()
var _soldier := PackedFloat32Array()
var _mutiny_beams: Array[Dictionary] = []
var _lynx := PackedFloat32Array()
var _dolphin := PackedFloat32Array()
var _sniper := PackedFloat32Array()
var _sniper_world_time := 0.0
var _telescope_beams: Array[Dictionary] = []
var _pulser_visual: EnemyVisual
var _pulser_parent: Node2D
var _phoenix_visual: EnemyVisual
var _picaro_sprites := {}
var _picaro_material: ShaderMaterial
const BOSS_FINAL_BEAM := preload("res://scenes/render/boss_final_beam.tscn")
var _boss_final_beams := {}
var _boss_body_displays := {}
var _boss_technique_visual: Node2D
var _boss_lance_visual: Node2D
var _boss_wave_visual: Node2D
var _boss_sword_visual: Node2D
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
var _kill_sonic_visual: RefCounted
var _slash_world_time := -1.0
var _slash_visual: RefCounted
var _afterimage_clock := -1.0
var _afterimage_visual: RefCounted
var _escort_world_time := -1.0
var _escort_visual: RefCounted
var _interceptor_world_time := -1.0
var _interceptor_visual: RefCounted
var _bipolar_world_time := -1.0
var _bipolar_visual: RefCounted
var _mass_tow_world_time := -1.0
var _mass_tow_visual: RefCounted
var _contact_arc_visual: RefCounted
var _sonic_visual: RefCounted
var _sonic_world_time := -1.0
var _contact_wave_visual: RefCounted
var _contact_wave_world_time := -1.0
var _knockback_visual: RefCounted
var _knockback_world_time := -1.0
var _vortex_visual: RefCounted
var _vortex_world_time := -1.0
var _mines_visual: RefCounted
var _mines_world_time := -1.0
var _mines_overlay: Sprite2D
var _run_up_visual: RefCounted
var _run_up_world_time := -1.0
var _end_blast_visual: RefCounted
var _end_blast_world_time := -1.0
var _full_burst_visual: RefCounted
var _full_burst_world_time := -1.0
var _duplicator_visual: RefCounted
var _duplicator_world_time := -1.0
var _scatter_world_time := -1.0
var _forward_world_time := -1.0
var _queued_events: Array[Dictionary] = []
var _epoch := 0
var _jet_time := 0.0
var finish_settings := {}
var finish_shake := 0.0
var finish_flash := 0.0
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
var _finale_overlay: Dictionary={}
var _finale_rect:=Rect2()
var _particle_canvas: Node2D
var _dim: Node2D
var _dim_strength := 0.0
var _dim_rect := Rect2()

var _flame: Sprite2D
var _spark: Sprite2D
var build_us := 0
var submit_us := 0
## 制作画面だけが表示用の行・時計を差し替える。C++の状態へ書き戻さない。
var authoring_frame: Callable
var authoring_clock := -1.0
var authoring_paused := false
var landmark_aura: Node2D
var elite_crackle: Node2D
var _mark_clock := 0.0

func setup(scope: ContentResourceScope, entries: Array[Dictionary], character_scale: float) -> void:
	metrics_record = perf.open(&"metrics")
	_scope = scope
	_pixel = 1.82*character_scale
	landmark_aura = preload("res://scripts/render/landmark_aura.gd").new()
	landmark_aura.z_index = -2
	add_child(landmark_aura)
	landmark_aura.setup(scope)
	for entry in entries: visuals[int(entry.id)] = entry
	add_child(_elite_deaths)
	_elite_deaths.setup(scope,visuals)
	for entry: Dictionary in entries:
		if entry.role==6: _shield_layer = maxi(_shield_layer,int(entry.id)-3)
	var mark_layer := CanvasLayer.new()
	mark_layer.layer = _shield_layer+1
	mark_layer.follow_viewport_enabled = true
	add_child(mark_layer)
	elite_crackle = preload("res://scripts/render/elite_crackle.gd").new()
	mark_layer.add_child(elite_crackle)
	elite_crackle.setup(scope)
	_hero_power_visual = preload("res://scripts/render/equipment/heroes.gd").new()
	_layer(9).add_child(_hero_power_visual)
	_hero_fire_canvas = DrawLayer.new()
	_hero_fire_canvas.draw_fn = _hero_power_visual.draw_fire
	_layer(2).add_child(_hero_fire_canvas)
	_hero_canvas = DrawLayer.new()
	_hero_canvas.draw_fn = _draw_hero_values
	_layer(2).add_child(_hero_canvas)
	_hero_aura = MeshInstance2D.new()
	_hero_aura.show_behind_parent = true
	var hero_aura: HeroAuraAssets = _scope.resources.get("res://.content/hero_aura.res")
	if hero_aura!=null:
		_hero_aura.mesh = hero_aura.mesh
		_hero_material = hero_aura.material.duplicate() as ShaderMaterial
		_hero_aura.material = _hero_material
	_layer(2).add_child(_hero_aura)

	_barrier_armor = Sprite2D.new()
	_barrier_armor.texture = _scope.resources.get("res://assets/pixel/airship_armor.png")
	_barrier_armor.offset = Vector2(0.0,_barrier_armor.texture.get_height()*0.5-30.0) if _barrier_armor.texture!=null else Vector2.ZERO
	_barrier_armor.scale = Vector2.ONE*character_scale
	_barrier_armor.hide()
	_layer(18).add_child(_barrier_armor)
	_mines_overlay = Sprite2D.new()
	_mines_overlay.texture = _scope.resources.get("res://assets/pixel/airship_mine.png")
	_mines_overlay.offset = Vector2(0.0,_mines_overlay.texture.get_height()*0.5-30.0) if _mines_overlay.texture!=null else Vector2.ZERO
	_mines_overlay.scale = Vector2.ONE*character_scale
	_mines_overlay.hide()
	_layer(18).add_child(_mines_overlay)
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
	_boss_technique_visual = preload("res://scripts/bosses/monoceros/technique_visual.gd").new()
	marlin_parent.add_child(_boss_technique_visual)
	_boss_lance_visual = preload("res://scripts/bosses/monoceros/lance_visual.gd").new()
	marlin_parent.add_child(_boss_lance_visual)
	_boss_wave_visual = preload("res://scripts/bosses/monoceros/horn_wave_visual.gd").new()
	marlin_parent.add_child(_boss_wave_visual)
	_boss_sword_visual = preload("res://scripts/bosses/monoceros/sword_flash_visual.gd").new()
	marlin_parent.add_child(_boss_sword_visual)
	_marlin_visual = preload("res://scripts/render/enemies/marlin.gd").new()
	_marlin_visual.setup_frame(marlin_parent)
	_phoenix_visual = preload("res://scripts/render/enemies/phoenix.gd").new()
	_phoenix_visual.setup_frame(marlin_parent)
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

	_crow_canvas = DrawLayer.new()
	_crow_canvas.draw_fn = func(canvas: CanvasItem):
		var values: PackedFloat32Array = _crows.get("values",PackedFloat32Array())
		for n in range(0,values.size(),6): preload("res://scripts/render/enemies/crow.gd").draw_bundle(canvas,Vector2(values[n],values[n+1]),values[n+2],values[n+3],values[n+4],int(values[n+5]),_crows.time,_pixel)
	_layer(9).add_child(_crow_canvas)
	_comet_canvas = DrawLayer.new()
	_comet_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_comet_canvas.draw_fn = func(canvas: CanvasItem):
		var values: PackedFloat32Array = _comets.get("values",PackedFloat32Array())
		for n in range(0, values.size(), 7):
			COMET_VISUAL.draw(canvas, Vector2(values[n], values[n+1]), values[n+2], Vector2(values[n+3], values[n+4]), values[n+5] > 0.0, values[n+6])
	_layer(8).add_child(_comet_canvas)
	_capsule_canvas = DrawLayer.new()
	_capsule_canvas.z_index = 1
	_capsule_canvas.draw_fn = func(canvas: CanvasItem):
		var values: PackedFloat32Array = _capsules.get("values",PackedFloat32Array())
		for n in range(0,values.size(),3): RunPresentation.draw_capsule_values(canvas,Vector2(values[n],values[n+1]),int(values[n+2]),_capsules.time)
	_layer(6).add_child(_capsule_canvas)
	_gravity_canvas = DrawLayer.new()
	_gravity_canvas.draw_fn = func(canvas: CanvasItem):
		if _warp.get("gone",-1.0)>=0.0: RunPresentation.draw_warp(canvas,_warp.position,_warp.radius,_warp.time,1.0/maxf(_zoom,0.01))
		var values: PackedFloat64Array = _gravity.get("wells",PackedFloat64Array())
		for n in range(0,values.size(),5): RunPresentation.draw_gravity(canvas,Vector2(values[n],values[n+1]),values[n+2],values[n+3],values[n+4],_gravity.time,1.0/maxf(_zoom,0.01))
	_layer(1).add_child(_gravity_canvas)
	_gunner_marks = DrawLayer.new()
	_gunner_marks.draw_fn = func(canvas: CanvasItem):
		var began := Time.get_ticks_usec() if perf.active else 0
		preload("res://scripts/render/enemies/gunner.gd").draw_frame(canvas,_gunner,_pixel)
		preload("res://scripts/render/enemies/beamer.gd").draw_frame(canvas,_beamer,_pixel)
		preload("res://scripts/render/enemies/aquarius.gd").draw_frame(canvas,_aquarius,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/cross.gd").draw_frame(canvas,_cross,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/bomber.gd").draw_frame(canvas,_bomber,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/crab.gd").draw_frame(canvas,_crab,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/ruler.gd").draw_frame(canvas,_ruler,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/triangle_star.gd").draw_frame(canvas,_triangle_star,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/cepheus.gd").draw_frame(canvas,_cepheus,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/aquila.gd").draw_frame(canvas,_aquila,_aquila_view,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/corona.gd").draw_frame(canvas,_corona,_corona_members)
		preload("res://scripts/render/enemies/missile.gd").draw_frame(canvas,_missile,_pixel)
		preload("res://scripts/render/enemies/battleship.gd").draw_frame(canvas,_battleship,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/reticle.gd").draw_frame(canvas,_reticle,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/soldier.gd").draw_frame(canvas,_soldier,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/lynx.gd").draw_frame(canvas,_lynx,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/dolphin.gd").draw_frame(canvas,_dolphin,1.0/maxf(_zoom,0.01))
		preload("res://scripts/render/enemies/sniper.gd").draw_frame(canvas,_sniper,_sniper_world_time,1.0/maxf(_zoom,0.01))
		for n in range(0,_enemy_weak.size(),5):
			canvas.draw_arc(Vector2(_enemy_weak[n],_enemy_weak[n+1]),_enemy_weak[n+2]+2.0/maxf(_zoom,0.01),_enemy_weak[n+3]+PI-_enemy_weak[n+4],_enemy_weak[n+3]+PI+_enemy_weak[n+4],12,Color("#ffe46b"),3.0/maxf(_zoom,0.01))
		for n in range(0,_enemy_health.size(),4):
			var width := _enemy_health[n+2]*1.6
			var top := Vector2(_enemy_health[n]-width*0.5,_enemy_health[n+1]-_enemy_health[n+2]-10.0/maxf(_zoom,0.01))
			canvas.draw_rect(Rect2(top,Vector2(width,4.0/maxf(_zoom,0.01))),Color(0,0,0,0.6))
			canvas.draw_rect(Rect2(top,Vector2(width*_enemy_health[n+3],4.0/maxf(_zoom,0.01))),Color("#ff6b5a"))
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
			if trail.points.size()>1: _particle_canvas.draw_polyline(trail.points,Color(1.0,0.6,0.25,0.6*trail.life/trail.max),3.0/maxf(_zoom,0.01))
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
		_particle_canvas.draw_set_transform(Vector2.ZERO)
		_draw_finale_overlay())
	_dim = Node2D.new()
	_layer(16).add_child(_dim)
	_dim.draw.connect(func():
		if _dim_strength>0.0: _dim.draw_rect(_dim_rect.grow(400.0),Color(0,0,0,_dim_strength))
		if finish_flash>0.0: _dim.draw_rect(_dim_rect.grow(400.0),Color(1,1,1,finish_flash*0.5)))
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

## 実験場の明示した外観編集だけ、新しい表示資源へ切り替える。
## 停止して保持した別Sessionの資源や描画実体は変更しない。
func replace_lab_visuals(scope: ContentResourceScope, entries: Array[Dictionary]) -> void:
	_scope = scope
	for entry: Dictionary in entries:
		var id: int = entry.id
		if visuals.get(id,{})==entry: continue
		visuals[id] = entry.duplicate(true)
		if enemy_frames.has(id):
			enemy_frames[id].queue_free()
			enemy_frames.erase(id)
		if batches.has(id):
			batches[id].queue_free()
			batches.erase(id)

func _batch(id: int, layer: int) -> InstanceBatch:
	if batches.has(id): return batches[id]
	var entry: Dictionary = visuals[id]
	var batch: InstanceBatch
	if entry.role==2:
		batch = preload("res://scripts/render/attacks/friend_shot.gd").create_batch(_pixel)
		batch.visibility_layer = 1|RenderPipeline.GLOW_LAYER
		batch.modulate = RenderPipeline.plain_color(_layer(layer))
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
	if frame.has("enemy_weak"):
		if not frame.enemy_weak is PackedFloat32Array or frame.enemy_weak.size()%5: return false
		for value: float in frame.enemy_weak:
			if not is_finite(value): return false
	if frame.has("enemy_health"):
		if not frame.enemy_health is PackedFloat32Array or frame.enemy_health.size()%4: return false
		for value: float in frame.enemy_health:
			if not is_finite(value): return false
	if frame.has("petrified_enemies"):
		if not frame.petrified_enemies is PackedFloat32Array or frame.petrified_enemies.size()%3: return false
		for value: float in frame.petrified_enemies:
			if not is_finite(value): return false
	if frame.get("schema_version")!=1 or not frame.get("batches") is Array or not frame.get("shapes") is Array or not frame.get("poses") is Array: return false
	if frame.has("boss_bodies"):
		if not frame.boss_bodies is Array: return false
		for body in frame.boss_bodies:
			if not body is Dictionary or not body.get("mode") is int or body.mode<0 or body.mode>5 or not body.get("kind") is int: return false
			if body.mode<4:
				if not body.get("position") is Vector2 or not body.position.is_finite(): return false
				for key in ["facing","radius","hp","max_hp","clock","phase_progress","horn_length"]:
					if not (body.get(key) is float or body.get(key) is int) or not is_finite(float(body[key])): return false
	if frame.has("boss_techniques"):
		if not frame.boss_techniques is Array: return false
		for row in frame.boss_techniques:
			if not row is Dictionary or not row.get("stage") is int or row.stage<0 or row.stage>7: return false
			if row.has("position"):
				if not row.position is Vector2 or not row.position.is_finite(): return false
				for key in ["horn","warning"]:
					if not row.get(key) is PackedVector2Array or (row[key].size() not in [0,2] if key=="warning" and int(row.get("kind",0))>=96 else row[key].size()!=(0 if int(row.get("kind",0))>=8 else 2)): return false
					for point: Vector2 in row[key]:
						if not point.is_finite(): return false
	for key in ["comets","capsules","crows"]:
		if frame.has(key):
			var data = frame[key]
			var stride := 7 if key == "comets" else (3 if key == "capsules" else 6)
			if not data is Dictionary or not data.get("values") is PackedFloat32Array or data.values.size() % stride != 0: return false
			if key != "comets" and (not (data.get("time") is float or data.get("time") is int) or not is_finite(data.time)): return false
			for value: float in data.values:
				if not is_finite(value): return false
	if frame.has("warp"):
		var warp = frame.warp
		if not warp is Dictionary or not warp.get("position") is Vector2 or not warp.position.is_finite(): return false
		for key in ["gone","radius","time"]:
			if not (warp.get(key) is float or warp.get(key) is int) or not is_finite(warp[key]): return false
		if warp.radius<0.0: return false
	if frame.has("gravity"):
		var wells = frame.gravity
		if not wells is Dictionary or not wells.get("wells") is PackedFloat64Array or wells.wells.size()%5!=0 or not (wells.get("time") is float or wells.get("time") is int) or not is_finite(wells.time): return false
		for value: float in wells.wells:
			if not is_finite(value): return false
		for n in range(0,wells.wells.size(),5):
			if wells.wells[n+3]<=0.0 or wells.wells[n+4]<0.0: return false
	if frame.has("pulser"):
		if not frame.pulser is PackedFloat64Array or frame.pulser.size()%6!=0: return false
		for value in frame.pulser:
			if not is_finite(value): return false
	if frame.has("ruler"):
		if not frame.ruler is PackedFloat64Array or frame.ruler.size()%12!=0: return false
		for value: float in frame.ruler:
			if not is_finite(value): return false
	if frame.has("triangle_star"):
		if not frame.triangle_star is PackedFloat64Array or frame.triangle_star.size()%5!=0: return false
		for value: float in frame.triangle_star:
			if not is_finite(value): return false
	if frame.has("cepheus"):
		if not frame.cepheus is Dictionary: return false
		for pair in [["values",5],["marks",10]]:
			var values = frame.cepheus.get(pair[0])
			if not values is PackedFloat64Array or values.size()%int(pair[1])!=0: return false
			for value: float in values:
				if not is_finite(value): return false
	for pair in [["corona",7],["corona_members",10]]:
		if not frame.has(pair[0]): continue
		var values = frame[pair[0]]
		if not values is PackedFloat64Array or values.size()%int(pair[1])!=0: return false
		for value: float in values:
			if not is_finite(value): return false
	if frame.has("aquila"):
		var data = frame.aquila
		if not data is Dictionary or not data.get("values") is PackedFloat64Array or not data.get("view") is Rect2 or data.values.size()%9!=0: return false
		for value: float in data.values:
			if not is_finite(value): return false
		for i in range(0,data.values.size(),9):
			if data.values[i+6]<=0.0: return false
	if frame.has("phoenix"):
		if not frame.phoenix is PackedFloat64Array or frame.phoenix.size()%7!=0: return false
		for value: float in frame.phoenix:
			if not is_finite(value): return false
	if frame.has("marlin"):
		var data = frame.marlin
		if not data is Dictionary or not data.get("ids") is PackedInt64Array or not data.get("values") is PackedFloat64Array or not data.get("view") is Rect2 or data.values.size()!=data.ids.size()*14: return false
		for value: float in data.values:
			if not is_finite(value): return false
	for row in frame.batches:
		if not row is Dictionary or not visuals.has(row.get("visual_id")) or not row.get("ids") is PackedInt64Array or not row.get("transforms") is PackedFloat32Array or not row.get("colors") is PackedColorArray or not row.get("flags") is PackedInt32Array: return false
		var count: int = row.ids.size()
		if row.has("marks"):
			if not row.marks is PackedInt32Array or row.marks.size()!=count: return false
			for mark: int in row.marks:
				if mark<0 or mark>3: return false
		if visuals[row.visual_id].get("ruler",false):
			if not row.get("ruler_sides") is PackedInt32Array or row.ruler_sides.size()!=count: return false
			for side: int in row.ruler_sides:
				if side< -1 or side>1: return false
		if row.transforms.size()!=count*6 or row.colors.size()!=count or row.flags.size()!=count: return false
		if visuals[row.visual_id].role==6 and visuals[row.visual_id].get("biting",false):
			if not row.get("biter") is Dictionary: return false
			for key in ["modes","charges","timers","rests"]:
				if not row.biter.has(key) or row.biter[key].size()!=count: return false
		if row.has("beamer"):
			if not row.beamer is PackedFloat32Array or row.beamer.size()%10!=0: return false
			for value: float in row.beamer:
				if not is_finite(value): return false
		if row.has("reticle"):
			if not row.reticle is PackedFloat32Array or row.reticle.size()%12!=0: return false
			for value: float in row.reticle:
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
		if row.has("pump"):
			if not row.pump is PackedFloat32Array or row.pump.size()!=count*9: return false
			for value: float in row.pump:
				if not is_finite(value): return false
		if row.has("crab"):
			if not row.crab is PackedFloat32Array or row.crab.size()%14!=0: return false
			for value: float in row.crab:
				if not is_finite(value): return false
		if row.has("bomber"):
			if not row.bomber is PackedFloat32Array or row.bomber.size()%5!=0: return false
			for value: float in row.bomber:
				if not is_finite(value): return false
		if row.has("cross"):
			if not row.cross is PackedFloat32Array or row.cross.size()%9!=0: return false
			for value: float in row.cross:
				if not is_finite(value): return false
		if row.has("aquarius"):
			if not row.aquarius is PackedFloat32Array or row.aquarius.size()%5!=0: return false
			for value: float in row.aquarius:
				if not is_finite(value): return false
		if row.has("glows"):
			if not row.glows is PackedFloat32Array or row.glows.size()%3!=0: return false
			for value: float in row.glows:
				if not is_finite(value): return false
		for flag: int in row.flags:
			var maximum := 3 if visuals[row.visual_id].role==2 else 2 if visuals[row.visual_id].get("iron",false) else 1
			if flag<0 or flag>maximum: return false
	for row in frame.shapes:
		if not row is Dictionary or row.get("kind") not in [SHAPE_KIND.Polyline,SHAPE_KIND.Circle,SHAPE_KIND.Wave,SHAPE_KIND.Blast,SHAPE_KIND.LightArrow,SHAPE_KIND.FriendDebris,SHAPE_KIND.FriendHull,SHAPE_KIND.Zone,SHAPE_KIND.Flood,SHAPE_KIND.Shell] or not row.get("points") is PackedVector2Array or not row.get("offsets") is PackedInt32Array or not row.get("widths") is PackedFloat32Array or not row.get("colors") is PackedColorArray: return false
		if not row.get("owner_id") is int or not row.get("layer") is int or not row.get("order") is int or row.owner_id<0: return false
		if row.offsets.size()<2 or row.offsets[0]!=0 or row.offsets[-1]!=row.points.size() or row.widths.size()!=row.offsets.size()-1 or row.colors.size()!=row.widths.size(): return false
		if row.kind==SHAPE_KIND.Shell:
			if row.points.size()!=1 or row.widths.size()!=1 or not row.get("mouth") is Vector2 or not row.mouth.is_finite() or not row.get("contents") is PackedInt32Array: return false
			for id: int in row.contents:
				if not visuals.has(id): return false
			for key in ["angle","clock","flight_scale","full","petrified_radius"]:
				if not row.get(key) is float or not is_finite(row[key]): return false
		if row.kind==SHAPE_KIND.Flood:
			if row.points.size()!=1 or row.widths.size()!=1 or not row.get("effect_group") is int or row.effect_group<0: return false
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
		if row.get("draco_beam",false):
			if row.kind!=SHAPE_KIND.Polyline or row.points.size()!=1 or row.widths.size()!=1: return false
			for key in ["time","delay","active","angle","length","clock"]:
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

## 表示の本体と同じFrameから、輪郭・顎・ポンプ・分離形態を読む。
func _update_marks(frame: Dictionary) -> void:
	var clock := authoring_clock if authoring_clock >= 0.0 else _mark_clock
	landmark_aura.begin()
	elite_crackle.begin(clock)
	for row: Dictionary in frame.batches:
		var marks: PackedInt32Array = row.get("marks",PackedInt32Array())
		if marks.is_empty(): continue
		var entry: Dictionary = visuals[row.visual_id]
		var look: EnemyLook = _scope.resources.get(entry.get("path","")) as EnemyLook
		for i in row.ids.size():
			if marks[i] == 0: continue
			var n: int = i*6
			var pose := Transform2D(Vector2(row.transforms[n],row.transforms[n+1]),Vector2(row.transforms[n+2],row.transforms[n+3]),Vector2(row.transforms[n+4],row.transforms[n+5]))
			var key: String = look.source_path if look != null else entry.get("mark_key","")
			if look != null and look.split_other != null:
				var side: int = row.get("ruler_sides",PackedInt32Array())[i] if row.has("ruler_sides") else 0
				if side == 1:
					key = look.split_other.source_path
					pose = pose*Transform2D(look.split_other.angle-look.angle,Vector2.ZERO)
				elif side == 0: key += ":joined"
			var body := {"id":int(row.ids[i]),"key":key,"pose":pose}
			if row.has("pump"):
				var pump: PackedFloat32Array = row.pump
				body.pump_full = pump[i*9+4]
				body.pose = Transform2D(pump[i*9+2],pose.origin).scaled_local(Vector2.ONE*pump[i*9+3]*18.5)
			if row.has("biter") and not String(entry.get("biter_parts","")).is_empty():
				var source: Resource = _scope.resources.get(entry.biter_parts)
				var parts: Array = []
				var values: Dictionary = row.biter
				var jaw := deg_to_rad(preload("res://scripts/render/run_enemy_frame.gd").jaw_angle(values.modes[i],values.charges[i],values.timers[i],values.rests[i]))
				var radius: float = row.deformations[i*5] if row.has("deformations") else pose.x.length()
				var angle: float = row.deformations[i*5+1] if row.has("deformations") else pose.x.angle()
				for part: Dictionary in source.get_meta("parts",[]):
					var turn := jaw if part.name=="jaw_left" else -jaw if part.name=="jaw_right" else 0.0
					var pivot: Vector2 = (part.pivot-Vector2(10,17))*(radius/17.0)
					var center := pose.origin+(pivot-pivot.rotated(turn)).rotated(angle)
					var part_pose := Transform2D(angle+turn,center).scaled_local(Vector2.ONE*(radius/17.0))
					if row.has("deformations"):
						var d: PackedFloat32Array = row.deformations
						var normal := Vector2(d[i*5+2],d[i*5+3]).normalized()
						var side := normal.orthogonal()
						for column in 2: part_pose[column] = normal*part_pose[column].dot(normal)*(1.0-0.5*d[i*5+4])+side*part_pose[column].dot(side)*(1.0+0.6*d[i*5+4])
					part_pose.origin -= part_pose.basis_xform(Vector2(10,17))
					parts.append(part_pose)
				body.parts = parts
			if (marks[i]&1)!=0: landmark_aura.add_body(body,clock)
			if (marks[i]&2)!=0: elite_crackle.add_body(body)
	elite_crackle.end()

func apply_frame(frame: Dictionary) -> bool:
	if authoring_frame.is_valid(): frame = authoring_frame.call(frame)
	var begin := Time.get_ticks_usec()
	if not _valid(frame): return false
	_hero_power_visual.petrified = frame.get("petrified_enemies",PackedFloat32Array())
	_hero_power_visual.queue_redraw()
	_update_marks(frame)
	var weak: PackedFloat32Array = frame.get("enemy_weak",PackedFloat32Array())
	if weak!=_enemy_weak:
		_enemy_weak = weak
		_gunner_marks.queue_redraw()
	var health: PackedFloat32Array = frame.get("enemy_health",PackedFloat32Array())
	if health!=_enemy_health:
		_enemy_health = health
		_gunner_marks.queue_redraw()
	var next_shots := {}
	for row: Dictionary in frame.batches:
		if visuals[row.visual_id].role==2: next_shots[row.visual_id] = {"transforms":row.transforms,"flags":row.flags}
	var unchanged_shots := {}
	for id in visuals:
		if visuals[id].role==2 and next_shots.get(id,{})==_shot_transforms.get(id,{}): unchanged_shots[id] = true
	_shot_transforms = next_shots
	for id in batches:
		if not unchanged_shots.has(id): batches[id].begin()
	for display: Node in enemy_frames.values(): display.begin()
	for node: Sprite2D in parts.values(): node.hide()
	for line in _lines: line.hide()
	var previous_crab := _crab
	var previous_bomber := _bomber
	var previous_cross := _cross
	var previous_aquarius := _aquarius
	var previous_gunner := _gunner
	var previous_beamer := _beamer
	var previous_missile := _missile
	var previous_battleship := _battleship
	var previous_reticle := _reticle
	var previous_soldier := _soldier
	var previous_lynx := _lynx
	var previous_dolphin := _dolphin
	var previous_sniper := _sniper
	_crab = PackedFloat32Array()
	_bomber = PackedFloat32Array()
	_cross = PackedFloat32Array()
	_aquarius = PackedFloat32Array()
	_gunner = PackedFloat32Array()
	_beamer = PackedFloat32Array()
	_missile = PackedFloat32Array()
	_battleship = PackedFloat32Array()
	_reticle = PackedFloat32Array()
	_soldier = PackedFloat32Array()
	_lynx = PackedFloat32Array()
	_dolphin = PackedFloat32Array()
	_sniper = PackedFloat32Array()
	for row: Dictionary in frame.batches:
		if row.has("crab"): _crab.append_array(row.crab)
		if row.has("bomber"): _bomber.append_array(row.bomber)
		if row.has("cross"): _cross.append_array(row.cross)
		if row.has("aquarius"): _aquarius.append_array(row.aquarius)
		if row.has("gunner"): _gunner.append_array(row.gunner)
		if row.has("beamer"): _beamer.append_array(row.beamer)
		if row.has("missile"): _missile.append_array(row.missile)
		if row.has("battleship"): _battleship.append_array(row.battleship)
		if row.has("reticle"): _reticle.append_array(row.reticle)
		if row.has("soldier"): _soldier.append_array(row.soldier)
		if row.has("lynx"): _lynx.append_array(row.lynx)
		if row.has("dolphin"): _dolphin.append_array(row.dolphin)
		if row.has("sniper"): _sniper.append_array(row.sniper)
	# 描画命令はCanvasItemが保持する。変わらない予告は再構築しない。
	if _crab!=previous_crab or _bomber!=previous_bomber or _cross!=previous_cross or _aquarius!=previous_aquarius or _gunner!=previous_gunner or _beamer!=previous_beamer or _missile!=previous_missile or _battleship!=previous_battleship or _sniper!=previous_sniper or _dolphin!=previous_dolphin or _lynx!=previous_lynx or _soldier!=previous_soldier or _reticle!=previous_reticle: _gunner_marks.queue_redraw()
	var rows: Array = frame.batches.duplicate()
	rows.sort_custom(func(a,b): return a.layer<b.layer or (a.layer==b.layer and a.order<b.order))
	var packed_bytes := 0
	for row: Dictionary in rows:
		if perf.active:
			packed_bytes+=row.ids.size()*8+row.transforms.size()*4+row.colors.size()*16+row.flags.size()*4
			for key in ["gunner","beamer","missile","battleship","sniper","glows","ruler_sides"]: packed_bytes+=row.get(key,PackedFloat32Array()).size()*4
			if row.has("biter"):
				for key in row.biter: packed_bytes+=row.biter[key].size()*4
		if visuals[row.visual_id].role==6 or visuals[row.visual_id].get("iron",false):
			if not enemy_frames.has(row.visual_id):
				var display = preload("res://scripts/render/enemies/iron.gd").new() if visuals[row.visual_id].get("iron",false) else preload("res://scripts/render/run_enemy_frame.gd").new()
				if visuals[row.visual_id].get("iron",false): _layer(row.layer).add_child(display)
				else:
					add_child(display)
					display.perf = perf
				display.setup(_scope,visuals[row.visual_id])
				display.begin()
				enemy_frames[row.visual_id] = display
			if visuals[row.visual_id].get("iron",false) and enemy_frames[row.visual_id].get_parent()!=_layer(row.layer): enemy_frames[row.visual_id].reparent(_layer(row.layer))
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
	for display: Node in _draco_beam_displays.values(): display.hide()
	for display: Node in _debris_displays.values(): display.hide()
	for display: Node in _hull_displays.values(): display.hide()
	for display: Node in _zone_displays.values(): display.hide()
	for display: Node in _shell_displays.values(): display.hide()
	for display: Dictionary in _flood_displays.values(): display.node.hide()
	var flood_groups := {}
	var line_index := 0
	for row: Dictionary in frame.shapes:
		if perf.active: packed_bytes+=row.points.size()*8+row.offsets.size()*4+row.widths.size()*4+row.colors.size()*16
		var parent: Node2D = _layer(row.layer)
		if row.kind==SHAPE_KIND.Shell:
			var key := int(row.order)
			if not _shell_displays.has(key):
				var shell := preload("res://scripts/render/attacks/shell_frame.gd").new()
				parent.add_child(shell)
				shell.setup(_scope,visuals)
				_shell_displays[key] = shell
			_shell_displays[key].apply_frame(row)
			_shell_displays[key].show()
			continue
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
			var group: int = row.effect_group if row.effect_group>0 else row.owner_id
			flood_groups[group] = true
			if row.time>=row.delay and not water.fired:
				water.fired = true
				if not _flood_groups.has(group):
					_flood_groups[group] = true
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
		if row.get("draco_beam",false):
			var key:=int(row.order)
			if not _draco_beam_displays.has(key):
				var beam:=preload("res://scripts/render/attacks/beam_draco.gd").new()
				parent.add_child(beam)
				if pipeline!=null and not pipeline.rich:beam.visibility_layer=1|RenderPipeline.GLOW_LAYER
				_draco_beam_displays[key]=beam
			_draco_beam_displays[key].frame_apply(row,1.0/maxf(_zoom,0.01))
			_draco_beam_displays[key].show()
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
	for group in _flood_groups.keys():
		if not flood_groups.has(group): _flood_groups.erase(group)
	for display: Dictionary in _shape_displays.values():
		display.node.visible = display.used
		if display.circles!=display.previous_circles: display.node.queue_redraw()
	if frame.has("crows") and frame.crows!=_crows:
		_crows = frame.crows
		_crow_canvas.queue_redraw()
	if frame.has("comets") and frame.comets!=_comets:
		_comets = frame.comets
		_comet_canvas.queue_redraw()
	if frame.has("capsules") and frame.capsules!=_capsules:
		_capsules = frame.capsules
		_capsule_canvas.queue_redraw()
	if frame.has("warp") and frame.warp!=_warp:
		_warp = frame.warp
		_gravity_canvas.queue_redraw()
	if frame.has("gravity") and frame.gravity!=_gravity:
		_gravity = frame.gravity
		_gravity_canvas.queue_redraw()
	if frame.has("boss_techniques"):
		_boss_technique_visual.apply_frame(frame.boss_techniques)
		_boss_lance_visual.apply_frame(frame.boss_techniques,float(frame.boss_bodies[0].clock) if not frame.get("boss_bodies",[]).is_empty() else _sniper_world_time)
	if frame.has("boss_bodies"):
		var waves: Array = []
		for body: Dictionary in frame.boss_bodies: waves.append_array(body.get("horn_waves",[]))
		_boss_wave_visual.apply_frame(waves,float(frame.boss_bodies[0].clock) if not frame.boss_bodies.is_empty() else _sniper_world_time)
		_boss_sword_visual.apply_frame(float(frame.boss_bodies[0].clock) if not frame.boss_bodies.is_empty() else _sniper_world_time)
	_sync_cpp_boss_final_beams(frame.get("boss_bodies",[]))
	var body_seen := {}
	_sync_cpp_picaro(frame.get("boss_bodies",[]))
	for body: Dictionary in frame.get("boss_bodies",[]):
		if body.kind not in [0,1,2,3,4]: continue
		body_seen[body.id] = true
		if body.mode>=4:
			if _boss_body_displays.has(body.id):
				if body.kind==2: _boss_body_displays[body.id].clear_flames()
				_boss_body_displays[body.id].hide()
			continue
		var entry := {}
		for asset in visuals.values():
			if asset.get("boss","")==["monoceros","centaurus","canis_major","hydra","draco"][body.kind]: entry = asset; break
		if entry.is_empty(): continue
		if not _boss_body_displays.has(body.id):
			var scene: PackedScene = _scope.resources.get(entry.path)
			if scene==null: continue
			var display = scene.instantiate()
			display.set_script([preload("res://scripts/render/bosses/monoceros.gd"),preload("res://scripts/render/bosses/centaurus.gd"),preload("res://scripts/render/bosses/canis_major.gd"),preload("res://scripts/render/bosses/hydra.gd"),preload("res://scripts/render/bosses/draco.gd")][body.kind])
			_pulser_parent.add_child(display)
			if body.kind==2: display.setup_flames(_scope,visuals)
			if body.kind in [3,4]: display.setup_effects(_scope,visuals)
			if body.kind in [0,4]: display.hit_feedback = boss_hit_feedback
			_boss_body_displays[body.id] = display
		var attack := {}
		for value: Dictionary in frame.get("boss_techniques",[]):
			if value.actor==body.actor and value.stage<5: attack = value; break
		var display: Node2D = _boss_body_displays[body.id]
		var move := String(attack.get("technique",""))
		if display.get_meta("visual_move",null)!=move or display.get_meta("visual_revision",-1)!=EFFECT_SETTINGS.preview_revision:
			EFFECT_SETTINGS.apply_body(display,["monoceros","centaurus","canis_major","hydra","draco"][body.kind],move)
			display.set_meta("visual_move",move)
			display.set_meta("visual_revision",EFFECT_SETTINGS.preview_revision)
		display.apply_frame(body,attack,entry.get("appearance",{}))
	for id in _boss_body_displays.keys():
		if not body_seen.has(id):
			_boss_body_displays[id].queue_free()
			_boss_body_displays.erase(id)
	if frame.has("pulser"): _pulser_visual.apply_frame(_pulser_parent,frame.pulser)
	var ruler: PackedFloat64Array=frame.get("ruler",PackedFloat64Array())
	if ruler!=_ruler:
		_ruler=ruler
		_gunner_marks.queue_redraw()
	var triangle_star: PackedFloat64Array = frame.get("triangle_star",PackedFloat64Array())
	if triangle_star!=_triangle_star:
		_triangle_star=triangle_star
		_gunner_marks.queue_redraw()
	var cepheus: Dictionary = frame.get("cepheus",{"values":PackedFloat64Array(),"marks":PackedFloat64Array()})
	if cepheus!=_cepheus:
		_cepheus=cepheus
		_gunner_marks.queue_redraw()
	var next_corona: PackedFloat64Array = frame.get("corona",PackedFloat64Array())
	var next_corona_members: PackedFloat64Array = frame.get("corona_members",PackedFloat64Array())
	if next_corona!=_corona or next_corona_members!=_corona_members: _gunner_marks.queue_redraw()
	_corona = next_corona
	_corona_members = next_corona_members
	var previous_aquila := _aquila
	_aquila = frame.get("aquila",{}).get("values",PackedFloat64Array())
	_aquila_view = frame.get("aquila",{}).get("view",Rect2())
	if _aquila!=previous_aquila: _gunner_marks.queue_redraw()
	if frame.has("phoenix"): _phoenix_visual.apply_frame(frame.phoenix,_sniper_world_time,_zoom)
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
	_mark_clock = float(frame.ui.world_time)
	if frame.epoch!=_epoch:
		_epoch = frame.epoch
		boss_hit_feedback.clear()
		ruler_shake=0.0
		_queued_events.clear()
		_elite_deaths.clear()
		for display in _boss_body_displays.values():
			if display.has_method("clear_flames"): display.clear_flames()
		if _boss_lance_visual!=null: _boss_lance_visual.reset_frame()
		if _boss_wave_visual!=null: _boss_wave_visual.reset_frame()
		if _boss_sword_visual!=null: _boss_sword_visual.reset_frame()
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
		if _end_blast_visual!=null: _end_blast_visual.dispose()
		_end_blast_visual = null
		_end_blast_world_time = -1.0
		if _run_up_visual!=null: _run_up_visual.dispose()
		_run_up_visual = null
		_run_up_world_time = -1.0
		if _mines_visual!=null: _mines_visual.dispose()
		_mines_visual = null
		_mines_world_time = -1.0
		if _vortex_visual!=null: _vortex_visual.dispose()
		_vortex_visual = null
		_vortex_world_time = -1.0
		if _kill_sonic_visual!=null: _kill_sonic_visual.dispose()
		_kill_sonic_visual = null
		if _slash_visual!=null: _slash_visual.dispose()
		_slash_visual = null
		_slash_world_time = -1.0
		if _afterimage_visual!=null: _afterimage_visual.dispose()
		_afterimage_visual = null
		_afterimage_clock = -1.0
		if _escort_visual!=null: _escort_visual.dispose()
		_escort_visual = null
		_escort_world_time = -1.0
		if _interceptor_visual!=null: _interceptor_visual.dispose()
		_interceptor_visual = null
		_interceptor_world_time = -1.0
		if _bipolar_visual!=null: _bipolar_visual.dispose()
		_bipolar_visual = null
		_bipolar_world_time = -1.0
		if _mass_tow_visual!=null: _mass_tow_visual.dispose()
		_mass_tow_visual = null
		_mass_tow_world_time = -1.0
		if _contact_arc_visual!=null: _contact_arc_visual.dispose()
		_contact_arc_visual = null
		if _sonic_visual!=null: _sonic_visual.dispose()
		_sonic_visual = null
		_sonic_world_time = -1.0
		if _contact_wave_visual!=null: _contact_wave_visual.dispose()
		_contact_wave_visual = null
		_contact_wave_world_time = -1.0
		if _knockback_visual!=null: _knockback_visual.dispose()
		_knockback_visual = null
		_knockback_world_time = -1.0
		_particles.clear()
		_rings.clear()
		_debris_trails.clear()
		_attack_ends.clear()
		_lance_effects.clear()
		_lance_flashes.clear()
		_lance_hits.clear()
		if is_instance_valid(_critical_lances): _critical_lances.shots.clear()
		_zone_seen.clear()
		_flood_world_time = -1.0
		for tail: Dictionary in _flood_tails: tail.node.queue_free()
		_flood_tails.clear()
		_flood_groups.clear()
		for water: Dictionary in _flood_displays.values(): water.fired = false; water.row = {}
		_zone_world_time = -1.0
		for bursts: Node in _zone_bursts.values(): bursts.queue_free()
		_zone_bursts.clear()
		_meteor_shards.clear()
		_shield_transfers.clear()
	var feedback_targets := {}
	for body: Dictionary in frame.ui.get("boss_bodies",[]):
		if int(body.kind) not in [0,4]:continue
		feedback_targets[int(body.actor)]=true
		for clone: Dictionary in body.get("clones",[]):feedback_targets[int(clone.id)]=true
	for event: Dictionary in frame.events:
		var payload: Dictionary = event.payload.duplicate(true)
		if event.type=="combat_damage" and payload.get("target","")=="enemy" and float(payload.get("applied",0.0))>0.0 and feedback_targets.has(int(payload.get("target_id",0))):
			boss_hit_feedback.pulse(int(payload.target_id))
		payload["type"] = event.type
		_queued_events.append(payload)
	return true

func update_effects(frame: Dictionary, dt: float) -> void:
	if authoring_clock >= 0.0:
		frame = frame.duplicate()
		frame.ui = frame.ui.duplicate()
		frame.ui.world_time = authoring_clock
		frame.ui.presentation_frozen = authoring_paused
		if authoring_paused:
			dt = 0.0
			frame.ui.input_enabled = false
	_finale_overlay={}
	_finale_rect=Rect2(frame.ui.view_center-frame.ui.view_half,frame.ui.view_half*2.0).grow(400.0)
	for body: Dictionary in frame.ui.get("boss_bodies",[]):
		if body.get("kind",-1)==4:_finale_overlay=body.get("finale",{})
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
	_hero_power_visual.fire = frame.ui.get("hero",{}).get("hercules",{})
	_hero_power_visual.world_time = float(frame.ui.world_time)
	_hero_fire_canvas.queue_redraw()
	_hero_power_visual.unit = 1.0/maxf(0.01,float(frame.camera.zoom))
	_hero_frame = frame.ui.duplicate()
	_hero_frame.camera_zoom = frame.camera.zoom
	_hero_canvas.queue_redraw()
	_rear_frame = frame.ui
	_rear_canvas.visible = equipped_rear and _ship_visible
	_rear_canvas.get_parent().move_child(_rear_canvas,-1)
	_rear_canvas.queue_redraw()
	var equipped_kill_sonic: bool = frame.ui.get("kill_sonic",{}).get("ready",false)
	if equipped_kill_sonic and _kill_sonic_visual==null:
		_kill_sonic_visual = preload("res://scripts/render/equipment/killSonic.gd").new()
		_kill_sonic_visual.setup_frame(_layer(14),_pixel)
	if not equipped_kill_sonic and _kill_sonic_visual!=null:
		_kill_sonic_visual.dispose()
		_kill_sonic_visual = null
	var equipped_slash: bool = frame.ui.get("flash_slash",{}).get("ready",false)
	if equipped_slash and _slash_visual==null:
		_slash_visual = preload("res://scripts/render/equipment/flashSlash.gd").new()
		_slash_visual.setup_frame(_layer(19),_pixel)
	if not equipped_slash and _slash_visual!=null:
		_slash_visual.dispose()
		_slash_visual = null
		_slash_world_time = -1.0
	var equipped_afterimage: bool = frame.ui.get("afterimage",{}).get("ready",false)
	if equipped_afterimage and _afterimage_visual==null:
		_afterimage_visual = preload("res://scripts/render/equipment/afterimage.gd").new()
		_afterimage_visual.setup_frame(_layer(13))
	if not equipped_afterimage and _afterimage_visual!=null:
		_afterimage_visual.dispose()
		_afterimage_visual = null
		_afterimage_clock = -1.0
	var equipped_escort: bool = frame.ui.get("escort",{}).get("ready",false)
	if equipped_escort and _escort_visual==null:
		_escort_visual = preload("res://scripts/render/equipment/dashRangeDrone.gd").new()
		_escort_visual.setup_frame(_layer(14),_layer(18),_pixel)
	if not equipped_escort and _escort_visual!=null:
		_escort_visual.dispose()
		_escort_visual = null
		_escort_world_time = -1.0
	var equipped_interceptor: bool = frame.ui.get("interceptor",{}).get("ready",false)
	if equipped_interceptor and _interceptor_visual==null:
		_interceptor_visual = preload("res://scripts/render/equipment/interceptor.gd").new()
		_interceptor_visual.setup_frame(_layer(14),_layer(18),_pixel,frame.ui.character_scale)
	if not equipped_interceptor and _interceptor_visual!=null:
		_interceptor_visual.dispose()
		_interceptor_visual = null
		_interceptor_world_time = -1.0
	var equipped_bipolar: bool = frame.ui.get("bipolar",{}).get("ready",false)
	if equipped_bipolar and _bipolar_visual==null:
		_bipolar_visual = preload("res://scripts/render/equipment/bipolar.gd").new()
		_bipolar_visual.setup_frame(_layer(18),_layer(19),_pixel)
	if not equipped_bipolar and _bipolar_visual!=null:
		_bipolar_visual.dispose()
		_bipolar_visual = null
		_bipolar_world_time = -1.0
	var equipped_tow: bool = frame.ui.get("mass_tow",{}).get("ready",false)
	if equipped_tow and _mass_tow_visual==null:
		_mass_tow_visual = preload("res://scripts/render/equipment/massTow.gd").new()
		_mass_tow_visual.setup_frame(_layer(18),_pixel)
	if not equipped_tow and _mass_tow_visual!=null:
		_mass_tow_visual.dispose()
		_mass_tow_visual = null
		_mass_tow_world_time = -1.0
	var equipped_arc: bool = frame.ui.get("contact_arc",{}).get("ready",false)
	if equipped_arc and _contact_arc_visual==null:
		_contact_arc_visual = preload("res://scripts/render/equipment/contactArc.gd").new()
		_contact_arc_visual.setup_frame(_layer(14),_layer(18),_scope.resources.get("res://assets/pixel/airship_electronic_probe.png"),frame.ui.character_scale)
	if not equipped_arc and _contact_arc_visual!=null:
		_contact_arc_visual.dispose()
		_contact_arc_visual = null
	var equipped_sonic: bool = frame.ui.get("sonic",{}).get("ready",false)
	if equipped_sonic and _sonic_visual==null:
		_sonic_visual = preload("res://scripts/render/equipment/sonic.gd").new()
		_sonic_visual.setup_frame(_layer(14),_pixel)
	if not equipped_sonic and _sonic_visual!=null:
		_sonic_visual.dispose()
		_sonic_visual = null
		_sonic_world_time = -1.0
	var equipped_contact_wave: bool = frame.ui.get("contact_wave",{}).get("ready",false)
	if equipped_contact_wave and _contact_wave_visual==null:
		_contact_wave_visual = preload("res://scripts/render/equipment/contactWave.gd").new()
		_contact_wave_visual.setup_frame(_layer(14),_pixel)
	if not equipped_contact_wave and _contact_wave_visual!=null:
		_contact_wave_visual.dispose()
		_contact_wave_visual = null
		_contact_wave_world_time = -1.0
	var equipped_knockback: bool = frame.ui.get("knockback",{}).get("ready",false)
	if equipped_knockback and _knockback_visual==null:
		_knockback_visual = preload("res://scripts/render/equipment/knockback.gd").new()
		_knockback_visual.setup_frame(_layer(14),_pixel)
	if not equipped_knockback and _knockback_visual!=null:
		_knockback_visual.dispose()
		_knockback_visual = null
		_knockback_world_time = -1.0
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
	_barrier_armor.visible = (equipped_barrier or equipped_knockback) and _ship_visible
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
	var equipped_vortex: bool = frame.ui.get("vortex",{}).get("ready",false)
	if equipped_vortex and _vortex_visual==null:
		_vortex_visual = preload("res://scripts/render/equipment/vortex.gd").new()
		_vortex_visual.setup_frame(_layer(14),_layer(18),_layer(19),_pixel)
	if not equipped_vortex and _vortex_visual!=null:
		_vortex_visual.dispose()
		_vortex_visual = null
		_vortex_world_time = -1.0
	var equipped_mines: bool = frame.ui.get("mines",{}).get("ready",false)
	if equipped_mines and _mines_visual==null:
		_mines_visual = preload("res://scripts/render/equipment/mines.gd").new()
		_mines_visual.setup_frame(_layer(18),_pixel)
	if not equipped_mines and _mines_visual!=null:
		_mines_visual.dispose()
		_mines_visual = null
		_mines_world_time = -1.0
	_mines_overlay.visible = equipped_mines and _ship_visible
	_mines_overlay.position = _ship_visual_position
	_mines_overlay.rotation = frame.ui.ship.ship_heading.angle()+PI/2.0
	_mines_overlay.modulate = _barrier_armor.modulate
	_mines_overlay.get_parent().move_child(_mines_overlay,-1)
	var equipped_run_up: bool = frame.ui.get("run_up",{}).get("ready",false)
	if equipped_run_up and _run_up_visual==null:
		_run_up_visual = preload("res://scripts/render/equipment/runUp.gd").new()
		_run_up_visual.setup_frame(_layer(18),_pixel)
	if not equipped_run_up and _run_up_visual!=null:
		_run_up_visual.dispose()
		_run_up_visual = null
		_run_up_world_time = -1.0
	var equipped_end_blast: bool = frame.ui.get("end_blast",{}).get("ready",false)
	if equipped_end_blast and _end_blast_visual==null:
		_end_blast_visual = preload("res://scripts/render/equipment/endBlast.gd").new()
		_end_blast_visual.setup_frame(_layer(18),_pixel)
	if not equipped_end_blast and _end_blast_visual!=null:
		_end_blast_visual.dispose()
		_end_blast_visual = null
		_end_blast_world_time = -1.0
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
	var death_view := Rect2(frame.ui.view_center-frame.ui.view_half,frame.ui.view_half*2.0)
	var captured := {}
	for event: Dictionary in _queued_events:
		if event.type==&"anchor_capture": captured[event.get("id",0)] = true
	for event: Dictionary in _queued_events:
		if event.type==&"kill" and not captured.has(event.id): _elite_deaths.add_event(event,frame.ui.world_time,death_view)
		if event.type==&"combat_damage" and event.get("target","")=="enemy" and float(event.get("applied",0.0))>0.0:
			for display in _boss_body_displays.values():
				if display.state.get("kind",-1) in [0,1,2] and display.state.get("actor",0)==event.get("target_id",0): display.frame_event(event)
		if event.type==&"hydra_cue":
			for display in _boss_body_displays.values():
				if display.state.get("actor",0)==event.id: display.frame_event(event)
		if event.type==&"canis_cue":
			for display in _boss_body_displays.values():
				if display.state.get("actor",0)==event.id: display.frame_event(event)
		if event.type==&"canis_ignite_arrived" and _boss_body_displays.has(event.boss_id): _boss_body_displays[event.boss_id].frame_event(event)
		_boss_lance_visual.frame_event(event)
		_boss_wave_visual.frame_event(event)
		if _slash_visual!=null: _slash_visual.frame_event(event)
		if _escort_visual!=null: _escort_visual.on_event(event)
		if _interceptor_visual!=null: _interceptor_visual.on_event(event)
		if _bipolar_visual!=null: _bipolar_visual.frame_event(event)
		if event.type==&"beam" and event.get("visual_key","")=="weapon/bipolar": ruler_shake = maxf(ruler_shake,5.0)
		if _mass_tow_visual!=null and (event.type in [&"anchor_capture",&"anchor_fire"] or event.type==&"shot_hit" and event.get("visual_key","")=="weapon/massTow"): _mass_tow_visual.frame_event(event)
		if event.type==&"anchor_fire": ruler_shake = maxf(ruler_shake,3.0)
		if event.type==&"shot_hit" and event.get("visual_key","")=="weapon/massTow": ruler_shake = maxf(ruler_shake,4.0)
		_boss_sword_visual.frame_event(event)
		if event.type==&"draco_roar":
			ruler_shake = maxf(ruler_shake,12.0)
			if pipeline!=null: pipeline.add_wave(event.pos,event.radius,0.8)
			_rings.append({"pos":event.pos,"radius":event.radius,"color":Color("#c2b8ff"),"life":0.8,"max":0.8})
		if event.type==&"shield_stolen":
			_shield_transfers.append({"pos":event.pos,"facing":event.facing,"r":event.r,"arc":event.arc,"life":0.3,"max":0.3})
			_rings.append({"pos":event.pos,"radius":event.r*1.7,"color":Color("#65e8ff"),"life":0.3,"max":0.3})
		if event.type==&"shield_block":
			_rings.append({"pos":event.pos,"radius":float(frame.ui.ship_radius)*3.0,"color":Color("#bcefff"),"life":0.18,"max":0.18})
		if (event.type==&"kill" and event.get("enemy_type")==&"meteor" and event.get("cause",&"")!=&"vortex") or event.type==&"rock_break":
			var frames: SpriteFrames = _scope.resources.get("res://.content/meteor_pieces.res")
			if frames!=null:
				var animation := StringName("meteor_%d" % (posmod(int(event.meteor_index),2)+1))
				for i in frames.get_frame_count(animation):
					var texture := frames.get_frame_texture(animation,i) as AtlasTexture
					var offset: Vector2 = (texture.get_meta("offset") as Vector2).rotated(event.facing)
					_meteor_shards.append({"texture":texture,"pos":event.pos+offset*0.35,"vel":offset.normalized()*100.0+event.dir*60.0,
						"angle":event.facing,"spin":-1.5 if i%2==0 else 1.5,"life":0.65})
		if event.type==&"rock_break":
			_burst(event.pos,event.color,10,300.0,event.dir)
			_rings.append({"pos":event.pos,"radius":event.r*1.2,"color":Color(1.0,0.95,0.6),"life":0.2,"max":0.2})
		if event.type==&"ruler_split":
			ruler_shake=maxf(ruler_shake,4.0)
			_rings.append({"pos":event.pos,"radius":46.0,"color":(event.color as Color).lightened(0.4),"life":0.3,"max":0.3})
			_burst(event.pos,event.color,10,260.0)
		if event.type==&"cepheus_summon":
			_rings.append({"pos":event.pos,"radius":70.0,"color":(event.color as Color).lightened(0.4),"life":0.3,"max":0.3})
		if event.type==&"beam" and event.get("visual_key","")!="weapon/bipolar":
			var life: float = event.get("life",0.4)*EFFECT_SETTINGS.number("","visible_time_scale",1.0)
			_mutiny_beams.append({"from":event.from,"to":event.to,"width":event.width,"life":life,"max":life,"color":event.get("color",Color(1,0.95,0.6))})
		if event.type==&"telescope_charge": _rings.append({"pos":event.pos,"radius":30.0,"color":Color(1.0,0.4,0.3),"life":0.2,"max":0.2})
		if event.type==&"telescope_fire":
			var direction := Vector2.from_angle(event.angle)
			_telescope_beams.append({"from":event.pos,"to":event.pos+direction*event.length,"width":event.width*1.6,"life":0.28,"max":0.28})
			_rings.append({"pos":event.pos,"radius":40.0,"color":Color(1.0,0.75,0.6),"life":0.22,"max":0.22})
			_burst(event.pos,Color(1.0,0.5,0.35),10,500.0,direction)

		if event.type in [&"critical_lance",&"critical_lance_hit"] and not frame.ui.has("light_lances"):
			if not is_instance_valid(_critical_lances):
				_critical_lances = preload("res://scripts/render/light_lance.gd").new()
				_critical_lances.name = "CriticalLances"
				_layer(11).add_child(_critical_lances)
			if event.type==&"critical_lance": _critical_lances.fire(event)
			preload("res://scripts/render/equipment/critBeam.gd").frame_event(_lance_flashes,_lance_hits,event,_pixel)
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
		if event.type==&"explode" and event.get("cause",&"") not in [&"endBlast",&"runUp",&"mine"]:
			_rings.append({"pos":event.pos,"radius":event.radius,"color":event.color,"life":event.life,"max":event.life})
			if event.radius>=150.0 and pipeline!=null: pipeline.add_wave(event.pos,event.radius,0.4)
		if event.type==&"debris_trail" and event.get("life",0.0)>0.0:
			_debris_trails.append({"points":event.points,"life":event.life,"max":event.life})
		if event.type==&"ring" and event.get("visual_key","")!="weapon/bipolar":
			if _rings.size()>80: _rings.pop_front()
			var duration: float = event.life*EFFECT_SETTINGS.number("","visible_time_scale",1.0)
			_rings.append({"pos":event.pos,"radius":event.radius,"color":event.color,"life":duration,"max":duration})
		if event.type==&"bud":
			_rings.append({"pos":event.pos,"radius":20.0,"color":event.color,"life":0.25,"max":0.25})
			_burst(event.pos,event.color,6,160.0)
		if event.type==&"gem_burst":
			if _rings.size()>80: _rings.pop_front()
			var duration: float = 0.3*EFFECT_SETTINGS.number("","visible_time_scale",1.0)
			_rings.append({"pos":event.pos,"radius":event.r*2.4,"color":Color("#ffe27a"),"life":duration,"max":duration})
			_burst(event.pos,Color("#ffd23f"),14,360.0)
		if event.type==&"boss_explode":
			finish_flash = float(finish_settings.get("flash",0.2))
			finish_shake = float(finish_settings.get("shake",6.0))
			var scene: PackedScene = finish_settings.get("effect")
			if scene!=null:
				var effect: Node2D = scene.instantiate()
				effect.position = event.pos
				add_child(effect)
			else: _burst(event.pos,finish_settings.get("color",Color("#e2b96b")),int(finish_settings.get("particles",80)),700.0)
			if pipeline!=null: pipeline.add_wave(event.pos,1600.0,float(finish_settings.get("wave_seconds",0.8)))
		if event.type==&"ship_explode": _death_burst(event.pos)
		if equipped_end_blast: _end_blast_visual.frame_event(event,frame.ui.end_blast.radius,frame.ui.end_blast.secondary)
		if equipped_full_burst: _full_burst_visual.frame_event(event,frame.ui.ship.ship_pos,frame.ui.ship.ship_heading,frame.ui.character_scale)
		if equipped_duplicator and event.type==&"duplicate": _duplicator_visual.on_event(event)
		if event.type==&"swallow":
			var entry: Dictionary = visuals.get(event.get("visual_id",0),{})
			var texture: Texture2D
			if entry.get("role")==VISUAL_ROLE.EnemyLook:
				var look: EnemyLook = _scope.resources.get(entry.path)
				if look!=null: texture = look.previews.get(entry.get("hull_preview",""))
			else: texture = _scope.resources.get(entry.get("path","")) as Texture2D
			for display: Node in enemy_frames.values(): display.frame_event(event,texture)
		if equipped_barrier and not barrier_from_state and event.type in [&"barrier_hit",&"barrier_restore"]: _barrier_visual.on_event(event)
		if equipped_rear: preload("res://scripts/render/equipment/rear.gd").frame_event(_rear_flashes,_rear_shells,event,frame.ui.ship.ship_heading,frame.ui.rear.mount)
		if equipped_scatter: preload("res://scripts/render/equipment/scatter.gd").frame_event(_scatter_flashes,event)
		if equipped_forward: preload("res://scripts/render/equipment/forward.gd").frame_event(_flashes,event)
	_elite_deaths.step(frame.ui.world_time,death_view,1.0-float(frame.ui.get("death_dim",0.0)))
	_queued_events.clear()
	var ui: Dictionary = frame.ui
	_dim_strength = float(ui.get("death_dim",0.0))
	_dim_rect = Rect2(frame.camera.center-frame.camera.half,frame.camera.half*2.0)
	_dim.queue_redraw()
	for display: Node in enemy_frames.values(): display.set_death_brightness(1.0-_dim_strength)
	var effect_dt := 0.0 if ui.get("presentation_frozen",not ui.input_enabled) else dt
	finish_flash = maxf(0.0,finish_flash-effect_dt*2.0)
	if ui.has("light_lances"):
		if not ui.light_lances.is_empty() and not is_instance_valid(_critical_lances):
			_critical_lances = preload("res://scripts/render/light_lance.gd").new()
			_critical_lances.name = "CriticalLances"
			_layer(11).add_child(_critical_lances)
		if is_instance_valid(_critical_lances): _critical_lances.shots.assign(ui.light_lances.duplicate(true))
		preload("res://scripts/render/equipment/critBeam.gd").frame_state(_lance_effects,_lance_flashes,_lance_hits,ui.lance_effects,_pixel)
	if is_instance_valid(_critical_lances): _critical_lances.step(0.0 if ui.has("light_lances") else effect_dt,ui.character_scale,_zoom)
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
	if _kill_sonic_visual!=null:
		_kill_sonic_visual.sync_frame(ui.kill_sonic.waves,ui.world_time)
		_kill_sonic_visual.frame_tick(0.0)
	var slash_dt: float = 0.0 if _slash_world_time<0.0 else maxf(0.0,ui.world_time-_slash_world_time)
	_slash_world_time = ui.world_time if equipped_slash else -1.0
	if _slash_visual!=null: _slash_visual.frame_tick(ui.flash_slash,ui.character_scale,slash_dt)
	var afterimage_dt: float = 0.0 if _afterimage_clock<0.0 else maxf(0.0,ui.afterimage.clock-_afterimage_clock)
	_afterimage_clock = ui.afterimage.clock if equipped_afterimage else -1.0
	if _afterimage_visual!=null: _afterimage_visual.frame_tick(ui.afterimage,ui.character_scale,afterimage_dt)
	var escort_dt: float = 0.0 if _escort_world_time<0.0 else maxf(0.0,ui.world_time-_escort_world_time)
	_escort_world_time = ui.world_time if equipped_escort else -1.0
	if _escort_visual!=null: _escort_visual.frame_tick(ui.escort,ui.character_scale,_zoom,ui.ship,ui.draw.tracing,escort_dt)
	var interceptor_dt: float = 0.0 if _interceptor_world_time<0.0 else maxf(0.0,ui.world_time-_interceptor_world_time)
	_interceptor_world_time = ui.world_time if equipped_interceptor else -1.0
	if _interceptor_visual!=null: _interceptor_visual.frame_tick(ui.interceptor.drones,interceptor_dt)
	var bipolar_dt: float = 0.0 if _bipolar_world_time<0.0 else maxf(0.0,ui.world_time-_bipolar_world_time)
	_bipolar_world_time = ui.world_time if equipped_bipolar else -1.0
	if _bipolar_visual!=null:
		_bipolar_visual.sync_frame(ui.bipolar,ui.ship,ui.world_time,_dim_rect)
		_bipolar_visual.frame_tick(bipolar_dt)
	var mass_tow_dt: float = 0.0 if _mass_tow_world_time<0.0 else maxf(0.0,ui.world_time-_mass_tow_world_time)
	_mass_tow_world_time = ui.world_time if equipped_tow else -1.0
	if _mass_tow_visual!=null:
		_mass_tow_visual.sync_frame(ui.mass_tow,ui.ship,ui.world_time)
		_mass_tow_visual.frame_tick(mass_tow_dt)
	if _contact_arc_visual!=null: _contact_arc_visual.frame_tick(ui.contact_arc,ui.ship,_zoom,_ship_visible)
	var sonic_dt: float = 0.0 if _sonic_world_time<0.0 else maxf(0.0,ui.world_time-_sonic_world_time)
	_sonic_world_time = ui.world_time if equipped_sonic else -1.0
	if _sonic_visual!=null:
		_sonic_visual.sync_frame(ui.sonic,{"ship_pos":ui.ship.ship_pos,"ship_heading":ui.ship.ship_heading,"tracing":ui.tracing,"glide":ui.glide},sonic_dt)
		_sonic_visual.frame_tick(sonic_dt)
	var contact_wave_dt: float = 0.0 if _contact_wave_world_time<0.0 else maxf(0.0,ui.world_time-_contact_wave_world_time)
	_contact_wave_world_time = ui.world_time if equipped_contact_wave else -1.0
	if _contact_wave_visual!=null:
		_contact_wave_visual.sync_frame(ui.contact_wave.waves,contact_wave_dt)
		_contact_wave_visual.frame_tick(contact_wave_dt)
	if pipeline!=null:
		pipeline.sync_contact_ripples(ui.get("contact_wave",{}).get("ripples",[]),_pixel)
		ShaderTuning.apply(pipeline.ripple_material(),"weapon/contactWave")
	var knockback_dt: float = 0.0 if _knockback_world_time<0.0 else maxf(0.0,ui.world_time-_knockback_world_time)
	_knockback_world_time = ui.world_time if equipped_knockback else -1.0
	if _knockback_visual!=null:
		_knockback_visual.sync_frame(ui.knockback.visuals,knockback_dt)
		_knockback_visual.frame_tick(knockback_dt,ui.world_time)
	var vortex_dt: float = 0.0 if _vortex_world_time<0.0 else maxf(0.0,ui.world_time-_vortex_world_time)
	_vortex_world_time = ui.world_time if equipped_vortex else -1.0
	if _vortex_visual!=null:
		_vortex_visual.sync_frame(ui.vortex.visuals,vortex_dt)
		_vortex_visual.frame_tick(vortex_dt,ui.ship.ship_pos)
	var mines_dt: float = 0.0 if _mines_world_time<0.0 else maxf(0.0,ui.world_time-_mines_world_time)
	_mines_world_time = ui.world_time if equipped_mines else -1.0
	if _mines_visual!=null:
		_mines_visual.frame_tick(mines_dt,ui.mines.items,ui.world_time)
		_mines_visual.sync_frame(ui.mines.visuals)
	var run_up_dt: float = 0.0 if _run_up_world_time<0.0 else maxf(0.0,ui.world_time-_run_up_world_time)
	_run_up_world_time = ui.world_time if equipped_run_up else -1.0
	if _run_up_visual!=null:
		_run_up_visual.frame_tick(run_up_dt,ui.ship.ship_pos,ui.ship.ship_heading,ui.full_charge.distance,ui.run_up.distance,ui.run_up.first,ui.draw.tracing,ui.world_time,_ship_visible)
		_run_up_visual.sync_frame(ui.run_up.hits)
	var end_blast_dt: float = 0.0 if _end_blast_world_time<0.0 else maxf(0.0,ui.world_time-_end_blast_world_time)
	_end_blast_world_time = ui.world_time if equipped_end_blast else -1.0
	if _end_blast_visual!=null:
		_end_blast_visual.frame_tick(end_blast_dt)
		_end_blast_visual.sync_frame(ui.end_blast.visuals)
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
	preload("res://scripts/render/equipment/critBeam.gd").frame_draw(_effects,_lance_flashes,_lance_hits,0.0 if ui.has("lance_effects") else effect_dt,ui.ship.ship_pos,ui.ship.ship_heading)
	_effects.end()
	perf.since(&"view_geometry.attacks",draw_start)
	if active and not ui.draw.drawing and ui.hitstop<=0.0:
		_jet_time += dt*clampf(ui.ship_vel.length()/ui.base_max_speed,0.0,3.0)
	_flame.texture = _scope.resources.get("res://assets/pixel/airship_blue_flame.png") if equipped_sonic else _scope.resources.get("res://assets/pixel/airship_flame.png")
	for sprite in [_flame,_spark]:
		sprite.position = ui.ship.ship_pos
		sprite.rotation = ui.ship.ship_heading.angle()+PI/2.0
		sprite.frame = int(_jet_time*12.0)%3
		sprite.visible = (ui.phase==0 or ui.phase==4) and not (equipped_escort and ui.draw.tracing)

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

func _draw_hero_values(canvas: CanvasItem) -> void:
	if _hero_frame.is_empty(): return
	var half: Vector2 = _hero_frame.view_half
	preload("res://scripts/render/hero_constellation.gd").draw(canvas,_hero_frame.get("hero",{}),1.0/maxf(0.01,float(_hero_frame.get("camera_zoom",1.0))),float(_hero_frame.world_time),Rect2(_hero_frame.view_center-half,half*2.0),_hero_aura,_hero_material)

## 元の敵と同じ画像・形へ、既存のコズミック表示だけを重ねる。
func _sync_cpp_picaro(bodies: Array) -> void:
	if _picaro_material==null:
		_picaro_material = ShaderMaterial.new()
		_picaro_material.shader = preload("res://shaders/picaro.gdshader")
	var used := {}
	for body: Dictionary in bodies:
		for member: Dictionary in body.get("picaro",[]):
			var entry: Dictionary = visuals.get(member.visual_id,{})
			if entry.is_empty(): continue
			used[member.id] = true
			if not _picaro_sprites.has(member.id):
				var texture: Texture2D
				var resource: Resource = _scope.resources.get(entry.path)
				if resource is EnemyLook: texture = resource.previews.get(entry.get("hull_preview",""))
				elif resource is Texture2D: texture = resource
				var node: Node2D
				if texture!=null:
					var sprite := Sprite2D.new()
					sprite.texture = texture
					node = sprite
				else:
					var shape := Polygon2D.new()
					shape.polygon = entry.get("points",InstanceBatch.circle_points(24))
					shape.color = member.color
					node = shape
				node.material = _picaro_material
				_layer(8).add_child(node)
				_picaro_sprites[member.id] = node
			var node: Node2D = _picaro_sprites[member.id]
			node.position = member.position
			node.rotation = member.angle
			node.visible = not body.get("cinematic_hide_enemies",false)
			var forming := clampf(1.0-float(member.born_age),0.0,1.0)
			var radius: float = lerpf(float(member.sprite_radius),maxf(float(member.sprite_radius)*1.8,70.0),forming*forming)
			node.scale = Vector2.ONE*radius
			if node is Sprite2D: node.scale *= 2.0/maxf(node.texture.get_width(),node.texture.get_height())
			node.modulate = Color(1,1,1,0.7 if member.guard>0.0 else 1.0)
	for id in _picaro_sprites.keys():
		if not used.has(id):
			_picaro_sprites[id].queue_free()
			_picaro_sprites.erase(id)

## 最終攻撃も、各ボスの戦闘状態を読み取る同じ表示経路へ通す。
func _sync_cpp_boss_final_beams(bodies: Array) -> void:
	var seen := {}
	for body: Dictionary in bodies:
		if int(body.mode)!=3 or int(body.kind)==3 or float(body.get("final_alpha",0.0))<=0.0: continue
		seen[body.id] = true
		if not _boss_final_beams.has(body.id):
			var line: Line2D = BOSS_FINAL_BEAM.instantiate()
			_pulser_parent.add_child(line)
			_boss_final_beams[body.id] = line
		var line: Line2D = _boss_final_beams[body.id]
		line.points = PackedVector2Array([body.position,body.final_to])
		line.width = body.final_width
		line.modulate.a = body.final_alpha
		var material := line.material as ShaderMaterial
		material.set_shader_parameter("tint",EFFECT_SETTINGS.tinted("boss/final_strike",Color(1,0.25,0.4)))
		material.set_shader_parameter("clock",body.final_clock)
		material.set_shader_parameter("warning",body.final_warning)
		material.set_shader_parameter("span",body.position.distance_to(body.final_to))
		material.set_shader_parameter("thickness",body.final_width)
	for id in _boss_final_beams.keys():
		if not seen.has(id):
			_boss_final_beams[id].queue_free()
			_boss_final_beams.erase(id)

func _draw_finale_overlay() -> void:
	var f: Dictionary=_finale_overlay
	if f.is_empty() or not f.get("active",false):return
	if float(f.dim)>0.0:_particle_canvas.draw_rect(_finale_rect,Color(0,0,0.02,float(f.dim)))
	var line: PackedVector2Array=f.line
	if line.size()==2:
		var width:=18.0 if f.stage=="strikes" else 48.0
		var alpha:=1.0 if f.stage in ["strikes","last"] else maxf(0.0,float(f.dim))
		_particle_canvas.draw_line(line[0],line[1],Color(0.65,0.65,1.0,alpha*0.45),width*3.0,false)
		_particle_canvas.draw_line(line[0],line[1],Color(1,1,1,alpha),width,false)
