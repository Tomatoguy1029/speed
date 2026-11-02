## 英雄の力の表示。C++から受けた値だけを描く。
extends Node2D
var petrified := PackedFloat32Array()
var unit := 1.0
var fire := {}
var world_time := 0.0
func _draw() -> void:
	for i in range(0,petrified.size(),3):
		var at := Vector2(petrified[i],petrified[i+1])
		var radius := petrified[i+2]*1.05
		draw_circle(at,radius,Color(0.62,0.6,0.58,0.85))
		draw_arc(at,radius,0,TAU,20,Color(0.35,0.33,0.32),unit*2.0)

func draw_fire(canvas: CanvasItem) -> void:
	var falls: PackedFloat64Array = fire.get("falls",PackedFloat64Array())
	var burns: PackedFloat64Array = fire.get("burns",PackedFloat64Array())
	for i in range(0,falls.size(),3):
		var k := clampf(1.0-falls[i+2]/0.6,0.0,1.0)
		var at := Vector2(falls[i],falls[i+1])
		canvas.draw_circle(at,30.0+60.0*k,Color(1.0,0.4,0.1,0.12+0.25*k))
		canvas.draw_circle(at-Vector2(-0.6,1.0)*500.0*(1.0-k),22.0,Color("#ffb060"))
	for i in range(0,burns.size(),3):
		var flick := 0.8+0.2*sin(world_time*18.0+burns[i])
		canvas.draw_circle(Vector2(burns[i],burns[i+1]),80.0*flick,Color(1.0,0.45,0.1,0.22*minf(1.0,burns[i+2])))
