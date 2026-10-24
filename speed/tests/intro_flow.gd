## 導入の最小確認。既存のセーブと設定は書き込まない。
extends Node

class MemorySave:
	extends "res://scripts/managers/save_manager.gd"
	var writes := 0
	func save() -> void:
		writes += 1
		save_changed.emit()
	func _save_settings() -> void:
		pass

var failed := 0
var shots := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			shots = arg.trim_prefix("--out=")
	if OS.get_cmdline_user_args().has("--persist-write") or OS.get_cmdline_user_args().has("--persist-read"):
		await _test_persistence()
		return
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings
	TranslationServer.set_locale("ja")
	var old := {"version": 1, "coins": 321, "cleared_stage": 3, "meta": {"attack": 2}, "legendary": ["legendary_stern"], "encyclopedia": ["W01"], "best": {"runs": 7, "clears": 3, "fastest_clear": 120.0, "top_speed": 2400.0}, "endless_high_score": 42}
	SaveManager.data = SaveManager._migrate(JSON.parse_string(JSON.stringify(old)), SaveManager.default_data())
	_check(not SaveManager.has_seen_intro(), "既存セーブの不足フラグを初期化")
	for key in old:
		_check(JSON.parse_string(JSON.stringify(SaveManager.data[key])) == JSON.parse_string(JSON.stringify(old[key])), "既存セーブを保持: " + key)
	_test_save_migration()
	GameManager.boot_request = Callable()
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	app.set_meta("skip_stage_launch", true)
	add_child(app)
	await get_tree().process_frame
	_check(app._current.find_child("ReplayIntroButton", true, false).is_visible_in_tree() == false, "タイトルには再生ボタンを出さない")
	app._current.get_node("%StartButton").pressed.emit()
	await get_tree().process_frame
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU, "ゲームスタート後のメニューを保持")
	_check(app._current.find_child("ReplayIntroButton", true, false).is_visible_in_tree(), "メニュー端に再生ボタン")
	await _shot("menu")
	GameManager.goto(GameManager.Screen.STAGE_SELECT)
	await get_tree().process_frame
	_check(GameManager.screen == GameManager.Screen.INTRO, "初回の選択前に導入")
	_check(app._current.get("visual") != null and app._current.get("_hud") != null, "映像と操作 UI の初期化")
	if failed:
		get_tree().quit(1)
		return
	var cancelled_id: int = app._current.session.id
	app._current._pause()
	app._current._hud.get_node("Pause").get_child(0).get_child(1).pressed.emit()
	await get_tree().process_frame
	_check(RunManager.session(cancelled_id) == null, "途中離脱で専用セッションを解放")
	_check(not SaveManager.has_seen_intro(), "途中で戻っても未視聴")
	GameManager.goto(GameManager.Screen.STAGE_SELECT)
	await get_tree().process_frame
	await _test_practice(app._current)
	_check(GameManager.screen == GameManager.Screen.STAGE_SELECT and SaveManager.has_seen_intro(), "初回の練習完了後は選択と視聴済み")
	_check(SaveManager.writes == 1, "独立フラグを一度保存")
	GameManager.back()
	await get_tree().process_frame
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU, "選択から戻るとメニュー")
	GameManager.goto(GameManager.Screen.STAGE_SELECT)
	await get_tree().process_frame
	_check(GameManager.screen == GameManager.Screen.STAGE_SELECT, "2回目は導入を挟まない")
	GameManager.back()
	await get_tree().process_frame
	app._current.find_child("ReplayIntroButton", true, false).pressed.emit()
	await get_tree().process_frame
	_check(GameManager.screen == GameManager.Screen.INTRO, "メニューから同じ導入を再生")
	_check(app._current.get("run") != null, "再生は本番操作を使う練習を持つ")
	var replay_id: int = app._current.session.id
	GameManager.replay_intro()
	_check(app._current.session.id == replay_id, "再生の重複要求を無視")
	var pause := InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	app._current._unhandled_input(pause)
	_check(app._current._paused, "キャンセル入力でポーズを開く")
	app._current._unhandled_input(pause)
	_check(not app._current._paused, "同じ入力でポーズから再開")
	GameManager.back()
	await get_tree().process_frame
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU and SaveManager.writes == 1, "再視聴から戻っても保存を増やさない")
	GameManager.replay_intro()
	await get_tree().process_frame
	_check(not app._current.run.state.drawing and not app._current.run.state.tracing and not app._current.run.input._press, "再実行は前の入力を引き継がない")
	app._current.find_child("SkipIntro", true, false).pressed.emit()
	await get_tree().process_frame
	_check(GameManager.screen == GameManager.Screen.STAGE_SELECT and SaveManager.writes == 1, "再生で進行記録を増やさない")
	for key in old:
		_check(JSON.parse_string(JSON.stringify(SaveManager.data[key])) == JSON.parse_string(JSON.stringify(old[key])), "導入後も保持: " + key)
	await _test_run_transitions(app)
	app.queue_free()
	await get_tree().process_frame
	_check(RunManager._sessions.is_empty(), "全ての導入セッションを解放")
	for player: AudioStreamPlayer in AudioManager._players:
		player.stop()
	await get_tree().process_frame
	print("[intro] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	print("[intro] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failed += 1

func _test_practice(intro: Node) -> void:
	intro.set_physics_process(false)
	# 自動キャプチャはウィンドウのフォーカスを要求しない。実際のポーズは下で確認する。
	intro.get_window().focus_exited.disconnect(Callable(intro, "_pause"))
	intro._resume()
	var run: RunSimulation = intro.run
	_check(not intro.session.view.has_node("Hud") and run.state.lab_mode and run.loadout.weapon_behaviors.is_empty(), "練習は通常ランの記録・装備から独立")
	await _shot("flight")
	_elapse(intro, intro.presentation.flight_time)
	_check(intro.practice.enemies.is_empty(), "星だけの間は敵を生成しない")
	_elapse(intro, intro.presentation.transform_time * 0.4)
	await _shot("gather")
	_check(intro.practice.enemies.is_empty(), "瓦礫の集合中も敵を生成しない")
	_elapse(intro, intro.presentation.transform_time * 0.4)
	await _shot("solidify")
	_elapse(intro, intro.presentation.transform_time * 0.18)
	await _shot("transform")
	_elapse(intro, intro.presentation.transform_time * 0.02 + 0.001)
	_elapse(intro, intro.presentation.handoff_time)
	_check(intro.beat == intro.Beat.PRACTICE, "同じ World から本番操作へ移る")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	intro._input(touch)
	intro._draw_button.pressed.emit()
	_check(run.input._alt_press and intro._draw_button.visible, "タッチ用の描くボタンは既存の入力へ接続")
	run.input.cancel_gesture()
	intro._touch = false
	intro._draw_button.hide()
	intro._pause()
	var time: float = intro.beat_time
	_elapse(intro, 1.0)
	_check(intro.beat_time == time and run.state.phase == RunState.Phase.PAUSED, "ポーズ中は映像と練習を停止")
	intro._resume()
	_check(intro.practice.enemies.size() == 4, "練習相手を複数体配置")
	var guide: PackedVector2Array = intro.practice.guide_points.duplicate()
	_check(guide.size() > 4 and guide[8].y != guide[16].y, "敵の中心を曲がって通る見本線")
	_check(not intro.session.is_in_group("recordable_runs") and RunManager.current_id == -1 and not run.state.stage.boss_enabled, "導入は録画・通常ラン・ボス進行から独立")
	await _shot("practice_guide")
	_mouse_at(run.input, guide[0], true)
	_elapse(intro, 1.0 / 120.0)
	_check(run.state.drawing, "マウス入力を既存ルーターで読み描画を開始")
	# GUI が受け取ったクリックの残りを、再開後の突進に持ち込まない。
	run.input._press = true
	intro._pause()
	_check(not run.input._press and run.state.drawing, "描画中のポーズで未処理の押下を取り消す")
	intro._resume()
	for point in guide:
		_mouse_at(run.input, point)
		_elapse(intro, 1.0 / 60.0)
	intro._update_hint()
	await _shot("practice")
	_mouse_at(run.input, guide[-1], true)
	_elapse(intro, 1.0 / 120.0)
	_check(run.state.tracing, "再クリックで本番の突進を開始")
	for i in 360:
		_elapse(intro, 1.0 / 120.0)
		run.flush_events()
		if intro.beat == intro.Beat.RESTORE:
			break
	_check(intro.beat == intro.Beat.RESTORE, "突進で倒したら星の復帰へ進む")
	_elapse(intro, intro.presentation.restore_time * 0.5)
	await _shot("restore")
	_elapse(intro, intro.presentation.restore_time * 0.5)
	_elapse(intro, intro.presentation.omen_time * 0.25)
	await _shot("omen_gather")
	_elapse(intro, intro.presentation.omen_time * 0.50)
	await _shot("omen")
	_elapse(intro, intro.presentation.omen_time * 0.25)
	_check(intro.beat == intro.Beat.MOTIVE and intro._motive.text == "何か異変が起きている。あの星々も救わねば。", "一角獣の異変から合意した台詞へ")
	var sky_bounds: Rect2 = intro.sky.omen_rect()
	var half: Vector2 = run.state.view_half
	_check(sky_bounds.size.y <= half.y * 0.45 and sky_bounds.end.y < run.state.view_center.y - half.y * 0.2, "一角獣座は上空の小さな遠景")
	_check(intro.sky.z_index < 2 and intro.visual.z_index > intro.sky.z_index, "遠い星座は敵・機体・近景より奥")
	await _shot("motive")
	var app: Node = intro.get_parent()
	_elapse(intro, intro.presentation.motive_time)
	await get_tree().process_frame
	_check(GameManager.screen == GameManager.Screen.STAGE_SELECT, "最後は自動でステージ選択へ")
	var map_screen: Node = app._current
	if map_screen._transition != null and map_screen._transition.is_running():
		await map_screen._transition.finished
	_check(map_screen._map.visible and map_screen._map.process_mode == Node.PROCESS_MODE_INHERIT, "ステージ選択の演出後に操作を受け付ける")
	if map_screen._map._detail_fade != null and map_screen._map._detail_fade.is_running():
		await map_screen._map._detail_fade.finished
	_check(map_screen._map._details.modulate.a > 0.99, "ステージ情報と出撃ボタンを表示")
	await _shot("stage_select")

func _shot(label: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(label + ".png"))

func _elapse(intro: Node, seconds: float) -> void:
	intro._physics_process(seconds)
	var renderer: RunPresentation = intro.session.view.get_node("RunPresentation")
	renderer._process(seconds)

## 実ファイルを使う再起動確認は、HOME を /tmp 配下へ分離したプロセスだけで実行する。
func _test_persistence() -> void:
	var folder := OS.get_user_data_dir()
	if not (folder.begins_with("/tmp/") or folder.begins_with("/private/tmp/")):
		push_error("intro persistence: isolated HOME under /tmp is required")
		get_tree().quit(1)
		return
	GameManager.boot_request = Callable()
	var writing := OS.get_cmdline_user_args().has("--persist-write")
	_check(SaveManager.has_seen_intro() == not writing, "別プロセスで初回フラグを読み込む")
	if writing:
		var legacy := SaveManager.default_data()
		legacy.erase("intro_seen")
		legacy.coins = 321
		legacy.cleared_stage = 3
		legacy.endless_high_score = 42
		legacy.meta = {"attack": 2}
		legacy.best.runs = 7
		var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		file.store_string("[]")
		file.close()
		_check(SaveManager._load_save() == SaveManager.default_data(), "辞書以外の保存内容を初期値で扱う")
		file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(legacy))
		file.close()
		SaveManager.data = SaveManager._load_save()
	_check(SaveManager.coins() == 321 and SaveManager.data.cleared_stage == 3 and SaveManager.data.endless_high_score == 42 and SaveManager.meta_level(&"attack") == 2 and int(SaveManager.data.best.runs) == 7, "実ファイルの JSON 往復で部品・段階・最高点・強化・記録を保持")
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	GameManager.reset_to_main_menu()
	GameManager.goto(GameManager.Screen.STAGE_SELECT)
	await get_tree().process_frame
	_check(GameManager.screen == (GameManager.Screen.INTRO if writing else GameManager.Screen.STAGE_SELECT), "再起動後は初回導入をスキップ")
	if writing:
		app._current.find_child("SkipIntro", true, false).pressed.emit()
		await get_tree().process_frame
		_check(SaveManager.has_seen_intro() and FileAccess.file_exists(SaveManager.SAVE_PATH), "明示スキップで独立保存先へ書く")
	print("[intro persistence] user_dir=%s failed=%d" % [folder, failed])
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

func _mouse_at(router: InputRouter, world: Vector2, click := false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = router.get_canvas_transform() * world
	router._input(motion)
	if click:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		router._unhandled_input(event)

func _test_save_migration() -> void:
	for key in ["coins", "cleared_stage", "endless_high_score"]:
		_check(typeof(SaveManager.data[key]) == TYPE_INT, "JSON の整数型を復元: " + key)
	for value in ["321", true, [], {}, null, NAN, INF, -INF, 1.5, 1.0e30, -1.0e30, 9223372036854775808.0]:
		var migrated: Dictionary = SaveManager._migrate({"coins": value}, SaveManager.default_data())
		_check(migrated.coins == 0 and typeof(migrated.coins) == TYPE_INT, "想定外の整数入力は初期値: " + str(value))
	var migrated: Dictionary = SaveManager._migrate({"intro_seen": 1, "meta": [], "best": [], "legendary": {}}, SaveManager.default_data())
	_check(not migrated.intro_seen and migrated.meta == {} and migrated.best.runs == 0 and migrated.legendary == [], "型違いの項目を初期値で補う")
	migrated = SaveManager._migrate({"best": {"runs": 7}, "unknown": 1}, SaveManager.default_data())
	_check(migrated.best.runs == 7 and migrated.best.clears == 0 and not migrated.has("unknown"), "不足する既存項目を補い、未知のトップレベル項目を除く")

## 初回済みの通常の入口から全ステージへ出撃し、保存せず中止する。
func _test_run_transitions(app: Node) -> void:
	for stage_index in range(1, ContentManager.stage_count() + 1):
		GameManager.goto(GameManager.Screen.STAGE_SELECT)
		await get_tree().process_frame
		var selection: Node = app._current
		if selection._transition != null and selection._transition.is_running():
			await selection._transition.finished
		selection._map._select(stage_index - 1)
		selection._map._launch.pressed.emit()
		var limit := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < limit:
			await get_tree().process_frame
			if app._current is RunSession:
				app._current.auto_step = false
				if app._current.sim.state != null and not GameManager.screen_transition_active:
					break
		var session: RunSession = app._current as RunSession
		_check(session != null and session.sim.state != null, "通常の出撃を初期化: ステージ%d" % stage_index)
		if session == null or session.sim.state == null:
			return
		var id := session.id
		var boss: BossDef = ContentManager.definition(&"bosses", session.sim.state.stage.boss_id)
		if boss != null:
			var actor: Node = (load(boss.scene_path) as PackedScene).instantiate()
			_check(actor is BossActor, "通常ステージのボスシーンを読み込める: ステージ%d" % stage_index)
			actor.free()
		_check(not session.sim.state.lab_mode and session.sim.state.stage_index == stage_index and RunManager.current_id == id and session.view.has_node("Hud"), "通常ランの状態と HUD を接続: ステージ%d" % stage_index)
		await get_tree().process_frame
		RunManager.command(id, &"pause")
		_check(session.sim.state.phase == RunState.Phase.PAUSED, "通常ランをポーズ: ステージ%d" % stage_index)
		RunManager.command(id, &"resume")
		RunManager.command(id, &"abort")
		await get_tree().process_frame
		_check(GameManager.screen == GameManager.Screen.MAIN_MENU and RunManager.session(id) == null and SaveManager.writes == 1, "通常ラン中止でセッションを解放し、導入の保存を増やさない: ステージ%d" % stage_index)
