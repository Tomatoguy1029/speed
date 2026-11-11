extends Node2D
var stage := 0
const GOLD := Color("ffd86b")
const CYAN := Color("5fe3ff")
# Perseus star positions and links, scaled from data/heroes/perseus.tres.
const POINTS := [Vector2(46,12),Vector2(61,37),Vector2(76,62),Vector2(91,89.5),Vector2(101,117),Vector2(91,144.5),Vector2(111,72),Vector2(131,82)]
const LINKS := [0,1,1,2,2,3,3,4,4,5,2,6,6,7]
func _draw() -> void:
	if stage == 2:
		var center := Vector2(90,80)
		for radius in [50.0,60.0]: draw_arc(center,radius,0,TAU,64,Color(0.35,0.73,0.9,0.25),1.0,true)
		for i in 8:
			var direction := Vector2.from_angle(i*PI/4)
			draw_line(center+direction*39,center+direction*48,GOLD,2,true)
		var jewel := PackedVector2Array([Vector2(90,42),Vector2(102,68),Vector2(123,80),Vector2(102,92),Vector2(90,118),Vector2(78,92),Vector2(57,80),Vector2(78,68)])
		draw_colored_polygon(jewel,Color("29485e"))
		jewel.append(jewel[0])
		draw_polyline(jewel,GOLD,2,true)
		draw_circle(center,9,CYAN)
		return
	for i in range(0,LINKS.size(),2):
		var lit := stage == 1 or i in [0,2]
		draw_line(POINTS[LINKS[i]],POINTS[LINKS[i+1]],GOLD if lit else Color("43617b"),3 if lit else 1,true)
	for i in POINTS.size():
		var lit := stage == 1 or i in [0,1,2]
		draw_circle(POINTS[i],8,Color(1.0,0.85,0.42,0.13) if lit else Color(0.2,0.4,0.6,0.15))
		draw_circle(POINTS[i],3.5,GOLD if lit else Color("8ba5bc"))
	if stage == 0:
		draw_line(Vector2(48,21),Vector2(84,75),CYAN,2,true)
		draw_colored_polygon(PackedVector2Array([Vector2(87,81),Vector2(74,72),Vector2(84,66)]),CYAN)
