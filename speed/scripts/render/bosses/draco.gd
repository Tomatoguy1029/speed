## 戦闘の点列と寸法を読むだけの表示。部位やHPへ書き戻さない。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var core_glow_radius := 43.0
@export var core_glow_opacity := 0.16
@export var core_glow_color := Color(0.38,0.59,1.0)
@export var rift_color := Color("#5a4d91")
var state := {}
## 吸引で口に届いたときは、通常の噛みつきと同じ大きさの牙を見せる。
const INHALE_BITE_WIDTH := 96.0
const INHALE_BITE_RECOVER := 0.8
var attack := {}
var _move_style := {}
var _styles := {}
var hit := 0.0
var hit_feedback: RefCounted
var _clones := {}
var _field: Node2D
func setup_effects(scope: ContentResourceScope, entries: Dictionary) -> void:
	if _field==null:
		_field=preload("res://scripts/render/bosses/hydra.gd").new()
		add_child(_field);_field.top_level=true
	_field.setup_effects(scope,entries)
var _rift_image: Polygon2D
var _rift_material: ShaderMaterial
var _parts: Node2D
var _reference_canvas
var _pose := {}
var _wake: Array = []
var _bite := {}
var _shout_clock := -1.0
var _crack_rows := {}
var _shot_born := {}
var _shot_times: Array[float] = []
var _raster := SpeedFxRaster.new()
var _raster_under := SpeedFxRaster.new()
var _fire: Node2D
const FX := preload("res://scripts/render/bosses/draco_fx.gd")
const HYDRA_FX := preload("res://scripts/render/bosses/hydra_fx.gd")
const FORM := preload("res://scripts/bosses/draco_form.gd")
const FINALE_VIEW := preload("res://scripts/render/bosses/draco_finale_view.gd")
var finale_view: Node2D
const PRIM := preload("res://scripts/render/fx/fx_reference_primitives.gd")
func set_reference_canvas(canvas) -> void:
	_reference_canvas = canvas
func _ready() -> void:
	z_index = 1
	_rift_image = Polygon2D.new()
	_rift_image.show_behind_parent = true
	_rift_material = ShaderMaterial.new()
	_rift_material.shader = preload("res://shaders/draco_rift_post.gdshader")
	_rift_material.set_shader_parameter("noise_tex",preload("res://assets/fx/water_noise.png"))
	_rift_image.material = _rift_material
	add_child(_rift_image)
	_parts = preload("res://scripts/bosses/draco_parts.gd").new()
	add_child(_parts)
	_fire = preload("res://scripts/render/bosses/draco_meteor_fire.gd").new()
	add_child(_fire)
	EFFECT_SETTINGS.apply_key(self,"boss/body/draco")
func apply_frame(body: Dictionary, current: Dictionary = {}, _appearance: Dictionary = {}) -> void:
	attack = current
	state = body
	_styles = _appearance.get("draco_styles",{})
	_move_style = _styles.get(current.get("technique",""),{})
	position = body.position
	rotation = body.facing
	visible = body.mode<4
	var intro: Dictionary = body.get("intro",{})
	_update_entrance_rift(intro)
	var feedback := {"white":0.0,"offset":Vector2.ZERO,"angle":0.0}
	if hit_feedback!=null: feedback=hit_feedback.sample(int(body.actor))
	hit = float(feedback.white)
	var points := PackedVector2Array()
	for point: Vector2 in body.body_points: points.append(to_local(point))
	var finale: Dictionary=body.get("finale",{})
	_pose = _present(points,body,current)
	points = _pose.points
	points = FINALE_VIEW.kink(points,finale)
	_parts.set_finale_tone(finale_view.tone() if finale_view!=null and finale_view.visible else {})
	_parts.arm_turns = _pose.arms
	_parts.pose(points,float(body.body_width)*float(body.perspective_scale),float(body.head_scale)*float(body.perspective_scale),0.0 if finale.get("stage","")=="explode" and float(finale.get("time",0.0))>0.1 else float(body.alpha),bool(current.get("cosmic_body",false)),hit,to_local(finale.get("center",Vector2.ZERO)),Vector2.RIGHT.rotated(-rotation)*float(finale.get("split",0.0))*90.0)
	_parts.entrance(intro,to_local(intro.get("rift_center",body.position)),float(body.get("entrance_quiet",2.5)))
	_parts.position = Vector2(feedback.offset).rotated(-float(body.facing))
	_parts.rotation = float(feedback.angle)
	var live := {}
	for clone: Dictionary in body.get("clones",[]):
		live[clone.id]=true
		if not _clones.has(clone.id):
			var parts: Node2D=preload("res://scripts/bosses/draco_parts.gd").new()
			add_child(parts);parts.top_level=true
			parts.use_picaro(float(clone.id)*0.37)
			_clones[clone.id]=parts
		var parts: Node2D=_clones[clone.id]
		var clone_feedback := {"white":0.0,"offset":Vector2.ZERO,"angle":0.0}
		if hit_feedback!=null: clone_feedback=hit_feedback.sample(int(clone.id))
		parts.position=clone.position+clone_feedback.offset;parts.rotation=float(clone.angle)+float(clone_feedback.angle)
		parts.visible=not body.get("cinematic_hide_enemies",false)
		var posed := PackedVector2Array()
		for point: Vector2 in clone.points:posed.append((point-clone.position).rotated(-float(clone.angle)))
		var clone_time := float(current.get("stage_time",0.0))
		var clone_active := float(current.get("active_time",7.5))
		var fade_in := _smooth(0.0,0.45,clone_time)*(1.0-_smooth(clone_active-0.9,clone_active-0.25,clone_time))
		parts.pose(_swim(posed,float(body.clock)+float(clone.id)*2.0,0.8,1.0,float(clone.id)),float(body.body_width),float(body.head_scale),fade_in,true,float(clone_feedback.white))
	for id in _clones.keys():
		if not live.has(id):_clones[id].queue_free();_clones.erase(id)
	if _field!=null:_field.apply_frame(body)
	queue_redraw()
func _draw() -> void:
	if state.is_empty() or not visible: return
	var cycle: Dictionary = state.get("cycle",{})
	if cycle.get("stage",0)==2:
		for j in 16:
			var k := fmod(float(cycle.time)*0.5+j/16.0,1.0)
			var at := Vector2.from_angle(j*2.399963)*450.0*(1.0-k)
			draw_circle(at,4.0,Color(0.8,0.9,1.0,k))
	var intro: Dictionary = state.get("intro",{})
	var glow: float = float(intro.chest_glow) if intro.get("active",false) else 1.0
	var finale: Dictionary=state.get("finale",{})
	if not finale.get("stage","").is_empty():glow=0.0
	var depth := float(state.perspective_scale)
	var core := Vector2(-110.0*float(state.head_scale)*depth,0)
	var pulse := 0.85+sin(float(state.clock)*3.0)*0.15
	draw_circle(core,core_glow_radius*depth,Color(core_glow_color,core_glow_opacity*pulse*float(state.alpha)*glow))
	preload("res://scripts/bosses/draco_form.gd").star(self,core,27.0*depth,Color(0.85,0.96,1.0,float(state.alpha)*glow))

static func _smooth(a: float, b: float, x: float) -> float:
	return smoothstep(a,b,x) if a<b else 1.0-smoothstep(b,a,x)

## 長さと速さの違う波を重ね、胴の場所と時間で強さをむらにする。
static func _live_wave(s: float, t: float, seed := 0.0) -> float:
	var n := FX._noise(s*0.0016-t*0.55+t*0.37,seed+7.0)
	var surge := pow(0.5+0.5*FX._noise(s*0.0009+t*0.9-t*0.23,seed+19.0),3.0)*2.6
	return (0.62*sin(s*0.0071-t*3.3+1.4*n+seed)+0.42*sin(s*0.0029+t*1.7+seed*2.0)+0.3*sin(s*0.016-t*6.1+2.0*n))*(0.45+0.75*absf(n)+surge)

static func _fit(desired: PackedVector2Array, reference: PackedVector2Array) -> PackedVector2Array:
	var out := desired.duplicate()
	for j in range(1,out.size()):
		var delta := out[j]-out[j-1]
		if delta.is_zero_approx(): delta = Vector2(-1,0)
		out[j] = out[j-1]+delta.normalized()*reference[j-1].distance_to(reference[j])
	return out

## 当たりの点列は変えず、絵の動きだけに溜め・解放・うねりを足す。
func _present(points: PackedVector2Array, body: Dictionary, current: Dictionary) -> Dictionary:
	var tech: String = current.get("technique","")
	var stage := int(current.get("stage",5))
	var world_facing: float = float(body.facing)
	var arms := [0.0,0.0,0.0,0.0]
	if points.size()<2 or stage>2 or tech.is_empty(): return {"points":points,"facing":world_facing,"arms":arms,"charge":0.0}
	var t := float(body.clock)
	var st := float(current.get("stage_time",0.0))
	var warn := maxf(0.01,float(current.get("warn_time",1.0)))
	var active := float(current.get("active_time",0.0))
	var recover := maxf(0.01,float(current.get("recover_time",1.0)))
	var ready: bool = current.get("staging_ready",true)
	var windup := stage==0
	var releasing := stage==1 or stage==2
	var release_time := st if stage==1 else active+st
	var recoil := func(x: float) -> float: return (1.0-_smooth(0.0,0.1,x))-0.46*_smooth(0.025,0.075,x)*(1.0-_smooth(0.075,0.26,x))
	var k := _smooth(0.05,maxf(0.06,warn*0.82),st) if windup and ready else 0.0
	var charge: float = k if windup else recoil.call(release_time) if releasing else 0.0
	var out := points
	var tail := tech in ["tail_sweep","tail_slam"]
	if ready and tech not in ["spiral","tail_sweep","tail_slam","clones"]:
		var u := Vector2.RIGHT
		var side := Vector2.DOWN
		var weight := 0.3 if tech=="bite" else 1.0
		var last := float(points.size()-1)
		var desired := PackedVector2Array()
		for i in points.size():
			var s := i/last
			var bend := _smooth(0.02,0.16,s)*(1.0-_smooth(0.3,0.73,s))
			var strength: float = recoil.call(maxf(0.0,release_time-s*0.13)) if releasing else charge
			desired.append(points[i]+(u*44.0*bend+side*64.0*bend)*strength*weight)
		out = _fit(desired,points)
	var swim := 0.0
	if not ready: swim = 1.0
	elif windup: swim = 0.7*(1.0-_smooth(0.1,0.8,st/warn))
	elif stage==1: swim = 1.0 if tech in ["charge","leap"] else 0.25 if tech in ["breath","meteor","star_fan","inhale"] else 0.35
	else: swim = 0.7*_smooth(0.0,1.0,st/recover)
	if tail: swim *= 0.3
	var roar := _exhale_life(st-float(current.get("inhale_time",0.0))-float(current.get("beam_warn",0.0)),st) if tech=="inhale" and stage==1 and current.get("spent",false) else 0.0
	if roar>0.0:
		var last := float(out.size()-1)
		for i in out.size(): out[i] += (Vector2.RIGHT*-26.0*minf(1.4,roar)+Vector2.DOWN*sin(t*74.0)*4.0*roar)*(1.0-_smooth(0.0,0.35,i/last))
	var kick := _spit_kick(t,current,stage)
	if kick!=0.0:
		var last := float(out.size()-1)
		for i in out.size(): out[i] += Vector2.RIGHT*46.0*kick*(1.0-_smooth(0.0,0.3,i/last))
	if tech=="spiral":
		var coil := float(current.get("coil_time",1.2))
		var shrink_at := coil+float(current.get("pause_time",2.8))
		swim = 1.0 if stage!=1 or st<coil else 0.35 if st<shrink_at else 0.7
		var last := float(out.size()-1)
		var along := 0.0
		var waved := PackedVector2Array()
		for i in out.size():
			if i>0: along += out[i-1].distance_to(out[i])
			var delta := (out[i]-out[i-1]) if i>0 else (out[1]-out[0])
			var normal := Vector2(-delta.y,delta.x).normalized()
			waved.append(out[i]+normal*_live_wave(along,t*1.15)*34.0*swim*(0.15+0.85*_smooth(0.0,0.35,i/last)))
		out = waved
		if stage==1 and st>=coil and st<shrink_at+0.15:
			var pull := _smooth(shrink_at-0.45,shrink_at-0.05,st)*(1.0-_smooth(shrink_at,shrink_at+0.12,st))
			for i in 7: out[i] += (Vector2.RIGHT*-48.0*pull+Vector2.DOWN*sin(t*90.0)*3.0*pull)*(1.0-i/7.0)
	if tech!="spiral":
		out = _swim(out,t,swim,0.0 if tail else 1.0)
		if windup and ready:
			var q := _smooth(0.72,1.0,st/warn)
			var shake := Vector2.DOWN*sin(t*90.0)*3.0*q
			if q>0.0:
				for i in 7: out[i] += shake*(1.0-i/7.0)
	var turn := sin(t*5.3)*(0.07 if tech=="spiral" else 0.05)*swim
	for i in 4: arms[i] = (1.0 if i%2 else -1.0)*charge*(0.42 if i<2 else 0.16)
	if tech=="rifts" and ready and stage<=1:
		var swipes: Array = current.get("rift_swipes",[])
		var total := FORM.length(out)
		var distance := minf(total,float(body.body_width)*0.9)
		var at := FORM.sample(out,distance/maxf(1.0,total))
		var tangent := (FORM.sample(out,minf(1.0,(distance+2.0)/maxf(1.0,total)))-at).normalized()
		var normal := tangent.orthogonal()
		for i in 2:
			var side := -1.0 if i==0 else 1.0
			var base := (normal*side-tangent*0.3).angle()
			var out_side := Vector2(0,1)*(1.0 if sin(base)>=0.0 else -1.0)
			var rise := (Vector2.RIGHT+out_side*0.7).angle()
			var strike := (Vector2.RIGHT-out_side*0.45).angle()
			var local := -1.0
			var ahead := INF
			for n in swipes.size():
				if n%2!=i: continue
				var age := float(swipes[n].age)
				if age>=0.0: local = age
				elif -age<ahead: ahead = -age
			var reach := _smooth(0.0,0.16,local) if local>=0.0 else 0.0
			var settle := _smooth(0.22,0.6,local) if local>=0.0 else 0.0
			var lift := _smooth(0.42,0.12,ahead) if ahead<INF else 0.0
			var want := rise+wrapf(strike-rise,-PI,PI)*reach
			want += wrapf(rise-want,-PI,PI)*lift
			arms[i] = wrapf(want-base,-PI,PI)*(k if windup else maxf(1.0-settle if local>=0.0 else 1.0,lift))
	return {"points":out,"facing":world_facing+turn,"arms":arms,"charge":charge,"claws":_claws(out,float(body.body_width),arms)}

## 爪先の位置。腕の根元と手首の長さは絵の画素から求める。
func _claws(pts: PackedVector2Array, width: float, arms: Array) -> PackedVector2Array:
	var total := FORM.length(pts)
	var out := PackedVector2Array()
	var distance := minf(total,width*0.9)
	var fraction := distance/maxf(1.0,total)
	var at := FORM.sample(pts,fraction)
	var tangent := (FORM.sample(pts,minf(1.0,fraction+2.0/maxf(1.0,total)))-at).normalized()
	var normal := tangent.orthogonal()
	var w := width*FORM.taper(fraction)
	for i in 2:
		var side := -1.0 if i==0 else 1.0
		var direction := (normal*side-tangent*0.3).normalized().rotated(float(arms[i]))
		out.append(at+normal*side*w*0.32+direction*w/57.0*32.25)
	return out

## 吐くたびの反動：頭と首が短く引かれてから突き出る。
func _spit_kick(t: float, current: Dictionary, stage: int) -> float:
	var kick := 0.0
	if String(current.get("technique","")) in ["picaro_wall","star_fan"]:
		for at: float in _shot_times:
			var a := t-at
			if a>=0.0: kick -= 1.1*exp(-a/0.12)*(1.0-exp(-a/0.015))
		return kick
	if stage!=0: return 0.0
	for q: Dictionary in current.get("rocks",[]):
		var a := float(q.age)
		if a>=0.0: kick += exp(-a/0.1)*(1.0-exp(-a/0.02))-0.6*exp(-a/0.02)
	return kick

func _swim(pts: PackedVector2Array, t: float, swim: float, bow: float, seed := 0.0) -> PackedVector2Array:
	var last := pts.size()-1
	var s := 0.0
	var out := PackedVector2Array()
	for i in pts.size():
		if i>0: s += pts[i-1].distance_to(pts[i])
		var u := float(i)/last
		var along := (pts[mini(last,i+8)]-pts[maxi(0,i-8)]).normalized()
		var normal := Vector2(-along.y,along.x)
		var amp := 30.0*swim*_smooth(0.04,0.4,u)
		var arch := bow*70.0*_smooth(0.06,0.32,u)*sin(u*PI*1.35+0.5+seed)
		out.append(pts[i]+normal*(_live_wave(s,t,seed)*amp+arch*swim))
	return _fit(out,pts)

func draw_reference(canvas, _real_dt: float) -> void:
	if canvas!=_reference_canvas or state.is_empty() or _pose.is_empty(): return
	var t := float(state.clock)
	var tech: String = attack.get("technique","")
	var stage := int(attack.get("stage",5))
	var st := float(attack.get("stage_time",0.0))
	_draw_under(canvas,t,st,stage,tech)
	if _field!=null: _field.draw_reference(canvas,_real_dt)
	var ready: bool = attack.get("staging_ready",true)
	var scale_head := float(state.head_scale)*float(state.perspective_scale)
	var head: Vector2 = to_global(_pose.points[0])
	var body_angle := float(state.facing)
	var world_facing := float(_pose.facing)
	var mouth := head+Vector2.from_angle(world_facing)*120.0*scale_head
	var k := clampf(float(attack.get("windup_progress",0.0)),0.0,1.0)
	var world_points := PackedVector2Array()
	for point: Vector2 in _pose.points: world_points.append(to_global(point))
	var total := FORM.length(world_points)
	var chest := FORM.sample(world_points,minf(1.0,float(state.body_width)*0.9/maxf(1.0,total)))
	var tip := world_points[-1]
	if stage==0 and ready:
		if tech in ["bite","charge","leap","clones"]: FX.eyes(canvas,head,world_facing,FX._smooth(0.15,0.95,k),Color("#ff5470"),t)
		elif tech in ["tail_sweep","tail_slam","rifts"]: FX.eyes(canvas,head,world_facing,0.45*FX._smooth(0.3,1.0,k),FX.BASE,t)
		if tech in ["tail_sweep","tail_slam"]:
			FX.gather(canvas,tip,100.0,k,t,193.0)
			FX.supply(canvas,FORM.sample(world_points,0.72),tip,k,t,213.0)
		elif tech=="picaro_wall":
			var e := FX._smooth(0.62,1.0,k)
			if e>0.0: FX.dark_gather(canvas,mouth,e,t)
		elif tech=="rifts":
			for i in 2:
				var claw: Vector2 = to_global(_pose.claws[i])
				FX.gather(canvas,claw,66.0,k,t,191.0+i)
				FX.supply(canvas,chest,claw,k,t,211.0+i,32.0 if i else -32.0)
		elif tech in ["breath","meteor","star_fan","inhale"]:
			FX.gather(canvas,mouth,85.0,k,t,191.0)
			FX.supply(canvas,chest,mouth,k,t,215.0,30.0)
		if tech=="tail_slam" and attack.has("target"): FX.tremble(canvas,attack.target,float(attack.get("telegraph_radius",110.0)),k,t,121.0)
		if tech=="leap" and not attack.get("telegraph_points",PackedVector2Array()).is_empty(): FX.tremble(canvas,attack.telegraph_points[0],170.0,FX._smooth(0.15,0.9,k),t,141.0)
		if tech=="charge" and attack.get("warning",PackedVector2Array()).size()>=2:
			var line: PackedVector2Array = attack.warning
			PRIM.warn_rail(canvas.back,canvas.to_logical(line[0]),canvas.to_logical(line[-1]),{"color":FX.BASE,"k":0.3+0.7*k,"time":t,"seed":300,"maxLv":2,"intensity":1.0})
		if tech=="star_fan":
			var stars: PackedVector2Array = attack.get("telegraph_points",PackedVector2Array())
			for i in stars.size():
				FX.supply(canvas,mouth,stars[i],FX._smooth(0.1,0.75,k),t,230.0+i,(i-stars.size()*0.5)*7.0)
				FX.star_charge(canvas,stars[i],i,FX._smooth(0.08+i*0.03,0.85,k),t)
	if tech in ["charge","leap"] and stage==1: FX.rush(canvas,world_points,float(state.body_width),attack.get("takeoff",attack.get("origin",head)),float(body_angle),st,float(attack.active_time),FORM)
	var inhale_bite: bool = tech=="inhale" and stage==2 and attack.get("caught",false)
	if inhale_bite or (tech in ["bite","leap"] and stage in [1,2]):
		var active := float(attack.get("active_time",0.5))
		var bite_time := st if inhale_bite else (st if stage==1 else active+st)-active*0.7
		if bite_time>=0.0:
			if _bite.is_empty(): _bite = {"at":mouth,"angle":world_facing}
			FX.bite_tear(canvas,_bite.at,_bite.angle,bite_time,INHALE_BITE_WIDTH if inhale_bite else float(attack.get("attack_width",96.0)),INHALE_BITE_RECOVER if inhale_bite else float(attack.get("recover_time",1.0)),t)
	else: _bite = {}
	if tech=="tail_sweep" and stage==1:
		var last := world_points.size()-1
		_wake.append({"t":t,"a":world_points[last],"b":world_points[roundi(last*0.82)]})
	if tech=="tail_sweep" or not _wake.is_empty():
		FX.sweep_wake(canvas,_wake,t)
		if stage!=1 and not _wake.is_empty() and t-float(_wake[-1].t)>0.4: _wake.clear()
	if tech=="inhale" and stage==1:
		var hold := float(attack.get("inhale_time",3.0))
		if st<hold: FX.inhale(canvas,mouth,float(attack.get("pull_range",1500.0)),_smooth(0.0,0.4,st)*(1.0-_smooth(hold-0.3,hold,st)),t)
		elif attack.get("spent",false) and st-hold<float(attack.beam_warn):
			var warn_k := clampf((st-hold)/float(attack.beam_warn),0.0,1.0)
			var from: Vector2 = attack.beam_from
			FX.gather(canvas,from,150.0,warn_k,t,21.0)
			PRIM.warn_rail(canvas.front,canvas.to_logical(from),canvas.to_logical(from+Vector2(attack.beam_direction)*float(attack.beam_reach)),{"color":FX.BASE,"k":warn_k,"time":t,"seed":5,"maxLv":2,"intensity":1.0})
	if tech=="spiral" and stage==1:
		var coil := float(attack.get("coil_time",1.2))
		var pause := float(attack.get("pause_time",2.8))
		if st>=coil and st<coil+pause+0.1:
			var q := clampf((st-coil)/pause,0.0,1.0)
			FX.spiral_countdown(canvas,world_points,q,t)
			FX.gather(canvas,mouth,120.0,q,t,88.0)
			var last_look := _smooth(0.85,1.0,q)
			if last_look>0.0: FX.eyes(canvas,head,world_facing,last_look,FX.BASE,t)
	if tech=="clones" and stage==1:
		for unit: Dictionary in attack.get("clones",[]):
			if not unit.alive: continue
			var mode := String(unit.mode)
			var time := float(unit.time)
			var charge := maxf(0.01,float(unit.get("charge",0.6)))
			if time<=0.0: continue
			var kind: String = {"bite_thrust":"bite","wind_band":"vortex","rubble_fan":"debris","beam_fixed":"beam","thunder_drop":"thunder"}.get(mode,"bite")
			var color: Color = HYDRA_FX.COLORS[kind]
			var unit_mouth: Vector2 = Vector2(unit.position)+Vector2.from_angle(float(unit.angle))*120.0*float(state.head_scale)
			var e := time-charge
			if e<0.0: FX.gather(canvas,unit_mouth,70.0,time/charge,t,400.0+float(unit.index),color)
			elif mode=="bite_thrust": HYDRA_FX.clone_fangs(canvas,unit_mouth,float(unit.angle),e-float(unit.get("active",0.2)),float(unit.get("bite_radius",70.0)),float(unit.index)*13.0,color)
	if tech=="picaro_wall":
		var shots := int(attack.get("shots",0))
		while _shot_times.size()<shots: _shot_times.append(t)
		for at: float in _shot_times: FX.dark_muzzle(canvas,mouth,world_facing,t-at)
	elif tech=="star_fan":
		if stage==1 and _shot_times.is_empty(): _shot_times.append(t)
		if not _shot_times.is_empty():
			var since := t-float(_shot_times[0])
			if since<0.35:
				var m: Vector2 = canvas.to_logical(mouth)
				var left := 1.0-since/0.35
				canvas.front.glow(m.x,m.y,11.0,FX.FLAME[4],0.55*left)
				canvas.front.disc(m.x,m.y,2.5*left,FX.FLAME[1],1.0)
	else: _shot_times.clear()
	for impact: Dictionary in attack.get("arrow_impacts",[]):
		if impact.locked: FX.dark_fall(canvas,impact.position,float(impact.age)-float(impact.wait),float(impact.warn),float(attack.get("impact_radius",85.0)),t)
	for effect: Dictionary in state.get("impacts",[]):
		var age := float(effect.age)
		var seed := 83.0+floorf((t-age)*10.0)
		var radius := float(effect.radius)
		if effect.technique=="tail_slam":
			FX.impact(canvas,effect.position,age,radius*2.6,seed,_cracks(seed,radius*2.6*float(canvas.world_scale)))
			FX.dark_blast(canvas,effect.position,age,radius*1.5,seed,FX.FLAME)
			for m in 6: FX.dust(canvas,effect.position,age-m*0.02,seed+m,m*TAU/6.0,2.4)
		elif effect.technique=="picaro_wall": FX.dark_blast(canvas,effect.position,age,radius,seed)
		else: FX.impact(canvas,effect.position,age,radius*1.1,seed,_cracks(seed,radius*1.1*float(canvas.world_scale)))
	if str(state.get("finale",{}).get("stage","")).is_empty(): canvas.front.glow(canvas.to_logical(chest).x,canvas.to_logical(chest).y,10.0,Color("#8dbdff"),0.35)
	_draw_heavy(canvas,t,st,stage,tech,mouth,world_facing)
	if tech=="rifts": FX.rift_tells(canvas,attack.get("rift_tears",[]),float(attack.get("rift_tell",0.5)),float(attack.get("rift_open",0.16)),float(attack.get("rift_close",0.55)),t)
	_draw_rocks(canvas,t,tech,stage)

func _draw_heavy(canvas, t: float, st: float, stage: int, tech: String, mouth: Vector2, world_facing: float) -> void:
	var front = canvas.front
	_raster.begin(front.colors,front.lights,front.width,front.height,float(canvas.world_scale),canvas._camera_position)
	var drew := false
	if tech=="breath" and stage==1 and attack.get("attack_points",PackedVector2Array()).size()>=3:
		_raster.breath(attack.attack_points,st,float(attack.active_time),float(attack.axis),float(attack.sweep),float(attack.half_angle),float(attack.reach),float(attack.fan_angle))
		drew = true
	if tech=="inhale" and stage==1 and attack.get("spent",false):
		var warn := float(attack.beam_warn)
		var age := st-float(attack.inhale_time)
		if age>=warn:
			_raster.exhale(attack.beam_from,Vector2(attack.beam_direction).angle(),float(attack.beam_reach),float(attack.beam_width),age-warn,float(attack.beam_extend),_exhale_life(age-warn,st),t)
			drew = true
	var live := {}
	for shot: Dictionary in state.get("shots",[]):
		live[shot.id] = true
		if not _shot_born.has(shot.id): _shot_born[shot.id] = t
		var age := t-float(_shot_born[shot.id])
		var seed := float(shot.id)*0.37
		match int(shot.style):
			0: _raster.comet(shot.position,float(shot.angle),age,float(shot.speed),12.0,240.0,0.5,seed,false)
			1: _raster.comet(shot.position,float(shot.angle),age,float(shot.speed),24.0,520.0,0.2,seed,true)
			2: _raster.dark_shot(shot.position,float(shot.angle),age,seed)
		drew = true
	for id in _shot_born.keys():
		if not live.has(id): _shot_born.erase(id)
	for impact: Dictionary in attack.get("arrow_impacts",[]):
		if not impact.locked: continue
		var age := float(impact.age)-float(impact.wait)
		var warn := float(impact.warn)
		var drop := clampf((age-(warn-0.14))/0.14,0.0,1.0)
		if drop>0.0:
			_raster.dark_shot(Vector2(impact.position)+Vector2(0.0,-900.0*(1.0-drop)),PI*0.5,age,float(impact.wait))
			drew = true
	front.colors = _raster.take_colors()
	front.lights = _raster.take_lights()
	if drew:
		front.has_color = true
		front.has_light = true

func _exhale_life(age: float, st: float) -> float:
	if age<0.0: return 0.0
	var active := float(attack.active_time)
	return _smooth(0.0,0.08,age)*(1.0-_smooth(active-0.45,active,st))*(1.0+0.5*exp(-age/0.16))

## 体より奥の層：暗転と、ためた光の広がり。
func _draw_under(canvas, t: float, st: float, stage: int, tech: String) -> void:
	var dim := 0.0
	var flash := 0.0
	var k := clampf(float(attack.get("windup_progress",0.0)),0.0,1.0)
	if tech=="star_fan":
		var recover := maxf(0.01,float(attack.get("recover_time",1.0)))
		dim = 0.5*_smooth(0.1,1.0,k) if stage==0 else 0.5 if stage==1 else 0.5*(1.0-_smooth(0.1,0.8,st/recover)) if stage==2 else 0.0
		if stage==1: flash = exp(-st/0.08)*0.12
	if tech=="inhale" and stage==1 and attack.get("spent",false):
		var warn := float(attack.beam_warn)
		var age := st-float(attack.inhale_time)
		dim = 0.55*_smooth(0.1,warn,age) if age<warn else 0.62*clampf(_exhale_life(age-warn,st),0.0,1.0)
		if age>=warn: flash = exp(-(age-warn)/0.07)*0.3
	var breath: bool = tech=="breath" and stage<=1 and not attack.get("rocks",[]).is_empty()
	if dim<=0.0 and flash<=0.0 and not breath:
		if tech!="breath": _raster_under.light_mask_reset()
		return
	var back = canvas.back
	_raster_under.begin(back.colors,back.lights,back.width,back.height,float(canvas.world_scale),canvas._camera_position)
	_raster_under.dim(dim,flash)
	if breath:
		var last := 1.6*0.62+0.42
		var warn := float(attack.warn_time)
		var charge := _smooth(last,warn-0.1,st) if stage==0 else 1.0-_smooth(0.2,float(attack.active_time),st)*0.55
		if charge>0.0:
			_raster_under.light_mask(attack.mouth,120.0,position,120.0*float(state.head_scale),float(attack.axis),float(attack.sweep),float(attack.half_angle),float(attack.reach),attack.rock_destinations,float(attack.rock_radius),charge*(0.88+0.12*sin(t*14.0)))
	back.colors = _raster_under.take_colors()
	back.lights = _raster_under.take_lights()
	back.has_color = true
	back.has_light = true

## 隕石：飛ぶ炎と、炎に耐えて広がるひび。
func _draw_rocks(canvas, t: float, tech: String, stage: int) -> void:
	var rows: Array = []
	for q: Dictionary in state.get("meteors",[]):
		rows.append({"position":q.position,"angle":q.angle,"radius":q.radius,"seed":q.seed,"alpha":_smooth(0.0,0.12,float(q.age))})
	if tech=="breath":
		var active := float(attack.get("active_time",1.0))
		for q: Dictionary in attack.get("rocks",[]):
			var age := float(q.age)
			if age<0.0 or not q.alive: continue
			var from: Vector2 = attack.mouth
			var dir: Vector2 = (Vector2(q.destination)-from).normalized()
			if age<0.92:
				rows.append({"position":q.position,"angle":dir.angle(),"radius":q.radius,"seed":q.order,"alpha":_smooth(0.0,0.12,minf(age,0.42))*(1.0-_smooth(0.42,0.87,age))})
			if age>=0.42 and age<1.82:
				var seed := 71.0+float(q.order)
				FX.impact(canvas,q.destination,age-0.42,float(q.radius)*1.25,seed,_cracks(seed,float(q.radius)*1.25*float(canvas.world_scale)))
			var k := clampf(float(q.burn)/(active*0.28),0.0,1.0)
			if k>0.0: FX.rock_heat(canvas,q.position,float(q.radius),k,float(q.burn),active*0.28,int(q.order),_cracks(61.0+float(q.order)*7.0,float(q.radius)*float(canvas.world_scale)))
	var shards: Array = []
	for effect: Dictionary in state.get("impacts",[]):
		var since := float(effect.age)
		if effect.technique!="breath" or since>1.1: continue
		var at: Vector2 = effect.position
		var radius := float(effect.radius)
		var seed := 91.0+posmod(int(at.x),3)*5.0
		for m in 14:
			var life := lerpf(0.45,0.85,FX._hash(m*7.3+3.1+seed))
			if since>life: continue
			var a := FX._hash(m*7.3+6.2+seed)*TAU
			var f := since/life
			shards.append({"position":at+Vector2.from_angle(a)*radius*(0.2+lerpf(0.9,1.9,FX._hash(m*7.3+9.3+seed))*(1.0-exp(-since/0.16))),"angle":FX._hash(m*7.3+12.4+seed)*6.0+since*lerpf(-5.0,5.0,FX._hash(m*7.3+15.5+seed)),"radius":radius*lerpf(0.14,0.36,FX._hash(m*7.3+18.6+seed))*(1.0-f*0.3),"alpha":1.0-f*f})
	_fire.apply_frame(rows,t,shards)

func _cracks(seed: float, radius: float) -> Array:
	if not _crack_rows.has(seed):
		if _crack_rows.size()>16: _crack_rows.clear()
		_crack_rows[seed] = FX.cracks(seed,radius)
	return _crack_rows[seed]

## 攻撃と同じ裂け目shaderを竜より奥へ置く。画面座標への変換も攻撃と揃える。
func _update_entrance_rift(intro: Dictionary) -> void:
	_rift_image.visible = intro.get("active",false) and float(intro.get("rift",0.0))>0.0
	if not _rift_image.visible: return
	var size := get_viewport_rect().size
	var pixel := size.y/225.0
	var transform := get_global_transform_with_canvas()
	var inverse := transform.affine_inverse()
	_rift_image.polygon = PackedVector2Array([inverse*Vector2.ZERO,inverse*Vector2(size.x,0),inverse*size,inverse*Vector2(0,size.y)])
	var center: Vector2 = intro.rift_center
	var opening := float(intro.rift)
	var a := transform*to_local(center+Vector2(0,-430)) / pixel
	var b := transform*to_local(center+Vector2(0,430)) / pixel
	var zoom := transform.x.length()
	var ends := PackedVector4Array([Vector4(a.x,a.y,b.x,b.y)])
	var shapes := PackedVector4Array([Vector4(230.0*zoom/pixel*opening,opening,opening,17.0)])
	ends.resize(12)
	shapes.resize(12)
	_rift_material.set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
	_rift_material.set_shader_parameter("viewport_size",size)
	_rift_material.set_shader_parameter("time",float(state.clock))
	_rift_material.set_shader_parameter("count",1)
	_rift_material.set_shader_parameter("ends",ends)
	_rift_material.set_shader_parameter("shape",shapes)
