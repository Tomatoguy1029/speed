extends Node
var failed:=0
func check(ok: bool,label: String)->void:
	print("[hydra-cases] ","PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func _ready()->void:
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[500,0]})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=lab.run.bosses.actors.back()
	a.hsm.set_active(false)
	for degrees in [0.0,36.0,90.0,180.0,270.0]:
		a.interrupt_tech()
		a.recovery_t=0.0
		a._tech_cd=0.0
		a._tech_until.clear()
		a.table.facing[a.body]=0.0
		a._set_count(5)
		a.run_state.ship_pos=Vector2.from_angle(deg_to_rad(degrees))*500.0
		check(a.try_start_tech(&"north",1.0),"five-head bite can start from angle "+str(degrees))
		for i in 49:a.sim_tick(0.05,0.05)
		var heading: float=(a.run_state.ship_pos-a.table.pos[a.body]).angle()
		check(a.participants.all(func(n):return absf(angle_difference(n.base_angle+a.table.facing[a.body],heading))<PI*0.5),"small body turn puts all three chosen sockets on player side")
	a.interrupt_tech()
	a.recovery_t=0.0
	a._set_count(8)
	for n in a.necks:
		if a.necks.find(n)>0:
			lab.run.combat.damage_enemy(n.row,100000.0,{"cause":&"weapon"})
	lab.run.enemies.cleanup()
	a._tech_cd=0.0
	a.combo_wait=0.0
	check(not a.attack_ready(&"sequence") and not a.attack_ready(&"tornado") and not a.attack_ready(&"curve"),"one surviving head never waits on an impossible combined technique")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
