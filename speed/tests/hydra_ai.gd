## 実際のLimboAIツリーで、形態・欠員・重み・中断・世界時間を確かめる。
extends Node
var failures:=0
func check(ok: bool,label: String)->void:
	print("[hydra-ai] ","PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _ready()->void:
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[400,0]})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=lab.run.bosses.lab_instances.back().actor
	a.hsm.set_active(false)
	a._tech_cd=0.0
	check(not a.attack_ready(&"north") and not a.attack_ready(&"sequence"),"three-head phase uses normals and eligible combos")
	a._set_count(8)
	var root: BTTask=a.decision.get_bt_instance().get_root_task()
	var combo: BTTask=root.get_child(0)
	var majors: BTTask=root.get_child(1)
	for i in combo.get_child_count():combo.set_weight(i,0.0)
	for i in majors.get_child_count():majors.set_weight(i,0.0)
	a._update_blackboard()
	check(root.execute(0.01)==BTTask.FAILURE and not a.busy,"zero weights disable every major and combo")
	majors.set_weight(1,1.0)
	root.abort()
	check(root.execute(0.01)==BTTask.RUNNING and a.tech==&"sequence","editable tree weight selects sequential bites")
	var clock: float=a.timeline.current_animation_position
	a.sim_tick(0.5,0.0)
	check(a.timeline.current_animation_position==clock,"world pause freezes gameplay timeline")
	var participant=a.participants[0]
	lab.run.combat.damage_enemy(participant.row,100000.0,{"cause":&"weapon"})
	lab.run.enemies.cleanup()
	a.sim_tick(0.01,0.01)
	check(not a.busy and a.recovery_t>0.0,"participant death interrupts combined bite and opens recovery")
	root.abort()
	a.recovery_t=0.0
	a._tech_cd=0.0
	a.combo_wait=0.0
	for n in a.necks:
		if a._alive(n) and n.kind==&"beam":lab.run.combat.damage_enemy(n.row,100000.0,{"cause":&"weapon"})
	lab.run.enemies.cleanup()
	check(not a.attack_ready(&"beam_pincer") and not a.attack_ready(&"debris_shatter"),"missing beam kinds remove their combo candidates")
	check(a.attack_ready(&"tornado"),"different surviving kinds keep their combo available")
	check(lab.run.bosses.actor_for_row(a.body)==a,"lab renderer resolves encounter owner")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
