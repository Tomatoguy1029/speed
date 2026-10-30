## 猟犬の群れ生成・欠員・行再利用・仲間の速度・率いる指示を比較する。
extends "res://tests/native_forward.gd"
func _ready() -> void:
	var comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("follow_hound"):
		check(false,"猟犬の群れと走る先をネイティブが保持する")
	else:
		await compare_packs(comparison)
		await compare_waves(comparison)
		for division in [1,3]: await compare_frames(comparison,1,division,false,true,true,&"hound")
	probe.close()
	print("[native_hound] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func pack_snapshot(run: RunSimulation) -> Dictionary:
	var dogs = run.enemies.behavior(&"hound")
	var packs := []
	for key in dogs.packs:
		var members := []
		for row in dogs.packs[key]: members.append(run.enemies.table.id[row])
		packs.append({"id":key,"members":members})
	var follows := []
	for row in dogs.follows:
		var order: Array = dogs.follows[row]
		follows.append({"id":run.enemies.table.id[row],"goal":order[0],"until":order[1],"scale":order[2]})
	follows.sort_custom(func(a,b): return a.id < b.id)
	return {"packs":packs,"follows":follows}
func compare_packs(comparison) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":763,"empty":true})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.state.ship_pos = Vector2(1400,0)
	run.state.enemy_aim = run.state.ship_pos
	var definition := run.enemies.def_of(&"hound").duplicate(true) as EnemyDef
	definition.params.pack_count = 3
	definition.rank = 3
	var core = comparison.create_native()
	check(core.configure(DATA.compile_enemy(definition,run.cfg,run.state.stage)),"群れの編集値を生成する")
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.configure_bite_zone(DATA.compile_bite_zone(load("res://.content/attack_visuals.res")))
	core.start(763,run.enemies._next_id)
	run.state.rng.seed = 763
	core.set_motion_context(run.state.ship_pos,run.state.view_center,run.state.view_half)
	run.state.events.clear()
	var first := -1
	for i in 2:
		var options := {"attack_group":int(100+i),"attack_value":0.7,"attack_priority":4.0,"facing":0.37}
		if i == 0: options.vel = Vector2(80,40)
		var row := run.enemies.spawn(definition,Vector2(0,i*180),options)
		check(core.spawn_enemy(&"hound",Vector2(0,i*180),options) == run.enemies.table.id[row],"親と追加個体のID順を保持する")
		if i == 0: first = row
	check(comparison.plain(run.state.events) == comparison.plain(core.drain_events()),"追加個体を含む出現通知順が一致する")
	var dogs = run.enemies.behavior(&"hound")
	check(dogs.rows().size() == 6,"指定した数だけ2つの群れを生成する")
	for tick in 100:
		var row: int = dogs.rows()[0]
		if tick in [10,30]:
			var goal := Vector2(-200,400)
			var until := run.state.world_time + 0.3
			dogs.follow(row,goal,until,1.7)
			check(core.follow_hound(run.enemies.table.id[row],goal,until,1.7),"期限付きの移動先を保持する")
		var changes := {}
		match tick:
			15: changes = {"held":true}
			20: changes = {"held":false,"stone":0.08}
			25: changes = {"knock_t":0.08,"vel":Vector2(0,300)}
			35: changes = {"shove_time":0.08,"shove_vel":Vector2(0,-300)}
		if not changes.is_empty():
			for key in changes:
				var column = run.enemies.table.get(key)
				column[row] = int(changes[key]) if changes[key] is bool else changes[key]
				run.enemies.table.set(key,column)
			core.set_enemy_motion(run.enemies.table.id[row],changes)
		if tick == 40:
			var id: int = run.enemies.table.id[first]
			run.enemies.mark_dead(first)
			run.enemies.cleanup()
			core.remove_enemy(id)
			check(not core.follow_hound(id,Vector2.ZERO,10.0,1.0),"死亡した個体へ古いIDで指示しない")
		if tick == 60:
			for dead in dogs.rows().duplicate():
				core.remove_enemy(run.enemies.table.id[dead])
				run.enemies.mark_dead(dead)
			run.enemies.cleanup()
			check(dogs.packs.is_empty() and core.hound_snapshot().packs.is_empty(),"全滅した群れと指示を消す")
			var replacement := run.enemies.spawn(definition,Vector2(-1800,0))
			core.spawn_enemy(&"hound",Vector2(-1800,0))
			check(replacement <= 5,"空いた格納行から新しい群れを作る")
		run.state.world_time += 0.02
		run.enemies.tick(0.02,0.02)
		core.step(0.02)
		var diff: String = comparison.difference(comparison.snapshot(run,[],tick).enemies,core.enemies_snapshot())
		if diff.is_empty(): diff = comparison.difference(comparison.plain(pack_snapshot(run)),comparison.plain(core.hound_snapshot()))
		check(diff.is_empty(),"群れと移動と欠員が一致する tick%d: %s" % [tick,diff])
		check(str(run.state.rng.state) == core.inspect().rng_state,"追加個体の乱数消費が一致する")
		if not diff.is_empty(): break
	core.close()
	lab.free()
func compare_waves(comparison) -> void:
	for seed_value in range(1,9):
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed":seed_value,"empty":true})
		var run: RunSimulation = lab.run
		var definition := run.enemies.def_of(&"hound").duplicate(true) as EnemyDef
		definition.params.pack_count = 3
		run.enemies.definitions[&"hound"] = definition
		var stage := StageDef.new()
		var phase := PhaseDef.new()
		phase.id = &"群れの波"
		phase.pop_from = 4
		phase.pop_to = 4
		phase.rate = 0
		phase.wave_interval = 0.01
		phase.wave_type = &"hound"
		phase.mix = {"hound":1.0}
		stage.phases = [phase]
		run.state.stage = stage
		run.cfg.spawn_refill_time = 1000
		run.cfg.density_mult = 1
		run.cfg.spawn_total_cap = 2
		var core = comparison.create_native()
		core.configure(DATA.compile_enemy(definition,run.cfg))
		core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
		core.configure_bite_zone(DATA.compile_bite_zone(load("res://.content/attack_visuals.res")))
		core.configure_spawn_timeline(DATA.compile_spawn_timeline(stage,run.cfg))
		core.configure_population(values(run.cfg,["spawn_recycle_scale","spawn_region_cap","spawn_margin","field_radius","planet_radius"]))
		core.configure_refill(values(run.cfg,["spawn_total_cap","spawn_refill_time"]))
		core.start(seed_value,run.enemies._next_id)
		run.state.rng.seed = seed_value
		core.set_motion_context(run.state.ship_pos,run.state.view_center,run.state.view_half)
		run.state.events.clear()
		run.spawn.spawner_tick(0.02,0.02)
		core.step_population(0.02,false)
		check(run.enemies.count() == 6,"残り4体の波を3体の群れ2回で止める")
		var diff: String = comparison.difference(comparison.snapshot(run,[],0).enemies,core.enemies_snapshot())
		check(diff.is_empty(),"環状と直線の波を仲間込みの人数で止める seed%d: %s" % [seed_value,diff])
		check(str(run.state.rng.state) == core.inspect().rng_state,"波の追加個体を含め乱数が一致する")
		core.close()
		lab.free()
