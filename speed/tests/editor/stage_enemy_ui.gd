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
	if "--cpp-reward-display" in OS.get_cmdline_user_args():
		await cpp_reward_display()
		print("[cpp_reward_display] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-save-failure" in OS.get_cmdline_user_args():
		var fixture = load("res://tests/editor/stage_enemy_tuning.gd").new()
		check(await fixture.cpp_save(self,true),"F4の未保存保持と生成失敗を確認する")
		failed += fixture.failed
		fixture.free()
		print("[cpp_save_failure] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-live" in OS.get_cmdline_user_args():
		check(await cpp_live(), "C++ランのF4指定確認を最後まで行う")
		print("[cpp_live] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
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
	var events: Array = session.sim.state.events.filter(func(event): return event.type == &"enemy_tuning_changed")
	check(not events.is_empty() and events[-1].values.telescope["params.bullet_dmg"] == 27.0 and events[-1].has("t"), "録画用の時刻・上書き辞書の変更イベントを維持する")
	await frames()
	await capture("override-enabled")
	spin.get_line_edit().grab_focus()
	await frames()
	for key in [KEY_P, KEY_1, KEY_Q, KEY_SPACE]:
		var phase: int = session.sim.state.phase
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

func cpp_live() -> bool:
	var source := RuntimeStage.new()
	source.index = 198
	source.resources = StageResources.new()
	source.resources.enemy_ids = PackedStringArray(["drifter"])
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var builder = load("res://tools/content/build_run_content.gd")
	var folder := "res://.content/dev/cpp_live"
	if builder.build(source,config,folder,"F4の確認".sha256_text())!=OK: return false
	var path := folder.path_join("stage_198.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var first: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":42,"cpp_edit_source":{"stage":source,"config":config}},true)
	var second: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":42,"cpp_edit_source":{"stage":source,"config":config}},false)
	for session: RunSession in [first,second]:
		session.auto_step = false
		while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
		if session.bridge==null: return false
		if not session.bridge.command("dev_remove_weapon",{"id":"W01"}).ok or not session.bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-600,250)}).ok: return false
	var bridge = first.bridge
	var old: Dictionary = bridge._core.enemies_snapshot()[0]
	if not bridge.command("dev_damage",{"entity_id":old.id,"amount":1.0,"cause":"shot","no_crit":true}).ok: return false
	old = bridge._core.enemies_snapshot()[0]
	var held: Dictionary = bridge.checkpoint()
	if not held.ok: return false
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = load("res://scripts/dev/stage_enemy_overlay.gd").new()
	overlay.cpp_session = first
	layer.add_child(overlay)
	overlay.show()
	await frames()
	if overlay.panel==null: return false
	var panel: Control = overlay.panel
	panel._select_enemy("drifter")
	panel._category = "すべて"
	panel._refresh_rows()
	var base: float = ContentManager.enemies[&"drifter"].base_hp(config)
	panel._edit_value(base*2.0,"hp",base)
	var after: Dictionary = bridge._core.enemies_snapshot()[0]
	check(after.id==old.id and after.max_hp>old.max_hp and is_equal_approx(after.hp/after.max_hp,old.hp/old.max_hp),"F4の一時編集が生存個体のIDとHP割合を維持する")
	check(source.enemy_tuning.is_empty() and second.bridge._core.enemies_snapshot()[0].max_hp==old.max_hp,"保存元と同居する別ランへ変更を広げない")
	panel._edit_value(3.0,"rank",1.0)
	panel._edit_value(4.0,"xp_reward_counts.mid",0.0)
	var recording: Dictionary = bridge.read_recording(true)
	check(recording.ok and recording.value.xp_config.enemy_rewards.drifter.rank==3 and recording.value.xp_config.enemy_rewards.drifter.counts[1]==4,"星と結晶の数を編集境界で解決し録画用定義へ渡す")
	if not bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-300,250)}).ok: return false
	check(bridge._core.enemies_snapshot()[1].max_hp==bridge._core.enemies_snapshot()[0].max_hp,"次の出現も同じ編集定義を使う")
	panel.values.clear()
	panel._changed()
	check(is_equal_approx(bridge._core.enemies_snapshot()[0].hp/bridge._core.enemies_snapshot()[0].max_hp,old.hp/old.max_hp) and bridge._core.enemies_snapshot()[0].max_hp==old.max_hp,"未保存の変更を取り消して基準へ戻せる")
	check(bridge.restore(held.value).ok,"編集後の保持点から旧Bundleへ戻せる")
	await frames()
	check(panel.values.is_empty() and overlay.content_edit.values.is_empty() and bridge._core.enemies_snapshot()[0]==old,"復帰後のF4表示も旧定義の値へ戻す")
	var presentation: RunPresentation = first.view.get_node("RunPresentation")
	var rendered: Dictionary = bridge.read_render(Rect2(-1200,-500,1800,1000))
	check(rendered.ok and presentation.frame_view.apply_frame(rendered.value),"編集した実際の敵を通常描画へ渡す")
	await frames()
	await capture("cpp-live")
	for session: RunSession in [first,second]:
		check(session.bridge.read_frame().ok and session.bridge.collect_frame().ok and session.bridge.delivery_error.get("ok",false),"F4編集後のフレーム回収と通知配信が成功する")
	bridge.release_checkpoint(held.value)
	layer.free()
	first.free()
	second.free()
	return true

func cpp_reward_display() -> void:
	var source := RuntimeStage.new()
	source.index = 4
	source.enemies = [&"drifter"]
	var config: GameConfig = ContentManager.base.duplicate(true)
	var panel = load("res://scripts/dev/stage_enemy_panel.gd").new()
	panel.bind_run(source,config,{})
	add_child(panel)
	panel._select_enemy("drifter")
	panel._category = "すべて"
	panel._refresh_rows()
	var common: EnemyDef = ContentManager.enemies[&"drifter"]
	panel._edit_value(3.0,"rank",float(common.rank))
	var resolved := StageEnemyTuning.resolve(common,panel.values.drifter)
	var hp_text: String = panel._row_controls.hp[0].text
	var reward_text: String = panel._row_controls["xp_reward_counts.mid"][0].text
	check(hp_text.contains("実効 "+String.num(resolved.base_hp(config),3)) and reward_text.contains("実効 "+String.num(float(resolved.resolve_xp_reward().counts[1]),3)),"星の数を変えるとHPと固定報酬の実効値表示も更新する")
	var reward_base := StageEnemyTuning.base_value(common,"xp_reward_counts.mid",config)
	panel._toggle_override(true,"xp_reward_counts.mid",reward_base)
	check(panel.values.drifter["xp_reward_counts.mid"]==resolved.resolve_xp_reward().counts[1],"結晶の上書きONは現在の星から計算した値で始める")
	panel._reset_key("rank",panel._row_controls.rank[2],float(common.rank))
	check(panel._row_controls.hp[0].text.contains("実効 "+String.num(common.base_hp(config),3)),"星の上書きを解除すると派生HP表示も基準へ戻る")
	panel.free()
