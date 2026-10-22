## 大きい結晶の計測を短い操作で確認する。JSONL は /tmp の専用フォルダだけへ書く。
## Godot --headless --path speed res://tests/play_recorder.tscn
extends Node

const RECORDER := preload("res://scripts/managers/play_recorder.gd")
var passed := 0
var failed := 0
var recording_path := ""

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("[play_recorder] " + label)

func _ready() -> void:
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
	print("[play_recorder] passed=%d failed=%d output=%s" % [passed, failed, recording_path])
	get_tree().quit(1 if failed else 0)

func scenario(recording: bool) -> Dictionary:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 932, "empty": true, "stage": 1, "config": {"drop_base": 1.0, "drop_max": 1.0}})
	var run: RunManager = lab.run
	var pk := run.pickups
	var s := run.state
	s.ship_pos = Vector2(3000, 0)
	s.time = 5.0
	var rec = TempRecorder.new()
	add_child(rec)
	rec.set_process(false)
	rec._set_armed(true)
	rec._begin(run)
	check(rec._file == null, "実験場は通常の記録先へ書かない")
	rec._set_armed(false)
	if recording:
		var directory := "/tmp/speed-xp-recorder-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		DirAccess.make_dir_recursive_absolute(directory)
		recording_path = directory.path_join("big_crystals.jsonl")
		# 本番のファイル作成だけを分離し、通知・sample・end の処理はそのまま使う。
		rec._file = FileAccess.open(recording_path, FileAccess.WRITE)
		rec._run = run
		rec._big_crystals = {}
		pk.big_crystal_dropped.connect(rec._on_big_crystal)
		check(rec._xp_config().big_crystal_xp == Array(run.cfg.big_crystal_xp), "開始時の大きい結晶の設定を取得できる")
		run.phase_changed.connect(rec._on_phase_changed)
		run.tree_exiting.connect(rec._end.bind("quit"))
	# 実際の敵ドロップ経路。ドロップ率1なので雑魚も大きい結晶を落とし、レチクル座は中の段を必ず落とす。
	pk.on_enemy_killed(run.enemies.spawn(ConfigManager.enemies[&"biter"], s.ship_pos))
	s.time = 6.0
	pk.on_enemy_killed(run.enemies.spawn(ConfigManager.enemies[&"reticle"], s.ship_pos))
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
	var run: RunManager = lab.run
	run.set_physics_process(false)
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
