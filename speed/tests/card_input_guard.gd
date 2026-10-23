## カードの0.3秒ガードを実際のGUI入力経路で短時間確認する。
## Godot --headless --path speed res://tests/card_input_guard.tscn
extends "res://tests/thrill_acceptance.gd"

var hud: Control
var point := Vector2.ZERO

func _ready() -> void:
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings_copy
	await _start(1)
	run.input.set_process_unhandled_input(true)
	hud = scene.view.get_node("Hud/HudRoot")
	await _open()
	_check(hud._cards_box.visible, "selection appears immediately")
	_click_card()
	_check(run.state.phase == RunState.Phase.LEVELUP, "immediate click cannot choose")
	await _open()
	_mouse(true)
	await _wait_real()
	_mouse(false)
	_check(run.state.phase == RunState.Phase.LEVELUP, "blocked press cannot choose on late release")
	_click_card()
	_check(run.state.phase == RunState.Phase.PLAY, "new click after delay can choose")
	_check(not run.input.poll().press, "card click does not leak into gameplay")
	await _open(2)
	_key(KEY_1, true)
	await _wait_real()
	_key(KEY_1, true, true)
	_key(KEY_1, false)
	_check(run.state.pending_levels == 2, "blocked hotkey hold and echo cannot choose")
	_key(KEY_1, true)
	_check(run.state.pending_levels == 1, "fresh hotkey can choose one queued level")
	await _wait_real()
	_key(KEY_1, true, true)
	_check(run.state.pending_levels == 1, "held valid hotkey cannot choose next level")
	_key(KEY_1, false)
	_key(KEY_1, true)
	_key(KEY_1, false)
	_check(run.state.phase == RunState.Phase.PLAY, "fresh hotkey can choose next level")
	await _open()
	_key(KEY_ENTER, true)
	Engine.time_scale = 0.0
	await _wait_real()
	_key(KEY_ENTER, false)
	_check(run.state.phase == RunState.Phase.LEVELUP, "ui_accept begun during lock remains rejected at time scale zero")
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	_check(run.state.phase == RunState.Phase.PLAY, "monotonic deadline expires at time scale zero")
	Engine.time_scale = 1.0
	await _open()
	run.state.rerolls_left = 3
	var before := run.state.rerolls_left
	_key(KEY_R, true)
	_key(KEY_R, false)
	_check(run.state.rerolls_left == before, "immediate reroll is guarded")
	await _wait_real()
	_key(KEY_R, true)
	_key(KEY_R, false)
	_check(run.state.rerolls_left == before - 1, "fresh reroll works after delay")
	_click_card()
	_check(run.state.phase == RunState.Phase.LEVELUP, "rerolled cards restart input guard")
	# 本番の割り当てを増やさず、決定へ割り当てた場合だけを確認する。
	var joy_binding := InputEventJoypadButton.new()
	joy_binding.button_index = JOY_BUTTON_A
	InputMap.action_add_event(&"ui_accept", joy_binding)
	await _open()
	_joy(true)
	await _wait_real()
	_joy(false)
	_check(run.state.phase == RunState.Phase.LEVELUP, "blocked gamepad accept release cannot choose")
	_joy(true)
	_joy(false)
	_check(run.state.phase == RunState.Phase.PLAY, "fresh gamepad accept can choose")
	InputMap.action_erase_event(&"ui_accept", joy_binding)
	await _open()
	_touch(true)
	await _wait_real()
	_touch(false)
	_check(run.state.phase == RunState.Phase.LEVELUP, "blocked touch and emulated mouse release cannot choose")
	_touch(true)
	_touch(false)
	_check(run.state.phase == RunState.Phase.PLAY, "fresh touch with emulated mouse chooses once")
	_check(not run.input.poll().press and run.input._stick_index == -1, "touch sequence does not leak into gameplay")

	# 開く前の押下を、遅い release や再開後の移動へ持ち越さない。
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(20, 300)
	get_viewport().push_input(touch, true)
	_mouse(true)
	await _open()
	await _wait_real()
	touch.pressed = false
	get_viewport().push_input(touch, true)
	_mouse(false)
	_check(run.state.phase == RunState.Phase.LEVELUP, "press before opening cannot choose on late release")
	_click_card()
	var intent := run.input.poll()
	_check(not intent.press and not intent.stick_active, "preexisting gameplay gesture is cleared when cards open")
	# マウス由来の擬似タッチと元のマウスの間に期限が来ても同じ押下を破棄する。
	await _open()
	var emulated := InputEventScreenTouch.new()
	emulated.device = -1
	emulated.pressed = true
	emulated.position = point
	get_viewport().push_input(emulated, true)
	hud._cards_accept_at = Time.get_ticks_usec() - 1
	_mouse(true)
	emulated.pressed = false
	get_viewport().push_input(emulated, true)
	_mouse(false)
	_check(run.state.phase == RunState.Phase.LEVELUP, "emulation pair cannot cross the deadline as a new click")
	# 初期武器選択も同じ保護を使う。
	run.state.pending_levels = 0
	run.loadout.reset_loadout()
	run.loadout.open_start_cards()
	await _position_card()
	_click_card()
	_check(run.state.start_pick, "initial weapon choice is guarded")
	await _wait_real()
	_click_card()
	_check(not run.state.start_pick and run.state.weapons.size() == 1, "initial weapon choice works after delay")
	await _close()
	print("[card-input] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _open(levels := 1) -> void:
	run.state.start_pick = false
	run.state.swap_pick = &""
	run.state.pending_levels = levels
	run.set_phase(RunState.Phase.PLAY)
	run.loadout.try_open_cards()
	await _position_card()

func _position_card() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	point = hud._cards_row.get_child(0).get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	get_viewport().push_input(move, true)

func _mouse(down: bool, device := 0) -> void:
	var ev := InputEventMouseButton.new()
	ev.device = device
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	ev.pressed = down
	ev.position = point
	ev.global_position = point
	get_viewport().push_input(ev, true)

func _click_card() -> void:
	_mouse(true)
	_mouse(false)

func _key(code: Key, down: bool, echo := false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	ev.echo = echo
	get_viewport().push_input(ev, true)

func _joy(down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = down
	get_viewport().push_input(ev, true)

func _touch(down: bool) -> void:
	# Godot はタッチ由来のマウス擬似イベントを元のタッチより先に送る。
	_mouse(down, -1)
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = point
	ev.pressed = down
	get_viewport().push_input(ev, true)

func _wait_real() -> void:
	# 入力のガードだけを検証する。乱数で選ばれた装備の報酬演出は別途確認する。
	run.flush_events()
	hud._rewards.cancel()
	var deadline := Time.get_ticks_usec() + 350_000
	while Time.get_ticks_usec() < deadline:
		await get_tree().process_frame
