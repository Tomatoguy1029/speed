## うみへびの技の光。戦闘の状態を読むだけで、論理画素の前後の層へ描く。
extends RefCounted
const PRIM := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const DRACO_FX := preload("res://scripts/render/bosses/draco_fx.gd")
const COLORS := {"bite":Color("#ff5470"),"vortex":Color("#5fe3c4"),"debris":Color("#a9bccd"),"beam":Color("#ff6fb4"),"thunder":Color("#7fb8ff"),"immortal":Color("#ffe69a")}
const JET := preload("res://scripts/render/enemies/aquarius_jet.gd")
const STONE := DRACO_FX.STONE
const STROKES := [[0.0,1.0],[0.13,0.8],[0.26,0.55]]
const FLICK := [1.0,0.72,0.3,0.95,0.5,0.8,0.22]

static func head_local(head: Vector2, angle: float, x: float, y: float, factor: float) -> Vector2:
	return head+Vector2(x*factor,y*factor).rotated(angle-PI*0.5)

## 噛みつき系の予兆の目：大きく強く光って点滅し、ためが深まると目から光の筋が横へ伸びる。
static func bite_eyes(canvas, head: Vector2, angle: float, k: float, color: Color, time: float, factor: float) -> void:
	var blink := 0.72+0.28*sin(time*(14.0+26.0*k))
	var reach := 2.0+7.0*k
	var side := Vector2.from_angle(angle+PI*0.5)
	for sx: float in [-8.5,8.5]:
		var e: Vector2 = canvas.to_logical(head_local(head,angle,sx,-9.5,factor))
		canvas.back.glow(e.x,e.y,5.0+11.0*k,color,(0.5+0.7*k)*blink)
		canvas.front.disc(e.x,e.y,1.6+k,color,1.0)
		if k>0.6: canvas.front.disc(e.x,e.y,0.6,Color.WHITE,1.0)
		var d := -reach
		while d<=reach:
			canvas.front.blend(e.x+side.x*d,e.y+side.y*d,color,pow(1.0-absf(d)/reach,2.0)*0.95*k*blink)
			d += 0.5

static func eyes(canvas, head: Vector2, angle: float, k: float, color: Color, factor: float) -> void:
	if k<=0.01: return
	var pal := PRIM.ramp(color)
	for sx: float in [-8.5,8.5]:
		var e: Vector2 = canvas.to_logical(head_local(head,angle,sx,-9.5,factor))
		canvas.front.glow(e.x,e.y,1.6+3.2*k,pal[3],0.22+0.55*k)
		if k>0.35: canvas.front.px(e.x,e.y,pal[4 if k>0.75 else 3])

static func beam(canvas, a: Vector2, b: Vector2, width: float, color: Color, time: float, from: float, to: float) -> void:
	var la: Vector2 = canvas.to_logical(a)
	PRIM.beam(canvas.front,la,canvas.to_logical(b),{"w":width*0.5*float(canvas.world_scale),"source":false,"color":color,"time":time,"from":from,"to":to,"taper":6.0,"alpha":1.0,"intensity":1.0})
	PRIM.flare(canvas.front,la,1.4,color,time,0.55*(1.0-from),4)

static func rail(canvas, a: Vector2, b: Vector2, k: float, color: Color, time: float, seed: float, front := true) -> void:
	PRIM.warn_rail(canvas.front if front else canvas.back,canvas.to_logical(a),canvas.to_logical(b),{"color":color,"k":k,"time":time,"seed":seed,"maxLv":2,"intensity":1.0})

## 噛む衝撃：上下の牙の鉤が口先へ寄り、閃光が前へ走る。
static func fangs(canvas, mouth: Vector2, angle: float, t: float, radius: float, seed: float, color: Color) -> void:
	if t<0.0 or t>0.5: return
	var pal := PRIM.ramp(color)
	var fw := Vector2.from_angle(angle)
	var sd := Vector2(-fw.y,fw.x)
	var p := clampf(t/0.06,0.0,1.0)
	var out := clampf((t-0.06)/0.2,0.0,1.0)
	for side: float in [-1.0,1.0]:
		var P0 := mouth+sd*side*radius*0.8+fw*0.1*radius
		var C := mouth+sd*side*radius*0.72+fw*0.72*radius
		var P1 := mouth+fw*0.92*radius+sd*side*radius*0.14
		var steps := ceili(radius*2.2*float(canvas.world_scale))
		for i in steps+1:
			var u := float(i)/steps
			if u>p or u<out: continue
			if out>0.3 and DRACO_FX._hash(i*7.0+side*3.0+seed+floorf(t*40.0))>(1.0-out)*1.6: continue
			var q: Vector2 = canvas.to_logical(P0.lerp(C,u).lerp(C.lerp(P1,u),u))
			var w := (0.4+1.6*pow(sin(PI*u),0.7))*(1.0-out*0.6)
			var o := -w
			while o<=w:
				var e := absf(o)/maxf(0.3,w)
				canvas.front.px(q.x+sd.x*o*side,q.y+sd.y*o*side,pal[4 if (p-u<0.25 or e<0.35) and out<0.5 else 3 if e<0.7 else 2])
				o += 0.5
	var hit: Vector2 = canvas.to_logical(mouth+fw*0.45*radius)
	if t>0.04:
		var fl := exp(-maxf(0.0,t-0.05)/0.07)
		for row: Array in [[fw,16.0],[-fw,5.0],[sd,8.0],[-sd,7.0]]:
			var reach: float = float(row[1])*fl
			var d := 0.0
			while d<=reach:
				canvas.front.light(hit.x+row[0].x*d,hit.y+row[0].y*d,pal[3],(1.0-d/(reach+0.01))*0.9)
				d += 0.5
		canvas.front.px(hit.x,hit.y,pal[4])

## 先回り落雷の着弾：太い稲妻が上から叩きつけられ、同じ通り道を3回打ち直して点滅する。pixelFX lightning/lightning-strike の作り。
static func bolt_strike(canvas, light, L: Vector2, rr: float, a: float, seed: int, C: Array[Color], src: Vector2) -> void:
	var rng = JET.Rng.new(seed*3+1)
	var side := 1.0 if (rng.next()<0.5) else -1.0
	var top := Vector2(L.x+rng.between(10.0,24.0)*side,-10.0)
	var main: Array = light.zigzag(rng,top,L,0.13,0.5)
	var f := floori(a*30.0+0.0001)
	if a<0.1:
		var flash = JET.Rng.new((f*31+seed)|1)
		light.ink(canvas.front,light.zigzag(flash,src,top+Vector2(flash.between(-30.0,30.0),0.0),0.22,0.2),0.8,C,1.0,true,0.35)
	var index := 0
	for stroke: Array in STROKES:
		var u := a-float(stroke[0])
		if u>=0.0:
			var slot := floori(u*30.0+0.0001)
			var level: float = FLICK[slot] if slot<FLICK.size() else 0.0
			if level>0.0: light.ink(canvas.front,main,level*float(stroke[1]),C,1.7,false,0.7)
		index += 1
	var burn := clampf(1.0-(a-0.15)/0.75,0.0,1.0)
	if burn>0.0:
		canvas.back.disc(L.x,L.y,rr*0.34,Color("#141020"),burn*0.6)
		canvas.back.disc(L.x,L.y,rr*0.16,C[5],pow(burn,2.5)*0.6)
	var k := a/0.42
	if k<1.0:
		var r0 := rr*(1.0-pow(1.0-k,3.0))
		var w := 2.4*(1.0-k)+0.6
		var steps := maxi(24,ceili(r0*6.0))
		for i in steps:
			var at := L+Vector2.from_angle(i*TAU/steps)*r0
			canvas.front.blend(at.x,at.y,Color.WHITE.lerp(C[5],k),(1.0-k)*0.95)
			if w>1.5: canvas.front.blend(at.x+cos(i*TAU/steps),at.y+sin(i*TAU/steps),C[5],(1.0-k)*0.5)
	for j in 18:
		var q = JET.Rng.new(seed*7+j+1)
		var life: float = q.between(0.25,0.5)
		if a>life: continue
		var an: float = q.between(0.0,TAU)
		var d: float = q.between(60.0,130.0)*a*(1.0-a/life*0.45)
		var tail := 3.5*(1.0-a/life)
		canvas.front.line(L.x+cos(an)*(d-tail),L.y+sin(an)*(d-tail),L.x+cos(an)*d,L.y+sin(an)*d,C[7 if a<0.15 else 5],1.0-a/life)
	if a<0.07:
		canvas.front.glow(L.x,L.y,rr*0.5,Color.WHITE,(1.0-a/0.07)*0.8)
		canvas.front.disc(L.x,L.y,4.0*(1.0-a/0.07)+1.0,Color.WHITE,1.0)
	if a<0.6: canvas.back.glow(L.x,L.y,rr*0.8,C[3],0.42*exp(-a*5.0)*(0.7 if f%2 else 1.0))

## ためるとき、首の瓦礫がきしんで小石と粉がこぼれる。
static func grit(canvas, pts: PackedVector2Array, age: float, warn: float) -> void:
	var last := pts.size()-1
	if last<4: return
	for j in 26:
		var born := warn*(0.1+0.75*DRACO_FX._hash(j*3.1+2.0))
		var a := age-born
		var life := 0.45+0.4*DRACO_FX._hash(j*5.7)
		if a<0.0 or a>life: continue
		var at := pts[2+floori(DRACO_FX._hash(j*7.3)*(last-3))]
		var an := DRACO_FX._hash(j*1.9)*TAU
		var d := (18.0+40.0*DRACO_FX._hash(j*4.4))*life*0.4*(1.0-exp(-a/(life*0.4)))
		var fade := 1.0-a/life
		if DRACO_FX._hash(j*13.0+floorf(a*30.0))>fade*1.6: continue
		var q: Vector2 = canvas.to_logical(at+Vector2.from_angle(an)*(14.0+d))
		canvas.front.px(q.x,q.y,STONE[3 if fade>0.5 else 2])
		if DRACO_FX._hash(j)>0.6: canvas.back.dot(q.x+1.0,q.y,STONE[1],fade*0.6)

## 突き噛みの空気の筋：頭の両脇からはがれて後ろへ残る。
static func air(canvas, from: Vector2, to: Vector2, rel: float, active: float, color: Color) -> void:
	var length := from.distance_to(to)
	if length<1.0: return
	var pal := PRIM.ramp(color)
	var d := (to-from)/length
	var sd := Vector2(-d.y,d.x)
	var speed := length/maxf(0.01,active)
	var head := minf(length,rel*speed)
	var step := 1.0/maxf(0.01,float(canvas.world_scale))
	for side: float in [-1.0,1.0]:
		for j in 2:
			var id := side*7.0+j*3.0
			var life := 0.05+0.07*DRACO_FX._hash(id+4.0)
			var base := 22.0+9.0*j+6.0*DRACO_FX._hash(id)
			var s := 0.0
			while s<head:
				var age := (head-s)/speed+maxf(0.0,rel-active)
				var k := age/life
				if k<1.0:
					var q: Vector2 = canvas.to_logical(from+d*s+sd*side*(base+age*160.0+sin(s*0.045+id)*3.0))
					canvas.front.dot(q.x,q.y,pal[3 if k<0.3 else 2],(1.0-k)*0.75)
				s += step

## 薙ぎ払い：頭の通った弧に、先が白く後ろへ冷えて細る三日月の帯。後ろから虫食いで消える。
static func sweep_trail(canvas, neck: Dictionary, rel: float, fire_angle: float, present, radius: float, color: Color) -> void:
	var pal := PRIM.ramp(color)
	var active := float(neck.active_time)
	var max_age := 0.34
	var half := radius*0.55*float(canvas.world_scale)
	var dt := 1.0/150.0
	var o := -half
	while o<=half:
		var e := absf(o)/half
		var lane := roundf(o/1.5)
		var life := max_age*(1.0-pow(e,1.6))*(0.5+0.5*DRACO_FX._hash(lane*3.7+1.0))
		if life>0.01:
			var age := maxf(0.0,rel-active)
			while age<=life:
				var q := rel-age
				if q<0.0: break
				var A: Vector2 = canvas.to_logical(present.sweep_visual(neck,q,fire_angle).pos)
				var B: Vector2 = canvas.to_logical(present.sweep_visual(neck,maxf(0.0,q-dt),fire_angle).pos)
				var tangent := (A-B).normalized()
				var n := Vector2(-tangent.y,tangent.x)
				var k := age/life
				var x := A.x+n.x*o
				var y := A.y+n.y*o
				age += dt
				if k>0.55 and DRACO_FX._hash(lane*11.0+floorf(q*300.0)*5.0)>(1.0-k)*2.2: continue
				var speed := A.distance_to(B)/dt/float(canvas.world_scale)
				var al := (1.0-k)*(1.0-e*0.7)*smoothstep(200.0,900.0,speed)
				if al<0.03: continue
				var level := 4 if k<0.12 and e<0.35 else 3 if k<0.4 else 2
				if al>0.6 and e<0.25: canvas.front.px(x,y,pal[level])
				elif al*(1.0-e)>0.18: canvas.front.dot(x,y,pal[maxi(1,level-1)],al*(1.0-e)*0.9)
				canvas.front.light(x,y,pal[2],al*(1.0-e)*0.1)
		o += 1.5
	var base: Vector2 = neck.base
	var sweep := float(neck.sweep)
	var arc := float(neck.sweep_arc)
	var reach := float(neck.sweep_reach)
	for i in 30:
		var born := active*DRACO_FX._hash(i*2.3+5.0)
		var a := rel-born
		var life := 0.35+0.3*DRACO_FX._hash(i*4.1)
		if a<0.0 or a>life: continue
		var an := sweep+arc*(born/active-0.5)
		var u := Vector2.from_angle(an)
		var at := base+u*(reach+(DRACO_FX._hash(i*6.7)-0.3)*radius)
		var v := (Vector2(-u.y,u.x)+u*(0.4+0.5*DRACO_FX._hash(i))).normalized()
		var k := a/life
		if DRACO_FX._hash(i*19.0+floorf(a*25.0))>(1.0-k)*1.8: continue
		var q: Vector2 = canvas.to_logical(at+v*(160.0+260.0*DRACO_FX._hash(i*8.1))*0.12*(1.0-exp(-a/0.12)))
		canvas.front.px(q.x,q.y,STONE[4 if k<0.4 else 3])

## 伸びる間：頭の形の光が通り道に残る。
static func silhouette(canvas, mask: Dictionary, center: Vector2, angle: float, color: Color, a: float, factor: float, seed: float) -> void:
	var wl: float = canvas.world_scale
	var c: Vector2 = canvas.to_logical(center)
	var w: int = mask.w
	var h: int = mask.h
	var data: PackedByteArray = mask.m
	var r := ceili(maxi(w,h)*factor*wl*0.75)
	for y in range(-r,r+1):
		for x in range(-r,r+1):
			var l := Vector2(x/wl,y/wl).rotated(-(angle-PI*0.5))
			var ix := floori(l.x/factor+w*0.5)
			var iy := floori(l.y/factor+h*0.5)
			if ix<0 or iy<0 or ix>=w or iy>=h or data[iy*w+ix]==0: continue
			if DRACO_FX._hash(seed+x*7.0+y*13.0)>a*1.6: continue
			canvas.front.light(c.x+x,c.y+y,color,a)

## 渦の予兆：前から空気の筋が口へ吸い込まれる（風の帯）／口のまわりを渦を巻いて縮む（風刃）。
static func wind_inhale(canvas, mouth: Vector2, angle: float, u: float, age: float, band: bool, color: Color) -> void:
	var pal := PRIM.ramp(color)
	if band:
		var step := 1.2/maxf(0.01,float(canvas.world_scale))
		for i in 36:
			var h := DRACO_FX._hash(i*3.3+1.0)
			var ph := fposmod(age*(1.4+h)+DRACO_FX._hash(i*7.1),1.0)
			var an := angle+(DRACO_FX._hash(i*5.5)-0.5)*1.1
			var s := (70.0+260.0*DRACO_FX._hash(i*2.9))*pow(1.0-ph,1.6)
			var reach := 10.0+16.0*(1.0-ph)
			var d := 0.0
			while d<=reach:
				var k := (1.0-d/reach)*u*smoothstep(0.0,0.25,ph)
				if k>0.05:
					var q: Vector2 = canvas.to_logical(mouth+Vector2.from_angle(an)*(s+d))
					canvas.front.dot(q.x,q.y,pal[3 if k>0.6 else 2],k*0.8)
				d += step
		return
	for i in 28:
		var h := DRACO_FX._hash(i*4.7+2.0)
		var ph := fposmod(age*(1.1+h*0.8)+h,1.0)
		var rad := (26.0+46.0*DRACO_FX._hash(i*9.1))*(1.0-ph*0.85)
		var an := DRACO_FX._hash(i*1.7)*TAU+age*(7.0+4.0*h)
		for j in 5:
			var k := u*(1.0-j/5.0)*sin(PI*ph)
			if k>0.05:
				var q: Vector2 = canvas.to_logical(mouth+Vector2.from_angle(an-j*0.09)*(rad+j*1.5))
				canvas.front.dot(q.x,q.y,pal[3 if j==0 and k>0.5 else 2],k)

## 瓦礫の首：首の瓦礫が口へ送られ、口先で砕ける。
static func rubble_warn(canvas, pts: PackedVector2Array, mouth: Vector2, u: float, age: float, lump: bool) -> void:
	var last := pts.size()-1
	if last<2: return
	for j in 9:
		var ph := fposmod(age*1.6+DRACO_FX._hash(j*3.1),1.0)
		var f := ph*last
		var i := mini(last-1,floori(f))
		var along := (pts[i+1]-pts[i]).normalized()
		var q: Vector2 = canvas.to_logical(pts[i].lerp(pts[i+1],f-i)+Vector2(-along.y,along.x)*(DRACO_FX._hash(j)-0.5)*18.0)
		canvas.front.px(q.x,q.y,STONE[4])
		canvas.front.px(q.x+1.0,q.y,STONE[3])
	var m: Vector2 = canvas.to_logical(mouth)
	var rr := 1.0+3.0*u if lump else 2.5
	for k in (24 if lump else 16):
		var an := DRACO_FX._hash(k*2.3)*TAU+age*(2.0 if lump else 9.0)*(DRACO_FX._hash(k)-0.5)
		var d := rr*sqrt(DRACO_FX._hash(k*5.9))
		canvas.front.px(m.x+cos(an)*d+sin(age*60.0+k)*0.6*u,m.y+sin(an)*d,STONE[2 if d>rr*0.6 else 3])

## 吐いた瞬間：口から土煙と砂利の扇。
static func spit_burst(canvas, mouth: Vector2, angle: float, t: float, fan: bool, spread: float) -> void:
	DRACO_FX.dust(canvas,mouth,t,91.0,angle,1.3 if fan else 0.9)
	for i in (26 if fan else 14):
		var life := 0.3+0.3*DRACO_FX._hash(i*3.7)
		if t>life: continue
		var an := angle+(DRACO_FX._hash(i*5.3)-0.5)*2.0*spread
		var k := t/life
		if DRACO_FX._hash(i*11.0+floorf(t*30.0))>(1.0-k)*1.8: continue
		var q: Vector2 = canvas.to_logical(mouth+Vector2.from_angle(an)*(300.0+400.0*DRACO_FX._hash(i*1.9))*0.12*(1.0-exp(-t/0.12)))
		canvas.front.px(q.x,q.y,STONE[4 if k<0.4 else 3])

## 頭のまわりの短い放電。
static func crackle(canvas, light, at: Vector2, rad: float, k: float, time: float, seed: int, C: Array[Color]) -> void:
	var f := floori(time/0.06)
	var c: Vector2 = canvas.to_logical(at)
	var rr: float = rad*canvas.world_scale
	for i in roundi(1.0+4.0*k):
		var rng = JET.Rng.new((seed*97+f*13+i*7)|1)
		var a0: float = rng.between(0.0,TAU)
		var a1: float = a0+rng.between(0.6,1.6)
		var r0: float = rr*rng.between(0.5,1.0)
		var r1: float = rr*rng.between(0.5,1.1)
		light.ink(canvas.front,light.zigzag(rng,c+Vector2.from_angle(a0)*r0,c+Vector2.from_angle(a1)*r1,0.35,0.15),k*rng.between(0.5,1.0),C,1.0,true,0.3)

## 帯電頭突きの予兆：目が雷の色に変わって光り、目から細い放電が走って目から目へ飛ぶ。
static func eye_charge(canvas, light, head: Vector2, angle: float, k: float, time: float, windup: bool, factor: float, C: Array[Color]) -> void:
	var f := floori(time/0.06)
	var eyes: Array[Vector2] = []
	for sx: float in [-8.5,8.5]: eyes.append(canvas.to_logical(head_local(head,angle,sx,-9.5,factor)))
	var back := angle+PI
	for i in 2:
		var e := eyes[i]
		canvas.front.glow(e.x,e.y,3.0+5.0*k,C[4],0.35+0.5*k)
		canvas.front.disc(e.x,e.y,1.4+0.5*k,C[7 if k>0.6 else 6],1.0)
		canvas.front.glow(e.x,e.y,1.6+1.6*k,C[6],0.6*k)
		if not windup: continue
		for j in 1+roundi(3.0*k):
			var rng = JET.Rng.new((f*17+i*29+j*7+3)|1)
			var an: float = back+(1.0 if i else -1.0)*rng.between(0.35,1.9)
			var reach: float = rng.between(5.0,12.0)*(0.6+0.8*k)
			light.ink(canvas.front,light.zigzag(rng,e,e+Vector2.from_angle(an)*reach,0.4,0.3),k*rng.between(0.6,1.0),C,1.0,true,0.3)
	if windup and k>0.45:
		var rng = JET.Rng.new((f*41+5)|1)
		if (rng.next()<0.75): light.ink(canvas.front,light.zigzag(rng,eyes[0],eyes[1],0.5,0.1),k,C,1.0,true,0.25)

## 先回り落雷の予兆：着弾点の放電が増え、頭から細い放電が伸びかける。
static func drop_warn(canvas, light, mouth: Vector2, target: Vector2, rr: float, k: float, time: float, C: Array[Color]) -> void:
	var L: Vector2 = canvas.to_logical(target)
	var M: Vector2 = canvas.to_logical(mouth)
	light.static_bolts(canvas.back,L,rr,roundi(3.0+7.0*k),rr*(0.2+0.25*k),time,23,C,0.45+0.5*k)
	canvas.back.glow(L.x,L.y,6.0+10.0*k,C[5],0.2+0.6*k)
	var f := floori(time/0.12)
	if DRACO_FX._hash(f*3.1)<k:
		var rng = JET.Rng.new(f*11+5)
		var mid: Vector2 = M.lerp(L,rng.between(0.25,0.55))+Vector2(rng.between(-6.0,6.0),rng.between(-6.0,6.0))
		light.ink(canvas.front,light.zigzag(rng,M,mid,0.4,0.2),0.6*k,C,1.0,true,0.3)

## 帯電頭突きの命中：当たった点が細かい放電の塊になり、火花がジグザグに跳ね、光が点滅して消える。
static func zap(canvas, light, L: Vector2, rr: float, a: float, direction: float, C: Array[Color]) -> void:
	var f := floori(a*30.0+0.0001)
	if a<0.4:
		var u := a/0.4
		var r0 := rr*0.32*(1.0-u*0.6)
		var rng = JET.Rng.new((f*53+7)|1)
		for i in roundi(11.0*(1.0-u*0.5)):
			var an: float = rng.between(0.0,TAU)
			var d0: float = rng.between(0.5,r0*0.5)
			var an2: float = an+rng.between(-1.2,1.2)
			var d1: float = rng.between(r0*0.55,r0)
			light.ink(canvas.front,light.zigzag(rng,L+Vector2.from_angle(an)*d0,L+Vector2.from_angle(an2)*d1,0.5,0.0),0.75*(1.0-u)+0.25,C,1.0,true,0.2)
		canvas.front.disc(L.x,L.y,3.0*(1.0-u)+1.0,C[5],1.0)
		canvas.front.disc(L.x,L.y,2.0*(1.0-u)+0.5,Color.WHITE,1.0)
		canvas.front.glow(L.x,L.y,rr*0.5,C[4],0.5*(1.0-u))
	for j in 14:
		var rng = JET.Rng.new(j*19+11)
		var life: float = rng.between(0.2,0.38)
		if a>=life: continue
		var at := Vector2.ZERO
		var an: float = direction+rng.between(-1.3,1.3)+(0.0 if (rng.next()<0.75) else PI)
		var speed: float = rng.between(45.0,80.0)
		var t := 0.0
		while t<a:
			var dt: float = minf(a-t,rng.between(0.025,0.055))
			at += Vector2.from_angle(an)*speed*dt
			speed *= 1.0-3.0*dt
			t += dt
			an += (1.0 if (rng.next()<0.5) else -1.0)*rng.between(0.6,1.3)
		var k: float = 1.0-a/life
		canvas.front.px(L.x+at.x,L.y+at.y,Color.WHITE if k>0.4 else C[5])
		canvas.front.glow(L.x+at.x,L.y+at.y,3.0,C[5],0.35*k)
	if a<0.85: canvas.back.glow(L.x,L.y,rr*0.95*(1.0-a/0.85),C[3],0.45*exp(-a*5.0)*(0.7 if f%2 else 1.0))

## 着地点の予告：牙の形の光が小さくちらつき、狙いが決まると止まって強まる。
static func mark(canvas, at: Vector2, direction: float, k: float, locked: bool, radius: float, color: Color, seed: float, time: float) -> void:
	var pal := PRIM.ramp(color)
	var fw := Vector2.from_angle(direction)
	var sd := Vector2(-fw.y,fw.x)
	var rr := radius*0.8
	var jit := 0.0 if locked else 1.0
	for side: float in [-1.0,1.0]:
		var P0 := at+sd*side*rr
		var P1 := at+fw*rr*0.7
		var steps := ceili(rr*1.6*float(canvas.world_scale))
		for i in steps+1:
			if DRACO_FX._hash(i*3.0+seed+floorf(time*12.0))>0.55+0.45*k: continue
			var u := float(i)/steps
			var q: Vector2 = canvas.to_logical(P0.lerp(P1,u)+sd*side*sin(u*PI)*rr*0.25+Vector2((DRACO_FX._hash(i+seed+floorf(time*20.0))-0.5)*6.0*jit,0.0))
			canvas.back.dot(q.x,q.y,pal[3 if locked else 2],0.25+0.55*k)
	var c: Vector2 = canvas.to_logical(at)
	canvas.back.glow(c.x,c.y,6.0,pal[2],0.2*k)

## 竜巻の走った跡：通った所に土ぼこりが残り、ふくらんで薄れる。
static func tornado_wake(canvas, center: Vector2, direction: Vector2, speed: float, width: float, a: float, fade: float) -> void:
	var dust_colors := [Color("#9a8f86"),Color("#7a7068")]
	var side := Vector2(-direction.y,direction.x)
	for i in range(maxi(0,floori((a-0.55)*40.0)),floori(a*40.0)+1):
		var born := i/40.0
		var life := lerpf(0.3,0.55,DRACO_FX._hash(i*6.1+2.9+17.0))
		var k := 1.0-(a-born)/life
		if k<=0.0: continue
		var q: Vector2 = canvas.to_logical(center+direction*speed*(born-a)+side*(DRACO_FX._hash(i*6.1+5.8+17.0)-0.5)*width*0.8)
		var rr := lerpf(2.0,3.6,DRACO_FX._hash(i*6.1+11.6+17.0))*(0.8+(1.0-k)*1.6)
		canvas.back.disc(q.x,q.y,rr,dust_colors[0 if DRACO_FX._hash(i*6.1+14.5+17.0)<0.5 else 1],pow(k,1.3)*0.4*fade)

## 風の首の口元で風が集まる：まわりの空気が巻きながら渦へ吸い込まれる筋。
static func tornado_gather(canvas, center: Vector2, radius: float, k: float, time: float) -> void:
	var L: Vector2 = canvas.to_logical(center)
	var rr: float = radius*canvas.world_scale
	var colors := [Color("#a6f0a0"),Color("#dcffd6")]
	for i in roundi(6.0+16.0*k):
		var h := DRACO_FX._hash(i*4.7+2.0)
		var ph := fposmod(time*(0.9+1.1*k+0.5*h)+DRACO_FX._hash(i*9.1),1.0)
		var an0 := DRACO_FX._hash(i*1.7)*TAU
		var r0 := rr+14.0+22.0*DRACO_FX._hash(i*3.3)
		var length := 10.0+8.0*h
		var m := 0.0
		while m<length:
			var u := m/length
			var ph2 := maxf(0.0,ph-u*0.1)
			var f := (1.0-u)*sin(PI*ph)*(0.35+0.65*k)
			if f>0.04:
				var r := lerpf(r0,rr*0.5,pow(ph2,1.5))
				var an := an0-2.2*pow(ph2,1.5)
				canvas.back.blend(L.x+cos(an)*r,L.y+sin(an)*r,colors[1 if u<0.3 else 0],f*0.8)
			m += 1.0
