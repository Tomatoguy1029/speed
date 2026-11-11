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
	if _operation_only():
		if "--cpp-operation-menus" in OS.get_cmdline_user_args(): await _operation_menus()
		elif "--cpp-operation-choice" in OS.get_cmdline_user_args(): await _operation_choice()
		elif "--cpp-operation-runtime" in OS.get_cmdline_user_args() or "--cpp-operation-input" in OS.get_cmdline_user_args(): await _operation_runtime()
		elif "--cpp-operation-debug" in OS.get_cmdline_user_args(): await _operation_debug()
		elif "--cpp-operation-settings" in OS.get_cmdline_user_args(): await _operation_settings()
		elif "--cpp-operation-codex" in OS.get_cmdline_user_args():
			await _codex_round_trip()
			hud._rewards.enqueue_bonus({"type": &"level_bonus", "kind": &"weapon", "id": &"W01", "level": 2, "count": 1})
			await _codex_round_trip()
			hud._rewards.cancel()
			_clear_choice()
			await _codex_round_trip()
		elif "--cpp-operation-spawn" in OS.get_cmdline_user_args():
			_clear_choice()
			_tap(KEY_P)
			await _operation_spawn()
		elif "--cpp-operation-release" in OS.get_cmdline_user_args():
			_clear_choice()
			bridge.command("dev_edit",{"kind":"debug_action","payload":{"action":"gauge_full","args":{}}})
			_pointer(Vector2(500,220),true)
			_input_step()
			_operation_release()
		await _close()
		print("[操作経路] 成功=%d 失敗=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	var cards: Array = _state().cards.duplicate(true)
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
	await _codex_round_trip()
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
	await _codex_round_trip()
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
	await _codex_round_trip()
	for equipment in ["W01", "W02", "W03", "W04"]:
		_check(bridge.command("dev_grant_equipment", {"kind":"weapon","id":equipment,"levels":1}).ok, "交換前に通常の装備枠を埋める")
	_check(bridge.command("dev_edit", {"kind":"comet_weapon","payload":{"id":"W22"}}).ok, "交換候補を開く")
	var swap: StringName = _state().swap_pick
	cards = _state().cards.duplicate(true)
	_tap(KEY_ESCAPE)
	_tap(KEY_ESCAPE)
	_tap(KEY_P)
	_tap(KEY_ESCAPE)
	_check(swap == &"W22" and _state().swap_pick == swap and _state().cards == cards and hud._swap_box.visible, "menus preserve weapon swap choice")
	_clear_choice()
	_tap(KEY_P)
	var before: float = _state().time
	_step(1.0)
	_check(_state().time == before, "debug suspends gameplay clock")
	_tap(KEY_P)
	_check(_state().phase == MenuIds.Phase.Play and not panel.visible, "debug close preserves gameplay phase")
	await _close()
	print("[selection_menus] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _codex_round_trip() -> void:
	var phase: int = _state().phase
	var cards: Array = _state().cards.duplicate(true)
	var before: float = _state().time
	var elapsed: float = hud._rewards._elapsed
	var screen: int = GameManager.screen
	_tap(KEY_ESCAPE)
	var button: Button = hud._pause_box.get_node("CodexButton")
	for use_back in [false, true]:
		await get_tree().process_frame
		button.grab_focus()
		_tap(KEY_ENTER)
		var page: Control = hud._menu_overlay
		_check(page != null and not hud._pause_box.visible, "pause opens codex above the run")
		if page == null: break
		await _shot("pause_codex")
		_tap(KEY_1)
		_tap(KEY_R)
		_tap(KEY_Q)
		_tap(KEY_P)
		_step(1.0)
		_check(_state().phase == MenuIds.Phase.Paused and _state().time == before and _state().cards == cards and hud._rewards._elapsed == elapsed and not panel.visible, "codex preserves clock, choices and rewards and blocks shortcuts")
		_check(not bridge.read_frame().value.ui.input_enabled, "codex blocks gameplay input at the run boundary")
		if use_back:
			_click(page.get_node("%BackButton").get_global_rect().get_center())
		else:
			_tap(KEY_ESCAPE)
		_check(hud._menu_overlay == null and hud._pause_box.visible and _state().phase == MenuIds.Phase.Paused, "codex returns to pause without resuming")
		_check(get_viewport().gui_get_focus_owner() == button and GameManager.screen == screen, "codex restores focus and keeps the run screen")
		var intent := router.poll()
		_check(not intent.press and not intent.alt_press and not intent.hero_press, "closing codex discards pending gameplay input")
		_key(KEY_ESCAPE, true, true)
		_key(KEY_ESCAPE, false)
		_check(_state().phase == MenuIds.Phase.Paused, "codex close key echo cannot resume the run")
	_tap(KEY_ESCAPE)
	_check(_state().phase == phase and _state().cards == cards, "resume after codex restores the previous phase and choices")

func _ready_cards() -> void:
	var deadline := Time.get_ticks_usec() + 350_000
	while Time.get_ticks_usec() < deadline:
		await get_tree().process_frame

func _operation_only() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cpp-operation-"): return true
	return false

func _pointer(point: Vector2, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down and button==MOUSE_BUTTON_LEFT else 0
	get_viewport().push_input(event,true)

func _input_step() -> void:
	var response: Dictionary = bridge.poll_and_step(1.0/120.0,scene.cpp_input_source,get_viewport().get_visible_rect().size)
	_check(response.ok,"本番の入力取得と更新を通す")

func _operation_runtime() -> void:
	if "--cpp-operation-input" in OS.get_cmdline_user_args():
		_clear_choice()
	else:
		await _operation_runtime_buttons()
	hud._rewards.ult_acquire_seconds = 0.01
	bridge.command("dev_hero_place",{"id":"perseus"})
	var hero: Dictionary = bridge.read_frame().value.ui.hero
	for i in range(0,hero.links.size(),2): bridge.command("dev_hero_pass",{"from":hero.stars[hero.links[i]],"to":hero.stars[hero.links[i+1]],"dash":i})
	for i in 180:
		await get_tree().process_frame
		if hud._rewards._ult_details != null: break
	_check(hud._rewards._ult_details != null, "英雄の獲得後に説明を表示する")
	await get_tree().create_timer(0.55).timeout
	_tap(KEY_SPACE)
	await get_tree().process_frame
	bridge.collect_frame()
	_check(not hud._rewards.is_active() and not bridge.read_frame().value.ui.presentation_frozen,"Spaceで英雄の説明を閉じて入力を戻す")
	var resumed_input := router.poll()
	_check(not resumed_input.alt_press and not resumed_input.press, "説明を閉じたSpaceを描線開始へ流さない")
	_tap(InputActions.key_of(&"hero"))
	_input_step()
	_check(float(bridge.read_frame().value.ui.hero.active)>0.0,"ULTキーから本番の入力経路で英雄を発動する")
	bridge.command("dev_edit",{"kind":"debug_action","payload":{"action":"gauge_full","args":{}}})
	var held: Dictionary = bridge.checkpoint()
	_pointer(Vector2(500,220),true)
	_input_step()
	_check(bridge.read_frame().value.ui.draw.drawing,"マウスの押下で描線を開始する")
	_operation_release()
	bridge.restore(held.value)
	bridge.collect_frame()
	router.cancel_gesture()
	_tap(InputActions.key_of(&"draw_alt"))
	_input_step()
	_check(bridge.read_frame().value.ui.draw.drawing,"描画補助キーから描線を開始する")
	bridge.restore(held.value)
	bridge.collect_frame()
	router.cancel_gesture()
	# 描くボタンはタッチ端末で表示される。同じButtonへ実ポインターを送る。
	hud._draw_button.show()
	_click(hud._draw_button.get_global_rect().get_center())
	_input_step()
	_check(bridge.read_frame().value.ui.draw.drawing,"タッチ用の描くボタンから描線を開始する")
	bridge.release_checkpoint(held.value)

func _operation_release() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(850,220)
	get_viewport().push_input(motion,true)
	_input_step()
	_pointer(motion.position,false)
	_input_step()
	# マウスは次のクリックで確定する。タッチの指離しとは区別する。
	for i in 30: bridge.poll_and_step(1.0/120.0,scene.cpp_input_source,get_viewport().get_visible_rect().size)
	_pointer(motion.position,true)
	_input_step()
	_pointer(motion.position,false)
	_input_step()
	_check(not bridge.read_frame().value.ui.draw.drawing and bridge.read_frame().value.ui.draw.tracing,"描線後の次のクリックで突進を開始する")

func _operation_runtime_buttons() -> void:
	await _ready_cards()
	var rerolls: int = bridge.read_frame().value.ui.rerolls_left
	_click(hud._reroll_button.get_global_rect().get_center())
	_check(bridge.read_frame().value.ui.rerolls_left==rerolls-1,"引き直すボタンの実クリックで候補を更新する")
	for n in [1,2]: hud._rewards.enqueue_bonus({"type":&"level_bonus","kind":&"weapon","id":&"W01","level":n+1,"count":n})
	await get_tree().process_frame
	_click(Vector2(600,120))
	_check(hud._rewards.is_active() and hud._rewards._current.count==2,"継続の実クリックは待ち時間なしで次の継続へ進む")
	await get_tree().process_frame
	_click(Vector2(600,120))
	await get_tree().process_frame
	_check(not hud._rewards.is_active() and hud._cards_box.visible,"最後の継続をクリックすると候補へ戻る")
	_tap(KEY_ESCAPE)
	await get_tree().process_frame
	_click(hud._pause_box.get_child(1).get_global_rect().get_center())
	_check(_state().phase==MenuIds.Phase.Levelup,"再開ボタンの実クリックで元の選択へ戻る")
	_clear_choice()
	for id in ["W01","W02","W03","W04"]: bridge.command("dev_grant_equipment",{"kind":"weapon","id":id,"levels":1})
	bridge.command("dev_edit",{"kind":"comet_weapon","payload":{"id":"W22"}})
	_step(1.0/120.0)
	await _ready_cards()
	var weapons: Array = bridge.read_frame().value.ui.weapon_levels.duplicate(true)
	_click(hud._swap_keep.get_global_rect().get_center())
	_step(1.0/120.0)
	_check(_state().phase==MenuIds.Phase.Play and bridge.read_frame().value.ui.weapon_levels==weapons,"維持ボタンの実クリックで交換せず戦闘へ戻る")

func _operation_debug() -> void:
	_clear_choice()
	_tap(KEY_P)
	await get_tree().process_frame
	var invincible: bool = bridge.read_frame().value.ui.invincible
	await _click_panel_button("無敵の切り替え")
	_check(bridge.read_frame().value.ui.invincible!=invincible,"無敵ボタンから状態を切り替える")
	await _operation_spawn()
	panel._module.select(0)
	panel._levels.value = 2
	var id: String = panel._module.get_item_metadata(0)
	await _click_panel_button("入手")
	for i in 300:
		if bridge.read_frame().value.ui.weapon_levels.any(func(v):return v.id==id): break
		await get_tree().process_frame
	_check(bridge.read_frame().value.ui.weapon_levels.any(func(v):return v.id==id and v.level==2),"入手ボタンから選んだ装備と段を取得する")
	await _click_panel_button("装備をリセット")
	_check(bridge.read_frame().value.ui.weapon_levels.is_empty(),"リセットボタンから装備を外す")
	_tap(KEY_P)
	var overlay = scene.view.get_node("Hud/PerfOverlay")
	for expected in [1,2,0]:
		_tap(InputActions.key_of(&"debug_perf"))
		_check(overlay.mode==expected,"F3の実入力で性能表示を切り替える: %d" % expected)
	for recorder in get_tree().get_nodes_in_group("cpp_recorders"): recorder.set_process_input(false)
	var rec = load("res://tests/integration/play_recorder.gd").TempRecorder.new()
	add_child(rec)
	_record_key()
	_check(rec.armed and rec._file!=null and rec._cpp_session_id==scene.id,"Ctrl+F9の実入力で現在のランを録画する")
	var path: String = rec._file.get_path() if rec._file!=null else ""
	_record_key()
	_check(not rec.armed and rec._file==null and FileAccess.file_exists(path),"Ctrl+F9の実入力で録画を閉じてファイルを残す")
	rec.free()

func _operation_spawn() -> void:
	var count: int = bridge.read_metrics().value.enemies
	panel._enemy_count.value = 1
	await _click_panel_button("敵を生成")
	for i in 600:
		if bridge.read_metrics().value.enemies>count: break
		await get_tree().process_frame
	_check(bridge.read_metrics().value.enemies==count+1,"敵生成ボタンから指定した数を追加する: %d → %d / %s" % [count,bridge.read_metrics().value.enemies,panel._status.text])

func _record_key() -> void:
	for down in [true,false]:
		var key := InputEventKey.new()
		key.keycode = KEY_F9
		key.physical_keycode = KEY_F9
		key.ctrl_pressed = true
		key.pressed = down
		get_viewport().push_input(key,true)

func _operation_settings() -> void:
	_tap(KEY_ESCAPE)
	await get_tree().process_frame
	_click(hud._pause_box.get_child(2).get_global_rect().get_center())
	await get_tree().process_frame
	var settings: Control = hud._settings
	var checks := settings.find_children("*","CheckBox",true,false)
	for i in 2:
		var key := "muted" if i==0 else "hitstop"
		var before: bool = SaveManager.settings[key]
		_click(checks[i].get_global_rect().get_center())
		_check(SaveManager.settings[key]!=before,"設定の実クリックで値を変更する: "+key)
	var button: Button = settings._bind_buttons[&"hero"]
	var parent := button.get_parent()
	while parent!=null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await get_tree().process_frame
	_click(button.get_global_rect().get_center())
	_tap(KEY_F8)
	_check(InputActions.key_of(&"hero")==KEY_F8,"キー設定ボタンの実クリックと押下で割り当てる")
	_click(settings.get_node("%BackButton").get_global_rect().get_center())
	_check(hud._settings==null and _state().phase==MenuIds.Phase.Paused,"設定の戻るボタンを実クリックしてポーズへ戻る")

func _click_panel_button(text: String) -> void:
	for button in panel.find_children("*","Button",true,false):
		if button.text!=text: continue
		panel.get_child(0).ensure_control_visible(button)
		await get_tree().process_frame
		_click(button.get_global_rect().get_center())
		return
	_check(false,"操作するボタンがある: "+text)

## 表示の確認やsignalの直接発火ではなく、Viewportから操作を最後まで通す。
func _operation_menus() -> void:
	_tap(KEY_ESCAPE)
	await get_tree().process_frame
	_click(hud._pause_box.get_child(2).get_global_rect().get_center())
	_check(hud._settings!=null,"設定ボタンのクリックで設定を開く")
	_tap(KEY_ESCAPE)
	_check(hud._settings==null and _state().phase==MenuIds.Phase.Paused,"設定のEscは設定だけ閉じてポーズを維持する")
	# 失敗時も次の独立した確認へ進めるための後片付け。
	if hud._settings!=null: hud._settings._on_back()
	bridge.command("pause",{"paused":false})
	await _ready_cards()
	_tap(KEY_P)
	var before: Dictionary = bridge.read_frame().value.ui
	_tap(KEY_1)
	_tap(KEY_R)
	var after: Dictionary = bridge.read_frame().value.ui
	_check(panel.visible and int(after.cards.selected_id)==0 and after.rerolls_left==before.rerolls_left,"デバッグ表示中の数字とRは背後の選択予約・引き直しをしない")
	_tap(KEY_P)
	_check(int(bridge.read_frame().value.ui.cards.selected_id)==0,"デバッグを閉じても背後の選択予約を残さない")

func _operation_choice() -> void:
	_clear_choice()
	for id in ["W01","W02","W03","W04"]: bridge.command("dev_grant_equipment",{"kind":"weapon","id":id,"levels":2})
	scene.cpp_choices.prepare = func(paths: PackedStringArray) -> ContentResourceScope:
		var scope := ContentManager.prepare_resources(paths,false)
		scope.pending.append("held://operation")
		_held_scopes.append(scope)
		return scope
	bridge.command("dev_edit",{"kind":"comet_weapon","payload":{"id":"W22"}})
	_step(1.0/120.0)
	await _ready_cards()
	var before: Array = bridge.read_frame().value.ui.weapon_levels.duplicate(true)
	var slot: Control = hud._swap_grid.get_child(1)
	_click(slot.get_global_rect().get_center())
	_step(1.0/120.0)
	var cards: Dictionary = bridge.read_frame().value.ui.cards
	_check(int(cards.selected_id)==int(cards.candidates[1].candidate_id) and cards.preparing,"交換先の実クリックで指定武器の準備を始める")
	await get_tree().process_frame
	_click(hud._cpp_cancel.get_global_rect().get_center())
	_step(1.0/120.0)
	_check(int(bridge.read_frame().value.ui.cards.selected_id)==0 and bridge.read_frame().value.ui.weapon_levels==before,"選び直すの実クリックで装備を変えず候補へ戻る")
	await get_tree().process_frame
	_click(hud._swap_grid.get_child(1).get_global_rect().get_center())
	_step(1.0/120.0)
	for scope in _held_scopes:
		scope.failed = true
		scope.pending.clear()
	scene.cpp_choices.poll()
	_step(1.0/120.0)
	cards = bridge.read_frame().value.ui.cards
	_check(int(cards.error_code)==-1 and hud._cpp_retry.visible,"準備失敗を正式画面に表示する")
	var failed_request: int = cards.get("request_id",0)
	scene.cpp_choices.prepare = Callable()
	await get_tree().process_frame
	_click(hud._cpp_retry.get_global_rect().get_center())
	cards = bridge.read_frame().value.ui.cards
	_check(int(cards.get("request_id",0))!=failed_request and int(cards.error_code)==0,"もう一度準備するの実クリックで新しい準備を始める")
	for i in 240:
		scene.cpp_choices.poll()
		_step(1.0/120.0)
		if int(bridge.read_frame().value.ui.phase)==MenuIds.Phase.Play: break
		await get_tree().process_frame
	var ui: Dictionary = bridge.read_frame().value.ui
	_check(int(ui.phase)==MenuIds.Phase.Play and ui.weapon_levels.any(func(v):return v.id=="W22") and not ui.weapon_levels.any(func(v):return v.id=="W02"),"再準備完了でクリックした武器だけ交換して戦闘へ戻る")

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
	if _operation_only():
		var config: GameConfig = ContentManager.base.duplicate(true)
		config.planet_radius = 0.0
		config.moon_count = 0
		config.levelup_bonus_chance = 0.0
		var stage := RuntimeStage.new()
		stage.index = 88
		stage.boss_enabled = false
		stage.resources = StageResources.new()
		stage.resources.enemy_ids = PackedStringArray(["splitling"])
		var output := "res://.content/dev/operation_paths"
		var generated: Error = load("res://tools/content/build_run_content.gd").build(stage,config,output,"操作経路の確認".sha256_text())
		_check(generated==OK,"操作確認用の最小データを生成する: %s" % error_string(generated))
		if generated!=OK: return false
		var path := output.path_join("stage_88.json")
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		scene = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":932,"cpp_start":{"equipment":[],"lab_mode":false},"cpp_edit_source":{"stage":stage,"config":config,"definitions":{}}},true)
		scene.auto_step = false
		while scene.bridge==null and scene.cpp_error==OK: await get_tree().process_frame
	else:
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
