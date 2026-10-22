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
		for i in 200:
			a.sim_tick(0.025,0.025)
			peak=maxi(peak,a.attack_field.effects.size())
			for e in a.attack_field.effects:
				if e.points.size()>3:curve=true
		check(peak>0,"timeline produces gameplay geometry")
		if name==&"sequence":
			var times: Array=events.filter(func(e):return e.cue==&"attack_started" and e.neck_index>=0).map(func(e):return e.world_time)
			check(times.size()==3 and times[2]-times[0]>0.5,"three heads attack in distinct ordered beats")
		if name==&"curve":check(curve,"rotating beam uses a curved shared polyline")
		check(not a.busy and a.last_tech==name,"tech completes and releases global attack slot")
		check(a._tech_until.has(name),"completed technique has an individual cooldown")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
