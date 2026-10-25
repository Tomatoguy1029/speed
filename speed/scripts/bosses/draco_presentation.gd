## 正式な構図・絵を差し替えられる竜の仮表示。
extends Node2D
var actor: BossActor
func _draw() -> void:
	if actor == null or not actor.has_body(): return
	var points := PackedVector2Array()
	for point in actor.body_points(): points.append(actor.to_local(point))
	draw_polyline(points, Color("#19122e"), 105.0, false)
	draw_polyline(points, Color("#544475"), 78.0, false)
	draw_circle(Vector2(-110,0), 30.0, Color("#e9faff"))
	draw_colored_polygon(PackedVector2Array([Vector2(-30,-48),Vector2(80,-35),Vector2(105,0),Vector2(80,35),Vector2(-30,48)]),Color("#70618c"))
	for side in [-1,1]: draw_circle(Vector2(58,side * 24),7,Color("#ff3155"))
	if actor.mode in [&"windup", &"active"]:
		var end: Vector2 = actor.direction * float(actor.rule().reach)
		draw_line(Vector2.ZERO,end,Color("#ffc17c") if actor.mode == &"windup" else Color("#ff568c"),8.0 if actor.mode == &"windup" else float(actor.rule().width) * 2.0,false)

	if actor.attack_points.size() > 1:
		var line := PackedVector2Array()
		for point in actor.attack_points: line.append(actor.to_local(point))
		draw_polyline(line,Color("#c8a5ff"),20.0,false)

	for point in actor.telegraph_points:
		draw_circle(actor.to_local(point),10.0,Color("#c4b0ff"))
