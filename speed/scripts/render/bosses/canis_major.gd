## 戦闘の参照を持たず、生成済みパーツへ本体の値だけを反映する。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const POUNCE_MOTION := preload("res://scripts/render/bosses/canis_motion.gd")
const POUNCE_SHADOW := preload("res://scripts/render/bosses/canis_pounce_shadow.gd")
const EMBERS := preload("res://scripts/render/bosses/canis_embers.gd")
const FIRE_PIXELS := preload("res://scripts/render/bosses/canis_fire_pixels.gd")
const HOUND_BURN := preload("res://scripts/render/bosses/canis_hound_burn.gd")
const LANDING_DUST := preload("res://scripts/render/bosses/canis_landing.gd")
const NOVA_DISPLAY := preload("res://scripts/render/bosses/canis_nova.gd")
const BURST_DISPLAY := preload("res://scripts/render/bosses/canis_burst.gd")
const NOVA_OVERLAY := preload("res://scripts/render/bosses/canis_nova_overlay.gd")
const FX_SETTINGS := preload("res://data/visuals/fx_reference.tres")
const REFERENCE_WHITE := preload("res://shaders/fx_reference_white.gdshader")
@export var pixel_size := 3.0
@export var sirius_color := Color("#e8f6ff")
@export var sirius_halo_color := Color("#9fe8ff")
@export var sirius_glow_scale := 1.0
var state := {}
var technique := {}
var hit := 0.0
var pulse := 0.0
var _pulse_until := -1.0
var _clock := -1.0
var gait := 0.0
var _walk_phase := 0.0
var flames: Node2D
var _part_origins := {}
var _land_clock := -1.0
var _land_facing := 0.0
var _land_feet: Array = []
var _reference_canvas
var _nova_params := {}
var _nova_overlay
var _burst_overlay
var _pounce_shadow
var _reference_white := 0.0
var _white_material: ShaderMaterial
var _white_sprites: Array[Dictionary] = []
@onready var parts: Node2D = $Parts
func _ready() -> void:
	EFFECT_SETTINGS.apply_key(self,"boss/body/canis_major")
	_nova_params = FX_SETTINGS.for_id("O-nova")
	for name: String in ["RearLeftLeg","RearRightLeg","FrontLeftLeg","FrontRightLeg","Body","Head","Tail"]:
		_part_origins[name] = (parts.get_node(name) as Node2D).position
	_create_reference_white()
	_pounce_shadow = POUNCE_SHADOW.new()
	add_child(_pounce_shadow)
	_pounce_shadow.setup(parts)
	visibility_changed.connect(_sync_reference_shadow_visibility)
	z_index = 1
func setup_flames(scope: ContentResourceScope, assets: Dictionary) -> void:
	flames = preload("res://scripts/render/bosses/canis_flames.gd").new()
	flames.setup(scope,assets)
	add_child(flames)
func clear_flames() -> void:
	if flames!=null: flames.clear()
func frame_event(event: Dictionary) -> void:
	if event.get("type",&"")==&"canis_cue" and event.get("cue","")=="landing":
		_land_clock = float(event.world_time)
		_land_facing = float(event.angle)
		if not state.is_empty(): _land_feet = POUNCE_MOTION.landing_feet(parts,_part_origins,event.position,_land_facing,float(state.radius)/100.0)
		if not state.is_empty(): apply_frame(state,technique)
	if event.get("type",&"")==&"combat_damage" and event.get("cause",&"")!=&"ram":
		hit = 0.18
		queue_redraw()
	if event.get("type",&"")==&"canis_cue" and event.cue in ["aim_locked","pounce","command","sirius","phase_changed","howl","call","called","stream_windup","bay_windup","entrance_bark","nova_windup","nova_flash","relay_windup","relay_mark","relay_fire","flame_windup","flame_start"]:
		_pulse_until = float(event.world_time)+0.35
		if not state.is_empty(): apply_frame(state,technique)
	if flames!=null: flames.frame_event(event)
func apply_frame(body: Dictionary, attack: Dictionary = {}, _appearance: Dictionary = {}) -> void:
	var dt: float = maxf(0.0,float(body.clock)-_clock) if _clock>=0.0 else 0.0
	if _clock>float(body.clock):
		gait = 0.0
		_walk_phase = 0.0
		_pulse_until = -1.0
		_land_clock = -1.0
		_land_feet.clear()
		_trails.clear()
	if not state.is_empty() and int(body.phase)>int(state.phase): _pulse_until = float(body.clock)+0.35
	if not state.is_empty() and (body.get("calling",false)!=state.get("calling",false) or body.get("barking",false) and not state.get("barking",false)): _pulse_until = float(body.clock)+0.35
	pulse = maxf(0.0,_pulse_until-float(body.clock))
	if flames!=null: flames.apply_frame(body.get("flames",[]),float(body.clock),body.get("burning",[]),{"position":body.position+Vector2.from_angle(float(body.facing))*float(body.radius)*0.84,"profile":attack.get("flame_profile",5),"active":attack.get("technique","")=="blaze" and int(attack.get("stage",5))==0},body.get("fire_visual",[]))
	_track_command(body,attack,dt)
	_track_nova(body)
	if not state.is_empty() and dt>0.0:
		var previous_position: Vector2 = state.position
		_walk_phase += previous_position.distance_to(body.position)/maxf(float(body.radius)*0.95,0.001)*TAU
	state = body
	technique = attack
	_clock = float(body.clock)
	position = body.position
	rotation = body.facing
	visible = body.mode<4
	hit = maxf(float(body.flash),hit-dt)
	gait += dt*(18.0 if int(attack.get("stage",5))==1 else 9.0)
	var k := float(body.radius)/100.0
	var crouch := float(attack.get("crouch",0.0)) if int(attack.get("stage",5)) in [0,1] else 0.0
	var stretch := float(attack.get("stretch",1.0)) if int(attack.get("stage",5)) in [0,1] else 1.0
	parts.scale = Vector2(k*(1.0+crouch*0.15),k*stretch)
	var moving: bool = body.velocity.length()>5.0
	var legs := ["RearLeftLeg","RearRightLeg","FrontLeftLeg","FrontRightLeg"]
	for name: String in _part_origins:
		var part := parts.get_node(name) as Node2D
		part.position = _part_origins[name]
		part.scale = Vector2.ONE
	parts.get_node("Body").rotation = 0.0
	for i in legs.size(): parts.get_node(legs[i]).rotation = 0.0
	parts.get_node("Tail").rotation = sin(gait*0.4)*0.07
	parts.get_node("Head").rotation = -0.45*smoothstep(0.0,0.65,float(body.charge)) if attack.get("technique","")=="howl" and int(attack.get("stage",5))==0 else 0.0
	if moving:
		# canisPose の歩行は時間ではなく移動距離で足を一周させる。
		var offsets := [0.0,0.5,0.25,0.75]
		for i in legs.size():
			var part := parts.get_node(legs[i]) as Node2D
			var step_phase := fposmod(_walk_phase/TAU+offsets[i],1.0)
			var stance := step_phase<0.72
			var stroke := 1.0-2.0*step_phase/0.72 if stance else -1.0+2.0*smoothstep(0.72,1.0,step_phase)
			var lift := 0.0 if stance else sin((step_phase-0.72)/0.28*PI)
			part.position = _part_origins[legs[i]]+Vector2(lift*3.0*(1.0 if i%2!=0 else -1.0),stroke*11.0)
			part.rotation = stroke*0.26
			part.scale = Vector2(1.0,1.0-lift*0.18)
		parts.get_node("Tail").rotation += sin(_walk_phase)*0.12
		parts.get_node("Body").rotation = sin(_walk_phase)*0.05
		parts.get_node("Body").position = Vector2(sin(_walk_phase)*1.5,absf(sin(_walk_phase))*2.0)
		parts.get_node("Head").rotation -= sin(_walk_phase)*0.07
	var motion: Dictionary = attack.get("pounce_motion",{})
	var land_age := float(body.clock)-_land_clock if _land_clock>=0.0 else -1.0
	if not motion.is_empty() and not motion.get("done",false):
		parts.scale = Vector2.ONE*k
		var flying := bool(motion.jumping)
		POUNCE_MOTION.apply(parts,_part_origins,"strike" if flying else "load",float(motion.stage_time),float(motion.active_time if flying else motion.warn_time))
	elif land_age>=0.0 and land_age<0.5:
		parts.scale = Vector2.ONE*k
		POUNCE_MOTION.apply(parts,_part_origins,"catch",land_age,0.0)
	var nova: Dictionary = body.get("nova",{})
	if not nova.is_empty():
		parts.get_node("Head").position = Vector2(0,float(nova.head_y))
		parts.get_node("Head").rotation = float(nova.head_rotation)
	var image_pose: Array = body.get("image_pose",[])
	if image_pose.size()==7:
		parts.scale = Vector2.ONE*k
		var names := ["Tail","RearLeftLeg","RearRightLeg","FrontLeftLeg","FrontRightLeg","Body","Head"]
		for i in names.size():
			var node := parts.get_node(names[i]) as Node2D
			var pose: Dictionary = image_pose[i]
			node.position = pose.position
			node.rotation = pose.rotation
			node.scale = pose.scale
	var phase := 1.0-pow(1.0-clampf(float(body.phase_progress),0.0,1.0),3.0)
	parts.get_node("Head/Sirius").set_state(float(body.clock),phase,float(attack.get("glow",body.charge)) if int(attack.get("stage",5)) in [0,1] else float(body.charge),pulse)
	modulate = Color(1.6,1.6,1.6) if hit>0.0 else Color.WHITE

func set_reference_canvas(canvas) -> void:
	_reference_canvas = canvas

## 体当たり時の白は通常被弾とは別に、各部位の画像の上へ加算する。
func set_reference_hit(white: float) -> void:
	_reference_white = clampf(white,0.0,1.0)
	_sync_reference_white()

func _create_reference_white() -> void:
	_white_material = ShaderMaterial.new()
	_white_material.shader = REFERENCE_WHITE
	for name: String in ["RearLeftLeg","RearRightLeg","FrontLeftLeg","FrontRightLeg","Body","Head","Tail"]:
		var source := parts.get_node(name+"/Sprite") as Sprite2D
		var overlay := Sprite2D.new()
		overlay.material = _white_material
		overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		source.add_child(overlay)
		_white_sprites.append({"source":source,"overlay":overlay})
	_sync_reference_white()

func _sync_reference_white() -> void:
	if _white_material==null: return
	_white_material.set_shader_parameter("strength",_reference_white)
	for entry: Dictionary in _white_sprites:
		var source: Sprite2D = entry.source
		var overlay: Sprite2D = entry.overlay
		overlay.visible = _reference_white>0.0 and source.texture!=null
		if not overlay.visible: continue
		overlay.texture = source.texture
		overlay.centered = source.centered
		overlay.offset = source.offset
		overlay.flip_h = source.flip_h
		overlay.flip_v = source.flip_v
		overlay.hframes = source.hframes
		overlay.vframes = source.vframes
		overlay.frame = source.frame
		overlay.region_enabled = source.region_enabled
		overlay.region_rect = source.region_rect
		overlay.self_modulate.a = source.self_modulate.a

func setup_reference_shadows(parent: Node2D) -> void:
	if _pounce_shadow.get_parent()!=parent: _pounce_shadow.reparent(parent)

func setup_reference_front(parent: Node2D) -> void:
	if is_instance_valid(_nova_overlay) and _nova_overlay.get_parent()!=parent: _nova_overlay.reparent(parent)
	if flames!=null and flames.get_parent()!=parent: flames.reparent(parent)

func _sync_reference_shadow_visibility() -> void:
	if is_instance_valid(_pounce_shadow) and not is_visible_in_tree(): _pounce_shadow.hide()

func setup_reference_overlay(parent: Node2D) -> void:
	if is_instance_valid(_nova_overlay): return
	_nova_overlay = NOVA_OVERLAY.new()
	parent.add_child(_nova_overlay)
	_burst_overlay = BURST_DISPLAY.new()
	parent.add_child(_burst_overlay)

func _exit_tree() -> void:
	if is_instance_valid(_pounce_shadow) and _pounce_shadow.get_parent()!=self: _pounce_shadow.queue_free()
	if is_instance_valid(flames) and flames.get_parent()!=self: flames.queue_free()
	if is_instance_valid(_nova_overlay): _nova_overlay.queue_free()
	if is_instance_valid(_burst_overlay): _burst_overlay.queue_free()

func draw_reference(canvas, _real_dt: float) -> void:
	if canvas!=_reference_canvas or state.is_empty(): return
	_pounce_shadow.apply(state,technique,gait,canvas.world_scale*get_viewport_rect().size.y/225.0)
	if is_instance_valid(_burst_overlay): _burst_overlay.apply_frame(state.get("blaze_bursts",[]),float(state.clock))
	HOUND_BURN.draw(canvas,_trails,float(state.clock))
	if not _nova.is_empty():
		NOVA_DISPLAY.draw_field(canvas,_nova,_nova_params)
		NOVA_DISPLAY.draw_flare(canvas,_nova,_nova_params)
	EMBERS.draw(canvas,state.get("fire_visual",[]),float(state.clock),get_viewport_rect().size.y/225.0)
	if _land_clock>=0.0: LANDING_DUST.draw(canvas,_land_feet,_land_facing,float(state.clock)-_land_clock)
	FIRE_PIXELS.draw(canvas,state.get("fire_visual",[]))
	if is_instance_valid(_nova_overlay):
		_nova_overlay.update_overlay(_nova,_nova_params,float(state.facing),canvas.world_scale*get_viewport_rect().size.y/225.0)

## 飛びかかりは技の回復後も各猟犬の寿命まで続く。履歴は表示だけが持つ。
var _trails: Dictionary = {}
func _track_command(body: Dictionary, _attack: Dictionary, dt: float) -> void:
	var live := {}
	var indices := {}
	var led: Array = body.get("led",[])
	for i in led.size(): indices[int(led[i].id)] = i
	for lunge: Dictionary in body.get("lunges",[]):
		var id := int(lunge.actor)
		live[id] = true
		var trail: Dictionary = _trails.get(id,{"points":PackedVector2Array(),"index":indices.get(id,0)})
		trail.position = lunge.position
		trail.radius = lunge.radius
		trail.sprite_radius = lunge.get("sprite_radius",lunge.radius)
		trail.sprite_angle = lunge.get("sprite_angle",0.0)
		trail.facing = (lunge.velocity as Vector2).angle()
		trail.until = lunge.until
		if dt>0.0 or trail.points.is_empty():
			trail.points.append(lunge.position)
			if trail.points.size()>14: trail.points = trail.points.slice(trail.points.size()-14)
		_trails[id] = trail
	for id in _trails.keys():
		if not live.has(id) and float(body.clock)>=float(_trails[id].until)+0.4: _trails.erase(id)
	queue_redraw()
func _draw() -> void:
	for warning: Dictionary in technique.get("warnings",[]):
		var from: Vector2 = warning.from
		var to := from+Vector2.from_angle(float(warning.angle))*float(warning.length)
		draw_line(to_local(from),to_local(to),Color(SIRIUS_COLOR,lerpf(0.12,0.45,float(warning.progress))),lerpf(1.0,3.0,float(warning.progress)))
	if (technique.get("technique","")=="sirius" or (technique.get("technique","") in ["hunt","relay"] and technique.get("aiming",false))) and int(technique.get("stage",5))==0:
		var color := Color("#ff667d") if technique.locked else Color("#e8f6ff")
		var alpha := 0.35 if technique.locked else lerpf(0.12,0.45,float(state.charge))
		var width := float(technique.beam_width) if technique.locked else lerpf(1.0,3.0,float(state.charge))
		var mouth := Vector2(float(state.radius)*0.84,0.0)
		draw_line(mouth,mouth+Vector2(float(technique.beam_length),0.0),Color(color,alpha),width)
	# 咆哮はroar_post、着地は足元の土煙が描く。旧い輪は重ねない。
	draw_set_transform(Vector2.ZERO)
## 閃光の遮蔽場は戦闘側から受け取り、描画側で再計算しない。
const SIRIUS_COLOR := Color("#cfefff")
var _nova := {}
func _track_nova(body: Dictionary) -> void:
	_nova = body.get("nova",{})
