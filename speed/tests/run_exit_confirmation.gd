## ラン終了の確認だけを、保存を伴わない Viewport 入力で確認する。
extends "res://tests/selection_menus.gd"

var aborts := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): shots = arg.trim_prefix("--out=")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings_copy
	scene = RunManager.create_session(self, {"stage_index": 1, "seed": 42}, true)
	scene.auto_step = false
	run = scene.sim
	run.aborted.connect(func(): aborts += 1)
	hud = scene.view.get_node("Hud/HudRoot")
	panel = scene.view.get_node("Hud/DebugPanel")
	await get_tree().process_frame
	await get_tree().process_frame
	var cards := run.state.cards.duplicate(true)
	_tap(KEY_ESCAPE)
	var quit: Button = hud._pause_box.get_child(3)
	quit.grab_focus()
	_tap(KEY_SPACE)
	_check(aborts == 0 and run.state.phase == RunState.Phase.PAUSED, "quit button requests confirmation without aborting")
	if hud._menu_overlay == null:
		_check(false, "quit confirmation is visible")
		await _finish_test()
		return
	var dialog: Control = hud._menu_overlay
	_tap(KEY_SPACE)
	_check(hud._menu_overlay == dialog, "opening Space does not carry over into confirmation")
	_key(KEY_SPACE, true)
	await _ready_cards()
	_key(KEY_SPACE, true, true)
	_key(KEY_SPACE, false)
	_check(hud._menu_overlay == dialog and aborts == 0, "blocked Space hold and release cannot dismiss or confirm")
	await _shot("run_exit_confirmation")
	_tap(KEY_1)
	_tap(KEY_R)
	_tap(KEY_Q)
	_tap(KEY_P)
	_check(run.state.cards == cards and run.state.start_pick and not panel.visible, "confirmation blocks selection and debug shortcuts")
	var intent := run.input.poll()
	_check(not intent.press and not intent.alt_press and not intent.hero_press, "confirmation blocks gameplay input")
	_tap(KEY_ESCAPE)
	_check(hud._menu_overlay == null and hud._pause_box.visible and run.state.phase == RunState.Phase.PAUSED, "Esc returns only to pause")
	_key(KEY_ESCAPE, true, true)
	_key(KEY_ESCAPE, false)
	_check(run.state.phase == RunState.Phase.PAUSED, "Esc echo cannot resume underneath")
	for i in 3:
		await get_tree().process_frame
		_click(quit.get_global_rect().get_center())
		dialog = hud._menu_overlay
		_check(dialog != null and aborts == 0, "reopening confirmation is safe (%d)" % i)
		await get_tree().process_frame
		var confirm := dialog.find_child("Confirm", true, false) as Button
		_click(confirm.get_global_rect().get_center())
		_check(hud._menu_overlay == dialog and aborts == 0, "immediate click cannot confirm")
		await _ready_cards()
		var cancel := dialog.find_child("Cancel", true, false) as Button
		_click(cancel.get_global_rect().get_center())
		_check(hud._pause_box.visible and hud._menu_overlay == null and aborts == 0, "cancel returns to pause (%d)" % i)
	await get_tree().process_frame
	_tap(KEY_ESCAPE)
	_check(run.state.phase == RunState.Phase.LEVELUP and run.state.cards == cards and run.state.start_pick, "cancel and resume preserve initial selection")
	hud._rewards.enqueue_bonus({"type": &"level_bonus", "kind": &"weapon", "id": &"W01", "level": 2, "count": 1})
	_tap(KEY_ESCAPE)
	quit.pressed.emit()
	dialog = hud._menu_overlay
	var elapsed: float = hud._rewards._elapsed
	var before := run.state.time
	await _ready_cards()
	run.physics_step(1.0)
	_check(run.state.time == before and hud._rewards._elapsed == elapsed and run.state.phase == RunState.Phase.PAUSED, "confirmation keeps world and reward paused")
	_tap(KEY_ESCAPE)
	await get_tree().process_frame
	_tap(KEY_ESCAPE)
	_check(hud._rewards.visible and run.state.phase == RunState.Phase.LEVELUP and run.state.cards == cards, "reward and selection return after cancelling")
	hud._rewards.cancel()
	run.set_phase(RunState.Phase.PLAY)
	_tap(KEY_ESCAPE)
	quit.pressed.emit()
	await _ready_cards()
	_tap(KEY_SPACE)
	_check(hud._menu_overlay == null and hud._pause_box.visible, "default keyboard focus cancels safely")
	await get_tree().process_frame
	quit.pressed.emit()
	await _ready_cards()
	dialog = hud._menu_overlay
	var confirm := dialog.find_child("Confirm", true, false) as Button
	_click(confirm.get_global_rect().get_center())
	_check(aborts == 1 and run.state.phase == RunState.Phase.ENDED, "confirm invokes existing abort exactly once")
	confirm.pressed.emit()
	_tap(KEY_SPACE)
	_tap(KEY_ESCAPE)
	_check(aborts == 1 and run.state.phase == RunState.Phase.ENDED, "repeat confirm and shortcuts cannot trigger a second transition")
	await _close()
	# 通常起動と同じ接続で、承諾からメインメニューへ到達する。
	GameManager.screen = GameManager.Screen.TITLE
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	GameManager.start_run(1)
	var deadline := Time.get_ticks_usec() + 10_000_000
	while (RunManager.current() == null or RunManager.current().sim.state == null) and Time.get_ticks_usec() < deadline:
		await get_tree().process_frame
	scene = RunManager.current()
	_check(scene != null and scene.sim.state != null, "production run starts")
	if scene == null or scene.sim.state == null:
		app.queue_free()
		print("[run_exit_confirmation] passed=%d failed=%d" % [passed, failed])
		get_tree().quit(1)
		return
	scene.auto_step = false
	run = scene.sim
	hud = scene.view.get_node("Hud/HudRoot")
	await get_tree().process_frame
	_tap(KEY_ESCAPE)
	hud._pause_box.get_child(3).pressed.emit()
	await _ready_cards()
	dialog = hud._menu_overlay
	confirm = dialog.find_child("Confirm", true, false) as Button
	_click(confirm.get_global_rect().get_center())
	await _settle_screen()
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU and RunManager.current() == null, "confirmation returns to main menu through existing transition")
	_check(SaveManager.data.best.runs == 0, "aborted run is not saved")
	app.queue_free()
	await get_tree().process_frame
	print("[run_exit_confirmation] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _finish_test() -> void:
	await _close()
	print("[run_exit_confirmation] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
