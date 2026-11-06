## うみへびの首の見た目。戦闘の点列と判定は変えず、溜め・発動・戻りの動きを絵の位置と向きへ足す。
extends RefCounted
const PRIM := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const COIL := 1.0
const SNAP := 1.0
const LIVE := 1.2
const TYPES := {"bite_thrust":"lunge","bite_sweep":"sweep","wind_band":"breath","wind_blades":"sweep","rubble_lump":"spit","rubble_fan":"spit","beam_fixed":"breath","beam_bolt":"spit","thunder_headbutt":"lunge","thunder_drop":"breath"}
const LUNGES := ["north","sequence","swarm"]
const CURVE_TILT := 0.6108652381980153

static func _hash(n: float) -> float:
	return PRIM.hash_value(n)
static func _smooth(a: float, b: float, x: float) -> float:
	return smoothstep(a,b,x)
static func _orth(v: Vector2) -> Vector2:
	return Vector2(-v.y,v.x)
static func _wrap(a: float) -> float:
	return wrapf(a,-PI,PI)

## 横薙ぎの見た目の頭：ゆっくり→一気に→行き過ぎて戻る緩急、真ん中で外へ突き出す踏み込み、振る先を向く頭。
static func sweep_visual(neck: Dictionary, rel: float, fire_angle: float) -> Dictionary:
	var active := maxf(0.001,float(neck.active_time))
	var arc := float(neck.sweep_arc)
	var sweep := float(neck.sweep)
	var reach := float(neck.sweep_reach)
	var base: Vector2 = neck.base
	var f := clampf(rel/active,0.0,1.0)
	var after := maxf(0.0,rel-active)
	var fe := 4.0*f*f*f if f<0.5 else 1.0-pow(-2.0*f+2.0,3.0)/2.0
	var on := _smooth(0.0,0.06,rel)*(1.0-_smooth(active+0.2,active+0.45,rel))
	var over := sin(minf(1.0,after/0.1)*PI)*exp(-after/0.16) if after>0.0 else 0.0
	var swing := sin(PI*fe)
	var real := sweep+arc*(f-0.5)
	var angle := real+((sweep+arc*(fe-0.5)+arc*0.13*over)-real)*on*LIVE+_wrap(fire_angle-(sweep-arc*0.5))*(1.0-_smooth(0.0,0.14,rel))
	return {"pos":base+Vector2.from_angle(angle)*(reach+(70.0*swing-18.0*(1.0-swing))*on*LIVE),"face":angle+(0.5*swing+0.25*over)*on*LIVE}

static func _normal(neck: Dictionary, mem: Dictionary, clock: float) -> Dictionary:
	var mode: String = neck.mode
	var type: String = TYPES.get(mode,"breath")
	var t := float(neck.elapsed)
	var warn := maxf(0.01,float(neck.warn_time))
	var active := float(neck.active_time)
	var angle := float(neck.facing)
	var at: Vector2 = neck.position
	var out := {"coil":0.0,"freeze":0.0,"rel":-1.0,"head":at,"angle":angle,"sx":1.0,"sy":1.0,"type":type,"warn":warn,"active":active}
	var u := clampf(t/warn,0.0,1.0)
	var fw := Vector2.from_angle(angle)
	if t<warn:
		out.coil = _smooth(0.0,0.62,u)
		out.freeze = _smooth(0.62,0.8,u)
		mem.fire_angle = angle
		var back: float = 16.0 if type=="lunge" else 22.0 if type=="spit" else 12.0 if type=="breath" else 6.0
		var head := at
		if mode=="bite_sweep":
			if not mem.has("wind_from"): mem.wind_from = at.distance_to(neck.base)
			head = Vector2(neck.base)+Vector2.from_angle((at-Vector2(neck.base)).angle())*lerpf(float(mem.wind_from),float(neck.sweep_reach),_smooth(0.1,0.85,u))
		out.head = head-fw*back*float(out.coil)*COIL
		out.sx = 1.0+(0.1 if type=="breath" and mode!="thunder_drop" else 0.05)*float(out.coil)
		out.sy = 1.0-0.08*float(out.coil)
		if float(out.freeze)>0.0: out.head = Vector2(out.head)+_orth(fw)*sin(clock*95.0)*1.6*float(out.freeze)
		return out
	mem.erase("wind_from")
	var rel := t-warn
	out.rel = rel
	out.coil = exp(-rel/0.035)
	var k := clampf(rel/maxf(0.001,active),0.0,1.0)
	if type=="lunge":
		if rel<active:
			out.sy = 1.0+0.16*sin(PI*k)
			out.sx = 1.0-0.07*sin(PI*k)
		else:
			var after := rel-active
			var j := exp(-after/0.07)*sin(minf(1.0,after/0.05)*PI)
			out.head = at+fw*9.0*j*SNAP
			out.sy = 1.0+0.06*j
	elif type=="spit":
		out.head = at+fw*20.0*exp(-rel/0.1)*minf(1.0,rel/0.03)*SNAP
		out.sy = 1.0+0.1*exp(-rel/0.08)
	elif mode=="thunder_drop":
		out.head = at-fw*10.0*exp(-rel/0.12)
	elif type=="breath":
		var on := 1.0 if rel<active else exp(-(rel-active)/0.1)
		out.head = at-fw*9.0*on*SNAP+_orth(fw)*sin(clock*70.0)*1.8*on
		out.sx = 1.0+0.04*on
	if mode=="wind_blades" and neck.has("blade_interval"):
		var interval := maxf(0.01,float(neck.blade_interval))
		var step := minf(2.0,floorf(rel/interval))
		var since := rel-step*interval
		out.angle = angle+0.16*exp(-since/0.06)*sin(minf(1.0,since/0.03)*PI*0.5)*(1.0 if rel<active+interval else 0.0)
	if mode=="bite_sweep" and rel<active+0.5:
		var v := sweep_visual(neck,rel,float(mem.get("fire_angle",angle)))
		out.head = Vector2(v.pos)-Vector2.from_angle(float(v.face))*6.0*float(out.coil)*COIL
		out.angle = v.face
	return out

static func _normal_neck(neck: Dictionary, pose: Dictionary, clock: float) -> PackedVector2Array:
	var pts: PackedVector2Array = neck.points
	var last := pts.size()-1
	if last<1: return pts
	var d_head: Vector2 = Vector2(pose.head)-Vector2(neck.position)
	var side := _orth((pts[last]-pts[0]).normalized())
	var type: String = pose.type
	var amp: float = (30.0 if type=="sweep" else 36.0 if type=="lunge" else 18.0)*COIL
	var out := PackedVector2Array()
	var coil := float(pose.coil)
	var freeze := float(pose.freeze)
	var rel := float(pose.rel)
	var active := float(pose.active)
	for i in pts.size():
		var u := float(i)/last
		var o := 0.0
		if coil>0.0: o += (sin(u*TAU)*sin(u*PI)*0.5 if type=="lunge" else -sin(u*PI))*amp*coil
		if freeze>0.0 and rel<0.0: o += sin(clock*95.0+i*1.7)*1.3*freeze*sin(u*PI)
		if rel>=0.0:
			if neck.mode=="bite_sweep" and rel<active+0.25:
				var w := 1.0 if rel<active else exp(-(rel-active)/0.08)
				o += -sin(u*PI)*(1.0-u*0.3)*26.0*w*(1.0-coil)*COIL
			var after := rel-(active if type=="lunge" else 0.0)
			var s := 1.0-u
			var wave: float = 13.0 if type=="lunge" else 10.0 if type=="spit" else 6.0 if type=="sweep" else 4.0
			if after>0.0 and s<after*9.0: o += sin((after*9.0-s)*9.0)*wave*exp(-after/0.22)*(1.0-s*0.5)*SNAP
		out.append(pose.head if i==last else pts[i]+side*o+d_head*u*u)
	return out

static func _major(neck: Dictionary, mem: Dictionary, clock: float) -> Dictionary:
	var mode: String = neck.mode
	var at: Vector2 = neck.position
	var angle := float(neck.facing)
	var fw := Vector2.from_angle(angle)
	var warn := maxf(0.01,float(neck.warn_time))
	var time := float(neck.get("major_time",0.0))
	var out := {"coil":0.0,"freeze":0.0,"rel":-1.0,"head":at,"angle":angle,"sx":1.0,"sy":1.0,"type":"major","warn":warn,"active":float(neck.active_time),"lunge":mode in LUNGES,"bend":0.0}
	if mode in LUNGES:
		if not neck.locked:
			mem.erase("lock_at")
			out.coil = _smooth(0.0,0.6,clampf(time/warn,0.0,1.0))
			var fz := _smooth(0.6,0.85,clampf(time/warn,0.0,1.0))
			out.head = at-fw*12.0*float(out.coil)*COIL+_orth(fw)*sin(clock*95.0+float(neck.id))*1.5*fz
			out.sy = 1.0-0.07*float(out.coil)
			out.sx = 1.0+0.05*float(out.coil)
		else:
			if not mem.has("lock_at"): mem.lock_at = clock
			var rel := clock-float(mem.lock_at)
			out.rel = rel
			var flight := maxf(0.01,float(neck.get("lunge_time",0.25)))
			out.flight = flight
			if rel<flight:
				out.sy = 1.0+0.14*sin(PI*rel/flight)
				out.sx = 1.0-0.06*sin(PI*rel/flight)
			else:
				var a := rel-flight
				out.head = at+fw*9.0*exp(-a/0.07)*sin(minf(1.0,a/0.05)*PI)*SNAP
		return out
	var delay: float = float(neck.get("curve_delay",0.8)) if mode=="curve" else 0.0
	var u := clampf(time/(warn+delay),0.0,1.0) if mode!="grid" else float(neck.glow)
	var rel := time-warn-delay
	if mode=="grid": rel = -1.0
	if mode=="curve":
		var ext := _smooth(0.0,1.0,clampf(time/warn,0.0,1.0))
		out.angle = angle-CURVE_TILT*ext
		out.bend = Vector2(neck.position).distance_to(neck.base)*0.2*ext
		mem.curve = {"tilt":CURVE_TILT*ext,"bend":float(out.bend)}
		fw = Vector2.from_angle(float(out.angle))
	if rel<0.0:
		var c := _smooth(0.0,0.6,u)
		var fz := _smooth(0.6,0.85,u)
		out.head = at-fw*14.0*c*COIL+_orth(fw)*sin(clock*95.0)*1.4*fz
		out.sx = 1.0+0.05*c
		out.sy = 1.0-0.07*c
	else:
		var j := exp(-rel/0.1)*minf(1.0,rel/0.03)
		out.head = at+fw*12.0*j*SNAP
		out.sy = 1.0+0.08*j
	return out

static func _major_neck(neck: Dictionary, pose: Dictionary, mem: Dictionary, clock: float) -> PackedVector2Array:
	var pts: PackedVector2Array = neck.points
	var last := pts.size()-1
	if last<1: return pts
	var d: Vector2 = Vector2(pose.head)-Vector2(neck.position)
	var bend := float(pose.get("bend",0.0))
	var coil := float(pose.coil)
	var side := _orth((pts[last]-pts[0]).normalized())
	var ph := float(neck.id)*3.0
	var out := PackedVector2Array()
	for i in pts.size():
		var u := float(i)/last
		var o := sin(u*PI)*(bend+sin(u*5.0-clock*3.0+ph)*bend*0.12) if bend>0.0 else 0.0
		if pose.get("lunge",false): o += sin(u*TAU)*sin(u*PI)*18.0*coil*COIL
		out.append(pts[i]+side*o+d*u*u)
	return out

## 技が終わった首：うねりが頭から根元へ走りながら戻る。回転ビームの首はなめらかに曲げを解く。
static func _recover(neck: Dictionary, mem: Dictionary, clock: float, copy: Dictionary) -> void:
	var pts: PackedVector2Array = neck.points
	var last := pts.size()-1
	if last<1: return
	if mem.has("curve"):
		var tau := clock-float(mem.idle_at)
		if tau>=0.55:
			mem.erase("curve")
			return
		var k := tau/0.55
		var e := k*k*(3.0-2.0*k)
		copy.facing = float(neck.facing)-float(mem.curve.tilt)*(1.0-e)
		var bend := float(mem.curve.bend)*(1.0-e)
		var side := _orth((pts[last]-pts[0]).normalized())
		var out := PackedVector2Array()
		for i in pts.size(): out.append(pts[i]+side*sin(float(i)/last*PI)*bend)
		copy.points = out
		return
	if not mem.get("wave",false): return
	var tau := clock-float(mem.idle_at)-float(mem.wave_delay)
	var length := float(mem.wave_time)
	if tau>length:
		mem.wave = false
		return
	if tau<=0.0: return
	var amp := 34.0*pow(1.0-tau/length,0.7)*_smooth(0.0,0.15,tau)
	var ph := float(mem.wave_phase)
	var side := _orth((pts[last]-pts[0]).normalized())
	var sign_value := float(mem.wave_side)
	var out := PackedVector2Array()
	for i in pts.size():
		var u := float(i)/last
		out.append(pts[i]+side*sin(u*7.5+tau*11.0+ph)*sin(u*PI)*amp*sign_value)
	copy.points = out

static func apply(body: Dictionary, memory: Dictionary) -> Dictionary:
	if not body.has("necks"): return body
	var shown := body.duplicate()
	var clock := float(body.clock)
	var necks: Array = []
	for neck: Dictionary in body.necks:
		var copy := neck.duplicate()
		necks.append(copy)
		var id := int(neck.id)
		if not memory.has(id): memory[id] = {"mode":"idle","idle_at":-9.0}
		var mem: Dictionary = memory[id]
		var mode: String = neck.get("mode","idle")
		if mode=="idle":
			if mem.mode!="idle":
				mem.idle_at = clock
				# 伸びていた首だけ、ずらした時間でうねりながら戻る。
				var i := necks.size()-1
				mem.wave = str(mem.mode) in LUNGES and Vector2(neck.position).distance_to(neck.base)>float(body.get("neck_rest",200.0))*1.3
				mem.wave_delay = i*0.14+_hash(i*3.3)*0.08
				mem.wave_time = 0.85+0.25*_hash(i*5.1)
				mem.wave_phase = _hash(i*7.7)*TAU
				mem.wave_side = -1.0 if _hash(i*2.9)<0.5 else 1.0
			mem.mode = mode
			_recover(neck,mem,clock,copy)
			continue
		mem.mode = mode
		if not neck.get("alive",false): continue
		if TYPES.has(mode):
			var pose := _normal(neck,mem,clock)
			copy.points = _normal_neck(neck,pose,clock)
			copy.position = pose.head
			copy.facing = pose.angle
			copy.sx = pose.sx
			copy.sy = pose.sy
			copy.pose = pose
		else:
			var pose := _major(neck,mem,clock)
			copy.points = _major_neck(neck,pose,mem,clock)
			copy.position = pose.head
			copy.facing = pose.angle
			copy.sx = pose.sx
			copy.sy = pose.sy
			copy.pose = pose
	shown.necks = necks
	return shown
