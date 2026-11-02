## 英雄の力の表示。C++から受けた値だけを描く。
extends Node2D
var petrified := PackedFloat32Array()
var unit := 1.0
func _draw() -> void:
	for i in range(0,petrified.size(),3):
		var at := Vector2(petrified[i],petrified[i+1])
		var radius := petrified[i+2]*1.05
		draw_circle(at,radius,Color(0.62,0.6,0.58,0.85))
		draw_arc(at,radius,0,TAU,20,Color(0.35,0.33,0.32),unit*2.0)
