extends Node
var failed:=0
func check(ok: bool,label: String)->void:
	print("[hydra-live] ","PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func _ready()->void:
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[400,0]})
	var run: RunSimulation=lab.run
	var wall_enemy:=run.enemies.spawn(run.enemies.def_of(&"biter"),Vector2(1900,0))
	var rock:=FieldSystem.Rock.new()
	rock.kind=&"iron"
	rock.pos=Vector2(1900,200)
	rock.size=40.0
	rock.lab_manual=true
	run.field.rocks.append(rock)
	var gem:=run.pickups.drop_gem(Vector2(1850,0),17.0)
	run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=run.bosses.actors.back()
	a.hsm.set_active(false)
	check(a.table.pos[wall_enemy].x<1800.0 and a.table.pos[wall_enemy].x>0.0,"arena installation clears enemy from rubble footprint")
	check(run.pickups.gem_pos[gem].x<1800.0 and run.pickups.gem_value[gem]==17.0,"arena installation preserves and clears buried XP")
	run.field.gimmick(&"meteors")._stream_rocks(0.02)
	check(rock.pos.x<1800.0 and rock.row>=0 and a.table.pos[rock.row].x<1800.0,"streamed rock source stays clear after arena installation")
	var d=load("res://scripts/encounters/attack_director.gd").new()
	d.state=run.state
	d.projectiles=run.projectiles
	d.formation_mode=true
	d.configure({"enabled":true,"budget":0.0})
	run.projectiles.director=d
	var n=a.necks[0]
	n.cd=0.0
	n.length=230.0
	run.state.ship_pos=a._head_pos(n)+Vector2(100,0)
	run.state.view_center=a._head_pos(n)
	check(a.start_normal(0,&"bite_thrust"),"normal attack uses boss budget while stage mob budget is zero")
	a.finish_normal(n)
	a.combo_wait=100.0
	var warnings:=0
	a.presentation_event.connect(func(e):
		if e.cue==&"warning_started":a.set_meta("live_warnings",int(a.get_meta("live_warnings",0))+1))
	for step in 350:
		a.sim_tick(0.02,0.02)
	warnings=int(a.get_meta("live_warnings",0))
	check(warnings>0,"actual head BehaviorTree starts attacks under zero stage budget")
	a._set_count(5)
	a.recovery_t=0.0
	a._tech_cd=0.0
	check(a.try_start_tech(&"curve",1.0),"major attack starts with zero mob budget")
	a.interrupt_tech()
	a.table.guard[a.body]=0.0
	var body_hp: float=a.table.hp[a.body]
	run.combat.damage_enemy(a.body,run.combat.attack_power()*0.7,{"cause":&"shot"})
	check(a.table.hp[a.body]>0.0 and is_equal_approx(body_hp-a.table.hp[a.body],run.combat.attack_power()*0.7),"ordinary weapon hit subtracts its damage rather than executing the boss")
	run.state.ship_pos=a.table.pos[a.body]
	run.combat.rebuild_grid()
	var wave_hp: float=a.table.hp[a.body]
	run.projectiles.attached_attack(&"sonic").fire(&"sonic",300.0,7.0,0.0,0.5)
	for step in 6:run.projectiles.tick_attached(0.1)
	check(is_equal_approx(wave_hp-a.table.hp[a.body],7.0),"one real sonic wave hits the core once across its lifetime")
	a.begin_separation()
	a.separation_t=0.0
	var plan: Dictionary=a.grid_plan()
	check(not plan.is_empty(),"clear field permits grid formation")
	if not plan.is_empty():
		var obstruction:=FieldSystem.Body.new()
		obstruction.pos=plan.bearer
		obstruction.r=100.0
		run.field.bodies.append(obstruction)
		check(a.grid_plan().is_empty(),"grid never starts with the bearer destination inside a planet")
		run.field.bodies.erase(obstruction)
	run.enemies.clear_regular()
	check(a._alive(a.immortal_neck) and a.necks.all(func(h):return a._alive(h)),"regular-enemy clearing preserves living boss snakes")
	for h in a.necks:
		if a._alive(h):run.enemies.mark_dead(h.row)
	a.immortal_neck.cd=0.0
	run.state.ship_pos=Vector2(350,100)
	a.tick_bearer(0.02)
	check(a.immortal_neck.target==run.state.ship_pos,"lone bearer captures the current player for its bite")
	a.table.guard[a.immortal_row]=0.0
	var bearer_hp: float=a.table.hp[a.immortal_row]
	run.combat.damage_enemy(a.immortal_row,run.combat.attack_power()*0.7,{"cause":&"shot"})
	check(a.table.hp[a.immortal_row]>0.0 and is_equal_approx(bearer_hp-a.table.hp[a.immortal_row],run.combat.attack_power()*0.7),"ordinary weapon hit does not execute the compass bearer")
	a.immortal_neck.mode=&"idle"
	a.immortal_neck.cd=100.0
	var planet:=FieldSystem.Body.new()
	planet.pos=a.immortal_neck.free_pos+Vector2(80,0)
	planet.r=130.0
	run.field.bodies.append(planet)
	for step in 100:a.steer_snake(a.immortal_neck,planet.pos,0.02)
	check(a.immortal_neck.free_pos.distance_to(planet.pos)>=planet.r+a.table.r[a.immortal_row]-0.1,"bearer stays outside solid planet even when destination is inside")
	run.field.bodies.erase(planet)
	check(run.heroes.has_method("guidance_visible"),"hero guidance exposes a boss encounter visibility condition")
	if run.heroes.has_method("guidance_visible"):
		run.state.boss_spawned=false
		check(run.heroes.guidance_visible(),"hero guidance available before boss")
		run.state.boss_spawned=true
		check(not run.heroes.guidance_visible(),"hero arrows and map clues hidden after boss begins")
	check(is_equal_approx(a.table.max_hp[a.body],float(a.def.params.immortal_hp)*run.cfg.enemy_hp_mult),"separated main HP follows bearer data")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
