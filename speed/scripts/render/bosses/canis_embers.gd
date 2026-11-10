## canisEmbers: 実通過画素だけを使い、すすと3層の残り火を描く。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const H := [Color("#ffffff"),Color("#f2fbff"),Color("#d8f1ff"),Color("#a9dcff"),Color("#6fb8f2"),Color("#3f8ce0"),Color("#2a66c4"),Color("#1d479b"),Color("#13306a")]
const SOOT := [Color("#0c1420"),Color("#142238")]

static func _hash(n: float) -> float:
	var value := sin(n*127.1+311.7)*43758.5453
	return value-floorf(value)

static func draw(canvas, rows: Array, clock: float, logical_pixel: float) -> void:
	var groups := {}
	for row: Dictionary in rows:
		var id := str(row.settings)
		if not groups.has(id): groups[id] = []
		groups[id].append(row)
	for id: String in groups:
		_draw_group(canvas,groups[id],clock,logical_pixel,SETTINGS.for_id(id),id in ["O-sirius_flame","O-relay","O-hunt"])

static func _draw_group(canvas, rows: Array, clock: float, logical_pixel: float, params: Dictionary, has_footprints: bool) -> void:
	if params.is_empty(): return
	var masks := []
	if has_footprints:
		for row: Dictionary in rows:
			var keys := {}
			for key: int in row.footprint: keys[key] = true
			var origin: Vector2 = row.field_origin
			masks.append({"keys":keys,"cell":float(row.history_cell),"origin":origin,"logical_origin":canvas.to_logical(origin)})
	var particles: Array = []
	for row: Dictionary in rows:
		var elapsed := clock-float(row.started)
		var wait := clampf(float(params.emberDelay),0.0,float(row.duration))
		var born := elapsed-wait
		var after := maxf(0.0,elapsed-float(row.duration)-0.22/float(row.speed))
		if born<0.0: continue
		for deposit: Dictionary in row.deposits:
			var seed := float(deposit.seed)
			var life := 1.0+_hash(seed+5.0)*1.8
			if after>life+0.8: continue
			var center: Vector2 = canvas.to_logical(deposit.position)
			var pixels: PackedVector2Array = deposit.pixels
			var cell := 45.0*float(canvas.world_scale)
			for j in 7:
				var point := Vector2.ZERO
				if not pixels.is_empty(): point = canvas.to_logical(pixels[floori(_hash(seed+j*7.0)*pixels.size())])
				else: point = center+Vector2((_hash(seed+j*7.0)-0.5)*cell*1.2,(_hash(seed+j*11.0)-0.5)*cell*1.2)
				if _hash(seed+j*13.0+1.0)<0.35: continue
				canvas.mid.blend(point.x,point.y,SOOT[j%2],0.6*(1.0-smoothstep(life*0.5,life+0.8,after)))
			for j in 4:
				var h := _hash(seed+j*17.0+3.0)
				if h<0.3: continue
				var lf := life*(0.45+0.55*_hash(seed+j*29.0))
				if after>lf: continue
				var k := 1.0-after/lf
				var flick := 0.75+0.25*sin(clock*(9.0+h*7.0)+j*2.0)
				var point := Vector2.ZERO
				if not pixels.is_empty(): point = canvas.to_logical(pixels[floori(_hash(seed+j*7.0+50.0)*pixels.size())])
				else: point = center+Vector2((_hash(seed+j*7.0+50.0)-0.5)*cell*1.1,(_hash(seed+j*11.0+50.0)-0.5)*cell*1.1)
				var width := 1.0 if not pixels.is_empty() else float(params.jetWidth)*float(params["size"])
				var radius := (2.4+3.4*h)*pow(k,0.6)*flick*width*smoothstep(0.0,0.1,born)
				particles.append({"point":point,"radius":radius,"age":1.0-k})
	if particles.is_empty(): return
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	for particle: Dictionary in particles:
		var point: Vector2 = particle.point
		var size := float(particle.radius)*2.0
		lo = lo.min(point-Vector2.ONE*size)
		hi = hi.max(point+Vector2.ONE*size)
	var logical_size: Vector2i = canvas.logical_size
	var origin := Vector2i(maxi(0,floori(lo.x)),maxi(0,floori(lo.y)))
	var width := mini(logical_size.x,ceili(hi.x))-origin.x+1
	var height := mini(logical_size.y,ceili(hi.y))-origin.y+1
	if width<=0 or height<=0: return
	var points := PackedVector2Array()
	var radii := PackedFloat64Array()
	var layers := PackedByteArray()
	for particle: Dictionary in particles:
		var point: Vector2 = particle.point
		var radius := float(particle.radius)
		var age := float(particle.age)
		points.append(point)
		radii.append(radius * 1.25)
		layers.append(0)
		if age < 0.55:
			points.append(point + Vector2(0, -radius * 0.15))
			radii.append(radius * 0.8)
			layers.append(1)
		if age < 0.25:
			points.append(point + Vector2(0, -radius * 0.2))
			radii.append(radius * 0.5)
			layers.append(2)
	var display := {"clock": floorf(clock * 30.0) / 30.0, "logical_pixel": logical_pixel,
		"deformation": 1.2, "v_gain": 0.66, "v_deformation": 1.0, "threshold": 0.32,
		"glow_radius": 4.0, "strengths": PackedFloat64Array([0.18 * float(params.intensity), 0.18 * float(params.intensity), 0.18 * float(params.intensity)]),
		"masks": masks, "include_edge": true}
	_draw_density(canvas, canvas.mid, points, radii, layers, origin, width, height, display, PackedColorArray([H[6], H[4], H[1]]))

## 動く粒の入力をまとめて渡し、密度領域の保存場所は再利用する。
static func _draw_density(canvas, painter, points: PackedVector2Array, radii: PackedFloat64Array, layers: PackedByteArray, origin: Vector2i, width: int, height: int, display: Dictionary, palette: PackedColorArray) -> void:
	var raster: SpeedFxRaster = canvas.get_density_raster()
	raster.begin(painter.colors, painter.lights, painter.width, painter.height, float(canvas.world_scale), canvas._camera_position)
	raster.density_field(points, radii, layers, origin, width, height, display, palette)
	painter.colors = raster.take_colors()
	painter.lights = raster.take_lights()
	painter.has_color = painter.has_color or raster.has_color()
	painter.has_light = painter.has_light or raster.has_light()
