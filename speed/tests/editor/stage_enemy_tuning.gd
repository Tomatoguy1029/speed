## ステージ局所の敵調整の保存・生成・ライブ反映を、ソースを書き換えずに確認する。
extends Node
const IO := preload("res://scripts/dev/stage_enemy_edit.gd")
const BUILD := preload("res://tools/content/build_runtime_stage.gd")
var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	if "--cpp-save" in OS.get_cmdline_user_args():
		check(await cpp_save(self,false),"F4の保存からC++の再出撃まで確認する")
		print("[cpp_save] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var common := IO.definition("telescope")
	var cfg := ContentManager.cfg.duplicate(true) as GameConfig
	var hp := common.base_hp(cfg)
	var damage: float = common.params.bullet_dmg
	var source := ContentManager.stage(4).duplicate(true) as StageDef
	source.enemy_tuning = {"telescope": {"hp": hp * 2.0, "params.bullet_dmg": damage + 3.0, "params.cooldown": 2.0}}
	check(IO.validate(source.enemy_tuning).is_empty(), "星のHPと敵固有数値を検証できる")
	check(not IO.validate({"telescope": {"xp": 5.0}}).is_empty(), "共通のXPを編集対象から外す")
	check(not IO.validate({"telescope": {"params.cooldown": 0.0}}).is_empty(), "不正な攻撃間隔を拒否する")
	check(not IO.validate({"telescope": {"hp": NAN}}).is_empty(), "非有限値を拒否する")
	var path := "/tmp/speed-stage-enemy-tuning-fixture.tres"
	ResourceSaver.save(source, path)
	var initial := IO.read_stage(path)
	check(initial.enemy_tuning == source.enemy_tuning, "ステージに差分を保存・再読込できる")
	# 他のステージ設定の編集と共存し、敵調整の同時編集は検出する。
	initial.boss_time = 123.0
	ResourceSaver.save(initial, path)
	var edited := source.enemy_tuning.duplicate(true)
	edited.telescope["params.bullet_dmg"] = damage + 8.0
	check(IO.save(path, edited, source.enemy_tuning).has("stage"), "敵調整だけを保存できる")
	check(IO.read_stage(path).boss_time == 123.0, "保存時に他のステージ設定を維持する")
	check(IO.save(path, {}, source.enemy_tuning).has("error"), "別の敵調整を古い状態で上書きしない")
	var panel = load("res://scripts/dev/stage_enemy_panel.gd").new()
	panel.stage_path = path
	add_child(panel)
	panel._select_enemy("telescope")
	panel._edit_value(hp * 4.0, "hp", hp)
	check(panel.is_dirty(), "UIの数値変更を未保存の試行として保持する")
	panel.open_stage(path)
	check(panel.values.telescope.hp == hp * 4.0, "同じステージの再選択で試行を失わない")
	panel.reload_stage()
	check(not panel.is_dirty() and panel.values == edited, "UIの再読込で保存済み設定へ戻せる")
	panel.free()
	var runtime := BUILD.compile(IO.read_stage(path))
	check(runtime.enemy_tuning == edited, "buildでRuntimeStageに差分を反映する")
	var baked_path := "/tmp/speed-stage-enemy-tuning-runtime.tres"
	ResourceSaver.save(runtime, baked_path)
	runtime = IO.read_stage(baked_path)
	check(runtime.enemy_tuning == edited, "生成物の再読込でも差分を保持する")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(baked_path)
	check(await cpp_save(self,false),"F4の保存からC++の再出撃まで確認する")
	print("[stage_enemy_tuning] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func cpp_save(parent: Node, failure_only: bool) -> bool:
	var source := StageDef.new()
	source.index = 196 if failure_only else 197
	source.enemies = [&"drifter"]
	var fixture := "/tmp/speed-cpp-save-%d.tres" % source.index
	if ResourceSaver.save(source,fixture)!=OK: return false
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	# 共通生成で準備済みの外観索引と同じ出力ルートを使う。
	var output := "res://.content"
	var generator = load("res://addons/content_build/builder.gd")
	if generator.build_cpp_stage(source,config,output)!=OK: return false
	var path := output.path_join("run/stage_%d.json" % source.index)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var runtime := BUILD.compile(source,output,config)
	var session: RunSession = RunManager.create_session(parent,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":53,"cpp_edit_source":{"stage":runtime,"config":config}},false)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await parent.get_tree().process_frame
	if session.bridge==null: return false
	var bridge = session.bridge
	if not bridge.command("dev_remove_weapon",{"id":"W01"}).ok or not bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-500,300)}).ok: return false
	var original: Dictionary = bridge._core.enemies_snapshot()[0]
	var layer := CanvasLayer.new()
	parent.add_child(layer)
	var overlay = load("res://scripts/dev/stage_enemy_overlay.gd").new()
	overlay.cpp_session = session
	layer.add_child(overlay)
	overlay.show()
	await parent.get_tree().process_frame
	if overlay.content_edit==null: return false
	var panel: Control = overlay.panel
	panel.stage_path = fixture
	panel._select_enemy("drifter")
	var base: float = ContentManager.enemies[&"drifter"].base_hp(config)
	panel._edit_value(base*2.0,"hp",base)
	if failure_only:
		overlay.hide()
		overlay.show()
		check(overlay.panel==panel and panel.is_dirty() and panel.values.drifter.hp==base*2.0 and IO.read_stage(fixture).enemy_tuning.is_empty(),"F4を閉じても未保存値を保持し編集元には書かない")
		var previous := FileAccess.get_sha256(path)
		var generated: Array = []
		panel.saved.connect(func(_stage): generated.append(true))
		panel._save()
		check(panel._status.text.contains("次回起動時") and generated.size()==1,"Saveは編集元の保存だけを通知する")
		check(IO.read_stage(fixture).enemy_tuning.drifter.hp==base*2.0 and FileAccess.get_sha256(path)==previous,"保存済みの編集元と古い生成物を区別する")
		panel.values = {"drifter":{"hp":NAN}}
		panel._save()
		check(IO.read_stage(fixture).enemy_tuning.drifter.hp==base*2.0 and FileAccess.get_sha256(path)==previous and not panel._status.text.contains("次回起動時"),"不正な保存値で編集元と生成物を変更しない")
	else:
		var notifications: Array = []
		bridge.subscribe("保存確認",func(frame: Dictionary) -> bool:
			notifications.append_array(frame.events)
			return true)
		panel._save()
		check(panel._status.text.contains("次回起動時") and not panel.is_dirty() and IO.read_stage(fixture).enemy_tuning.drifter.hp==base*2.0,"Saveが編集元へ保存し、次回起動時の生成を表示する")
		# 次回起動と同じ共通入口で、保存済みSourceから実行用データを生成する。
		if load("res://addons/content_build/builder.gd").build_cpp_stage(IO.read_stage(fixture),config,output)!=OK: return false
		var saved_path: String = output.path_join("run/stage_%d.json" % source.index)
		var saved_index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saved_path))
		var next: RunSession = RunManager.create_session(parent,{"runtime":"cpp","cpp_index":saved_path,"cpp_signature":saved_index.input_sha256,"seed":53},false)
		next.auto_step = false
		while next.bridge==null and next.cpp_error==OK: await parent.get_tree().process_frame
		if next.bridge==null: return false
		if not next.bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-500,300)}).ok: return false
		check(is_equal_approx(next.bridge._core.enemies_snapshot()[0].max_hp,original.max_hp*2.0),"保存後の生成物で次のC++ランを起動する")
		check(notifications.any(func(event): return event.type==&"enemy_tuning_saved" and event.payload.path==fixture and event.payload.values.drifter.hp==base*2.0),"保存内容を生成済みの型付き定義から通知する")
		check(next.bridge.read_frame().ok and next.bridge.collect_frame().ok and next.bridge.delivery_error.get("ok",false),"再出撃のフレーム回収と通知配信が成功する")
		next.free()
	var stepped: Dictionary = bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)})
	check(stepped.ok and bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.get("ok",false),"保存操作後も固定更新と通知配信が成功する")
	layer.free()
	session.free()
	DirAccess.remove_absolute(fixture)
	return true
