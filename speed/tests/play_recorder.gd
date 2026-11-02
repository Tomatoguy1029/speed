## 録画の開始経路・成長の保全と既存の計測を確認する。JSONL は /tmp の専用フォルダだけへ書く。
## Godot --headless --path speed res://tests/play_recorder.tscn
extends Node

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
	if "--legacy-mid-fixes" in OS.get_cmdline_user_args() and not (label.begins_with("途中開始の残存結晶") or label.begins_with("重複開始で")): return
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("[play_recorder] " + label)

func _ready() -> void:
	if "--legacy-mid-fixes" in OS.get_cmdline_user_args():
		await verify_mid_run_start()
		print("[legacy_mid_fixes] passed=%d failed=%d" % [passed,failed])
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			shots = arg.trim_prefix("--out=")
	var on: Dictionary = await scenario(true)
	var off: Dictionary = await scenario(false)
	check(on == off, "記録 ON/OFF で XP・レベル・乱数状態・残存結晶が同じ")
	var records: Array[Dictionary] = []
	var file := FileAccess.open(recording_path, FileAccess.READ)
	while file.get_position() < file.get_length():
		var row: Variant = JSON.parse_string(file.get_line())
		check(row is Dictionary, "出力は JSONL")
		if row is Dictionary: records.append(row)
	file.close()
	verify(records)
	await verify_performance()
	await verify_ui_pause_performance()
	await verify_mid_run_start()
	await verify_start_routes()
	var measured_on := await measurement_scenario(true)
	var measured_off := await measurement_scenario(false)
	check(measured_on == measured_off, "追加イベントの ON/OFF で装備・HP・XP・乱数・結晶が同じ")
	await verify_live_tuning(false)
	await verify_live_tuning(true)
	print("[play_recorder] passed=%d failed=%d output=%s" % [passed, failed, recording_path])
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

func verify_mid_run_start() -> void:
	var scene := RunManager.create_run() as Node
	add_child(scene)
	if scene.sim.state == null: await scene.started
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var run: RunSimulation = scene.sim as RunSimulation
	await get_tree().process_frame
	run.state.time = 42.0
	run.state.level = 3
	run.state.xp = 0.125
	run.state.xp_gained = 1000.0
	run.state.xp_dropped = 1200.0
	run.state.weapons[&"W01"] = 2
	run.state.kills = 10
	var existing_row := run.pickups.drop_crystal(Vector2.ZERO, PickupSystem.GemKind.MID)
	var existing_id := run.pickups.gem_seq[existing_row]
	run.state.emit(&"hurt", {"amount": 99.0, "cause": &"before_recording"})
	var initial_profile: Dictionary = scene.recording_initial.profile.duplicate(true)
	run.ctx.profile.mult[&"xp"] = 9.0
	var before := [run.state.time, run.state.level, run.state.xp, run.state.rng.state]
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	var key := InputEventKey.new()
	key.keycode = KEY_F9
	key.pressed = true
	key.ctrl_pressed = true
	rec._input(key)
	check(rec._file != null, "プレイ中の Ctrl+F9 で既存ランの記録を開始する")
	check(before == [run.state.time, run.state.level, run.state.xp, run.state.rng.state], "録画開始は時計・成長・乱数を変えない")
	if rec._file != null:
		var path := rec._file.get_path()
		var start: Dictionary = read_rows(path)[0]
		check(start.run_start.source == "stage_start" and start.run_start.t == 0.0, "通常ランの出自を途中録画でも保つ")
		check(start.run_start.level == 0 and start.run_start.weapons.is_empty(), "初期武器の選択前の状態を保持する")
		check(start.recording_start.t == 42.0 and start.recording_start.level == 3 and start.recording_start.xp == 0.125, "録画開始時の時計・レベル・XP を保存する")
		check(start.recording_start.weapons.W01 == 2 and start.recording_start.xp_gained == 1000.0, "録画開始時の装備と累計を保存する")
		check(start.missing_prefix and start.recording_start.trigger == "during_run", "同じ通常ランでも前半欠落を明示する")
		var existing: Dictionary = read_rows(path).filter(func(row):return row.type=="xp_existing")[0]
		check(existing.type == "xp_existing" and existing.origin == "unobserved" and int(existing.ground[0].id) == existing_id and existing.ground[0].kind == "mid" and existing.ground[0].base_xp == run.cfg.xp_crystal_values[PickupSystem.GemKind.MID], "途中開始の残存結晶IDと値を生成不明として記録する")
		check(start.run_start.conditions.profile == RECORDER.IDENTITY.plain(initial_profile) and start.recording_start.conditions.profile.mult.xp == 9.0, "開始時の強化と途中録画時の強化を区別する")
		check(rec._offered.size() == run.state.cards.size(), "既に表示中のカード候補を引き継ぐ")
		var previous_rows := read_rows(path).size()
		rec._set_armed(true)
		rec._begin(scene)
		check(rec._file.get_path() == path and read_rows(path).size() == previous_rows, "重複開始でファイルを作り直さない")
		run.flush_events()
		check(read_rows(path).filter(func(row): return row.type == "hurt").is_empty(), "Ctrl+F9前から通知待ちの被弾を観測区間へ混ぜない")
		rec._process(0.0)
		await capture("mid-run")
		run.state.time += 3.0
		run.state.xp_gained += 2.0
		run.state.xp_dropped += 4.0
		rec._process(0.0)
		var sample: Dictionary = read_rows(path).filter(func(row): return row.type == "sample")[0]
		check(sample.xp_picked == 2.0 and sample.xp_dropped == 4.0, "最初の sample は録画開始後の XP だけを集計する")
		rec._input(key)
		var closed := FileAccess.get_file_as_bytes(path)
		check(read_rows(path).back().result == "stopped", "Ctrl+F9 停止を記録する")
		rec._set_armed(false)
		rec._end("stopped")
		check(FileAccess.get_file_as_bytes(path) == closed, "重複停止で記録を書き足さない")
		rec._input(key)
		check(rec._file != null and rec._file.get_path() != path, "すぐ再開しても別のファイルへ記録する")
		check(FileAccess.get_file_as_bytes(path) == closed, "再開で既存ファイルを上書きしない")
		run.set_phase(RunState.Phase.ENDED)
		check(rec._file == null and rec.armed, "ラン終了後も次のランの待機は続く")
		rec._set_armed(false)
		rec._set_armed(true)
		check(rec._file == null, "終了済みランでは新しく記録しない")
	rec._set_armed(false)
	rec.queue_free()
	scene.queue_free()
	await get_tree().process_frame

func verify_start_routes() -> void:
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	for route in [{"source": "stage_start", "t": 0.0}, {"source": "timeline", "t": 240.0},
		{"source": "timeline", "t": 0.0}, {"source": "stage_launcher", "t": 0.0}, {"source": "unknown", "t": 0.0}]:
		for delayed in [false, true]:
			GameManager.run_start_source = route.source
			GameManager.run_start_time = route.t
			if not delayed:
				rec._set_armed(true)
			var scene := RunManager.create_run() as Node
			var run: RunSimulation = scene.sim as RunSimulation
			run.options = {"seed": 932}
			add_child(scene)
			if scene.sim.state == null: await scene.started
			scene.process_mode = Node.PROCESS_MODE_DISABLED
			await get_tree().process_frame
			check(GameManager.run_start_time == 0.0 and GameManager.run_start_source == "stage_start", "開始条件を次のランへ持ち越さない")
			if delayed:
				# 初期武器を選び、実際のラン更新を短く進めてから Ctrl+F9。
				run.choose_card(0)
				run.combat.rebuild_grid()
				for tick in 12:
					run.physics_step(1.0 / 120.0)
				var snapshot := run.recording_snapshot()
				var rng := run.state.rng.state
				var key := InputEventKey.new()
				key.keycode = KEY_F9
				key.ctrl_pressed = true
				key.pressed = true
				rec._input(key)
				check(run.recording_snapshot() == snapshot and run.state.rng.state == rng, "途中開始も実更新後の状態を保全する")
			check(rec._file != null, "各開始経路で記録を開始する")
			if rec._file != null:
				var path := rec._file.get_path()
				var start: Dictionary = read_rows(path)[0]
				check(start.schema_version == 4 and start.run_start.source == route.source and start.run_start.t == route.t, "開始経路とラン開始時刻を正確に保存する")
				check(start.run_start.level == 0 and start.run_start.xp == 0.0, "途中時刻のランでも初期レベル・XP を推測しない")
				check(start.missing_prefix == delayed, "ランの開始経路と前半欠落は別々に保存する")
				check(is_equal_approx(start.recording_start.t, run.state.time if delayed else route.t), "録画開始時刻をランの開始時刻と区別する")
				if route.source == "timeline" and delayed and route.t > 0.0:
					check(run.state.time > route.t and run.state.xp_gained == 0.0, "タイムライン途中開始は成長のない時計から進む")
					rec._process(0.0)
					await capture("timeline-mid-run")
				scene.queue_free()
				await get_tree().process_frame
				check(rec._file == null and read_rows(path).back().result == "quit", "シーンを離れると記録を閉じる")
			else:
				scene.queue_free()
				await get_tree().process_frame
			rec._set_armed(false)
	# ready の前に待機を解除した通知は、後から記録を始めない。
	rec._begin(null)
	check(rec._file == null, "解除後に届いた開始通知を無視する")
	print("START_ROUTE_CHECK directory=", rec.directory)
	rec.queue_free()
	await get_tree().process_frame

func read_rows(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	while file.get_position() < file.get_length():
		rows.append(JSON.parse_string(file.get_line()))
	return rows

func capture(label: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(shots)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(label + ".png"))

func scenario(recording: bool) -> Dictionary:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 932, "empty": true, "stage": 1, "config": {"strong_gold_chance": 1.0}})
	var run: RunSimulation = lab.run
	var pk := run.pickups
	var s := run.state
	s.ship_pos = Vector2(3000, 0)
	s.time = 5.0
	var rec = TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	rec._set_armed(true)
	rec._begin(lab.scene)
	check(rec._file == null, "実験場は通常の記録先へ書かない")
	rec._set_armed(false)
	if recording:
		var directory := "/tmp/speed-xp-recorder-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		DirAccess.make_dir_recursive_absolute(directory)
		recording_path = directory.path_join("fixed_crystals.jsonl")
		# 本番のファイル作成だけを分離し、通知・sample・end の処理はそのまま使う。
		rec._file = FileAccess.open(recording_path, FileAccess.WRITE)
		rec._run = run
		rec._session = lab.scene
		rec._xp_start_summary = pk.xp_summary().duplicate(true)
		rec._last_xp_summary = rec._xp_start_summary.duplicate(true)
		pk.xp_recorded.connect(rec._write)
		check(rec._xp_config().xp_crystal_values.mid == run.cfg.xp_crystal_values[PickupSystem.GemKind.MID], "開始時の固定色の基準XPを取得できる")
		run.phase_changed.connect(rec._on_phase_changed)
		lab.scene.tree_exiting.connect(rec._end.bind("quit"))
	# 実際の敵ドロップ経路。雑魚は水色1個、レチクルは紫2個と確率1にした黄色1個。
	pk.on_enemy_killed(run.enemies.spawn(ContentManager.enemies[&"biter"], s.ship_pos))
	s.time = 6.0
	pk.on_enemy_killed(run.enemies.spawn(ContentManager.enemies[&"reticle"], s.ship_pos))
	pk._collect_gems(0.01)
	check(s.xp_gained > 0.0 and pk.gem_slots.live == 0, "固定色の結晶を共通入口で回収する")
	var outcome := {"xp": s.xp_gained, "level": s.level, "rng": s.rng.state, "gems": pk.gem_slots.live}
	if recording:
		s.time = 8.0
		rec._on_phase_changed(RunState.Phase.ENDED)
		check(rec._file == null and rec._run == null, "ラン終了でファイルを閉じる")
	check(not pk.xp_recorded.has_connections(), "記録 OFF/終了後は購読が残らない")
	rec.queue_free()
	lab.queue_free()
	await get_tree().process_frame
	return outcome

func verify(records: Array[Dictionary]) -> void:
	var drops: Array[Dictionary] = []
	for event in records:
		if event.type == "xp_drop": drops.append(event)
	check(drops.size() == 4, "雑魚1個とレチクルの紫2個・黄色1個を記録する")
	if drops.size() == 4:
		check(drops[0].t == 5.0 and drops[0].origin.enemy == "biter" and drops[0].kind == "low", "通常報酬の時刻・敵・固定色を記録する")
		check(drops[1].origin.enemy == "reticle" and drops[1].kind == "mid" and drops[2].kind == "mid" and drops[3].kind == "high", "レチクルの確定報酬と追加黄色を区別する")
	var rolls := records.filter(func(event): return event.type == "xp_gold_roll")
	check(rolls.size() == 1 and rolls[0].won, "紫2個でも黄色は敵1体に1回だけ抽選する")
	var end: Dictionary = records.back()
	check(end.type == "end" and end.result == "quit" and end.xp_reward_version == 2, "終了行に報酬仕様の版を保持する")
	check(end.xp_observed.supplied.low.count == 1 and end.xp_observed.supplied.mid.count == 2 and end.xp_observed.supplied.high.count == 1, "終了時に新規供給の色別個数を集計する")
	check(end.xp_cumulative.ground.low.count == 0 and end.xp_cumulative.ground.mid.count == 0 and end.xp_cumulative.ground.high.count == 0, "回収後に地面の残存を重ねて計上しない")

## 報酬とメニューは PLAY のまま停止する。描画だけの時間を性能窓に混ぜない。
func verify_ui_pause_performance() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 932, "empty": true, "stage": 1})
	lab.scene.auto_step = false
	var run: RunSimulation = lab.run
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	DirAccess.make_dir_recursive_absolute(rec.directory)
	var path := rec.directory.path_join("ui-pause.jsonl")
	rec._file = FileAccess.open(path, FileAccess.WRITE)
	rec._run = run
	rec._session = lab.scene
	run.state.phase = RunState.Phase.PLAY
	var stamp := Time.get_ticks_usec()
	run.ui_reward_active = true
	rec._perf_start(stamp)
	stamp += 100000000
	rec._perf_tick(stamp)
	run.ui_reward_active = false
	stamp += 16667
	rec._perf_tick(stamp)
	for pause_kind in ["ui_reward_active", "ui_overlay_active"]:
		for k in 60:
			stamp += 16667
			rec._perf_tick(stamp)
		run.set(pause_kind, true)
		stamp += 16667
		rec._perf_tick(stamp)
		stamp += 100000000
		rec._perf_tick(stamp)
		run.set(pause_kind, false)
		stamp += 16667
		rec._perf_tick(stamp)
	for k in 60:
		stamp += 16667
		rec._perf_tick(stamp)
	rec._flush_performance(stamp)
	rec._file.close()
	rec._file = null
	rec._run = null
	var records := read_rows(path)
	check(records.size() == 3, "報酬とメニューの停止を境に性能窓を分ける")
	var measured_frames := 0
	var measured_seconds := 0.0
	for record in records:
		measured_frames += int(record.frames)
		measured_seconds += float(record.duration_real)
	check(measured_frames == 180 and measured_seconds < 3.1, "PLAYのまま止まった300秒をプレイ性能へ混ぜない")
	rec.queue_free()
	lab.queue_free()
	await get_tree().process_frame

func verify_performance() -> void:
	var lab = load('res://gyms/enemy_lab/lab_session.gd').new()
	add_child(lab)
	await lab.reset({'seed':932,'empty':true,'stage':4})
	var run: RunSimulation = lab.run
	lab.scene.auto_step = false
	run.state.phase = RunState.Phase.PLAY
	run.state.time = 300.0
	var rec = RECORDER.new()
	add_child(rec)
	rec.set_process(false)
	var directory := '/tmp/speed-performance-recorder-%d' % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join('performance.jsonl')
	rec._file = FileAccess.open(path,FileAccess.WRITE)
	rec._run = run
	rec._session = lab.scene
	var stamp := Time.get_ticks_usec()
	rec._perf_start(stamp)
	var rng_before := run.state.rng.state
	var xp_before := run.state.xp
	for k in 180:
		stamp += 16667
		rec._perf_tick(stamp)
	check(run.state.rng.state==rng_before and run.state.xp==xp_before,"recording preserves RNG and XP")
	run.state.hitstop = 0.05
	stamp += 100000
	rec._perf_tick(stamp)
	rec._flush_performance(stamp)
	run.state.hitstop = 0.0
	run.state.phase = RunState.Phase.PAUSED
	stamp += 16667
	rec._perf_tick(stamp)
	stamp += 100000000
	rec._perf_tick(stamp)
	run.state.phase = RunState.Phase.PLAY
	stamp += 16667
	rec._perf_tick(stamp)
	for k in 60:
		stamp += 16667
		rec._perf_tick(stamp)
	run.state.bonus_t = 30.0
	rec._on_events([{'type':&'bonus','enter':true}])
	stamp += 100000
	rec._perf_tick(stamp)
	for k in 180:
		stamp += 16667
		rec._perf_tick(stamp)
	rec._flush_performance(stamp)
	rec._file.close()
	rec._file = null
	rec._run = null
	var file := FileAccess.open(path,FileAccess.READ)
	var rows := []
	while file.get_position() < file.get_length(): rows.append(JSON.parse_string(file.get_line()))
	file.close()
	var perf := rows.filter(func(v):return v.type=='performance')
	check(perf.size()==4,'4 windows only; no per-frame log')
	check(perf[0].frames==180,'normal frames')
	check(absf(perf[0].fps-60.0)<0.01,'60 FPS from real microseconds')
	check(perf[1].frame_ms_max==100.0,'100ms stall retained')
	check(perf[1].hitstop_frame_ratio==1.0 and perf[0].hitstop_frame_ratio==0.0,'hitstop observation ratio')
	check(perf[1].frames_over_33ms==1 and perf[1].frames_over_50ms==1,'slow frame thresholds')
	check(perf[2].frames==61 and perf[2].duration_real<2.0,'pause and resume gap excluded')
	check(perf[2].frame_ms_max==100.0,'bonus transition stall retained')
	check(not perf[0].bonus and perf[3].bonus,'bonus split from normal')
	check(perf[3].t==300.0 and perf[3].duration_real>3.0,'bonus records despite frozen run clock')
	check(perf[0].objects_at_write.enemy_capacity>=perf[0].objects_at_write.enemies,'allocated capacity and live count')
	check(perf[0].has('real_t') and perf[0].has('window_end_real'),'wall timestamp and measurement window distinct')
	check(rows.filter(func(v):return v.type=='bonus').size()==1,'bonus transition emitted')
	check(FileAccess.get_file_as_bytes(path).size()<10000,'bounded aggregate log')
	print('PERF_RECORDER_CHECK passed=',passed,' rows=',rows.size(),' bytes=',FileAccess.get_file_as_bytes(path).size())
	rec.queue_free()
	lab.queue_free()
	await get_tree().process_frame

## 実際の入口を使い、履歴の対応と観測による状態変化を検証する。
func measurement_scenario(recording: bool) -> Dictionary:
	var config := ContentManager.cfg.duplicate() as GameConfig
	config.levelup_bonus_chance = 1.0
	config.levelup_bonus_more = 1.0
	config.levelup_bonus_last = 1.0
	config.gem_max = 1
	config.strong_gold_chance = 0.0
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	if recording: rec._set_armed(true)
	var scene := RunManager.create_session(self, {"seed": 704, "config": config, "profile": ProfileManager.compute({})}, false)
	scene.auto_step = false
	var run: RunSimulation = scene.sim
	var s := run.state
	var pk := run.pickups
	await get_tree().process_frame
	var path := rec._file.get_path() if recording else ""
	run.choose_card(0)
	s.time = 12.25
	s.world_time = 7.5
	s.cards = [{"kind": &"trait", "id": &"T10", "level": 1}]
	s.pending_levels = 1
	run.loadout.choose_card(0)
	# 彗星の空き枠取得と、満員時の入れ替え。
	run.loadout._receive_comet_weapon(&"W21")
	for id in ContentManager.catalog.table(&"weapons"):
		if not ContentManager.catalog.find(&"weapons", id).comet_only and s.weapons.size() < config.weapon_slots:
			run.loadout.grant(&"weapon", id)
	run.loadout._receive_comet_weapon(&"W22")
	await get_tree().process_frame
	var replaced: StringName = s.cards[0].id
	run.loadout.choose_card(0)
	# 各被弾を、無敵で拒否した攻撃と区別する。書込時には時計を進めておく。
	s.phase = RunState.Phase.PLAY
	s.ship_hp = 100.0
	s.ship_shield_t = 0.0
	s.ship_invuln = 0.0
	run.ship.damage(7.0, 0.0, &"bullet", &"reticle")
	run.ship.damage(99.0, 0.0, &"bullet", &"reticle")
	s.time = 12.5
	s.world_time = 7.75
	s.ship_invuln = 0.0
	run.ship.damage(3.0, 0.0, &"touch", &"biter")
	s.time = 13.0
	run.flush_events()
	# 結晶の生成・通常回収・上限合流・ビーコン回収。
	s.ship_pos = Vector2(1000, 0)
	var row := pk.drop_crystal(s.ship_pos, PickupSystem.GemKind.LOW, &"enemy", &"biter", 101)
	var ship_id := pk.gem_seq[row]
	pk._collect_gems(0.01)
	row = pk.drop_crystal(Vector2.ZERO, PickupSystem.GemKind.MID, &"enemy", &"reticle", 102)
	var first := pk.gem_seq[row]
	pk.drop_crystal(Vector2.ZERO, PickupSystem.GemKind.LOW, &"enemy", &"biter", 103)
	pk.drop_crystal(Vector2.ZERO, PickupSystem.GemKind.MID, &"enemy", &"biter", 104)
	s.time = 14.0
	pk.collect(&"magnet")
	# からす座の実際の回収経路と、運搬XPの再ドロップ。
	var crow_def := run.enemies.def_of(&"crow").duplicate(true) as EnemyDef
	crow_def.params.flock = 1
	var crow := run.enemies.spawn(crow_def, Vector2.ZERO)
	run.enemies.table.facing[crow] = 0.0
	row = pk.drop_crystal(Vector2(-run.enemies.table.r[crow] * 0.62, 0), PickupSystem.GemKind.MID, &"enemy", &"biter", 105)
	var carried := pk.gem_seq[row]
	run.enemies.behavior(&"crow").gather_pickups(pk, 1.0)
	check(run.enemies.table.carry[crow] == 50.0, "からす座が実際に結晶を回収する")
	pk.on_enemy_killed(crow)
	var outcome := {"weapons": s.weapons.duplicate(), "traits": s.traits.duplicate(), "hp": s.ship_hp,
		"xp": s.xp_gained, "rng": s.rng.state, "gems": Array(pk.gem_value), "alive": Array(pk.gem_alive)}
	if recording:
		rec._end("stopped")
		var rows := read_rows(path)
		var start: Dictionary = rows[0]
		check(start.schema_version == 4 and start.measurement_version == 3 and start.xp_reward_version == 2, "schema4 に識別可能な追加計測を保存する")
		check(start.perf_excludes_ui_pause, "報酬・メニューの停止を除いた録画を識別できる")
		check(start.run_start.conditions.config.gem_max == 1 and start.run_start.conditions.profile.mult.xp == 1.0, "開始時の実効設定と強化係数を保存する")
		check(start.run_start.conditions.identity.code_sha256.length() == 64 and start.run_start.conditions.identity.runtime_stage_sha256.length() == 64, "コード・実行ステージを識別するハッシュ")
		var changes := rows.filter(func(e): return e.type == "loadout")
		check(changes[0].source == "initial_choice" and changes[0].previous == 0 and changes[0].current == 1, "初期武器選択を記録する")
		check(changes.filter(func(e): return e.source == "level_bonus").size() == 3, "おまけ対象を3件すべて記録する")
		var equipment := {"weapon": {}, "trait": {}}
		for e in changes:
			check(equipment[e.kind].get(e.id, 0) == int(e.previous), "装備変更の前値が履歴につながる")
			if e.current == 0: equipment[e.kind].erase(e.id)
			else: equipment[e.kind][e.id] = int(e.current)
		check(equipment.weapon == RECORDER._plain(s.weapons) and equipment.trait == RECORDER._plain(s.traits), "時刻付き履歴から最終装備を復元できる")
		check(changes.any(func(e): return e.source == "comet" and e.id == "W21"), "空き枠への彗星武器取得")
		check(changes.any(func(e): return e.source == "comet_swap" and e.id == String(replaced) and e.current == 0) and s.weapons.has(&"W22"), "彗星交換の取り外しと取得を記録する")
		var hurts := rows.filter(func(e): return e.type == "hurt")
		check(hurts.size() == 2 and hurts[0].amount == 7.0 and hurts[1].amount == 3.0, "無敵による拒否を含めず実被弾を1発ずつ記録する")
		var samples := rows.filter(func(e): return e.type == "sample")
		check(samples.back().damage.get("bullet/reticle", 0) == 7.0 and samples.back().damage.get("touch/biter", 0) == 3.0, "既存の被弾集計へ二重計上しない")
		check(hurts[0].t == 12.25 and hurts[0].world_t == 7.5 and hurts[0].hp_after == 93.0 and hurts[1].source == "biter", "被弾の発生時刻・原因・残HPを保持する")
		check(rows.any(func(e): return e.type == "xp_collect" and e.get("id", -1) == ship_id and e.method == "ship" and e.kind == "low" and e.base_xp == 1.0), "通常結晶の生成IDと回収を対応づける")
		check(rows.any(func(e): return e.type == "xp_absorb" and e.target_id == first and e.new_supply and e.before_base_xp == 51.0 and e.after_base_xp == 101.0), "上限集約先のIDと新規供給・保持XPを区別する")
		var beacon: Array = rows.filter(func(e): return e.type == "xp_collect" and e.method == "magnet")
		check(beacon.size() == 1 and beacon[0].gems.size() == 1 and beacon[0].base_xp == 101.0 and beacon[0].t == 14.0, "ビーコン回収を1行で各結晶ID・値・時刻につなぐ")
		check(rows.any(func(e): return e.type == "xp_transfer" and e.id == carried), "からす座による回収を機体取得と区別する")
		check(rows.any(func(e): return e.type == "xp_absorb" and e.source == "crow_carry" and not e.new_supply and e.base_xp == 50.0), "からす座の運搬XPを再供給と識別する")
		check(rows.filter(func(e): return e.type == "pick").size() > 0 and rows.back().type == "end", "既存 pick・end の行形式を保持する")
		var previous_time := 0.0
		for e in rows:
			if e.has("t"):
				check(e.t >= previous_time, "出来事と区間行のラン時計が順序を保つ")
				previous_time = e.t
		print("MEASUREMENT_CHECK rows=%d bytes=%d" % [rows.size(), FileAccess.get_file_as_bytes(path).size()])
	rec._set_armed(false)
	check(not pk.xp_recorded.has_connections() and not run.loadout.loadout_recorded.has_connections(), "録画終了で追加計測の購読を解除する")
	rec.queue_free()
	scene.queue_free()
	await get_tree().process_frame
	return outcome


## EnemySystem の実イベントを録画へ接続し、通常開始と前半欠落の双方で変更境界を保持する。
func verify_live_tuning(during_run: bool) -> void:
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	if not during_run: rec._set_armed(true)
	var stage := ContentManager.runtime_stage(4).duplicate(true) as RuntimeStage
	stage.enemy_tuning = {}
	var scene := RunManager.create_session(self, {"stage": stage, "seed": 819, "stage_index": 4}, false)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var run: RunSimulation = scene.sim
	var state := run.state
	var hp := run.enemies.def_of(&"telescope").base_hp(run.cfg)
	var initial := {"telescope": {"hp": hp * 1.5}}
	if during_run:
		state.time = 7.0
		state.world_time = 3.0
		run.enemies.update_stage_tuning(initial)
		rec._set_armed(true)
		rec._begin(scene, true)
	check(rec._file != null, "ライブ調整の統合検証で録画を開始する")
	if rec._file == null:
		scene.queue_free()
		rec.queue_free()
		await get_tree().process_frame
		return
	var path := rec._file.get_path()
	var start: Dictionary = read_rows(path)[0]
	check(start.run_start.conditions.enemy_tuning.is_empty(), "ラン初期化時の上書きは後のライブ変更から独立する")
	check(start.recording_start.conditions.enemy_tuning == (initial if during_run else {}), "録画開始時のライブ上書きを保存する")
	check(start.missing_prefix == during_run, "ライブ調整でも前半欠落の区分を保つ")
	state.time = 10.25
	state.world_time = 4.5
	var values := {"telescope": {"hp": hp * 2.0}}
	var expected := values.duplicate(true)
	run.enemies.update_stage_tuning(values)
	values.telescope.hp = 1.0
	state.time = 11.0
	state.world_time = 5.0
	var rng_before := state.rng.state
	run.flush_events()
	check(state.rng.state == rng_before and run.enemies.stage_tuning == expected, "受信は乱数と適用済みの上書きを変更しない")
	rec._file.flush()
	var changes := read_rows(path).filter(func(e): return e.type == "enemy_tuning_changed")
	check(changes.size() == 1, "途中録画より前の通知待ち変更を履歴へ混ぜない")
	if changes.size() == 1:
		check(changes[0].event_t == 10.25 and changes[0].event_world_t == 4.5, "実イベントの適用ラン秒・世界秒を保存する")
		check(changes[0].t == 11.0 and changes[0].world_t == 5.0, "通知処理の時計を適用時刻から区別する")
		check(changes[0].values == expected, "適用後の辞書は通知待ち中の別編集から独立する")
	# ボーナス中はラン時計が止まっても世界秒と行順で変更を区別できる。
	state.bonus_t = 30.0
	state.world_time = 5.25
	run.enemies.update_stage_tuning({"telescope": {"hp": hp * 3.0}})
	state.world_time = 5.5
	run.enemies.update_stage_tuning({})
	run.enemies.update_stage_tuning({})
	state.world_time = 6.0
	run.flush_events()
	# 保存の通知は適用履歴と区別する。ソースファイルへの保存は行わず契約だけを検証する。
	state.emit(&"enemy_tuning_saved", {"t": state.time, "world_t": state.world_time,
		"path": "res://data/stages/stage_4.tres", "values": expected.duplicate(true)})
	run.flush_events()
	# 時刻を持たない通知も欠測のまま読めることを確認する。
	state.emit(&"enemy_tuning_changed", {"values": {}})
	run.flush_events()
	rec._end("stopped")
	var rows := read_rows(path)
	changes = rows.filter(func(e): return e.type == "enemy_tuning_changed")
	check(changes.size() == 4, "3回の実適用と時刻欠測の1通知だけを保存する")
	if changes.size() == 4:
		check(changes[1].event_t == 11.0 and changes[1].event_world_t == 5.25 and changes[2].event_world_t == 5.5, "停止したラン時計でも世界秒が適用順を保つ")
		check(changes[2].values.is_empty(), "空の辞書は上書き全解除として保存する")
		check(changes[3].event_t == null and changes[3].event_world_t == null, "欠けた適用時刻を処理時計で補完しない")
	var saved := rows.filter(func(e): return e.type == "enemy_tuning_saved")
	check(saved.size() == 1 and saved[0].path == "res://data/stages/stage_4.tres" and saved[0].values == expected, "保存通知を実適用と別の種類で保存する")
	check(rows.back().type == "end" and rows.back().result == "stopped", "ライブ履歴を含む録画も既存の終端を保つ")
	rec._set_armed(false)
	rec.queue_free()
	scene.queue_free()
	await get_tree().process_frame

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
