extends Node
var failed:=0
func check(ok: bool,label: String)->void:
	print("[hydra-split] ","PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func _ready()->void:
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[500,0]})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=lab.run.bosses.lab_instances.back().actor
	a.hsm.set_active(false)
	a._set_count(8)
	lab.run.combat.damage_enemy(a.necks[0].row,100000.0,{"cause":&"weapon"})
	lab.run.enemies.cleanup()
	lab.run.combat.damage_enemy(a.body,100000.0,{"cause":&"weapon"})
	for i in 140:a.sim_tick(0.025,0.025)
	check(a.separated and not a.separation_pending,"central destruction starts separated phase once")
	check(a.necks.size()==8 and a.necks.all(func(n):return a._alive(n) and is_equal_approx(a.table.hp[n.row],a.table.max_hp[n.row])),"all eight snakes recover on separation")
	check(a.immortal_row>=0 and a.manager.has_boss(),"compass bearer exists while encounter stays alive")
	if a.immortal_row>=0:
		var before: float=a.table.hp[a.immortal_row]
		lab.run.combat.damage_enemy(a.immortal_row,10.0,{"cause":&"weapon"})
		check(a.table.hp[a.immortal_row]<before,"immortal accepts ordinary damage with guards alive")
		var n=a.necks[0]
		lab.run.combat.damage_enemy(n.row,100000.0,{"cause":&"weapon"})
		lab.run.enemies.cleanup()
		n.regrow=0.0
		for i in 100:a.sim_tick(0.05,0.05)
		check(n.row<0,"separated snake death is permanent")
		check(not lab.run.state.boss_dead,"central destruction never signals final victory")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
