## 技に合わせた予告とエフェクト。
extends "res://scripts/bosses/draco/technique_visual.gd"

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	super()
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
