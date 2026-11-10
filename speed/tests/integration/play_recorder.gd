## 録画の開始経路・成長の保全と既存の計測を確認する。JSONL は /tmp の専用フォルダだけへ書く。
## Godot --headless --path speed res://tests/integration/play_recorder.tscn
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS

const RECORDER := preload("res://scripts/dev/play_recorder.gd")

class TempRecorder:
	extends "res://scripts/dev/play_recorder.gd"
	var directory := "/tmp/speed-recording-start-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	func _recording_directory() -> String:
		return directory

var passed := 0
var failed := 0
var recording_path := ""
var shots := ""

func check(ok: bool, label: String) -> void:
	if "--cpp-recording-sequence-fix" in OS.get_cmdline_user_args() and not (label.begins_with("開始前の通知番号") or label.begins_with("C++通知の座標")): return
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("[play_recorder] " + label)

func _ready() -> void:
	if "--cpp-detail-reader-audit" in OS.get_cmdline_user_args():
		check(await verify_cpp_detail_reader(),"F3を閉じても録画中は詳細計測を続ける")
		print("[cpp_detail_reader] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-metadata-detail-audit" in OS.get_cmdline_user_args():
		check(await verify_cpp_metadata_detail(),"開始条件と詳細計測の追加照合を完了する")
		print("[cpp_metadata_detail] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-recording-initial" in OS.get_cmdline_user_args():
		check(await verify_cpp_initial_recording(),"通常開始の最初の通知まで録画する")
		print("[cpp_recording_initial] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-recording-restore" in OS.get_cmdline_user_args():
		check(not (await cpp_recording_scenario(true,2,true)).is_empty(),"保持から復帰した後の録画を最後まで保存する")
		print("[cpp_recording_restore] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-recording-measurements" in OS.get_cmdline_user_args():
		check(not (await cpp_recording_scenario(true,0)).is_empty(),"詳細度0でも通常計測を最後まで保存する")
		print("[cpp_recording_measurements] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-combat-limits" in OS.get_cmdline_user_args():
		verify_cpp_combat_limits()
		print("[cpp_combat_limits] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-recording" in OS.get_cmdline_user_args():
		var finished: bool = await verify_cpp_recording()
		check(finished,"C++録画の指定確認を最後まで実施する")
		print("[cpp_recording] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-perf" in OS.get_cmdline_user_args() or "--cpp-perf-bytes-fixes" in OS.get_cmdline_user_args():
		var finished: bool = await verify_cpp_perf()
		check(finished,"C++のF3と同時録画の確認を最後まで実施する")
		print("[cpp_perf] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return

	await verify_recording_shortcuts()
	check(await verify_cpp_recording(),"C++録画の指定確認を最後まで実施する")
	print("[play_recorder] passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)

func verify_recording_shortcuts() -> void:
	var rec := TempRecorder.new()
	add_child(rec)
	var key := InputEventKey.new()
	key.keycode = KEY_F9
	key.pressed = true
	var suspend := Shortcut.new()
	suspend.events = [key.duplicate()]
	rec._input(key)
	check(not rec.armed, "Godot の停止キー F9 単独で記録を切り替えない")
	key.ctrl_pressed = true
	check(not suspend.matches_event(key), "Ctrl+F9 は Godot の埋め込み停止キーと一致しない")
	rec._input(key)
	check(rec.armed, "Ctrl+F9 で記録待機を有効にする")
	key.echo = true
	rec._input(key)
	check(rec.armed, "キーリピートで記録を切り替えない")
	key.echo = false
	key.pressed = false
	rec._input(key)
	check(rec.armed, "キーを離したときに記録を切り替えない")
	key.pressed = true
	rec._input(key)
	check(not rec.armed, "Ctrl+F9 で記録待機を無効にする")
	key.ctrl_pressed = false
	key.keycode = KEY_F10
	var next_frame := Shortcut.new()
	next_frame.events = [key.duplicate()]
	key.ctrl_pressed = true
	check(not next_frame.matches_event(key), "Ctrl+F10 は Godot のコマ送りキーと一致しない")
	rec.queue_free()
	await get_tree().process_frame

func read_rows(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	while file.get_position() < file.get_length():
		rows.append(JSON.parse_string(file.get_line()))
	return rows

func verify_cpp_combat_limits() -> void:
	# 共通封筒を実際の保存先へ渡し、診断の上限で通常イベントを落とさない。
	for scenario in ["rate", "count", "bytes", "line", "off", "level_one", "gap", "effect_loss"]:
		var rec := TempRecorder.new()
		add_child(rec)
		rec.set_process(false)
		rec.combat_events_per_second = 1 if scenario=="rate" else 120
		rec.combat_max_events = 1 if scenario=="count" else 30000
		rec.combat_max_bytes = 1 if scenario=="bytes" else 33554432
		rec.combat_level = 0 if scenario=="off" else 1 if scenario=="level_one" else 2
		rec._reset_combat_recording({"combat_diagnostics":{"effect_tracking_dropped":4}})
		if scenario=="effect_loss": rec._cpp_record_previous = {"combat_diagnostics":{"effect_tracking_dropped":6}}
		DirAccess.make_dir_recursive_absolute(rec.directory)
		var path: String = rec.directory.path_join(scenario+".jsonl")
		rec._file = FileAccess.open(path,FileAccess.WRITE)
		rec._cpp_session_id = 123
		rec._real_start_us = Time.get_ticks_usec()
		var first := {"type":"boss_decision" if scenario=="level_one" else "boss_action","sequence":1,"payload":{"action":"charge"}}
		if scenario=="line": first.payload["detail"] = "あ".repeat(6000)
		var events := [first,{"type":"boss_action","sequence":2,"payload":{"step":"end"}},
			{"type":"hurt","sequence":4 if scenario=="gap" else 3,"payload":{"amount":2}},
			{"type":"combat_player_damage","sequence":5 if scenario=="gap" else 4,"payload":{"hp_before":8,"hp_after":6}}]
		for event in events:
			event.merge({"epoch":1,"tick":1,"t":0.0,"world_t":0.0})
		rec.consume_cpp_frame({"run_id":123,"ui":{"run_time":0.0},"events":events})
		rec._end("stopped")
		var rows := read_rows(path)
		var diagnostics: Array = rows.filter(func(row):return row.type in ["boss_action","boss_decision"])
		check(rows.any(func(row):return row.type=="hurt"),"%s: 診断の制限で通常の被弾を落とさない" % scenario)
		check(rows.any(func(row):return row.type=="combat_player_damage"),"%s: 機体の被弾判定を詳細度0でも保存する" % scenario)
		var expected := 0 if scenario in ["bytes","off"] else 2 if scenario in ["gap","effect_loss"] else 1
		check(diagnostics.size()==expected,"%s: 詳細度と診断の上限を保存時に適用する" % scenario)
		var summary: Dictionary = rows.back().get("combat_summary",{})
		check(summary.get("emitted",-1)==expected,"%s: 実際に保存した診断件数を終端へ記録する" % scenario)
		if scenario in ["rate","count"]: check(summary.get("rate_or_count_dropped",0)==1,"%s: 件数上限の欠測を集計する" % scenario)
		if scenario in ["bytes","line"]: check(summary.get("size_dropped",0)==(2 if scenario=="bytes" else 1),"%s: 容量上限の欠測を集計する" % scenario)
		if scenario=="gap": check(summary.get("sequence_gaps",0)==1 and not summary.get("transport_complete",true),"通知末尾の欠測を終端で明示する")
		if scenario=="effect_loss": check(summary.get("effect_tracking_dropped",0)==2 and not summary.get("transport_complete",true),"攻撃追跡の欠測は録画開始後の差分だけを終端へ記録する")
		rec.free()

func verify_cpp_perf() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 89
	stage.boss_enabled = false
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["splitling"])
	var output := "res://.content/dev/run_perf"
	if load("res://tools/content/build_run_content.gd").build(stage,config,output,"F3と同時録画の累積差分".sha256_text())!=OK: return false
	var path := output.path_join("stage_89.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":350},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null: session.free(); return false
	check(await begin_cpp_play(session),"性能確認の前に初期カードを選びPLAYへ進める")
	if session.bridge.read_frame().value.ui.phase!=RunIds.Phase.Play: session.free(); return false
	var overlay := session.view.get_node_or_null("Hud/PerfOverlay")
	check(overlay!=null,"C++の通常表示へF3の性能表示を接続する")
	if overlay==null: session.free(); return false
	if "--cpp-perf-bytes-fixes" in OS.get_cmdline_user_args(): return await verify_cpp_perf_bytes(session,overlay)
	var action := InputEventAction.new()
	action.action = &"debug_perf"
	action.pressed = true
	overlay._unhandled_input(action)
	check(overlay.mode==PerfOverlay.Mode.COMPACT,"F3で簡易表示を開く")
	overlay._unhandled_input(action)
	check(overlay.mode==PerfOverlay.Mode.DETAIL,"F3で詳細表示へ進む")
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	var key := InputEventKey.new()
	key.keycode = KEY_F9
	key.ctrl_pressed = true
	key.pressed = true
	rec._input(key)
	check(rec._cpp_session_id==session.id and rec._file!=null,"Ctrl+F9で同じC++ランを同時に記録する")
	if rec._file==null: rec.free();session.free();return false
	var recording := rec._file.get_path()
	var bridge = session.bridge
	var before: Dictionary = bridge.read_metrics().value
	bridge.command("dev_spawn",{"definition_id":"splitling","position":bridge.read_frame().value.ui.ship.ship_pos+Vector2(50,0)})
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for frame in 4:
		check(bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)}).ok,"通常窓口から固定更新する")
		presentation._present_cpp(0.0)
		rec._cpp_perf_tick(Time.get_ticks_usec())
		await get_tree().process_frame
	var cumulative: Dictionary = presentation.metrics_snapshot()
	check(cumulative.timings.sim[1]>=before.timings.sim[1]+4 and cumulative.timings.output_build[0]>0,"C++内部の更新と出力構築を別の累積値で測る")
	overlay._acc = PerfOverlay.REFRESH
	overlay._process(0.01)
	var label: String = overlay._label.text
	for name in ["ゲーム更新","C++の出力構築","窓口の受け渡し","表示の更新","描画命令の構築","資源待ち","未分離","bytes/frame","GPU単独時間：未取得"]:
		check(label.contains(name),"F3で%sを区別する" % name)
	check(not label.contains("処理ごと（世界側") and label.contains("結晶 %d" % cumulative.rows.crystals[0]),"C++の実数で結晶を表示する")
	check(overlay._cpp_window.packed_bytes_per_frame>0.0,"Packed配列の論理量をbytes/frameで表示する")
	check(cumulative.timings.resource_wait[0]>0,"開始時の資源待ちを独立して記録する")
	rec._flush_cpp_performance()
	var after: Dictionary = bridge.read_metrics().value
	check(after.timings.sim[0]>=cumulative.timings.sim[0] and after.timings.sim[1]==cumulative.timings.sim[1],"F3と録画の読み取りで共有の累積値をresetしない")
	var first: Dictionary = bridge.read_metrics().value
	var second: Dictionary = bridge.read_metrics().value
	check(first==second,"更新なしの複数読み取りで累積値を変えない")
	overlay._unhandled_input(action)
	check(overlay.mode==PerfOverlay.Mode.HIDDEN,"F3で非表示へ戻す")
	rec._input(key)
	check(rec._file==null and not rec.armed,"Ctrl+F9で記録を終了する")
	var records: Array = []
	var file := FileAccess.open(recording,FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty(): records.append(JSON.parse_string(line))
	file.close()
	check(records.any(func(row): return row.type=="performance" and row.profile.timings.sim.count>=4 and row.profile.packed_bytes_per_frame>0),"同時録画にもC++の処理時間とPacked論理量を残す")
	rec.free()
	session.free()
	await get_tree().process_frame
	await get_tree().process_frame
	return true

func verify_cpp_detail_reader() -> bool:
	var path := "res://.content/run/stage_2.json"
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session := RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":9688},false)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null: session.free();return false
	if not await begin_cpp_play(session): session.free();return false
	var bridge = session.bridge
	var overlay := PerfOverlay.new()
	overlay.bridge = bridge
	add_child(overlay)
	overlay._set_mode(PerfOverlay.Mode.DETAIL)
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	rec._set_armed(true)
	if rec._file==null: rec.free();overlay.free();session.free();return false
	for tick in 4: bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var before: Dictionary = bridge.read_metrics().value
	var interval := maxi(1,int(bridge.recording_origin.conditions.config.world_tick_div))
	overlay._set_mode(PerfOverlay.Mode.HIDDEN)
	for tick in interval: bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var after: Dictionary = bridge.read_metrics().value
	print("[cpp_detail_reader] world_tick_div=%d enemy_updates=%d->%d" % [interval,before.detail_timings.enemies[1],after.detail_timings.enemies[1]])
	var continued: bool = after.detail_timings.enemies[1]>before.detail_timings.enemies[1]
	rec._set_armed(false)
	rec.free()
	overlay.free()
	session.free()
	await get_tree().process_frame
	return continued

func verify_cpp_metadata_detail() -> bool:
	var path := "res://.content/run/stage_2.json"
	if not FileAccess.file_exists(path): return false
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var profile := {"mult":{"max_speed":1.25,"xp":1.5,"fuel_gain":1.25},"add":{"max_hp":7.0},"reduce":{}}
	var session := RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"cpp_profile":profile,"cpp_source":"stage_launcher","seed":9688},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null: session.free();return false
	var bridge = session.bridge
	var initial: Dictionary = bridge.recording_origin.conditions
	check(initial.config.size()>80 and initial.stats.size()==18,"開始時のC++設定全列と旧機体能力18列を保存する")
	check(initial.profile.mult.max_speed==1.25 and initial.profile.mult.xp==1.5 and initial.profile.add.max_hp==7.0 and initial.profile.mult.fuel_gain==1.25,"開始時に適用した永続強化の係数を保存する")
	check(initial.rng_seed=="9688" and not String(initial.rng_state).is_empty() and initial.rng_algorithm=="pcg32","乱数のseed・状態・方式を別々に保存する")
	check(initial.physics_ticks_per_second==Engine.physics_ticks_per_second and initial.simulation_ticks_per_second==120 and initial.meta_levels.size()>0,"物理更新数と機体強化の段を開始条件に残す")
	check(initial.identity.implementation_sha256.length()==64 and initial.identity.input_sha256==index.input_sha256 and initial.identity.payload_sha256==index.payload_sha256,"ロード済みC++実装と入力・戦闘データの署名を保存する")
	if not await begin_cpp_play(session): session.free();return false
	bridge._core.set_run_guards({"invincible":true,"hitstop_enabled":false})
	var position: Vector2 = bridge.read_frame().value.ui.ship.ship_pos
	bridge.command("dev_spawn",{"definition_id":"splitling","position":position+Vector2(100,0)})
	bridge.command("dev_drop_crystal",{"position":position+Vector2(500,0),"kind":1})
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	var before: Dictionary = bridge._core.inspect()
	rec._set_armed(true)
	if rec._file==null: rec.free();session.free();return false
	var recording := rec._file.get_path()
	var start := read_rows(recording)[0]
	check(start.run_start.source=="stage_launcher" and start.recording_start.trigger=="during_run","起動元と録画開始のきっかけを別々に保存する")
	check(start.run_start.conditions.hitstop_enabled==initial.hitstop_enabled and not start.recording_start.conditions.hitstop_enabled and start.recording_start.conditions.invincible,"ラン開始条件と途中録画時の現在条件を分ける")
	check(bridge._core.inspect()==before and start.recording_start.conditions.run_state.xp_gained>=initial.run_state.xp_gained,"開始情報を読む処理はゲーム状態と乱数を変えない")
	var overlay: PerfOverlay = session.view.get_node("Hud/PerfOverlay")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	overlay._set_mode(PerfOverlay.Mode.DETAIL)
	for tick in 4:
		bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
		presentation._present_cpp(0.0)
	overlay._acc = PerfOverlay.REFRESH
	overlay._process(0.01)
	var label: String = overlay._label.text
	for name in ["物理更新","結晶","部品","描画命令","シェーダーのコンパイル","RAM","VRAM","つながっていないノード","表の行"]:
		check(label.contains(name),"F3詳細へ%sの実数を戻す" % name)
	check(overlay._view_label.visible and overlay._view_label.text.contains("C++処理") and overlay._view_label.text.contains("表示側") and overlay._view_label.text.contains("通常バッチ"),"F3右列へ処理・表示・描画個体数の内訳を戻す")
	var first: Dictionary = bridge.read_metrics(StringName("recorder:%d" % rec.get_instance_id())).value
	var second: Dictionary = bridge.read_metrics(StringName("recorder:%d" % rec.get_instance_id())).value
	check(first.timings.sim[3]>0 and second.timings.sim[3]==0 and first.timings.sim.slice(0,3)==second.timings.sim.slice(0,3),"読取先の区間最大だけを更新し累積計測値を保つ")
	var view_first: Array = presentation.metrics_snapshot(StringName("recorder:%d" % rec.get_instance_id())).detail_timings["view.view_submit"]
	var view_second: Array = presentation.metrics_snapshot(StringName("recorder:%d" % rec.get_instance_id())).detail_timings["view.view_submit"]
	check(view_first[3]>0 and view_second[3]==0 and view_first.slice(0,3)==view_second.slice(0,3),"表示側も区間最大だけを更新し累積計測値を保つ")
	check(first.render_rows.live[0]>0 and first.rows.crystals[0]>0 and not first.detail_timings.is_empty(),"C++の個体数と内訳を実際の状態から取得する")
	var detail_count: int = first.detail_timings.enemies[1]
	overlay._set_mode(PerfOverlay.Mode.HIDDEN)
	for tick in maxi(1,int(initial.config.world_tick_div)):
		bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	check(bridge.read_metrics().value.detail_timings.enemies[1]>detail_count,"F3を閉じても録画中は詳細計測を続ける")
	rec._set_armed(false)
	detail_count = bridge.read_metrics().value.detail_timings.enemies[1]
	for tick in maxi(1,int(initial.config.world_tick_div)):
		bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	check(bridge.read_metrics().value.detail_timings.enemies[1]==detail_count,"最後の読取先を閉じたら詳細計測を止める")
	rec.free()
	session.free()
	await get_tree().process_frame
	return true

func begin_cpp_play(session: RunSession) -> bool:
	if session.bridge.read_frame().value.ui.phase==RunIds.Phase.Play: return true
	if not session.bridge.command("choose_card",{"index":0}).ok: return false
	for attempt in 60:
		session.cpp_choices.poll()
		if session.bridge.read_frame().value.ui.phase==RunIds.Phase.Play: return true
		await get_tree().process_frame
	return false

func verify_cpp_perf_bytes(session: RunSession, overlay: PerfOverlay) -> bool:
	overlay._set_mode(PerfOverlay.Mode.DETAIL)
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	rec._set_armed(true)
	if rec._file==null: rec.free();session.free();return false
	var recording := rec._file.get_path()
	var bridge = session.bridge
	var at: Vector2 = bridge.read_frame().value.ui.ship.ship_pos
	if not bridge.command("dev_spawn",{"definition_id":"splitling","position":at+Vector2(100,0)}).ok: return false
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	for frame in 4:
		bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
		presentation._present_cpp(0.0)
		rec._cpp_perf_tick(Time.get_ticks_usec())
		await get_tree().process_frame
	overlay._acc = PerfOverlay.REFRESH
	overlay._process(0.01)
	check(overlay._cpp_window.packed_bytes_per_frame>0.0,"実際に敵を表示するPacked配列の論理量をbytes/frameで表示する")
	rec._flush_cpp_performance()
	rec._set_armed(false)
	var records: Array = []
	var file := FileAccess.open(recording,FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty(): records.append(JSON.parse_string(line))
	file.close()
	check(records.any(func(row): return row.type=="performance" and row.profile.timings.sim.count>=4 and row.profile.packed_bytes_per_frame>0),"同時録画にもC++の処理時間とPacked論理量を残す")
	rec.free()
	session.free()
	await get_tree().process_frame
	await get_tree().process_frame
	return true

func verify_cpp_recording() -> bool:
	var on: Dictionary = await cpp_recording_scenario(true)
	var off: Dictionary = await cpp_recording_scenario(false)
	check(not on.is_empty() and on==off,"録画の開始/停止/再開と読取でランの状態・乱数・XPを変えない")
	return not on.is_empty() and not off.is_empty()

func verify_cpp_initial_recording() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 90
	stage.boss_enabled = false
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["splitling"])
	var output := "res://.content/dev/run_recording_initial"
	if load("res://tools/content/build_run_content.gd").build(stage,config,output,"開始前待機の通知".sha256_text())!=OK: return false
	var path := output.path_join("stage_90.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	rec._set_armed(true)
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":690,"cpp_start":{"equipment":[]}},false)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null or rec._file==null: rec.free();session.free();return false
	var recording: String = rec._file.get_path()
	rec._set_armed(false)
	var rows := read_rows(recording)
	check(rows.front().event_sequence_at_start==0 and not rows.front().missing_prefix,"開始前待機では初期化通知を観測対象に含める")
	check(rows.any(func(row):return row.type=="offer" and row.get("initial",false)),"初期武器の候補通知を開始済みとして捨てない")
	check(rows.back().combat_summary.transport_complete,"通常開始の通知列に欠測を作らない")
	rec.free()
	session.free()
	await get_tree().process_frame
	return true

func cpp_recording_scenario(recording: bool, combat_detail := 2, restore_recording := false) -> Dictionary:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.gem_max = 2
	config.xp_base = 100000.0
	var stage := RuntimeStage.new()
	stage.index = 88
	stage.boss_enabled = false
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["splitling"])
	var output := "res://.content/dev/run_recording"
	if load("res://tools/content/build_run_content.gd").build(stage,config,output,"録画と経験値の対応".sha256_text())!=OK: return {}
	var path := output.path_join("stage_88.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":688},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null: session.free();return {}
	if not await begin_cpp_play(session): session.free();return {}
	var bridge = session.bridge
	var core = bridge._core
	if not core.has_method("recording_run"):
		check(false,"C++の正しい状態から録画用の集計を読み取れる")
		session.free()
		return {}
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var origin: Vector2 = core.ship_snapshot().ship_pos
	var owner: int = bridge.command("dev_spawn",{"definition_id":"splitling","position":origin+Vector2(500,0)}).value
	core.set_enemy_motion(owner,{"held":true})
	var carried: int = bridge.command("dev_drop_crystal",{"position":origin+Vector2(500,0),"kind":1}).value
	var carry_ok: bool = bridge.command("dev_carry_crystal",{"entity_id":owner,"crystal_id":carried}).ok
	if "--cpp-recording-fix" not in OS.get_cmdline_user_args(): check(carry_ok,"途中開始前の運搬結晶を準備する")
	for kind in 3: bridge.command("dev_drop_crystal",{"position":origin+Vector2(700,0),"kind":kind})
	bridge.collect_frame()
	var before: Dictionary = core.inspect()
	var before_sequence: int = bridge.read_metrics().value.events_emitted
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	rec.combat_level = combat_detail
	var paths: Array[String] = []
	if recording:
		var key := InputEventKey.new()
		key.keycode = KEY_F9
		key.pressed = true
		key.ctrl_pressed = true
		rec._input(key)
		check(rec._file!=null and rec._cpp_session_id==session.id,"Ctrl+F9で途中のC++ランを記録する")
		if rec._file==null: rec.free();session.free();return {}
		paths.append(rec._file.get_path())
		check(core.inspect()==before,"開始時のXP集計と識別情報の読取は時計・乱数を変えない")
	bridge.command("dev_damage",{"entity_id":owner,"cause":"shot","amount":0.01,"weapon_id":1})
	bridge.command("dev_kill",{"entity_id":owner,"cause":"shot"})
	bridge.command("dev_pickup_rates",{"ship":1.5,"run":2.0})
	bridge.command("dev_collect_gems",{})
	bridge.command("dev_ship_damage",{"amount":2.0,"cause":"slash"})
	bridge.command("dev_ship_damage",{"amount":1.0,"cause":"slash"})
	bridge.collect_frame()
	var idle: Dictionary = bridge.pack_intent(Intent.new())
	for tick in 4: bridge.step(1.0/120.0,idle,{"logical_size":Vector2(1280,720)})
	if recording:
		rec._cpp_sample()
		rec._set_armed(false)
		rec._set_armed(true)
		check(rec._file!=null,"録画を停止して同じランで再開する")
		if rec._file!=null: paths.append(rec._file.get_path())
	if restore_recording:
		var held: Dictionary = bridge.checkpoint()
		check(held.ok,"録画中のランを保持する")
		if not held.ok: rec.free();session.free();return {}
		check(bridge.restore(held.value).ok,"保持したランへ復帰する")
		check(rec._file!=null and rec._file.get_path()!=paths.back(),"復帰前の記録を閉じて別ファイルへ途中録画を始める")
		if rec._file!=null: paths.append(rec._file.get_path())
		bridge.release_checkpoint(held.value)
	bridge.command("dev_drop_crystal",{"position":origin+Vector2(700,0),"kind":0})
	bridge.collect_frame()
	for tick in 4: bridge.step(1.0/120.0,idle,{"logical_size":Vector2(1280,720)})
	if recording:
		rec._set_armed(false)
		for i in paths.size():
			var rows := read_rows(paths[i])
			check(not rows.is_empty(),"短いC++録画をJSONLとして読み取れる")
			if rows.is_empty(): continue
			var start: Dictionary = rows.front()
			check(start.type=="start" and start.schema_version==4 and start.measurement_version==3 and start.combat_version==1 and start.xp_reward_version==2,"既存識別子とC++形式版を残す")
			check(start.combat_config.level==combat_detail and start.combat_config.events_per_second==120 and start.combat_config.max_events==30000 and start.combat_config.max_bytes==33554432 and start.combat_config.line_bytes==16384,"開始行に適用した診断の詳細度と上限を保存する")
			check(start.format=="cpp_events_v2" and start.identity.payload_sha256.length()==64 and start.identity.xp_reward_config_sha256.length()==64 and start.identity.implementation_version.begins_with("cpp_api"),"定義署名・報酬署名・実装版と開始条件を残す")
			check(start.run_start.start.seed=="688" and start.missing_prefix,"開始seedと途中開始を明示する")
			var existing: Array = rows.filter(func(row):return row.type=="xp_existing")
			check(existing.size()==1 and existing[0].origin=="unobserved","途中開始の結晶の未観測の出所を推定しない")
			var ending: Dictionary = rows.back()
			check(ending.type=="end" and ending.has("xp_cumulative") and ending.has("xp_observed") and ending.has("equipment_progress"),"終了時はラン累計と録画区間を分ける")
			check(ending.get("combat_summary",{}).get("transport_complete",false) and ending.combat_summary.rate_or_count_dropped==0 and ending.combat_summary.size_dropped==0,"終了までの診断の送出数と欠測の有無を残す")
			if i==0:
				var samples: Array = rows.filter(func(row):return row.type=="sample")
				check(not samples.is_empty() and samples[0].has("effective_damage") and samples[0].has("enemy_life") and samples[0].has("enemy_contacts") and samples[0].has("attack_budget_max"),"通常の命中・生存・接触計測を診断ログとは別の区間集計へ残す")
				if not samples.is_empty() and samples[0].has("effective_damage"):
					check(samples[0].effective_damage.any(func(hit):return hit.enemy=="splitling" and hit.weapon_id=="W01" and hit.applied>0.0),"武器IDと敵種付きの実ダメージを保存する")
					check(samples[0].enemy_life.any(func(life):return life.enemy=="splitling" and life.killed==1 and life.unknown_spawn==1 and life.life_world_count==0),"途中録画の既存敵を出現から撃破の時間へ混ぜない")
				check(start.event_sequence_at_start==before_sequence,"開始前の通知番号を区間の欠落として数えない")
				check(rows.any(func(row):return row.type=="hurt" and row.pos is Array and row.pos.size()==2),"C++通知の座標を既存と同じ数値配列で記録する")
				check(existing[0].ground.size()==2 and existing[0].carried.size()==1 and existing[0].cap.absorber_id>0,"途中開始の地面・運搬・集約先の基準XPを保存する")
				check(rows.any(func(row):return row.type in ["xp_drop","xp_absorb"] and row.get("source","")=="crow_carry" and row.id==carried and not row.new_supply),"運搬から戻した結晶を新しい供給と混ぜない")
				check(rows.any(func(row):return row.type=="combat_player_damage" and row.cause=="slash" and row.accepted) and rows.any(func(row):return row.type=="combat_player_damage" and not row.accepted),"機体の実HP減少と拒否理由を同じ通知経路から記録する")
				check(ending.xp_observed.collected_actual_xp>0.0 and ending.xp_observed.supplied.high.base_xp>=0.0,"倍率適用後XPと基準XPの区間差を保存する")
			elif i==paths.size()-1:
				check(ending.xp_observed.collected_actual_xp==0.0 and ending.xp_observed.supplied.low.count==1,"再開前の取得を録画区間へ混ぜない")
			if restore_recording and i==1:
				check(ending.result=="restore","復帰前の録画の終了理由を区別する")
			if restore_recording and i==2:
				check(start.epoch>read_rows(paths[1]).front().epoch and start.missing_prefix,"復帰後の通知世代と途中開始を保存する")
		print("[cpp_recording] output="+paths[0])
	var result := {"inspect":core.inspect(),"xp":bridge.read_recording().value.xp,"ship":core.ship_snapshot()}
	rec.free()
	session.free()
	await get_tree().process_frame
	return result
