## 大技の配置と連続動作。開始・終了の時点はAnimationPlayerが決める。
extends RefCounted
var a: Node
var time:=0.0
var playing:=false
var positioning:=false
var state: Dictionary={}
func _init(actor: Node = null)->void:a=actor
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
		n.target=a.run_state.ship_pos
	if a.tech==&"curve":call("curve", 0.0)
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
			n.target=n.strike_pos+direction*float(a.move_params(a.tech).swarm_reach)
			var hit: Dictionary=a.ctx.field.arena_hit(n.strike_pos,n.target,a.table.r[n.row])
			if not hit.is_empty():n.target=hit.pos
	return ready

func tick(dt: float) -> void:
	if not playing: return
	time += dt
	perform(dt)
func perform(_dt: float) -> void: pass
func tick_neck(_a: Node, _neck, _dt: float) -> void: pass
