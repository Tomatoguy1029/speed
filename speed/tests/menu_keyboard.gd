## メニューから出撃まで、実際の Viewport へキーとポインターを送って確認する。
extends "res://tests/thrill_acceptance.gd"

var app: Node
var title: Control
var map: Control
var requests := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): shots = arg.trim_prefix("--out=")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings_copy
	SaveManager.data = SaveManager.default_data()
	GameManager.boot_request = Callable()
	GameManager.screen = GameManager.Screen.TITLE
	GameManager.run_requested.connect(func(_stage, _endless): requests += 1)
	app = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	await _frames()
	title = app._current
	map = title._map
	_check(_focus() == title.get_node("%StartButton"), "title starts with visible keyboard focus")
	await _shot("keyboard_title")
	_tap(KEY_DOWN)
	_check(_focus() == title.get_node("%SettingsButton"), "down selects settings")
	_tap(KEY_UP)
	_tap(KEY_SPACE)
	await _frames()
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU and _focus() == title._stage_button, "Space opens mode menu with initial focus")
	_key(KEY_SPACE, true, true)
	_key(KEY_SPACE, false)
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU, "accept echo and release do not advance another menu")
	_tap(KEY_DOWN)
	_check(_focus().text == "機体強化", "down selects next menu mode")
	_tap(KEY_UP)
	await _shot("keyboard_modes")
	_tap(KEY_SPACE)
	_key(KEY_SPACE, true)
	_key(KEY_ESCAPE, true)
	_key(KEY_RIGHT, true)
	await _wait(1.4)
	_key(KEY_SPACE, true, true)
	_key(KEY_SPACE, false)
	_key(KEY_ESCAPE, false)
	_key(KEY_RIGHT, false)
	_check(GameManager.screen == GameManager.Screen.STAGE_SELECT and requests == 0 and map._selected == 0, "transition discards accept, cancel and navigation begun during animation")
	_check(_focus() == map._stars[0], "stage map focuses current selection")
	_tap(KEY_RIGHT)
	_check(map._selected == 1 and _focus() == map._stars[1], "right selects and focuses stage 2")
	_key(KEY_RIGHT, true, true)
	_key(KEY_RIGHT, false)
	_check(map._selected == 1, "navigation echo cannot skip stages")
	_tap(KEY_SPACE)
	_check(requests == 0, "accept during selection animation cannot launch")
	await _wait(0.75)
	await _shot("keyboard_stage_2")
	_tap(KEY_DOWN)
	_check(map._selected == 2, "down selects stage 3")
	_tap(KEY_UP)
	_check(map._selected == 1, "up returns to stage 2")
	_tap(KEY_LEFT)
	_tap(KEY_LEFT)
	_check(map._selected == 4 and _focus() == map._final_stage, "left reaches final stage with matching focus")
	await _wait(0.75)
	await _shot("keyboard_stage_5")
	# Space はテキスト・SpinBox の数値欄を編集する入力として残す。
	var edit := LineEdit.new()
	edit.size = Vector2(120, 30)
	map.add_child(edit)
	edit.grab_focus()
	_tap(KEY_SPACE)
	_check(edit.text == " " and requests == 0, "Space edits text without launching")
	edit.queue_free()
	var spin := SpinBox.new()
	map.add_child(spin)
	spin.get_line_edit().grab_focus()
	_tap(KEY_SPACE)
	_check(requests == 0, "numeric input does not launch")
	spin.queue_free()
	# マウスで星座を選んだ後も、矢印による選択を続けられる。
	await _frames()
	_click_map(map._stars[0].get_rect().get_center())
	await _wait(0.75)
	_check(map._selected == 0, "mouse can select a constellation after keyboard navigation")
	_touch_sub(map._stars[1].get_global_rect().get_center())
	await _wait(0.75)
	_check(map._selected == 1 and requests == 0, "touch still selects a constellation without launching")
	_tap(KEY_LEFT)
	await _wait(0.75)
	_tap(KEY_RIGHT)
	await _wait(0.75)
	_check(map._selected == 1 and _focus() == map._stars[1], "keyboard resumes after mouse selection")
	# Tab のフォーカスでも、画面の選択と決定対象を一致させる。
	_tap(KEY_TAB)
	await _wait(0.75)
	_check(map._selected == 2 and _focus() == map._stars[2], "Tab focus and selected stage stay aligned")
	map._back.grab_focus()
	_tap(KEY_SPACE)
	await _wait(1.7)
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU and _focus() == title._stage_button, "Space on back returns to modes")
	_tap(KEY_ENTER)
	await _wait(1.4)
	_tap(KEY_ESCAPE)
	_key(KEY_ESCAPE, true, true)
	await _wait(1.7)
	_key(KEY_ESCAPE, false)
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU, "Esc echo cannot cross back transition")
	# メニューへのマウス操作も引き続き使える。
	_click_sub(title._stage_button.get_global_rect().get_center())
	await _wait(1.4)
	_check(GameManager.screen == GameManager.Screen.STAGE_SELECT, "mouse opens stage map")
	_tap(KEY_LEFT)
	await _wait(0.75)
	var stage: int = map._selected + 1
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, true, true)
	_key(KEY_ENTER, true)
	var deadline := Time.get_ticks_usec() + 10_000_000
	while Time.get_ticks_usec() < deadline:
		if app._current is RunSession and app._current.sim.state != null and not GameManager.screen_transition_active:
			break
		await get_tree().process_frame
	_check(requests == 1 and GameManager.run_stage == stage, "Space launches the selected stage exactly once")
	# フェード中からの押下を初期武器選択へ持ち越さない。
	scene = app._current as RunSession
	_check(scene != null, "launch creates a run session")
	if scene != null:
		scene.auto_step = false
		run = scene.sim
		_key(KEY_SPACE, true, true)
		_key(KEY_SPACE, false)
		_key(KEY_ENTER, false)
		_check(run.state.start_pick and run.state.weapons.is_empty(), "held launch keys cannot choose starting weapon")
		await _shot("keyboard_launch")
	app.queue_free()
	await _frames()
	print("[menu-keyboard] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _focus() -> Control:
	return title._stage_button.get_viewport().gui_get_focus_owner()

func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _key(code: Key, down: bool, echo := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	if code == KEY_SPACE: ev.unicode = 32
	ev.pressed = down
	ev.echo = echo
	get_viewport().push_input(ev, true)

func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)

func _click_map(point: Vector2) -> void:
	_click_sub(map.get_global_transform_with_canvas() * point)

func _click_sub(point: Vector2, touch := false) -> void:
	# メニューは半解像度 SubViewport 内に描く。実ウィンドウ座標で送る。
	var window_point: Vector2 = title._art.get_global_transform_with_canvas() * (point * 2.0)
	var move := InputEventMouseMotion.new()
	move.position = window_point
	move.global_position = window_point
	get_viewport().push_input(move, true)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.device = -1 if touch else 0
		ev.position = window_point
		ev.global_position = window_point
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		ev.pressed = down
		get_viewport().push_input(ev, true)
		if touch:
			var original := InputEventScreenTouch.new()
			original.position = window_point
			original.pressed = down
			get_viewport().push_input(original, true)

func _touch_sub(point: Vector2) -> void:
	_click_sub(point, true)
