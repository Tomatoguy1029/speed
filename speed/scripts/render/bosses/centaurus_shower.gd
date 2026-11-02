## C++の円と着弾時刻を読み、取消後の矢も表示だけ薄く残す。
extends Node2D
const POWDER := preload("res://scripts/bosses/centaurus/additional_technique_visual.gd")
const ARROW := preload("res://scripts/render/attacks/light_arrow.gd")
const FADE := 0.15
var groups := {}
var clock := 0.0
func apply_frame(row: Dictionary, body: Dictionary) -> void:
	clock = float(body.clock)
	top_level = true
	global_transform = Transform2D.IDENTITY
	if int(body.mode)>=3: groups.clear()
	elif not row.get("marks",[]).is_empty(): groups[row.technique] = row.duplicate(true)
	for key in groups.keys():
		var state: Dictionary = groups[key]
		state.marks = state.marks.filter(func(mark): return clock<float(mark.at)+float(state.mark_time)+float(state.rain_time)+float(state.linger)+FADE)
		if state.marks.is_empty(): groups.erase(key)
	queue_redraw()
func _draw() -> void:
	for state: Dictionary in groups.values():
		for mark: Dictionary in state.marks:
			var age := clock-float(mark.at)
			if age<0.0: continue
			var warning := maxf(float(state.mark_time),0.001)
			var active_age := age-warning
			var center: Vector2 = mark.center
			var radius := float(state.radius)
			if active_age<0.0:
				var strength := clampf(age/0.12,0.0,1.0)*clampf(-active_age/0.15,0.0,1.0)
				POWDER.draw_powder(self,center,radius,age,strength,float(mark.at))
			var fall := warning*0.3
			if active_age < -fall: continue
			var opacity := 1.0-clampf((active_age-float(state.linger))/FADE,0.0,1.0)
			if opacity<=0.0: continue
			for j in int(state.arrow_count):
				var seed := float(mark.at)*19.7+center.x*0.019+center.y*0.071
				var target := center+POWDER.scatter(seed,j)*radius*0.85
				var origin := POWDER.fall_origin(self,target)
				var progress := clampf((active_age+fall)/fall,0.0,1.0)
				ARROW.draw_arrow(self,origin.lerp(target,progress*progress),(target-origin).angle(),float(state.arrow_radius),false,clock,opacity,state.effect_tint,float(state.arrow_length),state)
