extends Node
var failed:=0
func check(ok: bool,label: String)->void:
	print("[hydra-motion] ","PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func _ready()->void:
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[500,0]})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=lab.run.bosses.lab_instances.back().actor
	a.hsm.set_active(false)
	a._set_count(8)
	a.begin_separation()
	a.separation_t=0.0
	var n=a.necks[0]
	n.cd=1000.0
	var angles: Array=[]
	var max_turn:=0.0
	var moving_turn:=false
	for i in 160:
		var before: float=n.angle
		a.sim_tick(0.025,0.025)
		max_turn=maxf(max_turn,absf(angle_difference(before,n.angle)))
		if absf(angle_difference(before,n.angle))>0.001 and n.velocity.length()>30.0:moving_turn=true
		angles.append(n.angle)
	check(max_turn<0.2 and moving_turn,"guard changes heading continuously while moving")
	check(n.segs.size()>8 and n.segs[-1].distance_to(a._head_pos(n))<0.001,"body follows exact head while turning")
	check(not n.motion.is_empty() and n.motion.has("weights"),"runtime locomotion blends motion channels")
	if n.motion.has("weights"):
		a.table.hp[n.row]-=1.0
		a.sim_tick(0.025,0.025)
		check(float(n.motion.weights.get("hit",0.0))>0.0,"damage blends recoil without replacing locomotion")
	var shape: PackedVector2Array=n.segs.duplicate()
	var at: Vector2=n.free_pos
	a.sim_tick(0.0,0.0)
	check(shape==n.segs and at==n.free_pos,"world pause preserves posture and position")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
