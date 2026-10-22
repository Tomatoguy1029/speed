## 実際の接触入口と残像再生で、ボスの自力移動と外力を区別する。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	print("[boss-knockback] ","PASS " if ok else "FAIL ",label)
	if not ok: failed += 1

func check_target(run: RunSimulation, row: int, label: String) -> void:
	var t := run.enemies.table
	var original_hp := t.hp[row]
	var moving := Vector2(35,-12)
	t.vel[row]=moving
	for cause in [&"ram",&"touch",&"sonic"]:
		run.combat.damage_enemy(row,1.0,{"cause":cause,"dir":Vector2.RIGHT,"knock":1500.0,"no_crit":true})
	check(is_equal_approx(t.hp[row],original_hp-3.0),label+" receives unchanged damage")
	check(t.vel[row]==moving and t.knock_t[row]==0.0,label+" keeps AI velocity after damage")
	run.loadout.weapon_behaviors[&"W03"].on_contact(row,t.pos[row],Vector2.RIGHT)
	check(t.vel[row]==moving and t.shove_time[row]==0.0 and t.shove_vel[row]==Vector2.ZERO,label+" rejects contact shove")
	t.vel[row]=Vector2.ZERO

func _ready() -> void:
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[-240,0],"config":{"base_attack":20.0}})
	var run: RunSimulation=lab.run
	run.loadout.reset_loadout()
	run.loadout.grant(&"weapon",&"W03",5)
	run.loadout.grant(&"weapon",&"W27",5)
	run.combat.ignore_armor=true
	run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=run.bosses.actors.back()
	a.hsm.set_active(false)
	for n in a.necks:n.cd=1e6
	check_target(run,a.body,"combined core")
	check_target(run,a.necks[0].row,"attached head")
	# 同じ経路を時間差で通る5機が、本体の押し流しで外れない。
	var origin: Vector2=a.table.pos[a.body]
	var id: int=a.table.id[a.body]
	lab.perform("route",{"points":[[-240,0],[240,0]],"draw_seconds":0.2})
	for step in 150:
		lab.step()
		if run.state.dash_id>0 and not run.state.tracing and not run.state.drawing and lab.pinned==null:lab.pinned=run.state.ship_pos
	check(a.table.pos[a.body].distance_to(origin)<0.01,"contact cannot slide engaged core away from recorded route")
	var echo_hits:=0
	for event in lab.events:
		if event.get("type",&"")==&"hit" and event.get("id",-1)==id and event.get("cause",&"")==&"afterimage":echo_hits+=1
	check(echo_hits==5,"all five delayed echoes hit core on same route")
	run.state.ship_pos=Vector2(900,0)
	var before: Vector2=a.table.pos[a.body]
	a._move(0.2)
	# engage外の目標へ泳ぐ能力は維持する。
	run.state.ship_pos=Vector2(1600,0)
	a._move(0.2)
	check(a.table.pos[a.body].distance_to(before)>0.01,"boss still swims under its own AI")
	a._set_count(8)
	a.begin_separation()
	a.separation_t=0.0
	for n in a.necks:a.table.guard[n.row]=0.0
	a.table.guard[a.immortal_row]=0.0
	a.sim_tick(0.025,0.025)
	check_target(run,a.necks[0].row,"separated guard")
	check_target(run,a.immortal_row,"compass bearer")
	a.sim_tick(0.025,0.025)
	check(float(a.necks[0].motion.weights.hit)>0.0,"damage recoil animation remains active")
	var grunt: int=run.enemies.spawn(run.enemies.def_of(&"drifter"),Vector2(800,800))
	run.loadout.weapon_behaviors[&"W03"].on_contact(grunt,a.table.pos[grunt],Vector2.RIGHT)
	check(a.table.shove_time[grunt]>0.0 and a.table.vel[grunt].length()>0.0,"ordinary enemies still receive contact knockback")
	run.bosses.spawn_lab(&"provisional",Vector2(600,0))
	var provisional=run.bosses.actors.back()
	check_target(run,provisional.body,"provisional boss")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
