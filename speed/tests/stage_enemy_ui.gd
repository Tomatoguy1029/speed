## 敵調整画面の分類・レイアウト・入力・保存を、隔離したステージで確認する。
extends Node
const IO := preload("res://scripts/dev/stage_enemy_edit.gd")
const FIELDS := preload("res://scripts/dev/stage_enemy_fields.gd")
var failed := 0
var overlay: Control
var output := ""

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))

func move_pointer(point: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await get_tree().process_frame

func mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	get_window().title = "SPEED — 敵調整UI確認"
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1180, 740)
	var source := ContentManager.stage(4).duplicate(true) as StageDef
	source.enemy_tuning = {}
	var fixture := "/tmp/speed-enemy-ui-fixture.tres"
	ResourceSaver.save(source, fixture)
	var stage: RuntimeStage = load("res://tools/content/build_runtime_stage.gd").compile(source)
	var session := RunManager.create_session(self, {"stage": stage, "stage_index": 4, "seed": 42}, false)
	session.auto_step = false
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.name = "HudRoot"
	hud.run = session.sim
	layer.add_child(hud)
	hud.set_process(false)
	var debug = load("res://scripts/dev/debug_panel.gd").new()
	debug.run = session.sim
	layer.add_child(debug)
	var router := InputRouter.new()
	add_child(router)
	session.sim.input = router
	overlay = load("res://scripts/dev/stage_enemy_overlay.gd").new()
	overlay.run = session.sim
	layer.add_child(overlay)
	check(overlay.panel == null and overlay.get_child_count() == 0, "閉じている敵調整はUIを構築しない")
	overlay.show()
	await frames()
	var panel: Control = overlay.panel
	check(panel._definitions.size() == 1, "初回表示は選択した敵の定義だけを読む")
	check(panel._names["telescope"] == IO.definition("telescope").display_name, "一覧はソースの敵名を表示する")
	panel.stage_path = fixture
	panel.reload_stage()
	panel._select_enemy("telescope")
	await frames()
	if "--manual" in OS.get_cmdline_user_args(): return
	check(panel._tree_items.has("予告・頻度") and panel._tree_items.has("範囲・形状"), "敵固有の項目を意味のある階層に分類する")
	check(panel._wide, "大きいウィンドウで共通値・ステージ設定・実効値を横に比較する")
	await capture("large")
	var initial_size := overlay.size
	var grip: Vector2 = overlay._grip.global_position + Vector2(12, 12)
	await move_pointer(grip)
	await mouse_button(grip, true)
	check(overlay._mode == "resize", "右下のハンドルの押下でリサイズを開始する")
	await move_pointer(grip - Vector2(100, 60), true)
	await mouse_button(grip - Vector2(100, 60), false)
	await frames()
	check(overlay.size.x < initial_size.x and overlay.size.y < initial_size.y, "ドラッグ入力でウィンドウをリサイズできる")
	check(not router.poll().press, "リサイズの押下をゲームへ漏らさない")
	overlay.size = initial_size
	await frames()
	var divider: Vector2 = panel._split.get_drag_area_controls()[0].get_global_rect().get_center()
	var nav_width: float = panel._nav.size.x
	await move_pointer(divider)
	await mouse_button(divider, true)
	await move_pointer(divider + Vector2(55, 0), true)
	await mouse_button(divider + Vector2(55, 0), false)
	await frames()
	check(panel._nav.size.x > nav_width, "区切りのドラッグ入力で領域の幅を変えられる")
	var origin := overlay.position
	var header: Control = overlay.get_child(0).get_child(0).get_child(0)
	var handle := header.get_global_rect().get_center()
	await move_pointer(handle)
	await mouse_button(handle, true)
	await move_pointer(handle + Vector2(-30, 10), true)
	await mouse_button(handle + Vector2(-30, 10), false)
	check(overlay.position != origin, "タイトルのドラッグ入力で移動できる")
	panel._tree_items["予告・頻度"].select(0)
	await frames()
	check(panel._row_controls.has("params.cooldown") and not panel._row_controls.has("hp"), "分類で編集対象を絞る")
	var section: VBoxContainer = panel._rows.get_child(0)
	var toggle: Button = section.get_child(0)
	toggle.button_pressed = false
	check(not section.get_child(1).visible, "分類内のグループを折り畳める")
	toggle.button_pressed = true
	panel._tree_items["すべて"].select(0)
	await frames()
	panel._scroll.scroll_vertical = 500
	await frames()
	check(panel._scroll.scroll_vertical > 0, "多数の項目を編集領域内でスクロールできる")
	panel._split.split_offset = 260
	panel._nav_split.split_offset = 210
	await frames()
	check(panel._nav.size.x >= 200, "敵選択と編集の領域幅を調整できる")
	panel._category = "威力・効果"
	panel._refresh_rows()
	await frames()
	var enabled: CheckBox = panel._row_controls["params.bullet_dmg"][3]
	check(not enabled.button_pressed and panel._row_controls["params.bullet_dmg"][2] == null, "継承中は共通値を使用し編集欄を作らない")
	check(panel._row_controls["params.bullet_dmg"][0].text.contains("共通値を使用"), "継承状態と実効値を表示する")
	enabled.button_pressed = true
	var spin: SpinBox = panel._row_controls["params.bullet_dmg"][2]
	check(spin.visible and panel.values.telescope["params.bullet_dmg"] == 20.0, "チェックONでこのステージの上書き欄を表示する")
	spin.value = 27.0
	check(panel.is_dirty() and session.sim.enemies.stage_tuning.telescope["params.bullet_dmg"] == 27.0, "数値編集とライブ適用を維持する")
	check(IO.definition("telescope").params.bullet_dmg == 20.0, "共通値を変更しない")
	enabled.button_pressed = false
	check(not spin.visible and not panel.values.get("telescope", {}).has("params.bullet_dmg"), "チェックOFFで上書きを解除して共通値へ戻る")
	enabled.button_pressed = true
	spin.value = 27.0
	var events := session.sim.state.events.filter(func(event): return event.type == &"enemy_tuning_changed")
	check(not events.is_empty() and events[-1].values.telescope["params.bullet_dmg"] == 27.0 and events[-1].has("t"), "録画用の時刻・上書き辞書の変更イベントを維持する")
	await frames()
	await capture("override-enabled")
	spin.get_line_edit().grab_focus()
	await frames()
	for key in [KEY_P, KEY_1, KEY_Q, KEY_SPACE]:
		var phase := session.sim.state.phase
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.unicode = key
		event.pressed = true
		Input.parse_input_event(event)
		await get_tree().process_frame
		var intent := router.poll()
		check(not intent.press and not intent.alt_press and not intent.hero_press and not debug.visible and session.sim.state.phase == phase, "入力欄のキーをゲーム操作へ漏らさない: %s" % key)
	spin.get_line_edit().text = "27"
	spin.get_line_edit().release_focus()
	panel._save()
	check(not panel.is_dirty() and IO.read_stage(fixture).enemy_tuning.telescope["params.bullet_dmg"] == 27.0, "Saveボタンの経路で保存し未保存状態を解除する")
	check(panel._row_controls["params.bullet_dmg"][3].button_pressed, "保存済みの上書きを有効表示する")
	get_window().size = Vector2i(400, 560)
	await frames()
	check(overlay.get_global_rect().end.x <= 400 and overlay.get_global_rect().end.y <= 560, "小さい画面にパネル全体を収める")
	check(panel._compact and not panel._nav.visible and panel._editor.visible, "狭い表示で編集領域を優先する")
	await capture("small-edit")
	panel._nav_button.pressed.emit()
	await frames()
	check(panel._nav.visible and not panel._editor.visible, "狭い表示で敵一覧と分類へ切り替える")
	await capture("small-navigation")
	panel._tree_items["予告・頻度"].select(0)
	await frames()
	check(panel._editor.visible and not panel._nav.visible, "分類選択後に編集へ戻る")
	get_window().size = Vector2i(320, 480)
	await frames()
	check(overlay.get_global_rect().end.x <= 320 and overlay.get_global_rect().end.y <= 480, "幅320の画面でも編集領域と操作を画面内に収める")
	await capture("narrow-edit")
	get_window().size = Vector2i(400, 560)
	await frames()
	overlay.size = Vector2(350, 410)
	overlay.position = Vector2(25, 30)
	overlay._constrain()
	await frames()
	var rect := overlay.get_rect()
	overlay._close()
	overlay.show()
	overlay._fit()
	check(overlay.get_rect() == rect, "閉じて開いても位置とサイズを保持する")
	check(overlay.panel == panel, "再表示では構築済みのUIを使う")
	var next = load("res://scripts/dev/stage_enemy_overlay.gd").new()
	next.run = session.sim
	layer.add_child(next)
	next.show()
	await frames()
	check(next.get_rect() == rect, "次のパネルにも位置とサイズを引き継ぐ")
	next.free()
	overlay._maximize()
	await frames()
	check(overlay.size.x >= 390, "画面内に広げられる")
	overlay._maximize()
	check(overlay.get_rect() == rect, "元の位置とサイズに戻れる")
	panel.reload_stage()
	panel._category = "威力・効果"
	panel._refresh_rows()
	await frames()
	check(panel._row_controls["params.bullet_dmg"][3].button_pressed and panel._row_controls["params.bullet_dmg"][2].value == 27.0, "再読込でも保存済み上書きのチェックと値を復元する")
	panel._row_controls["params.bullet_dmg"][3].button_pressed = false
	panel._save()
	check(not IO.read_stage(fixture).enemy_tuning.get("telescope", {}).has("params.bullet_dmg"), "解除してSaveするとステージの上書きも削除する")
	panel.reload_stage()
	await frames()
	check(not panel._row_controls["params.bullet_dmg"][3].button_pressed and panel._row_controls["params.bullet_dmg"][2] == null, "解除後の再読込は共通値の参照に戻る")
	overlay.free()
	debug.free()
	hud.free()
	session.free()
	DirAccess.remove_absolute(fixture)
	await get_tree().process_frame
	print("[stage_enemy_ui] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
