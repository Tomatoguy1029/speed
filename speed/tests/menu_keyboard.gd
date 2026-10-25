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
	SaveManager.data.intro_seen = true
	GameManager.boot_request = Callable()
	GameManager.screen = GameManager.Screen.TITLE
	GameManager.run_requested.connect(func(_stage, _endless): requests += 1)
	app = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	await _frames()
	title = app._current
	map = title._map
	_check(_focus() == title.get_node("%StartButton"), "title starts with visible keyboard focus")
	_tap(KEY_S)
	_check(_focus() == title.get_node("%SettingsButton"), "S navigates title like down")
	_tap(KEY_W)
	_check(_focus() == title.get_node("%StartButton"), "W navigates title like up")
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		var global_navigation := false
		for action in [&"ui_up", &"ui_left", &"ui_down", &"ui_right"]:
			global_navigation = global_navigation or key.is_action(action)
		_check(not global_navigation, "WASD does not alter global UI or gameplay bindings (%d)" % code)
	await _shot("keyboard_title")
	_tap(KEY_DOWN)
	_check(_focus() == title.get_node("%SettingsButton"), "down selects settings")
	_tap(KEY_UP)
	_tap(KEY_SPACE)
	await _frames()
	_check(GameManager.screen == GameManager.Screen.MAIN_MENU and _focus() == title._stage_button, "Space opens mode menu with initial focus")
	_tap(KEY_S)
	_check(_focus().text == "機体強化", "S navigates mode menu like down")
	_tap(KEY_W)
	_check(_focus() == title._stage_button, "W navigates mode menu like up")
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
	_key(KEY_D, true, false, false)
	_tap(KEY_W)
	_tap(KEY_A)
	_tap(KEY_S)
	await _wait(1.4)
	_key(KEY_SPACE, true, true)
	_key(KEY_SPACE, false)
	_key(KEY_ESCAPE, false)
	_key(KEY_RIGHT, false)
	_key(KEY_D, true, true)
	_key(KEY_D, false)
	_check(GameManager.screen == GameManager.Screen.STAGE_SELECT and requests == 0 and map._selected == 0, "transition discards accept, cancel and navigation begun during animation")
	_check(_focus() == map._stars[0], "stage map focuses current selection")
	await _test_horizontal_navigation()
	_tap(KEY_RIGHT)
	_check(map._selected == 3 and _focus() == map._stars[3], "right selects and focuses stage 4 on the right")
	_key(KEY_RIGHT, true, true)
	_key(KEY_RIGHT, false)
	_check(map._selected == 3, "navigation echo cannot skip stages")
	_key(KEY_D, true, true)
	_key(KEY_D, false)
	_check(map._selected == 3, "WASD navigation echo cannot skip stages")
	_tap(KEY_SPACE)
	_check(requests == 0, "accept during selection animation cannot launch")
	await _wait(0.75)
	await _shot("keyboard_stage_4")
	_tap(KEY_DOWN)
	_check(map._selected == 4, "down selects stage 5 in stage order")
	_tap(KEY_UP)
	_check(map._selected == 3, "up returns to stage 4 in stage order")
	_tap(KEY_S)
	_check(map._selected == 4, "S selects stage 5 like down")
	_tap(KEY_W)
	_check(map._selected == 3, "W selects stage 4 like up")
	_tap(KEY_S)
	_check(map._selected == 4 and _focus() == map._final_stage, "S reaches final stage with matching focus")
	await _wait(0.75)
	await _shot("keyboard_stage_5")
	# Space はテキスト・SpinBox の数値欄を編集する入力として残す。
	var edit := LineEdit.new()
	edit.size = Vector2(120, 30)
	map.add_child(edit)
	edit.grab_focus()
	_tap(KEY_SPACE)
	_check(edit.text == " " and requests == 0, "Space edits text without launching")
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]: _tap(code)
	_key(KEY_W, true, true)
	_key(KEY_W, false)
	_check(edit.text == " wasdw" and map._selected == 4 and _focus() == edit, "WASD and text repeat edit text without navigating")
	edit.queue_free()
	var spin := SpinBox.new()
	map.add_child(spin)
	spin.get_line_edit().grab_focus()
	_tap(KEY_SPACE)
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]: _tap(code)
	_check(requests == 0, "numeric input does not launch")
	_check(map._selected == 4 and _focus() == spin.get_line_edit(), "WASD leaves numeric input focus and stage selection alone")
	spin.queue_free()
	var multiline := TextEdit.new()
	multiline.size = Vector2(180, 80)
	title.add_child(multiline)
	multiline.grab_focus()
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]: _tap(code)
	_check(multiline.text == "wasd" and map._selected == 4, "WASD edits multiline text in the window viewport without navigating")
	multiline.queue_free()
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
	_key(KEY_D, true, false, false)
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
		_key(KEY_D, true, true, false)
		_key(KEY_D, false, false, false)
		_check(not app._fade._discard.has("key:0:%d" % KEY_D) and not app._fade._discard.has("key:0:%d" % KEY_RIGHT), "held WASD clears without a synthetic arrow remaining after transition")
		_check(run.state.start_pick and run.state.weapons.is_empty(), "held launch keys cannot choose starting weapon")
		await _shot("keyboard_launch")
	app.queue_free()
	await _frames()
	print("[menu-keyboard] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _test_horizontal_navigation() -> void:
	# 各ステージの回転後と、次の回転途中に、実際に描かれた中心座標で方向を確認する。
	for stage in 5:
		for direction in [-1, 1]:
			map.select_constellation(stage)
			await _wait(0.7)
			_check_horizontal(direction, "stage %d settled" % (stage + 1))
			await _wait(0.2)
			_check_horizontal(-direction, "stage %d during rotation" % (stage + 1))
			await _wait(0.7)
	# 左端・右端からのラップも、円周の各向きで確認する。
	for rotation_stage in 4:
		map.select_constellation(rotation_stage)
		await _wait(0.7)
		for direction in [-1, 1]:
			if map._turn != null: map._turn.kill()
			map._apply_rotation(-90.0 * rotation_stage)
			var points := _stage_centers()
			var edge := 0
			for i in points.size():
				if points[i] * direction > points[edge] * direction: edge = i
			map._select(edge)
			map._focus_selected()
			_check_horizontal(direction, "rotation %d wrap" % rotation_stage)
	map.select_constellation(0)
	await _wait(0.7)
	await _shot("keyboard_direction_initial")

func _stage_centers() -> Array[float]:
	var points: Array[float] = []
	for button in map._stars:
		points.append(button.get_global_rect().get_center().x)
	points.append(map._final_stage.get_global_rect().get_center().x)
	return points

func _check_horizontal(direction: int, label: String) -> void:
	var points := _stage_centers()
	var from: int = map._selected
	var angle: float = map._angle
	var has_neighbor := false
	for x in points:
		if (x - points[from]) * direction > 0.5: has_neighbor = true
	_tap(KEY_LEFT if direction < 0 else KEY_RIGHT)
	var selected: int = map._selected
	var arrow_focus := _focus()
	var correct := selected != from
	if has_neighbor:
		correct = correct and (points[selected] - points[from]) * direction > 0.5
	else:
		for x in points:
			correct = correct and points[selected] * direction <= x * direction + 0.5
	_check(correct, "%s: %s selects screen-side neighbor or opposite edge" % [label, "left" if direction < 0 else "right"])
	# 同じ描画状態から WASD を送り、矢印と同じ対象・フォーカスになることを確認する。
	map._turn.kill()
	map._select(from)
	map._apply_rotation(angle)
	map._focus_selected()
	_tap(KEY_A if direction < 0 else KEY_D)
	_check(map._selected == selected and _focus() == arrow_focus, "%s: A/D chooses the same visible target as arrows" % label)
	print("[menu-direction] %s key=%d from=%d to=%d centers=%s" % [label, direction, from + 1, selected + 1, points])

func _focus() -> Control:
	return title._stage_button.get_viewport().gui_get_focus_owner()

func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _key(code: Key, down: bool, echo := false, physical := true) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code if physical else 0
	if code == KEY_SPACE: ev.unicode = 32
	elif code >= KEY_A and code <= KEY_Z: ev.unicode = code + 32
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
