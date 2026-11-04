## 戦闘の参照を持たず、生成済みパーツへ本体の値だけを反映する。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const POUNCE_MOTION := preload("res://scripts/render/bosses/canis_motion.gd")
const LANDING_DUST := preload("res://scripts/render/bosses/canis_landing.gd")
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
@onready var parts: Node2D = $Parts
func _ready() -> void:
	EFFECT_SETTINGS.apply_key(self,"boss/body/canis_major")
	for name: String in ["RearLeftLeg","RearRightLeg","FrontLeftLeg","FrontRightLeg","Body","Head","Tail"]:
		_part_origins[name] = (parts.get_node(name) as Node2D).position
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
	if event.get("type",&"")==&"combat_damage":
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
	if not state.is_empty() and int(body.phase)>int(state.phase): _pulse_until = float(body.clock)+0.35
	if not state.is_empty() and (body.get("calling",false)!=state.get("calling",false) or body.get("barking",false) and not state.get("barking",false)): _pulse_until = float(body.clock)+0.35
	pulse = maxf(0.0,_pulse_until-float(body.clock))
	if flames!=null: flames.apply_frame(body.get("flames",[]),float(body.clock),body.get("burning",[]),{"position":body.position+Vector2.from_angle(float(body.facing))*float(body.radius)*0.84,"profile":attack.get("flame_profile",5),"active":attack.get("technique","")=="blaze" and int(attack.get("stage",5))==0})
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
	var phase := 1.0-pow(1.0-clampf(float(body.phase_progress),0.0,1.0),3.0)
	parts.get_node("Head/Sirius").set_state(float(body.clock),phase,float(attack.get("glow",body.charge)) if int(attack.get("stage",5)) in [0,1] else float(body.charge),pulse)
	modulate = Color(1.6,1.6,1.6) if hit>0.0 else Color.WHITE

func set_reference_canvas(canvas) -> void:
	_reference_canvas = canvas

func draw_reference(canvas, _real_dt: float) -> void:
	if canvas!=_reference_canvas or _land_clock<0.0 or state.is_empty(): return
	LANDING_DUST.draw(canvas,_land_feet,_land_facing,float(state.clock)-_land_clock)

## 描画専用の短い履歴。戦闘の猟犬位置へ書き戻さない。
var _trails: Dictionary = {}
var _lunge_layer: Node2D
func _track_command(body: Dictionary, attack: Dictionary, dt: float) -> void:
	if _lunge_layer==null:
		_lunge_layer = Node2D.new()
		_lunge_layer.top_level = true
		_lunge_layer.draw.connect(_draw_command_lunges)
		add_child(_lunge_layer)
	var live := {}
	if attack.get("technique","") in ["command","bay"] and int(attack.get("stage",5)) in [0,1]:
		for lunge: Dictionary in body.get("lunges",[]):
			live[lunge.actor] = true
			var trail: Dictionary = _trails.get(lunge.actor,{"points":PackedVector2Array(),"radius":lunge.radius})
			if dt>0.0 or trail.points.is_empty():
				trail.points.append(lunge.position)
				if trail.points.size()>6: trail.points = trail.points.slice(trail.points.size()-6)
			_trails[lunge.actor] = trail
	for id in _trails.keys():
		if not live.has(id): _trails.erase(id)
	_lunge_layer.queue_redraw()
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
	if (technique.get("technique","")=="pounce" or (technique.get("technique","") in ["bay","hunt_pounce"] and technique.get("jumping",false))) and int(technique.get("stage",5))==0:
		var reach := position.distance_to(technique.aim)
		var color := Color("#ff667d") if technique.locked else Color("#f2b567")
		draw_line(Vector2(float(state.radius),0.0),Vector2(maxf(float(state.radius),reach),0.0),Color(color,0.35+float(state.charge)*0.4),6.0 if technique.locked else 3.0)
		draw_arc(Vector2(reach,0.0),float(state.radius)*0.5,0.0,TAU,24,Color(color,0.6),3.0)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE*float(state.radius)/100.0)
	if int(technique.get("stage",5))==2:
		var alpha := 0.45+sin(float(state.clock)*14.0)*0.25
		draw_arc(Vector2(-6,0),106.0,0.0,TAU,32,Color(sirius_halo_color,alpha),pixel_size*2.0)
	var calling: bool = state.get("calling",false) or state.get("barking",false)
	var shouting: bool = technique.get("technique","") in ["command","stream","bay","hunt_pounce"] and int(technique.get("stage",5))==0 and not technique.get("jumping",false)
	if not calling and not shouting:
		draw_set_transform(Vector2.ZERO)
		return
	for ring in 2:
		var grow := fmod(float(state.clock)*2.5+ring*0.5,1.0)
		draw_arc(Vector2(84.0,0.0),20.0+grow*90.0,0.0,TAU,32,Color(Color("#f2b567"),1.0-grow),pixel_size)
	draw_set_transform(Vector2.ZERO)
func _draw_command_lunges() -> void:
	for id in _trails:
		var trail: Dictionary = _trails[id]
		var points: PackedVector2Array = trail.points
		var radius: float = trail.radius
		for j in range(1,points.size()):
			var f := float(j)/float(points.size()-1)
			_lunge_layer.draw_line(points[j-1],points[j],Color(Color("#ff667d"),0.15+0.55*f),radius*(0.4+0.9*f),true)
		var at: Vector2 = points[points.size()-1]
		var flicker := 0.75+0.25*sin(float(state.clock)*40.0+float(id))
		_lunge_layer.draw_circle(at,radius*1.9,Color(Color("#ff667d"),0.22*flicker))
		_lunge_layer.draw_circle(at,radius*1.3,Color(Color("#f2b567"),0.35*flicker))
		_lunge_layer.draw_arc(at,radius*1.3,0.0,TAU,20,Color(Color("#e8f6ff"),0.8*flicker),2.1,true)

## 輪と影は C++ の読取値だけを描く。
const NOVA_KEY := "res://scenes/bosses/canis_major/nova_visual.tscn"
const SIRIUS_COLOR := Color("#cfefff")
var _nova := {}
var _nova_layer: Node2D
var _nova_flash: ColorRect
func _track_nova(body: Dictionary) -> void:
	if _nova_layer==null:
		_nova_layer = Node2D.new()
		_nova_layer.top_level = true
		_nova_layer.draw.connect(_draw_nova)
		add_child(_nova_layer)
		var layer := CanvasLayer.new()
		layer.layer = 80
		add_child(layer)
		_nova_flash = ColorRect.new()
		_nova_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_nova_flash)
	_nova = body.get("nova",{})
	var age := float(_nova.get("age",-1.0))-float(_nova.get("warn",0.0))
	var duration := EFFECT_SETTINGS.number(NOVA_KEY,"flash_duration",0.08)
	_nova_flash.size = get_viewport_rect().size
	_nova_flash.color = Color(Color.WHITE,EFFECT_SETTINGS.number(NOVA_KEY,"flash_opacity",0.12)*(1.0-age/maxf(duration,0.001)) if not _nova.is_empty() and age>=0.0 and age<duration else 0.0)
	_nova_layer.queue_redraw()
func _nova_shadow(point: Vector2) -> bool:
	var to: Vector2 = point-_nova.source
	for shadow: Dictionary in _nova.shadows:
		if to.length()>float(shadow.near) and absf(wrapf(to.angle()-float(shadow.angle),-PI,PI))<=float(shadow.half): return true
	return false
func _draw_nova() -> void:
	if _nova.is_empty(): return
	var r: Dictionary = _nova
	var age: float = float(_nova.age)
	var source: Vector2 = _nova.source
	var light := clampf(age/maxf(float(r.warn),0.001),0,1) if age < float(r.warn) else maxf(0.0,1.0-(age-float(r.warn))/maxf(float(r.after),0.001))
	var light_alpha := EFFECT_SETTINGS.number(NOVA_KEY,"warning_glow_opacity",0.06)
	# 照明はなめらかな面にし、広がる攻撃の輪と同じ模様を作らない。
	var light_radius := maxf(900.0,float(r.ring_end))
	for k in 64:
		var a := Vector2.from_angle(k*TAU/64.0)*light_radius
		var b := Vector2.from_angle((k+1)*TAU/64.0)*light_radius
		_nova_layer.draw_polygon(PackedVector2Array([source,source+a,source+b]),PackedColorArray([Color(SIRIUS_COLOR,light*light_alpha),Color(SIRIUS_COLOR,0.0),Color(SIRIUS_COLOR,0.0)]))
	if age < float(r.warn):
		var progress := clampf(age/maxf(float(r.warn),0.001),0,1)
		var ray_length := EFFECT_SETTINGS.number(NOVA_KEY,"warning_ray_length",100.0)*lerpf(0.25,1.0,progress)
		var pulse := 0.7+0.3*sin(progress*PI*6.0)
		for k in 8:
			var u := Vector2.from_angle(k*TAU/8.0)
			_nova_layer.draw_line(source+u*10.0,source+u*ray_length,Color(SIRIUS_COLOR,pulse*progress),EFFECT_SETTINGS.number(NOVA_KEY,"warning_ray_width",4.0))
		_nova_layer.draw_circle(source,12.0+progress*18.0,Color(1,1,1,0.2+progress*0.5))
	for shadow in _nova.shadows:
		var polygon := PackedVector2Array()
		for k in 13:
			var angle := float(shadow.angle)+lerpf(-float(shadow.half),float(shadow.half),k/12.0)
			polygon.append(source+Vector2.from_angle(angle)*float(shadow.near))
		for k in range(12,-1,-1):
			var angle := float(shadow.angle)+lerpf(-float(shadow.half),float(shadow.half),k/12.0)
			polygon.append(source+Vector2.from_angle(angle)*maxf(900.0,float(r.ring_end)))
		_nova_layer.draw_colored_polygon(polygon,Color(0.0,0.005,0.015,light*0.9))
	for ring in int(r.rings):
		var elapsed: float = age-float(r.warn)-ring*float(r.ring_gap)
		if elapsed < 0: continue
		var radius: float = 30.0+float(r.ring_speed)*elapsed
		if radius > float(r.ring_end): continue
		for k in 256:
			var a := TAU*k/256.0
			var b := TAU*(k+1)/256.0
			if _nova_shadow(source+Vector2.from_angle((a+b)*0.5)*radius): continue
			var from := source+Vector2.from_angle(a)*radius
			var to := source+Vector2.from_angle(b)*radius
			var width := float(r.ring_band)*2.0
			# 太い帯が判定の全幅。暗い縁で照明から分離し、白い先端で進む向きを示す。
			var outline := EFFECT_SETTINGS.number(NOVA_KEY,"ring_outline_width",3.0)
			var core := minf(width,EFFECT_SETTINGS.number(NOVA_KEY,"ring_core_width",8.0))
			_nova_layer.draw_line(from,to,Color(SIRIUS_COLOR,0.08),width*EFFECT_SETTINGS.number(NOVA_KEY,"ring_halo_scale",1.6))
			_nova_layer.draw_line(from,to,Color(0.005,0.015,0.04,0.95),width+outline*2.0)
			_nova_layer.draw_line(from,to,Color("#65baff"),width)
			_nova_layer.draw_line(from,to,Color(0.95,0.99,1.0,1.0),core)
			var front := radius+float(r.ring_band)-1.0
			_nova_layer.draw_line(source+Vector2.from_angle(a)*front,source+Vector2.from_angle(b)*front,Color.WHITE,minf(2.0,width))
