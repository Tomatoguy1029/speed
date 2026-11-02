extends Node
var failed:=0
func check(ok: bool,label: String)->void:
	print("[hydra-victory] ","PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func _ready()->void:
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[400,0]})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=lab.run.bosses.actors.back()
	a.hsm.set_active(false)
	a._set_count(8)
	a.begin_separation()
	a.separation_t=0.0
	a.table.guard[a.immortal_row]=0.0
	check(a.has_method("health_row") and a.health_row()==a.immortal_row,"upper health source switches to compass bearer")
	for n in a.necks:
		a.table.guard[n.row]=0.0
		lab.run.combat.damage_enemy(n.row,100000.0,{"cause":&"weapon"})
	lab.run.enemies.cleanup()
	var attack_seen:=false
	var hold_seen:=false
	for i in 400:
		a.sim_tick(0.025,0.025)
		if a.immortal_neck.mode!=&"idle":attack_seen=true
		if a.immortal_neck.locked and a.immortal_neck.glow<=0.0:hold_seen=true
	check(attack_seen and hold_seen,"lone bearer turns back to bite then exposes its head")
	lab.run.combat.damage_enemy(a.immortal_row,100000.0,{"cause":&"weapon"})
	lab.run.enemies.cleanup()
	a.sim_tick(0.025,0.025)
	var wins: int=lab.run.state.events.filter(func(e):return e.type==&"boss_defeated").size()
	check(wins==1,"only bearer death emits one final victory")
	check(a.attack_field.effects.is_empty(),"final victory clears owned attack geometry")
	check(not a.has_body(),"lab final cleanup releases encounter owner")
	check(not lab.run.state.boss_dead and lab.run.state.modules_obtained.is_empty(),"lab victory leaves campaign progression untouched")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
