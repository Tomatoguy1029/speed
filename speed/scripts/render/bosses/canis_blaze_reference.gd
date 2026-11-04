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
	var field := PackedFloat32Array()
	field.resize(width*height*3)
	for sample: Dictionary in list: FIELD._splat(field,width,height,origin,sample.point,float(sample.radius),int(sample.layer))
	var stepped_clock := floorf(clock*settings.update_fps)/settings.update_fps
	var deformation := float(settings.deformation)/logical_pixel
	var colors := []
	for color: Color in [settings.outer_color,settings.inner_color,settings.core_color]:
		colors.append(Color(roundf(color.r*255.0)/255.0,roundf(color.g*255.0)/255.0,roundf(color.b*255.0)/255.0))
	var logical_size: Vector2i = canvas.logical_size
	for y in range(maxi(0,-origin.y),mini(height,logical_size.y-origin.y)):
		for x in range(maxi(0,-origin.x),mini(width,logical_size.x-origin.x)):
			var px := x+origin.x
			var py := y+origin.y
			var wx := px*logical_pixel
			var wy := py*logical_pixel
			var u := (sin(wy*0.075-stepped_clock*4.4)+sin(wx*0.11+wy*0.033+stepped_clock*2.1))*deformation
			var v := cos(wx*0.08+stepped_clock*3.0)*0.55*deformation
			if FIELD._read(field,width,height,x+u,y+v,0)<settings.merge_threshold: continue
			var inner := FIELD._read(field,width,height,x+u,y+v,1)>=settings.merge_threshold
			var core := inner and FIELD._read(field,width,height,x+u,y+v,2)>=settings.merge_threshold
			var color: Color = colors[2 if core else 1 if inner else 0]
			canvas.front.px(px,py,color)
			if (px&3)==0 and (py&3)==0: canvas.front.glow(px,py,5.0,color,0.3 if core else 0.18 if inner else 0.08)
