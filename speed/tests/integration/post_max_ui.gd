## 同じ武器選択UIで追加強化を表示し、Viewport入力と描画を確認する。
extends "res://tests/integration/selection_menus.gd"

func _ready() -> void:
	await _cpp_ui_ready()

func _cpp_ui_ready() -> void:
	TranslationServer.set_locale("ja")
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 0.0
	config.moon_count = 0
	config.weapon_slots = 1
	config.trait_slots = 1
	config.levelup_bonus_chance = 0.0
	var stage := RuntimeStage.new()
	stage.index = 88
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/post_max_ui"
	_check(load("res://tools/content/build_run_content.gd").build(stage,config,output,"最大後強化の正式UI".sha256_text())==OK,"同じ生成入口で表示と装備の資源を準備する")
	var path := output.path_join("stage_88.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session := RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":42},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	_check(session.bridge!=null,"最大後強化を正式UIへ接続する")
	if session.bridge==null:
		get_tree().quit(1)
		return
	var bridge = session.bridge
	var upgrades: Array = []
	bridge.subscribe("post_max_test",func(frame: Dictionary) -> bool:
		for event: Dictionary in frame.events:
			if event.type==&"upgrade": upgrades.append(event.payload.card)
		return true)
	hud = session.view.get_node("Hud/HudRoot")
	_check(bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W01","levels":5}).ok,"表示確認の武器をMAXにする")
	_check(bridge.command("dev_grant_equipment",{"kind":"trait","id":"T08","levels":5}).ok,"表示確認の特性をMAXにする")
	_check(bridge.command("dev_edit",{"kind":"progression","payload":{"hp":40.0,"pending_levels":1}}).ok,"表示確認のHPと保留レベルを設定する")
	var opened: Dictionary = bridge.command("dev_edit",{"kind":"post_max_offer","payload":{"ids":PackedStringArray(["crit_chance","max_hp","heal"])}})
	_check(opened.ok,"最大後候補を開く: %s; phase=%s complete=%s" % [opened,bridge._ui.phase,bridge._ui.normal_complete])
	bridge.collect_frame()
	await _ready_cards()
	if "--cpp-event-retry" not in OS.get_cmdline_user_args(): _check(hud._cards_row.get_child_count()==3 and hud._cards_box.visible,"既存の3択に追加強化を3枚表示する")
	var cards: Dictionary = bridge._ui.cards
	if cards.candidates.is_empty():
		session.free()
		get_tree().quit(1)
		return
	if "--cpp-event-retry" not in OS.get_cmdline_user_args(): _check(cards.candidates[0].info.desc=="+1%" and cards.candidates[0].info.tooltip_desc.contains("→"),"C++の確定値を増分・累計表示へ翻訳する")
	if "--cpp-event-retry" not in OS.get_cmdline_user_args(): _check(cards.candidates[1].info.desc=="+5 HP" and cards.candidates[1].info.tooltip_desc.contains("現在HP"),"HPの保持条件を同じカードへ表示する")
	_tap(KEY_2)
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	if "--cpp-event-retry" not in OS.get_cmdline_user_args(): _check(int(bridge._ui.post_max_stacks.get("max_hp",0))==1 and bridge._ui.pending_levels==0,"正式HUDの数字入力で1回だけ選択する")
	if "--cpp-event-retry" not in OS.get_cmdline_user_args(): _check(is_equal_approx(bridge._core.ship_snapshot().ship_hp,40.0),"画面から最大HPを増やしても現在HPは維持する")
	_check(not upgrades.is_empty() and upgrades.back().info.desc=="+5 HP" and upgrades.back().info.tooltip_desc.contains("0 → 5HP"),"取得通知にも選択前の確定値を一度だけ渡す")
	if "--cpp-event-retry" in OS.get_cmdline_user_args():
		session.free()
		await get_tree().process_frame
		print("[post_max_ui_cpp_event_retry] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	TranslationServer.set_locale("en")
	bridge.command("dev_edit",{"kind":"post_max_offer","payload":{"ids":PackedStringArray(["weapon_interval","followup","heal"])}})
	bridge.collect_frame()
	await _ready_cards()
	for button in hud._cards_row.get_children():
		_check(not button.tooltip_text.contains("postmax."),"英語でも翻訳キーを残さない")
	var frame: Dictionary = bridge._ui.cards
	_check(frame.candidates[0].info.tooltip_desc.contains("0.") and frame.candidates[0].info.tooltip_desc.contains("→"),"武器ごとの実効秒数を表示する")
	if DisplayServer.get_name()!="headless":
		for dimensions in [Vector2i(960,720),Vector2i(960,540)]:
			DisplayServer.window_set_size(dimensions)
			await get_tree().process_frame
			await get_tree().process_frame
			for button in hud._cards_row.get_children(): _check(get_viewport().get_visible_rect().encloses(button.get_global_rect()),"最大後カードが画面比率に合わせて収まる")
	session.free()
	await get_tree().process_frame
	print("[post_max_ui_cpp] passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
