## C++の弧と着弾進行を読み、粉と散らばる矢だけを描く。
extends Node2D
const POWDER := preload("res://scripts/bosses/centaurus/additional_technique_visual.gd")
const ARROW := preload("res://scripts/render/attacks/light_arrow.gd")
var state := {}
var clock := 0.0
func apply_frame(row: Dictionary, world_clock: float) -> void:
	state = row
	clock = world_clock
	top_level = true
	global_transform = Transform2D.IDENTITY
	queue_redraw()
func point(trace: Dictionary, distance: float) -> Vector2:
	var start: Vector2 = trace.start
	var direction: Vector2 = trace.direction
	var bend := float(state.trace_bend)
	if absf(bend)<0.001: return start+direction*distance
	var radius := float(state.trace_length)/bend
	var center := start+direction.orthogonal()*float(trace.turn)*radius
	return center+(start-center).rotated(-float(trace.turn)*distance/radius)
func _draw() -> void:
	if state.is_empty(): return
	var radius := float(state.circle_radius)
	var length := float(state.trace_length)
	var speed := float(state.trace_speed)
	for trace: Dictionary in state.traces:
		var run := clock-float(trace.started)
		var head := clampf(run*speed,0.0,length)
		var landed := float(trace.landed)
		var spacing := maxf(70.0,radius)
		var sample := ceili(landed/spacing)
		while head>landed and sample*spacing<=head:
			var distance := sample*spacing
			var age := run-distance/speed
			POWDER.draw_powder(self,point(trace,distance),radius,age,clampf(age/0.12,0.0,1.0),float(trace.started)+sample)
			sample += 1
		var drop := 0.0
		while drop<=head:
			var at := float(trace.started)+drop/speed+float(state.drop_delay)
			var age := clock-at
			var fall := maxf(float(state.fall),0.001)
			var linger := float(state.linger)
			if age>=0.0 and age<=fall+linger+0.15:
				var center := point(trace,drop)
				var seed := at*19.7+center.x*0.019+center.y*0.071
				for k in int(state.arrows_per_step):
					var target := center+POWDER.scatter(seed,k)*radius
					var origin := POWDER.fall_origin(self,target,float(state.drop_height))
					var progress := clampf(age/fall,0.0,1.0)
					var opacity := clampf(age/maxf(minf(float(state.fade),0.05),0.001),0.0,1.0)
					if age>fall+linger: opacity *= clampf(1.0-(age-fall-linger)/0.15,0.0,1.0)
					ARROW.draw_arrow(self,origin.lerp(target,progress*progress),(target-origin).angle(),float(state.arrow_radius),false,clock,opacity,state.effect_tint,float(state.arrow_length),state)
					if age>=fall: POWDER.draw_powder(self,target,12.0,age,opacity*0.4,at)
			drop += float(state.arrow_gap)
