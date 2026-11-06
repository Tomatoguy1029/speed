## うみへびの技の光。戦闘の状態を読むだけで、論理画素の前後の層へ描く。
extends RefCounted
const PRIM := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const DRACO_FX := preload("res://scripts/render/bosses/draco_fx.gd")
const COLORS := {"bite":Color("#ff5470"),"vortex":Color("#5fe3c4"),"debris":Color("#a9bccd"),"beam":Color("#ff6fb4"),"thunder":Color("#7fb8ff"),"immortal":Color("#ffe69a")}
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
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*3+1
	var side := 1.0 if rng.randf()<0.5 else -1.0
	var top := Vector2(L.x+rng.randf_range(10.0,24.0)*side,-10.0)
	var main: Array = light.zigzag(rng,top,L,0.13,0.5)
	var f := floori(a*30.0+0.0001)
	if a<0.1:
		var flash := RandomNumberGenerator.new()
		flash.seed = (f*31+seed)|1
		light.ink(canvas.front,light.zigzag(flash,src,top+Vector2(flash.randf_range(-30.0,30.0),0.0),0.22,0.2),0.8,C,1.0,true,0.35)
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
		var q := RandomNumberGenerator.new()
		q.seed = seed*7+j+1
		var life := q.randf_range(0.25,0.5)
		if a>life: continue
		var an := q.randf_range(0.0,TAU)
		var d := q.randf_range(60.0,130.0)*a*(1.0-a/life*0.45)
		var tail := 3.5*(1.0-a/life)
		canvas.front.line(L.x+cos(an)*(d-tail),L.y+sin(an)*(d-tail),L.x+cos(an)*d,L.y+sin(an)*d,C[7 if a<0.15 else 5],1.0-a/life)
	if a<0.07:
		canvas.front.glow(L.x,L.y,rr*0.5,Color.WHITE,(1.0-a/0.07)*0.8)
		canvas.front.disc(L.x,L.y,4.0*(1.0-a/0.07)+1.0,Color.WHITE,1.0)
	if a<0.6: canvas.back.glow(L.x,L.y,rr*0.8,C[3],0.42*exp(-a*5.0)*(0.7 if f%2 else 1.0))
