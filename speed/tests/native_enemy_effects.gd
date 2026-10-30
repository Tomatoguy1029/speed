## 共通の捕捉・石化・外力を、近距離と遠方の更新で比較する。
extends "res://tests/native_attack_budget.gd"
const EXTRA := ["stone","knock_t","shove_time","shove_vel","shove_from","shoved","held","slash_hold","age","fire_t"]
func _ready() -> void:
	comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("set_enemy_motion"):
		check(false,"捕捉・石化・外力をネイティブが保持する")
	else:
		for type in [&"drifter",&"shield"]:
			for distant in [false,true]: await compare_effects(type,distant)
	probe.close()
	print("[native_enemy_effects] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func motion_snapshot(run: RunSimulation) -> Array:
	var result := []
	for row in run.enemies.table.alive.size():
		if not run.enemies.table.alive[row]: continue
		var item := {"id":run.enemies.table.id[row]}
		for key in EXTRA: item[key] = run.enemies.table.get(key)[row]
		result.append(item)
	result.sort_custom(func(a,b): return a.id < b.id)
	return comparison.plain(result)
func compare_effects(type: StringName,distant: bool) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":822,"empty":true})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	var definition := run.enemies.def_of(type)
	var core = comparison.create_native()
	core.configure(DATA.compile_enemy(definition,run.cfg,run.state.stage))
	configure(run.projectiles.director,core,true,0.0)
	core.start(822,run.enemies._next_id)
	run.state.rng.seed = 822
	core.set_motion_context(run.state.ship_pos,run.state.view_center,run.state.view_half)
	var at := run.state.ship_pos + Vector2(3000 if distant else 300,100)
	var options := {"vel":Vector2(70,30),"knock":0.08}
	var row := run.enemies.spawn(definition,at,options)
	check(core.spawn_enemy(type,at,options) == run.enemies.table.id[row],"出現直後の外力を保持する")
	run.state.events.clear()
	core.drain_events()
	for tick in 60:
		var changes := {}
		match tick:
			5: changes = {"held":true,"vel":Vector2(100,20)}
			10: changes = {"held":false,"stone":0.08}
			15: changes = {"stone":0.0,"knock_t":0.08,"vel":Vector2(-200,50)}
			20: changes = {"shove_time":0.08,"shove_vel":Vector2(300,-50)}
			25: changes = {"shove_time":0.08,"knock_t":0.08,"shove_vel":Vector2(-300,50)}
			35: changes = {"slash_hold":true}
			40: changes = {"slash_hold":false}
		if not changes.is_empty():
			for key in changes:
				var column = run.enemies.table.get(key)
				column[row] = int(changes[key]) if changes[key] is bool else changes[key]
				run.enemies.table.set(key,column)
			check(core.set_enemy_motion(run.enemies.table.id[row],changes),"個体の共通移動状態を更新する")
		if tick in [5,10,15,20,25,35]: request(run,core,"待機",row,1.0)
		run.state.world_time += 0.02
		run.projectiles.director.advance(run.state.world_time,run.enemies)
		core.advance_attack_budget(run.state.world_time)
		check(comparison.difference(snapshot(run.projectiles.director),core.attack_budget_snapshot()).is_empty(),"石化と外力による待機取消が一致する")
		run.enemies.tick(0.02,0.02)
		core.step(0.02)
		var diff: String = comparison.difference(comparison.snapshot(run,[],tick).enemies,core.enemies_snapshot())
		if diff.is_empty(): diff = comparison.difference(motion_snapshot(run),comparison.plain(core.enemy_motion_snapshot()))
		check(diff.is_empty(),"共通移動の状態と位置が一致する %s 遠方%s tick%d: %s" % [type,distant,tick,diff])
		if not diff.is_empty(): break
	var before: Array = core.enemy_motion_snapshot()
	check(not core.set_enemy_motion(run.enemies.table.id[row],{"held":true,"stone":NAN}) and before == core.enemy_motion_snapshot(),"不正な一括更新では一部も変更しない")
	var id: int = run.enemies.table.id[row]
	run.enemies.mark_dead(row)
	run.enemies.cleanup()
	core.remove_enemy(id)
	var replacement := run.enemies.spawn(definition,at)
	core.spawn_enemy(type,at)
	check(replacement == row and not core.set_enemy_motion(id,{"held":true}),"再利用した格納行へ古いIDから書かない")
	check(motion_snapshot(run) == comparison.plain(core.enemy_motion_snapshot()),"再利用時に共通移動状態を初期化する")
	core.close()
	lab.free()
