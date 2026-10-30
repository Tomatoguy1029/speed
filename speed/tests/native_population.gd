## 領域別の人数・上限・画面外の再配置・出現位置と乱数を比較する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
const CONFIG := ["spawn_recycle_scale", "spawn_region_cap", "spawn_margin", "field_radius", "planet_radius"]
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var comparison = COMPARE.new()
	var probe = comparison.create_native()
	if not probe.has_method("survey_population"):
		check(false, "補充前の人数と再配置をネイティブが扱う")
	else:
		await compare_population(comparison)
		for mode in ["mix", "curve", "bonus", "blocked", "wave", "wave_bonus"]:
			await compare_refill(comparison, mode)
	await compare_attack_metadata(comparison)
	probe.close()
	print("[native_population] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func compare_population(comparison) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 807, "empty": true})
	var run: RunSimulation = lab.run
	var chase: EnemyDef = run.enemies.def_of(&"drifter")
	var shield: EnemyDef = run.enemies.def_of(&"shield").duplicate(true)
	shield.max_alive = 3
	var core = comparison.create_native()
	var data := DATA.compile_enemy(chase, run.cfg)
	data.enemies.append_array(DATA.compile_enemy(shield, run.cfg).enemies)
	core.configure(data)
	core.configure_enemy_order(PackedStringArray(["chase"]))
	var stage := StageDef.new()
	var phase := PhaseDef.new()
	phase.id = &"comparison"
	phase.mix = {"drifter": 1.0, "shield": 1.0}
	stage.phases = [phase]
	var timeline := DATA.compile_spawn_timeline(stage, run.cfg)
	# 比較専用に作った上限付きの定義と同じ固定値を渡す。
	timeline.types.shield.max_alive = shield.max_alive
	core.configure_spawn_timeline(timeline)
	var config := {}
	for key in CONFIG: config[key] = run.cfg.get(key)
	check(core.configure_population(config), "領域と再配置の編集値を渡す")
	var changed := data.duplicate(true)
	changed.enemies.resize(1)
	check(core.configure(changed) and core.population_snapshot().is_empty(), "定義を変更したら古い集計の準備を使わない")
	core.configure(data)
	core.configure_population(config)
	check(core.configure_spawn_timeline(timeline) and core.population_snapshot().is_empty(), "時間帯を変更したら古い集計の準備を使わない")
	core.configure_population(config)
	core.start(807, run.enemies._next_id)
	run.state.rng.seed = 807
	var center := Vector2(-3200,0)
	var half := Vector2(640,360)
	run.state.ship_pos = center
	run.state.view_center = center
	run.state.view_half = half
	core.set_motion_context(center, center, half)
	var offsets := [Vector2(-500,0),Vector2(500,0),Vector2(0,-330),Vector2(0,330),Vector2.ZERO,Vector2(1400,100),Vector2(-1500,-200)]
	for i in 35:
		var definition: EnemyDef = shield if i % 4 == 0 else chase
		var point: Vector2 = center + offsets[i % offsets.size()]
		run.enemies.spawn(definition, point)
		core.spawn_enemy(definition.id, point)
	# 行番号が空いた後の再配置順も一致させる。
	for row in [3,8,17]:
		core.remove_enemy(run.enemies.table.id[row])
		run.enemies.mark_dead(row)
	run.enemies.cleanup()
	for i in 3:
		run.enemies.spawn(chase, center + Vector2(2000,i*100))
		core.spawn_enemy(chase.id, center + Vector2(2000,i*100))
	for target in [5.0, 100.0, 0.0]:
		var expected := run.spawn._survey_rows(target)
		check(core.survey_population(target) == expected, "地域の上限と再配置後の有効人数が一致する")
		var snapshot := {"raw": run.spawn._survey_raw, "edges": Array(run.spawn._edge_counts), "type_counts": run.spawn._type_counts, "per_type": run.spawn._zako_counts}
		var difference: String = comparison.difference(comparison.plain(snapshot), comparison.plain(core.population_snapshot()))
		check(difference.is_empty(), "種類別・領域別の人数が一致する: " + difference)
		difference = comparison.difference(comparison.snapshot(run, [], 0).enemies, core.enemies_snapshot())
		check(difference.is_empty(), "再配置後の位置・速度・向き・HPを保つ: " + difference)
		check(str(run.state.rng.state) == core.inspect().rng_state, "再配置の乱数消費が一致する")
		for i in 12:
			check(run.spawn.spawn_point(12.3) == core.population_spawn_point(12.3), "空いている辺の選択と出現位置が一致する")
			check(str(run.state.rng.state) == core.inspect().rng_state, "出現位置を選ぶ乱数消費が一致する")
	# 全候補が外周より外なら、24回で打ち切って出現しない。
	run.state.view_center = Vector2(1e8,1e8)
	core.set_motion_context(center, run.state.view_center, half)
	check(run.spawn.spawn_point() == null and core.population_spawn_point(0.0) == null, "出現できる位置がない条件を打ち切る")
	check(str(run.state.rng.state) == core.inspect().rng_state, "位置の選択に失敗したときも乱数消費が一致する")
	core.close()
	lab.free()

func compare_refill(comparison, mode: String) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 472, "empty": true})
	var run: RunSimulation = lab.run
	var core = comparison.create_native()
	if not core.has_method("step_population"):
		check(false, "通常の補充をネイティブが扱う")
		core.close()
		lab.free()
		return
	var definitions: Array[EnemyDef] = []
	for type in [&"drifter", &"shield"]:
		var definition: EnemyDef = run.enemies.def_of(type).duplicate(true)
		definition.max_alive = 3 if type == &"shield" else 0
		definition.size_var = true
		run.enemies.definitions[type] = definition
		definitions.append(definition)
	var data := DATA.compile_enemy(definitions[0], run.cfg)
	data.enemies.append_array(DATA.compile_enemy(definitions[1], run.cfg).enemies)
	core.configure(data)
	core.configure_enemy_order(PackedStringArray(["chase"]))
	var stage := StageDef.new()
	for number in 2:
		var phase := PhaseDef.new()
		phase.id = StringName("補充%d" % number)
		phase.start = number * 2.0
		phase.pop_from = 35.0 if number == 0 else 15.0
		phase.pop_to = phase.pop_from
		phase.rate = 12.3
		phase.wave_interval = 0.19 if mode.begins_with("wave") else 0.0
		phase.wave_type = &"drifter"
		phase.mix = {"shield": 1.7, "drifter": 1.0}
		stage.phases.append(phase)
	if mode == "curve":
		for type in [&"shield", &"drifter"]:
			var curve := SpawnCurve.new()
			curve.type = type
			curve.points = PackedVector2Array([Vector2(0,12),Vector2(5,22)])
			stage.zako_curves.append(curve)
	run.state.stage = stage
	run.cfg.density_mult = 1.137
	run.cfg.spawn_total_cap = 1.1
	var timeline := DATA.compile_spawn_timeline(stage, run.cfg)
	timeline.types.shield.max_alive = 3
	core.configure_spawn_timeline(timeline)
	var config := {}
	for key in CONFIG: config[key] = run.cfg.get(key)
	core.configure_population(config)
	check(core.configure_refill({"spawn_total_cap": run.cfg.spawn_total_cap, "spawn_refill_time": run.cfg.spawn_refill_time}), "補充の編集値を渡す")
	check(not core.configure_refill({"spawn_total_cap": 1.0, "spawn_refill_time": 0.0}), "ゼロ秒の補充設定を拒否して直前の設定を保つ")
	core.start(472, run.enemies._next_id)
	run.state.rng.seed = 472
	run.state.ship_pos = Vector2(-3200,0)
	run.state.enemy_aim = run.state.ship_pos
	run.state.view_center = Vector2(1e8,1e8) if mode == "blocked" else run.state.ship_pos
	run.state.view_half = Vector2(640,360)
	core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
	for tick in 180:
		var dt := 0.0 if tick == 10 else 0.031 if tick % 3 else 0.017
		run.state.time += dt
		run.state.world_time += dt
		run.state.bonus_t = 1.0 if mode in ["bonus", "wave_bonus"] and tick >= 60 else 0.0
		run.enemies.tick(dt,dt)
		core.step(dt)
		run.state.events.clear()
		if tick == 90:
			for row in range(0,run.enemies.table.alive.size(),3):
				if run.enemies.table.dead[row] != 0: continue
				core.remove_enemy(run.enemies.table.id[row])
				run.enemies.mark_dead(row)
			run.enemies.cleanup()
		run.spawn.spawner_tick(dt,dt)
		check(core.step_population(dt, run.state.bonus_t > 0.0), "通常の補充を更新できる")
		var difference: String = comparison.difference(comparison.snapshot(run, [], tick).enemies, core.enemies_snapshot())
		check(difference.is_empty(), "補充後の種類・大きさ・HP・位置が一致する %s/%d: %s" % [mode,tick,difference])
		difference = comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events()))
		check(difference.is_empty(), "時間帯と出現の通知が一致する: " + difference)
		check(str(run.state.rng.state) == core.inspect().rng_state, "補充の乱数消費が一致する %s/%d" % [mode,tick])
		check(run.spawn._spawn_acc == core.refill_snapshot().accumulator, "補充の残り時間が一致する")
		check(run.spawn._wave_t == core.refill_snapshot().wave_time, "波状補充の経過時間が一致する")
	core.close()
	lab.free()

func compare_attack_metadata(comparison) -> void:
	var probe = comparison.create_native()
	if not probe.has_method("enemy_attack_snapshot"):
		check(false, "群れと個体の攻撃枠の設定を保持する")
		probe.close()
		return
	probe.close()
	for formation_mode in [false,true]:
		for runtime in [false,true]:
			var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
			add_child(lab)
			await lab.reset({"seed": 512, "empty": true})
			var run: RunSimulation = lab.run
			var stage: StageDef = RuntimeStage.new() if runtime else StageDef.new()
			stage.enemy_attack_values = {"drifter": 0.37}
			stage.enemy_attack_priorities = {"drifter": 3.0}
			if runtime: stage.attack_managed_by_type = {"drifter": false}
			run.state.stage = stage
			run.projectiles.director.formation_mode = formation_mode
			var definition := run.enemies.def_of(&"drifter")
			var generator: RefCounted = DATA.new()
			var data: Dictionary = generator.compile_enemy(definition, run.cfg, stage)
			var core = comparison.create_native()
			check(core.configure(data), "ステージの攻撃枠の固定値を生成する")
			core.set_attack_formation_mode(formation_mode)
			core.start(512, run.enemies._next_id)
			run.state.rng.seed = 512
			var options := [{}, {"attack_group": 111, "attack_value": 2.7}, {"attack_group": 112, "attack_value": 0.0},
				{"attack_group": 113, "attack_value": 0.0, "attack_managed": true, "attack_priority": 0.0},
				{"attack_group": 114, "attack_value": 0.5, "attack_managed": false, "attack_priority": 4.1},
				{"attack_group": 115}, {"attack_value": 7.0, "attack_managed": true}]
			for opts in options:
				run.enemies.spawn(definition, Vector2.ZERO, opts)
				check(core.spawn_enemy(&"drifter", Vector2.ZERO, opts) > 0, "群れの上書きを受け付ける")
			var expected := []
			for row in run.enemies.table.alive.size():
				if run.enemies.table.alive[row] == 0: continue
				expected.append({"id": run.enemies.table.id[row], "group": run.enemies.table.attack_group[row],
					"value": run.enemies.table.attack_value[row], "priority": run.enemies.table.attack_priority[row], "managed": bool(run.enemies.table.attack_managed[row])})
			var difference: String = comparison.difference(expected, core.enemy_attack_snapshot())
			check(difference.is_empty(), "個体と群れの攻撃設定が一致する: " + difference)
			check(str(run.state.rng.state) == core.inspect().rng_state, "攻撃枠の設定で乱数順を変えない")
			var before: Dictionary = core.inspect()
			check(core.spawn_enemy(&"drifter",Vector2.ZERO,{"attack_group": 1.5}) < 0, "整数でない群れIDは個体追加前に拒否する")
			check(core.spawn_enemy(&"drifter",Vector2.ZERO,{"attack_value": NAN}) < 0, "不正な攻撃枠は個体追加前に拒否する")
			check(before == core.inspect() and core.enemy_attack_snapshot().size() == expected.size(), "失敗時にIDと乱数と個体を消費しない")
			core.close()
			lab.free()
