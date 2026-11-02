## 既存の本体・装甲・法線を保ち、進む方向の薙ぎの予告と振りを重ねる。
extends EnemyVisual
const EnemyMode := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.EnemyModeId

static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for i in range(0,values.size(),14):
		var p := Vector2(values[i],values[i+1])
		var r := values[i+2]
		var toward := values[i+3]
		var mode := int(values[i+4])
		var charge := values[i+5]
		var center := p+Vector2.from_angle(toward)*(r+values[i+8]*0.5)
		var radius := values[i+8]*0.6
		var base := Color(values[i+9],values[i+10],values[i+11],values[i+12])
		var col := base.lightened(0.3)
		if values[i+13]>0.0:
			for side: float in [-1.0,1.0]:
				var open := mode==EnemyMode.Windup or mode==EnemyMode.Recover
				c.draw_circle(p+Vector2.from_angle(toward+side*(0.75 if open else 0.35))*r*1.15,r*0.38,col if open else base)
		if mode==EnemyMode.Windup:
			c.draw_circle(center,radius,Color(col,0.04+0.08*charge))
			c.draw_arc(center,radius,0.0,TAU,40,Color(col,0.35+0.4*charge),pixel*1.5)
			for side: float in [-1.0,1.0]:
				c.draw_circle(p+Vector2.from_angle(toward+side*0.7)*r,r*(0.12+0.3*charge),Color(col,0.3+0.5*charge))
		elif mode==EnemyMode.Recover:
			var k := clampf((values[i+7]-values[i+6])/0.25,0.0,1.0)
			if k>=1.0: continue
			for side: float in [-1.0,1.0]:
				var a := toward+side*lerpf(1.5,0.1,k)
				c.draw_arc(center,radius*0.9,a-0.35,a+0.35,16,Color(col,1.0-k),pixel*4.0)
