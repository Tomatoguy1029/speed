extends Node
var failed := 0
func check(ok: bool,label: String) -> void:
	print("[hydra-revision] ","PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func _ready() -> void:
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[-220,0]})
	var run: RunSimulation=lab.run
	check(run.state.stage.boss_id==&"hydra","stage four selects playable hydra encounter")
	run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=run.bosses.lab_instances.back().actor
	a.hsm.set_active(false)
	run.state.stats.attack_mult=0.01
	var hp: float=a.table.hp[a.body]
	run.combat.rebuild_grid()
	run.state.ship_pos=Vector2.ZERO
	run.state.ship_vel=Vector2.DOWN*1000.0
	run.state.tracing=true
	var bounced:=run.combat.collide_ship(Vector2(0,-220),run.cfg.trace_radius,TraceRun.new())
	check(not bounced and a.table.hp[a.body]<hp,"weak ram damages central rubble without armor reflection")
	check(not run.state.events.any(func(e):return e.type==&"block_impact"),"central hit does not emit shield impact")
	run.state.tracing=false
	a.table.facing[a.body]=0.0
	var head=a.necks[0]
	head.angle=0.0
	head.motion.clear()
	var last_speed:=0.0
	var peak_change:=0.0
	for step in 90:
		run.state.ship_pos=a._neck_base(head)+Vector2(-200,1 if step%2 else -1)
		var before: float=head.angle
		a.position_head(0,1.0/60.0)
		var speed:=angle_difference(before,head.angle)*60.0
		peak_change=maxf(peak_change,absf(speed-last_speed))
		last_speed=speed
	check(peak_change<0.25,"idle head does not flip tracking direction every frame behind root")
	var wind=a._first(&"vortex")
	a.table.facing[a.body]=-wind.base_angle
	wind.angle=0.0
	wind.cd=0.0
	run.state.ship_pos=a._head_pos(wind)+Vector2(200,0)
	var aimed: Vector2=run.state.ship_pos
	check(a.start_normal(a.necks.find(wind),&"wind_band"),"wind attack begins from valid pose")
	run.state.ship_pos=aimed+Vector2(0,500)
	wind.t=0.3
	a.NORMALS.tick(a,wind,1.0/60.0)
	check(wind.target==aimed,"windup keeps captured aim instead of chasing player each frame")
	a._set_count(8)
	a.begin_separation()
	a.separation_t=0.0
	a.table.guard[a.immortal_row]=0.0
	check(run.combat.can_pierce(0.01,a.immortal_row,false),"compass bearer is directly pierceable with guards alive")
	await lab.reset({"empty":true,"stage":4,"ship_pos":[500,0]})
	run=lab.run
	run.state.stage.boss_enabled=true
	run.state.boss_spawned=false
	run.state.boss_at=0.0
	run.bosses.tick(0.01,0.01)
	check(run.bosses.actor!=null and run.bosses.actor.def.id==&"hydra","normal timed boss spawn loads hydra without override")
	a=run.bosses.actor
	a.hsm.set_active(false)
	a.interrupt_tech()
	a._set_count(8)
	a.recovery_t=0.0
	a.combo_wait=0.0
	a._tech_until.clear()
	a._tech_cd=0.0
	check(a.try_start_tech(&"tornado",1.0),"rubble wind combo starts")
	var rendered:=false
	var feed_seen:=false
	for step in 170:
		a.sim_tick(0.025,0.025)
		for e in a.attack_field.effects:
			if e.kind==&"tornado_charge" and e.get("feed",[]).size()==3:feed_seen=true
			if e.kind==&"tornado":
				var visual=a.attack_field.visuals[e.id]
				rendered=visual.get("stones")!=null and visual.stones.size()>=10
	check(feed_seen and rendered,"rubble feed leads to shader vortex with orbiting stone sprites")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
