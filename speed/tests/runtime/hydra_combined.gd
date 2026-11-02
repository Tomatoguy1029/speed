extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	print("[hydra-combined] ", "PASS " if ok else "FAIL ", label)
	if not ok: failed += 1
func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty": true,"stage":4,"ship_pos":[500,0]})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a = lab.run.bosses.actors.back()
	a.hsm.set_active(false)
	a._tech_cd = 0.0
	check(not a.attack_ready(&"north"),"combined major attack requires at least five heads")
	a._set_count(5)
	check(a.try_start_tech(&"north",1.0),"five-head configuration can start simultaneous bite")
	for i in 60: a.sim_tick(0.05,0.05)
	var hold: Array = a.necks.filter(func(n):return n.mode == &"tech_hold")
	check(hold.size()==3,"only three front heads bite and stop")
	if hold.size()==3:
		check(absf((hold[1].strike_pos-hold[0].strike_pos).cross(hold[2].strike_pos-hold[0].strike_pos)) < 1.0,"stopped heads form a single stroke line")
		var safe := true
		for n in a.necks:
			for j in range(n.segs.size()-1):
				if Geometry2D.get_closest_point_to_segment(Vector2.ZERO,n.segs[j],n.segs[j+1]).length() < a.table.r[a.body]-1.0: safe=false
		check(safe,"neck segments stay outside the body")
		lab.run.combat.damage_enemy(hold[0].row,1e6,{"cause":&"weapon"})
		lab.run.enemies.cleanup()
		a.sim_tick(0.01,0.01)
		check(not a.busy and a.recovery_t>0.0,"loss of participant interrupts into global counterattack window")
	lab.queue_free()
	await get_tree().process_frame
	var cases_lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(cases_lab)
	await cases_lab.reset({"empty": true,"stage":4,"ship_pos":[500,0]})
	cases_lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var cases_actor = cases_lab.run.bosses.actors.back()
	cases_actor.hsm.set_active(false)
	for degrees in [0.0,36.0,90.0,180.0,270.0]:
		cases_actor.interrupt_tech()
		cases_actor.recovery_t=0.0
		cases_actor._tech_cd=0.0
		cases_actor._tech_until.clear()
		cases_actor.table.facing[cases_actor.body]=0.0
		cases_actor._set_count(5)
		cases_actor.run_state.ship_pos=Vector2.from_angle(deg_to_rad(degrees))*500.0
		check(cases_actor.try_start_tech(&"north",1.0),"five-head bite can start from angle "+str(degrees))
		for i in 49: cases_actor.sim_tick(0.05,0.05)
		var heading: float=(cases_actor.run_state.ship_pos-cases_actor.table.pos[cases_actor.body]).angle()
		check(cases_actor.participants.size()==3 and cases_actor.participants.all(func(n):return absf(angle_difference(n.base_angle+cases_actor.table.facing[cases_actor.body],heading))<PI*0.5),"body turn puts three chosen sockets on player side")
	cases_actor.interrupt_tech()
	cases_actor.recovery_t=0.0
	cases_actor._set_count(8)
	for i in range(1,cases_actor.necks.size()):
		cases_lab.run.combat.damage_enemy(cases_actor.necks[i].row,100000.0,{"cause":&"weapon"})
	cases_lab.run.enemies.cleanup()
	cases_actor._tech_cd=0.0
	cases_actor.combo_wait=0.0
	check(not cases_actor.attack_ready(&"sequence") and not cases_actor.attack_ready(&"tornado") and not cases_actor.attack_ready(&"curve"),"one surviving head never waits on an impossible combined technique")
	cases_lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
