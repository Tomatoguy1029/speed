## 保持したC++ランを複製し、隠れた待機・時計・集合を含む先の結果を比較する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
var failed := 0
var restore_state_only := false
func check(ok: bool, label: String) -> void:
	if restore_state_only and not (label.begins_with("通常敵全種類") or label.begins_with("候補の外部要求")): return
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--restore-heroes" in OS.get_cmdline_user_args():
		check_restore_heroes()
		print("[restore_heroes] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--restore-draco-final" in OS.get_cmdline_user_args():
		check_restore_draco_final()
		print("[restore_draco_final] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--restore-outputs" in OS.get_cmdline_user_args() or "--restore-state-only" in OS.get_cmdline_user_args():
		restore_state_only="--restore-state-only" in OS.get_cmdline_user_args()
		await check_restore_outputs()
		print("[restore_outputs] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	await check_restore_outputs()
	print("[restore_outputs] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func restore_logical(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key in value:
			if key!="request_id": out[key]=restore_logical(value[key])
		return out
	if value is Array:
		var out: Array=[]
		for item in value: out.append(restore_logical(item))
		return out
	return value

func restored_state(bridge) -> Dictionary:
	var population = load("res://tests/runtime/run_population.gd").new()
	var value: Dictionary = population.semantics_observe(bridge)
	population.free()
	value.budget=bridge._core.attack_budget_snapshot()
	value.groups=bridge._core.hound_snapshot()
	value.combat=bridge._core.combat_snapshot()
	return value

func restored_render(bridge) -> Array:
	var frames: Array = []
	for alpha in [0.0,0.375,1.0]:
		var result: Dictionary = bridge.read_render(Rect2(-2500,-1200,3200,2400),alpha)
		check(result.ok,"表示補間の読取が成功する")
		var frame: Dictionary = result.value.duplicate(true)
		for key in ["epoch","state_revision","run_id"]: frame.erase(key)
		frames.append(frame)
	return frames

func restore_step(bridge, tick: int) -> void:
	var intent := Intent.new()
	intent.has_cursor=true;intent.cursor=Vector2(-400+tick*3.0,200)
	bridge.step(1.0/120.0,bridge.pack_intent(intent),{"logical_size":Vector2(1280,720)})

func check_restore_outputs() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.weapon_slots=32;config.trait_slots=32
	config.planet_radius=0;config.moon_count=0;config.meteor_count=0;config.iron_count=0;config.saw_count=0
	var stage := RuntimeStage.new()
	stage.index=198;stage.resources=StageResources.new()
	stage.boss_enabled = false
	var definitions := {}
	for id in ContentManager.enemies:
		var definition: EnemyDef = ContentManager.enemies[id]
		if definition.behavior in [&"part",&"triangle_star",&"soldier",&"meteor",&"obstacle",&"saw"]: continue
		if load("res://tools/content/build_run_content.gd").chase_package(definition,config,stage).is_empty(): continue
		definitions[id]=definition
		stage.resources.enemy_ids.append(String(id))
	var output := "res://.content/dev/checkpoint_outputs"
	var built: Error = load("res://tools/content/build_run_content.gd").build(stage,config,output,"D08の共通不足".sha256_text(),definitions)
	if built!=OK: check(false,"全移行済み通常敵・装備の保持用定義を生成する");return
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("stage_198.json")))
	var bytes := FileAccess.get_file_as_bytes(index.binary)
	var helper = load("res://tests/runtime/run_population.gd").new()
	var bridge = helper.semantics_bridge(bytes,59)
	if bridge==null: check(false,"共通保持場面を開始する");helper.free();return
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"invincible":true,"auto_spawn":false,"empty":true}})
	for kind in ["weapons","traits"]:
		for id in ContentManager.catalog.table(StringName(kind)):
			bridge.command("dev_grant_equipment",{"kind":"weapon" if kind=="weapons" else "trait","id":String(id),"levels":2})
	var count := 0
	for id in definitions:
		bridge._core.spawn_enemy(id,Vector2(-700+(count%8)*100,-300+(count/8)*80))
		count += 1
	for tick in 24: restore_step(bridge,tick)
	check(bridge.command("dev_edit",{"kind":"debug_action","payload":{"action":"hazards","args":{}}}).ok,"複数形状の残留攻撃を保持場面へ加える")
	var carrier: int = bridge._core.spawn_enemy(&"splitling",Vector2(-1500,300))
	for kind in [0,1,2]:
		var crystal: Dictionary = bridge.command("dev_drop_crystal",{"position":Vector2(-1500,300),"kind":kind})
		if kind==1: bridge.command("dev_carry_crystal",{"entity_id":carrier,"crystal_id":crystal.value})
	bridge.command("dev_add_xp",{"amount":100.0})
	restore_step(bridge,24)
	bridge.collect_frame()
	var before: Dictionary = restored_state(bridge)
	var ui: Dictionary = bridge._ui.duplicate(true)
	var render: Array = restored_render(bridge)
	check(render[0]!=render[2],"保存前にPreviousPoseと現在Poseの差を実際に作る")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"通常敵・装備・候補待ち・運搬・攻撃を一緒に保持する")
	var old_hash: String = bridge.read_recording(true).value.identity.payload_sha256
	bridge.dispose();bridge=null
	var changed: GameConfig = config.duplicate(true)
	changed.base_max_speed *= 1.1
	var replacement := "res://.content/dev/checkpoint_outputs_changed"
	if load("res://tools/content/build_run_content.gd").build(stage,changed,replacement,"異なる現定義".sha256_text(),definitions)!=OK:
		check(false,"変更後のSource定義を生成する");helper.free();return
	var next_index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(replacement.path_join("stage_198.json")))
	var restored = helper.semantics_bridge(FileAccess.get_file_as_bytes(next_index.binary),60)
	var delivered: Array = []
	restored.subscribe("復帰出力",func(frame): delivered.append(frame.duplicate(true));return true)
	var voice: int = AudioManager._next
	var earlier_epoch: int=restored._epoch
	var stale={"run_id":restored._run_id,"epoch":earlier_epoch,"command_id":restored._next_command,"kind":"resources_complete","payload":{"request_id":1,"status":1}}
	check(restored.restore(held.value).ok,"元の複合ラン破棄後に独立したランへ復元する")
	check(restored.read_recording(true).value.identity.payload_sha256==old_hash and old_hash!=next_index.payload_sha256,"複合状態を保持した旧ContentBundleへ戻す")
	var state_diff: String=COMPARE.new().difference(COMPARE.new().plain(before),COMPARE.new().plain(restored_state(restored)))
	check(state_diff.is_empty(),"通常敵全種類・装備・群れ・運搬・攻撃・候補待ちの状態を値として復元する: "+state_diff)
	var first: Dictionary = restored.read_frame().value
	check(restored._epoch>earlier_epoch and not first.resource_requests.is_empty() and first.ui.cards.candidates[0].request_id>0 and not restored.send_envelope(stale).ok,"候補の外部要求は新epochで再発行し旧完了を拒否する")
	if restore_state_only:
		print("RESTORE_STATE_DIFFERENCE ",state_diff," REISSUED ",first.resource_requests.size())
		restored.release_checkpoint(held.value);restored.dispose();helper.free();return
	check(restored_render(restored)==render,"PreviousPoseを含む3つの補間率の表示を復元する")
	check(restore_logical(first.ui)==restore_logical(ui),"復帰直後に全UI項目を再送する（外部資源要求番号だけ再発行）")
	check(first.events.is_empty() and first.result==null,"過去の通知・音・結果を復帰直後に再発行しない")
	check(restored.collect_frame().ok and delivered.size()==1,"復帰した表示を購読先へ一度届ける")
	AudioManager.consume_cpp_frame(first)
	check(AudioManager._next==voice,"過去の音を復帰後に再生しない")
	var current: Dictionary = restored_state(restored)
	var current_render: Array = restored_render(restored)
	var epoch: int = restored._epoch
	check(not restored.restore(-1).ok and restored._epoch==epoch and restored_state(restored)==current and restored_render(restored)==current_render,"複合状態の復帰失敗は現ランと表示を保持する")
	var independent = helper.semantics_bridge(bytes,61)
	check(independent.restore(held.value).ok,"保持点を別ランにも独立復元する")
	var other: Dictionary = restored_state(independent)
	restored.command("dev_edit",{"kind":"level","payload":{"value":20}})
	check(restored_state(independent)==other,"復元先の変更を別ランと保持点へ漏らさない")
	independent.dispose();restored.release_checkpoint(held.value);restored.dispose()
	# 確定済みの結果も状態として保持する。外部への結果通知と過去音は増やさない。
	var ended = helper.semantics_bridge(bytes,62)
	var session := RunSession.new()
	var results: Array=[]
	session.cpp_finished.connect(func(result):results.append(result))
	ended.subscribe("結果",session._consume_cpp_result)
	ended.command("dev_finish",{"cleared":true})
	session.flush_cpp_result()
	var result_point: Dictionary=ended.checkpoint()
	var result_id: int=results[0].result_id if results.size()==1 else 0
	check(result_point.ok and result_id>0,"確定済みの結果を持つ状態も保持する")
	var voices_before: int=AudioManager._next
	check(ended.restore(result_point.value).ok and ended.collect_frame().ok,"結果確定後の保持点へ復元する")
	session.flush_cpp_result()
	var result_frame: Dictionary=ended.read_frame().value
	AudioManager.consume_cpp_frame(result_frame)
	check(results.size()==1 and result_frame.result.result_id==result_id and result_frame.events.is_empty() and AudioManager._next==voices_before,"確定済み結果の復帰で結果通知と過去音を再発行しない")
	ended.release_checkpoint(result_point.value);ended.dispose();session.free();helper.free()

func draco_restore_state(bridge) -> Dictionary:
	var core=bridge._core
	return {"run":core.inspect(),"ship":core.ship_snapshot(),"draw":core.draw_snapshot(),"enemies":core.enemies_snapshot(),"motion":core.enemy_motion_snapshot(),"friends":core.projectiles_snapshot(),"hostiles":core.hostiles_snapshot(),"hazards":core.hazards_snapshot(),"body":bridge.command("dev_boss_body_state").value,"lab":bridge.read_lab().value}

func check_restore_draco_final() -> void:
	var helper=load("res://tests/integration/draco_cinematics.gd").new()
	if not helper.has_method("finale_fixture"):
		check(false,"最終決着を含む統合版の検査入口を使う");helper.free();return
	var f: Dictionary=helper.finale_fixture(Vector2(1280,720),INF,load("res://data/bosses/draco_moves/rifts.tres"))
	if f.is_empty():check(false,"最終決着の保持場面を開始する");helper.free();return
	f.bridge.command("dev_boss_technique",{"entity_id":f.boss,"definition":1})
	for tick in 2400:
		f.bridge._core.step(1.0/120.0)
		if not helper.finale_body(f).rift_walls.is_empty():break
	f.bridge.command("dev_draco_finale",{"entity_id":f.boss,"operation":"begin"})
	check(int(helper.finale_body(f).closing_walls)>0,"復元用の核解放に実在する裂け目の修復状態を含める")
	var start:=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--restore-draco-from="):start=int(arg.get_slice("=",1))
	var stages: Array[String]=["release","combine","pose","input","strikes","charge","flash","sight","explode"]
	for index in stages.size():
		var stage: String=stages[index]
		if not helper.finale_to(f,stage):check(false,"保持する決着の段階へ進む: "+stage);break
		# 段階の途中の姿勢・カメラ・筆跡を保持する。入力待ちは解放せず筆跡を残す。
		for tick in 3:
			var input:=Intent.new()
			if stage=="input":input.press=tick==0;input.pen=Vector2(180+tick*20,80+tick*15);input.has_cursor=true
			helper.finale_tick(f,input)
		if index<start:continue
		var before: Dictionary=draco_restore_state(f.bridge)
		var render: Array=restored_render(f.bridge)
		var ui: Dictionary=f.bridge.read_frame().value.ui.duplicate(true)
		var point: Dictionary=f.bridge.checkpoint()
		if not point.ok:check(false,"最終決着の途中を保持する: "+stage);break
		f.events.clear()
		for tick in 3:helper.finale_tick(f)
		var future: Dictionary=draco_restore_state(f.bridge)
		var future_events: Array=f.events.duplicate(true)
		f.bridge.dispose()
		var restored: Dictionary=helper.finale_fixture(Vector2(1280,720),INF,load("res://data/bosses/draco_moves/rifts.tres"))
		var voices: int=AudioManager._next
		if not restored.bridge.restore(point.value).ok:check(false,"元ラン破棄後に決着を独立復元する: "+stage);restored.bridge.dispose();break
		var actual: Dictionary=draco_restore_state(restored.bridge)
		var diff: String=COMPARE.new().difference(COMPARE.new().plain(before),COMPARE.new().plain(actual))
		var frame: Dictionary=restored.bridge.read_frame().value
		var exact: bool=before==actual
		check(exact,"決着の全状態を値として独立復元する: "+stage+" "+diff)
		check(restored_render(restored.bridge)==render,"決着のPreviousPoseと表示補間を独立復元する: "+stage)
		check(restore_logical(frame.ui)==restore_logical(ui),"決着の全UIとカメラを独立復元して再送する: "+stage)
		AudioManager.consume_cpp_frame(frame)
		check(frame.events.is_empty() and frame.result==null and AudioManager._next==voices,"決着の過去通知・結果・音を再送しない: "+stage)
		restored.events.clear()
		for tick in 3:helper.finale_tick(restored)
		check(draco_restore_state(restored.bridge)==future and restored.events==future_events,"決着の復元後の状態と論理通知を同じ入力で再現する: "+stage)
		restored.bridge.release_checkpoint(point.value)
		f=restored
		print("RESTORE_DRACO_STAGE ",stage," failed=",failed)
		if failed:break
	f.bridge.dispose();helper.free()

func hero_restore_state(bridge) -> Dictionary:
	return {"core":draco_restore_state(bridge),"hero":bridge.read_frame().value.ui.hero,"draw":bridge.read_frame().value.ui.draw}

func restore_hero_point(bridge,fixture,behavior,label: String):
	bridge.collect_frame()
	var before: Dictionary=hero_restore_state(bridge)
	var render: Array=restored_render(bridge)
	var ui: Dictionary=bridge.read_frame().value.ui.duplicate(true)
	var held: Dictionary=bridge.checkpoint()
	if not held.ok:check(false,"英雄の重要状態を保持する: "+label);return bridge
	fixture._cpp_events.clear()
	for tick in 3:behavior._cpp_step(bridge)
	var future: Dictionary=hero_restore_state(bridge)
	var future_events: Array=fixture._cpp_events.duplicate(true)
	bridge.dispose()
	var restored=fixture._cpp_fixture(true,100000.0,100000.0)
	var voices: int=AudioManager._next
	if not restored.restore(held.value).ok:check(false,"元ラン破棄後に英雄を独立復元する: "+label);return restored
	var actual: Dictionary=hero_restore_state(restored)
	check(before==actual,"英雄の全状態を値として独立復元する: "+label+" "+COMPARE.new().difference(COMPARE.new().plain(before),COMPARE.new().plain(actual)))
	check(restored_render(restored)==render,"英雄のPreviousPoseと表示補間を独立復元する: "+label)
	var frame: Dictionary=restored.read_frame().value
	check(restore_logical(frame.ui)==restore_logical(ui),"英雄の全UIを独立復元して再送する: "+label)
	AudioManager.consume_cpp_frame(frame)
	check(frame.events.is_empty() and frame.result==null and AudioManager._next==voices,"英雄の過去通知・結果・音を再送しない: "+label)
	fixture._cpp_events.clear()
	for tick in 3:behavior._cpp_step(restored)
	check(hero_restore_state(restored)==future and fixture._cpp_events==future_events,"英雄の復元後の状態と論理通知を同じ入力で再現する: "+label)
	restored.release_checkpoint(held.value)
	print("RESTORE_HERO ",label," failed=",failed)
	return restored

func check_restore_heroes() -> void:
	var fixture=load("res://tests/integration/hero_guidance.gd").new()
	var behavior=load("res://tests/runtime/hero_behaviors.gd").new()
	for id in ["perseus","leo","gemini","hercules"]:
		var bridge=fixture._cpp_fixture(true,100000.0,100000.0)
		behavior._cpp_rescue(bridge,id)
		bridge.command("dev_ship_motion",{"position":Vector2(-300,0),"velocity":Vector2.ZERO})
		var enemy: int=bridge.command("dev_spawn",{"definition_id":"splitling","position":Vector2(120,0)}).value
		if id=="perseus":bridge.command("dev_fire_enemy",{"source_id":enemy,"angle":0.0,"speed":100.0})
		var input:=Intent.new()
		input.hero_press=true;behavior._cpp_step(bridge,input)
		if id in ["leo","gemini"]:
			behavior._cpp_draw(bridge)
			bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
		bridge=restore_hero_point(bridge,fixture,behavior,id+"/発動中")
		if id=="gemini" and not failed:
			bridge._core.step_draw(0.01)
			bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
			check(bridge.read_frame().value.ui.hero.twin.tracing,"独立復元する影が反転した経路を実際に進む")
			bridge=restore_hero_point(bridge,fixture,behavior,"gemini/影の走行途中")
		if id=="hercules" and not failed:
			behavior._cpp_hero_tick(bridge,0.3,0.3);behavior._cpp_hero_tick(bridge,0.3,0.6)
			check(not bridge.read_frame().value.ui.hero.hercules.falls.is_empty() and not bridge.read_frame().value.ui.hero.hercules.burns.is_empty(),"独立復元する落下と燃焼が同時に存在する")
			bridge=restore_hero_point(bridge,fixture,behavior,"hercules/落下と燃焼")
		bridge.dispose()
		if failed:break
	check(fixture.failed==0 and behavior.failed==0,"英雄の保持場面の既存準備入口が成功する")
	fixture.free();behavior.free()
