## 戦闘の点列と寸法を読むだけの表示。部位やHPへ書き戻さない。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
var state := {}
var attack := {}
var _move_style := {}
var _styles := {}
var hit := 0.0
var _parts: Node2D
func _ready() -> void:
	z_index = 1
	_parts = preload("res://scripts/bosses/draco_parts.gd").new()
	add_child(_parts)
	EFFECT_SETTINGS.apply_key(self,"boss/body/draco")
func apply_frame(body: Dictionary, current: Dictionary = {}, _appearance: Dictionary = {}) -> void:
	attack = current
	state = body
	_styles = _appearance.get("draco_styles",{})
	_move_style = _styles.get(current.get("technique",""),{})
	position = body.position
	rotation = body.facing
	visible = body.mode<4
	var intro: Dictionary = body.get("intro",{})
	var intro_active: bool = intro.get("active",false)
	_parts.visible = not intro_active or intro.time>=float(body.get("entrance_quiet",2.5))
	hit = float(body.flash)
	var points := PackedVector2Array()
	for point: Vector2 in body.body_points: points.append(to_local(point))
	_parts.pose(points,float(body.body_width)*float(body.perspective_scale),float(body.head_scale)*float(body.perspective_scale),float(body.alpha)*smoothstep(0.0,1.0,float(intro.emerged)) if intro_active else float(body.alpha),false,hit)
	queue_redraw()
func _draw() -> void:
	if state.is_empty() or not visible: return
	_draw_rift()
	_draw_technique()
	_draw_impacts()
	var cycle: Dictionary = state.get("cycle",{})
	if cycle.get("stage",0)==2:
		for j in 16:
			var k := fmod(float(cycle.time)*0.5+j/16.0,1.0)
			var at := Vector2.from_angle(j*2.399963)*450.0*(1.0-k)
			draw_circle(at,4.0,Color(0.8,0.9,1.0,k))
	var intro: Dictionary = state.get("intro",{})
	var glow: float = float(intro.chest_glow) if intro.get("active",false) else 1.0
	var depth := float(state.perspective_scale)
	var core := Vector2(-110.0*float(state.head_scale)*depth,0)
	var pulse := 0.85+sin(float(state.clock)*3.0)*0.15
	draw_circle(core,43.0*depth,Color(0.38,0.59,1.0,0.16*pulse*float(state.alpha)*glow))
	preload("res://scripts/bosses/draco_form.gd").star(self,core,27.0*depth,Color(0.85,0.96,1.0,float(state.alpha)*glow))

func _draw_rift() -> void:
	var intro: Dictionary = state.get("intro",{})
	if not intro.get("active",false) or intro.rift<=0.0: return
	var opening: float = intro.rift
	var center: Vector2 = intro.rift_center
	var axis := Vector2.DOWN
	var line := PackedVector2Array()
	for j in 19:
		var along := float(j-9)*55.0*opening
		var side := (sin(j*2.3)*24.0+sin(j*4.9)*12.0)*opening
		line.append(to_local(center+axis*along+axis.orthogonal()*side))
	draw_polyline(line,Color(0.41,0.25,0.88,0.22),160.0*opening,false)
	draw_polyline(line,Color("#5a4d91"),105.0*opening,false)
	draw_polyline(line,Color("#050612"),88.0*opening,false)
	if intro.eyes>0.0 and intro.emerged<0.4:
		for side in [-1,1]:
			var at: Vector2 = to_local(center+axis.orthogonal()*side*65.0)
			var offset := axis.rotated(-rotation)*12.0
			draw_line(at-offset,at+offset,Color(1.0,0.1,0.3,float(intro.eyes)),8.0,false)

func _draw_technique() -> void:
	if attack.is_empty() or int(attack.get("stage",5))>=5 or _move_style.is_empty(): return
	var progress: float = attack.get("windup_progress",0.0) if int(attack.get("stage",0))==0 else 1.0
	var paths: Array = attack.get("telegraph_paths",[])
	if paths.is_empty() and not attack.get("warning",PackedVector2Array()).is_empty(): paths=[attack.warning]
	for warning: PackedVector2Array in paths:
		if warning.size()<2: continue
		var width: float = attack.warning_width
		var path := PackedVector2Array()
		for point in warning: path.append(to_local(point))
		draw_polyline(path,Color(1.0,0.61,0.25,0.09+progress*0.09),width*2.0,false)
		for j in range(path.size()-1):
			var normal := (path[j+1]-path[j]).normalized().orthogonal()*width
			for side in [-1,1]: draw_line(path[j]+normal*side,path[j+1]+normal*side,Color(1.0,0.69,0.36,float(_move_style.telegraph_edge_opacity)+progress*0.4),float(_move_style.telegraph_line_width),false)
		preload("res://scripts/bosses/draco_form.gd").star(self,path[-1],10.0,Color(1.0,0.86,0.6,0.7))
	for target: Vector2 in attack.get("telegraph_points",PackedVector2Array()):
		var at: Vector2 = to_local(target)
		var radius: float = attack.get("telegraph_radius",attack.warning_width)
		draw_arc(at,radius,0,TAU,48,Color(1.0,0.7,0.35,0.8),float(_move_style.telegraph_line_width),false)
		draw_arc(at,radius*(1.7-progress*0.7),-PI*0.5,TAU-PI*0.5,48,Color(1.0,0.77,0.5,0.8),4.0,false)
		for side in [-1,1]:
			draw_line(at+Vector2(side*(radius+10.0),0),at+Vector2(side*(radius+25.0),0),Color("#f8c879"),float(_move_style.telegraph_line_width),false)
			draw_line(at+Vector2(0,side*(radius+10.0)),at+Vector2(0,side*(radius+25.0)),Color("#f8c879"),float(_move_style.telegraph_line_width),false)
	var points: PackedVector2Array = attack.get("attack_points",PackedVector2Array())
	if points.size()>=2 and points[0].distance_to(points[1])>=8.0:
		var line := PackedVector2Array()
		for point in points: line.append(to_local(point))
		if attack.get("technique","")=="breath":
			for j in range(1,line.size()-1):
				if absf((line[j]-line[0]).cross(line[j+1]-line[0]))>0.1: draw_colored_polygon(PackedVector2Array([line[0],line[j],line[j+1]]),Color(0.34,0.46,1.0,0.5))
			draw_polyline(line,Color(0.68,0.86,1.0,0.8),float(_move_style.active_line_width),false)
			return
		draw_polyline(line,Color(0.52,0.72,1.0,float(_move_style.motion_trail_opacity)),14.0,false)
		draw_polyline(line,Color(0.86,0.95,1.0,0.7),float(_move_style.telegraph_line_width),false)

func _draw_impacts() -> void:
	var form = preload("res://scripts/bosses/draco_form.gd")
	for effect: Dictionary in state.get("impacts",[]):
		var style: Dictionary = _styles.get(effect.technique,{})
		if style.is_empty() or effect.age>=float(style.impact_lifetime): continue
		var f := clampf(float(effect.age)/float(style.impact_lifetime),0.0,1.0)
		var center: Vector2 = to_local(effect.position)
		var radius: float = effect.radius
		var size := radius*(0.35+f*1.4)
		draw_arc(center,size,0,TAU,48,Color(0.42,0.55,1.0,(1.0-f)*0.6),maxf(2.0,12.0*(1.0-f)),false)
		draw_arc(center,size*0.72,0,TAU,48,Color(0.72,0.87,1.0,(1.0-f)*0.8),float(style.telegraph_line_width),false)
		form.star(self,center,radius*0.8*(1.0-f),Color(0.88,0.96,1.0,(1.0-f)*0.9))
		for j in 8:
			var direction := Vector2.from_angle(float(j)*TAU/8.0+0.2)
			var at := center+direction*size
			var cross := direction.orthogonal()*radius*0.07*(1.0-f)
			form.quad(self,at-direction*radius*0.22,at+cross,at+direction*radius*0.1,at-cross,Color(0.56,0.62,1.0,1.0-f))
