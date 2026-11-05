## centaurus.js のC07/C10/C05/C13/C09。状態と寿命は本番から受け取る。
extends Node2D
const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const ARROW := preload("res://scripts/render/attacks/light_arrow.gd")
const RANDOM := preload("res://scripts/render/enemies/aquarius_jet.gd")
var _random = RANDOM.new()
var _ups: Array = []
var _clock := 0.0

func _mix(a: Color, b: Color, weight: float) -> Color:
	var k := clampf(weight,0.0,1.0)
	return Color8(int(lerpf(roundf(a.r*255),roundf(b.r*255),k)),int(lerpf(roundf(a.g*255),roundf(b.g*255),k)),int(lerpf(roundf(a.b*255),roundf(b.b*255),k)))

func draw_reference(body: Dictionary, attack: Dictionary, canvas) -> void:
	_clock = float(body.clock)
	var effects: Dictionary = body.get("reference_fx",{})
	_ups = effects.get("ups",[])
	if attack.get("technique","")=="power_shot" and int(attack.get("stage",5))==0: _power(body,attack,canvas)
	for row: Dictionary in effects.get("releases",[]): _release(row,canvas)
	for row: Dictionary in effects.get("landings",[]): _landing(row,canvas)
	if attack.get("technique","")=="stomp" and int(attack.get("stage",5))==0:
		_stomp({"position":attack.center,"angle":body.facing,"half":attack.half_angle,"radius":attack.range_radius},canvas,true,float(body.charge))
	for row: Dictionary in effects.get("stomps",[]): _stomp(row,canvas,false,0.0)
	var palette: Array[Color] = FX.ramp(Color(SETTINGS.for_id("C09-rain-current").color))
	for row: Dictionary in _ups:
		var age := _clock-float(row.started)
		if age<0.0 or age>0.5: continue
		var direction := Vector2.from_angle(float(row.angle))
		var a: Vector2 = canvas.to_logical(row.position)
		var at: Vector2 = canvas.to_logical(Vector2(row.position)+direction*1700.0*age)
		var opacity := 1.0-smoothstep(0.3,0.5,age)
		if age<0.06:
			canvas.front.glow(a.x,a.y,4.0,palette[4],1.0-age/0.06)
			canvas.front.glow(a.x,a.y,11.0,palette[3],0.6*(1.0-age/0.06))
		canvas.front.line(at.x-direction.x*2.0,at.y-direction.y*2.0,at.x-direction.x*18.0,at.y-direction.y*18.0,func(u:float): return palette[4] if u<0.3 else palette[3],func(u:float):return (1.0-u)*0.6*opacity)
	queue_redraw()

func _draw() -> void:
	for row: Dictionary in _ups:
		var age := _clock-float(row.started)
		if age<0.0 or age>0.5: continue
		var at: Vector2 = Vector2(row.position)+Vector2.from_angle(float(row.angle))*1700.0*age
		ARROW.draw_arrow(self,at,float(row.angle),float(row.radius),false,_clock,1.0-smoothstep(0.3,0.5,age),Color.WHITE,float(row.length))

func _power(body: Dictionary, attack: Dictionary, canvas) -> void:
	var p: Dictionary = SETTINGS.for_id("C07-power-shot")
	var mouth: Vector2 = attack.aim_origin
	var angle := float(attack.aim_angle)
	var end := mouth+Vector2.from_angle(angle)*float(attack.travel)
	var hit := Geom.seg_circle_t(mouth,end,attack.ship_position,float(attack.ship_radius))
	if hit>=0.0: end=mouth.lerp(end,hit)
	var a: Vector2 = canvas.to_logical(mouth)
	var e: Vector2 = canvas.to_logical(end)
	var locked := bool(attack.alerting)
	var k := float(body.charge)
	var color := Color(p.color) if locked else Color("ffb35a")
	var palette: Array[Color] = FX.ramp(color)
	FX.warn_rail(canvas.back,a,e,{"color":color,"k":1.0 if locked else 0.35+0.45*k,"time":_clock,"seed":77,"rail":1.6 if locked else 0.9,"intensity":float(p.intensity),"maxLv":2})
	var jitter := 0.0 if locked else (1.0-k)*3.0
	if hit>=0.0:
		var q := e+Vector2(sin(_clock*23.0),cos(_clock*17.0))*jitter
		canvas.front.px(q.x,q.y,palette[4])
		canvas.front.glow(q.x,q.y,(3.0 if locked else 5.0-2.0*k)*float(p.size),palette[4],0.7*float(p.intensity))
		canvas.front.glow(q.x,q.y,9.0,palette[2],0.6*float(p.intensity))
	canvas.front.px(a.x,a.y,palette[4])
	canvas.front.glow(a.x,a.y,2.5+(2.0 if locked else 0.0),palette[4],0.7)
	canvas.front.glow(a.x,a.y,8.0+6.0*k,palette[2],0.5*float(p.intensity))
	var alert_age := float(attack.get("alert_age",1.0))
	if locked and alert_age>=0.0 and alert_age<0.1: FX.flare(canvas.front,a,3.0*float(p.size),Color(p.color),_clock,1.0-alert_age/0.1,4)

func _cycle(time: float, count: int, seed: int, lo: float, hi: float) -> Array:
	var result := []
	for i in count:
		var g = RANDOM.Rng.new(_random._hash([seed,i,911]))
		var born: float = g.next()*10.0
		var life: float = g.between(lo,hi)
		var age := fposmod(time-born,10.0)
		if age<life and age<=time: result.append({"age":age,"life":life,"rng":RANDOM.Rng.new(_random._hash([seed,i]))})
	return result

func _release(row: Dictionary, canvas) -> void:
	var p: Dictionary = SETTINGS.for_id("C10-release")
	var time := (_clock-float(row.started))/float(p.timing)
	if time<0.0 or time>0.4: return
	var a: Vector2 = canvas.to_logical(row.position)
	var palette: Array[Color] = FX.ramp(Color(p.color))
	var u := Vector2.from_angle(float(row.angle))
	var n := u.orthogonal()
	var wind := _mix(palette[3],Color("fff4dc"),0.3)
	var dark := Color("2a2540")
	var size := float(p.size)
	if time<0.06:
		canvas.front.glow(a.x,a.y,4.0*size,palette[4],1.0-time/0.06)
		canvas.front.glow(a.x,a.y,12.0*size,palette[3],0.7*(1.0-time/0.06)*float(p.intensity))
	for item: Dictionary in _cycle(time,12,floori(float(row.started)*97.0),0.14,0.3):
		var r = item.rng
		var age := float(item.age)
		var k := age/float(item.life)
		var side := -1.0 if r.next()<0.5 else 1.0
		var distance: float = r.between(4.0,34.0)*size+age*r.between(20.0,50.0)
		var length: float = r.between(6.0,14.0)*(0.5+k)*size
		var offset: float = side*(r.between(2.5,4.5)+k*r.between(1.0,2.5))*size
		var point := a+u*distance+n*offset
		canvas.front.line(point.x,point.y,point.x-u.x*length,point.y-u.y*length,func(w:float):return _mix(wind,Color.WHITE,0.5) if w<0.25 and k<0.4 else wind if k<0.4 else _mix(wind,dark,(k-0.4)*1.2),func(w:float):return (1.0 if w<0.65 else (1.0-w)/0.35)*(1.0-k*0.6))
	for item: Dictionary in _cycle(time,6,floori(float(row.started)*53.0),0.15,0.28):
		var r = item.rng
		var age := float(item.age)
		var k := age/float(item.life)
		var distance: float = r.between(0.0,8.0)*size+age*15.0
		var offset: float = (-1.0 if r.next()<0.5 else 1.0)*(r.between(2.0,4.0)+age*25.0)*size
		var angle: float = age*30.0+r.between(0.0,TAU)
		var radius := (1.2+k*1.5)*size
		var center := a+u*distance+n*offset
		for i in 4:
			var point := center+Vector2.from_angle(angle+i*0.5)*radius
			canvas.front.dot(point.x,point.y,wind,(1.0-k)*(1.0-i*0.2))
	FX.sparks(canvas.front,a,time,float(row.started)*31.0,7,Color(p.color),45.0,0.25,float(row.angle),0.4)

func _landing(row: Dictionary, canvas) -> void:
	var p: Dictionary = SETTINGS.for_id("C05-landing")
	var time := (_clock-float(row.started))/float(p.timing)
	if time<0.0 or time>0.3: return
	var palette: Array[Color] = FX.ramp(Color(p.color))
	var index := 0
	for foot: Vector2 in row.feet:
		var point: Vector2 = canvas.to_logical(foot)
		for j in 7:
			var life := 0.2+FX.hash_value(index*9+j)*0.1
			if time>life: continue
			var q := time/life
			var angle := FX.hash_value(index*13+j*3)*TAU
			var distance := (3.0+12.0*sqrt(q))*float(p.size)
			var radius := (1.5+3.5*q)*float(p.size)
			canvas.back.disc(point.x+cos(angle)*distance,point.y+sin(angle)*distance*0.7-q*2.0,radius,palette[3 if q<0.3 else 2],func(d:float):return 0.45*(1.0-q)*(1.0-d*d)*float(p.intensity))
		if time<0.08: canvas.back.glow(point.x,point.y,6.0,palette[3],0.4*(1.0-time/0.08))
		index+=1
	var center: Vector2 = canvas.to_logical(row.position)
	for j in 40:
		var angle := FX.hash_value(j)*TAU
		var distance: float = float(row.radius)*canvas.world_scale*0.8*(0.6+1.1*time/0.3)*(0.85+0.3*FX.hash_value(j+1))
		canvas.back.dot(center.x+cos(angle)*distance,center.y+sin(angle)*distance*0.75,palette[2],0.7*(1.0-time/0.3))

func _cracks(center: Vector2, angle: float, half: float, radius: float) -> Array:
	var result := []
	for q in 5:
		var a := angle+(q/4.0-0.5)*2.0*half*0.85+(FX.hash_value(q*5)-0.5)*0.2
		var point := center
		var step := radius*(0.55+0.4*FX.hash_value(q+9))/14.0
		for s in 14:
			a+=(FX.hash_value(q*17+s)-0.5)*0.9
			var next := point+Vector2.from_angle(a)*step
			if absf(angle_difference(angle,(next-center).angle()))>half or next.distance_to(center)>radius: break
			result.append({"from":point,"to":next,"u":s/14.0,"trunk":true})
			if s==5 and FX.hash_value(q+33)>0.4:
				var b := a+(0.7 if FX.hash_value(q)>0.5 else -0.7)
				var branch := next
				for k in 4:
					var end := branch+Vector2.from_angle(b)*step
					if absf(angle_difference(angle,(end-center).angle()))>half or end.distance_to(center)>radius: break
					result.append({"from":branch,"to":end,"u":(s+k+1)/14.0,"trunk":false})
					branch=end
					b+=(FX.hash_value(k+q*3)-0.5)*0.8
			point=next
	return result

func _stomp(row: Dictionary, canvas, warning: bool, charge: float) -> void:
	var p: Dictionary = SETTINGS.for_id("C13-stomp")
	var point: Vector2 = canvas.to_logical(row.position)
	var radius: float = float(row.radius)*canvas.world_scale
	var cracks := _cracks(point,float(row.angle),float(row.half),radius)
	var crack: Array[Color] = FX.ramp(Color("ffc890"))
	var dirt: Array[Color] = FX.ramp(Color("b89878"))
	var palette: Array[Color] = FX.ramp(Color(p.color))
	if warning:
		var grow := smoothstep(0.0,1.0,charge)
		var flicker := 0.55+0.45*sin(_clock*40.0)*sin(_clock*23.0)
		for c: Dictionary in cracks:
			if float(c.u)<=grow: canvas.back.line(c.from.x,c.from.y,c.to.x,c.to.y,crack[2],(0.25+0.4*charge)*flicker*float(p.intensity))
		canvas.front.glow(point.x,point.y,8.0+10.0*charge,palette[3],0.5*charge*float(p.intensity))
		return
	var time := (_clock-float(row.started))/float(p.timing)
	if time<0.0 or time>=0.9: return
	for c: Dictionary in cracks:
		if float(c.u)>clampf(time/0.1,0.0,1.0): continue
		canvas.back.beam(c.from.x,c.from.y,c.to.x,c.to.y,maxf(1.0,(1.6 if c.trunk else 1.0)*(1.0-float(c.u)*0.6)),crack[4] if time<0.15 else crack[3] if time<0.4 else dirt[3],1.0-smoothstep(0.45,0.9,time))
		if time<0.4: canvas.back.light(c.to.x,c.to.y,crack[2],0.3*(1.0-time/0.4))
	for i in 12:
		var q := time/0.55
		if q>1.0: continue
		var a := float(row.angle)+(FX.hash_value(i*3.1)-0.5)*2.0*float(row.half)
		var distance := radius*0.5*q*(0.5+FX.hash_value(i))
		canvas.front.rect(point.x+cos(a)*distance-1.0,point.y+sin(a)*distance-10.0*sin(PI*q)-1.0,2.0,2.0,dirt[2+i%2])
	if time<0.1:
		canvas.front.glow(point.x,point.y,6.0*float(p.size),palette[4],1.0-time/0.1)
		canvas.front.glow(point.x,point.y,radius*0.5,palette[3],0.6*(1.0-time/0.1))
	FX.sparks(canvas.front,point,time,88,16,Color("d8c7a8"),70.0,0.5,float(row.angle),float(row.half))
