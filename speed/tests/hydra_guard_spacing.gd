extends Node
var failed:=0
func check(ok: bool,label: String)->void:
	print("[hydra-guard] ","PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func _ready()->void:
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[400,0]})
	var run: RunSimulation=lab.run
	run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=run.bosses.actors.back()
	a.hsm.set_active(false)
	a._set_count(8)
	a.begin_separation()
	a.separation_t=0.0
	for n in a.necks:n.cd=1000.0
	run.state.ship_pos=a.arena.bounds.end-Vector2(240,240)
	run.state.view_center=run.state.ship_pos
	for step in 800:a.sim_tick(0.025,0.025)
	var cells: Dictionary={}
	var min_distance:=INF
	var max_distance:=0.0
	var extent:=Rect2(a._head_pos(a.necks[0]),Vector2.ZERO)
	var pair_total:=0.0
	var pairs:=0
	for i in a.necks.size():
		var at: Vector2=a._head_pos(a.necks[i])
		cells[Vector2i((at/200.0).floor())]=true
		extent=extent.expand(at)
		max_distance=maxf(max_distance,at.distance_to(a._head_pos(a.immortal_neck)))
		for j in range(i+1,a.necks.size()):
			var distance:=at.distance_to(a._head_pos(a.necks[j]))
			min_distance=minf(min_distance,distance)
			pair_total+=distance
			pairs+=1
	print("[hydra-guard] cells=",cells.size()," minimum=",min_distance," bearer_distance=",max_distance," extent=",extent.size," average_pair=",pair_total/pairs)
	check(cells.size()>=6 and min_distance>140.0 and pair_total/pairs>550.0,"idle guards spread across separate positions instead of clumping in the viewport")
	check(max_distance<1400.0,"spread guards remain around the compass bearer")
	check(a.necks.all(func(n):return a.arena.bounds.has_point(a._head_pos(n))),"guard patrol stays inside rubble arena")
	check(is_equal_approx(a.def.params.head_hp,360.0) and is_equal_approx(a.def.params.regrow,4.0),"approved HP and regrowth values are active")
	check(is_equal_approx(a.def.params.chance_time,5.0) and is_equal_approx(a.def.params.fire_regrow_scale,3.0),"all-head recovery opening and fire delay are preserved")
	var warned: Dictionary={}
	a.presentation_event.connect(func(e):
		if e.cue==&"warning_started" and e.neck_index>=0:warned[e.neck_index]=true)
	for n in a.necks:n.cd=0.0
	var within_budget:=true
	for step in 600:
		a.sim_tick(0.025,0.025)
		var used:=0.0
		for n in a.necks:
			if a.def.params.normal_rules.has(n.mode):used+=float(a.def.params.normal_rules[n.mode].cost)*a.table.attack_value[n.row]
		within_budget=within_budget and used<=float(a.def.params.normal_budget)+0.001
	check(warned.size()>=3,"different spread guards enter the viewport and take turns attacking")
	check(within_budget,"guard approach preserves the existing attack budget")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
