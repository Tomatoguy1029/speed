## 正式な構図・絵を差し替えられる竜の仮表示。
extends Node2D
var actor: BossActor
var effects: Array = []
func on_event(event: Dictionary) -> void:
	if event.cue in [&"rock_break",&"arrow_impact",&"cosmic_collapse"]:
		effects.append({"pos":event.pos,"time":actor.clock,"radius":event.radius})
		if effects.size() > 32: effects.pop_front()
func _draw() -> void:
	if actor == null or not actor.has_body(): return
	var points := PackedVector2Array()
	for point in actor.body_points(): points.append(actor.to_local(point))
	if actor.finale.stage != &"explode":
		if actor.finale.split>0.0:
			for side in 2:
				var piece := PackedVector2Array()
				for j in range(0 if side==0 else 6,6 if side==0 else points.size()): piece.append(points[j]+Vector2((-1 if side==0 else 1)*actor.finale.split*90.0,0))
				if piece.size()>1: draw_polyline(piece,Color("#544475"),78.0,false)
		else:
			draw_polyline(points, Color("#19122e"), 105.0, false)
			draw_polyline(points, Color("#544475"), 78.0, false)
	if actor.finale.stage != &"explode": draw_circle(Vector2(-110,0), 30.0, Color("#e9faff"))
	if actor.finale.stage != &"explode": draw_colored_polygon(PackedVector2Array([Vector2(-30,-48),Vector2(80,-35),Vector2(105,0),Vector2(80,35),Vector2(-30,48)]),Color("#70618c"))
	for side in ([] if actor.finale.stage == &"explode" else [-1,1]): draw_circle(Vector2(58,side * 24),7,Color("#ff3155"))
	if actor.mode in [&"windup", &"active"] and actor.technique == &"bite":
		var end: Vector2 = actor.direction * float(actor.rule().reach)
		draw_line(Vector2.ZERO,end,Color("#ffc17c") if actor.mode == &"windup" else Color("#ff568c"),8.0 if actor.mode == &"windup" else float(actor.rule().width) * 2.0,false)

	if actor.attack_points.size() > 1:
		var line := PackedVector2Array()
		for point in actor.attack_points: line.append(actor.to_local(point))
		if actor.technique == &"breath" and line.size() > 3:
			for j in range(1,line.size()-1):
				if absf((line[j]-line[0]).cross(line[j+1]-line[0])) > 0.1:
					draw_colored_polygon(PackedVector2Array([line[0],line[j],line[j+1]]),Color(1.0,0.35,0.12,0.7))
		else:
			draw_polyline(line,Color("#c8a5ff"),20.0,false)

	for point in actor.telegraph_points:
		draw_circle(actor.to_local(point),10.0,Color("#c4b0ff"))

	for effect: Dictionary in effects:
		var age: float = actor.clock-float(effect.time)
		if age > 0.6: continue
		for j in 12:
			var at: Vector2 = actor.to_local(effect.pos) + Vector2.from_angle(j*TAU/12.0)*(float(effect.radius)+age*160.0)
			draw_rect(Rect2(at.snapped(Vector2(3,3)),Vector2(6,6)),Color(0.75,0.65,0.55,1.0-age/0.6))

	for member: Dictionary in actor.picaro.alive():
		var age: float = actor.clock-float(member.born)
		if age>1.4: continue
		var center := actor.to_local(actor.table.pos[member.row])
		var radius: float = actor.table.r[member.row]*1.5
		var alpha := clampf((1.4-age)*2.0,0.0,1.0)
		var membrane := PackedVector2Array()
		for j in 49:
			var angle := j*TAU/48.0
			membrane.append(center+Vector2.from_angle(angle)*radius*(1.0+sin(angle*5.0+age*12.0)*0.1)*(1.0+maxf(0.0,age-0.8)))
		draw_polyline(membrane,Color(0.5,0.3,1.0,alpha*0.6),4.0,false)
		for j in 12:
			var angle := j*TAU/12.0+age*6.0
			var at := center+Vector2.from_angle(angle)*radius*maxf(0.1,1.5-age)
			draw_line(at,at+Vector2.from_angle(angle+1.0)*12.0,Color(0.6,0.85,1.0,alpha),3.0)

	if actor.technique == &"picaro_wall" and actor._driver != null:
		for impact: Dictionary in actor._driver.impacts:
			if impact.pos == Vector2.INF: continue
			var progress := clampf((float(impact.age)-float(impact.wait))/float(impact.warn),0.0,1.0)
			var point := actor.to_local(impact.pos)
			draw_arc(point,float(actor.rule().radius)*(1.8-progress*0.8),0,TAU,48,Color("#baa8ff"),3.0,false)
			draw_line(point+Vector2(0,-1200*(1.0-progress)),point,Color(0.6,0.75,1.0,progress*0.6),4.0)

	if actor.technique == &"clones" and actor._driver != null:
		for unit: Dictionary in actor._driver.units:
			if unit.index==0 or not actor.ctx.enemies.is_same(unit.row,unit.id) or actor.table.dead[unit.row]!=0: continue
			var at := actor.to_local(actor.table.pos[unit.row])
			var line := PackedVector2Array()
			for j in 13: line.append(at+Vector2(-j*45.0,sin(j*0.7-actor.clock)*55.0).rotated(unit.angle-actor.rotation))
			draw_polyline(line,Color("#443d83"),70.0,false)
			draw_polyline(line,Color(0.4,0.65,1.0,0.5),45.0,false)
			draw_circle(at,55.0,Color("#8d87c9"))

	if actor.technique == &"inhale" and actor._driver != null and not actor._driver.spent:
		var mouth := actor.to_local(actor.table.pos[actor.body]+actor.direction*100.0)
		for j in 24:
			var k := fmod(actor.elapsed*0.7+j/24.0,1.0)
			var angle := j*2.399963
			var at := mouth+Vector2.from_angle(angle)*float(actor.rule().pull_range)*(1.0-k)
			draw_line(at,at+(mouth-at).normalized()*25.0,Color(0.6,0.5,1.0,k*0.6),3.0)

	if actor.finale.stage in [&"release",&"combine",&"pose",&"input"]:
		var at := actor.to_local(actor.finale.core)
		var bear := PackedVector2Array()
		for point in actor.finale.BEAR: bear.append(at+point)
		draw_polyline(bear,Color("#e6eeff"),3.0,false)
		for point in bear: draw_circle(point,7.0,Color("#eefaff"))
		draw_circle(bear[0],12.0,Color.WHITE)
		if actor.finale.stage == &"combine":
			for j in 4:
				var from := at+Vector2.from_angle(j*TAU/4.0)*250.0
				var position: Vector2=from.lerp(actor.to_local(actor.run_state.ship_pos),clampf(actor.finale.time/2.0,0.0,1.0))
				draw_rect(Rect2(position-Vector2(12,8),Vector2(24,16)),Color("#d3c2ff"))

	if actor.finale.stage == &"input":
		var guide := PackedVector2Array()
		for point in actor.finale.guide: guide.append(actor.to_local(point))
		if guide.size()>1: draw_polyline(guide,Color(0.65,0.75,1.0,0.18),3.0,false)
		var strokes := PackedVector2Array()
		for point in actor.finale.strokes: strokes.append(actor.to_local(point))
		if strokes.size()>1: draw_polyline(strokes,Color("#effaff"),4.0,false)

	if actor.entrance.active:
		var opening: float=actor.entrance.rift
		var line := PackedVector2Array()
		for j in 17: line.append(Vector2(sin(j*2.3)*60.0*opening,(j-8)*55.0*opening))
		if opening>0.0: draw_polyline(line,Color("#070411"),90.0*opening,false)
		if opening>0.4:
			for side in [-1,1]: draw_circle(Vector2(0,side*25.0),8.0,Color("#ff2345"))
