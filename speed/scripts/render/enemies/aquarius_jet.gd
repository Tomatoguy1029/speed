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

func draw(canvas, world_origin: Vector2, angle: float, length: float, half0: float, slope: float, clock: float, strength: float, seed: int, color: Color, alpha: float) -> void:
	var p = canvas.front
	var origin: Vector2 = canvas.to_logical(world_origin)
	var scale: float = canvas.world_scale
	var direction := Vector2.from_angle(angle)
	var across := Vector2(-direction.y, direction.x)
	var full_length := length * scale
	var view := Vector2(p.width, p.height).length()
	var maximum := minf(full_length, view * 1.2)
	var count := ceili(maximum) + 1
	var up := PackedFloat32Array()
	var down := PackedFloat32Array()
	up.resize(count)
	down.resize(count)
	for d in range(count):
		var u := d / full_length
		var rough := _smooth(0.1, 1.0, u)
		var sd := fposmod(d - clock * 520.0, 150.0) - 75.0
		var h := maxf(1.2, (half0 + d / scale * slope) * scale) * (0.55 + 0.45 * strength) * (1.0 + exp(-sd*sd/160.0)*0.12*(1.0-u*0.5))
		up[d] = h * (1.0 + _noise(d*0.09-clock*30.0, 9, seed+1)*0.16*rough)
		down[d] = h * (1.0 + _noise(d*0.09-clock*30.0, 3, seed+1)*0.16*rough)
	var far := origin + direction * maximum
	var ends := [origin, far + across * up[count-1], far - across * down[count-1]]
	var lo := origin
	var hi := origin
	for point: Vector2 in ends:
		lo = lo.min(point)
		hi = hi.max(point)
	var palette := _ramp(color)
	for y in range(maxi(0, floori(lo.y-2)), mini(p.height, ceili(hi.y+2))):
		for x in range(maxi(0, floori(lo.x-2)), mini(p.width, ceili(hi.x+2))):
			var relative := Vector2(x+0.5,y+0.5)-origin
			var d := relative.dot(direction)
			if d < 1.0 or d >= maximum: continue
			var q := relative.dot(across)
			var edge: float = down[floori(d)] if q < 0 else up[floori(d)]
			var aq := absf(q) / maxf(0.8, edge)
			if aq > 1.0: continue
			var u := d / full_length
			if u > 0.5 and _noise(d*0.1-clock*25.0,q*0.18,seed+2) < -0.95 + 1.7*_smooth(0.5,1.0,u) + (1.0-strength)*0.8: continue
			var streak := _noise(d*0.045-clock*46.0,q*0.55,seed)
			var body := _noise(d*0.02-clock*12.0,q*0.06,seed+5)
			var level := 2 if aq > 0.9 else (3 if aq > 0.72 else (5 if body > 0.2 else 4))
			if aq < 0.07 + 0.05*(1.0-u): level = 7
			elif streak > 0.42: level = mini(7,level+2)
			elif streak > 0.25: level = mini(6,level+1)
			p.dot(x,y,palette[level],alpha*(0.75 if aq > 0.9 else 1.0))
			if level == 7 and (x & 3) == 0 and (y & 3) == 0: p.light(x,y,palette[5],0.12*alpha)
	_droplets(p,origin,direction,full_length,half0,slope,scale,clock,strength,seed,palette,alpha)
	_mist(p,origin,direction,full_length,half0,slope,scale,clock,seed,palette,alpha)
	var d := 0.0
	while d < minf(full_length,view):
		var point := origin+direction*d
		p.glow(point.x,point.y,10.0+d*0.06,palette[4],0.18*alpha*(1.0-d/full_length*0.6))
		d += 12.0

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
