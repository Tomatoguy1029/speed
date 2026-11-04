## 角の実軌道に沿う薙ぎの面。元 monoceros_fx.js の monoSlashCrescent / monoSweepSlash。
## 軌道と粒子は戦闘時の固定更新で保持し、この部品は面と光だけを描く。
extends RefCounted

static func _ramp(base: Color) -> Array[Color]:
	var result: Array[Color] = []
	for factor in [0.25,0.45,0.7,1.0]:
		result.append(Color(roundf(base.r*factor*255.0)/255.0,roundf(base.g*factor*255.0)/255.0,roundf(base.b*factor*255.0)/255.0))
	for white in [0.35,0.7]:
		result.append(Color(roundf(lerpf(base.r,1.0,white)*255.0)/255.0,roundf(lerpf(base.g,1.0,white)*255.0)/255.0,roundf(lerpf(base.b,1.0,white)*255.0)/255.0))
	result.append(Color.WHITE)
	return result

static func _progress_at(points: Array, time: float) -> float:
	for i in range(1,points.size()):
		var a: Dictionary = points[i-1]
		var b: Dictionary = points[i]
		if float(b.t)>=time:
			return lerpf(float(a.v),float(b.v),clampf((time-float(a.t))/maxf(0.00001,float(b.t)-float(a.t)),0.0,1.0))
	return float(points.back().v)

static func _crescent(canvas, points: Array, head: float, tail: float, width: float, ramp: Array[Color], age: float, radius_scale := 1.0) -> void:
	if head-tail<0.005 or width<0.3: return
	var center: Vector2 = points[0].center
	var logical_center: Vector2 = canvas.to_logical(center)
	var p = canvas.front
	for i in range(points.size()-1):
		var a: Dictionary = points[i]
		var b: Dictionary = points[i+1]
		if float(b.v)<=tail or float(a.v)>=head or float(b.v)-float(a.v)<0.00001: continue
		var angle := (Vector2(a.tip)-center).angle()
		var span := angle_difference(angle,(Vector2(b.tip)-center).angle())
		if absf(span)<0.00001: continue
		var radius_a := Vector2(a.tip).distance_to(center)*float(canvas.world_scale)*radius_scale
		var radius_b := Vector2(b.tip).distance_to(center)*float(canvas.world_scale)*radius_scale
		var bounds := maxf(radius_a,radius_b)+2.0
		var count := ramp.size()
		p.shade(logical_center.x-bounds,logical_center.y-bounds,logical_center.x+bounds,logical_center.y+bounds,
			func(x: float,y: float,out: Dictionary):
				var delta := Vector2(x,y)-logical_center
				var radius := delta.length()
				var f := angle_difference(angle,delta.angle())/span
				if f<0.0 or f>=1.0: return
				var edge_radius := lerpf(radius_a,radius_b,f)
				if radius>edge_radius+0.5 or radius<edge_radius-width-1.0: return
				var along := lerpf(float(a.v),float(b.v),f)
				if along<tail or along>head: return
				var v := (along-tail)/(head-tail)
				var w := width*pow(sin(PI*pow(v,2.2)),0.6)
				if w<0.35: return
				var q := (edge_radius-radius)/w
				if q<0.0 or q>1.0: return
				var color_index := 0 if q<0.22 and age<0.5 else roundi(q*(count-1)*0.75+age*2.4-v*0.8+0.4)
				out.c = ramp[count-1-clampi(color_index,0,count-1)]
				out.a = minf(1.0,v/0.4))
		if float(b.v)>=tail and float(b.v)<=head:
			var tip: Vector2 = canvas.to_logical(b.tip)
			var inward := (logical_center-tip).normalized()
			var at := logical_center+(tip-logical_center)*radius_scale+inward*width*0.4
			p.glow(at.x,at.y,5.0+width,ramp[count-3],0.22*(1.0-age)*(float(b.v)-tail)/(head-tail))

## points は固定更新で記録した {center, tip, v, t}。粒は別途同じ時刻で描く。
static func draw(canvas, points: Array, time: float, sweep: float, params: Dictionary) -> void:
	if points.size()<2: return
	var timing := float(params.timing)
	var linger := 0.32*timing
	if time<0.0 or time>sweep+maxf(linger,0.55): return
	var ramp := _ramp(Color(params.color))
	var width := 42.0*float(canvas.world_scale)*float(params.size)
	var p = canvas.front
	var fade: float = p.fade
	p.fade *= float(params.intensity)
	var echo_time := time-0.017*timing
	var echo_end := 1.0-0.15/3.5
	var echo_tail := 0.1+(echo_end-0.1)*smoothstep(sweep+0.03*timing,sweep+0.23*timing,echo_time)
	if echo_time>=0.0:
		var echo_width := width*4.5/12.0*(1.0-clampf((echo_tail-0.1)/(echo_end-0.1),0.0,1.0)*0.55)
		var echo_ramp: Array[Color] = []
		echo_ramp.assign(ramp.slice(0,6))
		_crescent(canvas,points,minf(echo_end,_progress_at(points,echo_time)),echo_tail,echo_width,echo_ramp,clampf(echo_time/(sweep+0.23*timing),0.0,1.0),33.0/42.0)
	var tail := smoothstep(sweep+0.06*timing,sweep+linger,time)
	var age := clampf(time/(sweep+linger),0.0,1.0)
	_crescent(canvas,points,float(points.back().v),tail,width*(1.0-tail*0.55),ramp,age)
	if time<0.3*timing:
		var last: Dictionary = points.back()
		var tip: Vector2 = canvas.to_logical(last.tip)
		var inward: Vector2 = (canvas.to_logical(last.center)-tip).normalized()
		var at := tip+inward*width/3.0
		p.glow(at.x,at.y,40.0*width/12.0,ramp[3],0.5*(1.0-time/(0.3*timing)))
	p.fade = fade
