## 試作 canis_fx.js の drawLanding。足先は着地時の本番パーツから渡す。
extends RefCounted

const SEEDS := [9,37,71,101]
const COUNTS := [18,23,16,21]
const HEIGHTS := [0.8,0.6,1.2,0.7]
const SIZES := [1.05,0.85,0.95,1.0]
const SHADE := Color("#625c55")
const DUST := Color("#887f74")
const LIT := Color("#aca397")

static func noise(n: float) -> float:
	var value := sin(n*127.1+311.7)*43758.5453
	return value-floorf(value)

static func project(canvas, point: Vector2, forward: Vector2, right: Vector2, x: float, y: float, z: float) -> Vector2:
	return canvas.to_logical(point+forward*x+right*y-Vector2(0,z*0.45))

static func draw(canvas, feet: Array, facing: float, age: float) -> void:
	if age<0.0 or age>0.62 or feet.size()!=4: return
	var painter = canvas.back
	var forward := Vector2.from_angle(facing)
	var right := Vector2(-forward.y,forward.x)
	for foot in 4:
		var clock := (age-(0.045 if foot>=2 else 0.0))*1.65
		if clock<0.0: continue
		var count: int = COUNTS[foot]
		var foot_seed: int = SEEDS[foot]
		for i in count:
			var seed := foot_seed+i*23
			var delay := noise(seed+11)*0.035
			var t := clock-delay
			var life := 0.28+noise(seed+12)*0.5
			if t<0.0 or t>life: continue
			var life_k := 1.0-t/life
			var drag := (1.0-exp(-4.5*t))/4.5
			var angle := float(i)/count*TAU+noise(foot_seed*7)*TAU+(noise(seed+13)-0.5)*0.35
			var radius := noise(seed+16)*3.0+(20.0+noise(seed+14)*75.0)*drag
			var z := (5.0+noise(seed+15)*22.0)*t*0.7
			var point := project(canvas,feet[foot],forward,right,cos(angle)*radius*1.25,sin(angle)*radius*1.25,z*1.25*HEIGHTS[foot])
			var size: float = 1.25*SIZES[foot]*(3.0+noise(seed+18)*5.0)*(0.7+(1.0-life_k)*0.85)*canvas.world_scale
			var alpha := pow(life_k,1.25)*minf(1.0,t/0.018)*(1.0-smoothstep(0.42,0.62,age))
			var phase := noise(seed+19)*TAU
			var edge := func(d: float, a: float, amount: float, falloff: float) -> float:
				var limit := 0.81+0.1*sin(a*5.0+phase)+0.055*sin(a*9.0+phase*2.3)
				return 0.0 if d>limit else alpha*amount*(1.0-d*d*falloff)
			painter.disc(point.x,point.y,size*1.22,SHADE,func(d,a): return edge.call(d,a,0.42,0.65))
			painter.disc(point.x-size*0.12,point.y-size*0.15,size,DUST,func(d,a): return edge.call(d,a,0.54,0.7))
			painter.disc(point.x-size*0.22,point.y-size*0.27,size*0.56,LIT,func(d,a): return edge.call(d,a,0.20,1.0))
		for i in 13:
			var seed := foot_seed+i*43+810
			var life := 0.25+noise(seed+1)*0.4
			if clock>life: continue
			var drag := (1.0-exp(-3.5*clock))/3.5
			var angle := float(i)/13.0*TAU+noise(foot_seed*11)*TAU+(noise(seed+2)-0.5)*0.4
			var radius := noise(seed+3)*3.0+(35.0+noise(seed+4)*110.0)*drag
			var z := maxf(0.0,(25.0+noise(seed+6)*50.0)*clock-140.0*clock*clock)
			var point := project(canvas,feet[foot],forward,right,cos(angle)*radius*1.25,sin(angle)*radius*1.25,z*1.25*HEIGHTS[foot])
			painter.dot(point.x,point.y,SHADE if i%3!=0 else DUST,(1.0-clock/life)*0.8)
