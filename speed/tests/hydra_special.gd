extends Node
var failed := 0
func check(ok: bool,label: String)->void:
	print("[hydra-special] ","PASS " if ok else "FAIL ",label)
	if not ok: failed+=1
func _ready()->void:
	var name:=&"sequence"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tech="):name=StringName(arg.trim_prefix("--tech="))
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[500,0]})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=lab.run.bosses.lab_instances.back().actor
	a.hsm.set_active(false)
	a._set_count(8)
	a._tech_cd=0.0
	var events: Array=[]
	a.presentation_event.connect(func(e):events.append(e))
	check(a.attack_ready(name),String(name)+" eligible for current composition")
	if a.attack_ready(name):
		check(a.try_start_tech(name,1.0),"special starts through admission")
		var peak:=0
		var curve:=false
		var tornado_owned:=false
		var owners: Dictionary={}
		for i in 200:
			a.sim_tick(0.025,0.025)
			peak=maxi(peak,a.attack_field.effects.size())
			for e in a.attack_field.effects:
				if e.kind==&"beam":owners[e.owner]=true
				if e.points.size()>3:curve=true
				if e.kind==&"tornado" and e.velocity.length()>0.0:
					tornado_owned=e.owner==a.participants[0].row and a.participants[0].kind==&"vortex" and e.width>150.0
		check(peak>0,"timeline produces gameplay geometry")
		if name==&"sequence":
			var times: Array=events.filter(func(e):return e.cue==&"attack_started" and e.neck_index>=0).map(func(e):return e.world_time)
			check(times.size()==3 and times[2]-times[0]>0.5,"three heads attack in distinct ordered beats")
		if name==&"curve":check(curve,"rotating beam uses a curved shared polyline")
		if name==&"tornado":
			check(tornado_owned,"vortex head launches a broad moving rubble tornado")
			var order: Array=events.filter(func(e):return e.cue in [&"gather_started",&"attack_started"] and e.neck_index>=0)
			check(order.size()>=2 and order[0].cue==&"gather_started" and order[-1].world_time>order[0].world_time,"gather and rubble feed precede vortex launch")
			check(a.combo_wait>0.0 and not a.attack_ready(&"tornado"),"combo opportunity consumes a common cooldown")
		if name==&"debris_shatter":check(events.filter(func(e):return e.cue==&"rubble_shattered").size()==int(a.def.params.rubble_count),"beam intersection shatters each physical rubble once")
		if name==&"beam_pincer":check(owners.size()==2 and a.participants[0]!=a.participants[1],"two distinct beam heads each own one ray")
		check(not a.busy and a.last_tech==name,"tech completes and releases global attack slot")
		check(a._tech_until.has(name),"completed technique has an individual cooldown")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
