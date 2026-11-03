## 選択待ちに重ねるメニューを実際の Viewport 入力で確認する。セーブはメモリだけで扱う。
extends "res://tests/integration/thrill_acceptance.gd"
const MenuIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS

var hud: Control
var panel: Control
var bridge: RefCounted
var router: InputRouter
var _initial_checkpoint := 0
var _held_scopes: Array[ContentResourceScope] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			shots = arg.trim_prefix("--out=")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings_copy
	if not await _open_session():
		get_tree().quit(1)
		return
	var cards := _state().cards.duplicate(true)
	await _shot("selection")
	for i in 3:
		_tap(KEY_ESCAPE)
		_check(_state().phase == MenuIds.Phase.Paused and hud._pause_box.visible, "Esc opens pause during initial choice (%d)" % i)
		if i == 0: await _shot("selection_pause")
		_key(KEY_ESCAPE, true, true)
		_check(_state().phase == MenuIds.Phase.Paused, "Esc echo does not close pause")
		_key(KEY_ESCAPE, false)
		_tap(KEY_ESCAPE)
		_check(_state().phase == MenuIds.Phase.Levelup and hud._cards_box.visible, "Esc restores initial choice")
	_check(_state().start_pick and _state().cards == cards and _state().weapons.is_empty(), "pause preserves initial candidates and choice state")
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
		_check(_state().cards == cards and _state().start_pick, "debug blocks underlying choice and reroll")
		var intent := router.poll()
		_check(not intent.press and not intent.alt_press and not intent.hero_press, "debug blocks gameplay input")
		_tap(KEY_ESCAPE)
		_check(not panel.visible and _state().phase == MenuIds.Phase.Levelup and hud._cards_box.visible, "Esc closes debug and restores choice")
	_tap(KEY_ESCAPE)
	_tap(KEY_P)
	_tap(KEY_ESCAPE)
	_check(not panel.visible and hud._pause_box.visible and _state().phase == MenuIds.Phase.Paused, "Esc closes debug before underlying pause")
	hud._pause_box.get_child(2).pressed.emit()
	# 設定のキー割り当てには、メニューのショートカットを割り込ませない。
	hud._settings._wait_for_key(&"debug_perf")
	_tap(KEY_P)
	_check(not panel.visible and InputActions.key_of(&"debug_perf") == KEY_P, "settings can bind the debug menu key")
	SaveManager.set_binding(&"debug_perf", KEY_F3)
	_tap(KEY_ESCAPE)
	_check(hud._settings == null and hud._pause_box.visible, "Esc closes settings before pause")
	_tap(KEY_ESCAPE)
	_check(_state().phase == MenuIds.Phase.Levelup, "Esc after settings restores selection")
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
	_check(hud._rewards.visible and _state().phase == MenuIds.Phase.Levelup, "pause restores reward and selection phase")
	hud._rewards.cancel()
	await _ready_cards()
	# 資源待ちで既に選んだカードは、メニュー中に準備が終わっても確定を保留する。
	_hold_choice_resources()
	cards = _state().cards.duplicate(true)
	_choose_first()
	_tap(KEY_P)
	for held_scope in _held_scopes:
		held_scope.pending.erase("held://selection")
	scene.cpp_choices.prepare = Callable()
	_step(0.1)
	_check(_state().start_pick and _state().cards == cards, "debug suspends resource pending choice")
	_tap(KEY_P)
	_tap(KEY_ESCAPE)
	_step(0.1)
	_check(_state().start_pick, "pause suspends resource pending choice")
	_tap(KEY_ESCAPE)
	await _settle_choice()
	_check(not _state().start_pick and _state().phase == MenuIds.Phase.Play, "pending choice completes after menu closes")
	_restore_initial()
	await _ready_cards()
	# メニュー中から押したままの決定を、閉じた後のカードへ渡さない。
	_tap(KEY_P)
	_key(KEY_ENTER, true)
	_tap(KEY_P)
	await _ready_cards()
	_key(KEY_ENTER, false)
	_check(_state().start_pick, "menu accept release cannot choose underlying card")
	_tap(KEY_1)
	await _settle_choice()
	_check(_state().phase == MenuIds.Phase.Play and not _state().start_pick, "fresh choice still works after menus")
	bridge.command("dev_edit", {"kind":"progression","payload":{"pending_levels":2}})
	_step(1.0/120.0)
	cards = _state().cards.duplicate(true)
	_tap(KEY_ESCAPE)
	hud._pause_box.get_child(1).pressed.emit()
	_check(_state().phase == MenuIds.Phase.Levelup and _state().pending_levels == 2 and _state().cards == cards, "resume button restores queued level choices")
	# 実際のカード領域へのクリックも隠れたカードを確定しない。
	var point: Vector2 = hud._cards_row.get_child(2).get_global_rect().get_center()
	_tap(KEY_P)
	_click(point)
	_check(_state().pending_levels == 2 and _state().cards == cards, "debug shields card pointer area")
	_tap(KEY_P)
	# ゲーム中のデバッグ表示も閉じるまで時計を停止し、背後の入力を残さない。
	_clear_choice()
	for equipment in ["W01", "W02", "W03", "W04"]:
		_check(bridge.command("dev_grant_equipment", {"kind":"weapon","id":equipment,"levels":1}).ok, "交換前に通常の装備枠を埋める")
	_check(bridge.command("dev_edit", {"kind":"comet_weapon","payload":{"id":"W22"}}).ok, "交換候補を開く")
	var swap := _state().swap_pick
	cards = _state().cards.duplicate(true)
	_tap(KEY_ESCAPE)
	_tap(KEY_ESCAPE)
	_tap(KEY_P)
	_tap(KEY_ESCAPE)
	_check(swap == &"W22" and _state().swap_pick == swap and _state().cards == cards and hud._swap_box.visible, "menus preserve weapon swap choice")
	_clear_choice()
	_tap(KEY_P)
	var before := _state().time
	_step(1.0)
	_check(_state().time == before, "debug suspends gameplay clock")
	_tap(KEY_P)
	_check(_state().phase == MenuIds.Phase.Play and not panel.visible, "debug close preserves gameplay phase")
	await _close()
	print("[selection_menus] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _ready_cards() -> void:
	var deadline := Time.get_ticks_usec() + 350_000
	while Time.get_ticks_usec() < deadline:
		await get_tree().process_frame

func _settle_choice() -> void:
	for i in 4000:
		scene.cpp_choices.poll()
		_step(0.0)
		if int(bridge.read_frame().value.ui.cards.selected_id) == 0: break
		await get_tree().process_frame

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

func _open_session() -> bool:
	scene = await _cpp_open(1, false)
	if scene.bridge == null: return false
	bridge = scene.bridge
	hud = scene.view.get_node("Hud/HudRoot")
	router = scene.view.get_node("World/InputRouter")
	for frame in 60:
		panel = scene.view.get_node_or_null("Hud/DebugPanel")
		if panel != null: break
		await get_tree().process_frame
	_check(panel != null, "本番の開発起動が調整パネルを接続する")
	if panel == null: return false
	_initial_checkpoint = bridge.checkpoint().value
	await get_tree().process_frame
	return true

func _state() -> Dictionary:
	var ui: Dictionary = bridge.read_frame().value.ui
	return {"phase":ui.phase,"cards":ui.cards.candidates,"start_pick":ui.cards.initial,
		"weapons":ui.weapon_levels,"pending_levels":ui.pending_levels,"swap_pick":StringName(ui.cards.get("swap_pick","")),"time":ui.run_time}

func _step(seconds: float) -> void:
	var count := maxi(1, ceili(seconds * 120.0))
	for tick in count:
		var response: Dictionary = bridge.step(seconds/count, bridge.pack_intent(Intent.new()), {"logical_size":get_viewport().get_visible_rect().size})
		_check(response.ok, "C++の固定更新を完了する")

func _choose_first() -> void:
	var cards: Dictionary = bridge.read_frame().value.ui.cards
	var first: Dictionary = cards.candidates[0]
	_check(bridge.command("choose_card", {"offer_id":cards.offer_id,"candidate_id":first.candidate_id}).ok, "通常の候補を選ぶ")

func _restore_initial() -> void:
	_check(bridge.restore(_initial_checkpoint).ok, "最初の選択前へ戻す")
	bridge.collect_frame()

func _clear_choice() -> void:
	_check(bridge.command("dev_edit", {"kind":"progression","payload":{"pending_levels":0}}).ok, "確認用の保留レベル数を戻す")
	_check(bridge.command("dev_edit", {"kind":"debug_action","payload":{"action":"reset_loadout","args":{}}}).ok, "選択を終えてゲームの位相へ戻す")

func _hold_choice_resources() -> void:
	_held_scopes.clear()
	scene.cpp_choices.prepare = func(paths: PackedStringArray) -> ContentResourceScope:
		var scope := ContentManager.prepare_resources(paths, DisplayServer.get_name() != "headless")
		scope.pending.append("held://selection")
		_held_scopes.append(scope)
		return scope
	_restore_initial()
	scene.cpp_choices.poll()
