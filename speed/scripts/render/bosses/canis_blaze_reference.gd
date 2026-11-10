## 凍結canisFireの3層密度場。着火と燃える猟犬の炎を同じ論理画素へ置く。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const IGNITE := preload("res://data/visuals/canis_fire_ignite.tres")
const HOUND := preload("res://data/visuals/canis_fire_hound.tres")
const FIELD := preload("res://scripts/render/bosses/canis_embers.gd")

static func draw(canvas, rows: Array, burning: Array, clock: float, logical_pixel: float) -> void:
	var params: Dictionary = SETTINGS.for_id("O-blaze")
	if params.is_empty() or float(params.intensity)<=0.0: return
	for row: Dictionary in burning:
		var samples := []
		var direction := float(row.facing)
		var radius := float(row.radius)
		for i in 12:
			var offset := Vector2(-i*radius*0.3,sin(i*2.0+clock*18.0)*radius*0.4).rotated(direction)
			samples.append({"pos":row.position+offset,"radius":radius*(1.4-i*0.08),"seed":i})
		_draw_samples(canvas,samples,clock,logical_pixel,HOUND,float(params["size"]))
	for row: Dictionary in rows:
		if int(row.kind)!=3: continue
		var age := float(row.age)
		var life := float(row.get("travel_time",row.life))
		if life<=0.0 or age>life+0.25: continue
		var point: Vector2 = (row.from as Vector2).lerp(row.to,clampf(age/life,0.0,1.0))
		var fade := 1.0-smoothstep(life,life+0.25,age)
		_draw_samples(canvas,[{"pos":point,"radius":16.0*fade}],clock,logical_pixel,IGNITE,float(params["size"]))

static func _draw_samples(canvas, samples: Array, clock: float, logical_pixel: float, settings: PixelFireSettings, size: float) -> void:
	if samples.is_empty() or size<=0.0: return
	var list := []
	var count := mini(samples.size(),floori(settings.capacity/3.0))
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for slot in count:
		var index := roundi(float(slot)/maxf(1.0,float(count-1))*(samples.size()-1))
		var sample: Dictionary = samples[index]
		var seed := float(sample.get("seed",slot))
		for layer in 3:
			var budget := maxi(1,floori(float(settings.capacity)/maxi(1,count)/3.0))
			var births := mini(budget,maxi(1,mini(5,ceili(settings.birth_rate/28.0*settings.layer_rates[layer]))))
			for k in births:
				var phase := seed*2.39996+k*1.7+layer
				var cycle := fposmod(clock*settings.rise_speed/108.0+phase,1.0)
				var age := 0.1+cycle*0.35+float(sample.get("age",0.0))/maxf(0.001,float(sample.get("life",1.0)))*0.2
				var jitter := Vector2(sin(phase+clock*2.0)*settings.sway*0.12,cos(phase+clock)*settings.source_size.y*0.12)
				var point: Vector2 = canvas.to_logical(sample.pos+jitter)
				var radius := float(sample.radius)*settings.particle_size/27.0*settings.layer_sizes[layer]*pow(1.0-age,0.6)*(0.7+0.3*smoothstep(0.0,0.08,age))*float(canvas.world_scale)*size
				list.append({"point":point,"radius":radius,"layer":layer})
				low = low.min(point-Vector2.ONE*radius*2.0)
				high = high.max(point+Vector2.ONE*radius*2.0)
	if list.is_empty(): return
	var origin := Vector2i(floori(low.x)-6,floori(low.y)-6)
	var width := ceili(high.x)-origin.x+6
	var height := ceili(high.y)-origin.y+6
	if width<=0 or height<=0: return
	var points := PackedVector2Array()
	var radii := PackedFloat64Array()
	var layers := PackedByteArray()
	for sample: Dictionary in list:
		points.append(sample.point)
		radii.append(float(sample.radius))
		layers.append(int(sample.layer))
	var colors := PackedColorArray()
	for color: Color in [settings.outer_color, settings.inner_color, settings.core_color]:
		colors.append(Color(roundf(color.r * 255.0) / 255.0, roundf(color.g * 255.0) / 255.0, roundf(color.b * 255.0) / 255.0))
	var deformation := float(settings.deformation) / logical_pixel
	var display := {"clock": floorf(clock * settings.update_fps) / settings.update_fps, "logical_pixel": logical_pixel,
		"deformation": deformation, "v_gain": 0.55, "v_deformation": deformation, "threshold": settings.merge_threshold,
		"glow_radius": 5.0, "strengths": PackedFloat64Array([0.08, 0.18, 0.3])}
	FIELD._draw_density(canvas, canvas.front, points, radii, layers, origin, width, height, display, colors)
