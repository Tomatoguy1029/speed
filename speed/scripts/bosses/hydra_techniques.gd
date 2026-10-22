## 大技の配置と連続動作。開始・終了の時点はAnimationPlayerが決める。
extends RefCounted
var a: Node
var time:=0.0
var playing:=false
var positioning:=false
var state: Dictionary={}
func _init(actor: Node)->void:a=actor
func prepare()->void:
	time=0.0
	state.clear()
	playing=false
	positioning=false
	for n in a.participants:
		n.strike_pos=a._head_pos(n)
		n.strike_from=n.strike_pos
		n.mode=&"special_aim"
		n.locked=false
		n.step=0
		n.emission.clear()
	if a.tech==&"curve":curve(0.0)
	if a.tech in [&"swarm",&"grid"]:
		positioning=true
		state.slots=[]
		state.arrived={}
		state.position_elapsed=0.0
		var rect: Rect2=a.run_state.view_rect().intersection(a.arena.bounds).grow(-float(a.def.params.formation_margin))
		for i in a.participants.size():
			var angle: float=TAU*float(i)/a.participants.size()
			var slot: Vector2=rect.get_center()+Vector2(cos(angle)*rect.size.x*0.45,sin(angle)*rect.size.y*0.45)
			state.slots.append(a.arena.safe_point(slot,a.table.r[a.participants[i].row]+12.0))
		if a.tech==&"grid":
			state.plan=a.grid_plan()
			state.slots.clear()
			for beam in state.plan.beams:state.slots.append(beam[0])
func tick(dt: float)->void:
	if not playing:return
	time+=dt
	if a.tech==&"sequence":sequence(dt)
	elif a.tech==&"curve":curve(dt)
	elif a.tech==&"tornado":tornado()
	elif a.tech==&"debris_shatter":debris_shatter()
	elif a.tech==&"beam_pincer":beam_pincer()
	elif a.tech==&"swarm":swarm(dt)
	elif a.tech==&"grid":grid()
func sequence(dt: float)->void:
	var p: Dictionary=a.def.params
	for i in a.participants.size():
		var n=a.participants[i]
		var local: float=time-i*float(p.sequence_gap)
		if local<0.0:continue
		if not n.locked:
			n.target=a.run_state.ship_pos
			if local<float(p.sequence_charge):continue
			n.locked=true
			n.strike_from=n.strike_pos
			n.angle=(n.target-n.strike_from).angle()
			a._cue(&"target_locked",a.tech,a.necks.find(n))
			a._cue(&"attack_started",a.tech,a.necks.find(n))
		var fraction:=clampf((local-float(p.sequence_charge))/float(p.normal_lunge),0.0,1.0)
		if n.mode!=&"special_hold":
			var before: Vector2=n.strike_pos
			n.strike_pos=n.strike_from.lerp(n.target,fraction)
			a.attack_field.add_shape(PackedVector2Array([before,n.strike_pos]),float(p.bite_radius)*2.0,0.0,maxf(dt,0.02)+0.001,float(p.bite_dmg),&"bite",n.row)
			if fraction>=1.0:n.mode=&"special_hold"

func curve(dt: float)->void:
	var p: Dictionary=a.def.params
	a.table.facing[a.body]+=float(p.curve_turn)*dt
	for n in a.participants:
		if not a._alive(n):continue
		n.angle=n.base_angle+a.table.facing[a.body]
		n.strike_pos=a._neck_base(n)+Vector2.from_angle(n.angle)*float(p.neck_rest)
		var points:=PackedVector2Array([n.strike_pos])
		var at: Vector2=n.strike_pos
		for j in range(1,25):
			var f:=float(j)/24.0
			at+=Vector2.from_angle(n.angle-f*float(p.curve_lag))*float(p.beam_len)/24.0
			points.append(at)
		if n.emission.is_empty():
			n.emission=a.attack_field.add_shape(points,float(p.beam_width),0.8,float(p.curve_time),float(p.beam_dmg),&"beam",n.row)
		else:n.emission.points=points
		if time>=float(p.curve_time):
			n.emission.life=0.0
			n.mode=&"special_hold"

func tornado()->void:
	var p: Dictionary=a.def.params
	var wind=a.participants[0]
	var debris=a.participants[1]
	if not state.has("vortex"):
		var direction: Vector2=(a.run_state.ship_pos-wind.strike_pos).normalized()
		if direction==Vector2.ZERO:direction=Vector2.from_angle(wind.angle)
		state.center=wind.strike_pos+direction*120.0
		state.direction=direction
		wind.angle=direction.angle()
		debris.angle=(Vector2(state.center)-debris.strike_pos).angle()
		var points:=PackedVector2Array([state.center,state.center+Vector2(0.1,0)])
		state.vortex=a.attack_field.add_shape(points,float(p.tornado_width)*0.8,0.0,1.2,0.0,&"tornado_charge",wind.row)
		state.rows=[]
		state.from=debris.strike_pos
		for j in 3:
			var row: int=a.manager.enemies.spawn(a.manager.enemies.def_of(&"hydra_rubble"),debris.strike_pos)
			a._rubble.append(Vector2i(row,a.table.id[row]))
			state.rows.append(row)
			a.table.color[row].a=0.0
			a.table.r[row]=26.0+float(j)*6.0
		a._cue(&"gather_started",a.tech,a.necks.find(wind))
	if not state.has("launched"):
		state.vortex.fill=clampf((time-0.5)/0.7,0.0,1.0)
		state.vortex.feed=[]
		var from: Vector2=state.from
		var center: Vector2=state.center
		var side: Vector2=(center-from).normalized().orthogonal()
		for j in state.rows.size():
			var row: int=state.rows[j]
			var progress:=clampf((time-0.25-float(j)*0.12)/0.65,0.0,1.0)
			var at:=from.lerp(center,progress)+side*sin(progress*PI)*(60.0+float(j)*35.0)
			a.table.pos[row]=at
			a.table.r[row]=(26.0+float(j)*6.0)*(1.0-progress*0.7)
			state.vortex.feed.append(Vector3(at.x,at.y,a.table.r[row]))
	if time>=1.2 and not state.has("launched"):
		state.launched=true
		state.vortex.life=0.0
		for row in state.rows:a.manager.enemies.mark_dead(row)
		var direction: Vector2=state.direction
		var points:=PackedVector2Array([state.center-direction*45.0,state.center+direction*45.0])
		a.attack_field.add_shape(points,float(p.tornado_width),0.0,float(p.tornado_life),float(p.lump_dmg),&"tornado",wind.row,direction*float(p.tornado_speed),true)
		a._cue(&"attack_started",a.tech,a.necks.find(wind))

func debris_shatter()->void:
	var p: Dictionary=a.def.params
	var debris=a.participants[0]
	var beam=a.participants[1]
	if not state.has("deployed"):
		state.deployed=true
		state.aim=(a.run_state.ship_pos-beam.strike_pos).angle()
		for j in int(p.rubble_count):
			var offset: float=(float(j)/maxf(1.0,float(p.rubble_count)-1.0)-0.5)*1.4
			var at: Vector2=beam.strike_pos+Vector2.from_angle(float(state.aim)+offset)*420.0
			var row: int=a.manager.enemies.spawn(a.manager.enemies.def_of(&"hydra_rubble"),debris.strike_pos)
			a._rubble.append(Vector2i(row,a.table.id[row]))
			a.table.vel[row]=Vector2.ZERO
			state[row]={"from":debris.strike_pos,"to":at}
	if time<0.7:
		for ref in a._rubble:
			a.table.pos[ref.x]=Vector2(state[ref.x].from).lerp(state[ref.x].to,clampf(time/0.7,0.0,1.0))
	if time>=0.7 and time<2.5:
		beam.angle=float(state.aim)-0.9+1.8*clampf((time-0.7)/1.8,0.0,1.0)
		var points:=PackedVector2Array([beam.strike_pos,beam.strike_pos+Vector2.from_angle(beam.angle)*float(p.beam_len)])
		if beam.emission.is_empty():beam.emission=a.attack_field.add_shape(points,float(p.beam_width),0.0,1.8,float(p.beam_dmg),&"beam",beam.row)
		else:beam.emission.points=points
		for ref in a._rubble.duplicate():
			if not a.manager.enemies.is_same(ref.x,ref.y) or a.table.dead[ref.x]:
				a._rubble.erase(ref)
				continue
			if Geometry2D.get_closest_point_to_segment(a.table.pos[ref.x],points[0],points[1]).distance_to(a.table.pos[ref.x])<=a.table.r[ref.x]+float(p.beam_width)*0.5:
				a._burst_rubble(ref.x,(a.table.pos[ref.x]-beam.strike_pos).normalized())
				a._rubble.erase(ref)
				a._cue(&"rubble_shattered",a.tech,a.necks.find(beam))

func beam_pincer()->void:
	var p: Dictionary=a.def.params
	if not state.has("aims"):
		state.aims=[]
		for n in a.participants:state.aims.append((a.run_state.ship_pos-n.strike_pos).angle())
	for j in a.participants.size():
		var n=a.participants[j]
		var side:=1.0 if j==0 else -1.0
		n.angle=float(state.aims[j])+side*lerpf(0.8,0.12,clampf((time-0.5)/1.8,0.0,1.0))
		var points:=PackedVector2Array([n.strike_pos,n.strike_pos+Vector2.from_angle(n.angle)*float(p.beam_len)])
		if n.emission.is_empty():n.emission=a.attack_field.add_shape(points,float(p.beam_width),0.5,1.8,float(p.beam_dmg),&"beam",n.row)
		else:n.emission.points=points


## 配置の途中も同じ操舵を使う。到着まで攻撃の時間軸を進めない。
func position(dt: float)->bool:
	state.position_elapsed+=dt
	if state.position_elapsed>float(a.def.params.formation_timeout):
		a.interrupt_tech()
		return false
	var ready:=true
	for i in a.participants.size():
		var n=a.participants[i]
		if not a._alive(n):continue
		if not state.arrived.has(i):
			if a.tech==&"grid" and n.free_pos.distance_to(state.slots[i])<45.0:
				n.velocity=(state.slots[i]-n.free_pos).limit_length(100.0)
				n.free_pos+=n.velocity*dt*4.0
			else:a.steer_snake(n,state.slots[i],dt,1.8,true)
		n.strike_pos=n.free_pos
		a.table.pos[n.row]=n.free_pos
		if n.free_pos.distance_to(state.slots[i])<=float(a.def.params.grid_tolerance if a.tech==&"grid" else a.def.params.formation_tolerance):state.arrived[i]=true
		if not state.arrived.has(i):ready=false
	if a.tech==&"grid" and a.immortal_neck.free_pos.distance_to(state.plan.bearer)>float(a.def.params.grid_tolerance):ready=false
	if ready and not a.participants.filter(func(n):return a._alive(n)).all(func(n):return a.run_state.view_rect().grow(-a.table.r[n.row]).has_point(n.strike_pos)):
		a.interrupt_tech()
		return false
	if ready:
		positioning=false
		for n in a.participants:
			n.strike_from=n.strike_pos
			var direction: Vector2=(a.run_state.ship_pos-n.strike_pos).normalized()
			n.target=n.strike_pos+direction*float(a.def.params.swarm_reach)
			var hit: Dictionary=a.manager.field.arena_hit(n.strike_pos,n.target,a.table.r[n.row])
			if not hit.is_empty():n.target=hit.pos
	return ready

func swarm(dt: float)->void:
	var p: Dictionary=a.def.params
	for i in a.participants.size():
		var n=a.participants[i]
		if not a._alive(n):continue
		var local: float=time-i*float(p.swarm_gap)
		if local<0.0:continue
		if n.emission.is_empty():n.emission=a.attack_field.add_shape(PackedVector2Array([n.strike_from,n.target]),float(p.bite_radius),float(p.sequence_charge),0.001,0.0,&"bite",n.row)
		if local<float(p.sequence_charge):continue
		if not n.locked:
			n.locked=true
			n.angle=(n.target-n.strike_from).angle()
			a._cue(&"target_locked",a.tech,a.necks.find(n))
			a._cue(&"attack_started",a.tech,a.necks.find(n))
		var f:=clampf((local-float(p.sequence_charge))/float(p.swarm_flight),0.0,1.0)
		if n.mode!=&"special_hold":
			var before: Vector2=n.strike_pos
			n.strike_pos=n.strike_from.lerp(n.target,f)
			n.free_pos=n.strike_pos
			a.attack_field.add_shape(PackedVector2Array([before,n.strike_pos]),float(p.bite_radius),0.0,dt+0.001,float(p.bite_dmg),&"bite",n.row)
			if f>=1.0:n.mode=&"special_hold"


func grid()->void:
	var p: Dictionary=a.def.params
	for i in a.participants.size():
		var n=a.participants[i]
		if not a._alive(n) or not n.emission.is_empty():continue
		var points:=PackedVector2Array([n.strike_pos,state.plan.beams[i][1]])
		n.angle=(points[1]-points[0]).angle()
		n.emission=a.attack_field.add_shape(points,float(p.beam_width),float(p.normal_charge),float(p.grid_time),float(p.beam_dmg),&"beam",n.row)
		n.mode=&"special_hold"
		a._cue(&"attack_started",a.tech,a.necks.find(n))
