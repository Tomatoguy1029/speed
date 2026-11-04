## 試作 water-jet の水流、飛沫、霧。座標は論理画素。
extends RefCounted

class Rng:
	var state: int
	func _init(seed: int) -> void:
		state = seed & 0xffffffff
		if state == 0: state = 1
	func next() -> float:
		state = (state + 0x6d2b79f5) & 0xffffffff
		var t := state
		t = ((t ^ (t >> 15)) * (t | 1)) & 0xffffffff
		t = (t ^ ((t + ((t ^ (t >> 7)) * (t | 61))) & 0xffffffff)) & 0xffffffff
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0
	func between(a: float, b: float) -> float:
		return lerpf(a, b, next())

func _hash(values: Array) -> int:
	var h := 0x9e3779b9
	for n in values:
		h = ((h ^ int(n)) * 0x85ebca6b) & 0xffffffff
		h = h ^ (h >> 13)
		h = (h * 0xc2b2ae35) & 0xffffffff
		h = h ^ (h >> 16)
	return h & 0xffffffff

func _rand(x: int, y: int, seed: int) -> float:
	return float(_hash([x,y,seed])) / 4294967296.0

func _noise(x: float, y: float, seed: int) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(_rand(ix, iy, seed), _rand(ix+1, iy, seed), ux), lerpf(_rand(ix, iy+1, seed), _rand(ix+1, iy+1, seed), ux), uy) * 2.0 - 1.0

func _smooth(a: float, b: float, x: float) -> float:
	var k := clampf((x-a)/(b-a), 0.0, 1.0)
	return k*k*(3.0-2.0*k)

func _mix(a: Color, b: Color, k: float) -> Color:
	return Color8(int(lerpf(a.r*255,b.r*255,k)), int(lerpf(a.g*255,b.g*255,k)), int(lerpf(a.b*255,b.b*255,k)))

func _ramp(color: Color) -> Array[Color]:
	var dark := Color("04101e")
	return [_mix(dark,color,0.12), _mix(dark,color,0.25), _mix(dark,color,0.45), _mix(dark,color,0.7), color, _mix(color,Color.WHITE,0.35), _mix(color,Color.WHITE,0.7), Color.WHITE]

## 本体と加算光はGPUで描き、元の個別の水滴・霧だけを画素層へ置く。
func draw_particles(canvas, world_origin: Vector2, angle: float, length: float, half0: float, slope: float, clock: float, seed: int, color: Color, alpha: float) -> void:
	var p = canvas.front
	var origin: Vector2 = canvas.to_logical(world_origin)
	var scale: float = canvas.world_scale
	var direction := Vector2.from_angle(angle)
	var palette := _ramp(color)
	_droplets(p,origin,direction,length*scale,half0,slope,scale,clock,1.0,seed,palette,alpha)
	_mist(p,origin,direction,length*scale,half0,slope,scale,clock,seed,palette,alpha)

func _droplets(p, origin: Vector2, direction: Vector2, length: float, half0: float, slope: float, scale: float, clock: float, strength: float, seed: int, palette: Array[Color], alpha: float) -> void:
	var normal := Vector2(-direction.y,direction.x)
	for i in range(46):
		var g := Rng.new(_hash([seed+3,i,911]))
		var born := g.next()*0.6
		var life := g.between(0.25,0.5)
		var age := fposmod(clock-born,0.6)
		while age < life:
			var r := Rng.new(_hash([seed+3,i]))
			var f := sqrt(r.next())
			var d := length*(0.15+0.85*f)
			var side := -1.0 if r.next() < 0.5 else 1.0
			var h := (half0+d/scale*slope)*scale*(0.55+0.45*strength)
			var va := r.between(160,300)
			var vs := side*r.between(20,110)*(0.4+f)
			var start := origin+direction*d+normal*side*h
			var velocity := direction*va+normal*vs
			var point := start+velocity*age*0.25
			var k := age/life
			if k <= 0.8 or r.next() >= (k-0.8)*5.0:
				var tail := minf(4.0,velocity.length()*0.012)
				var start_point := point-velocity.normalized()*tail
				p.line(start_point.x,start_point.y,point.x,point.y,func(u: float): return palette[4] if u < 0.5 else palette[6],alpha)
				p.dot(point.x,point.y,palette[7] if k < 0.4 else palette[6],alpha)
			age += 0.6

func _mist(p, origin: Vector2, direction: Vector2, length: float, half0: float, slope: float, scale: float, clock: float, seed: int, palette: Array[Color], alpha: float) -> void:
	var normal := Vector2(-direction.y,direction.x)
	for i in range(10):
		var g := Rng.new(_hash([seed+4,i,911]))
		var born := g.next()*1.2
		var life := g.between(0.8,1.2)
		var age := fposmod(clock-born,1.2)
		while age < life:
			var r := Rng.new(_hash([seed+4,i]))
			var k := age/life
			var d := length*r.between(0.75,1.0)+age*30.0
			var q := r.between(-1,1)*(half0+d/scale*slope)*scale*0.8
			var radius := r.between(4,7)+k*8.0
			var point := origin+direction*d+normal*q
			var fade := 0.16*alpha*minf(1.0,k/0.15)*pow(1.0-k,1.5)
			p.disc(point.x,point.y,radius,palette[6],func(v: float): return fade*(1.0-v*v))
			age += 1.2
