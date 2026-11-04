## bosses_common.js の bossBreath。蹴りと槍の衝撃に使う同じ42画素。
extends RefCounted
const SLASH := preload("res://scripts/render/bosses/monoceros_slash.gd")

static func draw(canvas, mouth: Vector2, direction: float, age: float, seed: float, spread: float, reach: float, params: Dictionary) -> void:
	var time := age / float(params.timing)
	if time<0.0 or time>0.7: return
	var origin: Vector2 = canvas.to_logical(mouth)
	var colors := SLASH._ramp(Color(params.color))
	var fade := 1.0-time/0.7
	for i in 42:
		var angle := direction+(SLASH._hash(seed+i*7.0)-0.5)*spread*2.0
		var speed := (0.4+SLASH._hash(seed+i*3.0))*reach*float(canvas.world_scale)*float(params.size)
		var point := origin+Vector2.from_angle(angle)*(speed*sqrt(time))
		canvas.front.glow(point.x,point.y,1.2+2.0*fade,colors[2],fade*0.16*float(params.intensity))
		if SLASH._hash(i*3.0+seed)>time: canvas.front.px(point.x,point.y,colors[3] if time<0.1 else colors[1])
