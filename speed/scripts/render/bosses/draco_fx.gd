## りゅうの技の光・闇・土ぼこり。戦闘の状態を読むだけで、論理画素の前後の層へ描く。
## 炎の部品は pixelFX fire/_lib.js の式（Sprite Fusion、MIT、Hugo Duprez）。
extends RefCounted
const PRIM := preload("res://scripts/render/fx/fx_reference_primitives.gd")
const BASE := Color("#ab9cff")
const EYE_FORWARD := 77.0
const EYE_SIDE := 25.0
const STONE := [Color("#1b2430"),Color("#2f3c4a"),Color("#4b5a68"),Color("#6f7f8d"),Color("#a3b0ba")]
const SPACE := [Color("#07040f"),Color("#140a26"),Color("#2a1650"),Color("#4b2c8a")]
const FLAME := [Color("#ffffff"),Color("#fbf4ff"),Color("#e6d8ff"),Color("#c9b0ff"),Color("#a884ff"),Color("#8259ee"),Color("#5f3cc8"),Color("#412a94"),Color("#291c62")]
const DARK := [Color("#f4e2ff"),Color("#d39bff"),Color("#9a4cf0"),Color("#6a24c4"),Color("#3e1484"),Color("#220b50"),Color("#110630"),Color("#070214")]
const LAYERS := [[1.0,1.0,6],[0.76,0.86,4],[0.54,0.68,2],[0.3,0.42,0]]

static func _hash(n: float) -> float:
	return PRIM.hash_value(n)
static func _smooth(a: float, b: float, x: float) -> float:
	return smoothstep(a,b,x) if a<b else 1.0-smoothstep(b,a,x)
static func _burst(x: float) -> float:
	return 1.0-pow(1.0-clampf(x,0.0,1.0),3.0)
static func _orth(v: Vector2) -> Vector2:
	return Vector2(-v.y,v.x)

## 1次元の滑らかな値ノイズ（-1〜1）。
static func _noise(x: float, seed: float) -> float:
	var i := floorf(x)
	var f := x-i
	var a := _hash(i*1.37+seed*7.1)
	var b := _hash((i+1.0)*1.37+seed*7.1)
	return lerpf(a,b,f*f*(3.0-2.0*f))*2.0-1.0
static func _n(time: float, rate: float, seed: float, offset := 0.0) -> float:
	return _noise(time*rate+offset,seed)

static func solid(p, x: float, y: float, r: float, c: Color) -> void:
	if r<0.6:
		p.px(x,y,c)
		return
	p.disc(x,y,r,c,1.0)
static func soft(p, x: float, y: float, r: float, c: Color, a: float) -> void:
	if a<=0.004: return
	if r<0.5:
		p.blend(x,y,c,a)
		return
	p.disc(x,y,r,c,a)

static func flame_blade(p, x: float, y: float, ux: float, uy: float, length: float, w: float, bend: float, time: float, n: float, H: Array, layers: Array = LAYERS, jit := 0.5, wob := 1.1) -> void:
	if length<1.0: return
	var nx := -uy
	var ny := ux
	for layer: Array in layers:
		var lw := float(layer[0])
		var lh := float(layer[1])
		var c: Color = H[int(layer[2])]
		var full := length*lh
		var r := 0.0
		while r<=full:
			var u := r/maxf(1.0,full)
			var half := w*lw*pow(1.0-u,0.85)*minf(1.0,(r+1.5)/3.5)+_n(time,9.0,n,r*0.45)*jit
			if half>=0.3:
				var off := bend*u*u*lh+_n(time,4.0,n+7.0,r*0.2)*u*wob
				var cx := x+ux*r+nx*off
				var cy := y+uy*r+ny*off
				var q := -half
				while q<=half:
					p.px(cx+nx*q,cy+ny*q,c)
					q += 0.5
			r += 0.5

static func fire_puff(p, x: float, y: float, k: float, size: float, frac: float, H: Array, glow_k := 0.18, tx := 0.0, ty := -1.0) -> void:
	var age := 1.0-k
	var n := H.size()
	var heat := minf(0.999,pow(age,0.62)+frac*0.1)
	var idx := mini(n-2,floori(heat*(n-1)))
	var r := size*(0.55+0.45*minf(1.0,age*7.0))*(1.0-age*0.55)
	var c: Color = H[idx]
	if idx>=n-2:
		soft(p,x,y,r,c,minf(1.0,k*3.0)*0.85)
		return
	solid(p,x,y,r,H[mini(n-1,idx+2)])
	if r>1.6 and ty>-0.99: solid(p,x+tx*r*1.5,y+ty*r*1.5,r*0.3,H[mini(n-1,idx+1)])
	solid(p,x-r*0.16,y-r*0.22,r*0.78,c)
	if r>1.6: solid(p,x+tx*r*0.9,y+ty*r*0.9,r*0.42,c)
	if idx<=3 and r>1.8: solid(p,x-r*0.28,y-r*0.34,r*0.36,H[maxi(0,idx-1)])
	if idx<6: p.glow(x,y,r*2.4+2.0,c,glow_k*k)

static func smoke_puff(p, x: float, y: float, k: float, size: float, col: Color, aMul := 1.0) -> void:
	var age := 1.0-k
	var r := size*(0.65+minf(1.0,age*2.5)*0.45+age*0.5)
	var a := minf(1.0,age*12.0)*minf(1.0,k*2.4)*0.7*aMul
	soft(p,x,y,r,col,a*0.45)
	soft(p,x+r*0.05,y+r*0.06,r*0.74,col,a*0.62)

## 部位から部位へ光を運ぶ。
static func supply(canvas, from: Vector2, to: Vector2, strength: float, time: float, seed := 1.0, bend := 0.0) -> void:
	if strength<=0.0: return
	var pal := PRIM.ramp(BASE)
	var n := _orth((to-from).normalized())
	var control := from.lerp(to,0.5)+n*bend
	for i in 9:
		if _hash(seed+i*13.0)>strength: continue
		var phase := fposmod(time*1.65+_hash(seed+i*17.0),1.0)
		var at := from.lerp(control,phase).lerp(control.lerp(to,phase),phase)
		var q: Vector2 = canvas.to_logical(at)
		canvas.front.glow(q.x,q.y,1.2+phase,pal[2],strength*(0.25+phase*0.6)*0.17)
		if phase>0.28: canvas.front.px(q.x,q.y,pal[3 if phase>0.82 else 1])

static func gather(canvas, at: Vector2, radius: float, charge: float, time: float, seed := 1.0, color := BASE) -> void:
	var a: Vector2 = canvas.to_logical(at)
	var pal := PRIM.ramp(color)
	var wl: float = canvas.world_scale
	for i in 28:
		var life := 0.4+_hash(i+seed)*0.55
		var phase := fposmod(time/life+_hash(i*9.0+seed),1.0)
		var q := a+Vector2.from_angle(_hash(i*19.0+seed)*TAU)*radius*wl*pow(1.0-phase,1.4)
		canvas.front.px(q.x,q.y,pal[3 if phase>0.6 else 1])
		canvas.front.light(q.x,q.y,pal[2],charge*phase*0.5)
	canvas.front.glow(a.x,a.y,radius*wl*0.6,pal[2],charge*0.32)

static func eyes(canvas, head: Vector2, facing: float, k: float, color: Color, time: float) -> void:
	if k<=0.0: return
	var forward := Vector2.from_angle(facing)
	var side_axis := _orth(forward)
	var blink := 0.72+0.28*sin(time*(14.0+26.0*k))
	var reach := 2.0+5.0*k
	for side: float in [-1.0,1.0]:
		var e: Vector2 = canvas.to_logical(head+forward*EYE_FORWARD+side_axis*side*EYE_SIDE)
		canvas.back.glow(e.x,e.y,4.0+7.0*k,color,(0.4+0.5*k)*blink)
		canvas.front.disc(e.x,e.y,1.0+0.8*k,color,1.0)
		if k>0.6: canvas.front.disc(e.x,e.y,0.5,Color.WHITE,1.0)
		var d := -reach
		while d<=reach:
			canvas.front.blend(e.x+side_axis.x*d,e.y+side_axis.y*d,color,pow(1.0-absf(d)/reach,2.0)*0.95*k*blink)
			d += 0.5

static func tremble(canvas, at: Vector2, radius: float, k: float, time: float, seed: float) -> void:
	var c: Vector2 = canvas.to_logical(at)
	var rr: float = radius*canvas.world_scale
	for i in 26:
		if _hash(seed+i*2.3)>0.3+0.7*k: continue
		var a := _hash(seed+i*3.1)*TAU
		var d := rr*sqrt(_hash(seed+i*7.7))
		canvas.back.px(c.x+cos(a)*d+sin(time*50.0+i)*k*0.8,c.y+sin(a)*d-k*1.5*_hash(i),STONE[4 if k>0.6 else 3])
	canvas.back.glow(c.x,c.y,rr*0.5,PRIM.ramp(BASE)[2],0.3*k)

static func star(canvas, c: Vector2, size: float, spin: float, a: float, pal: Array) -> void:
	if a<=0.02: return
	canvas.front.px(c.x,c.y,pal[4])
	for j in 4:
		var angle := spin+j*PI/2.0
		var reach := size*(0.7 if j%2 else 1.0)
		var d := 0.5
		while d<=reach:
			canvas.front.light(c.x+cos(angle)*d,c.y+sin(angle)*d,pal[4 if d<reach*0.4 else 3],a*(1.0-d/(reach+0.5)))
			d += 0.5
	canvas.front.glow(c.x,c.y,size*1.4,pal[2],0.35*a)

static func dust(canvas, at: Vector2, t: float, seed: float, direction: float, power: float) -> void:
	var life := 0.55
	if t<0.0 or t>life: return
	var c: Vector2 = canvas.to_logical(at)
	var k := t/life
	var wl: float = canvas.world_scale
	for i in 26:
		var angle := direction+(_hash(seed+i*3.7)-0.5)*2.6
		var distance := (60.0+110.0*_hash(seed+i*1.3))*power*0.18*(1.0-exp(-t/0.18))*wl
		var r := (1.2+2.6*_hash(seed+i*5.9))*(0.6+k)
		var q := c+Vector2.from_angle(angle)*distance
		var y := -r
		while y<=r:
			var x := -r
			while x<=r:
				if x*x+y*y<=r*r and _hash(seed+i*17.0+floorf(x)*3.0+floorf(y)*7.0)>=k*1.25:
					canvas.back.dot(q.x+x,q.y+y,STONE[3 if k<0.3 else 2],(1.0-k)*0.55)
				x += 1.0
			y += 1.0

## 地面の割れ目。seedごとに同じ形。結果は呼ぶ側が保持する。
static func cracks(seed: float, r: float) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed*1000.0)+1
	for i in 7:
		_crack(rng,out,0.0,0.0,i*TAU/7.0+rng.randf_range(-0.3,0.3),r*rng.randf_range(0.55,0.95),0)
	return out
static func _crack(rng: RandomNumberGenerator, out: Array, x: float, y: float, a: float, length: float, depth: int) -> void:
	var points := PackedVector2Array([Vector2(x,y)])
	var s := 0.0
	while s<length:
		a += rng.randf_range(-0.35,0.35)
		x += cos(a)*1.5
		y += sin(a)*1.5
		points.append(Vector2(x,y))
		if depth<2 and s>3.0 and rng.randf()<0.08:
			_crack(rng,out,x,y,a+(1.0 if rng.randf()<0.5 else -1.0)*rng.randf_range(0.5,1.1),(length-s)*rng.randf_range(0.3,0.6),depth+1)
		s += 1.5
	out.append(points)

static func impact(canvas, at: Vector2, age: float, radius: float, seed: float, crack_rows: Array) -> void:
	if age<0.0 or age>1.4: return
	var pal := PRIM.ramp(BASE)
	var c: Vector2 = canvas.to_logical(at)
	var rr: float = radius*canvas.world_scale
	var heat := pow(clampf(1.0-age/1.1,0.0,1.0),1.4)
	if heat>0.0:
		for row: PackedVector2Array in crack_rows:
			for i in row.size():
				var h := heat*(1.0-0.5*i/row.size())-_hash(row[i].x*7.1+row[i].y*3.3)*0.25
				canvas.back.px(c.x+row[i].x,c.y+row[i].y,pal[4] if h>0.6 else pal[3] if h>0.35 else pal[1] if h>0.12 else SPACE[1])
	if age<0.08:
		canvas.front.glow(c.x,c.y,rr*1.1,pal[3],(1.0-age/0.08)*0.8)
		canvas.front.glow(c.x,c.y,rr*0.35,pal[4],1.0-age/0.08)
	dust(canvas,at,age-0.03,seed,0.0,1.6)
	for i in 18:
		var life := 0.3+0.35*_hash(seed+i*3.7)
		if age>life: continue
		var a := _hash(seed+i*5.3)*TAU
		var d: float = (90.0+160.0*_hash(i*1.9))*0.14*(1.0-exp(-age/0.14))*canvas.world_scale+rr*0.3
		var k := age/life
		canvas.front.px(c.x+cos(a)*d,c.y+sin(a)*d,pal[3] if k<0.3 else STONE[4 if k<0.6 else 3])

## 炎に耐える隕石：当たっている間にひびが広がって熱を持ち、欠片がこぼれる。
static func rock_heat(canvas, at: Vector2, radius: float, k: float, burn: float, full: float, i: int, crack_rows: Array) -> void:
	var pal := PRIM.ramp(BASE)
	var c: Vector2 = canvas.to_logical(at)
	var rr: float = radius*canvas.world_scale
	for row: PackedVector2Array in crack_rows:
		var show := ceili(row.size()*k)
		for m in show:
			var h := k*(1.0-0.5*m/row.size())
			canvas.front.blend(c.x+row[m].x,c.y+row[m].y,pal[4 if h>0.6 else 3],minf(1.0,0.45+h*0.7))
	canvas.front.glow(c.x,c.y,rr*0.8,pal[2],0.3*k)
	for m in 16:
		var th := m/16.0
		if k<=th: continue
		var ph := (burn-th*full)/0.5
		if ph>=1.0: continue
		var a := _hash(m*3.7+i)*TAU
		var d := rr*(0.85+0.9*(1.0-exp(-ph*2.2)))
		var x := c.x+cos(a)*d
		var y := c.y+sin(a)*d
		canvas.front.blend(x,y,STONE[3 if m%2 else 4],1.0-ph)
		canvas.front.blend(x+1.0,y,STONE[3],(1.0-ph)*0.8)

## 予兆の細いひびと、裂ける先端の光。
static func rift_tells(canvas, tears: Array, tell: float, open_time: float, close_time: float, time: float) -> void:
	var pal := PRIM.ramp(BASE)
	var p = canvas.front
	for tear: Dictionary in tears:
		var age := float(tear.age)
		var A: Vector2 = canvas.to_logical(tear.from)
		var B: Vector2 = canvas.to_logical(tear.to)
		var length := A.distance_to(B)
		if length<1.0: continue
		var u := (B-A)/length
		var n := _orth(u)
		var seed := float(tear.seed)
		if age<0.0:
			var k := clampf(1.0+age/tell,0.0,1.0)
			if k<=0.0: continue
			var d := 0.0
			while d<length:
				var f := d/length
				if absf(f-0.5)*2.0<=0.25+0.75*k:
					var j := (_hash(seed*3.0+floorf(d/4.0))-0.5)*3.0*k*sin(PI*f)
					p.blend(A.x+u.x*d+n.x*j,A.y+u.y*d+n.y*j,pal[3 if k>0.7 else 2],(0.3+0.6*k)*(0.7+0.3*sin(time*40.0+d*0.3)))
				d += 0.5
			continue
		var hold := float(tear.hold)
		var close := smoothstep(0.0,1.0,(age-hold)/close_time)
		if age>=hold+close_time: continue
		var tip := _burst(age/open_time)*(1.0-close)
		if age<open_time+0.05 or (close>0.0 and close<1.0):
			var tx := A.x+u.x*length*tip
			var ty := A.y+u.y*length*tip
			p.glow(tx,ty,11.0,pal[3],0.9)
			p.disc(tx,ty,2.2,Color.WHITE,1.0)
			for m in 10:
				var a := _hash(m*3.3+seed+floorf(time*30.0))*TAU
				var d := 3.0+16.0*_hash(m*7.1+floorf(time*24.0))
				p.blend(tx+cos(a)*d,ty+sin(a)*d,pal[4],0.9)

static func dark_gather(canvas, mouth: Vector2, k: float, time: float) -> void:
	var p = canvas.front
	var c: Vector2 = canvas.to_logical(mouth)
	for i in 34:
		var ph := fposmod(time*(0.7+0.8*_hash(i))+_hash(i*3.1),1.0)
		var a := _hash(i*7.7)*TAU+(1.0-ph)*1.6
		var d := 46.0*pow(1.0-ph,1.4)+4.0
		var reach := 6.0+12.0*ph
		var m := 0.0
		while m<reach:
			p.blend(c.x+cos(a+m*0.04)*(d+m),c.y+sin(a+m*0.04)*(d+m),DARK[2 if ph>0.6 else 3],(1.0-m/reach)*ph*k)
			m += 0.5
	soft(p,c.x,c.y,3.0+11.0*k,DARK[3],0.35*k)
	solid(p,c.x,c.y,1.0+6.0*k,DARK[7])
	p.glow(c.x,c.y,8.0+12.0*k,DARK[2],0.5*k)

static func dark_muzzle(canvas, mouth: Vector2, facing: float, age: float) -> void:
	if age<0.0 or age>0.42: return
	var p = canvas.front
	var c: Vector2 = canvas.to_logical(mouth)
	var forward := Vector2.from_angle(facing)
	var k := 1.0-age/0.42
	for i in 4:
		var off := (i-1.5)*0.3
		flame_blade(p,c.x,c.y,cos(facing+off),sin(facing+off),(70.0-absf(off)*50.0)*k,11.0*k,_n(age,3.0,i)*3.0,age,70.0+i*13.0,DARK,LAYERS,0.5,1.4)
	for i in 12:
		var a := _hash(i*3.7)*TAU
		var d := (10.0+44.0*_hash(i*1.3))*(1.0-exp(-age/0.1))
		smoke_puff(p,c.x+cos(a)*d-forward.x*d*0.3,c.y+sin(a)*d-forward.y*d*0.3,k,8.0,DARK[5],0.9)
	p.glow(c.x,c.y,26.0,DARK[2],0.8*k)
	solid(p,c.x,c.y,7.0*k,DARK[0])

## 着弾点：闇の染みが広がってから縮む。
static func dark_fall(canvas, at: Vector2, age: float, warn: float, radius: float, time: float) -> void:
	var p = canvas.back
	var c: Vector2 = canvas.to_logical(at)
	var k := clampf(age/warn,0.0,1.0)
	var rr: float = radius*canvas.world_scale*lerpf(1.8,0.8,smoothstep(0.0,1.0,k))
	var on := smoothstep(0.0,0.14,age)
	var r_int := ceili(rr*1.3)
	for dy in range(-r_int,r_int+1):
		for dx in range(-r_int,r_int+1):
			var d := Vector2(dx,dy).length()/rr
			if d>1.3: continue
			var edge := 1.0+0.2*_noise(atan2(dy,dx)*2.0+7.0+time*2.4,17.0)
			var e := d/edge
			if e>1.06: continue
			if e>0.93: p.blend(c.x+dx,c.y+dy,DARK[2],0.9*on*(1.06-e)/0.13)
			else: p.blend(c.x+dx,c.y+dy,DARK[7 if e<0.6 else 6],(0.62+0.3*k)*on)

static func dark_blast(canvas, at: Vector2, age: float, radius: float, seed: float, H: Array = DARK) -> void:
	if age<0.0 or age>1.0: return
	var p = canvas.front
	var c: Vector2 = canvas.to_logical(at)
	var rr: float = radius*canvas.world_scale*1.3
	var flash := 1.0-smoothstep(0.0,0.14,age)
	if flash>0.0:
		p.glow(c.x,c.y,rr*2.0,H[2],0.6*flash)
		solid(p,c.x,c.y,rr*(0.15+0.22*smoothstep(0.0,0.1,age))*flash,H[0])
	for i in 46:
		var life := lerpf(0.35,0.75,_hash(i*5.3+2.1+seed))
		if age>life: continue
		var a := _hash(i*5.3+4.2+seed)*TAU
		var d := rr*lerpf(0.5,1.25,_hash(i*5.3+6.3+seed))*(1.0-exp(-age/0.13))
		fire_puff(p,c.x+cos(a)*d,c.y+sin(a)*d,1.0-age/life,minf(rr*lerpf(0.18,0.36,_hash(i*5.3+8.4+seed)),11.0),_hash(i*5.3+10.5+seed),H,0.06,cos(a)*0.7,sin(a)*0.7)
	for i in 14:
		var life := lerpf(0.6,1.0,_hash(i*9.1+3.7+seed))
		if age>life: continue
		var a := _hash(i*9.1+7.4+seed)*TAU
		var d := rr*1.2*(1.0-exp(-age/0.22))
		smoke_puff(p,c.x+cos(a)*d,c.y+sin(a)*d,1.0-age/life,rr*0.4,H[5],0.8)

static func star_charge(canvas, at: Vector2, i: int, k: float, time: float) -> void:
	if k<=0.0: return
	var p = canvas.front
	var c: Vector2 = canvas.to_logical(at)
	var rad := (1.5+3.5*k)*(1.0+0.08*sin(time*22.0+i))
	soft(p,c.x,c.y,rad*2.0,FLAME[6],0.3*k)
	solid(p,c.x,c.y,rad,FLAME[4])
	solid(p,c.x,c.y,rad*0.5,FLAME[1])
	p.glow(c.x,c.y,rad*2.2,FLAME[5],0.3*k)
	star(canvas,c,3.0+5.0*k,time*2.0+i,k*0.8,PRIM.ramp(BASE))

static func rush(canvas, points: PackedVector2Array, width: float, start: Vector2, axis: float, elapsed: float, active: float, form) -> void:
	var pal := PRIM.ramp(BASE)
	var k := 1.0-smoothstep(active*0.55,active,elapsed)
	var wind := 1.0-smoothstep(0.0,0.5,elapsed/active)
	dust(canvas,start,elapsed,61.0,axis+PI,1.3)
	var total: float = form.length(points)
	var half := width*0.5
	var step := 2.0/maxf(0.01,canvas.world_scale)
	for side: float in [-1.0,1.0]:
		for j in 2:
			var reach := minf(total,(240.0+130.0*j)*wind+60.0)
			var from := 60.0+j*90.0
			var s := from
			while s<from+reach:
				var at: Vector2 = form.sample(points,s/total)
				var ahead: Vector2 = form.sample(points,minf(1.0,(s+2.0)/total))
				var u := (s-from)/reach
				var q: Vector2 = canvas.to_logical(at+_orth((ahead-at).normalized())*side*(half*form.taper(s/total)+4.0+u*u*26.0))
				canvas.front.blend(q.x,q.y,pal[2 if j else 3],pow(sin(PI*u),0.8)*k*0.55)
				s += step

## 閉じる牙の形に空間が裂ける。裂け目はその場に残り、根元から閉じる。
static func bite_tear(canvas, at: Vector2, angle: float, t: float, width: float, recover: float, time: float) -> void:
	if t<0.0: return
	var pal := PRIM.ramp(BASE)
	var fw := Vector2.from_angle(angle)
	var sd := _orth(fw)
	var size := width*1.25
	var c := at+fw*size*0.3
	var snap := _burst(t/0.07)
	var close := smoothstep(0.16,recover*0.7,t)
	if close>=1.0: return
	for side: float in [-1.0,1.0]:
		for i in 4:
			var along := (i-1.5+side*0.22)*size*0.46
			var big := (1.0-absf(i-1.5)*0.2)*(0.78+0.4*_hash(i*3.1+side*2.0))
			var base := c+fw*along+sd*side*size*lerpf(1.5,0.82,snap)
			var tip := base-sd*side*size*1.02*big
			var A: Vector2 = canvas.to_logical(base)
			var B: Vector2 = canvas.to_logical(tip)
			var length := A.distance_to(B)
			if length<1.0: continue
			var u := (B-A)/length
			var n := _orth(u)
			var wide := 5.5*big
			var d := 0.0
			while d<=length:
				var f := d/length
				if f>=close:
					var jag := (_hash(i*7.0+side*3.0+floorf(d/2.0))-0.5)*1.4*f+f*f*wide*0.3*(1.0 if i<2 else -1.0)*side
					var w := wide*pow(1.0-f,0.8)*(1.0-close*0.7)
					var x := A.x+u.x*d+n.x*jag
					var y := A.y+u.y*d+n.y*jag
					var fade := 1.0-close
					var o := -w
					while o<=w:
						var e := absf(o)/maxf(0.5,w)
						canvas.front.blend(x+n.x*o,y+n.y*o,SPACE[1 if e<0.45 else 2 if e<0.8 else 3],0.95*fade)
						o += 0.5
					var rim: Color = pal[4 if t<0.14 else 3]
					canvas.front.blend(x+n.x*w,y+n.y*w,rim,0.8*fade)
					canvas.front.blend(x-n.x*w,y-n.y*w,rim,0.8*fade)
					if _hash(d*3.7+i*9.0+side)>0.86: star(canvas,Vector2(x,y),1.0,time*5.0+d,fade,pal)
				d += 0.5
	var k: Vector2 = canvas.to_logical(c)
	var flash := 1.0-smoothstep(0.05,0.16,t)
	if snap>=1.0 and flash>0.0: canvas.front.glow(k.x,k.y,size*canvas.world_scale*1.3,pal[3],0.75*flash)

## 尾が通った道に残る面。後ろの端はノイズで不揃いにほつれる。
static func sweep_wake(canvas, wake: Array, time: float) -> void:
	var life := 0.3
	var list: Array = []
	for q: Dictionary in wake:
		if time-float(q.t)<life: list.append(q)
	if list.size()<3: return
	var reach := PackedFloat32Array()
	var fine := PackedFloat32Array()
	for m in 96:
		var v := m/95.0
		reach.append(clampf(0.5+0.42*(1.0-v)+0.3*_noise(v*7.0,37.0)+0.08*_noise(v*26.0,19.0),0.0,1.0))
		fine.append(0.5+0.5*_noise(m/95.0*30.0,53.0))
	for i in range(1,list.size()):
		var q0: Dictionary = list[i-1]
		var q1: Dictionary = list[i]
		var f := (time-float(q1.t))/life
		var A0: Vector2 = canvas.to_logical(q0.a)
		var A1: Vector2 = canvas.to_logical(q1.a)
		var B0: Vector2 = canvas.to_logical(q0.b)
		var B1: Vector2 = canvas.to_logical(q1.b)
		var steps := ceili(maxf(A0.distance_to(A1),B0.distance_to(B1))+1.0)
		var span := ceili(A1.distance_to(B1)+1.0)
		for n in steps+1:
			var u := float(n)/steps
			var A := A0.lerp(A1,u)
			var B := B0.lerp(B1,u)
			var bend := sin(i*0.22+time*1.5)*0.02
			for m in span+1:
				var v := clampf(float(m)/span+bend,0.0,1.0)
				var slot := roundi(v*95.0)
				var k := f/reach[slot]
				if k>=1.0: continue
				var end := smoothstep(0.62,1.0,k)
				var thin := lerpf(1.0,fine[slot]*1.5,end)
				var heat := clampf(1.0-v*0.8-k*0.45,0.0,1.0)
				var level := lerpf(5.6,1.4,heat)
				var ci := mini(6,floori(level))
				var a := 0.82*(1.0-v*v*0.8)*(1.0-end)*minf(1.0,thin+(1.0-end))
				if a>0.02:
					var at := A.lerp(B,float(m)/span)
					canvas.back.blend(at.x,at.y,FLAME[ci].lerp(FLAME[ci+1],level-ci),a)
	var tip: Vector2 = canvas.to_logical(list[-1].a)
	canvas.front.glow(tip.x,tip.y,10.0,FLAME[3],0.5)

## 吸い込み：まわりの光の筋と星屑が、口へ向かって流れながら細く伸びる。
static func inhale(canvas, mouth: Vector2, pull_range: float, k: float, time: float) -> void:
	var pal := PRIM.ramp(BASE)
	var step := 2.0/maxf(0.01,canvas.world_scale)
	for i in 90:
		var ph := fposmod(_hash(i*17.0)+time*(0.45+0.6*_hash(i)),1.0)
		var an := _hash(i*31.0)*TAU+ph*2.6
		var head := mouth+Vector2.from_angle(an)*pull_range*0.6*pow(1.0-ph,1.3)
		var reach := 20.0+70.0*ph
		var s := 0.0
		while s<reach:
			var b := (1.0-s/reach)*ph*k
			if b>=0.06:
				var q: Vector2 = canvas.to_logical(head+Vector2.from_angle(an-0.9-(s/reach)*1.1)*s)
				canvas.back.blend(q.x,q.y,pal[3 if b>0.55 else 2],minf(0.7,b*0.85))
			s += step
		if i%9==0: star(canvas,canvas.to_logical(head),1.0+ph*2.0,time*4.0+i,k*ph,pal)
	var m: Vector2 = canvas.to_logical(mouth)
	canvas.front.glow(m.x,m.y,8.0,pal[3],0.5*k)

## 渦の待ち：光が尾から頭へ胴を満たしていき、頭に届いたら飛び出す。
static func spiral_countdown(canvas, points: PackedVector2Array, q: float, time: float) -> void:
	var pal := PRIM.ramp(BASE)
	var last := points.size()-1
	var cut := last*(1.0-q)
	for i in range(last,maxi(0,floori(cut))-1,-1):
		var c: Vector2 = canvas.to_logical(points[i])
		var edge := clampf(1.0-(i-cut)/6.0,0.0,1.0)
		canvas.front.glow(c.x,c.y,7.0+4.0*edge,pal[3 if edge>0.5 else 2],(0.38+0.5*edge)*(0.75+0.25*sin(time*9.0-i*0.5)))
		canvas.front.px(c.x,c.y,pal[4 if edge>0.3 else 3])
