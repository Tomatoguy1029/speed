## 技の予告・攻撃線・着弾。各技のシーンが表示の値と追加描画を持つ。
extends Node2D
@export var technique_id: StringName
var visual_kind: StringName
@export var keep_visible := false
var actor: BossActor
var effects: Array = []
var retained: bool:
	get: return keep_visible or not effects.is_empty()
const FORM = preload("res://scripts/bosses/draco_form.gd")

func update_technique() -> void:
	var tell := get_node_or_null("Telegraph") as Polygon2D
	if tell != null:
		var shape := PackedVector2Array()
		if actor.technique == technique_id:
			var points: PackedVector2Array = actor.telegraph_areas[0].polygon if not actor.telegraph_areas.is_empty() else actor.telegraph_paths[0] if not actor.telegraph_paths.is_empty() else PackedVector2Array()
			for point in points: shape.append(actor.to_local(point))
		tell.polygon = shape
	effects = effects.filter(func(effect): return actor.clock - float(effect.time) < (1.1 if effect.cue == &"cosmic_collapse" else 0.65))

func on_event(event: Dictionary) -> void:
	if actor.technique == technique_id and event.cue in [&"rock_break", &"arrow_impact", &"cosmic_collapse", &"tail_impact"]:
		effects.append({"pos":event.pos,"time":actor.clock,"radius":event.radius,"cue":event.cue})
		if effects.size() > 32: effects.pop_front()

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	if actor.technique == technique_id:
		_draw_current()
	_draw_impacts()

func _draw_current() -> void:
	_draw_telegraphs()
	if actor.attack_points.size()>1:
		var line := _local_points(actor.attack_points)
		if visual_kind == &"breath" and line.size()>3:
			for j in range(1,line.size()-1):
				if absf((line[j]-line[0]).cross(line[j+1]-line[0]))>0.1:
					draw_colored_polygon(PackedVector2Array([line[0],line[j],line[j+1]]),Color(0.34,0.46,1.0,0.5))
			draw_polyline(line,Color(0.68,0.86,1.0,0.8),4.0,false)
		elif FORM.length(line)>=8.0:
			var active: bool=actor.mode==&"active"
			if visual_kind in [&"bite",&"charge",&"leap",&"tail_slam",&"tail_sweep"]:
				# The moving creature is the physical hit shape; a restrained motion seam is not a debug hitbox.
				draw_polyline(line,Color(0.52,0.72,1.0,0.24),14.0,false)
				draw_polyline(line,Color(0.86,0.95,1.0,0.7),3.0,false)
			else:
				draw_polyline(line,Color(0.6,0.78,1.0,0.32) if active else Color(1.0,0.71,0.3,0.14),actor.attack_width*2.0,false)
				draw_polyline(line,Color("#e5f7ff") if active else Color("#efb56c"),4.0,false)

func _local_points(world: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in world: result.append(actor.to_local(point))
	return result

func _draw_telegraphs() -> void:
	var progress := clampf(actor.elapsed/maxf(0.01,float(actor.rule().get("warn",1.0))),0.0,1.0) if actor.mode==&"windup" else 1.0
	for area: Dictionary in actor.telegraph_areas:
		var shape := _local_points(area.polygon)
		if shape.size() < 3: continue
		# 範囲全体を薄く塗り、中心から外へ広がる濃い塗りが端へ届くと攻撃が出る。
		draw_colored_polygon(shape,Color(1.0,0.61,0.25,0.12))
		var center: Vector2=actor.to_local(area.center)
		var far := 0.0
		for point in shape: far=maxf(far,point.distance_to(center))
		var circle := PackedVector2Array()
		for j in 64: circle.append(center+Vector2.from_angle(TAU*j/64.0)*far*progress)
		if progress > 0.0:
			for part in Geometry2D.intersect_polygons(shape,circle): draw_colored_polygon(part,Color(1.0,0.66,0.3,0.3))
		draw_polyline(shape+PackedVector2Array([shape[0]]),Color(1.0,0.69,0.36,0.42+progress*0.4),3.0,false)
	for i in actor.telegraph_paths.size():
		var path := _local_points(actor.telegraph_paths[i])
		if path.size()<2: continue
		var width: float = actor.telegraph_widths[i] if i<actor.telegraph_widths.size() else actor.attack_width
		draw_polyline(path,Color(1.0,0.61,0.25,0.09+progress*0.09),width*2.0,false)
		for j in range(path.size()-1):
			var normal := (path[j+1]-path[j]).normalized().orthogonal()*width
			for side in [-1,1]:
				draw_line(path[j]+normal*side,path[j+1]+normal*side,Color(1.0,0.69,0.36,0.42+progress*0.4),3.0,false)
		FORM.star(self,path[-1],10.0,Color(1.0,0.86,0.6,0.7))
	for target in actor.telegraph_points:
		var at: Vector2=actor.to_local(target)
		if visual_kind == &"star_fan":
			# radius is the formation radius, not a blast at each of the nine stars.
			FORM.star(self,at,8.0+progress*4.0,Color(1.0,0.78,0.48,0.85))
			continue
		var radius: float=float(actor.rule().get("radius",actor.rule().get("width",60.0)))
		draw_arc(at,radius,0,TAU,48,Color(1.0,0.7,0.35,0.8),3.0,false)
		draw_arc(at,radius*(1.7-progress*0.7),-PI*0.5,TAU-PI*0.5,48,Color(1.0,0.77,0.5,0.8),4.0,false)
		for side in [-1,1]:
			draw_line(at+Vector2(side*(radius+10.0),0),at+Vector2(side*(radius+25.0),0),Color("#f8c879"),3.0,false)
			draw_line(at+Vector2(0,side*(radius+10.0)),at+Vector2(0,side*(radius+25.0)),Color("#f8c879"),3.0,false)

func _draw_impacts() -> void:
	for effect: Dictionary in effects:
		var age: float=actor.clock-float(effect.time)
		var duration := 1.1 if effect.cue==&"cosmic_collapse" else 0.65
		if age>=duration: continue
		var f := clampf(age/duration,0.0,1.0)
		var center: Vector2=actor.to_local(effect.pos)
		var radius: float=float(effect.radius)
		var size := radius*(0.35+f*1.4)
		draw_arc(center,size,0,TAU,48,Color(0.42,0.55,1.0,(1.0-f)*0.6),maxf(2.0,12.0*(1.0-f)),false)
		draw_arc(center,size*0.72,0,TAU,48,Color(0.72,0.87,1.0,(1.0-f)*0.8),3.0,false)
		FORM.star(self,center,radius*0.8*(1.0-f),Color(0.88,0.96,1.0,(1.0-f)*0.9))
		for j in 8:
			var direction := Vector2.from_angle(float(j)*TAU/8.0+0.2)
			var at := center+direction*size
			var cross := direction.orthogonal()*radius*0.07*(1.0-f)
			FORM.quad(self,at-direction*radius*0.22,at+cross,at+direction*radius*0.1,at-cross,Color(0.56,0.62,1.0,1.0-f))
