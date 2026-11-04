## わし座の進路、落雷、体の帯電、実移動履歴に沿う航跡。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const LIGHTNING := preload("res://scripts/render/enemies/aquila_lightning.gd")
const JET := preload("res://scripts/render/enemies/aquarius_jet.gd")
const EDGES := preload("res://assets/effects/reference/edges.tres")
const FLICK := [1.0,0.72,0.3,0.95,0.5,0.8,0.22]
var _settings: Dictionary = SETTINGS.for_id("G12-aquila")
var _light = LIGHTNING.new()
var _noise = JET.new()
var _edges: Dictionary = EDGES.get_meta("edges")
var _scope: ContentResourceScope
var _visuals: Dictionary
var _zones := {}
var _last_time := -1.0

func setup(_parent: Node2D, scope: ContentResourceScope, visuals: Dictionary) -> void:
	_scope = scope
	_visuals = visuals

func render(actors: Array, zones: Array, events: Array, canvas, clock: float) -> void:
	if _last_time >= 0.0 and clock < _last_time:
		_zones.clear()
	_last_time = clock
	var colors: Array[Color] = _light.palette(Color(_settings.color))
	for actor: Dictionary in actors:
		if not bool(actor.enabled): continue
		var mode := int(actor.mode)
		var k := 0.6+0.4*float(actor.charge) if mode==1 else 1.0
		if mode==1 and float(actor.charge)>0.0: _aim(actor,canvas,clock,colors)
		_wake(actor.trace,canvas,clock,colors,1.0 if mode==2 or mode==3 else 0.5)
		_electrify(actor,canvas,clock,colors,k)
	var present := {}
	for row: Dictionary in zones:
		var id := int(row.order)
		present[id] = true
		_zones[id] = {"row":row,"clock":clock}
		_draw_zone(row,float(row.time),canvas,clock,colors)
	for event: Dictionary in events:
		if event.get("type") != &"attack_retired": continue
		var id := int(event.id)
		if not _zones.has(id): continue
		if event.reason != "lifetime":
			_zones.erase(id)
			continue
		_zones[id]["retired"] = true
	for id in _zones.keys():
		if present.has(id): continue
		var saved: Dictionary = _zones[id]
		if not saved.has("retired"): continue
		var row: Dictionary = saved.row
		var time := float(row.time)+clock-float(saved.clock)
		if time >= float(row.delay)+1.2:
			_zones.erase(id)
		else:
			_draw_zone(row,time,canvas,clock,colors)

func _aim(row: Dictionary, canvas, clock: float, colors: Array[Color]) -> void:
	var origin: Vector2 = row.pos
	var target: Vector2 = row.anchor
	var delta := target-origin
	var distance := delta.length()
	var direction := delta/distance if distance>0 else Vector2.ZERO
	var step := float(row.step)
	var points: Array[Vector2] = []
	var d := 0.0
	while d<=distance+0.001:
		points.append(origin+direction*d)
		d += step
	if distance-floorf(distance/step)*step>step*0.25: points.append(target)
	var k := float(row.charge)
	var reach := ceili(points.size()*minf(1.0,k*1.4))
	var frame := floori(clock/0.06)
	for i in range(maxi(0,reach-1)):
		var a: Vector2 = canvas.to_logical(points[i])
		var b: Vector2 = canvas.to_logical(points[i+1])
		var rng = JET.Rng.new(i*53+frame*11)
		_light.ink(canvas.back,_light.zigzag(rng,a,b,0.25,0.3),0.35+0.35*k,colors,1,true,0.35)
	var radius: float = float(row.blast_radius)*canvas.world_scale
	for i in range(reach):
		_light.static_bolts(canvas.back,canvas.to_logical(points[i]),radius,roundi(1+4*k),radius*0.3,clock,i+3,colors,0.4+0.4*k)

func _draw_zone(row: Dictionary, time: float, canvas, clock: float, colors: Array[Color]) -> void:
	if time<0: return
	var center: Vector2 = canvas.to_logical(row.pos)
	var radius: float = float(row.radius)*canvas.world_scale
	var delay := float(row.delay)
	var seed := int(row.seed)
	var intensity := float(_settings.intensity)
	if time<delay:
		var k := clampf(time/delay,0.0,1.0)
		_draw_sky_bolt(canvas,center,seed,colors,time-delay)
		_light.static_bolts(canvas.back,center,radius,roundi(3+7*k),radius*(0.2+0.25*k),clock,seed,colors,0.45+0.5*k)
		canvas.back.glow(center.x,center.y,6+10*k,colors[5],(0.2+0.6*k)*intensity)
		return
	var age := time-delay
	_draw_sky_bolt(canvas,center,seed,colors,age)
	var heat := pow(clampf(1.0-age/1.2,0.0,1.0),1.4)
	if heat>0:
		for crack: Dictionary in _light.cracks(seed,radius):
			var points: Array = crack.points
			for i in range(points.size()):
				var point: Vector2 = center+points[i]
				var h := heat*(1.0-0.5*float(i)/points.size())-FX.hash_value(point.x*7.1+point.y*3.3)*0.25
				canvas.back.px(point.x,point.y,colors[6] if h>0.6 else (colors[4] if h>0.35 else (colors[2] if h>0.12 else Color("141020"))))
	var frame := floori(age*30.0+0.0001)
	var flick: float = FLICK[frame] if frame<FLICK.size() else 0.0
	if flick>0:
		var rng = JET.Rng.new(seed*13+frame)
		var paths: Array = []
		for j in range(6):
			var angle: float = j*TAU/6.0+rng.between(-0.35,0.35)
			var length: float = radius*rng.between(0.7,0.95)
			paths.append_array(_light.zigzag(rng,center,center+Vector2.from_angle(angle)*length,0.22,0.6))
		var bright: Array[Color] = []
		for i in range(8): bright.append(colors[mini(6,i)])
		_light.ink(canvas.front,paths,flick,bright,0.85,false,0.18)
	if age<0.5:
		for j in range(16):
			var r = JET.Rng.new(seed*7+j+1)
			var life: float = r.between(0.2,0.45)
			if age>life: continue
			var angle: float = r.between(0,TAU)
			var d: float = r.between(25,60)*age*(1.0-age/life*0.4)
			var point := center+Vector2.from_angle(angle)*d
			var start := point-Vector2.from_angle(angle)*3.0*(1.0-age/life)
			canvas.front.line(start.x,start.y,point.x,point.y,func(u: float): return colors[7] if u>0.5 else colors[5],1.0-age/life)
	if age<0.3: canvas.back.glow(center.x,center.y,radius*1.2,colors[4],0.5*(1.0-age/0.3)*intensity)
	if age<0.08:
		canvas.front.glow(center.x,center.y,radius*1.1,colors[5],(1.0-age/0.08)*0.22*intensity)
		canvas.front.glow(center.x,center.y,radius*0.4,colors[6],(1.0-age/0.08)*0.12*intensity)
	var active := float(row.active)
	if age>active and age<active+0.35: _light.static_bolts(canvas.back,center,radius*0.7,3,radius*0.18,clock,seed+5,colors,0.5*(1.0-(age-active)/0.35))

# 上端の段階的な先行放電と、同じ経路を走る三度の落雷。
func _draw_sky_bolt(canvas, center: Vector2, seed: int, colors: Array[Color], age: float) -> void:
	if age < -0.18 or age >= 0.72 or center.y <= 1.0: return
	var intensity := clampf(float(_settings.intensity),0.0,1.0)
	if intensity <= 0.0: return
	var rng = JET.Rng.new(seed*31+11)
	var top := Vector2(center.x+rng.between(-15.0,15.0),-2.0)
	var paths: Array = _light.zigzag(rng,top,center,0.17,0.5)
	if age < 0.0:
		var progress := clampf((age+0.18)/0.18,0.0,1.0)
		var reach := lerpf(top.y,center.y-5.0,pow(progress,1.2))
		for path: Dictionary in paths:
			var points: Array = path.points
			for i in range(points.size()-1):
				var a: Vector2 = points[i]
				var b: Vector2 = points[i+1]
				if b.y > reach: break
				canvas.front.line(a.x,a.y,b.x,b.y,colors[5] if b.y>reach-15.0 else colors[3],0.85*intensity)
		return
	var strength := 0.0
	for stroke in [[0.0,1.0],[0.28,0.8],[0.5,0.55]]:
		var elapsed: float = age-float(stroke[0])
		if elapsed < 0: continue
		var frame := floori(elapsed*30.0)
		strength = float(FLICK[frame])*float(stroke[1]) if frame<FLICK.size() else 0.0
	if strength > 0.0:
		var restrained: Array[Color] = colors.duplicate()
		restrained[7] = colors[6]
		_light.ink(canvas.front,paths,strength*intensity,restrained,0.85,false,0.14)
	elif age < 0.65:
		var points: Array = paths[0].points
		for i in range(points.size()-1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i+1]
			canvas.front.line(a.x,a.y,b.x,b.y,colors[3],maxf(0.15,0.5-age*0.45)*intensity)

func _wake(history: Array, canvas, clock: float, colors: Array[Color], strength: float) -> void:
	if history.size()<2 or strength<=0: return
	var frame := floori(clock*30.0)
	for i in range(1,history.size()):
		var a: Vector2 = canvas.to_logical(history[i-1].pos)
		var b: Vector2 = canvas.to_logical(history[i].pos)
		var u := clampf((clock-float(history[i].time))/0.45,0.0,1.0)
		if u>=1.0: continue
		var width := (1.0-u)*2.2*strength
		var delta := b-a
		var length := delta.length()
		if length==0: length = 1.0
		var normal := Vector2(-delta.y,delta.x)/length
		var d := 0.0
		while d<=length:
			var point := a+delta*d/length
			var q := -width
			while q<=width:
				var edge := absf(q)/maxf(width,0.01)
				var at := point+normal*q
				canvas.back.px(at.x,at.y,colors[6] if edge<0.35 and u<0.4 else (colors[5] if u<0.5 else (colors[4] if u<0.75 else colors[3])))
				q += 0.5
			d += 0.5
		if i%3==0: canvas.back.glow(b.x,b.y,6*(1.0-u)+2,colors[4],0.3*(1.0-u)*strength)
	for i in range(30):
		var g = JET.Rng.new(_noise._hash([77,i,911]))
		var born: float = g.next()*0.8
		var life: float = g.between(0.35,0.7)
		var age := fposmod(clock-born,0.8)
		while age<life:
			var r = JET.Rng.new(_noise._hash([77,i]))
			var index := mini(history.size()-1,floori(r.next()*history.size()))
			var h: Dictionary = history[index]
			if clock-float(h.time)<=0.45 and age<=clock-float(h.time):
				var point: Vector2 = canvas.to_logical(h.pos)
				var angle: float = r.between(0,TAU)
				var speed: float = r.between(6,20)
				var k := 1.0-age/life
				point += Vector2.from_angle(angle)*speed*age
				canvas.back.px(point.x,point.y,colors[6] if k>0.6 else (colors[4] if k>0.3 else colors[3]))
				canvas.back.glow(point.x,point.y,3,colors[4],0.3*k*strength)
			age += 0.8
	if history.size()>4 and (frame & 1)!=0:
		var rng = JET.Rng.new(frame+5)
		var index := floori(rng.between(0,history.size()-3))
		if clock-float(history[index].time)<0.4:
			var a: Vector2 = canvas.to_logical(history[index].pos)
			var b: Vector2 = canvas.to_logical(history[mini(history.size()-1,index+3)].pos)
			_light.ink(canvas.back,_light.zigzag(rng,a,b,0.45,0.3),0.6*strength,colors,1,true,0.3)

func _electrify(row: Dictionary, canvas, clock: float, colors: Array[Color], strength: float) -> void:
	var visual_id := int(row.visual_id)
	if not _visuals.has(visual_id): return
	var entry: Dictionary = _visuals[visual_id]
	var look := _scope.resources.get(entry.path) as EnemyLook
	if look==null or not _edges.has(look.source_path): return
	var edge: Dictionary = _edges[look.source_path]
	var points: PackedVector2Array = edge.points
	if points.is_empty(): return
	var dims: Vector2i = edge.size
	var scale := 2.0*float(row.sprite_radius)/maxi(dims.x,dims.y)
	var angle := look.angle if look.fixed_angle else look.angle+float(row.angle)
	var center: Vector2 = canvas.to_logical(row.pos)
	var frame := floori(clock*30.0)
	var jolt := frame%20<3
	var rng = JET.Rng.new((frame>>1)*7+3)
	var extra := 3 if jolt else floori(rng.between(0,2))
	var count := roundi((2+extra)*strength)
	for i in range(count):
		var a := _edge(row,points[mini(points.size()-1,floori(rng.next()*points.size()))],angle,scale,canvas)
		var b := Vector2.ZERO
		var found := false
		for attempt in range(12):
			var candidate := _edge(row,points[mini(points.size()-1,floori(rng.next()*points.size()))],angle,scale,canvas)
			var distance := candidate.distance_to(a)
			if distance>2 and distance<9:
				b = candidate
				found = true
				break
		if not found: continue
		var branch = JET.Rng.new(frame*13+i+1)
		_light.ink(canvas.front,_light.zigzag(branch,a,b,0.42,0.35),(0.75 if (frame & 1)!=0 else 0.95)*strength,colors,1,true,0.4)
		canvas.front.px(a.x,a.y,colors[5])
		canvas.front.px(b.x,b.y,colors[5])
	if jolt:
		for i in range(8):
			var r = JET.Rng.new(floori(frame/20.0)*31+i+1)
			var a := _edge(row,points[mini(points.size()-1,floori(r.next()*points.size()))],angle,scale,canvas)
			var dir: float = (a-center).angle()+r.between(-0.6,0.6)
			var age := float(frame%20)/30.0
			var d: float = r.between(20,50)*age
			var point := a+Vector2.from_angle(dir)*d
			var start := point-Vector2.from_angle(dir)*2.0
			canvas.front.line(start.x,start.y,point.x,point.y,func(u: float): return colors[7] if u>0.5 else colors[5],strength)
	canvas.front.glow(center.x,center.y,float(row.radius)*canvas.world_scale*2.2,colors[4],(0.15 if jolt else 0.07)*strength)

func _edge(row: Dictionary, point: Vector2, angle: float, scale: float, canvas) -> Vector2:
	return canvas.to_logical(row.pos+point.rotated(angle)*scale)

