## 本体から伸びる予告線を、固定した実際の突進終点まで描く。
extends EnemyVisual

static func draw_frame(c: CanvasItem, values: PackedFloat64Array, view: Rect2, pixel: float) -> void:
	var line_view := view.grow(-pixel*48.0)
	for i in range(0,values.size(),9):
		var position := Vector2(values[i],values[i+1])
		var radius := values[i+2]
		var charge := values[i+3]
		var anchor := Vector2(values[i+4],values[i+5])
		if view.grow(radius*1.2).has_point(position):
			c.draw_arc(position,radius*1.18,0,TAU*maxf(0.12,charge),36,Color(Color("#e1f7ff"),0.55+0.4*charge),pixel*3.0)
		if charge<=0.0 or values[i+8]==0.0: continue
		var path := preload("res://scripts/render/enemies/marlin.gd").clip_warning(position,anchor,line_view)
		if path.is_empty(): continue
		c.draw_line(path[0],path[1],Color(Color("#e1f7ff"),0.65+0.3*charge),pixel*4.0)
		c.draw_circle(path[0],pixel*4.0,Color("#fff1cc"))
		var spacing := values[i+6]
		var blast_radius := values[i+7]
		var direction := (anchor-position).normalized()
		var length := position.distance_to(anchor)
		var distance := 0.0
		while distance<=length+0.001:
			var at := position+direction*distance
			if line_view.grow(blast_radius).has_point(at):
				c.draw_arc(at,blast_radius,0.0,TAU,40,Color(Color("#e1f7ff"),0.35+0.4*charge),pixel*2.0)
			distance += spacing
		if length-floorf(length/spacing)*spacing>spacing*0.25:
			c.draw_arc(anchor,blast_radius,0.0,TAU,40,Color(Color("#e1f7ff"),0.35+0.4*charge),pixel*2.0)
