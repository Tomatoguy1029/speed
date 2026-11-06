## りゅう座の決着の演出。戦闘の状態を読むだけで、承認済みの試作と同じ式を座標系ごと写す。
## 座標は決着の中心を原点とする。時間は各段階の開始からの秒数。
extends Node2D
const RUSH: DracoFinaleRush = preload("res://data/bosses/draco_finale_rush.tres")
const PUFF := preload("res://assets/effects/build/draco_finale_puff.png")
const SHIP := preload("res://assets/pixel/airship.png")
const FLAME := preload("res://assets/pixel/airship_blue_flame.png")
const MODULE := preload("res://scripts/ui/legendary_module_geometry.gd")
const MODULES := ["legendary_stern","legendary_keel","legendary_sail","legendary_compass"]
const DEBRIS_PARTS := ["body_a","body_b","body_c","body_d","body_e","tail_joint","claw","arm"]
const WARM := [Color("#ffffff"),Color("#ffe6bd"),Color("#ffc27a"),Color("#ff9d52"),Color("#a9c8ff"),Color("#7fb0ff"),Color("#ffffff"),Color("#d9c2ff")]
const GOLD := Color("#ffc24d")
const GOLD_LIGHT := Color("#ffd777")
const GOLD_PALE := Color("#fff4cf")
const SHIP_LOW := Vector2(0,385)
const RAIL_TRAIL := 0.55
const DEPTH := 1100.0
const DOCK_FIRST := 0.9
const DOCK_STEP := 0.42
const UNLOCK_AT := 2.6
## 枠の色。黒い竜の影へ薄れていく色。
const GRAY_TONE := Color(0.62,0.67,0.75)
const SHADOW_TONE := Color(0.02,0.04,0.09)
var f := {}
var stage := ""
var t := 0.0
var clock := 0.0
var zoom := 1.0
var view_rect := Rect2()
var times := {}
var _grade: Node2D
var _dim: Node2D
var _fx: Node2D
var _top: Node2D
var _soft: Texture2D
var _textures := {}
var _puffs: Array[Rect2] = []
var _sparks: Array[Dictionary] = []
var _streaks: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _wisps: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _rubble: Array[Dictionary] = []
var _glitter: Array = []
var _charge: Array[Dictionary] = []
var _shake_hook: Callable

func _ready() -> void:
	_grade = _canvas(CanvasItemMaterial.BLEND_MODE_MUL,_draw_grade)
	_dim = _canvas(CanvasItemMaterial.BLEND_MODE_MIX,_draw_dim)
	_fx = _canvas(CanvasItemMaterial.BLEND_MODE_ADD,_draw_fx)
	_top = _canvas(CanvasItemMaterial.BLEND_MODE_MIX,_draw_top)
	_top.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.18,0.5,1.0])
	gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0.67),Color(1,1,1,0.15),Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1.0,0.5)
	_soft = texture
	for j in 4: _puffs.append(Rect2(j*96,0,96,96))
	for part: String in DEBRIS_PARTS+["head","tail_tip"]: _textures[part] = load("res://assets/pixel/draco/%s.png" % part)
	_build_particles()
	visible = false

func _canvas(mode: int, painter: Callable) -> Node2D:
	var node := Node2D.new()
	var material_ := CanvasItemMaterial.new()
	material_.blend_mode = mode
	node.material = material_
	node.draw.connect(painter)
	add_child(node)
	return node

func _random(seed_value: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random

func _build_particles() -> void:
	var r := _random(99)
	for j in 300:
		_charge.append({"a":r.randf()*TAU,"r":110.0+r.randf()*430.0,"ts":0.55*pow(r.randf(),1.5),"life":0.3+r.randf()*0.15,"turn":(-1.0 if r.randf()<0.5 else 1.0)*(1.8+r.randf()*1.8),"color":[GOLD_PALE,GOLD_LIGHT,GOLD,Color("#ffe9a8")][r.randi()%4],"w":0.9+r.randf()*1.3})
	for j in 1500:
		var a := r.randf()*TAU
		var speed := 120.0+r.randf()*r.randf()*2300.0
		_sparks.append({"at":Vector2((r.randf()-0.5)*90.0,(r.randf()-0.5)*560.0),"v":Vector2.from_angle(a)*speed,"drag":0.7+r.randf()*1.2,"life":2.0+r.randf()*4.6,"color":WARM[r.randi()%8],"tw":r.randf()*TAU,"delay":r.randf()*0.4})
	for j in 900:
		var flat := r.randf()<0.3
		var a := (0.0 if r.randf()<0.5 else PI)+(r.randf()-0.5)*0.28 if flat else r.randf()*TAU
		_streaks.append({"dir":Vector2.from_angle(a),"speed":700.0+r.randf()*r.randf()*4800.0,"y":(r.randf()-0.5)*168.0,"drag":0.55+r.randf()*0.8,"life":0.7+r.randf()*2.2,"delay":r.randf()*r.randf()*1.5,"color":WARM[r.randi()%8],"shutter":0.05+r.randf()*0.09})
	for j in 150:
		var a := r.randf()*TAU
		_clouds.append({"puff":r.randi()%4,"color":[Color("#ff8c3c"),Color("#ff8c3c"),Color("#ffcd78"),Color("#ffcd78"),Color("#46beff"),Color("#d2dcff"),Color("#7846ff"),Color("#ff5abe")][r.randi()%8],"at":Vector2((r.randf()-0.5)*260.0,(r.randf()-0.5)*620.0),"v":Vector2(cos(a)*(120.0+r.randf()*760.0),sin(a)*(90.0+r.randf()*620.0)),"size":460.0+r.randf()*1300.0,"rot":r.randf()*TAU,"spin":(r.randf()-0.5)*0.5,"life":3.0+r.randf()*4.4,"delay":r.randf()*0.7})
	for j in 7:
		var angle := r.randf()*TAU
		var points := PackedVector2Array()
		var radius := 70.0
		var turn := 0.0
		var reach := 620.0+r.randf()*680.0
		while radius<reach:
			turn = turn*0.82+(r.randf()-0.5)*0.07
			angle += turn
			radius += 14.0
			points.append(Vector2.from_angle(angle)*radius)
		_wisps.append({"points":points,"delay":0.15+r.randf()*0.7,"life":2.2+r.randf()*1.8})
	var cut_count := RUSH.cuts.size()/2
	for j in 70:
		var row := (j%cut_count)*2
		var side := -1.0 if j%2==0 else 1.0
		var y := RUSH.cuts[row]+(r.randf()-0.5)*RUSH.cuts[row+1]*1.6
		_rubble.append({"part":DEBRIS_PARTS[r.randi()%8],"at":Vector2(_jag(y)+side*(6.0+r.randf()*40.0),y),"v":Vector2(side*(50.0+r.randf()*r.randf()*560.0),(r.randf()-0.5)*300.0+70.0),"rot":r.randf()*TAU,"spin":(r.randf()-0.5)*3.0,"tum":r.randf()*TAU,"size":0.14+r.randf()*0.42})
	for j in 190: _debris.append(_chunk(r,DEBRIS_PARTS[r.randi()%8],0.9+r.randf()*2.1))
	for j in 300: _debris.append(_chunk(r,DEBRIS_PARTS[r.randi()%8],0.14+r.randf()*0.42))
	_debris.append(_chunk(r,"head",2.7,1100.0))
	_debris.append(_chunk(r,"tail_tip",1.8,1400.0))
	for d in 5:
		var list: Array[Dictionary] = []
		var limit := d==4
		for j in (300 if limit else 130):
			list.append({"a":r.randf()*TAU,"speed":(140.0 if limit else 70.0)+r.randf()*r.randf()*(620.0 if limit else 300.0),"drag":1.6+r.randf()*2.0,"life":0.7+r.randf()*(1.5 if limit else 1.1),"size":2.4 if r.randf()<0.2 else 1.2,"tw":r.randf()*TAU,"fall":12.0+r.randf()*34.0,"color":[GOLD_PALE,GOLD_LIGHT,GOLD,Color("#ffe9a8")][r.randi()%4]})
		_glitter.append(list)

func _chunk(r: RandomNumberGenerator, part: String, size: float, reach := 0.0) -> Dictionary:
	var speed := reach if reach>0.0 else 380.0+r.randf()*2300.0
	var a := r.randf()*TAU
	return {"part":part,"at":Vector2((r.randf()-0.5)*140.0,(r.randf()-0.5)*600.0),"v":Vector2.from_angle(a)*speed,"vz":speed*(r.randf()*1.15-0.12),"rot":r.randf()*TAU,"spin":(r.randf()-0.5)*7.0,"tum":r.randf()*TAU,"ts":1.0+r.randf()*7.0,"size":size,"life":3.4+r.randf()*3.8,"delay":r.randf()*0.18}

static func _smooth(a: float, b: float, x: float) -> float:
	return smoothstep(a,b,x) if a<b else (1.0 if x>=a else 0.0)
static func _out_cubic(k: float) -> float:
	return 1.0-pow(1.0-clampf(k,0.0,1.0),3.0)
static func _out_expo(k: float) -> float:
	return 1.0 if k>=1.0 else 1.0-pow(2.0,-10.0*clampf(k,0.0,1.0))
static func _jag(y: float) -> float:
	return 6.0*sin(y*0.07)+5.0*sin(y*0.19+1.0)+3.0*sin(y*0.41+2.0)

## 連撃で当たった場所から竜の体をしならせる。
static func kink(points: PackedVector2Array, finale: Dictionary) -> PackedVector2Array:
	if str(finale.get("stage",""))!="strikes": return points
	var time := float(finale.time)
	var out := points.duplicate()
	var count := out.size()-1
	var hits := RUSH.hits
	for row in range(0,hits.size(),DracoFinaleRush.HIT_FIELDS):
		var tau := time-hits[row]
		if tau<0.0 or tau>0.6: continue
		var amount := (40.0 if hits[row+8]>0.0 else 22.0)*exp(-tau*7.0)*cos(tau*24.0)
		var center := int(hits[row+2]*count)
		var direction := Vector2(hits[row+5],hits[row+6])
		var span := int(count*0.15)
		for j in range(maxi(0,center-span),mini(count,center+span)+1):
			var d := float(j-center)/count*80.0
			out[j] += direction*amount*exp(-d*d/30.0)
	return out

func set_shake_hook(hook: Callable) -> void:
	_shake_hook = hook

func hide_view() -> void:
	if visible: visible = false
	f = {}
	stage = ""

func apply_frame(finale: Dictionary, world_clock: float, view: Rect2, view_zoom: float) -> void:
	var previous := stage
	f = finale
	stage = str(finale.get("stage",""))
	t = float(finale.get("time",0.0))
	clock = world_clock
	zoom = maxf(view_zoom,0.01)
	times = finale.get("times",{})
	visible = true
	position = finale.center
	view_rect = Rect2(view.position-position,view.size).grow(200.0)
	if stage=="strikes": _rush_shake()
	if stage=="explode" and _shake_hook.is_valid(): _shake_hook.call(62.0*exp(-t*1.25)+7.0*(1.0-_smooth(3.0,5.5,t)))
	for node: Node2D in [_grade,_dim,_fx,_top]: node.queue_redraw()
	if previous!=stage: pass

func _rush_shake() -> void:
	if not _shake_hook.is_valid(): return
	var hits := RUSH.hits
	var strength := 0.0
	for row in range(0,hits.size(),DracoFinaleRush.HIT_FIELDS):
		var tau := t-hits[row]
		if tau<0.0 or tau>0.3: continue
		strength = maxf(strength,exp(-tau*12.0)*(16.0 if hits[row+8]>0.0 else 11.0))
	if strength>0.0: _shake_hook.call(strength)

func _flash_rise() -> float:
	return _smooth(float(times.from),float(times.from)+float(times.ramp),t)
func _impact() -> float:
	return float(times.from)+float(times.ramp)+float(times.peak)
func _flash_total() -> float:
	return _impact()+float(times.fade)+float(times.after)

## 世界の色：止まった世界の青。
func tone() -> Dictionary:
	if stage=="flash":
		if t<float(times.from)+float(times.ramp): return {"on":false}
		var impact := _impact()
		var gray := 1.0-_smooth(impact,maxf(impact+0.01,_flash_total()-0.7),t)
		return {"on":true,"color":SHADOW_TONE.lerp(GRAY_TONE,gray)}
	if stage=="sight":
		return {"on":true,"color":SHADOW_TONE.lerp(GRAY_TONE,_smooth(0.2,float(times.sight),t)*0.7)}
	return {"on":false}

func _mono() -> float:
	match stage:
		"input": return _smooth(0.0,0.35,t)*0.85
		"strikes","charge": return 0.85
		"flash": return 0.85 if t<float(times.from)+float(times.ramp) else 0.0
	return 0.0

func _draw_grade() -> void:
	var m := _mono()
	if m>0.0: _grade.draw_rect(view_rect,Color.WHITE.lerp(Color(0.2,0.3,0.72),m))

func _darkness() -> float:
	if stage=="flash":
		if t<0.1: return 0.0
		var from := _impact()+float(times.fade)*0.5
		return _smooth(from,maxf(from+0.01,_flash_total()-0.12),t)*0.985
	if stage=="sight": return lerpf(0.985,0.32,_smooth(0.1,float(times.sight),t))
	if stage=="explode": return 0.32*(1.0-_smooth(0.0,1.0,t))
	return 0.0

func _draw_dim() -> void:
	var d := _darkness()
	if d>0.0: _dim.draw_rect(view_rect,Color(0,0,0.02,d))

func _glow(at: Vector2, radius: float, color: Color, alpha := 1.0) -> void:
	_fx.draw_texture_rect(_soft,Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2.0),false,Color(color,color.a*alpha))

func _streak(at: Vector2, angle: float, length: float, width: float, color: Color, alpha: float, canvas: Node2D = null) -> void:
	var target := canvas if canvas!=null else _fx
	target.draw_set_transform(at,angle)
	target.draw_texture_rect(_soft,Rect2(-length,-width,length*2.0,width*2.0),false,Color(color,alpha))
	target.draw_set_transform(Vector2.ZERO)

func _burst(at: Vector2, count: int, length: float, width: float, rot: float, alpha: float) -> void:
	var half := ceili(count*0.5)
	for k in half:
		var big := k%2==0
		_streak(at,rot+k*PI/half,length*(1.0 if big else 0.6),width*(5.0 if big else 3.6),GOLD,alpha*0.8)
	_streak(at,0.0,length*2.0,width*3.6,GOLD_LIGHT,alpha*0.8)
	_streak(at,0.0,length*0.9,width*1.8,GOLD_PALE,alpha*0.7)
	_streak(at,PI*0.5,length*0.9,width*1.8,GOLD_PALE,alpha*0.7)

func _ship_at() -> Vector2:
	return Vector2(f.get("ship_pos",Vector2.ZERO))-position

func _draw_fx() -> void:
	match stage:
		"release": _fx_release()
		"combine": _fx_release(); _fx_combine()
		"pose": _glow(_ship_at(),60.0,GOLD,(1.0-_smooth(0.0,1.2,t)*0.6)*0.5)
		"input": _fx_input()
		"strikes": _fx_rush(t)
		"charge": _fx_rush(float(times.rush)+t); _fx_charge()
		"flash": _fx_flash(); _fx_cut()
		"sight": _fx_cut()
		"explode": _fx_explode()

func _fx_release() -> void:
	var rel := t if stage=="release" else 4.0+t
	var chest := Vector2(f.core_from)-position
	var up := Vector2(f.core_to)-position
	var swell := _smooth(0.0,0.95,rel)*(1.0-_smooth(1.0,1.5,rel))
	if rel<1.5:
		_glow(chest,70.0+swell*swell*250.0,Color("#bfe2ff"),0.35+swell*0.65)
		var r := _random(41)
		for j in 9:
			var dir := Vector2.from_angle(r.randf()*TAU)
			var reach := (70.0+r.randf()*170.0)*_smooth(0.25,0.95,rel)
			_fx.draw_line(chest,chest+dir*reach,Color(Color("#e6f5ff"),swell),maxf(1.0,5.0*swell))
	if rel<=0.92: return
	var q := rel-0.92
	var core := chest.lerp(up,_out_expo(q/0.9))
	if q<1.0: _glow(chest,520.0*(1.0-q*0.6),Color("#d9edff"),exp(-q*4.5))
	var fade := 1.0-_smooth(0.4,1.2,t) if stage=="combine" else 1.0
	if fade<=0.0: return
	var form := _smooth(1.2,2.2,rel)
	var inhale := _smooth(2.25,2.7,rel)*(1.0-_smooth(2.7,2.8,rel))
	var tail := up+Vector2(-190,26)
	if form>0.0: _draw_bear(up+Vector2(0,-4),inhale,_smooth(2.3,2.75,rel),form*fade)
	_star(core.lerp(tail,_smooth(1.1,2.0,rel)) if form>0.0 else core,(60.0+inhale*40.0)*(1.0+exp(-q*3.0)),Color("#cfe8ff"),fade)

## こぐま座は正式な絵が届くまでの仮の形。
func _draw_bear(at: Vector2, inhale: float, lift: float, alpha: float) -> void:
	var color := Color(Color("#8ea8ff"),0.34*alpha)
	var scale_ := 1.5+inhale*0.2
	_fx.draw_set_transform(at,0.0,Vector2.ONE*scale_)
	_fx.draw_colored_polygon(PackedVector2Array([Vector2(-120,8),Vector2(-92,-30),Vector2(-30,-42),Vector2(40,-34),Vector2(78,-16),Vector2(86,20),Vector2(60,30),Vector2(52,58),Vector2(30,58),Vector2(26,30),Vector2(-30,30),Vector2(-38,58),Vector2(-62,58),Vector2(-66,28),Vector2(-110,24)]),color)
	_fx.draw_set_transform(at+Vector2(80,-8).rotated(0.0)*scale_,-0.1-lift*0.5,Vector2.ONE*scale_)
	_fx.draw_colored_polygon(PackedVector2Array([Vector2(-14,-22),Vector2(26,-24),Vector2(58,-2),Vector2(26,4+lift*14.0),Vector2(-10,18)]),color)
	_fx.draw_set_transform(Vector2.ZERO)

func _star(at: Vector2, radius: float, color: Color, alpha: float) -> void:
	_glow(at,radius*1.4,color,alpha)
	_streak(at,0.0,radius*1.6,maxf(2.0,radius*0.1),Color.WHITE,alpha)
	_streak(at,PI*0.5,radius*1.6,maxf(2.0,radius*0.1),Color.WHITE,alpha)

func _module_at(index: int, q: float, ship: Vector2) -> Vector2:
	return ship+Vector2.from_angle(index*TAU/4.0+0.5+2.3*q*q)*330.0*(1.0-q*q*q)

func _fx_combine() -> void:
	var ship := _ship_at()
	var docked := 0.0
	for i in 4: docked += _smooth(0.0,0.25,t-(DOCK_FIRST+i*DOCK_STEP))
	docked *= 0.25*(1.0-_smooth(3.0,3.75,t))
	var lim := exp(-(t-UNLOCK_AT)*1.5) if t>UNLOCK_AT else 0.0
	var r := _random(31)
	if docked>0.0:
		for i in 11:
			var angle := i*PI/11.0+clock*0.16*(1.0 if i%2==0 else -1.0)+r.randf()*0.3
			_streak(ship,angle,(210.0+r.randf()*260.0)*(1.0+lim*1.4),(9.0+r.randf()*16.0)*(1.0+lim*0.5),Color("#ffcf7d"),0.34*docked+0.3*lim)
		_glow(ship,62.0+docked*38.0,GOLD,0.3+0.25*docked)
	for i in 4:
		var start := 0.25+i*0.16
		var dock := DOCK_FIRST+i*DOCK_STEP
		var k := clampf((t-start)/(dock-start),0.0,1.0)
		if t>start and t<dock:
			var points := PackedVector2Array()
			var colors := PackedColorArray()
			for n in 9:
				points.append(_module_at(i,maxf(0.0,k-0.28+0.28*n/8.0),ship))
				colors.append(Color(GOLD,n/8.0*0.75))
			_fx.draw_polyline_colors(points,colors,3.0)
			var at := _module_at(i,k,ship)
			_glow(at,30.0,GOLD_LIGHT,0.6)
			_burst(at,4,44.0,1.3,clock*3.0,0.8)
			var q := _random(i*7+5)
			for n in 46:
				var back := q.randf()*0.34
				var spot := _module_at(i,maxf(0.0,k-back),ship)+Vector2.from_angle(q.randf()*TAU)*(8.0+q.randf()*20.0)+Vector2(0,back*40.0)
				var twinkle := sin(clock*18.0+n)*0.5+0.5
				_fx.draw_rect(Rect2(spot,Vector2.ONE*(2.2 if n%6==0 else 1.2)),Color(GOLD_LIGHT if n%3!=0 else GOLD_PALE,(1.0-back/0.34)*(0.3+0.7*twinkle)))
		var dq := t-dock
		if dq>=0.0:
			if dq<0.7:
				var b := exp(-dq*6.0)
				_glow(ship,70.0+dq*160.0,GOLD_LIGHT,b)
				_glow(ship,170.0+dq*240.0,Color("#ff9a30"),0.55*b)
			if dq<0.55: _burst(ship,14,120.0+_out_expo(dq*3.0)*240.0,3.2,i*0.4+dq*0.6,exp(-dq*5.5))
			_fx_glitter(i,ship,dq)
	var q2 := t-UNLOCK_AT
	if q2>0.0:
		_glow(ship,lerpf(190.0,90.0,clampf(q2*1.5,0.0,1.0)),GOLD_LIGHT,0.6*exp(-q2*3.0))
		_glow(ship,lerpf(150.0,70.0,clampf(q2*1.5,0.0,1.0)),GOLD,0.5*exp(-q2*2.2)+0.16)
		if q2<0.9: _burst(ship,20,280.0+_out_expo(q2*2.0)*420.0,5.5,q2*0.5,exp(-q2*3.4))
		_fx_glitter(4,ship,q2)
	var fl := 0.0
	for i in 4:
		var q3 := t-(DOCK_FIRST+i*DOCK_STEP)
		if q3>=0.0: fl = maxf(fl,0.34*exp(-q3*10.0))
	if q2>=0.0: fl = maxf(fl,0.58*exp(-q2*5.0))
	if fl>0.004: _fx.draw_rect(view_rect,Color(Color("#ffb445"),fl))

func _fx_glitter(index: int, at: Vector2, age: float) -> void:
	for piece: Dictionary in _glitter[index]:
		if age>float(piece.life): continue
		var f2 := (1.0-exp(-age*float(piece.drag)))/float(piece.drag)
		var twinkle := 0.45+0.55*sin(float(piece.tw)+clock*22.0)
		var spot: Vector2 = at+Vector2.from_angle(float(piece.a))*float(piece.speed)*f2+Vector2(0,float(piece.fall)*age*age)
		_fx.draw_rect(Rect2(spot,Vector2.ONE*float(piece.size)),Color(piece.color,clampf((1.0-age/float(piece.life))*twinkle,0.0,1.0)))

func _fx_input() -> void:
	var guide: PackedVector2Array = f.guide
	var offset := -position
	if guide.size()>1:
		var points := PackedVector2Array()
		for p in guide: points.append(p+offset)
		_fx.draw_polyline(points,Color(Color("#bcd2ff"),_smooth(0.1,0.6,t)*0.26),2.4,true)
	var strokes: PackedVector2Array = f.strokes
	if strokes.size()>1:
		var points := PackedVector2Array()
		for p in strokes: points.append(p+offset)
		_fx.draw_polyline(points,Color(Color("#5f9dff"),0.4),14.0,true)
		_fx.draw_polyline(points,Color(Color("#a8dcff"),0.8),6.0,true)
		_glow(points[-1],46.0,Color.WHITE,0.95)

func _path_at(time: float) -> Vector2:
	var path := RUSH.path
	var low := 0
	var high := path.size()/3-1
	while low<high:
		var mid := (low+high+1)/2
		if path[mid*3]<=time: low = mid
		else: high = mid-1
	var next_row := mini(low+1,path.size()/3-1)
	var a := Vector2(path[low*3+1],path[low*3+2])
	var b := Vector2(path[next_row*3+1],path[next_row*3+2])
	var span := path[next_row*3]-path[low*3]
	return a.lerp(b,clampf((time-path[low*3])/span,0.0,1.0) if span>0.0 else 0.0)

func _trail(time: float, window: float, offset: float, width: float, color: Color, alpha: float) -> void:
	var path := RUSH.path
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var row := path.size()/3-1
	while row>=0 and path[row*3]>time: row -= 1
	while row>=2:
		var age := time-path[row*3]
		if age>window: break
		var strength := 1.0-age/window
		var at := Vector2(path[row*3+1],path[row*3+2])
		var previous := Vector2(path[(row-2)*3+1],path[(row-2)*3+2])
		var side := (at-previous).orthogonal().normalized()*offset*strength
		points.append(at+side)
		colors.append(Color(color,alpha*strength*strength))
		row -= 2
	if points.size()>1: _fx.draw_polyline_colors(points,colors,width)

func _sharp_hit(time: float) -> int:
	var hits := RUSH.hits
	var row := hits.size()-DracoFinaleRush.HIT_FIELDS
	while row>=0:
		var tau := time-hits[row]
		if tau>=0.0:
			if tau>0.035: return -1
			if hits[row+7]>0.0: return row
		row -= DracoFinaleRush.HIT_FIELDS
	return -1

func _ship_shape(canvas: Node2D, at: Vector2, angle: float, color: Color, scale_ := 1.0) -> void:
	canvas.draw_set_transform(at,angle+PI*0.5,Vector2.ONE*scale_)
	canvas.draw_texture(SHIP,-SHIP.get_size()*0.5,color)
	canvas.draw_set_transform(Vector2.ZERO)

func _fx_rush(time: float) -> void:
	var window := RAIL_TRAIL
	_trail(time,window,0.0,9.0,Color("#3f78ff"),0.5)
	_trail(time,window*0.5,0.0,5.0,Color("#9fd2ff"),0.8)
	var offsets := [-13.0,-7.0,-3.0,3.0,8.0,14.0]
	var tints := [Color("#7fb6ff"),Color("#cfe8ff"),Color.WHITE,Color.WHITE,Color("#ffe9a8"),Color("#8fc4ff")]
	for j in 6: _trail(time,window*(0.5+0.09*j),offsets[j],1.6,tints[j],0.95)
	var hits := RUSH.hits
	for row in range(0,hits.size(),DracoFinaleRush.HIT_FIELDS):
		var tau := time-hits[row]
		if tau<0.0 or tau>0.38: continue
		var big := hits[row+8]>0.0
		var b := exp(-tau*(8.0 if big else 13.0))
		var size_ := 1.0 if big else 0.62
		var at := Vector2(hits[row+3],hits[row+4])
		var dir := Vector2(hits[row+5],hits[row+6])
		_glow(at,130.0*size_*(1.0+tau*2.0),Color("#e2f0ff"),b)
		_streak(at,dir.angle(),240.0*size_*(1.0+tau*4.0),6.0*b*size_,Color.WHITE,b)
		var q := _random(row+1)
		for j in (12 if big else 6):
			var angle := dir.angle()+(q.randf()-0.5)*1.6
			var reach := (240.0+q.randf()*560.0)*(1.0-exp(-tau*5.0))/5.0
			_fx.draw_rect(Rect2(at+Vector2.from_angle(angle)*reach,Vector2.ONE*4.0),Color(Color("#e8f3ff"),b))
	var ghosts := RUSH.ghosts
	for row in range(0,ghosts.size(),DracoFinaleRush.GHOST_FIELDS):
		var age := time-ghosts[row]
		if age<0.0 or age>0.24: continue
		_ship_shape(_fx,Vector2(ghosts[row+1],ghosts[row+2]),ghosts[row+3],Color(Color("#bfe0ff"),0.8*(1.0-age/0.24)))
	if time>=float(times.rush) or _sharp_hit(time)>=0: return
	for k in 12:
		var a := _path_at(time-k*0.0035)
		var b := _path_at(time-k*0.0035-0.003)
		_ship_shape(_fx,a,(a-b).angle(),Color(Color("#bfe0ff"),0.3*(1.0-k/12.0)))
	_glow(_path_at(time),46.0,Color("#a8d4ff"),0.5)

func _charge_time() -> float:
	return float(times.charge)

func _fx_charge() -> void:
	var charge := _charge_time()
	var k := _smooth(-0.3,charge*0.8,t)
	var ship := SHIP_LOW+Vector2(0,_smooth(0.0,charge,t)*16.0)
	var radius := 20.0+k*k*62.0
	_glow(ship,radius,GOLD,0.28+0.32*k)
	_glow(ship,radius*2.2,Color("#ff9a30"),0.22*k)
	var progress := t/charge
	for piece: Dictionary in _charge:
		var u := (progress-float(piece.ts))/float(piece.life)
		if u<0.0 or u>1.0: continue
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var base := _smooth(0.0,0.2,u)
		for n in 10:
			var along := float(n)/9.0
			var q := clampf(u-along*0.36,0.0,1.0)
			points.append(ship+Vector2.from_angle(float(piece.a)+float(piece.turn)*q*q)*float(piece.r)*(1.0-pow(q,2.4)))
			colors.append(Color(piece.color,base*(1.0-along)*(1.0-along*0.3)))
		_fx.draw_polyline_colors(points,colors,float(piece.w)/zoom)
	var aura := _smooth(0.0,charge,t)
	_ship_shape(_fx,ship,-PI*0.5,Color(GOLD,0.75*aura),1.5*(1.0+0.14*aura))

func _soft_line(width: float, alpha: float, top: float, bottom: float) -> void:
	var half := width*3.2
	_fx.draw_texture_rect(_soft,Rect2(-half*1.4,top,half*2.8,bottom-top),false,Color(Color("#4d7dff"),alpha*0.5))
	_fx.draw_rect(Rect2(-width*0.5,top,width,bottom-top),Color(1,1,1,alpha))

func _fx_flash() -> void:
	var impact := _impact()
	var fade_end := impact+float(times.fade)
	var line := float(times.line)
	if t<fade_end:
		var rise := _flash_rise()
		var fade := 1.0-_smooth(impact,fade_end,t)
		var b := rise*fade
		var head := lerpf(SHIP_LOW.y,-900.0,clampf(t/line,0.0,1.0))
		if b>0.0:
			_glow(Vector2.ZERO,360.0*(0.3+0.7*b),Color.WHITE,b)
			_glow(Vector2.ZERO,760.0*(0.3+0.7*b),Color("#7fb6ff"),b*0.45)
			_streak(Vector2.ZERO,0.0,view_rect.size.x*0.5,12.0,Color.WHITE,0.9*b)
			_streak(Vector2.ZERO,0.0,view_rect.size.x*0.5,36.0,Color("#8fc0ff"),0.36*b)
			_fx.draw_rect(view_rect,Color(Color("#3f86f0"),0.42*b))
		_soft_line(lerpf(8.0,30.0,b),fade,head,lerpf(SHIP_LOW.y+16.0,1700.0,rise))
		if t<line: _glow(Vector2(0,head),85.0,Color.WHITE,1.0)
	var hold := 0.72*exp(-maxf(0.0,t-impact)*0.55)
	if t>=float(times.from)+float(times.ramp): _fx.draw_rect(view_rect,Color(Color("#2b67c4"),hold))

func _gold_amount() -> float:
	var total := _flash_total()+float(times.sight)
	var now := t if stage=="flash" else _flash_total()+t
	return roundf(_smooth(_impact(),total,now)*12.0)/12.0

func _fx_cut() -> void:
	var impact := _impact()
	if stage=="flash" and t<impact: return
	var a := 1.0-0.25*_smooth(0.2,float(times.sight),t) if stage=="sight" else 1.0
	var rise := 0.05+0.95*_smooth(impact,maxf(impact+0.01,_flash_total()-0.3),t) if stage=="flash" else 1.0
	var gold := _gold_amount()
	var q := _random(61)
	var cuts := RUSH.cuts
	var ray := Color("#cde6ff").lerp(Color("#ffd67d"),gold)
	for row in range(0,cuts.size(),2):
		for i in 9:
			var side := 1.0 if i%2==1 else -1.0
			var angle := (0.0 if side>0.0 else PI)+side*(q.randf()-0.5)*1.5+sin(clock*0.35+i)*0.02
			var length := 520.0+q.randf()*760.0
			var width := 10.0+q.randf()*34.0
			var origin := Vector2(_jag(cuts[row]),cuts[row]+(q.randf()-0.5)*cuts[row+1])
			_streak(origin+Vector2.from_angle(angle)*length*0.5,angle,length*0.5,width,ray,a*rise*(0.5+q.randf()*0.5)*0.42)
	var age := (t if stage=="flash" else _flash_total()+t)-impact
	var p := _random(19)
	var chip := Color("#e9f4ff").lerp(Color("#ffdf96"),gold)
	for i in 420:
		var row := (i%(cuts.size()/2))*2
		var side := 1.0 if i%2==1 else -1.0
		var angle := (0.0 if side>0.0 else PI)+side*(p.randf()-0.5)*1.5
		var speed := 70.0+p.randf()*p.randf()*560.0
		var y := cuts[row]+(p.randf()-0.5)*cuts[row+1]
		var twinkle := 0.45+0.55*absf(sin(p.randf()*9.0+clock*5.0))
		_fx.draw_rect(Rect2(Vector2(_jag(y),y)+Vector2.from_angle(angle)*speed*(1.0-exp(-age*0.8))/0.8,Vector2.ONE*2.0/zoom*0.9),Color(chip,a*(0.25+0.75*rise)*twinkle))
	var edge := Color.WHITE.lerp(Color("#ffd269"),gold)
	var halo := Color("#cfe6ff").lerp(Color("#ffbe4a"),gold)
	for row in range(0,cuts.size(),2):
		var width := cuts[row+1]
		_glow(Vector2(0,cuts[row]),width*0.8,halo,a*0.5)
		var points := PackedVector2Array()
		var y := -width
		while y<=width:
			points.append(Vector2(_jag(cuts[row]+y),cuts[row]+y))
			y += 8.0
		_fx.draw_polyline(points,Color(edge,a),lerpf(2.0,9.0,a))

func _fx_explode() -> void:
	var q := t
	var core := (0.3+0.7*exp(-q*0.75))*(1.0-_smooth(3.4,6.0,q))
	var flash := exp(-q*3.6)
	_glow(Vector2.ZERO,1500.0,Color("#4a6dff"),0.24*core)
	_glow(Vector2.ZERO,1050.0,Color("#ff8f3e"),0.42*core)
	_glow(Vector2.ZERO,560.0+700.0*flash,Color("#ffd9a0"),0.6*core+0.3*flash)
	_glow(Vector2.ZERO,300.0+900.0*flash,Color.WHITE,clampf(core*0.95+flash,0.0,1.0))
	_streak(Vector2.ZERO,PI*0.5,1700.0,120.0*exp(-q*7.0),Color.WHITE,exp(-q*6.0))
	for piece: Dictionary in _clouds:
		var k := q-float(piece.delay)
		if k<0.0 or k>float(piece.life): continue
		var u := k/float(piece.life)
		var f2 := (1.0-exp(-k*0.75))/0.75
		var alpha := _smooth(0.0,0.12,u)*(1.0-_smooth(0.22,0.85,u))*0.105
		var size_ := float(piece.size)*(0.5+1.15*_out_cubic(u))
		var at: Vector2 = piece.at+piece.v*f2
		_fx.draw_set_transform(at,float(piece.rot)+float(piece.spin)*k)
		_fx.draw_texture_rect_region(PUFF,Rect2(-size_*0.5,-size_*0.5,size_,size_),_puffs[piece.puff],Color(piece.color,alpha))
	_fx.draw_set_transform(Vector2.ZERO)
	for wisp: Dictionary in _wisps:
		var k := q-float(wisp.delay)
		if k<0.0 or k>float(wisp.life): continue
		var u := k/float(wisp.life)
		var count := ceili(wisp.points.size()*_out_cubic(clampf(u*2.2,0.0,1.0)))
		if count<2: continue
		var points := PackedVector2Array()
		var stretch := 1.0+u*0.5
		for j in count: points.append(wisp.points[j]*stretch)
		var alpha := 1.0-_smooth(0.45,1.0,u)
		_fx.draw_polyline(points,Color(Color("#5f92ff"),0.16*alpha),9.0)
		_fx.draw_polyline(points,Color(Color("#cfe2ff"),0.42*alpha),2.2)
	var lines := PackedVector2Array()
	var line_colors := PackedColorArray()
	for piece: Dictionary in _streaks:
		var k := t-float(piece.delay)
		if k<0.0 or k>float(piece.life): continue
		var drag := float(piece.drag)
		var speed := float(piece.speed)
		var r := speed*(1.0-exp(-k*drag))/drag
		var length := maxf(14.0,speed*exp(-k*drag)*float(piece.shutter))*(1.0+k)
		var dir: Vector2 = piece.dir
		var base := Vector2(0,float(piece.y))
		var alpha := 1.0-k/float(piece.life)
		lines.append(base+dir*r)
		lines.append(base+dir*maxf(0.0,r-length))
		var color := Color(piece.color,alpha*alpha)
		line_colors.append(color)
		line_colors.append(color)
	for piece: Dictionary in _sparks:
		var k := q-float(piece.delay)
		if k<0.0 or k>float(piece.life): continue
		var f2 := (1.0-exp(-k*float(piece.drag)))/float(piece.drag)+k*0.05
		var at: Vector2 = piece.at+piece.v*f2
		lines.append(at)
		lines.append(at+Vector2(2.0/zoom,0))
		var color := Color(piece.color,clampf((1.0-k/float(piece.life))*(0.6+0.4*sin(float(piece.tw)+clock*9.0)),0.0,1.0))
		line_colors.append(color)
		line_colors.append(color)
	if lines.size()>1: _fx.draw_multiline_colors(lines,line_colors,1.6/zoom)
	var band := 0.95*exp(-q*0.55)*(1.0-_smooth(4.2,6.2,q))
	_streak(Vector2.ZERO,0.0,view_rect.size.x*0.6,50.0,Color("#ffb46a"),band*0.42)
	_streak(Vector2.ZERO,0.0,view_rect.size.x*0.6,12.0,Color("#fff0d6"),band*0.8)
	var north := _smooth(5.0,6.6,t)
	if north>0.0: _star(Vector2.ZERO,(70.0+9.0*sin(clock*2.2))*north,Color("#cfe8ff"),north)
	var white := 0.8*exp(-t*7.0)
	if white>0.003: _fx.draw_rect(view_rect,Color(1,1,1,white))

func _draw_piece(part: String, at: Vector2, angle: float, size_: float, squash: float, alpha: float) -> void:
	var texture: Texture2D = _textures[part]
	_top.draw_set_transform(at,angle,Vector2(size_,size_*(0.25+0.75*absf(squash))))
	_top.draw_texture(texture,-texture.get_size()*0.5,Color(1,1,1,alpha))

func _draw_rubble(age: float, alpha: float) -> void:
	var f2 := (1.0-exp(-age*0.75))/0.75
	for piece: Dictionary in _rubble:
		var rot := float(piece.rot)+float(piece.spin)*f2
		_draw_piece(piece.part,piece.at+piece.v*f2,rot,float(piece.size),cos(float(piece.tum)+float(piece.spin)*f2*2.0),alpha)
	_top.draw_set_transform(Vector2.ZERO)

func _draw_top() -> void:
	match stage:
		"strikes":
			var row := _sharp_hit(t)
			if row>=0:
				var hits := RUSH.hits
				var dir := Vector2(hits[row+5],hits[row+6])
				_ship_shape(_top,Vector2(hits[row+3],hits[row+4])-dir*64.0,dir.angle(),Color.WHITE,1.45)
		"charge":
			var shaking := _smooth(0.0,_charge_time(),t)*(1.0-_smooth(_charge_time(),_charge_time()+0.04,t))
			var at := SHIP_LOW+Vector2(sin(clock*61.0)*1.8*shaking,_smooth(0.0,_charge_time(),t)*16.0+cos(clock*53.0)*1.6*shaking)
			_ship_shape(_top,at,-PI*0.5,Color.WHITE,1.5)
		"flash":
			if t>=_impact(): _draw_rubble(t-_impact(),1.0)
		"sight":
			_draw_rubble(_flash_total()+t-_impact(),1.0)
		"explode":
			if t<0.6: _draw_rubble(_flash_total()+float(times.sight)+t-_impact(),1.0-t/0.6)
			_draw_debris()

func _draw_debris() -> void:
	for piece: Dictionary in _debris:
		var k := t-float(piece.delay)
		if k<0.0 or k>float(piece.life): continue
		var f2 := (1.0-exp(-k*0.62))/0.62+k*0.035
		var z := float(piece.vz)*f2
		if z>DEPTH*0.9: continue
		var scale_ := DEPTH/maxf(40.0,DEPTH-z)
		var at: Vector2 = (piece.at+piece.v*f2)*scale_
		var rot := float(piece.rot)+float(piece.spin)*(1.0-exp(-k*0.5))/0.5
		var alpha := 1.0-_smooth(0.72,1.0,k/float(piece.life))
		_draw_piece(piece.part,at,rot,float(piece.size)*scale_,cos(float(piece.tum)+float(piece.ts)*k*0.5),alpha)
	_top.draw_set_transform(Vector2.ZERO)
