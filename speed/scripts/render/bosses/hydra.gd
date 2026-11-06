## C++が確定した本体・首点列・囲いを、同じ正式素材へ渡す。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const BURST_KEY := "boss/body/hydra"
const PRIM := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const DRACO_FX := preload("res://scripts/render/bosses/draco_fx.gd")
const BURST_SHADER := preload("res://shaders/hydra_burst.gdshader")
@export var body_texture: Texture2D
@export var neck_spacing_pixels := 14.0
var frame_scope: ContentResourceScope
var state := {}
var hit := 0.0
var arena: Node2D
var effects := {}
var shot_scenes := {}
var _burst_clock := -1.0
var _burst_serial := 0
var _bursts: Array[Dictionary] = []
func setup_effects(scope: ContentResourceScope, entries: Dictionary) -> void:
	frame_scope = scope
	for entry in entries.values():
		if entry.has("hydra_move"): shot_scenes[entry.hydra_move] = scope.resources.get(entry.path)
var white: Texture2D
const FX := preload("res://scripts/render/bosses/hydra_fx.gd")
const PRESENT := preload("res://scripts/render/bosses/hydra_present.gd")
var _memory := {}
var _heads := {}
var _masks := {}
var _ferns := {}
const LIGHT := preload("res://scripts/render/enemies/aquila_lightning.gd")
var _light = LIGHT.new()
const HIDDEN_LINES := ["beam","wind","wind_blade","rubble","bolt","bite"]
var _raster := SpeedFxRaster.new()
var _raster_back := SpeedFxRaster.new()
var _rock_last := {}
var _reference_canvas
func set_reference_canvas(canvas) -> void:
	_reference_canvas = canvas

func draw_reference(canvas, _real_dt: float) -> void:
	if state.is_empty(): return
	var t := float(state.clock)
	var factor := float(state.radius)*2.0/body_texture.get_width() if body_texture!=null and state.has("radius") else 1.0
	var ramp: Array[Color] = _light.palette(FX.COLORS.thunder)
	for neck: Dictionary in state.get("necks",[]):
		if neck.get("alive",false) and neck.has("pose"): _draw_neck(canvas,neck,t,factor,ramp)
	for target: Dictionary in state.get("north_targets",[]):
		var from: Vector2 = target.from
		var at: Vector2 = target.target
		var k := 1.0 if target.locked else 0.5
		FX.rail(canvas,from,at,k,FX.COLORS.bite,t,3.0,false)
		FX.mark(canvas,at,(at-from).angle(),k,target.locked,float(target.radius),FX.COLORS.bite,7.0,t)
	var beam_color: Color = FX.COLORS.beam
	if state.has("grid_shots"):
		var elapsed := float(state.grid_elapsed)
		var stop := float(state.grid_stop)
		for shot: Dictionary in state.grid_shots:
			if elapsed>=float(shot.fire_at): continue
			var neck := _neck_by_key(int(shot.actor))
			if neck.is_empty(): continue
			var from: Vector2 = neck.position
			var end: Vector2 = shot.end if shot.locked else from+Vector2.from_angle(float(neck.angle))*1400.0
			FX.rail(canvas,from,end,1.0 if shot.locked else 0.35,beam_color,t,float(shot.fire_at)*7.0)
	var effects_now: Array = state.get("effects",[])
	var heavy := false
	for effect: Dictionary in effects_now:
		if String(effect.kind) in ["wind","wind_blade","bolt","rubble","tornado","tornado_charge"]: heavy = true
	if heavy:
		_raster.begin(canvas.front.colors,canvas.front.lights,canvas.front.width,canvas.front.height,float(canvas.world_scale),canvas._camera_position)
		_raster_back.begin(canvas.back.colors,canvas.back.lights,canvas.back.width,canvas.back.height,float(canvas.world_scale),canvas._camera_position)
	var rocks := {}
	for effect: Dictionary in effects_now:
		var points: PackedVector2Array = effect.points
		if points.size()<2: continue
		var e := float(effect.age)-float(effect.delay)
		var life := float(effect.life)
		match String(effect.kind):
			"tornado":
				if float(effect.get("speed",0.0))>0.0:
					var fade_wake := clampf((life-float(effect.age))/0.4,0.0,1.0)
					FX.tornado_wake(canvas,points[0].lerp(points[1],0.5),(points[1]-points[0]).normalized(),float(effect.speed),float(effect.width),float(effect.age),fade_wake)
				_raster_back.tornado(points[0].lerp(points[1],0.5),float(effect.width)*0.5*lerpf(0.8,1.0,smoothstep(0.0,0.15,float(effect.age))),clampf((life-float(effect.age))/0.4,0.0,1.0),1.0,t)
			"tornado_charge":
				var grow := pow(clampf(float(effect.age)/maxf(0.01,life),0.0,1.0),1.4)
				FX.tornado_gather(canvas,points[0],float(effect.width)*0.5*lerpf(0.1,1.0,grow),grow,t)
				_raster_back.tornado(points[0],float(effect.width)*0.5*lerpf(0.1,1.0,grow),1.0,grow,t)
			"wind":
				if e>=0.0: _raster.wind_band(points[0],(points[1]-points[0]).angle(),points[0].distance_to(points[1]),e,life)
			"wind_blade":
				var center := points[0].lerp(points[-1],0.5)
				var tip := points[points.size()/2]
				_raster.wind_blade(center,(tip-center).angle(),float(effect.age),life,points[0].distance_to(center),1.0 if int(effect.id)%2 else -1.0,float(int(effect.id)%89))
			"bolt":
				_raster.bolt_bar(points[0],(points[1]-points[0]).angle(),float(effect.age),life,float(effect.get("speed",900.0)),points[0].distance_to(points[1]),float(effect.width),beam_color,t)
			"rubble":
				var id := int(effect.id)
				var last: Dictionary = _rock_last.get(id,{"at":points[0],"angle":0.0,"speed":0.0})
				var step: Vector2 = points[0]-Vector2(last.at)
				var angle := float(last.angle)
				var speed := float(last.speed)
				if step.length()>0.5:
					angle = step.angle()
					speed = lerpf(speed,step.length()*60.0,0.3 if speed>0.0 else 1.0)
				rocks[id] = {"at":points[0],"angle":angle,"speed":speed}
				if speed>0.0: _raster_back.rock_comet(points[0],angle,speed,float(effect.age),float(effect.width)*0.5,float(id%97),1.0 if speed>300.0 else 0.4)
	_rock_last = rocks
	if heavy and state.has("tornado_rocks"):
		var seed_rock := 1.0
		for rock: Dictionary in state.tornado_rocks:
			if float(rock.progress)<1.0: _raster_back.rock_comet(rock.position,float(rock.aim),float(rock.speed),float(rock.age),float(rock.size),seed_rock*3.0+1.0,1.0)
			seed_rock += 1.0
	if heavy:
		canvas.front.colors = _raster.take_colors()
		canvas.front.lights = _raster.take_lights()
		canvas.back.colors = _raster_back.take_colors()
		canvas.back.lights = _raster_back.take_lights()
		canvas.front.has_color = true
		canvas.front.has_light = true
		canvas.back.has_color = true
		canvas.back.has_light = true
	if state.has("tornado_rocks"):
		for effect: Dictionary in effects_now:
			if String(effect.kind) in ["tornado","tornado_charge"]:
				var points: PackedVector2Array = effect.points
				var center: Vector2 = points[0].lerp(points[1],0.5) if String(effect.kind)=="tornado" else points[0]
				for rock: Dictionary in state.tornado_rocks:
					if float(rock.progress)>=1.0: FX.tornado_rock(canvas,center,rock,float(state.tornado_fade),1.0)
	for effect: Dictionary in effects_now:
		var points: PackedVector2Array = effect.points
		if points.size()<2: continue
		var e := float(effect.age)-float(effect.delay)
		var life := float(effect.life)
		match String(effect.kind):
			"beam":
				var end: Vector2 = points[-1]
				if e<0.0:
					var k := clampf(float(effect.age)/maxf(0.01,float(effect.delay)),0.0,1.0)
					FX.rail(canvas,points[0],end,k,beam_color,t,float(effect.id))
					DRACO_FX.gather(canvas,points[0],46.0,k,t,float(effect.id),beam_color)
				else: FX.beam(canvas,points[0],end,float(effect.width),beam_color,t,clampf((e-(life-0.1))/0.1,0.0,1.0),clampf(e/0.07,0.0,1.0))
			"lightning":
				if points[0].distance_to(points[-1])<1.0 and e>=0.0:
					FX.bolt_strike(canvas,_light,canvas.to_logical(points[0]),float(effect.width)*0.5*float(canvas.world_scale),e,int(effect.id)%97+1,ramp,canvas.to_logical(effect.get("source",position)))

func _draw_neck(canvas, neck: Dictionary, t: float, factor: float, ramp: Array[Color]) -> void:
	var pose: Dictionary = neck.pose
	var kind := String(neck.kind)
	var mode := String(neck.mode)
	var color: Color = FX.COLORS.get(kind,FX.COLORS.bite)
	var head: Vector2 = neck.position
	var facing := float(neck.facing)
	var mouth := head+Vector2.from_angle(facing)*(16.5 if kind in ["debris","beam"] else 11.5)*factor
	var rel := float(pose.rel)
	var warn := float(pose.warn)
	var active := float(pose.active)
	var id := int(neck.id)
	var glow := float(neck.get("glow",0.0))
	var trail: Array = _heads.get(id,[])
	if String(pose.type)=="major":
		var lunge: bool = pose.get("lunge",false)
		var k := clampf(float(neck.get("major_time",0.0))/warn,0.0,1.0) if mode!="grid" else glow
		if rel<0.0:
			if kind=="bite": FX.bite_eyes(canvas,head,facing,pow(k,0.7),color,t,factor)
			else: FX.eyes(canvas,head,facing,k,color,factor)
			if mode in ["curve","beam_pincer","debris_shatter","grid"] and kind in ["beam","vortex","thunder"]: DRACO_FX.gather(canvas,mouth,42.0,k,t,float(id),color)
			if kind=="debris" and mode in ["tornado","debris_shatter"]: FX.rubble_warn(canvas,neck.points,mouth,k,t,false)
			if lunge: FX.rail(canvas,mouth,neck.target,0.4+0.6*k,color,t,60.0+id,false)
		elif lunge:
			var flight := float(pose.get("flight",0.25))
			var radius := float(neck.get("bite_radius",70.0))
			if rel<flight+0.2: FX.air(canvas,neck.strike_from,neck.target,rel,flight,color)
			if rel<flight: _ghost(canvas,neck,5,0.2,color,factor,id*7.0)
			var bite := rel-flight+0.03
			var to: Vector2 = neck.target
			var way := (to-Vector2(neck.strike_from)).normalized()
			var at := to+way*11.5*factor
			FX.fangs(canvas,at,way.angle(),bite,radius,float(id)*23.0,color)
			DRACO_FX.dust(canvas,at+way*0.3*radius,bite-0.05,41.0+id*23.0,way.angle(),0.8)
		return
	var age := float(neck.elapsed)
	var u := clampf(age/warn,0.0,1.0)
	var pts: PackedVector2Array = neck.points
	FX.grit(canvas,pts,age,warn)
	var mem: Dictionary = _memory.get(id,{})
	var thunder_range: float = float(neck.get("thunder_radius",170.0))*float(canvas.world_scale)
	if mode=="thunder_headbutt":
		FX.eye_charge(canvas,_light,head,facing,pow(u,1.1) if rel<0.0 else exp(-maxf(0.0,rel-active)/0.12),t,rel<0.0,factor,ramp)
	elif rel<0.0 and kind=="bite": FX.bite_eyes(canvas,head,facing,pow(u,0.8),color,t,factor)
	else:
		FX.eyes(canvas,head,facing,pow(u,1.4) if rel<0.0 else exp(-rel/0.25),color,factor)
		FX.eye_trail(canvas,trail,rel,color,factor)
	if rel<0.0:
		if mode=="wind_band" or mode=="wind_blades": FX.wind_inhale(canvas,mouth,facing,u,age,mode=="wind_band",FX.COLORS.vortex)
		if kind=="debris": FX.rubble_warn(canvas,pts,mouth,u,age,mode=="rubble_lump")
		if kind=="beam": DRACO_FX.gather(canvas,mouth,46.0,u,t,float(id),color)
		if mode=="beam_fixed": FX.rail(canvas,mouth,mouth+Vector2.from_angle(facing)*1400.0,u,color,t,float(id))
		if mode=="thunder_drop":
			FX.crackle(canvas,_light,head,34.0,pow(u,1.2),t,3,ramp)
			FX.drop_warn(canvas,_light,mouth,neck.target,thunder_range,u,t,ramp)
		return
	if mode=="beam_fixed" and rel<=active: FX.beam_spill(canvas,mouth,facing,rel,1400.0,40.0,color)
	if mode=="beam_fixed" and rel>active and rel<active+0.25:
		var m: Vector2 = canvas.to_logical(mouth)
		canvas.front.glow(m.x,m.y,6.0,PRIM.ramp(color)[2],0.4*(1.0-(rel-active)/0.25))
	if mode=="bite_sweep":
		FX.sweep_trail(canvas,neck,rel,float(mem.get("fire_angle",facing)),PRESENT,float(neck.get("bite_radius",70.0)),color)
		if rel>=active: DRACO_FX.dust(canvas,head,rel-active,77.0,facing+PI*0.5,0.8)
	if mode=="bite_thrust":
		if rel<=active+0.2: FX.air(canvas,neck.strike_from,neck.target,rel,active,color)
		FX.fangs(canvas,head+Vector2.from_angle(facing)*11.5*factor,facing,rel-active+0.03,float(neck.get("bite_radius",70.0)),0.0,color)
	if String(pose.type)=="lunge" and rel<=active+0.06: _ghosts(canvas,neck,rel,active,color,factor)
	if kind=="debris": FX.spit_burst(canvas,mouth,facing,rel,mode=="rubble_fan",0.6 if mode=="rubble_fan" else 0.35)
	if mode=="beam_bolt" and rel<0.12: PRIM.flare(canvas.front,canvas.to_logical(mouth),2.5,color,t,1.0-rel/0.12,4)
	if mode=="thunder_headbutt":
		if rel<active+0.3:
			var f := floori(t/0.05)
			var rng = FX.JET.Rng.new(f*7+3)
			var from: Vector2 = canvas.to_logical(neck.strike_from)
			var to: Vector2 = canvas.to_logical(head)
			if from.distance_to(to)>6.0: _light.ink(canvas.back,_light.zigzag(rng,from,to,0.3,0.3),0.7*exp(-maxf(0.0,rel-active)/0.1),ramp,1.0,true,0.4)
		if rel>=active:
			var key := roundi(thunder_range)
			if not _ferns.has(key): _ferns[key] = FX.fern(thunder_range)
			FX.zap(canvas,_light,canvas.to_logical(neck.target),thunder_range,rel-active,facing,ramp,_ferns[key])

func _ghost(canvas, neck: Dictionary, back: int, strength: float, color: Color, factor: float, seed: float) -> void:
	var mask := _head_mask(String(neck.kind))
	var trail: Array = _heads.get(int(neck.id),[])
	if mask.is_empty() or trail.size()<=back: return
	var old: Dictionary = trail[trail.size()-1-back]
	FX.silhouette(canvas,mask,old.pos,float(old.angle),PRIM.ramp(color)[2],strength,factor,seed)

func _ghosts(canvas, neck: Dictionary, rel: float, active: float, color: Color, factor: float) -> void:
	var mask := _head_mask(String(neck.kind))
	if mask.is_empty(): return
	var trail: Array = _heads.get(int(neck.id),[])
	var fade := exp(-maxf(0.0,rel-active)/0.03)
	var pal := PRIM.ramp(color)
	var j := 0
	for row: Array in [[3,0.14],[6,0.26]]:
		var back := int(row[0])
		if trail.size()>back:
			var old: Dictionary = trail[trail.size()-1-back]
			if Vector2(old.pos).distance_to(neck.position)>=45.0: FX.silhouette(canvas,mask,old.pos,float(old.angle),pal[2],float(row[1])*fade,factor,j*31.0+5.0)
		j += 1

func _head_mask(kind: String) -> Dictionary:
	if _masks.has(kind): return _masks[kind]
	_masks[kind] = {}
	var art := get_node_or_null("HeadArtwork")
	if art==null: return {}
	var texture: Texture2D = art.head_textures.get(StringName(kind))
	if texture==null: return {}
	var image := texture.get_image()
	if image==null: return {}
	if image.is_compressed(): image.decompress()
	var data := PackedByteArray()
	data.resize(image.get_width()*image.get_height())
	for y in image.get_height():
		for x in image.get_width(): data[y*image.get_width()+x] = 1 if image.get_pixel(x,y).a>0.5 else 0
	_masks[kind] = {"w":image.get_width(),"h":image.get_height(),"m":data}
	return _masks[kind]

func _neck_by_key(key: int) -> Dictionary:
	for neck: Dictionary in state.get("necks",[]):
		if int(neck.get("key",-1))==key: return neck
	return {}

func apply_frame(body: Dictionary, _attack: Dictionary = {}, _appearance: Dictionary = {}) -> void:
	var clock := float(body.clock)
	_advance_bursts(maxf(0.0,clock-_burst_clock) if _burst_clock>=0.0 else 0.0)
	_burst_clock = clock
	state = PRESENT.apply(body,_memory)
	for neck: Dictionary in state.get("necks",[]):
		var trail: Array = _heads.get(int(neck.id),[])
		trail.append({"pos":neck.position,"angle":neck.facing})
		if trail.size()>16: trail.pop_front()
		_heads[int(neck.id)] = trail
	queue_redraw()
	position = body.position
	rotation = 0.0
	visible = body.mode<4
	hit = float(body.flash)
	modulate = Color(1.5,1.5,1.5) if hit>0.0 else Color.WHITE
	for child in get_children():
		if child.has_method("apply_frame"): child.apply_frame(state)
	if arena==null and body.has("arena"):
		arena = preload("res://scripts/bosses/hydra_arena.gd").new()
		add_child(arena)
		arena.top_level = true
		arena.position = Vector2.ZERO
		arena.z_index = 3
		arena.bounds = body.arena
		arena.thickness = float(body.arena_wall_thickness)
		arena._build_rubble()
		arena._build_mesh()
		arena.queue_redraw()
	if arena!=null: arena.visible = visible and body.has("arena")
	var live := {}
	for effect: Dictionary in body.get("effects",[]):
		live[effect.id] = true
		if not effects.has(effect.id):
			if white==null:
				var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
				image.fill(Color.WHITE)
				white = ImageTexture.create_from_image(image)
			var scene: PackedScene = shot_scenes.get(String(effect.get("technique","")),preload("res://scenes/attacks/hydra_shape.tscn"))
			var line := scene.instantiate()
			line.visual_profile_key = "boss/move/hydra/"+String(effect.get("technique","bite_thrust"))
			line.visual_component = "shape"
			add_child(line)
			line.top_level = true
			line.global_position = Vector2.ZERO
			line.configure(self,StringName(effect.kind),effect.points,white)
			effects[effect.id] = line
		effects[effect.id].update_effect(effect,float(body.clock))
		effects[effect.id].visible = String(effect.kind) not in HIDDEN_LINES
		if effect.get("final",false): effects[effect.id].modulate.a=float(body.get("final_alpha",1.0))
	for id in effects.keys():
		if not live.has(id): effects[id].queue_free();effects.erase(id)

func frame_event(event: Dictionary) -> void:
	var cue := String(event.get("cue",""))
	if cue in ["phase_changed","exposed","defeated"]:
		for burst in _bursts: burst.sprite.queue_free()
		_bursts.clear()
		return
	if cue not in ["growth_started","separation_started","head_destroyed","hit"]: return
	if white==null:
		var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		white = ImageTexture.create_from_image(image)
	var values: Dictionary = EFFECT_SETTINGS.resolved_values(BURST_KEY,scene_file_path)
	var large := cue in ["growth_started","separation_started"]
	var diameter := 520.0 if large else 220.0 if cue=="head_destroyed" else 140.0
	var color: Color = {"vortex":Color("#70ffe0"),"thunder":Color("#77bbff"),"debris":Color("#dbac68"),"immortal":Color("#ffe69a")}.get(String(event.get("kind","body")),values.get("attack_color",Color("#ff765c")))
	if cue=="hit": color = values.get("hit_color",Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.texture = white
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE*diameter/2.0
	var burst_material := ShaderMaterial.new()
	burst_material.shader = BURST_SHADER
	burst_material.set_shader_parameter("tint",color)
	_burst_serial += 1
	burst_material.set_shader_parameter("seed",float(_burst_serial%19))
	sprite.material = burst_material
	add_child(sprite)
	sprite.top_level = true
	sprite.global_position = event.position
	_bursts.append({"sprite":sprite,"age":0.0,"large":large,"diameter":diameter})
	if _bursts.size()>96:
		var oldest: Dictionary = _bursts.pop_front()
		oldest.sprite.queue_free()
	_advance_bursts(0.0)

func _advance_bursts(dt: float) -> void:
	var values: Dictionary = EFFECT_SETTINGS.resolved_values(BURST_KEY,scene_file_path)
	for burst in _bursts.duplicate():
		burst.age += dt
		var duration := maxf(0.01,float(values.get("burst_large_seconds" if burst.large else "burst_small_seconds",0.8 if burst.large else maxf(float(values.get("flash_duration",0.25)),0.3))))
		var age: float = burst.age/ShaderTuning.burst_time_scale(BURST_KEY,scene_file_path)
		var burst_material: ShaderMaterial = burst.sprite.material
		ShaderTuning.apply(burst_material,BURST_KEY,scene_file_path)
		burst_material.set_shader_parameter("pixels",float(burst.diameter)/4.0*float(values.get("burst_pixel_scale",1.0)))
		burst_material.set_shader_parameter("progress",clampf(age/duration,0.0,1.0))
		burst.sprite.visible = age<duration
		if age>=duration and not ShaderTuning.previewing():
			burst.sprite.queue_free()
			_bursts.erase(burst)
