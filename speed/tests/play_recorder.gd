## カプセルの計測を短い操作で確認する。JSONL は /tmp の専用フォルダだけへ書く。
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
	check(on == off, "記録 ON/OFF で XP・レベル・乱数状態・残存カプセルが同じ")
	var records: Array[Dictionary] = []
	var file := FileAccess.open(recording_path, FileAccess.READ)
	while file.get_position() < file.get_length():
		var row: Variant = JSON.parse_string(file.get_line())
		check(row is Dictionary, "出力は JSONL")
		if row is Dictionary: records.append(row)
	file.close()
	verify(records)
	print("[play_recorder] passed=%d failed=%d output=%s" % [passed, failed, recording_path])
	get_tree().quit(1 if failed else 0)

func scenario(recording: bool) -> Dictionary:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 932, "empty": true, "stage": 1,
		"config": {"drop_base": 1.0, "drop_max": 1.0, "capsule_xp_frac": 2.0}})
	var run: RunManager = lab.run
	var pk := run.pickups
	var s := run.state
	s.ship_pos = Vector2(3000, 0)
	s.time = 5.0
	var existing := Pickup.new()
	existing.src = &"unrecognized"
	existing.pos = s.ship_pos + Vector2(800, 0)
	existing.value = 0.125
	pk.capsules.append(existing)
	var rec = RECORDER.new()
	add_child(rec)
	rec.set_process(false)
	rec._begin(run)
	check(rec._file == null, "実験場は通常の記録先へ書かない")
	if recording:
		var directory := "/tmp/speed-xp-recorder-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		DirAccess.make_dir_recursive_absolute(directory)
		recording_path = directory.path_join("capsules.jsonl")
		# 本番のファイル作成だけを分離し、通知・sample・end の処理はそのまま使う。
		rec._file = FileAccess.open(recording_path, FileAccess.WRITE)
		rec._run = run
		rec._start_capsules()
		check(rec._capsule_config().capsule_xp_frac == run.cfg.capsule_xp_frac, "開始時のカプセル設定を取得できる")
		run.phase_changed.connect(rec._on_phase_changed)
		run.tree_exiting.connect(rec._end.bind("quit"))
	# 実際の敵ドロップ経路と通常回収。XP でレベルが上がる前の値を記録する。
	var row := run.enemies.spawn(ConfigManager.enemies[&"biter"], s.ship_pos)
	pk.on_enemy_killed(row)
	pk._collect_capsules(0.01)
	check(s.level > 1, "通常回収の XP がレベルを上げる")
	# 実際の漂流生成経路。
	s.time = 6.0
	pk._spawn_field_capsules(run.cfg.drift_capsule_interval)
	var drift: Pickup = null
	for c: Pickup in pk.capsules:
		if c.src == &"field": drift = c
	check(drift != null, "漂流カプセルを生成する")
	# 通常カプセルがビーコンより先に回収され、残り2個はビーコンが回収する。
	# 3個とも回収圏内に置き、同じループ内の二重回収を確認する。
	pk._add_capsule(Pickup.Kind.CACHE, &"drop", s.ship_pos, 0.25)
	pk._add_capsule(Pickup.Kind.MAGNET, &"drop", s.ship_pos, 0.0)
	pk._add_capsule(Pickup.Kind.CACHE, &"drop", s.ship_pos, run.build.xp_needed() * 3.0 + 0.5)
	if drift != null:
		drift.pos = s.ship_pos
		pk.capsules.erase(drift)
		pk.capsules.append(drift)
	existing.pos = s.ship_pos + Vector2(800, 0)
	# 生成不明の既存カプセルもビーコンの対象になる。
	pk._collect_capsules(0.01)
	# 期限切れ、距離による除去、通知のない除去、終了時の未回収。
	s.time = 7.0
	pk._add_capsule(Pickup.Kind.CACHE, &"drop", s.ship_pos + Vector2(2000, 0), 0.75)
	pk.capsules.back().age = run.cfg.pickup_life + 1.0
	pk._collect_capsules(0.01)
	pk._add_capsule(Pickup.Kind.CACHE, &"field", s.ship_pos + Vector2(100000, 0), 1.25)
	run.cfg.drift_capsule_count = 0
	pk._spawn_field_capsules(0.01)
	pk._add_capsule(Pickup.Kind.CACHE, &"unrecognized", s.ship_pos + Vector2(800, 0), 1.5)
	pk.capsules.pop_back()
	pk._add_capsule(Pickup.Kind.CACHE, &"drop", s.ship_pos + Vector2(800, 0), 2.0)
	# 配列へ直接追加されたものは、生成済みと偽らず observed として記録する。
	var unknown := Pickup.new()
	unknown.src = &"unrecognized"
	unknown.pos = s.ship_pos + Vector2(800, 0)
	unknown.value = 0.0625
	pk.capsules.append(unknown)
	var outcome := {"xp": s.xp_gained, "level": s.level, "rng": s.rng.state, "remaining": pk.capsules.size()}
	if recording:
		s.time = 8.0
		rec._on_phase_changed(RunState.Phase.ENDED)
		check(rec._file == null and rec._run == null, "ラン終了でファイルを閉じる")
	check(not pk.xp_capsule_event.has_connections(), "記録 OFF/終了後は購読・計測が残らない")
	pk._add_capsule(Pickup.Kind.CACHE, &"drop", s.ship_pos, 0.03125)
	pk._collect_capsules(0.01)
	check(rec._xp_capsules.is_empty(), "記録 OFF/終了後にカプセルを追跡しない")
	rec.queue_free()
	lab.queue_free()
	await get_tree().process_frame
	return outcome

func verify(records: Array[Dictionary]) -> void:
	var spawned := {}
	var collected := {}
	var lost := {}
	var observed := 0
	var beacon := 0
	var normal := 0
	var reasons := {}
	var beacon_levels := {}
	for e in records:
		match e.type:
			"xp_capsule_spawn":
				check(not spawned.has(e.id), "生成 ID はラン内で一意")
				spawned[e.id] = e
				check(e.spawned == e.t, "生成時刻を保持する")
			"xp_capsule_observed":
				observed += 1
				check(e.spawned == null and e.source == "unknown", "生成や出所が不明なら偽らない")
			"xp_capsule_collect":
				check(not collected.has(e.id), "カプセルを二重計上しない")
				collected[e.id] = e
				if e.cause == "beacon":
					beacon += 1
					beacon_levels[e.level] = true
				if e.cause == "normal": normal += 1
				if e.t == 5.0:
					check(e.level == 1 and e.source == "enemy_drop", "通常回収は加算前レベルと敵ドロップを記録")
				if e.source == "drift":
					check(e.cause == "beacon" and e.t == 6.0, "漂流のビーコン回収に時刻と出所がある")
				if spawned.has(e.id): check(e.xp == spawned[e.id].xp, "1個の XP を丸めず保持する")
			"xp_capsule_lost":
				lost[e.id] = e
				reasons[e.cause] = true
	check(normal == 2 and beacon == 3, "通常2個・ビーコン3個を分けて記録する")
	check(beacon_levels.size() == 1 and beacon_levels.has(2.0), "ビーコンは合算 XP 加算前のレベルを全個に記録する")
	check(observed == 2, "生成未確認は別の観測数にする")
	check(reasons.has("expired") and reasons.has("distance_cull") and reasons.has("unknown"), "消失原因を区別する")
	var end: Dictionary = records.back()
	check(end.type == "end" and end.result == "quit", "終了行は既存形式を維持する")
	check(end.xp_capsules_remaining.size() == 2, "終了時の未回収2個を利用できる")
	check(end.xp_capsules.enemy_drop.remaining == 1 and end.xp_capsules.unknown.remaining == 1, "未回収を出所別に集計する")
	check(end.xp_capsules.enemy_drop.remaining_xp == 2.0, "未回収 XP を保持する")
	var generated := 0
	for source in end.xp_capsules:
		var counts: Dictionary = end.xp_capsules[source]
		generated += int(counts.get("spawn", 0))
	check(generated + observed == collected.size() + lost.size() + end.xp_capsules_remaining.size(), "生成・観測＝取得＋消失＋残存")
