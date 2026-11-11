## 試作 lightning/_lib の分岐と画素の重なり方。
extends RefCounted

const JET := preload("res://scripts/render/enemies/aquarius_jet.gd")
const HSL := preload("res://scripts/render/enemies/phoenix_particle_draw.gd")
const VOLT := ["120a33","2a1b78","4630c0","5a62f0","58a6ff","9ed8ff","e4f6ff","ffffff"]
var _raster := SpeedFxRaster.new()
var _crack_paths := {}
var _hsl = HSL.new()

func palette(base: Color) -> Array[Color]:
	var source: Vector3 = _hsl._hsl(Color("58a6ff"))
	var target: Vector3 = _hsl._hsl(base)
	var shift := target.x-source.x if target.y>0.05 else 0.0
	var out: Array[Color] = []
	for c in VOLT:
		var value: Vector3 = _hsl._hsl(Color(c))
		var hue := fposmod(value.x+shift,360.0)
		var chroma := (1.0-absf(2.0*value.z-1.0))*value.y
		var x := chroma*(1.0-absf(fposmod(hue/60.0,2.0)-1.0))
		var m := value.z-chroma*0.5
		var rgb: Vector3
		match floori(hue/60.0):
			0: rgb = Vector3(chroma,x,0)
			1: rgb = Vector3(x,chroma,0)
			2: rgb = Vector3(0,chroma,x)
			3: rgb = Vector3(0,x,chroma)
			4: rgb = Vector3(x,0,chroma)
			_: rgb = Vector3(chroma,0,x)
		out.append(Color8(roundi((rgb.x+m)*255),roundi((rgb.y+m)*255),roundi((rgb.z+m)*255)))
	return out

func zigzag(r, a: Vector2, b: Vector2, jag := 0.32, forks := 0.35, width := 1.0, depth := 0) -> Array:
	var out: Array = []
	var length := a.distance_to(b)
	var points: Array[Vector2] = [a,b]
	var offset := length*jag
	while points.size() < 2.0+length/3.0:
		var next: Array[Vector2] = [points[0]]
		for i in range(points.size()-1):
			var delta := points[i+1]-points[i]
			var l := delta.length()
			if l == 0.0: l = 1.0
			var o: float = r.between(-offset,offset)
			next.append((points[i]+points[i+1])*0.5+Vector2(-delta.y,delta.x)/l*o)
			next.append(points[i+1])
		points = next
		offset *= 0.52
	out.append({"points":points,"width":width})
	if depth < 2:
		for i in range(2,points.size()-3):
			if r.next() >= forks/(1.0+depth)/maxf(4.0,points.size()/6.0): continue
			var start := points[i]
			var end := points[mini(points.size()-1,i+3)]
			var sign := -1.0 if r.next()<0.5 else 1.0
			var angle: float = (end-start).angle()+sign*r.between(0.35,0.9)
			var l: float = (length-float(i)/points.size()*length)*r.between(0.25,0.55)
			out.append_array(zigzag(r,start,start+Vector2.from_angle(angle)*l,jag*1.1,forks,width*0.55,depth+1))
	return out

func ink(p, paths: Array, strength: float, colors: Array[Color], scale := 1.0, thin := false, glow := 0.5) -> void:
	if p.tx == 0.0 and p.ty == 0.0 and p.fx == 1.0 and p.cs == 1.0 and p.sn == 0.0:
		_raster.begin_painter(p,1.0,Vector2.ZERO,true,true)
		_raster.lightning_ink(paths,strength,PackedColorArray(colors),scale,thin,glow,p.fade,p.light_strength)
		p.colors = _raster.take_colors()
		p.lights = _raster.take_lights()
		p.has_color = p.has_color or _raster.has_color()
		p.has_light = p.has_light or _raster.has_light()
		return
	_ink_transformed(p,paths,strength,colors,scale,thin,glow)

func _ink_transformed(p, paths: Array, strength: float, colors: Array[Color], scale: float, thin: bool, glow: float) -> void:
	if strength <= 0.02: return
	var grid := {}
	for path: Dictionary in paths:
		var trunk := float(path.width)>=1.0
		if not trunk and strength<0.5: continue
		var outer := 0.0
		var body := 0.5
		if thin:
			outer = 1.2 if trunk and strength>0.45 else 0.0
		else:
			outer = ((2.1 if strength>0.6 else 1.6) if trunk else 1.1)*scale
			body = ((1.3 if strength>0.6 else 0.8) if trunk else 0.5)*scale
		var points: Array = path.points
		for i in range(points.size()-1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i+1]
			var length := maxf(1.0,a.distance_to(b))
			var d := 0.0
			while d<=length:
				var point := a+(b-a)*d/length
				if outer>0: _stamp(grid,point,outer,1)
				_stamp(grid,point,body,3 if trunk else 2)
				if trunk and strength>0.3: _stamp(grid,point,0,4)
				d += 0.5
		for i in range(0,points.size()-1,3):
			var point: Vector2 = points[i]
			p.glow(point.x,point.y,(8.0 if thin else 14.0)*scale if trunk else 6.0*scale,colors[4],glow*strength*float(path.width))
	var levels := [colors[2],colors[4],colors[5],colors[7]]
	for point: Vector2i in grid: p.px(point.x,point.y,levels[int(grid[point])-1])

func _stamp(grid: Dictionary, point: Vector2, radius: float, level: int) -> void:
	if radius<=0.5:
		_mark(grid,Vector2i(floori(point.x),floori(point.y)),level)
		return
	for y in range(floori(point.y-radius),ceili(point.y+radius)+1):
		for x in range(floori(point.x-radius),ceili(point.x+radius)+1):
			if Vector2(x+0.5,y+0.5).distance_squared_to(point)<=radius*radius: _mark(grid,Vector2i(x,y),level)

func _mark(grid: Dictionary, point: Vector2i, level: int) -> void:
	if int(grid.get(point,0))<level: grid[point] = level

func static_bolts(p, center: Vector2, radius: float, count: int, length: float, clock: float, seed: int, colors: Array[Color], strength: float) -> void:
	var frame := floori(clock/0.06)
	for i in range(count):
		var r = JET.Rng.new(seed*97+i*13+frame*7)
		if r.next()>=0.7: continue
		var angle: float = r.between(0,TAU)
		var d: float = radius*sqrt(r.next())*0.92
		var start := center+Vector2.from_angle(angle)*d
		var direction: float = r.between(0,TAU)
		var end: Vector2 = start+Vector2.from_angle(direction)*length*r.between(0.5,1)
		var paths := zigzag(r,start,end,0.35,0.2)
		ink(p,paths,strength*r.between(0.5,1),colors,1,true,0.3)

func cracks(seed: int, radius: float) -> Array:
	# 経路は種と半径だけで決まり、描画側は座標を読み取り専用で使う。
	var known: Dictionary = _crack_paths.get(seed,{})
	if not known.is_empty() and float(known.radius)==radius: return known.paths
	var out: Array = []
	var r = JET.Rng.new(seed)
	for i in range(7): _grow(out,r,Vector2.ZERO,i*TAU/7.0+r.between(-0.3,0.3),radius*r.between(0.55,0.95),1.0,0)
	if not _crack_paths.has(seed) and _crack_paths.size()>=64: _crack_paths.erase(_crack_paths.keys()[0])
	_crack_paths[seed] = {"radius":radius,"paths":out}
	return out

func _grow(out: Array, r, pos: Vector2, angle: float, length: float, width: float, depth: int) -> void:
	var points: Array[Vector2] = [pos]
	var d := 0.0
	while d<length:
		angle += r.between(-0.35,0.35)
		pos += Vector2.from_angle(angle)*1.5
		points.append(pos)
		if depth<2 and d>3 and r.next()<0.08:
			var sign := -1.0 if r.next()<0.5 else 1.0
			_grow(out,r,pos,angle+sign*r.between(0.5,1.1),(length-d)*r.between(0.3,0.6),width*0.6,depth+1)
		d += 1.5
	out.append({"points":points,"width":width})
