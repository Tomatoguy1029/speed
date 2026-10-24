## 共通フローで、形態・欠員・確率・中断・世界時間を確かめる。
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
	var a=lab.run.bosses.actors.back()
	a.hsm.set_active(false)
	a._tech_cd=0.0
	check(not a.attack_ready(&"north") and not a.attack_ready(&"sequence"),"three-head phase uses normals and eligible combos")
	a._set_count(8)
	var selector=a.flow_runner.selector
	var candidates: Array=a.flow_adapter.candidates({"request":"major"}).candidates
	check(selector.choose(candidates,{"weights":{"major":0.0}},[]).is_empty() and not a.busy,"zero weights disable every major")
	var sequence: Array=candidates.filter(func(c):return c.id=="sequence")
	var chosen: Array=selector.choose(sequence,{"weights":{"major":1.0}},[])
	check(not chosen.is_empty() and a.flow_adapter.start(chosen) and a.tech==&"sequence","section weights select sequential bites")
	var clock: float=a.timeline.current_animation_position
	a.sim_tick(0.5,0.0)
	check(a.timeline.current_animation_position==clock,"world pause freezes gameplay timeline")
	var participant=a.participants[0]
	lab.run.combat.damage_enemy(participant.row,100000.0,{"cause":&"weapon"})
	lab.run.enemies.cleanup()
	a.sim_tick(0.01,0.01)
	check(not a.busy and a.recovery_t>0.0,"participant death interrupts combined bite and opens recovery")
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
