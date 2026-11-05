## monoPressureWave の白金の帯と外へ押し出される光の筋。
extends RefCounted
const SLASH := preload("res://scripts/render/bosses/monoceros_slash.gd")
const GOLD := [Color("#ffffff"),Color("#fff3c0"),Color("#ffe08a"),Color("#ffc457"),Color("#f2a03a")]

static func draw(canvas, wave: Dictionary, params: Dictionary) -> void:
	var center: Vector2 = canvas.to_logical(wave.center)
	var radius := float(wave.radius)*float(canvas.world_scale)
	var maximum := float(wave.max)
	if maximum<=0.0: return
	var fade := 1.0-smoothstep(maximum*0.45,maximum,float(wave.radius))
	var gone := 1.0-fade
	var a0 := float(wave.angle)-float(wave.half)
	var a1 := float(wave.angle)+float(wave.half)
	var width := maxf(1.2,float(wave.width)*float(canvas.world_scale)*0.45)*float(params.size)
	var count := maxi(16,floori((a1-a0)*radius*1.5+0.5))
	var started := float(wave.reference_time)
	var time := float(wave.visual_time)
	for i in range(count+1):
		var u := float(i)/count
		var angle := lerpf(a0,a1,u)
		var taper := pow(minf(1.0,minf(u,1.0-u)/0.2),0.8)
		var noise := 0.6+0.4*sin(angle*17.0+started*5.0)*sin(angle*7.0-time*3.0)
		var half_width := width*taper*noise
		var direction := Vector2.from_angle(angle)
		var q := -half_width
		while q<=half_width:
			var point := center+direction*(radius+q)
			if gone<=0.0 or SLASH._hash(floorf(point.x+0.5)*12.9898+floorf(point.y+0.5)*78.233)>=gone*0.9:
				var edge := q/maxf(half_width,0.01)
				canvas.front.dot(point.x,point.y,GOLD[0] if edge>0.3 else GOLD[2] if edge> -0.3 else GOLD[4],maxf(0.15,fade))
			q += 0.5
		if i%4==0:
			var point := center+direction*radius
			canvas.front.light(point.x,point.y,GOLD[3],0.35*fade)
	for i in 38:
		var angle := lerpf(a0,a1,0.08+0.84*SLASH._hash(i*3.7+started))
		var length := (3.0+9.0*SLASH._hash(i*5.1))*float(params.size)
		var back := (2.0+10.0*SLASH._hash(i*7.3))*float(params.size)
		var bright := SLASH._hash(i*9.9)
		if SLASH._hash(i+floorf(time*20.0))<gone: continue
		var direction := Vector2.from_angle(angle)
		var a := center+direction*(radius-back-length)
		var b := center+direction*(radius-back)
		canvas.front.line(a.x,a.y,b.x,b.y,func(t: float): return GOLD[0 if bright>0.5 else 1] if t>0.7 else GOLD[3],func(t: float): return maxf(0.15,fade*(0.3+0.7*t)))
