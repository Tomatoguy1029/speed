extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
const CHECK := preload("res://scripts/encounters/route_constraints.gd")
const IO := preload("res://gyms/enemy_lab/lab_io.gd")
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--cpp-lab" in OS.get_cmdline_user_args():
		await check_cpp_lab_constraints()
		print("[cpp_lab_constraints] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-encounter" in OS.get_cmdline_user_args():
		check(await check_cpp_encounter(),"採用した配置規則の指定確認を最後まで行う")
		print("[cpp_encounter] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-route" in OS.get_cmdline_user_args(): check(await check_cpp_route(),"C++の経路判定と通常表示を最後まで確認する")
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset()
	var route := PackedVector2Array([Vector2(-300, 0), Vector2(300, 0)])
	lab.perform("spawn", {"type": "drifter", "pos": [0, 0]})
	check(CHECK.validate(lab, route).valid, "弱い敵はルートの障害物にしない")
	check(CHECK.validate(lab, route, 20, 1).status == "unsupported", "動く敵の静止判定を時間幅の保証にしない")
	lab.perform("spawn", {"type": "armored", "pos": [0, 0]})
	check(not CHECK.validate(lab, route).valid, "線の両端が安全でも中間の装甲を検出する")
	lab.perform("clear")
	lab.perform("spawn", {"type": "drifter", "pos": [0, 0]})
	lab.perform("parameter", {"type": "drifter", "key": "speed", "value": 0})
	lab.run.enemies.table.vel[lab.selected] = Vector2.ZERO
	check(CHECK.validate(lab, route, 20, 1).status == "window", "対応する静止モデルだけ時間幅を認証する")
	lab.run.projectiles.fire_beam(Vector2(0, 250), 0, 500, 20, 0.5, 1, 10)
	check(CHECK.validate(lab, route, 20, 1).status == "window", "固定方向の離れたビームを保守的な時間包絡で確認する")
	lab.run.projectiles.fire_beam(Vector2(-300, 0), 0, 600, 20, 0.5, 1, 10)
	check(not CHECK.validate(lab, route, 20, 1).valid, "未来に発動するビームもルートとの重なりを拒否する")
	lab.run.projectiles.clear_hostile()
	lab.run.projectiles._add_hostile(Vector2(0, -400), Vector2(0, 400), 400, 7, 4, 10, 0, 0, RunIds.HostileKind.Bullet)
	check(not CHECK.validate(lab, route, 20, 1).valid, "現在は離れていても途中で線を横切る弾を検出する")
	lab.run.projectiles.clear_hostile()
	lab.perform("spawn", {"type": "swarm", "pos": [400, 0]})
	await lab.undo_edit()
	check(lab.run.enemies.count() == 1, "同じ時刻の配置命令も取り消せる")
	await lab.redo_edit()
	check(lab.run.enemies.count() == 2, "取り消した配置命令をやり直せる")
	lab.perform("delete", {"id": lab.run.enemies.table.id[lab.selected]})
	var record := IO.record(lab, route, {}, [])
	check(IO.save_json("/private/tmp/speed-lab-roundtrip.json", record) == OK, "JSON を保存できる")
	var read := IO.read_json("/private/tmp/speed-lab-roundtrip.json")
	check(not read.has("error") and not read.stale, "基準付きで JSON を再読込できる")
	read.history.append({"tick": 0, "kind": "spawn", "args": {"type": "unknown"}})
	check(not IO.validate(read).is_empty(), "未知の敵を黙って読み込まない")
	var generator = load("res://gyms/enemy_lab/encounter_pattern.gd").new()
	add_child(generator)
	var pattern: Dictionary = generator.capture(lab, route, 0)
	var result: Dictionary = await generator.generate(lab, pattern, 34)
	check(result.status == "static", "ルートと領域から検証済みランダム候補を生成する")
	var runtime = load("res://scripts/encounters/encounter_coordinator.gd").new()
	await lab.reset({"empty": true})
	runtime.setup(lab.run, {"enabled": true, "patterns": [pattern], "director": {"enabled": true}})
	runtime.advance()
	check(not runtime.opportunity.is_empty() and lab.run.enemies.count() > 0, "採用した規則だけを本番と同じ入口で追加できる")
	check(ContentManager.stage(1).encounter_profile.is_empty(), "通常ステージでは採用前の機能を有効にしない")
	var old_lab_def: EnemyDef = lab.run.enemies.def_of(&"drifter")
	var old_def: EnemyDef = ContentManager.enemies[&"drifter"]
	check(ContentManager.reload_experiment_data(), "本番の敵・時間帯・共通値を読み直せる")
	check(ContentManager.enemies[&"drifter"] != old_def and lab.run.enemies.def_of(&"drifter") == old_lab_def, "再読込は新しい参照を作り、既存の実験の定義を変えない")
	print("[lab_constraints] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func check_cpp_route() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 900.0
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.draw_length = 1000.0
	var stage := RuntimeStage.new()
	stage.index = 181
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	stage.enemy_tuning = {"drifter":{"hp":1000.0,"armor":1000.0,"speed":0.0}}
	var builder = load("res://tools/content/build_run_content.gd")
	var output := "res://.content/dev/cpp_route"
	if builder.build(stage,config,output,"経路制約".sha256_text())!=OK: return false
	var index_path := output.path_join("stage_181.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":index_path,"cpp_signature":index.input_sha256,"seed":184},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null: session.free(); return false
	var bridge = session.bridge
	var core = bridge._core
	var path := PackedVector2Array([Vector2(-1100,0),Vector2(-700,0)])
	check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)}).ok and bridge.read_frame().ok and bridge.delivery_error.get("ok",false),"経路の問い合わせ前に固定更新と通知配信が成功する")
	check(bridge.query_route(path,{"window":1.0}).value.status=="unsupported","通常装備がある時間幅は通過可能と保証しない")
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var initial: Dictionary = bridge.query_route(path,{}).value
	check(initial.valid and initial.budget>path[0].distance_to(path[1]),"C++が所有する容量・ゲージから長さの上限を計算する")
	var top: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-900,200)}).value
	var bottom: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-900,-200)}).value
	var radius: float = core.enemies_snapshot()[0].radius
	var gap: float = initial.sweep_radius+radius+0.2
	bridge.command("dev_relocate",{"entity_id":top,"position":Vector2(-900,gap)})
	bridge.command("dev_relocate",{"entity_id":bottom,"position":Vector2(-900,-gap)})
	check(bridge.query_route(path,{"window":1.0}).value.status=="window","円の掃引で残る狭い隙間を時間幅付きで認証する")
	var held: Dictionary = bridge.checkpoint()
	var rng: String = core.inspect().rng_state
	bridge.command("dev_relocate",{"entity_id":top,"position":Vector2(-900,gap-0.4)})
	var blocked: Dictionary = bridge.query_route(path,{}).value
	check(not blocked.valid and blocked.blockers.any(func(row): return row.get("id")==top),"両端が安全でも線分の途中に入った装甲の円を検出する")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var frame: Dictionary = bridge.read_render(Rect2(-1500,-400,1000,800))
	check(frame.ok and presentation.frame_view.apply_frame(frame.value),"経路を塞ぐ通常の敵を本番の表示へ渡す")
	await get_tree().process_frame
	check(bridge.restore(held.value).ok and bridge.query_route(path,{}).value.valid and core.inspect().rng_state==rng,"問い合わせは乱数を消費せず、保持から戻して同じ経路を判定する")
	check(not bridge.query_route(PackedVector2Array([Vector2(NAN,0),Vector2.ZERO]),{}).ok and not bridge.query_route(path,{"margin":NAN}).ok,"非有限の経路や幅を拒否する")
	bridge.release_checkpoint(held.value)
	session.free()
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true})
	var lab_path := PackedVector2Array([Vector2(-300,0),Vector2(300,0)])
	lab.run.state.gauge = 0.01
	var low: Dictionary = CHECK.validate(lab,lab_path)
	check(not low.valid and low.length>low.budget and low.blockers.size()>=2,"実験場も同じC++判定でゲージ不足と長さ超過を表示する")
	var canvas = load("res://gyms/enemy_lab/lab_canvas.gd").new()
	canvas.session = lab
	canvas.route = lab_path
	canvas.result = low
	canvas.size = Vector2(640,480)
	add_child(canvas)
	await get_tree().process_frame
	check(canvas.result==low and canvas.result.blockers.all(func(row): return not row.reason.is_empty()),"実験場の経路と阻害位置・理由へ同じ返答を渡す")
	canvas.free()
	lab.free()
	return true

func encounter_ticks(bridge, count: int) -> bool:
	for tick in count:
		var stepped: Dictionary = bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
		if not stepped.ok:
			push_error("配置更新の失敗: "+str(stepped))
			return false
		var frame: Dictionary = bridge.read_frame()
		var collected: Dictionary = bridge.collect_frame()
		if not frame.ok or not collected.ok or not bridge.delivery_error.get("ok",false):
			push_error("配置通知の失敗: "+str([frame,collected,bridge.delivery_error]))
			return false
	return true

func check_cpp_encounter() -> bool:
	for mode in (["window"] if "--cpp-encounter-window-fix" in OS.get_cmdline_user_args() else ["window","deferred","pack"]):
		var config: GameConfig = ContentManager.base.duplicate(true)
		config.start_radius = 900.0
		config.planet_radius = 100.0
		config.moon_count = 0
		config.meteor_count = 0
		config.iron_count = 0
		config.saw_count = 0
		config.draw_length = 1000.0
		config.world_tick_div = 1
		var stage := RuntimeStage.new()
		stage.index = 182
		stage.resources = StageResources.new()
		# 規則だけに登場する種類も生成対象へ引き継ぐ。
		stage.resources.enemy_ids = PackedStringArray(["drifter"])
		stage.enemy_tuning = {"drifter":{"hp":1.0,"armor":0.0,"speed":0.0}}
		var phase := PhaseDef.new()
		phase.id = &"配置確認"
		phase.pop_from = 4.0
		phase.pop_to = 4.0
		phase.rate = 1200.0
		phase.attack_budget = 1
		phase.mix = {"drifter":1.0}
		stage.phases = [phase]
		var region := {"type":"hound" if mode=="pack" else "drifter","pos":[0.0,250.0] if mode=="pack" else [0.0,0.0],"angle":0.0,"jitter":0.0,"role":"fodder" if mode=="window" else "avoid"}
		var pattern := {"route":[[-200.0,0.0],[200.0,0.0]],"regions":[region],"rotation":0.0,"scale_min":1.0,"scale_max":1.0,"margin":0.0,"window":0.05 if mode=="window" else 0.0,"attempts":2,"min_fodder":0 if mode=="pack" else 1}
		stage.encounter_profile = {"enabled":true,"interval":0.5,"phases":["配置確認"],"patterns":[pattern]}
		var builder = load("res://tools/content/build_run_content.gd")
		var output: String = "res://.content/dev/cpp_encounter_"+String(mode)
		if builder.build(stage,config,output,("採用配置"+mode).sha256_text())!=OK: return false
		var index_path: String = output.path_join("stage_182.json")
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
		var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":index_path,"cpp_signature":index.input_sha256,"seed":194},true)
		session.auto_step = false
		while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
		if session.bridge==null: session.free(); return false
		var bridge = session.bridge
		var core = bridge._core
		bridge.command("dev_remove_weapon",{"id":"W01"})
		bridge.command("dev_ship_defense",{"shield":0.0,"invulnerability":10.0})
		var events: Array = []
		bridge.subscribe("配置確認",func(frame: Dictionary) -> bool:
			events.append_array(frame.events)
			return true)
		if mode=="window": core.set_population_mode(true,false,false)
		check(encounter_ticks(bridge,1),"候補の生成から固定更新・通知配信まで成功する: "+mode)
		var opportunity: Dictionary = bridge.read_encounter().value
		if mode=="deferred":
			check(core.enemies_snapshot().is_empty() and not opportunity.available and events.any(func(event): return event.type==&"encounter_deferred"),"不成立の候補を出現させず、見送りだけを通知する")
		else:
			var enemies: Array = core.enemies_snapshot()
			check(opportunity.available and opportunity.route.size()==2 and events.any(func(event): return event.type==&"route_opportunity"),"採用した規則の経路と成立を通知する: "+mode)
			check(core.enemy_motion_snapshot().all(func(row): return row.spawn_origin==preload("res://tools/content/generated/run_schema.gd").ENUMS.SpawnOrigin.Summon),"遭遇と群れの随伴をSummon由来で記録する: "+mode)
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			var frame: Dictionary = bridge.read_render(Rect2(-1600,-500,1500,1200))
			check(frame.ok and presentation.frame_view.apply_frame(frame.value) and frame.value.batches.any(func(batch): return not batch.ids.is_empty()),"採用規則から出た実際の敵を通常画面で表示する: "+mode)
			await get_tree().process_frame
			if mode=="pack":
				check(enemies.size()==int(ContentManager.enemies[&"hound"].params.pack_count) and core.hound_snapshot().packs.size()==1,"規則で追加した猟犬から型付き共通入口で随伴も生成する")
			else:
				check(opportunity.guard_active and enemies.size()==1,"時間幅の間は既存guardが追加補充を止める")
				var held: Dictionary = bridge.checkpoint()
				check(encounter_ticks(bridge,5) and bridge.read_encounter().value.guard_active and core.enemy_motion_snapshot().all(func(row): return row.spawn_origin!=preload("res://tools/content/generated/run_schema.gd").ENUMS.SpawnOrigin.Refill),"期限前は経路保護と補充停止を保つ")
				check(encounter_ticks(bridge,2) and not bridge.read_encounter().value.guard_active and core.enemies_snapshot().size()>1,"期限を過ぎると保護を解き、通常の補充へ戻す")
				check(encounter_ticks(bridge,57),"次の候補の抽選まで進める")
				var after: Array = core.enemies_snapshot()
				var after_opportunity: Dictionary = bridge.read_encounter().value
				var after_rng: String = core.inspect().rng_state
				check(bridge.restore(held.value).ok and bridge.read_encounter().value==opportunity,"次回時刻・成立経路・保護期限を値で保持から戻す")
				check(encounter_ticks(bridge,64) and core.enemies_snapshot()==after and bridge.read_encounter().value==after_opportunity and core.inspect().rng_state==after_rng,"復帰後も候補抽選・出現・保護・RunRandomが一致する")
				bridge.release_checkpoint(held.value)
		bridge.unsubscribe("配置確認")
		session.free()
	return true

func check_cpp_lab_constraints() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true})
	var route := PackedVector2Array([Vector2(-300,0),Vector2(300,0)])
	check(lab.perform("spawn",{"type":"drifter","pos":[0,0]}),"制約確認の敵を正式命令で置く")
	check(CHECK.validate(lab,route).valid,"C++所有の弱い敵は障害物にしない")
	check(CHECK.validate(lab,route,20,1).status=="unsupported","動く敵の静止判定を時間幅の保証にしない")
	lab.perform("spawn",{"type":"armored","pos":[0,0]})
	var blocked: Dictionary = CHECK.validate(lab,route)
	check(not blocked.valid and blocked.blockers.all(func(row): return not row.reason.is_empty()),"C++の中間衝突と理由を同じ形式で表示する")
	lab.perform("clear")
	lab.perform("spawn",{"type":"drifter","pos":[0,0]})
	lab.perform("parameter",{"type":"drifter","key":"speed","value":0})
	check(CHECK.validate(lab,route,20,1).status=="window","静止したモデルの時間幅を直接判定する")
	lab.perform("ship",{"pos":[0,0],"gauge":0.01})
	var low: Dictionary = CHECK.validate(lab,route)
	check(not low.valid and low.length>low.budget,"ゲージ不足と長さ超過を同じC++判定で表示する")
	lab.perform("ship",{"pos":[0,0],"gauge":1.0})
	lab.history.append({"tick":lab.tick+120,"kind":"spawn","args":{"type":"drifter","pos":[900,900]}})
	check(CHECK.validate(lab,route,20,2).status=="unsupported","120Hzの未来命令を時間幅へ含める")
	check(lab.bridge.read_frame().ok and lab.bridge.collect_frame().ok and lab.bridge.delivery_error.get("ok",false),"制約の問い合わせ後も通知配信が成功する")
	lab.queue_free()
	await get_tree().process_frame
