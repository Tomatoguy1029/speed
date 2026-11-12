## canisHoundBurn: 実画像輪郭の青い炎と14点の通過跡。
extends RefCounted
static var _raster := SpeedFxRaster.new()

const EDGES := preload("res://data/visuals/canis_hound_edges.tres")
const COLORS := [Color("#ffffff"),Color("#f2fbff"),Color("#d8f1ff"),Color("#a9dcff"),Color("#6fb8f2"),Color("#3f8ce0"),Color("#2a66c4"),Color("#1d479b"),Color("#13306a")]
const MASK := 0xffffffff

static func _hash(n: float) -> float:
	var value := sin(n*127.1+311.7)*43758.5453
	return value-floorf(value)

static func _next(state: Array) -> float:
	var n: int = (int(state[0])+0x6d2b79f5)&MASK
	state[0] = n
	var t: int = ((n^(n>>15))*(n|1))&MASK
	t = (t^(t+(((t^(t>>7))*(t|61))&MASK)))&MASK
	return float((t^(t>>14))&MASK)/4294967296.0

static func _solid(painter, at: Vector2, radius: float, color: Color) -> void:
	if radius<0.6: painter.px(at.x,at.y,color)
	else: painter.disc(at.x,at.y,radius,color)

static func _puff(painter, at: Vector2, left: float, size: float, fraction: float) -> void:
	var age := 1.0-left
	var heat := minf(0.999,pow(age,0.62)+fraction*0.1)
	var index := mini(COLORS.size()-2,floori(heat*(COLORS.size()-1)))
	var radius := size*(0.55+0.45*minf(1.0,age*7.0))*(1.0-age*0.55)
	var color: Color = COLORS[index]
	if index>=COLORS.size()-2:
		painter.disc(at.x,at.y,radius,color,minf(1.0,left*3.0)*0.85)
		return
	_solid(painter,at,radius,COLORS[mini(COLORS.size()-1,index+2)])
	_solid(painter,at+Vector2(-radius*0.16,-radius*0.22),radius*0.78,color)
	if radius>1.6: _solid(painter,at+Vector2(0,-radius*0.9),radius*0.42,color)
	if index<=3 and radius>1.8: _solid(painter,at+Vector2(-radius*0.28,-radius*0.34),radius*0.36,COLORS[maxi(0,index-1)])
	if index<6: painter.glow(at.x,at.y,radius*2.4+2.0,color,0.14*left)

static func draw(canvas, trails: Dictionary, clock: float) -> void:
	var edges: PackedVector2Array = EDGES.get_meta("points")
	var size := Vector2(float(EDGES.get_meta("width")),float(EDGES.get_meta("height")))
	if edges.is_empty(): return
	var p = canvas.back
	var native: bool = p.tx==0.0 and p.ty==0.0 and p.fx==1.0 and p.cs==1.0 and p.sn==0.0
	if native:
		_raster.begin_painter(p,canvas.world_scale,canvas._camera_position,true,true)
		_raster.canis_hound_trails(trails.values(),clock,PackedColorArray(COLORS),p.fade,p.light_strength)
		p.colors = _raster.take_colors()
		p.lights = _raster.take_lights()
		p.has_color = p.has_color or _raster.has_color()
		p.has_light = p.has_light or _raster.has_light()
	for actor: Dictionary in trails.values():
		var points: PackedVector2Array = actor.points
		if points.is_empty(): continue
		var live := clock<float(actor.until)
		var k := 1.0 if live else 1.0-clampf((clock-float(actor.until))/0.4,0.0,1.0)
		if k<=0.0: continue
		var index := int(actor.index)
		var radius := float(actor.radius)
		for i in (0 if native else points.size()):
			var f := float(i+1)/points.size()
			var drop := 1.0 if i%3==0 else 0.55
			var point: Vector2 = canvas.to_logical(points[i])+Vector2((_hash(i*3.1+index)-0.5)*2.0,(_hash(i*5.7+index)-0.5)*2.0)
			_puff(canvas.back,point,maxf(0.05,f*k),(0.8+2.6*f)*drop*radius*float(canvas.world_scale)*0.22,_hash(i+index*7))
		if not live: continue
		var direction := Vector2.from_angle(float(actor.facing))
		var angle := float(actor.facing)+float(actor.sprite_angle)
		var scale := 2.0*float(actor.sprite_radius)/maxf(size.x,size.y)
		var frame := floori(clock*30.0)
		for i in 18:
			var rng := [i*17+frame*3+index*101+1]
			var sample: Vector2 = edges[mini(edges.size()-1,floori(_next(rng)*edges.size()))]
			var origin: Vector2 = canvas.to_logical(actor.position+sample.rotated(angle)*scale)
			var length := 2.0+4.0*_next(rng)
			var end := origin-direction*length+Vector2(_next(rng)*2.0-1.0,_next(rng)*2.0-1.0)
			canvas.front.line(origin.x,origin.y,end.x,end.y,func(w): return COLORS[1] if w<0.3 else COLORS[3] if w<0.6 else COLORS[5])
		var head: Vector2 = canvas.to_logical(actor.position+direction*radius*0.6)
		canvas.front.glow(head.x,head.y,radius*float(canvas.world_scale)*1.6,COLORS[4],0.45)
		canvas.front.glow(head.x,head.y,radius*float(canvas.world_scale)*0.6,COLORS[1],0.4)
