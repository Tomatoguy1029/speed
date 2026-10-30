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
