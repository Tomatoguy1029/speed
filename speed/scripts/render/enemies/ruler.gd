## じょうぎ座の見た目。
extends EnemyVisual
const EnemyMode := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.EnemyModeId

static func draw_frame(c: CanvasItem, values: PackedFloat64Array, pixel: float) -> void:
	for i in range(0,values.size(),12):
		var radius:=values[i+2]
		var direction:=Vector2.from_angle(values[i+3])
		var tip:=Vector2(values[i],values[i+1])+direction*(radius+values[i+7]*0.5+values[i+8])
		var color:=Color(values[i+9],values[i+10],values[i+11])
		if int(values[i+4])==EnemyMode.Windup:
			var charge:=values[i+5]
			var length:=values[i+6]
			var along:=0.0
			while along<length:
				c.draw_line(tip+direction*along,tip+direction*minf(along+36.0*0.55,length),Color(color,0.25+0.6*charge),maxf(pixel*2.0,3.0+4.0*charge))
				along+=36.0
			c.draw_circle(tip,radius*(0.2+0.4*charge),Color(1,1,1,0.4+0.5*charge))
		elif int(values[i+4])==EnemyMode.Dash:
			c.draw_circle(tip,radius*0.18,Color(color,0.6))
