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
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("[play_recorder] " + label)

func _ready() -> void:
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
	await verify_mid_run_start()
	await verify_start_routes()
	var measured_on := await measurement_scenario(true)
	var measured_off := await measurement_scenario(false)
	check(measured_on == measured_off, "追加イベントの ON/OFF で装備・HP・XP・乱数・結晶が同じ")
	print("[play_recorder] passed=%d failed=%d output=%s" % [passed, failed, recording_path])
	get_tree().quit(1 if failed else 0)

func verify_mid_run_start() -> void:
	var scene := RunManager.create_run() as Node
	add_child(scene)
	if scene.sim.state == null: await scene.started
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var run := scene.sim as RunSimulation
	await get_tree().process_frame
	run.state.time = 42.0
	run.state.level = 3
	run.state.xp = 0.125
	run.state.xp_gained = 1000.0
	run.state.xp_dropped = 1200.0
	run.state.weapons[&"W01"] = 2
	run.state.kills = 10
	var existing_row := run.pickups.drop_gem(Vector2.ZERO, 8.0)
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
	rec._input(key)
	check(rec._file != null, "プレイ中の F9 で既存ランの記録を開始する")
	check(before == [run.state.time, run.state.level, run.state.xp, run.state.rng.state], "録画開始は時計・成長・乱数を変えない")
	if rec._file != null:
		var path := rec._file.get_path()
		var start: Dictionary = read_rows(path)[0]
		check(start.run_start.source == "stage_start" and start.run_start.t == 0.0, "通常ランの出自を途中録画でも保つ")
		check(start.run_start.level == 0 and start.run_start.weapons.is_empty(), "初期武器の選択前の状態を保持する")
		check(start.recording_start.t == 42.0 and start.recording_start.level == 3 and start.recording_start.xp == 0.125, "録画開始時の時計・レベル・XP を保存する")
		check(start.recording_start.weapons.W01 == 2 and start.recording_start.xp_gained == 1000.0, "録画開始時の装備と累計を保存する")
		check(start.missing_prefix and start.recording_start.trigger == "during_run", "同じ通常ランでも前半欠落を明示する")
		var existing: Dictionary = read_rows(path)[1]
		check(existing.type == "xp_existing" and existing.origin == "unobserved" and int(existing.gems[0][0]) == existing_id and existing.gems[0][1] == 8.0, "途中開始の残存結晶IDと値を生成不明として記録する")
		check(start.run_start.conditions.profile == RECORDER.IDENTITY.plain(initial_profile) and start.recording_start.conditions.profile.mult.xp == 9.0, "開始時の強化と途中録画時の強化を区別する")
		check(rec._offered.size() == run.state.cards.size(), "既に表示中のカード候補を引き継ぐ")
		rec._set_armed(true)
		rec._begin(scene)
		check(rec._file.get_path() == path and read_rows(path).size() == 2, "重複開始でファイルを作り直さない")
		run.flush_events()
		check(read_rows(path).filter(func(row): return row.type == "hurt").is_empty(), "F9前から通知待ちの被弾を観測区間へ混ぜない")
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
		check(read_rows(path).back().result == "stopped", "F9 停止を記録する")
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
			var run := scene.sim as RunSimulation
			run.options = {"seed": 932}
			add_child(scene)
			if scene.sim.state == null: await scene.started
			scene.process_mode = Node.PROCESS_MODE_DISABLED
			await get_tree().process_frame
			check(GameManager.run_start_time == 0.0 and GameManager.run_start_source == "stage_start", "開始条件を次のランへ持ち越さない")
			if delayed:
				# 初期武器を選び、実際のラン更新を短く進めてから F9。
				run.choose_card(0)
				run.combat.rebuild_grid()
				for tick in 12:
					run.physics_step(1.0 / 120.0)
				var snapshot := run.recording_snapshot()
				var rng := run.state.rng.state
				var key := InputEventKey.new()
				key.keycode = KEY_F9
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
	await lab.reset({"seed": 932, "empty": true, "stage": 1, "config": {"drop_base": 1.0, "drop_max": 1.0}})
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
		recording_path = directory.path_join("big_crystals.jsonl")
		# 本番のファイル作成だけを分離し、通知・sample・end の処理はそのまま使う。
		rec._file = FileAccess.open(recording_path, FileAccess.WRITE)
		rec._run = run
		rec._session = lab.scene
		rec._big_crystals = {}
		pk.big_crystal_dropped.connect(rec._on_big_crystal)
		check(rec._xp_config().big_crystal_xp == Array(run.cfg.big_crystal_xp), "開始時の大きい結晶の設定を取得できる")
		run.phase_changed.connect(rec._on_phase_changed)
		lab.scene.tree_exiting.connect(rec._end.bind("quit"))
	# 実際の敵ドロップ経路。ドロップ率1なので雑魚も大きい結晶を落とし、レチクル座は中の段を必ず落とす。
	pk.on_enemy_killed(run.enemies.spawn(ContentManager.enemies[&"biter"], s.ship_pos))
	s.time = 6.0
	pk.on_enemy_killed(run.enemies.spawn(ContentManager.enemies[&"reticle"], s.ship_pos))
	pk._collect_gems(0.01)
	check(s.xp_gained >= 75.0 + 12.0, "大きい結晶の XP を回収する")
	var outcome := {"xp": s.xp_gained, "level": s.level, "rng": s.rng.state, "gems": pk.gem_slots.live}
	if recording:
		s.time = 8.0
		rec._on_phase_changed(RunState.Phase.ENDED)
		check(rec._file == null and rec._run == null, "ラン終了でファイルを閉じる")
	check(not pk.big_crystal_dropped.has_connections(), "記録 OFF/終了後は購読が残らない")
	rec.queue_free()
	lab.queue_free()
	await get_tree().process_frame
	return outcome

func verify(records: Array[Dictionary]) -> void:
	var drops: Array[Dictionary] = []
	for e in records:
		if e.type == "big_crystal":
			drops.append(e)
	check(drops.size() == 2, "大きい結晶を1個ずつ記録する")
	if drops.size() == 2:
		check(drops[0].t == 5.0 and drops[0].enemy == "biter" and drops[0].level == 1.0, "時刻・落とした敵・落ちたときのレベルを記録する")
		check(drops[1].enemy == "reticle" and drops[1].tier == 2.0 and drops[1].xp == 75.0, "レチクル座は中の段を落とす")
	var end: Dictionary = records.back()
	check(end.type == "end" and end.result == "quit", "終了行は既存形式を維持する")
	var count := 0
	for tier in end.big_crystals:
		count += int(end.big_crystals[tier].count)
	check(count == drops.size(), "終了時に段ごとの数を集計する")

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
	var rec := TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	if recording: rec._set_armed(true)
	var scene := RunManager.create_session(self, {"seed": 704, "config": config, "profile": ProfileManager.compute({})}, false)
	scene.auto_step = false
	var run := scene.sim
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
	var row := pk.drop_gem(s.ship_pos, 2.5, &"enemy", &"biter", 101)
	var ship_id := pk.gem_seq[row]
	pk._collect_gems(0.01)
	row = pk.drop_gem(Vector2.ZERO, 5.0, &"big_crystal", &"reticle", 102, 2)
	var first := pk.gem_seq[row]
	pk.drop_gem(Vector2.ZERO, 3.0, &"enemy", &"biter", 103)
	row = pk.drop_gem(Vector2.ZERO, 4.0, &"enemy", &"biter", 104)
	var merged := pk.gem_seq[row]
	s.time = 14.0
	pk.collect(&"magnet")
	# からす座の実際の回収経路と、運搬XPの再ドロップ。
	var crow_def := run.enemies.def_of(&"crow").duplicate(true) as EnemyDef
	crow_def.params.flock = 1
	var crow := run.enemies.spawn(crow_def, Vector2.ZERO)
	run.enemies.table.facing[crow] = 0.0
	row = pk.drop_gem(Vector2(-run.enemies.table.r[crow] * 0.62, 0), 6.0, &"enemy", &"biter", 105)
	var carried := pk.gem_seq[row]
	run.enemies.behavior(&"crow").gather_pickups(pk, 1.0)
	check(run.enemies.table.carry[crow] == 6.0, "からす座が実際に結晶を回収する")
	pk.on_enemy_killed(crow)
	var outcome := {"weapons": s.weapons.duplicate(), "traits": s.traits.duplicate(), "hp": s.ship_hp,
		"xp": s.xp_gained, "rng": s.rng.state, "gems": Array(pk.gem_value), "alive": Array(pk.gem_alive)}
	if recording:
		rec._end("stopped")
		var rows := read_rows(path)
		var start: Dictionary = rows[0]
		check(start.schema_version == 4 and start.measurement_version == 1, "schema4 に識別可能な追加計測を保存する")
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
		check(rows.any(func(e): return e.type == "xp_collect" and e.get("id", -1) == ship_id and e.method == "ship" and e.xp == 2.5), "通常結晶の生成IDと回収を対応づける")
		check(rows.any(func(e): return e.type == "xp_drop" and e.id == merged and e.merged_from == first and e.added_xp == 4.0 and e.xp == 9.0), "合流の親IDと新規供給量を区別する")
		var beacon: Array = rows.filter(func(e): return e.type == "xp_collect" and e.method == "beacon")
		check(beacon.size() == 1 and beacon[0].gems.size() == 2 and beacon[0].xp == 12.0 and beacon[0].t == 14.0, "ビーコン回収を1行で各結晶ID・値・時刻につなぐ")
		check(rows.any(func(e): return e.type == "xp_transfer" and e.id == carried), "からす座による回収を機体取得と区別する")
		check(rows.any(func(e): return e.type == "xp_drop" and e.source == "crow_carry" and e.added_xp == 6.0), "からす座の運搬XPを再供給と識別する")
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
