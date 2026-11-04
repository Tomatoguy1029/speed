## fxlib.js の sparks。位置はワールド、それ以外は元の論理画素単位。
extends RefCounted
const SLASH := preload("res://scripts/render/bosses/monoceros_slash.gd")

static func draw(canvas, position: Vector2, age: float, params: Dictionary) -> void:
	var time := age/float(params.timing)
	var origin: Vector2 = canvas.to_logical(position)
	var colors := SLASH._ramp(Color(params.color))
	for i in 22:
		var life := 0.7*lerpf(0.6,1.2,SLASH._hash(31.0+i*1.7))
		if time<0.0 or time>life: continue
		var direction := Vector2.from_angle(SLASH._hash(31.0*5.0+i)*TAU)
		var speed := 55.0*lerpf(0.5,1.3,SLASH._hash(31.0*9.0+i))
		var q := time/life
		var point := origin+direction*(speed*time*(1.0-q*0.4))+Vector2(0.0,20.0*time*time)
		var tail := minf(4.0,1.0+speed*0.03*(1.0-q))
		canvas.front.line(point.x-direction.x*tail,point.y-direction.y*tail,point.x,point.y,func(u: float): return colors[4] if u>0.5 and q<0.4 else colors[3] if u>0.5 else colors[2],1.0-q*0.6)
		canvas.front.light(point.x,point.y,colors[2],0.3*(1.0-q))
