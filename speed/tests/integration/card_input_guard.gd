## カードの0.3秒ガードを実際のGUI入力経路で短時間確認する。
## Godot --headless --path speed res://tests/integration/card_input_guard.tscn
extends "res://tests/integration/thrill_acceptance.gd"
const CardPhase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase

var bridge: RefCounted
var router: InputRouter
var baseline := 0

var hud: Control
var point := Vector2.ZERO

func _ready() -> void:
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings_copy
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true
	scene = await _cpp_open(1, false)
	if scene.bridge == null:
		_check(false, "C++の通常ランを開始する")
		await _close()
		get_tree().quit(1)
		return
	bridge = scene.bridge
	router = scene.view.get_node("World/InputRouter")
	hud = scene.view.get_node("Hud/HudRoot")
	# 初期武器も通常出撃の実際の候補と資源準備を通す。
	await _position_card()
	_click_card()
	_check(_ui().cards.initial and _ui().cards.selected_id == 0, "初期武器は表示直後に選べない")
	await _wait_real()
	_click_card()
	await _settle_choice()
	_check(not _ui().cards.initial and _ui().weapon_levels.size() == 1, "待った後は初期武器を一つ取得する")
	var held: Dictionary = bridge.checkpoint()
	_check(held.ok, "同じ成長前の状態を保持する")
	if not held.ok:
		await _close()
		get_tree().quit(1)
		return
	baseline = held.value
	await _open()
	_check(hud._cards_box.visible, "候補は開いた直後から見える")
	_click_card()
	_check(_ui().phase == CardPhase.Levelup and _ui().cards.selected_id == 0, "表示直後のクリックでは選べない")
	await _open()
	_mouse(true)
	await _wait_real()
	_mouse(false)
	_check(_ui().phase == CardPhase.Levelup and _ui().cards.selected_id == 0, "無効な押下を待ってから離しても選べない")
	_click_card()
	await _settle_choice()
	_check(_ui().phase == CardPhase.Play, "待った後の新しいクリックで選べる")
	_check(not router.poll().press, "カードのクリックがゲーム操作へ漏れない")
	await _open(2)
	_key(KEY_1, true)
	await _wait_real()
	_key(KEY_1, true, true)
	_key(KEY_1, false)
	_check(_ui().pending_levels == 2, "無効なキーの長押しとリピートでは選べない")
	_key(KEY_1, true)
	await _settle_choice()
	_check(_ui().pending_levels == 1, "新しいキー押下で未選択レベルを一つ進める")
	await _wait_real()
	_key(KEY_1, true, true)
	_check(_ui().pending_levels == 1, "有効だったキーを押したまま次の候補は選べない")
	_key(KEY_1, false)
	_key(KEY_1, true)
	_key(KEY_1, false)
	await _settle_choice()
	_check(_ui().phase == CardPhase.Play, "押し直すと次の候補を選べる")
	await _open()
	_key(KEY_ENTER, true)
	Engine.time_scale = 0.0
	await _wait_real()
	_key(KEY_ENTER, false)
	_check(_ui().phase == CardPhase.Levelup and _ui().cards.selected_id == 0, "待ち時間中に押した決定キーは時間停止後に離しても選べない")
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	await _settle_choice()
	_check(_ui().phase == CardPhase.Play, "時間停止中も実時間が過ぎれば決定キーで選べる")
	Engine.time_scale = 1.0
	await _open()
	var before: int = _ui().rerolls_left
	_key(KEY_R, true)
	_key(KEY_R, false)
	_check(_ui().rerolls_left == before, "表示直後は引き直せない")
	await _wait_real()
	_key(KEY_R, true)
	_key(KEY_R, false)
	_check(_ui().rerolls_left == before - 1, "待った後の新しい押下で引き直せる")
	_click_card()
	_check(_ui().phase == CardPhase.Levelup and _ui().cards.selected_id == 0, "引き直した候補にも待ち時間がある")
	# 本番の割り当てを増やさず、決定へ割り当てた場合だけを確認する。
	var joy_binding := InputEventJoypadButton.new()
	joy_binding.button_index = JOY_BUTTON_A
	InputMap.action_add_event(&"ui_accept", joy_binding)
	await _open()
	_joy(true)
	await _wait_real()
	_joy(false)
	_check(_ui().phase == CardPhase.Levelup and _ui().cards.selected_id == 0, "無効なゲームパッド決定を後から離しても選べない")
	_joy(true)
	_joy(false)
	await _settle_choice()
	_check(_ui().phase == CardPhase.Play, "ゲームパッドの新しい決定で選べる")
	InputMap.action_erase_event(&"ui_accept", joy_binding)
	await _open()
	_touch(true)
	await _wait_real()
	_touch(false)
	_check(_ui().phase == CardPhase.Levelup and _ui().cards.selected_id == 0, "無効なタッチと擬似マウスを後から離しても選べない")
	_touch(true)
	_touch(false)
	await _settle_choice()
	_check(_ui().phase == CardPhase.Play, "新しいタッチと擬似マウスは一回だけ選ぶ")
	_check(not router.poll().press and router._stick_index == -1, "タッチ操作がゲーム操作へ漏れない")

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
	_check(_ui().phase == CardPhase.Levelup and _ui().cards.selected_id == 0, "開く前の押下を後から離しても選べない")
	_click_card()
	await _settle_choice()
	var intent := router.poll()
	_check(not intent.press and not intent.stick_active, "候補を開くと前の押下とスティック操作を消す")
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
	_check(_ui().phase == CardPhase.Levelup and _ui().cards.selected_id == 0, "擬似タッチと元のマウスの間で期限が来ても新しいクリックにならない")
	bridge.release_checkpoint(baseline)
	await _close()
	print("[カード入力] 成功=%d 失敗=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _ui() -> Dictionary:
	return bridge.read_frame().value.ui

func _step() -> void:
	var result: Dictionary = bridge.step(1.0 / 120.0, bridge.pack_intent(Intent.new()), {"logical_size": get_viewport().get_visible_rect().size})
	_check(result.ok and bridge.delivery_error.get("ok", true), "C++の更新とUIへの配信を完了する")

func _open(levels := 1) -> void:
	_check(bridge.restore(baseline).ok, "成長前の状態へ戻す")
	bridge.collect_frame()
	_check(bridge.command("dev_edit", {"kind": "progression", "payload": {"pending_levels": levels}}).ok, "開発命令で未選択レベル数を設定する")
	_step()
	_check(_ui().phase == CardPhase.Levelup and _ui().pending_levels == levels, "通常の更新でレベルアップ候補を開く")
	await _position_card()

func _settle_choice() -> void:
	# 候補の資源は本番のRunChoiceResourcesに任せ、選択済みの一回だけ進める。
	for i in 4000:
		if _ui().cards.selected_id == 0:
			break
		scene.cpp_choices.poll()
		_step()
		await get_tree().process_frame
	_check(_ui().cards.selected_id == 0, "選択した候補の資源準備と取得が終わる")

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
	bridge.collect_frame()
	hud._rewards.cancel()
	var deadline := Time.get_ticks_usec() + 350_000
	while Time.get_ticks_usec() < deadline:
		await get_tree().process_frame
