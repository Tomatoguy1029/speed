## 戦艦の砲口の光と背面の弱点を、C++の表示用の値から描く。
extends "res://scripts/render/enemies/gunner.gd"

static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for i in range(0,values.size(),6):
		var position := Vector2(values[i],values[i+1])
		var radius := values[i+2]
		var facing := values[i+3]
		draw_warning(c,position,facing,radius,values[i+4],pixel)
		var weak := values[i+5]
		if weak>0.0: c.draw_arc(position,radius+2.0*pixel,facing+PI-weak,facing+PI+weak,12,Color("#ffe46b"),3.0*pixel)
