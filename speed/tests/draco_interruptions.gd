extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok: failed+=1;push_error(message)
func _ready() -> void: run_test()
func run_test() -> void:
	var root := get_tree().root
	var content = root.get_node("ContentManager")
	var manager = root.get_node("RunManager")
	var stage: RuntimeStage=content.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session: RunSession = manager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":205},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var actor=sim.bosses.actor
	actor.selection_enabled=false
	sim.state.enemy_aim=Vector2(300,0)
	check(not actor.technique_ready(&"inhale",actor.action_rules.conditions.inhale),"序盤に吸引を選ばない")
	check(not actor.technique_ready(&"clones",actor.action_rules.conditions.clones),"序盤に複製を選ばない")
	for id in actor._moves:
		for progress in [0,1,2]:
			actor.cancel_attack();actor.cycle.cancel();actor.picaro.clear()
			sim.projectiles.clear_hostile()
			actor.phase=1;actor.mode=&"idle"
			sim.enemies.table.hp[actor.body]=sim.enemies.table.max_hp[actor.body]
			sim.enemies.table.guard[actor.body]=0.0
			actor.start_attack(id)
			var p: Dictionary=actor.rule()
			var duration: float = float(p.warn)*0.5 if progress==0 else (float(p.warn)+0.1 if progress==1 else float(p.warn)+float(p.active)+0.1)
			for frame in ceili(duration*120.0): actor.sim_tick(1.0/120.0,1.0/120.0)
			var bullets:=sim.projectiles.hostile_count()
			sim.combat.damage_enemy(actor.body,1.0e8,{"cause":&"shot"})
			check(actor.phase==2,"各時点でHP段階を一つ進める: "+id)
			check(sim.projectiles.hostile_count()==bullets,"発射済みの弾を残す: "+id)
			check(actor._driver==null,"移行時に技の所有を解放する: "+id)
			check(not sim.state.boss_dead,"移行中に勝利しない: "+id)
	actor.cycle.cancel()
	session.free()
	print("[draco_interruptions] failures=",failed)
	get_tree().quit(1 if failed else 0)
