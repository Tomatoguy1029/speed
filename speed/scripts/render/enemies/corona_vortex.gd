## 捕捉と投擲の値だけを、冠の輪・予告・尾へ変換する。
extends RefCounted
const ATTACK := Color("#ff3b3b")
const CORE := Color("#ffb36b")
static func draw_frame(c: CanvasItem, owners: PackedFloat64Array, members: PackedFloat64Array) -> void:
	for i in range(0,owners.size(),7):
		var at := Vector2(owners[i],owners[i+1])
		for k in 3:
			var angle := owners[i+3]+k*TAU/3.0
			c.draw_arc(at,owners[i+2]*(0.72+k*0.14),angle,angle+1.8,20,Color("#b6a2db",0.3),3.0,true)
		if int(owners[i+5])==EnemyTable.Mode.WINDUP:
			c.draw_arc(at,owners[i+4]*1.2,-PI/2.0,-PI/2.0+maxf(0.02,owners[i+6])*TAU,32,ATTACK,4.0,true)
	for i in range(0,members.size(),10):
		var at := Vector2(members[i],members[i+1])
		var r := members[i+2]
		if members[i+3]>0.0:
			var u := Vector2(members[i+4],members[i+5]).normalized()
			var side := Vector2(-u.y,u.x)*r
			c.draw_polygon(PackedVector2Array([at+side,at-u*r*4.5,at-side]),PackedColorArray([Color(ATTACK,0.5),Color(ATTACK,0.0),Color(ATTACK,0.5)]))
			c.draw_circle(at,r,Color(ATTACK,0.15))
			c.draw_arc(at,r,0,TAU,32,ATTACK,3.0,true)
			c.draw_arc(at,r*1.08,u.angle()-1.2,u.angle()+1.2,18,CORE,3.0,true)
		elif members[i+6]>0.0:
			var pulse := 0.65+0.35*sin(members[i+9]*18.0)
			c.draw_arc(at,r,0,TAU,24,Color(ATTACK,pulse),3.0,true)
			c.draw_line(Vector2(members[i+7],members[i+8]),at,Color(ATTACK,0.35),2.0,true)
