## 正式な構図・絵を差し替えられる竜の仮表示。
extends Node2D
var actor: BossActor
var effects: Array = []
func on_event(event: Dictionary) -> void:
	if event.cue == &"rock_break":
		effects.append({"pos":event.pos,"time":actor.clock,"radius":event.radius})
		if effects.size() > 32: effects.pop_front()
func _draw() -> void:
	if actor == null or not actor.has_body(): return
	var points := PackedVector2Array()
	for point in actor.body_points(): points.append(actor.to_local(point))
	draw_polyline(points, Color("#19122e"), 105.0, false)
	draw_polyline(points, Color("#544475"), 78.0, false)
	draw_circle(Vector2(-110,0), 30.0, Color("#e9faff"))
	draw_colored_polygon(PackedVector2Array([Vector2(-30,-48),Vector2(80,-35),Vector2(105,0),Vector2(80,35),Vector2(-30,48)]),Color("#70618c"))
	for side in [-1,1]: draw_circle(Vector2(58,side * 24),7,Color("#ff3155"))
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
