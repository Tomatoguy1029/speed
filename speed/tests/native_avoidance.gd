## 対応済みの敵による回避を、実際の行動更新と接続して比較する。
extends "res://tests/native_forward.gd"
func _ready() -> void:
	var comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("avoid_strong"):
		check(false,"ネイティブの所有状態で強敵を避ける")
	else:
		await compare_avoidance(comparison)
	probe.close()
	print("[native_avoidance] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_avoidance(comparison) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":803,"empty":true})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.state.ship_pos = Vector2(700,0)
	run.state.enemy_aim = run.state.ship_pos
	var normal := run.enemies.def_of(&"drifter").duplicate(true) as EnemyDef
	normal.speed = 120.0
	var strong := normal.duplicate(true) as EnemyDef
	strong.id = &"回避比較の強敵"
	strong.rank = 3
	strong.radius = 70.0
	strong.speed = 0.0
	var biting := run.enemies.def_of(&"biter").duplicate(true) as EnemyDef
	var core = comparison.create_native()
	var data := DATA.compile_enemy(normal,run.cfg)
	data.enemies.append_array(DATA.compile_enemy(strong,run.cfg).enemies)
	data.enemies.append_array(DATA.compile_enemy(biting,run.cfg).enemies)
	check(core.configure(data),"強敵と通常敵の編集値を生成する")
	core.configure_ship(values(run.cfg,SHIP.CONFIG_KEYS),values(run.state.stats,SHIP.STAT_KEYS))
	core.configure_bite_zone(DATA.compile_bite_zone(load("res://.content/attack_visuals.res")))
	core.start(803,run.enemies._next_id)
	run.state.rng.seed = 803
	core.set_motion_context(run.state.ship_pos,run.state.view_center,run.state.view_half)
	for point in [Vector2.ZERO,Vector2(120,0),Vector2(60,120)]:
		run.enemies.spawn(strong,point)
		core.spawn_enemy(strong.id,point)
	for k in 80:
		var point := Vector2.from_angle(k*TAU/80.0)*(20+k%15*10)
		var row := run.enemies.spawn(normal,point)
		core.spawn_enemy(normal.id,point)
		var changes := {}
		match k:
			0: changes = {"held":true}
			1: changes = {"stone":0.3}
			2: changes = {"knock_t":0.3,"vel":Vector2(800,0)}
			3: changes = {"shove_time":0.3,"shove_vel":Vector2(800,0)}
		for key in changes:
			var column = run.enemies.table.get(key)
			column[row] = int(changes[key]) if changes[key] is bool else changes[key]
			run.enemies.table.set(key,column)
		core.set_enemy_motion(run.enemies.table.id[row],changes)
	# 攻撃中の個体が回避で動かないことも実際の予告・回復で比較する。
	run.enemies.spawn(biting,Vector2(680,0))
	core.spawn_enemy(biting.id,Vector2(680,0))
	run.enemies.spawn(strong,Vector2(680,0))
	core.spawn_enemy(strong.id,Vector2(680,0))
	var corrected := false
	for tick in 100:
		run.state.world_time += 0.02
		run.enemies.tick(0.02,0.02)
		core.step(0.02)
		var before := run.enemies.table.pos.duplicate()
		run.enemies.avoid_strong(0.02)
		core.avoid_strong(0.02)
		corrected = corrected or before != run.enemies.table.pos
		var diff: String = comparison.difference(comparison.snapshot(run,[],tick).enemies,core.enemies_snapshot())
		check(diff.is_empty(),"密集・内部・接近・攻撃中・外力の回避が一致する tick%d: %s" % [tick,diff])
		if not diff.is_empty(): break
	check(corrected,"実際に回避で位置を直して比較する")
	core.close()
	lab.free()
