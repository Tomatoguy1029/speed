## 短時間の性能計測専用。実ゲームの仕様・セーブは変更しない。
## -- --time=320 --stage=1 --size=1280x720 --sparks=off --glow=off --hazards=on --types=pump,lynx
## -- --enemies=1000 --type=biter --keep=on --levels=off --hitstop=off --gpu=off
## -- --weapons=W02:5,W05:5,W08:5,W17:5 --drive=circle --draw=2
extends Node

## 敵の数を保つときに補う間隔（フレーム）
const REFILL_FRAMES := 15
## --drive=circle で機体が回る円の半径（ワールド単位）
const DRIVE_RADIUS := 900.0

var session: RunSession
var run: RunSimulation
var render: RunPresentation
## 計測の間だけ開く、このベンチ用の処理時間の記録（ゲーム側・表示側・敵の描画の行の数）
var sim_rec := {}
var view_rec := {}
var rows_rec := {}
## --drive=circle の円の中心と、--draw で次に線を描く実時刻（マイクロ秒）
var drive_center := Vector2.ZERO
var next_draw_us := 0
var drawing_times: Dictionary = {}
var frames: Array[float] = []
var gpu_times: Array[float] = []
var render_times: Array[float] = []
var draws: Array[float] = []
var measuring := false
var configured := false
var initial_weapons := {}
var initial_traits := {}
var loadout_changes := 0
var previous_us := 0
var start_us := 0
var counts := {"enemies": 0.0, "hostile": 0.0, "hazards": 0.0, "friendly": 0.0, "gems": 0.0}
var options: Dictionary = {}
var saved_rd: RenderingDevice
var attacked := false
var timeline: Array = []
var last_totals: Dictionary = {}
var phase_trace: Array = []

class FrameEnd extends Node:
	var recorder: Node
	func _process(_dt: float) -> void:
		recorder._mark(&"process_end")

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", false, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
	SaveManager.data = SaveManager.default_data()
	GameManager.run_stage = int(options.get("stage", "1"))
	GameManager.run_endless = false
	if options.has("overlay"):
		# --overlay=compact|detail で性能の表示を出した状態で始める
		PerfOverlay.saved_mode = PerfOverlay.Mode.DETAIL if options.overlay == "detail" else PerfOverlay.Mode.COMPACT
	session = RunManager.create_run()
	# 配置と装備の初期化も同じ乱数列から始める。
	session.sim.options.seed = 1029
	add_child(session)
	if session.sim.state == null: await session.started
	run = session.sim
	render = session.view.get_node("RunPresentation")
	await get_tree().process_frame
	await get_tree().process_frame
	# 指定装備へ直接置き換える。準備中の初期カードを後から確定させない。
	run.loadout.reset_loadout()
	run.state.start_pick = false
	run.state.cards.clear()
	run.set_phase(RunState.Phase.PLAY)
	run.loadout.grant(&"weapon", &"W01", 1)
	if options.get("attack", "off") == "on":
		run.loadout.reset_loadout()
		for id in [&"W03", &"W04", &"W08", &"W17"]:
			run.loadout.grant(&"weapon", id, 5)
		run.loadout.grant(&"trait", &"T04", 5)
	if options.has("weapons"):
		# --weapons=W01:5,W02:3,T03:2 で装備を置き換える（T で始まるものは特性）
		run.loadout.reset_loadout()
		for item in String(options.weapons).split(",", false):
			var parts := item.split(":")
			var kind := &"trait" if parts[0].begins_with("T") else &"weapon"
			run.loadout.grant(kind, StringName(parts[0]), int(parts[1]) if parts.size() > 1 else 1)
	initial_weapons = run.state.weapons.duplicate()
	initial_traits = run.state.traits.duplicate()
	run.loadout.loadout_recorded.connect(func(_change: Dictionary): loadout_changes += 1)
	run.state.rng.seed = 1029
	# ランの初期化は乱数配置なので、天体も同じシードで作り直す。
	# 天体との接触量の違いを、描画の比較条件へ混ぜない。
	run.field.bodies.clear()
	run.field.moons.clear()
	run.field.rocks.clear()
	run.enemies.clear_all()
	run.field.setup(run.ctx)
	run.ship.setup(run.ctx)
	run.state.world_time = 0.0
	run.ship.invincible = true
	run.input._touch = true
	run.input.set_process_input(false)
	run.input.set_process_unhandled_input(false)
	run.state.time = float(options.get("time", "10"))
	if options.has("enemies"):
		_spawn_enemies(int(options.enemies))
	if options.get("levels", "on") == "off":
		# 倒した経験値でレベルアップ画面に入ると世界が止まり、装備も変わるので、経験値を入れない
		get_tree().physics_frame.connect(_hold_level)
	if options.get("drive", "") == "circle":
		# 決まった円を回り続ける入力に替え、機体の速さと向きの変化で動く武器も働かせる
		drive_center = run.state.ship_pos
		run.input_source = _drive_intent
	if options.get("hitstop", "on") == "off":
		# 大量に倒すとヒットストップで世界の更新が止まり、処理の時間が測れないので切る
		run.state.hitstop_enabled = false
		run.state.hitstop = 0.0
	if options.has("types"):
		# --types=pump,lynx で、指定した種類の敵を機体の周りに2体ずつ出す
		for type in String(options.types).split(",", false):
			for k in 2:
				run.enemies.spawn(run.enemies.def_of(StringName(type)),
					run.state.ship_pos + Vector2.from_angle(run.state.rng.randf() * TAU) * 450.0)
		run.combat.rebuild_grid()
	if options.has("size") and DisplayServer.get_name() != "headless":
		var size := String(options.size).split("x")
		DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	if options.get("sparks", "on") == "off":
		saved_rd = render.pipeline.sparks.rd
		render.pipeline.sparks.rd = null
		render.pipeline.sparks.hide()
	if options.get("glow", "on") == "off":
		for child in session.view.get_node("World").get_children():
			if child is WorldEnvironment:
				child.environment.glow_enabled = false
	if options.get("background", "on") == "off":
		render._layers.background.draw_fn = func(_c): pass
		if render.get("_star_batch") != null:
			render._star_batch.hide()
	if options.has("hz"):
		Engine.physics_ticks_per_second = int(options.hz)
	if options.has("fps"):
		Engine.max_fps = int(options.fps)
	for key in render._layers:
		var layer: DrawLayer = render._layers[key]
		layer.draw_fn = _timed_draw.bind(key, layer.draw_fn)
	# --gpu=off で GPU 時間の計測を切る
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), options.get("gpu", "on") != "off")
	if options.get("trace", "off") == "on":
		get_tree().physics_frame.connect(_mark.bind(&"physics_begin"))
		get_tree().process_frame.connect(_mark.bind(&"process_begin"))
		RenderingServer.frame_pre_draw.connect(_mark.bind(&"draw_begin"))
		RenderingServer.frame_post_draw.connect(_mark.bind(&"draw_end"))
		var end := FrameEnd.new()
		end.recorder = self
		end.process_priority = 10000
		add_child(end)
	configured = true
	await get_tree().create_timer(6.0).timeout
	drawing_times.clear()
	sim_rec = run.perf.open(&"bench")
	view_rec = render.perf.open(&"bench")
	rows_rec = render.perf_rows.open(&"bench")
	sim_rec.clear()
	view_rec.clear()
	rows_rec.clear()
	previous_us = Time.get_ticks_usec()
	start_us = previous_us
	measuring = true
	print("PROFILE_BEGIN ", JSON.stringify({"options": options, "window": str(DisplayServer.window_get_size()),
		"viewport": str(get_viewport().get_visible_rect().size), "texture": str(get_viewport().get_texture().get_size()),
		"field_seed": 1029,
		"sparks_size": str(render.pipeline.sparks._image_size), "gpu_sparks": render.pipeline.sparks.available(),
		"renderer": RenderingServer.get_current_rendering_method(), "physics_hz": Engine.physics_ticks_per_second,
		"world_tick_div": run.cfg.world_tick_div, "max_fps": Engine.max_fps,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"machine": OS.get_processor_name(), "initial_enemies": run.enemies.count(), "adapter": RenderingServer.get_video_adapter_name()}))

func _timed_draw(c: CanvasItem, key: String, original: Callable) -> void:
	if not measuring:
		original.call(c)
		return
	var before := Time.get_ticks_usec()
	original.call(c)
	var rec: Array = drawing_times.get(key, [0, 0])
	rec[0] += Time.get_ticks_usec() - before
	rec[1] += 1
	drawing_times[key] = rec
	if options.get("trace", "off") == "on":
		phase_trace.append({"name": "layer:" + key, "start_us": before - start_us,
			"end_us": Time.get_ticks_usec() - start_us, "frame": Engine.get_process_frames()})

func _mark(label: StringName) -> void:
	if measuring:
		phase_trace.append({"name": label, "us": Time.get_ticks_usec() - start_us, "frame": Engine.get_process_frames()})

func _process(_delta: float) -> void:
	if run == null or not configured:
		return
	var ui_paused := run.ui_reward_active or run.ui_overlay_active
	# 付与済み報酬の表示だけを閉じ、連続して戦闘を測るための明示指定。
	if options.get("rewards", "on") == "off" and run.ui_reward_active:
		session.view.get_node("Hud/HudRoot")._rewards.cancel()
	# フォーカスによるポーズと強化選択を計測に含めない。
	if run.state.phase == RunState.Phase.PAUSED:
		run.command(&"resume")
	elif run.state.phase == RunState.Phase.LEVELUP:
		run.command(&"choose_card", {"index": 0})
	# --hazards=on で、敵の攻撃の形を一定間隔で出す（描画と当たり判定の確認用）
	if options.get("hazards", "off") == "on" and Engine.get_process_frames() % 90 == 0:
		run.command(&"debug_hazards")
	# --draw=秒 で、その間隔で機体の前へジグザグの線を描いて駆け抜ける
	if options.has("draw") and Engine.get_process_frames() > 2:
		var now_draw := Time.get_ticks_usec()
		if now_draw >= next_draw_us and _draw_ahead():
			next_draw_us = now_draw + int(float(options.draw) * 1000000.0)
	# --keep=on で、倒された分を補って --enemies の数を保つ
	if options.get("keep", "off") == "on" and options.has("enemies") and Engine.get_process_frames() % REFILL_FRAMES == 0:
		var missing := int(options.enemies) - run.enemies.count()
		if missing > 0:
			_spawn_enemies(missing)
	if not measuring:
		return
	var now := Time.get_ticks_usec()
	frames.append((now - previous_us) / 1000.0)
	previous_us = now
	var row := {"elapsed_ms": (now - start_us) / 1000.0, "frame_ms": frames[-1],
		"ui_paused": ui_paused,
		"engine_frame": Engine.get_process_frames(), "managers": {}, "drawing": {},
		"frame_setup_cpu_ms": RenderingServer.get_frame_setup_time_cpu(),
		"viewport_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),
		"canvas_compiles": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
		"draw_compiles": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		"specialization_compiles": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION),
		"enemies": run.enemies.count(), "hostile": run.projectiles.hostile_count(),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"gems": run.pickups.gem_slots.live, "friendly": run.projectiles.friend_count(), "hazards": run.projectiles.hazard_count()}
	for key in sim_rec:
		var rec: Array = sim_rec[key]
		var prev: Array = last_totals.get(key, [0, 0])
		row.managers[key] = {"ms": (rec[0] - prev[0]) / 1000.0, "calls": rec[1] - prev[1]}
		last_totals[key] = [rec[0], rec[1]]
	for key in drawing_times:
		var rec: Array = drawing_times[key]
		var label: String = "draw:" + key
		var prev: Array = last_totals.get(label, [0, 0])
		row.drawing[key] = {"ms": (rec[0] - prev[0]) / 1000.0, "calls": rec[1] - prev[1]}
		last_totals[label] = [rec[0], rec[1]]
	# 表示側の処理（内訳を含む）の、このフレームの時間
	row["view"] = {}
	for key in view_rec:
		var rec: Array = view_rec[key]
		var label: String = "view:" + String(key)
		var prev: Array = last_totals.get(label, [0, 0])
		row.view[String(key)] = (rec[0] - prev[0]) / 1000.0
		last_totals[label] = [rec[0], rec[1]]
	timeline.append(row)
	if options.get("attack", "off") == "on" and not attacked and now - start_us > 1500000:
		attacked = true
		var p := run.state.ship_pos
		var it := Intent.new()
		it.press = true
		it.pen = p + Vector2(-400, 0)
		run.draw._start(it)
		run.draw._extend(p + Vector2(400, 0))
		run.draw._extend(p + Vector2(200, 400))
		run.draw._commit(it)
	var viewport := get_viewport().get_viewport_rid()
	gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	render_times.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
	draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	counts.enemies += run.enemies.count()
	counts.hostile += run.projectiles.hostile_count()
	counts.hazards += run.projectiles.hazard_count()
	counts.friendly += run.projectiles.friend_count()
	counts.gems += run.pickups.gem_slots.live
	if now - start_us >= int(float(options.get("seconds", "6")) * 1000000.0):
		measuring = false
		_finish((now - start_us) / 1000000.0)

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	return {"mean": total / values.size(), "p95": values[int((values.size() - 1) * 0.95)], "max": values[-1]}

func _finish(seconds: float) -> void:
	var manager_ms := {}
	for key in sim_rec:
		var rec: Array = sim_rec[key]
		manager_ms[key] = {"ms_tick": rec[0] / 1000.0 / rec[1], "ms_frame": rec[0] / 1000.0 / frames.size(), "calls": rec[1]}
		if rec.size() >= 3:
			manager_ms[key].max_tick_ms = rec[2] / 1000.0
	var draw_ms := {}
	for key in drawing_times:
		var rec: Array = drawing_times[key]
		draw_ms[key] = rec[0] / 1000.0 / frames.size()
	for key in counts:
		counts[key] /= frames.size()
	# 表示側（RunPresentation）の処理ごとの時間。名前に「.」を含む項目は前半の項目の内訳
	var view_ms := {}
	for key in view_rec:
		var rec: Array = view_rec[key]
		view_ms[String(key)] = {"ms_frame": rec[0] / 1000.0 / frames.size(), "max_ms": rec[2] / 1000.0, "calls": rec[1]}
	var view_rows := {}
	for key in rows_rec:
		var rec: Array = rows_rec[key]
		view_rows[String(key)] = {"mean": float(rec[0]) / maxi(1, rec[1]), "max": rec[2]}
	var result := {"seconds": seconds, "frames": frames.size(), "fps": frames.size() / seconds,
		"ui_pause_frames": timeline.filter(func(row): return row.ui_paused).size(),
		"initial_weapons": initial_weapons, "initial_traits": initial_traits,
		"loadout_changes": loadout_changes, "traits": run.state.traits,
		"level": run.state.level,
		"frame_ms": _stats(frames), "gpu_viewport_ms": _stats(gpu_times), "render_cpu_ms": _stats(render_times),
		"draw_calls": _stats(draws), "counts": counts, "managers": manager_ms, "drawing_ms_frame": draw_ms,
		"view_ms": view_ms, "view_enemy_rows": view_rows,
		"phase": run.state.phase, "time": run.state.time, "world_time": run.state.world_time, "weapons": run.state.weapons}
	result.timeline = timeline
	result.phase_trace = phase_trace
	result.kills = run.state.kills
	if options.get("body_benchmark", "off") == "on":
		result.body_benchmark = _benchmark_bodies()
	if gpu_times[-1] <= 0.0:
		result.gpu_viewport_ms = {"available": false}
	print("PROFILE_RESULT ", JSON.stringify(result))
	print("PROFILE_SUMMARY ", _summary(result))
	if options.has("capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(options.capture)
	if saved_rd != null:
		render.pipeline.sparks.rd = saved_rd
	set_process(false)
	run.perf.close(&"bench")
	render.perf.close(&"bench")
	render.perf_rows.close(&"bench")
	# ランと描画リソースの後始末を、通常のノード削除で済ませてから閉じる。
	session.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

## 結果の要点を、出力で読みやすい複数行の文字列にする（1フレームあたりの平均、ms）。
func _summary(result: Dictionary) -> String:
	var frame: Dictionary = result.frame_ms
	var game: float = result.managers.get(&"play_total", {}).get("ms_frame", 0.0)
	# 表示側の出来事の処理（events）は、出来事の受け渡し（events_out）に含まれるので数えない
	var view := 0.0
	for key in result.view_ms:
		if not key.contains(".") and key != "events":
			view += result.view_ms[key].ms_frame
	var events: float = result.managers.get(&"events_out", {}).get("ms_frame", 0.0)
	var lines: Array[String] = []
	lines.append("fps %.1f  フレーム 平均 %.2f p95 %.2f 最大 %.2f" % [result.fps, frame.mean, frame.p95, frame.max])
	if result.ui_pause_frames > 0:
		lines.append("報酬・メニューでゲームが停止したフレーム %d（連続戦闘の比較には使わない）" % result.ui_pause_frames)
	if result.loadout_changes > 0:
		lines.append("準備開始後の装備変更 %d（固定装備の比較には使わない）" % result.loadout_changes)
	lines.append("ゲーム処理 %.2f  出来事の受け渡し %.2f  表示側 %.2f  残り（描画エンジン・GPU・待ち）%.2f  敵 %.0f" % [
		game, events, view, maxf(0.0, frame.mean - game - events - view), result.counts.enemies])
	var managers: Array = result.managers.keys().filter(func(k): return k != &"play_total" and k != &"events_out" and not String(k).contains("."))
	managers.sort_custom(func(a, b): return result.managers[a].ms_frame > result.managers[b].ms_frame)
	for key in managers.slice(0, 6):
		lines.append("  処理 %-18s %.2f（更新1回 %.3f）" % [key, result.managers[key].ms_frame, result.managers[key].ms_tick])
	# 敵の行動・武器・弾などの種類ごとの内訳
	var parts: Array = result.managers.keys().filter(func(k): return String(k).contains("."))
	parts.sort_custom(func(a, b): return result.managers[a].ms_frame > result.managers[b].ms_frame)
	for key in parts.slice(0, 10):
		lines.append("  内訳 %-26s %.2f" % [key, result.managers[key].ms_frame])
	var views: Array = result.view_ms.keys()
	views.sort_custom(func(a, b): return result.view_ms[a].ms_frame > result.view_ms[b].ms_frame)
	for key in views.slice(0, 8):
		lines.append("  表示 %-26s %.2f（1回の最大 %.2f）" % [key, result.view_ms[key].ms_frame, result.view_ms[key].max_ms])
	var rows: Dictionary = result.view_enemy_rows
	if rows.has("rows"):
		lines.append("  敵の行 見た %.0f 生存 %.0f 一括 %.0f 個別 %.0f 飾り %.0f" % [rows["rows"].mean, rows["live"].mean,
			rows["batched"].mean, rows["self_drawn"].mean, rows["marked"].mean])
	return "\n".join(lines)

## 画面内に n 体の敵を出す。--type=ID ならその種類だけ、なければ試せる種類から無作為に選ぶ。
func _spawn_enemies(n: int) -> void:
	if not options.has("type"):
		run.command(&"debug_spawn_enemies", {"count": n})
		return
	var def := run.enemies.def_of(StringName(options.type))
	assert(def != null, "--type の敵が見つからない")
	var view := run.state.view_rect()
	for k in n:
		var pos := Vector2(run.state.rng.randf_range(view.position.x, view.end.x),
			run.state.rng.randf_range(view.position.y, view.end.y))
		run.enemies.spawn(def, pos, {"facing": (run.state.ship_pos - pos).angle()})
	run.combat.rebuild_grid()

## 円の少し先を指すカーソルの入力。中心から DRIVE_RADIUS の円を回る。
func _drive_intent() -> Intent:
	var it := Intent.new()
	var rel := run.state.ship_pos - drive_center
	var ahead := rel.normalized().rotated(0.5) if rel.length() > 1.0 else Vector2.RIGHT
	it.has_cursor = true
	it.cursor = drive_center + ahead * DRIVE_RADIUS
	return it

## 機体の向きの先へジグザグの線を描いて確定する。描けたら true。
func _draw_ahead() -> bool:
	var s := run.state
	if s.phase != RunState.Phase.PLAY or s.drawing or s.tracing or s.gauge_amount() < run.cfg.draw_min_charge:
		return false
	var p := s.ship_pos
	var heading := s.ship_heading if not s.ship_heading.is_zero_approx() else Vector2.RIGHT
	var side := heading.orthogonal()
	var it := Intent.new()
	it.press = true
	it.pen = p + heading * 60.0
	run.draw._start(it)
	for k in range(1, 7):
		run.draw._extend(p + heading * (60.0 + 220.0 * k) + side * (160.0 if k % 2 else -160.0))
	run.draw._commit(it)
	return true

func _hold_level() -> void:
	if run != null and run.state != null:
		# 結晶の生成・回収・描画を保ち、取得側の倍率だけで成長を止める。
		run.state.stats.xp_gain_mult = 0.0
		run.state.pending_levels = 0
		run.state.pending_comet_weapons.clear()

## 同じ弾の位置で旧方式と格子方式を交互に測る。ランの状態は変更しない。
func _benchmark_bodies() -> Dictionary:
	var old_ms: Array[float] = []
	var grid_ms: Array[float] = []
	for sample in 20:
		for mode in 2:
			var start := Time.get_ticks_usec()
			var hostile_alive := run.projectiles.hostile_alive
			var hostile_pos := run.projectiles.hostile_pos
			var hostile_vel := run.projectiles.hostile_vel
			var hostile_r := run.projectiles.hostile_r
			for i in hostile_alive.size():
				if hostile_alive[i] == 0:
					continue
				var from := hostile_pos[i] - hostile_vel[i] / 120.0
				if (sample + mode) % 2 == 0:
					_old_body_hit(from, hostile_pos[i], hostile_r[i])
				else:
					run.field.first_body_hit(from, hostile_pos[i], hostile_r[i])
			var elapsed := (Time.get_ticks_usec() - start) / 1000.0
			if (sample + mode) % 2 == 0:
				old_ms.append(elapsed)
			else:
				grid_ms.append(elapsed)
	return {"bullets": run.projectiles.hostile_count(), "old_ms": _stats(old_ms), "grid_ms": _stats(grid_ms)}

func _old_body_hit(p0: Vector2, p1: Vector2, radius: float) -> Variant:
	var found = null
	var earliest := INF
	for b: FieldSystem.Body in run.field.bodies:
		var rr := b.r + radius
		if maxf(p0.x, p1.x) < b.pos.x - rr or minf(p0.x, p1.x) > b.pos.x + rr \
				or maxf(p0.y, p1.y) < b.pos.y - rr or minf(p0.y, p1.y) > b.pos.y + rr:
			continue
		var t := Geom.seg_circle_t(p0, p1, b.pos, rr)
		if t >= 0.0 and t < earliest:
			earliest = t
			found = {"body": b, "t": t, "point": p0.lerp(p1, t)}
	return found
