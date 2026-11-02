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

func verify_cpp_perf() -> bool:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = 89
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_perf"
	if load("res://tools/content/build_run_content.gd").build(stage,config,output,"F3と同時録画の累積差分".sha256_text())!=OK: return false
	var path := output.path_join("stage_89.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":350},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null: session.free(); return false
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
	bridge.command("dev_spawn",{"definition_id":"drifter","position":bridge.read_frame().value.ui.ship.ship_pos+Vector2(50,0)})
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
	check(not label.contains("処理ごと（世界側") and not label.contains("結晶 0"),"存在しない旧Systemを0表示しない")
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
	if not bridge.command("dev_spawn",{"definition_id":"drifter","position":at+Vector2(100,0)}).ok: return false
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

func cpp_recording_scenario(recording: bool) -> Dictionary:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	config.gem_max = 2
	config.xp_base = 100000.0
	var stage := RuntimeStage.new()
	stage.index = 88
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_recording"
	if load("res://tools/content/build_run_content.gd").build(stage,config,output,"録画と経験値の対応".sha256_text())!=OK: return {}
	var path := output.path_join("stage_88.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":688},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null: session.free();return {}
	var bridge = session.bridge
	var core = bridge._core
	if not core.has_method("recording_run"):
		check(false,"C++の正しい状態から録画用の集計を読み取れる")
		session.free()
		return {}
	bridge.command("dev_remove_weapon",{"id":"W01"})
	var origin: Vector2 = core.ship_snapshot().ship_pos
	var owner: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":origin+Vector2(500,0)}).value
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
			check(start.format=="cpp_events_v2" and start.identity.payload_sha256.length()==64 and start.identity.xp_reward_config_sha256.length()==64 and start.identity.implementation_version.begins_with("cpp_api"),"定義署名・報酬署名・実装版と開始条件を残す")
			check(start.run_start.start.seed=="688" and start.missing_prefix,"開始seedと途中開始を明示する")
			var existing: Array = rows.filter(func(row):return row.type=="xp_existing")
			check(existing.size()==1 and existing[0].origin=="unobserved","途中開始の結晶の未観測の出所を推定しない")
			var ending: Dictionary = rows.back()
			check(ending.type=="end" and ending.has("xp_cumulative") and ending.has("xp_observed") and ending.has("equipment_progress"),"終了時はラン累計と録画区間を分ける")
			if i==0:
				check(start.event_sequence_at_start==before_sequence,"開始前の通知番号を区間の欠落として数えない")
				check(rows.any(func(row):return row.type=="hurt" and row.pos is Array and row.pos.size()==2),"C++通知の座標を既存と同じ数値配列で記録する")
				check(existing[0].ground.size()==2 and existing[0].carried.size()==1 and existing[0].cap.absorber_id>0,"途中開始の地面・運搬・集約先の基準XPを保存する")
				check(rows.any(func(row):return row.type in ["xp_drop","xp_absorb"] and row.get("source","")=="crow_carry" and row.id==carried and not row.new_supply),"運搬から戻した結晶を新しい供給と混ぜない")
				check(rows.any(func(row):return row.type=="combat_player_damage" and row.cause=="slash" and row.accepted) and rows.any(func(row):return row.type=="combat_player_damage" and not row.accepted),"機体の実HP減少と拒否理由を同じ通知経路から記録する")
				check(ending.xp_observed.collected_actual_xp>0.0 and ending.xp_observed.supplied.high.base_xp>=0.0,"倍率適用後XPと基準XPの区間差を保存する")
			else:
				check(ending.xp_observed.collected_actual_xp==0.0 and ending.xp_observed.supplied.low.count==1,"再開前の取得を録画区間へ混ぜない")
		print("[cpp_recording] output="+paths[0])
	var result := {"inspect":core.inspect(),"xp":bridge.read_recording().value.xp,"ship":core.ship_snapshot()}
	rec.free()
	session.free()
	await get_tree().process_frame
	return result
