## 選択待ちに重ねるメニューを実際の Viewport 入力で確認する。セーブはメモリだけで扱う。
extends "res://tests/thrill_acceptance.gd"

var hud: Control
var panel: Control

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			shots = arg.trim_prefix("--out=")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings_copy
	var config := ContentManager.cfg.duplicate() as GameConfig
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	scene = RunManager.create_session(self, {"stage_index": 1, "seed": 42, "config": config}, true)
	scene.auto_step = false
	run = scene.sim
	hud = scene.view.get_node("Hud/HudRoot")
	panel = scene.view.get_node("Hud/DebugPanel")
	await get_tree().process_frame
	await get_tree().process_frame
	var cards := run.state.cards.duplicate(true)
	await _shot("selection")
	for i in 3:
		_tap(KEY_ESCAPE)
		_check(run.state.phase == RunState.Phase.PAUSED and hud._pause_box.visible, "Esc opens pause during initial choice (%d)" % i)
		if i == 0: await _shot("selection_pause")
		_key(KEY_ESCAPE, true, true)
		_check(run.state.phase == RunState.Phase.PAUSED, "Esc echo does not close pause")
		_key(KEY_ESCAPE, false)
		_tap(KEY_ESCAPE)
		_check(run.state.phase == RunState.Phase.LEVELUP and hud._cards_box.visible, "Esc restores initial choice")
	_check(run.state.start_pick and run.state.cards == cards and run.state.weapons.is_empty(), "pause preserves initial candidates and choice state")
	await _ready_cards()
	for i in 3:
		_tap(KEY_P)
		_check(panel.visible and not hud._cards_box.visible, "P opens debug above choice (%d)" % i)
		if i == 0: await _shot("selection_debug")
		_key(KEY_P, true, true)
		_key(KEY_P, false)
		_check(panel.visible, "P echo does not close debug")
		_tap(KEY_1)
		_tap(KEY_R)
		_tap(KEY_SPACE)
		_tap(KEY_Q)
		_click(Vector2(1100, 500))
		_check(run.state.cards == cards and run.state.start_pick, "debug blocks underlying choice and reroll")
		var intent := run.input.poll()
		_check(not intent.press and not intent.alt_press and not intent.hero_press, "debug blocks gameplay input")
		_tap(KEY_ESCAPE)
		_check(not panel.visible and run.state.phase == RunState.Phase.LEVELUP and hud._cards_box.visible, "Esc closes debug and restores choice")
	_tap(KEY_ESCAPE)
	_tap(KEY_P)
	_tap(KEY_ESCAPE)
	_check(not panel.visible and hud._pause_box.visible and run.state.phase == RunState.Phase.PAUSED, "Esc closes debug before underlying pause")
	hud._pause_box.get_child(2).pressed.emit()
	# 設定のキー割り当てには、メニューのショートカットを割り込ませない。
	hud._settings._wait_for_key(&"debug_perf")
	_tap(KEY_P)
	_check(not panel.visible and InputActions.key_of(&"debug_perf") == KEY_P, "settings can bind the debug menu key")
	SaveManager.set_binding(&"debug_perf", KEY_F3)
	_tap(KEY_ESCAPE)
	_check(hud._settings == null and hud._pause_box.visible, "Esc closes settings before pause")
	_tap(KEY_ESCAPE)
	_check(run.state.phase == RunState.Phase.LEVELUP, "Esc after settings restores selection")
	# 報酬中にも開き、閉じるまで演出も選択も進めない。
	hud._rewards.enqueue_bonus({"type": &"level_bonus", "kind": &"weapon", "id": &"W01", "level": 2, "count": 1})
	_tap(KEY_P)
	_check(panel.visible, "debug opens during reward presentation")
	var elapsed: float = hud._rewards._elapsed
	await get_tree().process_frame
	await get_tree().process_frame
	_tap(KEY_ENTER)
	_check(hud._rewards.is_active() and hud._rewards._elapsed == elapsed, "debug suspends reward presentation and accept")
	_tap(KEY_P)
	_check(not panel.visible and hud._rewards.visible, "P restores reward presentation")
	_tap(KEY_ESCAPE)
	_check(hud._pause_box.visible, "pause opens during reward presentation")
	_tap(KEY_ESCAPE)
	_check(hud._rewards.visible and run.state.phase == RunState.Phase.LEVELUP, "pause restores reward and selection phase")
	hud._rewards.cancel()
	await _ready_cards()
	# 資源待ちで既に選んだカードは、メニュー中に準備が終わっても確定を保留する。
	var scope: ContentResourceScope = run.loadout.resources_for_card(run.state.cards[0].id)
	scope.warmup_complete = false
	run.command(&"choose_card", {"index": 0})
	_tap(KEY_P)
	scope.warmup_complete = true
	run.physics_step(0.1)
	_check(run.state.start_pick and run.state.cards == cards, "debug suspends resource pending choice")
	_tap(KEY_P)
	_tap(KEY_ESCAPE)
	run.physics_step(0.1)
	_check(run.state.start_pick, "pause suspends resource pending choice")
	_tap(KEY_ESCAPE)
	await _settle_choice()
	_check(not run.state.start_pick and run.state.phase == RunState.Phase.PLAY, "pending choice completes after menu closes")
	run.loadout.reset_loadout()
	run.loadout.open_start_cards()
	await _ready_cards()
	# メニュー中から押したままの決定を、閉じた後のカードへ渡さない。
	_tap(KEY_P)
	_key(KEY_ENTER, true)
	_tap(KEY_P)
	await _ready_cards()
	_key(KEY_ENTER, false)
	_check(run.state.start_pick, "menu accept release cannot choose underlying card")
	_tap(KEY_1)
	await _settle_choice()
	_check(run.state.phase == RunState.Phase.PLAY and not run.state.start_pick, "fresh choice still works after menus")
	run.state.pending_levels = 2
	run.loadout.try_open_cards()
	cards = run.state.cards.duplicate(true)
	_tap(KEY_ESCAPE)
	hud._pause_box.get_child(1).pressed.emit()
	_check(run.state.phase == RunState.Phase.LEVELUP and run.state.pending_levels == 2 and run.state.cards == cards, "resume button restores queued level choices")
	# 実際のカード領域へのクリックも隠れたカードを確定しない。
	var point: Vector2 = hud._cards_row.get_child(2).get_global_rect().get_center()
	_tap(KEY_P)
	_click(point)
	_check(run.state.pending_levels == 2 and run.state.cards == cards, "debug shields card pointer area")
	_tap(KEY_P)
	# ゲーム中のデバッグ表示も閉じるまで時計を停止し、背後の入力を残さない。
	run.state.pending_levels = 0
	run.cfg.weapon_slots = 1
	run.loadout._receive_comet_weapon(&"W17")
	var swap := run.state.swap_pick
	cards = run.state.cards.duplicate(true)
	_tap(KEY_ESCAPE)
	_tap(KEY_ESCAPE)
	_tap(KEY_P)
	_tap(KEY_ESCAPE)
	_check(swap == &"W17" and run.state.swap_pick == swap and run.state.cards == cards and hud._swap_box.visible, "menus preserve weapon swap choice")
	run.set_phase(RunState.Phase.PLAY)
	_tap(KEY_P)
	var before := run.state.time
	run.physics_step(1.0)
	_check(run.state.time == before, "debug suspends gameplay clock")
	_tap(KEY_P)
	_check(run.state.phase == RunState.Phase.PLAY and not panel.visible, "debug close preserves gameplay phase")
	await _close()
	print("[selection_menus] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _ready_cards() -> void:
	var deadline := Time.get_ticks_usec() + 350_000
	while Time.get_ticks_usec() < deadline:
		await get_tree().process_frame

func _settle_choice() -> void:
	for i in 8:
		await get_tree().process_frame
		run.physics_step(0.0)

func _key(code: Key, down: bool, echo := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	ev.echo = echo
	get_viewport().push_input(ev, true)

func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)

func _click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point
	get_viewport().push_input(move, true)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = point
		ev.global_position = point
		ev.pressed = down
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		get_viewport().push_input(ev, true)
