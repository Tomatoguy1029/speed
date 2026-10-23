## 起動・通常出撃・同一プロセスの再出撃を、実際の画面と描画で短時間計測する。
## godot --path speed --script res://tools/profile_loading.gd -- --stage=1 --attempts=2
## shaderキャッシュのcold/warmは実行側で分ける。セーブと録画は書き込まない。
extends SceneTree

var _options := {"stage": 1, "attempts": 2, "frames": 90}
var _manager: Node
var _runs: Node

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", false, 1)
		if pair.size() == 2 and _options.has(pair[0]): _options[pair[0]] = int(pair[1])
	create_timer(60.0).timeout.connect(func(): push_error("ロード計測が時間内に完了しませんでした"); quit(1))
	_measure.call_deferred()

func _measure() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("ロード計測には描画付きの実行が必要です")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_manager = root.get_node("GameManager")
	_runs = root.get_node("RunManager")
	root.get_node("SaveManager").data = root.get_node("SaveManager").default_data()
	_manager.boot_request = Callable()
	_runs.session_created.connect(func(session): session.sim.options.seed = 1029)
	var main := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await RenderingServer.frame_post_draw
	print("LOAD_BOOT ", JSON.stringify({"first_frame_ms": Time.get_ticks_msec(),
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"window": str(DisplayServer.window_get_size()), "engine": Engine.get_version_info().string,
		"cached_stages": _cached_stages()}))
	_manager.reset_to_main_menu()
	await create_timer(0.7).timeout
	_manager.goto(_manager.Screen.STAGE_SELECT)
	await create_timer(0.7).timeout
	for attempt in maxi(1, _options.attempts):
		var begin := Time.get_ticks_usec()
		if attempt == 0: _manager.start_run(_options.stage)
		else: _manager.retry_run()
		while _runs.current() == null or _runs.current().sim.state == null: await process_frame
		var session = _runs.current()
		var started_us := Time.get_ticks_usec()
		while _manager.screen_transition_active: await process_frame
		await RenderingServer.frame_post_draw
		var result := {"attempt": attempt, "stage": _options.stage,
			"started_ms": (started_us - begin) / 1000.0,
			"interactive_ms": (Time.get_ticks_usec() - begin) / 1000.0,
			"phases": session.loading_timings.duplicate()}
		# 最初のカードを即時要求し、資源の準備待ちと最初の実プレイのフレームも観測する。
		while session.sim.state.cards.is_empty(): await process_frame
		var choice_us := Time.get_ticks_usec()
		session.sim.command(&"choose_card", {"index": 0})
		while session.sim.state.start_pick: await process_frame
		await RenderingServer.frame_post_draw
		result["first_choice_ms"] = (Time.get_ticks_usec() - choice_us) / 1000.0
		var frames := []
		var last_us := Time.get_ticks_usec()
		var compiles := _compilations()
		for frame in maxi(1, _options.frames):
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append((now - last_us) / 1000.0)
			last_us = now
		result["play_frame_max_at"] = frames.find(frames.max())
		frames.sort()
		result["play_frame_p95_ms"] = frames[int((frames.size() - 1) * 0.95)]
		result["play_frame_max_ms"] = frames[-1]
		var after := _compilations()
		for key in compiles: after[key] -= compiles[key]
		result["play_compilations"] = after
		result["cached_stages"] = _cached_stages()
		print("LOAD_RUN ", JSON.stringify(result))
		# 保存処理を通さず結果画面へ移り、実際の「もう一回やる」の入口を使う。
		_manager.last_result = {"stage": _options.stage}
		_manager.goto(_manager.Screen.RESULT, false)
		while _manager.screen_transition_active: await process_frame
		await process_frame
	main.queue_free()
	await process_frame
	await process_frame
	quit()

func _compilations() -> Dictionary:
	return {"canvas": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
		"draw": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		"specialization": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}

func _cached_stages() -> Array:
	var result := []
	for index in 5:
		for path in ["res://data/stages/stage_%d.tres" % (index + 1), "res://.content/stage_%d.tres" % (index + 1)]:
			if ResourceLoader.has_cached(path): result.append(path)
	return result
