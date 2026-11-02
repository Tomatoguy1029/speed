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
	var finale: Dictionary=body.get("finale",{})
	_parts.pose(points,float(body.body_width)*float(body.perspective_scale),float(body.head_scale)*float(body.perspective_scale),0.0 if finale.get("stage","")=="explode" else float(body.alpha)*smoothstep(0.0,1.0,float(intro.emerged)) if intro_active else float(body.alpha),bool(current.get("cosmic_body",false)),hit,to_local(finale.get("center",Vector2.ZERO)),Vector2.RIGHT.rotated(-rotation)*float(finale.get("split",0.0))*90.0)
	queue_redraw()
func _draw() -> void:
	if state.is_empty() or not visible: return
	_draw_rift()
	_draw_technique()
	_draw_impacts()
	_draw_rift_walls()
	_draw_arrow_impacts()
	_draw_spiral_charge()
	_draw_inhale()
	_draw_finale()
	var cycle: Dictionary = state.get("cycle",{})
	if cycle.get("stage",0)==2:
		for j in 16:
			var k := fmod(float(cycle.time)*0.5+j/16.0,1.0)
			var at := Vector2.from_angle(j*2.399963)*450.0*(1.0-k)
			draw_circle(at,4.0,Color(0.8,0.9,1.0,k))
	var intro: Dictionary = state.get("intro",{})
	var glow: float = float(intro.chest_glow) if intro.get("active",false) else 1.0
	var finale: Dictionary=state.get("finale",{})
	if not finale.get("stage","").is_empty():glow=0.12 if float(finale.get("split",0.0))<=0.0 else 0.0
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
	var polygon: PackedVector2Array=attack.get("telegraph_polygon",PackedVector2Array())
	if polygon.size()>=3:
		var shape:=PackedVector2Array()
		var center: Vector2=to_local(attack.telegraph_center)
		var far:=0.0
		for point in polygon:
			var local:=to_local(point)
			shape.append(local);far=maxf(far,local.distance_to(center))
		draw_colored_polygon(shape,_move_style.base_color)
		var circle:=PackedVector2Array()
		for j in 64:circle.append(center+Vector2.from_angle(TAU*j/64.0)*far*progress)
		if progress>0.0:
			for part in Geometry2D.intersect_polygons(shape,circle):draw_colored_polygon(part,_move_style.progress_color)
		var outline: Color=_move_style.outline_color
		outline.a+=progress*0.4
		draw_polyline(shape+PackedVector2Array([shape[0]]),outline,float(_move_style.outline_width),false)
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
		if attack.get("technique","")=="star_fan":
			preload("res://scripts/bosses/draco_form.gd").star(self,at,8.0+progress*4.0,Color(1.0,0.78,0.48,0.85))
			continue
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


## 亀裂の位置と修復中の幅は、戦闘側が出す壁の値だけを使う。
func _draw_rift_walls() -> void:
	var form=preload("res://scripts/bosses/draco_form.gd")
	for wall: Dictionary in state.get("rift_walls",[]):
		var length: float=wall.length
		var width: float=wall.width
		if length<1.0 or width<0.5:continue
		var origin: Vector2=wall.position
		var axis:=Vector2.from_angle(float(wall.angle))
		var normal:=axis.orthogonal()
		var left:=PackedVector2Array()
		var right:=PackedVector2Array()
		var count:=maxi(3,ceili(length/24.0))
		for j in count+1:
			var point:=origin+axis*length*float(j)/float(count)
			var notch:=sin(float(j)*2.7+float(wall.index)*0.31)*width*0.13
			left.append(to_local(point+normal*(width*0.34+notch)).snapped(Vector2(2,2)))
			right.append(to_local(point-normal*(width*0.34-notch)).snapped(Vector2(2,2)))
		for j in count:form.quad(self,left[j],left[j+1],right[j+1],right[j],Color("#050410"))
		draw_polyline(left,Color("#8770cb"),3.0,false)
		draw_polyline(right,Color("#40315f"),3.0,false)
		for j in range(0,count,3):draw_line(left[j].lerp(right[j],0.25),left[j+1],Color(0.68,0.74,1.0,0.45),2.0,false)

func _draw_arrow_impacts() -> void:
	for impact: Dictionary in attack.get("arrow_impacts",[]):
		if not impact.locked: continue
		var progress:=clampf((float(impact.age)-float(impact.wait))/float(impact.warn),0.0,1.0)
		var at:=to_local(impact.position)
		var radius: float=attack.get("impact_radius",85.0)
		draw_arc(at,radius*(1.8-progress*0.8),0,TAU,48,Color("#baa8ff"),3.0,false)
		draw_line(to_local(impact.position+Vector2.UP*1200.0*(1.0-progress)),at,Color(0.6,0.75,1.0,progress*0.6),4.0)

func _draw_spiral_charge() -> void:
	if attack.get("technique","")!="spiral" or int(attack.get("stage",5))!=1: return
	var coil: float=attack.coil_time
	var time: float=attack.stage_time
	if time<coil or time>=coil+float(attack.pause_time): return
	var progress:=clampf((time-coil)/float(attack.pause_time),0.0,1.0)
	var center:=to_local(attack.spiral_center)
	var radius:=lerpf(minf(attack.spiral_horizontal,attack.spiral_extent)*0.56,float(state.body_width)*0.7,progress)
	var warning:=Color(1.0,0.38,0.23,0.18+progress*0.6)
	draw_arc(center,radius,0,TAU,64,warning,4.0+progress*4.0,false)
	for j in 12:
		var direction:=Vector2.from_angle(j*TAU/12.0)
		draw_line(center+direction*(radius+20),center+direction*(radius+4),warning,3.0,false)
	preload("res://scripts/bosses/draco_form.gd").star(self,center,7.0+progress*12.0,warning)

func _draw_inhale() -> void:
	if attack.get("technique","")!="inhale" or int(attack.get("stage",5))>=3 or attack.get("spent",false):return
	var mouth:=to_local(state.position+Vector2.from_angle(state.facing)*120.0*float(state.head_scale)*float(state.perspective_scale))
	for j in 24:
		var k:=fmod(float(attack.stage_time)*0.7+j/24.0,1.0)
		var at:=mouth+Vector2.from_angle(j*2.399963)*float(_move_style.get("pull_range",1500.0))*(1.0-k)
		draw_line(at,at+(mouth-at).normalized()*25.0,Color(0.6,0.5,1.0,k*0.6),3.0)

func _draw_finale() -> void:
	var f: Dictionary=state.get("finale",{})
	var stage: String=f.get("stage","")
	if stage.is_empty():return
	var form=preload("res://scripts/bosses/draco_form.gd")
	if stage=="strikes":
		for trail: Dictionary in f.strike_trails:
			var age: float=float(state.clock)-float(trail.time)
			var points:=PackedVector2Array()
			for at: Vector2 in trail.points:points.append(to_local(at))
			if points.size()>1:
				draw_polyline(points,Color(0.5,0.56,1.0,maxf(0.0,0.35-age*0.7)),14.0,false)
				draw_polyline(points,Color(0.83,0.93,1.0,maxf(0.0,0.7-age*1.4)),3.0,false)
	if stage in ["release","combine","pose","input"]:
		var bear:=PackedVector2Array()
		for at: Vector2 in [Vector2(0,-130),Vector2(-35,-65),Vector2(-80,-15),Vector2(-145,10),Vector2(-130,70),Vector2(-55,80),Vector2(-80,-15)]:bear.append(to_local(f.core+at))
		draw_polyline(bear,Color("#e6eeff"),3.0,false)
		for at in bear:form.star(self,at,9.0,Color("#eefaff"))
		draw_circle(bear[0],12.0,Color.WHITE)
		if stage=="combine":
			var modules=["legendary_stern","legendary_keel","legendary_sail","legendary_compass"]
			for j in 4:
				var start:=to_local(f.core+Vector2.from_angle(j*TAU/4.0)*250.0)
				var at:=start.lerp(to_local(f.ship_pos),clampf(float(f.time)/2.0,0.0,1.0))
				draw_set_transform(at,-rotation,Vector2.ONE*0.4)
				preload("res://scripts/ui/legendary_module_geometry.gd").draw(self,modules[j],Color("#d3c2ff"))
				draw_set_transform(Vector2.ZERO)
				form.star(self,at,7.0,Color("#f3eaff"))
	if stage=="input":
		for key in ["guide","strokes"]:
			var points:=PackedVector2Array()
			for at: Vector2 in f[key]:points.append(to_local(at))
			if points.size()>1:draw_polyline(points,Color(0.65,0.75,1.0,0.18) if key=="guide" else Color("#effaff"),3.0 if key=="guide" else 4.0,false)
