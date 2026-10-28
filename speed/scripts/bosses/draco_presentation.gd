## Shared armored silhouette, cosmic energy and explicit attack geometry.
extends Node2D
var actor: BossActor
var effects: Array = []
const FORM = preload("res://scripts/bosses/draco_form.gd")
const MODULE_GEOMETRY = preload("res://scripts/ui/legendary_module_geometry.gd")
func _ready() -> void:
	material = preload("res://scripts/bosses/boss_hit_feedback.gd").new().make_material()
func _process(_dt: float) -> void:
	var sample := {"white":0.0,"offset":Vector2.ZERO,"angle":0.0}
	if actor != null and actor.has_body(): sample = actor.hit_feedback.sample(actor.body_id)
	position = sample.offset
	rotation = sample.angle
	material.set_shader_parameter("boss_hit_white", sample.white)

func on_event(event: Dictionary) -> void:
	if event.cue in [&"phase_changed",&"bear_roar"]:
		var at: Vector2=event.get("pos",actor.table.pos[actor.body])
		actor.run_state.emit(&"draco_roar",{"pos":at,"radius":700.0})
	if event.cue in [&"rock_break",&"arrow_impact",&"cosmic_collapse",&"tail_impact"]:
		effects.append({"pos":event.pos,"time":actor.clock,"radius":event.radius,"cue":event.cue})
		if effects.size() > 32: effects.pop_front()
func _draw() -> void:
	if actor == null or not actor.has_body(): return
	_draw_rift()
	var points := PackedVector2Array()
	for point in actor.body_points(): points.append(actor.to_local(point))
	var body_alpha := smoothstep(0.0,1.0,actor.entrance.emerged) if actor.entrance.active else 1.0
	var width: float = actor.body_width*actor.perspective_scale
	if actor.finale.stage != &"explode":
		if actor.finale.split>0.0:
			_draw_split_body(points,width,body_alpha)
		else:
			FORM.draw_body(self,points,width,actor.clock,actor.technique==&"spiral",body_alpha,PackedFloat32Array(),true)
		var mouth_open := 0.0
		if actor.mode in [&"windup",&"active"] and actor.technique in [&"bite",&"breath",&"inhale",&"star_fan",&"picaro_wall"]:
			mouth_open = 0.8 if actor.mode==&"windup" else 1.0
		var head_offset := Vector2.ZERO
		if actor.finale.split>0.0:
			var side := -1.0 if actor.table.pos[actor.body].x<actor.finale.center.x else 1.0
			head_offset=Vector2.RIGHT.rotated(-actor.rotation)*side*actor.finale.split*90.0
		FORM.draw_head(self,actor.head_scale*actor.perspective_scale,mouth_open,1.0,body_alpha,head_offset)
		var core: Vector2 = actor.to_local(actor.chest_pos())
		var core_glow := 1.0
		if actor.entrance.active: core_glow=float(actor.entrance.get("chest_glow") if actor.entrance.get("chest_glow")!=null else actor.entrance.emerged)
		if actor.finale.stage!=&"": core_glow=0.12 if actor.finale.split<=0.0 else 0.0
		var pulse := 0.85+sin(actor.clock*3.0)*0.15
		draw_circle(core,43.0*actor.perspective_scale,Color(0.38,0.59,1.0,core_glow*0.16*pulse))
		FORM.star(self,core,27.0*actor.perspective_scale,Color(0.85,0.96,1.0,core_glow))
	_draw_telegraphs()
	_draw_spiral_charge()
	if actor.attack_points.size()>1:
		var line := _local_points(actor.attack_points)
		if actor.technique==&"breath" and line.size()>3:
			for j in range(1,line.size()-1):
				if absf((line[j]-line[0]).cross(line[j+1]-line[0]))>0.1:
					draw_colored_polygon(PackedVector2Array([line[0],line[j],line[j+1]]),Color(0.34,0.46,1.0,0.5))
			draw_polyline(line,Color(0.68,0.86,1.0,0.8),4.0,false)
		elif FORM.length(line)>=8.0:
			var active: bool=actor.mode==&"active"
			if actor.technique in [&"bite",&"charge",&"leap",&"tail_slam",&"tail_sweep"]:
				# The moving creature is the physical hit shape; a restrained motion seam is not a debug hitbox.
				draw_polyline(line,Color(0.52,0.72,1.0,0.24),14.0,false)
				draw_polyline(line,Color(0.86,0.95,1.0,0.7),3.0,false)
			else:
				draw_polyline(line,Color(0.6,0.78,1.0,0.32) if active else Color(1.0,0.71,0.3,0.14),actor.attack_width*2.0,false)
				draw_polyline(line,Color("#e5f7ff") if active else Color("#efb56c"),4.0,false)
	_draw_impacts()
	_draw_residual_rifts()
	if actor.finale.stage==&"strikes":
		for trail: Dictionary in actor.finale.strike_trails:
			var age: float=actor.clock-float(trail.time)
			var path := _local_points(trail.points)
			if path.size()>1:
				draw_polyline(path,Color(0.5,0.56,1.0,maxf(0.0,0.35-age*0.7)),14.0,false)
				draw_polyline(path,Color(0.83,0.93,1.0,maxf(0.0,0.7-age*1.4)),3.0,false)

	for member: Dictionary in actor.picaro.alive():
		if actor.run_state.cinematic_hide_enemies: continue
		var age: float = actor.clock-float(member.born)
		if age>1.4: continue
		var center := actor.to_local(actor.table.pos[member.row])
		var radius: float = maxf(125.0,actor.table.r[member.row]*2.35)
		var alpha := clampf((1.4-age)*2.0,0.0,1.0)
		var gather := clampf(age/0.8,0.0,1.0)
		var swell := 1.0+0.06*sin(age*18.0)
		draw_circle(center,radius*0.92*swell,Color(0.35,0.26,0.9,alpha*0.075))
		draw_arc(center,radius*1.16,0.0,TAU,48,Color(0.58,0.74,1.0,alpha*0.2),8.0,false)
		var membrane := PackedVector2Array()
		for j in 49:
			var angle := j*TAU/48.0
			membrane.append(center+Vector2.from_angle(angle)*radius*swell*(1.0+sin(angle*5.0+age*12.0)*0.055))
		draw_polyline(membrane,Color(0.68,0.54,1.0,alpha*0.85),7.0,false)
		for j in 16:
			var angle := j*TAU/16.0+age*4.0
			var direction := Vector2.from_angle(angle)
			var at := center+direction*radius*(1.55-0.72*gather)
			var to := center+direction.rotated(0.36)*radius*(1.18-0.35*gather)
			draw_line(at,to,Color(0.69,0.87,1.0,alpha*(0.55+0.35*gather)),3.0)
			if j%2==0: draw_circle(at,3.5,Color(0.87,0.96,1.0,alpha))
		FORM.star(self,center,radius*0.3,Color(0.82,0.91,1.0,alpha*0.75))

	if actor.technique == &"picaro_wall" and actor._driver != null:
		for impact: Dictionary in actor._driver.impacts:
			if impact.pos == Vector2.INF: continue
			var progress := clampf((float(impact.age)-float(impact.wait))/float(impact.warn),0.0,1.0)
			var point := actor.to_local(impact.pos)
			draw_arc(point,float(actor.rule().radius)*(1.8-progress*0.8),0,TAU,48,Color("#baa8ff"),3.0,false)
			draw_line(actor.to_local(impact.pos+Vector2.UP*1200.0*(1.0-progress)),point,Color(0.6,0.75,1.0,progress*0.6),4.0)

	if actor.technique == &"inhale" and actor._driver != null and not actor._driver.spent:
		var mouth := actor.to_local(actor.mouth_pos())
		for j in 24:
			var k := fmod(actor.elapsed*0.7+j/24.0,1.0)
			var angle := j*2.399963
			var at := mouth+Vector2.from_angle(angle)*float(actor.rule().pull_range)*(1.0-k)
			draw_line(at,at+(mouth-at).normalized()*25.0,Color(0.6,0.5,1.0,k*0.6),3.0)

	if actor.finale.stage in [&"release",&"combine",&"pose",&"input"]:
		var at := actor.to_local(actor.finale.core)
		var bear := PackedVector2Array()
		for point in actor.finale.BEAR: bear.append(actor.to_local(actor.finale.core+point))
		draw_polyline(bear,Color("#e6eeff"),3.0,false)
		for point in bear: FORM.star(self,point,9.0,Color("#eefaff"))
		draw_circle(bear[0],12.0,Color.WHITE)
		if actor.finale.stage == &"combine":
			for j in 4:
				var from: Vector2=actor.to_local(actor.finale.core+Vector2.from_angle(j*TAU/4.0)*250.0)
				var position: Vector2=from.lerp(actor.to_local(actor.run_state.ship_pos),clampf(actor.finale.time/2.0,0.0,1.0))
				draw_set_transform(position,-actor.rotation,Vector2.ONE*0.4)
				MODULE_GEOMETRY.draw(self,String(actor.finale.MODULES[j]),Color("#d3c2ff"))
				draw_set_transform(Vector2.ZERO)
				FORM.star(self,position,7.0,Color("#f3eaff"))

	if actor.finale.stage == &"input":
		var guide := PackedVector2Array()
		for point in actor.finale.guide: guide.append(actor.to_local(point))
		if guide.size()>1: draw_polyline(guide,Color(0.65,0.75,1.0,0.18),3.0,false)
		var strokes := PackedVector2Array()
		for point in actor.finale.strokes: strokes.append(actor.to_local(point))
		if strokes.size()>1: draw_polyline(strokes,Color("#effaff"),4.0,false)

	if actor.cycle.stage==&"collect":
		for j in 16:
			var k:=fmod(actor.cycle.time*0.5+j/16.0,1.0)
			var at:=Vector2.from_angle(j*2.399963)*450.0*(1.0-k)
			draw_circle(at,4.0,Color(0.8,0.9,1.0,k))

func _local_points(world: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in world: result.append(actor.to_local(point))
	return result

func _draw_residual_rifts() -> void:
	var hazards: Array[int] = []
	if actor.technique == &"rifts" and actor._driver != null:
		for h: int in actor._driver.walls: hazards.append(h)
	for closing: Dictionary in actor.closing_walls:
		if not int(closing.h) in hazards: hazards.append(int(closing.h))
	var ps := actor.ctx.projectiles
	for h: int in hazards:
		if not ps.owns_hazard(h,actor.body,actor.body_id): continue
		var from: Vector2 = ps.hazard_pos[h]
		var length: float = ps.hazard_len[h]
		var width: float = ps.hazard_width[h]
		if length < 1.0 or width < 0.5: continue
		var axis := Vector2.from_angle(ps.hazard_angle[h])
		var normal := axis.orthogonal()
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var count := maxi(3,ceili(length/24.0))
		for j in count+1:
			var t := float(j)/float(count)
			var point := from+axis*length*t
			var notch := sin(float(j)*2.7+float(h)*0.31)*width*0.13
			left.append(actor.to_local(point+normal*(width*0.34+notch)).snapped(Vector2(2,2)))
			right.append(actor.to_local(point-normal*(width*0.34-notch)).snapped(Vector2(2,2)))
		for j in count:
			FORM.quad(self,left[j],left[j+1],right[j+1],right[j],Color("#050410"))
		# The torn lips stay within the solid width; repair shrinks the same
		# hazard from both ends, closing the void and its collision together.
		draw_polyline(left,Color("#8770cb"),3.0,false)
		draw_polyline(right,Color("#40315f"),3.0,false)
		for j in range(0,count,3):
			var at := left[j].lerp(right[j],0.25)
			draw_line(at,left[j+1],Color(0.68,0.74,1.0,0.45),2.0,false)

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
		if actor.technique == &"star_fan":
			# radius is the formation radius, not a blast at each of the nine stars.
			FORM.star(self,at,8.0+progress*4.0,Color(1.0,0.78,0.48,0.85))
			continue
		var radius: float=float(actor.rule().get("radius",actor.rule().get("width",60.0)))
		draw_arc(at,radius,0,TAU,48,Color(1.0,0.7,0.35,0.8),3.0,false)
		draw_arc(at,radius*(1.7-progress*0.7),-PI*0.5,TAU-PI*0.5,48,Color(1.0,0.77,0.5,0.8),4.0,false)
		for side in [-1,1]:
			draw_line(at+Vector2(side*(radius+10.0),0),at+Vector2(side*(radius+25.0),0),Color("#f8c879"),3.0,false)
			draw_line(at+Vector2(0,side*(radius+10.0)),at+Vector2(0,side*(radius+25.0)),Color("#f8c879"),3.0,false)

func _draw_spiral_charge() -> void:
	if actor.technique != &"spiral" or actor.mode != &"active" or actor._driver == null: return
	var wrap: float = actor._driver.coil_time
	if actor.elapsed < wrap or actor.elapsed >= wrap + actor._driver.pause_time: return
	var progress := clampf((actor.elapsed - wrap) / actor._driver.pause_time, 0.0, 1.0)
	var center: Vector2 = actor.to_local(actor._driver.center)
	var radius: float = lerpf(minf(actor._driver.horizontal_extent, actor._driver.extent) * 0.56, actor.body_width * 0.7, progress)
	var warning := Color(1.0, 0.38, 0.23, 0.18 + progress * 0.6)
	draw_arc(center, radius, 0.0, TAU, 64, warning, 4.0 + progress * 4.0, false)
	for j in 12:
		var direction := Vector2.from_angle(float(j) * TAU / 12.0)
		draw_line(center + direction * (radius + 20.0), center + direction * (radius + 4.0), warning, 3.0, false)
	FORM.star(self, center, 7.0 + progress * 12.0, warning)

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

func _draw_rift() -> void:
	if not actor.entrance.active: return
	var opening: float=actor.entrance.rift
	if opening<=0.0: return
	var center: Vector2=actor.entrance.get("rift_center") if actor.entrance.get("rift_center")!=null else actor.table.pos[actor.body]
	var axis: Vector2=actor.entrance.get("rift_axis") if actor.entrance.get("rift_axis")!=null else Vector2.DOWN
	var line := PackedVector2Array()
	for j in 19:
		var along := float(j-9)*55.0*opening
		var side := (sin(j*2.3)*24.0+sin(j*4.9)*12.0)*opening
		line.append(actor.to_local(center+axis*along+axis.orthogonal()*side))
	draw_polyline(line,Color(0.41,0.25,0.88,0.22),160.0*opening,false)
	draw_polyline(line,Color("#5a4d91"),105.0*opening,false)
	draw_polyline(line,Color("#050612"),88.0*opening,false)
	var eyes: float=float(actor.entrance.get("eyes") if actor.entrance.get("eyes")!=null else opening)
	if eyes>0.0 and actor.entrance.emerged<0.4:
		for side in [-1,1]:
			var at: Vector2=actor.to_local(center+axis.orthogonal()*side*65.0)
			var offset: Vector2=axis.rotated(-actor.rotation)*12.0
			draw_line(at-offset,at+offset,Color(1.0,0.1,0.3,eyes),8.0,false)

func _draw_split_body(local: PackedVector2Array, width: float, alpha: float) -> void:
	var world: PackedVector2Array=actor.body_points()
	var fractions := FORM.fractions(world)
	var cut_x: float=actor.finale.center.x
	for side in [-1.0,1.0]:
		var displacement: Vector2=Vector2.RIGHT.rotated(-actor.rotation)*side*actor.finale.split*90.0
		for j in range(world.size()-1):
			var left_inside: bool=(world[j].x-cut_x)*side>=0.0
			var right_inside: bool=(world[j+1].x-cut_x)*side>=0.0
			if not left_inside and not right_inside: continue
			var start: Vector2=local[j]
			var end: Vector2=local[j+1]
			var first: float=fractions[j]
			var last: float=fractions[j+1]
			if left_inside!=right_inside:
				var blend := clampf((cut_x-world[j].x)/(world[j+1].x-world[j].x),0.0,1.0)
				var crossing := local[j].lerp(local[j+1],blend)
				var middle := lerpf(first,last,blend)
				if left_inside: end=crossing;last=middle
				else: start=crossing;first=middle
			FORM.draw_body(self,PackedVector2Array([start+displacement,end+displacement]),width,actor.clock,true,alpha,PackedFloat32Array([first,last]))
