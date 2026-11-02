## 戦闘の点列と寸法を読むだけの表示。部位やHPへ書き戻さない。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
var state := {}
var attack := {}
var _move_style := {}
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
	_move_style = _appearance.get("draco_styles",{}).get(current.get("technique",""),{})
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
	var warning: PackedVector2Array = attack.get("warning",PackedVector2Array())
	var progress: float = attack.get("windup_progress",0.0)
	if warning.size()>=2:
		var width: float = attack.warning_width
		var from: Vector2 = to_local(warning[0])
		var to: Vector2 = to_local(warning[1])
		draw_line(from,to,Color(1.0,0.61,0.25,0.09+progress*0.09),width*2.0,false)
		var normal := (to-from).normalized().orthogonal()*width
		for side in [-1,1]: draw_line(from+normal*side,to+normal*side,Color(1.0,0.69,0.36,float(_move_style.telegraph_edge_opacity)+progress*0.4),float(_move_style.telegraph_line_width),false)
		preload("res://scripts/bosses/draco_form.gd").star(self,to,10.0,Color(1.0,0.86,0.6,0.7))
	var points: PackedVector2Array = attack.get("attack_points",PackedVector2Array())
	if points.size()>=2 and points[0].distance_to(points[1])>=8.0:
		var line := PackedVector2Array()
		for point in points: line.append(to_local(point))
		draw_polyline(line,Color(0.52,0.72,1.0,float(_move_style.motion_trail_opacity)),14.0,false)
		draw_polyline(line,Color(0.86,0.95,1.0,0.7),float(_move_style.telegraph_line_width),false)
