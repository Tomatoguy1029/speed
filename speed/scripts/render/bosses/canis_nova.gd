## canisNovaLight の遮光場・予兆光・閃光。遮光alphaはC++の判定と同じ値を使う。
extends RefCounted

const TINT := Color("#9caec0")
const FLASH := Color("#e8f4ff")
const SOURCE_GLOW := Color("#bedbe8")
const CORONA := Color("#6a9bca")
const HOT := Color("#fff0cc")
const EMISSION := preload("res://data/visuals/canis_nova_emission.tres")
const SPARK := Color("#ffe7bd")
const WHITE := Color.WHITE
const BLUE_LINE := Color("#9ed8ff")
static var _raster_front := SpeedFxRaster.new()
static var _raster_back := SpeedFxRaster.new()

static func flash(age: float) -> float:
	return smoothstep(0.0,0.09,age)*(1.0-smoothstep(0.22,0.98,age))

static func draw_field(canvas, nova: Dictionary, params: Dictionary) -> void:
	var alpha: PackedByteArray = nova.get("field_alpha",PackedByteArray())
	var width := int(nova.get("field_width",0))
	var height := int(nova.get("field_height",0))
	var cell: float = float(nova.get("field_cell",0.0))*canvas.world_scale
	if width<=0 or height<=0 or cell<=0.0 or alpha.size()!=width*height: return
	var age := float(nova.age)
	var warn := float(nova.warn)
	var t := age-warn
	var charge := smoothstep(float(nova.gather_start),warn,age) if age<warn else 0.0
	var burst := flash(t)
	var tell := charge if t<0.0 else 1.0-smoothstep(0.22,0.98,t)
	if tell<=0.0 and burst<=0.0: return
	var gain := minf(float(params.intensity),1.0)
	var source: Vector2 = canvas.to_logical(nova.source)
	var samples: PackedFloat32Array = EMISSION.get_meta("values")
	var aperture: float = float(nova.radius)*canvas.world_scale*(0.18+0.28*tell*(1.0-0.65*smoothstep(0.83,1.0,tell)) if t<0.0 else 0.24+2.65*smoothstep(0.0,0.115,t))
	var field_origin: Vector2 = canvas.to_logical(nova.field_origin)
	var range_end := float(nova.ring_end)
	var field := {"width": width, "height": height, "cell": cell, "source": source, "origin": field_origin,
		"aperture": aperture, "range_end": range_end, "t": t, "tell": tell, "burst": burst, "gain": gain}
	for pair: Array in [[canvas.back, _raster_back, false], [canvas.front, _raster_front, true]]:
		var painter = pair[0]
		var raster = pair[1]
		raster.begin_painter(painter, float(canvas.world_scale), canvas._camera_position, false, true)
		raster.nova_field(alpha, samples, field, pair[2])
		painter.lights = raster.take_lights()
		painter.has_light = painter.has_light or raster.has_light()
	canvas.front.glow(source.x,source.y,4.0+tell*6.0+burst*9.0,SOURCE_GLOW,gain*(tell*0.12+burst*0.25))
	if nova.get("hit_visual",false): _hit_sparks(canvas,nova,t-0.09,burst,gain)

static func draw_flare(canvas, nova: Dictionary, params: Dictionary) -> void:
	_implode(canvas,canvas.to_logical(nova.source),float(nova.age)-float(nova.warn),float(params.novaGatherTime),minf(float(params.intensity),1.0))

## canisNovaImplode: 吸い込まれる70本と、発動後に散る90本。
static func _implode(canvas, source: Vector2, t: float, duration: float, gain: float) -> void:
	var still_time := minf(0.08,duration*0.2)
	if t>=-duration and t<0.0:
		var k := smoothstep(-duration,-still_time,t)
		if t<=-still_time:
			for i in 70:
				var angle := _hash(i*7.31)*TAU
				var speed := 0.6+0.8*_hash(i*3.3)
				var phase := fposmod(_hash(i*1.7)+(t+duration)/duration*0.75*speed*1.6,1.0)
				var radius := (1.0-phase)*(110.0-70.0*k)
				var length := 4.0+10.0*(1.0-phase)
				var at := source+Vector2.from_angle(angle)*radius
				var end := at+Vector2.from_angle(angle)*length
				canvas.front.line(at.x,at.y,end.x,end.y,func(u): return WHITE if u<0.4 else BLUE_LINE,func(u): return (1.0-u)*(0.3+0.7*phase)*gain)
		canvas.front.glow(source.x,source.y,2.0+2.0*k,WHITE,(0.5+0.5*k)*gain)
		canvas.front.px(source.x,source.y,WHITE)
	if t>=0.0 and t<0.45:
		var u := t/0.45
		canvas.front.glow(source.x,source.y,18.0+90.0*sqrt(u),FLASH,(1.0-u)*1.2*gain)
		canvas.front.glow(source.x,source.y,6.0+20.0*u,WHITE,(1.0-u)*gain)
		for i in 90:
			var angle := _hash(i*5.17)*TAU
			var speed := 0.5+_hash(i*9.1)
			var radius := (20.0+260.0*speed)*pow(u,0.6)
			var length := (8.0+30.0*speed)*(1.0-u)
			var at := source+Vector2.from_angle(angle)*radius
			var start := at-Vector2.from_angle(angle)*length
			canvas.front.line(start.x,start.y,at.x,at.y,func(q): return WHITE if q>0.6 else BLUE_LINE,func(q): return q*(1.0-u)*gain)

static func _hash(n: float) -> float:
	var value := sin(n*127.1+311.7)*43758.5453
	return value-floorf(value)

## FX.sparks の固定seed・粒数・寿命・色をそのまま使う。
static func _hit_sparks(canvas, nova: Dictionary, age: float, burst: float, gain: float) -> void:
	var target: Vector2 = canvas.to_logical(nova.ship_position)
	var direction: float = (nova.ship_position-nova.source).angle()
	var bright := SPARK.lerp(Color.WHITE,0.45)
	for i in 19:
		var life := 0.34*lerpf(0.6,1.2,_hash(81+i*1.7))
		if age>life or age<0.0: continue
		var angle := direction+(_hash(81*5+i)-0.5)*2.0*1.4
		var speed := 78.0*lerpf(0.5,1.3,_hash(81*9+i))
		var q := age/life
		var distance := speed*age*(1.0-q*0.4)
		var at := target+Vector2(cos(angle)*distance,sin(angle)*distance+20.0*age*age)
		var tail := minf(4.0,1.0+speed*0.03*(1.0-q))
		var start := at-Vector2.from_angle(angle)*tail
		canvas.front.line(start.x,start.y,at.x,at.y,func(u): return (Color.WHITE if q<0.4 else bright) if u>0.5 else SPARK,1.0-q*0.6)
		canvas.front.light(at.x,at.y,SPARK,0.3*(1.0-q))
	canvas.front.glow(target.x,target.y,8.0,SPARK,burst*gain*0.48)
