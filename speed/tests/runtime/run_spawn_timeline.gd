## 全ステージの目標人数・強化帯・ボーナス配分を生成データの保存前後で比較する。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	await timeline_preview()
	get_tree().quit(1 if failed else 0)

func timeline_preview() -> void:
	var request := preload("res://addons/stage_launcher/launch_request.gd")
	var timeline_plugin := preload("res://addons/spawn_timeline/plugin.gd")
	var panel := preload("res://addons/spawn_timeline/timeline.gd").new()
	var root := EnemyFormation.new()
	root.name = "途中再生"
	root.types.assign([&"shield"])
	var layout := FormationLayout.new()
	layout.name = "並び"
	root.add_child(layout)
	layout.owner = root
	var marker := FormationMarker.new()
	marker.name = "敵"
	marker.enemy = &"shield"
	layout.add_child(marker)
	marker.owner = root
	var entry := FormationEntry.new()
	entry.name = "入口"
	entry.position = Vector2(260,-120)
	root.add_child(entry)
	entry.owner = root
	var packed := PackedScene.new()
	check(packed.pack(root)==OK,"途中再生用の編成を保存する")
	root.free()
	var formation_path := "res://.content/dev/d06_formation.tscn"
	check(ResourceSaver.save(packed,formation_path)==OK,"編成の制作元を保存する")
	var source := StageDef.new()
	source.index = 901
	source.boss_enabled = false
	source.enemies.assign([&"shield"])
	var phase := PhaseDef.new()
	phase.id = &"途中再生"
	phase.attack_budget = 3
	source.phases = [phase]
	var clip := SpawnClip.new()
	clip.time = 120
	clip.length = 60
	clip.types.assign([&"shield"])
	clip.formations.assign([load(formation_path)])
	source.clips = [clip]
	var source_path := "res://.content/dev/d06_source.tres"
	check(ResourceSaver.save(source,source_path)==OK,"タイムラインの制作元を保存する")
	source.take_over_path(source_path)
	panel.stage = source
	for time in [0.0,130.0]:
		await preview_from_saved(request,timeline_plugin,source,time,time>0.0,"時刻%d" % time)
	# 編集・取消が保存する同じプロパティと保存メソッドを、値を戻すUndoRedoへ通す。
	var history := UndoRedo.new()
	history.create_action("クリップの開始を変える")
	history.add_do_property(clip,"time",200.0)
	history.add_undo_property(clip,"time",120.0)
	history.add_do_method(panel._save_stage.bind(source))
	history.add_undo_method(panel._save_stage.bind(source))
	history.commit_action()
	await preview_from_saved(request,timeline_plugin,source,130.0,false,"クリップ編集")
	check(history.undo(),"クリップ編集を取り消す")
	await preview_from_saved(request,timeline_plugin,source,130.0,true,"クリップ取消")
	var saved_clip := source.clips[0].groups
	source.clips[0].groups = -1
	check(panel._save_stage(source)==OK,"無効な編集値もSourceの保存結果と区別する")
	request.request(source.index,130.0,"timeline",source_path)
	check(timeline_plugin.prepare_timeline_request()!=OK,"無効なクリップは生成時に起動を拒否する")
	check(request.consume()==source.index and request.content.is_empty(),"失敗した生成結果で古い生成物を起動しない")
	source.clips[0].groups = saved_clip
	history.clear_history()
	panel.free()
	print("[cpp_timeline_preview] failed=%d" % failed)

func preview_from_saved(request, timeline_plugin, source: StageDef, time: float, expected_clip: bool, label: String) -> void:
	request.request(source.index,time,"timeline",source.resource_path)
	var error: Error = timeline_plugin.prepare_timeline_request()
	check(error==OK,label+"：保存済みの制作元から正規生成する")
	if error!=OK: return
	check(request.consume()==source.index,label+"：起動予約を一度だけ受け取る")
	GameManager.run_stage = source.index
	GameManager.run_start_source = request.source
	GameManager.run_start_time = request.start_time
	GameManager.run_start_content = request.content.duplicate(true)
	var session: RunSession = RunManager.create_run()
	session.auto_step = false
	add_child(session)
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null and session.runtime_kind=="cpp",label+"：共通窓口から表示付きC++ランを開始する")
	if session.bridge==null:
		session.free()
		return
	var bridge: RefCounted = session.bridge
	if time == 0.0:
		var prepared := preload("res://scripts/runtime/run_content_loader.gd").read_bundle(session.cpp_index_path,request.content.signature)
		var probe := preload("res://scripts/runtime/run_bridge.gd").new()
		check(probe.configure(prepared.bytes,{"api_version":1,"run_id":900001,"mode":1,"stage_id":"901","profile":{},"settings":{}}).ok,"開始シナリオの検査用ランを準備する")
		check(not probe.start(932,{"scenario":{"kind":"timeline","params":{"time":-1.0}}}).ok,"負の開始時刻を拒否する")
		check(not probe.start(932,{"scenario":{"kind":"timeline","params":{"time":INF}}}).ok,"有限でない開始時刻を拒否する")
		check(probe.start(932,{"scenario":{"kind":"timeline","params":{"time":0.0}}}).ok,"無効な開始入力で新しいランを壊さない")
		probe.dispose()
	var ui: Dictionary = bridge.read_frame().value.ui
	check(is_equal_approx(ui.run_time,time) and ui.world_time==0.0 and ui.level==0 and ui.xp==0.0,label+"：ラン時計だけを指定し成長や世界時計を進めない")
	check(bridge.recording_origin.start.options.scenario=={"kind":"timeline","params":{"time":time}},label+"：Ctrl+F9へ途中再生の開始条件を渡す")
	check(GameManager.run_start_content.is_empty() and GameManager.run_start_time==0.0 and GameManager.run_start_source=="stage_start",label+"：次のランへ途中再生を持ち越さない")
	var cards: Dictionary = ui.cards
	check(not cards.candidates.is_empty(),label+"：通常と同じ初期武器選択を出す")
	if not cards.candidates.is_empty():
		check(bridge.command("choose_card",{"offer_id":cards.offer_id,"candidate_id":cards.candidates[0].candidate_id}).ok,label+"：初期武器を選択する")
		for i in 600:
			bridge.collect_frame()
			if bridge.read_frame().value.ui.cards.offer_id==0: break
			await get_tree().process_frame
	var input: Dictionary = bridge.pack_intent(Intent.new())
	for i in 8: check(bridge.step(1.0/120.0,input,{"logical_size":Vector2(1280,720)}).ok,label+"：固定更新を進める")
	bridge.collect_frame()
	var enemies: Array = bridge.read_lab().value.enemies.filter(func(row): return row.type==&"shield")
	check(not enemies.is_empty() if expected_clip else enemies.is_empty(),label+"：指定時刻のクリップだけを再生する")
	if expected_clip:
		var frame: Dictionary = bridge.read_render(Rect2(-5000,-5000,10000,10000)).value
		check(frame.batches.any(func(batch): return enemies.any(func(enemy): return enemy.id in batch.ids)),label+"：編成の個体を正式表示へ渡す")
	# 停止中のシナリオ変更も同じ型を使い、不正入力は元の時刻を保つ。
	check(not bridge.command("dev_set_scenario",{"kind":"timeline","params":{"time":1.0}}).ok,label+"：稼働中の途中再生変更を拒否する")
	bridge.command("pause",{"paused":true})
	var before: Dictionary = bridge.read_frame().value.ui
	check(not bridge.command("dev_set_scenario",{"kind":"timeline","params":{"time":NAN}}).ok and bridge.read_frame().value.ui.run_time==before.run_time,label+"：不正時刻を原子的に拒否する")
	check(bridge.command("dev_set_scenario",{"kind":"timeline","params":{"time":time}}).ok,label+"：停止境界で同じシナリオ型を適用する")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/speed-d06-"+label+".png")
	session.free()
	await get_tree().process_frame
