## 領域別の人数・上限・画面外の再配置・出現位置と乱数を比較する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	check(await check_cpp_mix(),"密集する通常構成を最後まで確認する")
	get_tree().quit(1 if failed else 0)

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
func semantics_bridge(bytes: PackedByteArray, seed_value: int, profile: Dictionary={}):
	if not ClassDB.class_exists(&"SpeedRunCore"):
		var probe = COMPARE.new().create_native()
		if probe==null: return null
		probe.close()
	var bridge = MIX_BRIDGE.new()
	bridge.subscribe("統計の受領",func(_packet):return true)
	if not bridge.configure(bytes,{"api_version":1,"run_id":seed_value+1,"mode":1,"stage_id":"semantics","profile":profile,"settings":{"hitstop":false}}).ok: return null
	if not bridge.start(seed_value,{"position":Vector2(-900,0),"lab_mode":true}).ok: return null
	bridge.command("dev_remove_weapon",{"id":"W01"})
	bridge._core.set_motion_context(Vector2(-900,0),Vector2(-900,0),Vector2(640,360))
	return bridge

func semantics_observe(bridge) -> Dictionary:
	var core = bridge._core
	return {"clock":core.inspect(),"ship":core.ship_snapshot(),"draw":core.draw_snapshot(),"enemies":core.enemies_snapshot(),"motion":core.enemy_motion_snapshot(),"population":core.population_snapshot(),"refill":core.refill_snapshot(),"pickups":core.pickups_snapshot(),"clips":core.clips_snapshot(),"friends":core.projectiles_snapshot(),"hostiles":core.hostiles_snapshot(),"hazards":core.hazards_snapshot()}
