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
	if "--semantics-hero-values" in OS.get_cmdline_user_args():
		check_semantics_hero_values()
		print("[semantics_hero_values] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--semantics-shot-values" in OS.get_cmdline_user_args():
		check_semantics_shot_values()
		print("[semantics_shot_values] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--semantics-tracking" in OS.get_cmdline_user_args() or "--semantics-tracking-tail" in OS.get_cmdline_user_args() or "--semantics-tracking-rocket" in OS.get_cmdline_user_args() or "--semantics-tracking-extra" in OS.get_cmdline_user_args() or "--semantics-tracking-extra-tail" in OS.get_cmdline_user_args() or "--semantics-tracking-telescope-tail" in OS.get_cmdline_user_args():
		await check_semantics_tracking()
		print("[semantics_tracking] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--semantics-fixed-values" in OS.get_cmdline_user_args():
		await check_semantics_fixed_values()
		print("[semantics_fixed_values] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--semantics-selection" in OS.get_cmdline_user_args():
		await check_semantics_selection()
		print("[semantics_selection] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--semantics-seeds" in OS.get_cmdline_user_args():
		await check_semantics_seeds()
		print("[semantics_seeds] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-mix" in OS.get_cmdline_user_args():
		check(await check_cpp_mix(),"混成出現の指定確認を最後まで行う")
		print("[cpp_mix] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
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
	var held_row := -1
	for i in 3:
		var row := run.enemies.spawn(chase, center + Vector2(2000,i*100))
		var id: int = core.spawn_enemy(chase.id, center + Vector2(2000,i*100))
		if i == 0:
			held_row = row
			run.enemies.table.held[row] = 1
			check(core.set_enemy_motion(id,{"held":true}),"捕捉中の再配置条件を作る")
	for target in [5.0, 100.0, 0.0]:
		var expected := run.spawn._survey_rows(target)
		check(run.enemies.table.pos[held_row] == center + Vector2(2000,0),"捕捉中の遠方個体は元の位置に残る")
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

const MIX_SCHEMA = preload("res://tools/content/generated/run_schema.gd")
const MIX_BRIDGE = preload("res://scripts/runtime/run_bridge.gd")
func mix_ticks(bridge, count: int) -> bool:
	for tick in count:
		var stepped: Dictionary = bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
		if not stepped.ok or not bridge.read_frame().ok or not bridge.collect_frame().ok: return false
		if not bridge.delivery_error.get("ok",false): return false
	return true

func check_cpp_mix() -> bool:
	var builder = load("res://tools/content/build_run_content.gd")
	var all_types := PackedStringArray()
	var from_stage := 5 if "--cpp-mix-stage5" in OS.get_cmdline_user_args() else 1
	var chosen_clip: RuntimeClip
	for number in range(1,6):
		var stage: RuntimeStage = load("res://.content/stage_%d.tres" % number) if number<from_stage else load("res://tools/content/build_runtime_stage.gd").compile(ContentManager.stage(number),"res://.content",ContentManager.base)
		if number<from_stage:
			for type in stage.resources.enemy_ids:
				if not all_types.has(type): all_types.append(type)
			if chosen_clip==null:
				for clip: RuntimeClip in stage.clips:
					if not clip.prepared.is_empty(): chosen_clip=clip.duplicate(true); break
			continue
		if stage==null: return false
		var output := "res://.content/dev/cpp_mix_stage_%d" % number
		var built: Error = builder.build(stage,ContentManager.base,output,("混成出現%d" % number).sha256_text())
		check(built==OK,"ステージ%dの曲線・クリップ・編成・種類フィルターを生成する（結果%d）" % [number,built])
		if built!=OK: return false
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("stage_%d.json" % number)))
		var bridge = MIX_BRIDGE.new()
		var configured: Dictionary = bridge.configure(FileAccess.get_file_as_bytes(index.binary),{"api_version":1,"run_id":number,"mode":0,"stage_id":str(number),"profile":{},"settings":{}})
		if not configured.ok: check(false,"全種類を代用品なしで読み込む"); return false
		check(bridge.start(822,{}).ok,"通常モードへ出現の固定入力を準備する")
		check(bridge._core.clips_snapshot().size()==stage.clips.size() and not bridge._core.population_snapshot().is_empty(),"通常ランが生成済みクリップと補充を持つ")
		for type in stage.resources.enemy_ids:
			if not all_types.has(type): all_types.append(type)
		if chosen_clip==null:
			for clip: RuntimeClip in stage.clips:
				if not clip.prepared.is_empty(): chosen_clip = clip.duplicate(true); break
		bridge.dispose()
	if chosen_clip==null or not all_types.has("triangle"): return false
	if not all_types.has("drifter"): all_types.append("drifter")
	var spawn_types := PackedStringArray()
	for type in all_types:
		var definition: EnemyDef = ContentManager.enemies[StringName(type)]
		if definition.behavior not in [&"part",&"triangle_star",&"soldier",&"meteor",&"obstacle",&"saw"]: spawn_types.append(type)
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.density_mult = 1.0
	config.spawn_total_cap = 1.0
	config.spawn_region_cap = 0.0
	config.bonus_time = 0.05
	config.bonus_pop = 40.0
	var stage := RuntimeStage.new()
	stage.index = 180
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = all_types
	var phase := PhaseDef.new()
	phase.id = &"混成出現"
	phase.pop_from = 1300.0
	phase.pop_to = 1300.0
	phase.rate = 1200.0
	phase.attack_budget = 20
	for type in spawn_types: phase.mix[type] = 1.0
	stage.phases = [phase]
	chosen_clip.time = 0.0
	chosen_clip.length = 60.0
	chosen_clip.groups = 1
	chosen_clip.interval = 0.1
	for prepared: Dictionary in chosen_clip.prepared:
		for layout: Dictionary in prepared.layouts:
			layout.value = 2.7
			layout.attack_managed = true
	stage.clips = [chosen_clip]
	var output := "res://.content/dev/cpp_mix"
	if builder.build(stage,config,output,"混成1300体".sha256_text())!=OK: return false
	var index_path := output.path_join("stage_180.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":index_path,"cpp_signature":index.input_sha256,"seed":822},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null: session.free(); return false
	var bridge = session.bridge
	var core = bridge._core
	bridge.command("dev_remove_weapon",{"id":"W01"})
	bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":10.0})
	bridge.command("dev_ship_motion",{"position":Vector2(-900,0),"velocity":Vector2.ZERO})
	core.set_motion_context(Vector2(-900,0),Vector2(-900,0),Vector2(640,360))
	var volatile_id: int = core.spawn_enemy(&"volatile",Vector2(-5000,0),{})
	check(volatile_id>0 and bridge.command("dev_kill",{"entity_id":volatile_id,"cause":"shot"}).ok,"画像なしの追跡種類も実定義で生成・撃破する")
	var chain: Array = core.hazards_snapshot()
	check(chain.size()==1 and chain[0].enemy_damage==config.base_attack*config.atk_scale*2.0 and is_equal_approx(chain[0].delay,0.35) and chain[0].damage==9.0,"固定定義の誘爆倍率・予告・機体威力を既存の範囲攻撃へ渡す")
	core.remove_enemy(volatile_id)
	bridge.command("dev_attack_scope",{"event":"bonus"})
	# 全種類を同じ個体表へ混ぜる。残り少数は群れを持たない種類で1300体へそろえる。
	var count := 0
	var type_index := 0
	while count<1300:
		var type: String = spawn_types[type_index%spawn_types.size()] if count<1280 else "drifter"
		type_index += 1
		if type in ["meteor","iron","saw","triangle_star","cepheus_soldier"]: continue
		var at := Vector2(-900,0)+Vector2((count%50-25)*20.0,(count/50-13)*20.0)
		if core.spawn_enemy(type,at,{})<0: session.free(); return false
		count = core.enemies_snapshot().size()
	check(count==1300,"移植した全種類を代用品なしで1300体混在させる")
	check(core.set_population_mode(true,false,false) and mix_ticks(bridge,4),"混成の固定更新・通知の読取・配信まで成功する")
	var clips: Array = core.clips_snapshot()
	check(clips.size()==1 and clips[0].groups.size()==1,"開始済みクリップから生成した編成を通常更新で出す")
	check(core.enemy_attack_snapshot().any(func(row): return row.group>0),"編成の共有予算・優先度を個体へ渡す")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var render: Dictionary = bridge.read_render(Rect2(-1700,-500,1600,1000))
	check(render.ok and presentation.frame_view.apply_frame(render.value) and not presentation.frame_view.enemy_frames.is_empty(),"混成1300体の本体・付属・攻撃を通常表示へ渡す")
	await get_tree().process_frame
	var motions: Array = core.enemy_motion_snapshot()
	var parent_ids: Array = motions.filter(func(row): return row.get("parts_alive",0)>0).map(func(row): return row.id)
	if parent_ids.is_empty(): session.free(); return false
	var parent_id: int = parent_ids[0]
	var child_ids: Array = motions.filter(func(row): return row.get("parent_id",0)==parent_id).map(func(row): return row.id)
	for id in [parent_id]+child_ids:
		if core.enemies_snapshot().any(func(row): return row.id==id): core.remove_enemy(id)
	check(core.enemies_snapshot().all(func(row): return row.id!=parent_id and not child_ids.has(row.id)),"親と部位を同時に解放しても二重解放や別個体への参照を残さない")
	var refill_ids: Array = core.enemies_snapshot().filter(func(row): return row.type=="drifter").slice(0,16).map(func(row): return row.id)
	for id in refill_ids: core.remove_enemy(id)
	check(mix_ticks(bridge,8) and core.enemy_motion_snapshot().any(func(row): return row.spawn_origin==MIX_SCHEMA.ENUMS.SpawnOrigin.Refill),"不足分を通常の補充元として新しい個体IDで補う")
	var generated: Dictionary = bridge.read_recording().value.population
	check(generated.origins.has("refill") and generated.roles.has("regular"),"記録にも補充と役割の区分を渡す")
	var ship: Vector2 = core.ship_snapshot().ship_pos
	check(bridge.command("dev_set_warp",{"position":ship,"life":2.0}).ok and mix_ticks(bridge,1) and core.inspect().bonus_remaining>0.0,"実際のワープからボーナスへ入る")
	var held: Dictionary = bridge.checkpoint()
	var held_clips: Array = core.clips_snapshot()
	var saved_time: float = core.inspect().time
	check(mix_ticks(bridge,16) and core.inspect().bonus_remaining==0.0 and core.inspect().time>saved_time,"ボーナス終了後に通常の時計と編成へ戻る")
	var after: Array = core.enemies_snapshot()
	var after_clips: Array = core.clips_snapshot()
	var after_rng: String = core.inspect().rng_state
	check(bridge.restore(held.value).ok and core.clips_snapshot()==held_clips,"ボーナス途中のクリップ群・到着フラグ・次回時刻を復元する")
	check(mix_ticks(bridge,16) and core.enemies_snapshot()==after and core.clips_snapshot()==after_clips and core.inspect().rng_state==after_rng,"復帰後も補充・編成・RunRandomが同じ結果になる")
	bridge.release_checkpoint(held.value)
	session.free()
	return true

# 設計15.1の未実施分だけ。固定場面の既存成功をこの入口で繰り返さない。
func semantics_legacy(config: GameConfig, stage: RuntimeStage, definitions: Dictionary, seed_value: int) -> RunSimulation:
	var run := RunSimulation.new()
	run.options = {"config":config.duplicate(true),"stage":stage,"enemies":definitions,"seed":seed_value,"lab":true,"empty":true,"profile":ProfileManager.for_run(true,{})}
	run.setup()
	run.state.ship_pos = Vector2(-900,0)
	run.state.view_center = run.state.ship_pos
	run.state.view_half = Vector2(640,360)
	return run

func semantics_bridge(bytes: PackedByteArray, seed_value: int):
	if not ClassDB.class_exists(&"SpeedRunCore"):
		var probe = COMPARE.new().create_native()
		if probe==null: return null
		probe.close()
	var bridge = MIX_BRIDGE.new()
	bridge.subscribe("統計の受領",func(_packet):return true)
	if not bridge.configure(bytes,{"api_version":1,"run_id":seed_value+1,"mode":1,"stage_id":"semantics","profile":{},"settings":{"hitstop":false}}).ok: return null
	if not bridge.start(seed_value,{"position":Vector2(-900,0),"lab_mode":true}).ok: return null
	bridge.command("dev_remove_weapon",{"id":"W01"})
	bridge._core.set_motion_context(Vector2(-900,0),Vector2(-900,0),Vector2(640,360))
	return bridge

func semantics_observe(bridge) -> Dictionary:
	var core = bridge._core
	return {"clock":core.inspect(),"ship":core.ship_snapshot(),"draw":core.draw_snapshot(),"enemies":core.enemies_snapshot(),"motion":core.enemy_motion_snapshot(),"population":core.population_snapshot(),"refill":core.refill_snapshot(),"pickups":core.pickups_snapshot(),"clips":core.clips_snapshot(),"friends":core.projectiles_snapshot(),"hostiles":core.hostiles_snapshot(),"hazards":core.hazards_snapshot()}

func semantics_population_tick(run: RunSimulation, bridge, tick: int) -> void:
	var dt := 1.0/60.0
	if run!=null:
		run.state.time += dt
		run.state.world_time += dt
		run.enemies.tick(dt,dt)
		run.spawn.spawner_tick(dt,dt)
	if bridge!=null:
		bridge._core.step(dt)
		bridge._core.step_population(dt,false)
	if tick==180:
		if run!=null:
			for row in range(0,run.enemies.table.alive.size(),2): run.enemies.mark_dead(row)
			run.enemies.cleanup()
		if bridge!=null:
			var rows: Array = bridge._core.enemies_snapshot()
			for n in range(0,rows.size(),2): bridge._core.remove_enemy(rows[n].id)

func semantics_histogram(rows: Array, key: String, out: Dictionary) -> void:
	for row: Dictionary in rows:
		var id := String(row[key])
		out[id] = int(out.get(id,0))+1

func semantics_distribution(label: String, reference: Dictionary, migrated: Dictionary) -> void:
	var a := 0
	var b := 0
	for n in reference.values(): a += int(n)
	for n in migrated.values(): b += int(n)
	check(a>0 and b>0 and absf(float(a-b))<=float(a)*0.1,label+"の合計機会数の差10%以内")
	var keys: Array = reference.keys()
	for key in migrated:
		if not keys.has(key): keys.append(key)
	for key in keys:
		check(reference.get(key,0)>0 and migrated.get(key,0)>0,label+"の必須経路が両版で発生: "+str(key))
		check(absf(float(reference.get(key,0))/maxi(a,1)-float(migrated.get(key,0))/maxi(b,1))<=0.05,label+"の割合差5ポイント以内: "+str(key))

func check_semantics_seeds() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius=0;config.moon_count=0;config.meteor_count=0;config.iron_count=0;config.saw_count=0
	config.start_radius=900;config.density_mult=1;config.spawn_total_cap=1;config.spawn_region_cap=0
	config.comet_interval_min=1e8;config.comet_interval_max=1e8;config.gravity_interval_min=1e8;config.gravity_interval_max=1e8
	config.reroll_count=64
	var stage := RuntimeStage.new()
	stage.index=197;stage.resources=StageResources.new();stage.resources.enemy_ids=PackedStringArray(["drifter","shield"])
	var phase := PhaseDef.new()
	phase.id=&"意味の照合";phase.pop_from=24;phase.pop_to=24;phase.rate=12;phase.mix={"drifter":1.0,"shield":1.7}
	stage.phases=[phase]
	var definitions := {}
	for id in stage.resources.enemy_ids:
		var definition: EnemyDef = ContentManager.enemies[StringName(id)].duplicate(true)
		definition.speed=0;definition.max_alive=0;definition.rank=3
		definitions[StringName(id)]=definition
	var output := "res://.content/dev/semantics_seeds"
	var builder = load("res://tools/content/build_run_content.gd")
	if builder.build(stage,config,output,"設計15.1 seed0..63".sha256_text(),definitions)!=OK:
		check(false,"両版で使うSource定義を正規生成する");return
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("stage_197.json")))
	var bytes := FileAccess.get_file_as_bytes(index.binary)
	var populations := [[],[]]
	for side in 2: populations[side].resize(6);populations[side].fill(0)
	var spawned := [{},{}]
	var cards := [{},{}]
	var gold := [{"won":0,"lost":0},{"won":0,"lost":0}]
	var xp := [0.0,0.0]
	var comparison = COMPARE.new()
	for seed_value in 64:
		var run := semantics_legacy(config,stage,definitions,seed_value)
		var bridge = semantics_bridge(bytes,seed_value)
		var second = semantics_bridge(bytes,seed_value)
		if bridge==null or second==null: check(false,"seed%dのC++開始"%seed_value);run.dispose();return
		var seen := [{},{}]
		var held := 0
		var future: Array = []
		for tick in 360:
			semantics_population_tick(run,bridge,tick)
			semantics_population_tick(null,second,tick)
			var legacy: Array = comparison.snapshot(run,[],tick).enemies
			var migrated: Array = bridge._core.enemies_snapshot()
			for side in 2:
				var rows: Array = legacy if side==0 else migrated
				for enemy: Dictionary in rows:
					if not seen[side].has(enemy.id):
						seen[side][enemy.id]=true
						var key := "refill:"+String(enemy.type)
						spawned[side][key]=int(spawned[side].get(key,0))+1
				if tick%60==59: populations[side][tick/60] += rows.size()
			check(semantics_observe(bridge)==semantics_observe(second),"C++同seedの可変戦闘状態 seed%d tick%d"%[seed_value,tick])
			var first_events: Array = bridge.read_frame().value.events
			var second_events: Array = second.read_frame().value.events
			check(first_events==second_events,"C++同seedの通知列 seed%d tick%d"%[seed_value,tick])
			bridge.collect_frame();second.collect_frame()
			if tick==239: held=bridge.checkpoint().value
			if tick>=240: future.append({"state":semantics_observe(bridge),"events":first_events})
		check(bridge.restore(held).ok,"統計場面の途中へ復帰 seed%d"%seed_value)
		for tick in range(240,360):
			semantics_population_tick(null,bridge,tick)
			var events: Array = bridge.read_frame().value.events
			# 外部epoch/配信番号は復元対象外。論理通知だけを照合する。
			for event: Dictionary in events: event.erase("epoch");event.erase("sequence")
			var expected: Array = future[tick-240].events.duplicate(true)
			for event: Dictionary in expected: event.erase("epoch");event.erase("sequence")
			var state_diff: String=comparison.difference(comparison.plain(future[tick-240].state),comparison.plain(semantics_observe(bridge)))
			var event_diff: String=comparison.difference(comparison.plain(expected),comparison.plain(events))
			check(state_diff.is_empty() and event_diff.is_empty(),"C++復帰後の状態と通知列 seed%d tick%d %s %s"%[seed_value,tick,state_diff,event_diff])
			bridge.collect_frame()
		bridge.release_checkpoint(held)
		var notification_rows := [[],[]]
		for side in 2:
			var native_bridge = bridge if side==0 else second
			native_bridge.subscribe("統計通知",func(packet):
				for item: Dictionary in packet.events:
					var event: Dictionary=item.duplicate(true)
					event.erase("epoch");event.erase("sequence")
					notification_rows[side].append(event)
				return true)
		# 同じ敵と撃破機会を通し、基準XPと黄色抽選を通常の報酬入口で比較する。
		for opportunity in 64:
			var row: int = run.enemies.spawn(definitions[&"drifter"],Vector2(-900,0))
			run.pickups.on_enemy_killed(row)
			run.enemies.mark_dead(row);run.enemies.cleanup()
			var id: int = bridge._core.spawn_enemy(&"drifter",Vector2(-900,0))
			bridge.command("dev_kill",{"entity_id":id,"cause":"shot"})
			var twin_id: int = second._core.spawn_enemy(&"drifter",Vector2(-900,0))
			second.command("dev_kill",{"entity_id":twin_id,"cause":"shot"})
		check(semantics_observe(bridge)==semantics_observe(second),"同seedのドロップ・抽選・乱数状態 seed%d"%seed_value)
		var summary: Dictionary = run.pickups.xp_summary()
		var native: Dictionary = bridge._core.pickups_snapshot().xp_statistics
		gold[0].won += int(summary.gold_rolls.won);gold[0].lost += int(summary.gold_rolls.eligible-summary.gold_rolls.won)
		gold[1].won += int(native.gold_won);gold[1].lost += int(native.gold_rolls-native.gold_won)
		xp[0] += run.pickups.collect_all_gems()
		xp[1] += float(bridge.command("dev_collect_gems",{}).value)
		second.command("dev_collect_gems",{})
		# 通常候補の有効プールを固定し、32機会/seedを同じ取得状態で比較する。
		run.loadout.add_xp(100.0);run.loadout.try_open_cards()
		for native_bridge in [bridge,second]:
			native_bridge.command("dev_add_xp",{"amount":100.0})
			native_bridge.step(1.0/120.0,native_bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
		var card_hold := 0
		var card_future: Array=[]
		for opportunity in 32:
			check(bridge._ui.cards==second._ui.cards and bridge._core.inspect().rng_state==second._core.inspect().rng_state,"同seedの候補と抽選位置 seed%d opportunity%d"%[seed_value,opportunity])
			if opportunity==15: card_hold=bridge.checkpoint().value
			if opportunity>15: card_future.append({"ids":bridge._ui.cards.candidates.map(func(card):return card.id),"rng":bridge._core.inspect().rng_state})
			semantics_histogram(run.state.cards,"id",cards[0])
			semantics_histogram(bridge._ui.cards.candidates,"id",cards[1])
			if opportunity<31:
				run.loadout.reroll_cards()
				for native_bridge in [bridge,second]:
					native_bridge.command("reroll",{"offer_id":native_bridge._ui.cards.offer_id});native_bridge.collect_frame()
		check(notification_rows[0]==notification_rows[1],"同seedのドロップ・XP・候補通知列 seed%d"%seed_value)
		check(bridge.restore(card_hold).ok,"候補抽選の途中へ復帰 seed%d"%seed_value)
		bridge.collect_frame()
		for expected: Dictionary in card_future:
			bridge.command("reroll",{"offer_id":bridge._ui.cards.offer_id});bridge.collect_frame()
			check(bridge._ui.cards.candidates.map(func(card):return card.id)==expected.ids and bridge._core.inspect().rng_state==expected.rng,"候補復帰後の抽選列と乱数 seed%d"%seed_value)
		bridge.release_checkpoint(card_hold)
		run.dispose();bridge.dispose();second.dispose()
		if failed: break
	for second_index in 6:
		check(absf(float(populations[0][second_index]-populations[1][second_index]))/64.0<=maxf(float(populations[0][second_index])/64.0*0.1,1.0),"世界秒%dの個体数平均の許容幅"%(second_index+1))
	semantics_distribution("由来別生成数/敵種",spawned[0],spawned[1])
	semantics_distribution("通常候補",cards[0],cards[1])
	semantics_distribution("黄色ドロップ抽選",gold[0],gold[1])
	check(xp[0]>0 and absf(xp[0]-xp[1])<=xp[0]*0.1,"取得XP平均の差10%以内")
	print("SEMANTICS_SEEDS ",JSON.stringify({"seeds":[0,63],"world_seconds":6,"population_sums":populations,"spawned":spawned,"cards":cards,"gold":gold,"xp_sums":xp,"replay_ticks_per_seed":120,"failed":failed}))

# 技の実行時間に左右されない、同じ制作フローの選択だけを両版へ渡す。
# 待機ノードは制作形式の正規ノードで、ゲームの技や数値は変更しない。
func check_semantics_selection() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg: GameConfig=ContentManager.base.duplicate(true)
	cfg.planet_radius=0;cfg.moon_count=0;cfg.meteor_count=0;cfg.iron_count=0;cfg.saw_count=0
	var definition: BossDef=load("res://data/bosses/monoceros.tres").duplicate(true)
	definition.speed=0;definition.params.initial_wait=0.0
	var rules=load("res://data/bosses/ai/monoceros_action_rules.tres").duplicate(true)
	rules.techniques.assign([load("res://data/bosses/monoceros_moves/charge.tres")])
	rules.graph_nodes={"charge":{"hidden":true}}
	rules.combos={}
	rules.conditions={}
	rules.costs={}
	rules.selection_bias={"normal_a":3.0,"normal_b":1.0,"combo":1.0,"major":1.0}
	rules.condition_groups={"choose_normal":{"category":"normal","nodes":["normal_a","normal_b"]},"choose_combo":{"category":"combo","nodes":["combo"]},"choose_major":{"category":"major","nodes":["major"]}}
	var candidates: Array=[]
	for id in ["normal_a","normal_b","combo","major"]:
		rules.combos[id]={"type":"wait","seconds":0.0}
		rules.costs[id]=1.0
		candidates.append({"id":id,"category":"single" if id.begins_with("normal") else id,"cost":1.0,"parts":[0],"exclusive":true})
	var section={"request":"any","weights":{"single":5.0,"combo":3.0,"major":2.0},"cap":1.0,"action_count":1,"next":0,"avoid_repeat":true,"technique_weights":rules.selection_bias}
	var flow=load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.maximum_stamina=100000.0;flow.partial_rest=0;flow.empty_rest=0;flow.sections=[section]
	var package: Dictionary=builder.boss_package(definition,cfg,null,{"rules":rules,"flow":flow})
	if package.is_empty():check(false,"選択条件だけを正規制作形式から生成する");return
	var bytes: PackedByteArray=builder.Schema.write_content(package.records,"1".repeat(64).hex_decode())
	var counts := [{},{}]
	for seed_value in 64:
		var selector=load("res://scripts/bosses/flow/selector.gd").new()
		selector.random.seed=seed_value
		var last: Array=[]
		for opportunity in 64:
			last=selector.choose(candidates,section,last)
			semantics_histogram(last,"id",counts[0])
		var bridge=semantics_bridge(bytes,seed_value)
		var twin=semantics_bridge(bytes,seed_value)
		if bridge==null or twin==null:check(false,"選択のC++ランを開始する");return
		for native_bridge in [bridge,twin]:
			check(native_bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).ok,"制作フローを本体へ接続する")
		var selected:=0
		var active:=false
		var held:=0
		var replay_start:=0
		var future: Array=[]
		var end_tick:=0
		for tick in 4096:
			for native_bridge in [bridge,twin]: native_bridge.step(1.0/120.0,native_bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
			var rows: Array=bridge.command("dev_boss_flow_state").value
			var second_rows: Array=twin.command("dev_boss_flow_state").value
			check(rows==second_rows and bridge._core.inspect().rng_state==twin._core.inspect().rng_state,"同seedの技選択・フロー・乱数 seed%d tick%d"%[seed_value,tick])
			if rows.is_empty():check(false,"選択フローが存在する");break
			if rows[0].active and not active:
				for id in rows[0].last:counts[1][id]=int(counts[1].get(id,0))+1
				selected+=1
			active=rows[0].active
			if held>0:future.append({"flow":rows,"rng":bridge._core.inspect().rng_state})
			if selected==32 and held==0:held=bridge.checkpoint().value;replay_start=tick+1
			if selected==64:end_tick=tick+1;break
		check(selected==64,"両版で同じ64回の技選択機会を通す seed%d"%seed_value)
		check(bridge.restore(held).ok,"選択履歴の途中へ復帰 seed%d"%seed_value)
		for tick in range(replay_start,end_tick):
			bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
			var expected: Dictionary=future[tick-replay_start]
			check(bridge.command("dev_boss_flow_state").value==expected.flow and bridge._core.inspect().rng_state==expected.rng,"復帰後も同じ技選択履歴へ進む seed%d tick%d"%[seed_value,tick])
		bridge.release_checkpoint(held);bridge.dispose();twin.dispose()
		if failed:break
	semantics_distribution("技選択",counts[0],counts[1])
	print("SEMANTICS_SELECTION ",JSON.stringify({"seeds":[0,63],"opportunities_per_seed":64,"counts":counts,"failed":failed}))

func semantics_fixed_values(run: RunSimulation, bridge) -> Array:
	var expected := {}
	var actual := {}
	var ui: Dictionary=bridge.read_frame().value.ui
	for key in ["max_speed","max_hp","attack_mult","crit_chance","crit_mult","pickup_radius","xp_pickup_radius","charge_time","capacity","length_mult","glide_duration_mult"]:
		expected[key]=run.state.stats.get(key);actual[key]=ui[key]
	expected.area=run.loadout.area_multiplier();actual.area=ui.area_multiplier
	expected.shots=1.0+run.loadout._trait_bonus(&"T35");actual.shots=ui.shot_multiplier
	expected.rate=run.loadout.shooting_rate();actual.rate=ui.shooting_rate
	expected.attack=run.combat.attack_power();actual.attack=ui.attack_power
	expected.next_xp=run.loadout.xp_needed();actual.next_xp=ui.next_xp
	var native_ship: Dictionary=bridge._core.ship_snapshot()
	for key in ["ship_pos","ship_vel","ship_heading","ship_hp","ship_hurt","ship_invuln","ship_shield_flash","ship_shield_t","ship_shield_max","ship_boost_t","ship_fade_t","glide","glide_t","glide_speed","peak_speed"]:
		expected[key]=run.state.get(key);actual[key]=native_ship[key]
	var clock: Dictionary=bridge._core.inspect()
	for key in ["time","world_time","sim_time","phase"]:
		expected[key]=run.state.get(key);actual[key]=clock[key]
	for kind in ["weapon","trait"]:
		expected[kind]=run.state.weapons if kind=="weapon" else run.state.traits
		var levels := {}
		for row: Dictionary in ui.weapon_levels if kind=="weapon" else ui.trait_levels:levels[StringName(row.id)]=row.level
		actual[kind]=levels
	return [expected,actual]

func check_semantics_fixed_values() -> void:
	var config: GameConfig=ContentManager.base.duplicate(true)
	config.planet_radius=0;config.moon_count=0;config.meteor_count=0;config.iron_count=0;config.saw_count=0
	config.comet_interval_min=1e8;config.comet_interval_max=1e8;config.gravity_interval_min=1e8;config.gravity_interval_max=1e8
	config.start_radius=900;config.weapon_slots=32;config.trait_slots=32
	var stage:=RuntimeStage.new()
	stage.index=199;stage.resources=StageResources.new();stage.resources.enemy_ids=PackedStringArray(["drifter"])
	var phase:=PhaseDef.new()
	phase.id=&"固定値";phase.pop_from=0;phase.pop_to=0;phase.rate=0;phase.attack_budget=0
	stage.phases=[phase]
	var output:="res://.content/dev/semantics_fixed_values"
	if load("res://tools/content/build_run_content.gd").build(stage,config,output,"設計15.1固定の能力値".sha256_text())!=OK:
		check(false,"現在のSourceから固定値の定義を生成する");return
	var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("stage_199.json")))
	var bytes:=FileAccess.get_file_as_bytes(index.binary)
	var comparison=COMPARE.new()
	var capture=load("res://tests/equipment_effects.gd").ErrorCapture.new()
	OS.add_logger(capture)
	var cases:=0
	for kind in ["weapon","trait"]:
		var category:=&"weapons" if kind=="weapon" else &"traits"
		for id in ContentManager.catalog.table(category):
			var run:=semantics_legacy(config,stage,{},17)
			var intent:=Intent.new()
			intent.has_cursor=true;intent.cursor=Vector2(500,250)
			run.input_source=func():return intent
			run.view_size_source=func():return Vector2(1280,720)
			var bridge=semantics_bridge(bytes,17)
			if bridge==null:check(false,"固定値のC++ランを開始する");run.dispose();return
			for level in range(1,(config.weapon_max_level if kind=="weapon" else config.trait_max_stacks)+1):
				check(run.loadout.grant(StringName(kind),id,1) and bridge.command("dev_grant_equipment",{"kind":kind,"id":String(id),"levels":1}).ok,"比較する同じ取得状態を作る %s/%d"%[id,level])
				for tick in 64:
					run._play_tick(1.0/120.0)
					var stepped:Dictionary=bridge.step(1.0/120.0,bridge.pack_intent(intent),{"logical_size":Vector2(1280,720)})
					if not stepped.ok or capture.count()>0:
						check(false,"固定場面の更新エラー %s/%d: %s %s"%[id,level,stepped,capture.messages()]);break
					var values:=semantics_fixed_values(run,bridge)
					var found:String=comparison.semantics_difference(values[0],values[1])
					check(found.is_empty(),"f64/Vector2/整数の指定許容幅 %s Lv%d tick%d: %s"%[id,level,tick,found])
					if not found.is_empty():break
				cases+=1
				if failed:break
			run.dispose();bridge.dispose()
			if failed:break
		if failed:break
	OS.remove_logger(capture)
	check(capture.count()==0,"固定場面の両実装に実行時エラーがない")
	print("SEMANTICS_FIXED_VALUES ",JSON.stringify({"cases":cases,"ticks_per_level":64,"f64_absolute_error_max":comparison.semantics_f64_error,"vector_error_max":comparison.semantics_vector_error,"numeric_values":comparison.semantics_numeric_values,"failed":failed,"scope":"全武器/特性の各段の共通実効値・機体移動・時計。種類固有の発火・命中の厳密幅は別"}))

# 既存ranged比較で幅が広かった移動・旋回・時計だけを直接採取する。
# 発射前の固定時刻を使い、乱数が効く弾の配置を比較対象へ混ぜない。
func check_semantics_tracking() -> void:
	var tail:= "--semantics-tracking-tail" in OS.get_cmdline_user_args()
	var rocket_only:="--semantics-tracking-rocket" in OS.get_cmdline_user_args()
	var extra_tail:="--semantics-tracking-extra-tail" in OS.get_cmdline_user_args()
	var telescope_tail:="--semantics-tracking-telescope-tail" in OS.get_cmdline_user_args()
	var extra:="--semantics-tracking-extra" in OS.get_cmdline_user_args() or extra_tail or telescope_tail
	var config:GameConfig=ContentManager.base.duplicate(true)
	config.start_radius=900;config.planet_radius=100 if extra else 0;config.moon_count=0;config.meteor_count=0;config.iron_count=0;config.saw_count=0
	var stage:=RuntimeStage.new()
	stage.index=200;stage.resources=StageResources.new()
	stage.resources.enemy_ids=PackedStringArray(["darter","telescope"] if extra else ["gunner","missile","battleship","spreader","beamer","rocket"])
	var phase:=PhaseDef.new()
	phase.id=&"追跡の固定場面";phase.pop_from=0;phase.pop_to=0;phase.rate=0;phase.attack_budget=0;stage.phases=[phase]
	var output:="res://.content/dev/semantics_tracking"
	if load("res://tools/content/build_run_content.gd").build(stage,config,output,"設計15.1追跡の不足値".sha256_text())!=OK:
		check(false,"追跡のSource定義を生成する");return
	var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("stage_200.json")))
	var bytes:=FileAccess.get_file_as_bytes(index.binary)
	var comparison=COMPARE.new()
	var capture=load("res://tests/equipment_effects.gd").ErrorCapture.new()
	OS.add_logger(capture)
	var cases:=0
	for type in stage.resources.enemy_ids:
		if rocket_only and type!="rocket":continue
		if telescope_tail and type!="telescope":continue
		if tail and type in ["gunner","missile"]:continue
		var offsets:Array=[Vector2(300,100)] if type=="darter" else ([Vector2(600,50),Vector2(1350,50)] if type=="telescope" else [Vector2(320,120),Vector2(900,120)])
		for offset:Vector2 in offsets:
			if tail and type=="battleship" and offset.x==320:continue
			var run:=semantics_legacy(config,stage,{},29)
			# 移行開始時のLabSessionと同じ空場面。半径0の惑星も衝突候補から外す。
			if config.planet_radius==0:
				run.field.bodies.clear();run.field.moons.clear();run.field.planet.pos=Vector2(1e7,1e7);run.field.planet.r=0;run.field.refresh_bodies()
			var bridge=semantics_bridge(bytes,29)
			if bridge==null:check(false,"追跡のC++ランを開始する");run.dispose();OS.remove_logger(capture);return
			check(bridge._core.configure_attack_budget({"enabled":false}),"基準版の実験モードと同じ予算なしに揃える")
			var at:Vector2=run.state.ship_pos+offset
			var definition:EnemyDef=run.enemies.def_of(StringName(type))
			var opts={"size":definition.radius,"facing":(-offset).angle() if type=="telescope" else 0.125,"vel":Vector2.ZERO}
			# 基準版の起動時sanity検査が使ったIDを、本番開始と同じ1へ揃える。
			run.enemies._next_id=1
			var row:int=run.enemies.spawn(definition,at,opts)
			var id:int=bridge._core.spawn_enemy(StringName(type),at,opts)
			check(run.enemies.table.id[row]==id,"個体IDも同じ固定場面を使う")
			run.enemies.table.fire_t[row]=2.0;run.enemies.table.charge[row]=0.0
			check(bridge._core.set_enemy_motion(id,{"fire_t":2.0,"charge":0.0}),"同じ発射前の時刻を固定する")
			if type=="darter":
				run.projectiles.director.formation_mode=true;bridge._core.set_attack_formation_mode(true)
				run.projectiles.director.configure({"enabled":true,"budget":0.0,"jitter":0.0});bridge._core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
			var dt:=0.125 if type=="darter" else (0.05 if type=="telescope" else 0.01)
			for tick in (21 if type=="darter" else (64 if type=="telescope" else 16)):
				if type=="darter" and tick==1:
					run.projectiles.director.configure({"enabled":true,"budget":1.0,"jitter":0.0});bridge._core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
				run.state.time+=dt;run.state.world_time+=dt
				if type=="darter":
					run.projectiles.director.advance(run.state.world_time,run.enemies);bridge._core.advance_attack_budget(run.state.world_time)
				run.enemies.tick(dt,dt)
				check(bridge._core.step(dt),"追跡の固定更新を進める")
				if capture.count()>0:check(false,"追跡の実行時エラー: %s"%capture.messages());break
				if extra_tail and type=="darter" and tick<20:continue
				if telescope_tail and offset.x==600 and tick<29:continue
				var rows:Array=bridge._core.enemies_snapshot().filter(func(enemy):return enemy.id==id)
				var motion:Array=bridge._core.enemy_motion_snapshot().filter(func(enemy):return enemy.id==id)
				if rows.size()!=1 or motion.size()!=1:check(false,"追跡対象の個体が残る");break
				var table:=run.enemies.table
				var expected={"pos":table.pos[row],"vel":table.vel[row],"hp":table.hp[row],"armor":table.armor[row],"radius":table.r[row],"facing":table.facing[row],"dead":bool(table.dead[row]),"mode":int(table.mode[row]),"timer":table.timer[row],"fire_t":table.fire_t[row],"charge":table.charge[row]}
				var actual={"pos":Vector2(rows[0].pos[0],rows[0].pos[1]),"vel":Vector2(rows[0].vel[0],rows[0].vel[1]),"hp":rows[0].hp,"armor":rows[0].armor,"radius":rows[0].radius,"facing":rows[0].facing,"dead":bool(rows[0].dead),"mode":int(motion[0].mode),"timer":motion[0].timer,"fire_t":motion[0].fire_t,"charge":motion[0].charge}
				if type=="telescope":
					expected.rays=Array(run.enemies.behavior(&"sniper").telescope_rays(row));actual.rays=Array(motion[0].sight_rays)
				var found:String=comparison.semantics_difference(expected,actual)
				check(found.is_empty(),"追跡・旋回・時計の指定許容幅 %s offset%s tick%d: %s"%[type,offset,tick,found])
				if not found.is_empty():break
			cases+=1
			run.dispose();bridge.dispose()
			if failed:break
		if failed:break
	OS.remove_logger(capture)
	check(capture.count()==0,"追跡の両実装に実行時エラーがない")
	print("SEMANTICS_TRACKING ",JSON.stringify({"cases":cases,"prior_successful_cases":10 if rocket_only else (5 if tail else 0),"extra":extra,"extra_tail":extra_tail,"telescope_tail":telescope_tail,"ticks_per_case":16 if not extra else "darter21/telescope64","numeric_values":comparison.semantics_numeric_values,"f64_absolute_error_max":comparison.semantics_f64_error,"vector_error_max":comparison.semantics_vector_error,"failed":failed}))

# 全Lvの発射・命中・復帰は既存成功を保持し、発射された数値の未証明の幅だけ採取する。
func check_semantics_shot_values() -> void:
	var config: GameConfig=ContentManager.base.duplicate(true)
	config.planet_radius=0;config.moon_count=0;config.meteor_count=0;config.iron_count=0;config.saw_count=0
	config.comet_interval_min=1e8;config.comet_interval_max=1e8;config.gravity_interval_min=1e8;config.gravity_interval_max=1e8
	config.start_radius=900
	var stage:=RuntimeStage.new()
	stage.index=201;stage.resources=StageResources.new();stage.resources.enemy_ids=PackedStringArray(["drifter"])
	var phase:=PhaseDef.new()
	phase.id=&"射撃の数値";phase.pop_from=0;phase.pop_to=0;phase.rate=0;phase.attack_budget=0;stage.phases=[phase]
	var output:="res://.content/dev/semantics_shot_values"
	if load("res://tools/content/build_run_content.gd").build(stage,config,output,"設計15.1射撃の不足値".sha256_text())!=OK:
		check(false,"射撃のSource定義を生成する");return
	var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("stage_201.json")))
	var bytes:=FileAccess.get_file_as_bytes(index.binary)
	var comparison=COMPARE.new()
	var capture=load("res://tests/equipment_effects.gd").ErrorCapture.new()
	OS.add_logger(capture)
	var cases:=0
	for id in [&"W01",&"W02",&"W23"]:
		if "--semantics-shot-tail" in OS.get_cmdline_user_args() and id==&"W01":continue
		var run:=semantics_legacy(config,stage,{},17)
		var intent:=Intent.new()
		intent.has_cursor=true;intent.cursor=Vector2(500,250)
		run.input_source=func():return intent
		run.view_size_source=func():return Vector2(1280,720)
		var bridge=semantics_bridge(bytes,17)
		if bridge==null:check(false,"射撃数値のC++ランを開始する");run.dispose();break
		for level in range(1,config.weapon_max_level+1):
			check(run.loadout.grant(&"weapon",id,1) and bridge.command("dev_grant_equipment",{"kind":"weapon","id":String(id),"levels":1}).ok,"数値を読む装備を同じ段へ進める")
			var observed:=0
			for tick in (170 if id==&"W02" else 110):
				run._play_tick(1.0/120.0)
				var stepped:Dictionary=bridge.step(1.0/120.0,bridge.pack_intent(intent),{"logical_size":Vector2(1280,720)})
				if not stepped.ok or capture.count()>0:check(false,"射撃の数値採取中に実行エラー: "+str(capture.messages()));break
				if "--semantics-shot-tail" in OS.get_cmdline_user_args() and id==&"W02" and level==1 and tick<64:continue
				var expected: Array=[]
				for row in run.projectiles.friend_alive.size():
					if run.projectiles.friend_alive[row]:
						expected.append({"pos":run.projectiles.friend_pos[row],"vel":run.projectiles.friend_vel[row],"radius":run.projectiles.friend_r[row],"damage":run.projectiles.friend_dmg[row],"life":run.projectiles.friend_life[row]})
				var actual: Array=[]
				for shot: Dictionary in bridge._core.projectiles_snapshot():actual.append({"pos":shot.pos,"vel":shot.vel,"radius":shot.radius,"damage":shot.damage,"life":shot.life})
				var weapon=run.loadout.weapon_behaviors[id]
				var timing: Dictionary=bridge._core.forward_snapshot() if id==&"W01" else bridge._core.scatter_snapshot() if id==&"W02" else bridge._core.rear_snapshot()
				var source: Dictionary={"shots":expected,"elapsed":weapon._t,"recoil":weapon.recoil}
				var native: Dictionary={"shots":actual,"elapsed":timing.elapsed,"recoil":timing.recoil}
				if id==&"W23":
					source.mount=weapon.mount_position();source.aim=weapon.aim_direction();native.mount=timing.mount;native.aim=timing.aim
				var found: String=comparison.semantics_difference(source,native)
				check(found.is_empty(),"射撃のf64/Vector2指定許容幅 %s Lv%d tick%d: %s"%[id,level,tick,found])
				observed+=actual.size()
				if failed:break
			check(observed>0,"数値を読む実弾が存在する %s Lv%d"%[id,level])
			cases+=1
			print("SEMANTICS_SHOT_CASE ",id," Lv",level," failed=",failed)
			if failed:break
		run.dispose();bridge.dispose()
		if failed:break
	OS.remove_logger(capture)
	check(capture.count()==0,"射撃の両実装に実行時エラーがない")
	print("SEMANTICS_SHOT_VALUES ",JSON.stringify({"cases":cases,"numeric_values":comparison.semantics_numeric_values,"f64_absolute_error_max":comparison.semantics_f64_error,"vector_error_max":comparison.semantics_vector_error,"failed":failed}))

func check_semantics_hero_values() -> void:
	var config: GameConfig=ContentManager.base.duplicate(true)
	config.planet_radius=0;config.moon_count=0;config.meteor_count=0;config.iron_count=0;config.saw_count=0
	config.comet_interval_min=1e8;config.comet_interval_max=1e8;config.gravity_interval_min=1e8;config.gravity_interval_max=1e8
	config.start_radius=900
	var stage:=RuntimeStage.new()
	stage.index=202;stage.resources=StageResources.new();stage.resources.enemy_ids=PackedStringArray(["drifter"])
	var phase:=PhaseDef.new()
	phase.id=&"英雄の時計";phase.pop_from=0;phase.pop_to=0;phase.rate=0;phase.attack_budget=0;stage.phases=[phase]
	var output:="res://.content/dev/semantics_hero_values"
	if load("res://tools/content/build_run_content.gd").build(stage,config,output,"設計15.1英雄の不足値".sha256_text())!=OK:
		check(false,"英雄のSource定義を生成する");return
	var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("stage_202.json")))
	var bytes:=FileAccess.get_file_as_bytes(index.binary)
	var comparison=COMPARE.new()
	var capture=load("res://tests/equipment_effects.gd").ErrorCapture.new()
	OS.add_logger(capture)
	for id in [&"perseus",&"leo",&"gemini",&"hercules"]:
		var run:=semantics_legacy(config,stage,{},17)
		var intent:=Intent.new()
		run.input_source=func():return intent
		run.view_size_source=func():return Vector2(1280,720)
		run.loadout.reset_loadout()
		run.state.hero_power=id
		var bridge=semantics_bridge(bytes,17)
		if bridge==null:check(false,"英雄数値のC++ランを開始する");run.dispose();break
		bridge.command("dev_set_hero",{"id":String(id)})
		for tick in 64:
			intent.hero_press=tick==0
			run._play_tick(1.0/120.0)
			var stepped:Dictionary=bridge.step(1.0/120.0,bridge.pack_intent(intent),{"logical_size":Vector2(1280,720)})
			if not stepped.ok or capture.count()>0:check(false,"英雄の数値採取中に実行エラー: "+str(capture.messages()));break
			var hero: Dictionary=bridge.read_frame().value.ui.hero
			var source: Dictionary={"active":run.state.hero_active_t,"cooldown":run.state.hero_cd,"boss_stun":run.state.boss_stun,"width":run.heroes.trace_width()}
			var native: Dictionary={"active":hero.active,"cooldown":hero.cooldown,"boss_stun":hero.boss_stun,"width":hero.trace_width}
			var found: String=comparison.semantics_difference(source,native)
			check(found.is_empty(),"英雄のf64指定許容幅 %s tick%d: %s"%[id,tick,found])
			if failed:break
		run.dispose();bridge.dispose()
		print("SEMANTICS_HERO_CASE ",id," failed=",failed)
		if failed:break
	OS.remove_logger(capture)
	check(capture.count()==0,"英雄の両実装に実行時エラーがない")
	print("SEMANTICS_HERO_VALUES ",JSON.stringify({"numeric_values":comparison.semantics_numeric_values,"f64_absolute_error_max":comparison.semantics_f64_error,"failed":failed,"scope":"全4英雄の実秒持続時間/CD/ボス停止/実効描線幅。乱数座標と固有攻撃は含めない"}))
