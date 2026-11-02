## 同じ武器選択UIで追加強化を表示し、Viewport入力と描画を確認する。
extends "res://tests/integration/selection_menus.gd"

func _ready() -> void:
	if "--cpp" in OS.get_cmdline_user_args():
		await _cpp_ui_ready()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): shots = arg.trim_prefix("--out=")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	TranslationServer.set_locale("ja")
	var config := ContentManager.cfg.duplicate(true) as GameConfig
	config.levelup_bonus_chance = 0.0
	scene = RunManager.create_session(self, {"lab": true, "seed": 42, "config": config}, true)
	scene.auto_step = false
	run = scene.sim
	hud = scene.view.get_node("Hud/HudRoot")
	run.state.lab_mode = false # 実験場では省かれる通常HUDのキー入力も確認する。
	for id in [&"W03", &"W04", &"W08", &"W17"]: run.loadout.grant(&"weapon", id, 5)
	for id in [&"T08", &"T03", &"T04", &"T05"]: run.loadout.grant(&"trait", id, run.cfg.trait_max_stacks)
	run.state.ship_hp = 40.0
	run.state.pending_levels = 3
	_show([&"area", &"max_hp", &"heal"])
	await _ready_cards()
	_check(hud._cards_row.get_child_count() == 3 and hud._cards_box.visible, "既存3択UIで追加強化を表示")
	await _shot("postmax_area_heal")
	var cards := run.state.cards.duplicate(true)
	_tap(KEY_ESCAPE)
	_tap(KEY_1)
	_tap(KEY_R)
	_check(run.state.cards == cards and run.state.post_max_stacks.is_empty(), "ポーズが追加強化・リロール入力を遮断")
	_tap(KEY_ESCAPE)
	await _ready_cards()
	_tap(KEY_1)
	await _settle_choice()
	_check(int(run.state.post_max_stacks.get(&"area", 0)) == 1 and run.state.pending_levels == 2, "新たな数字入力で追加強化を1回取得")
	_show([&"crit_chance", &"charge_time", &"repair"])
	await _ready_cards()
	_check(run.state.cards[0].info.desc == "+1%" and run.state.cards[0].info.tooltip_desc.contains("1%"), "クリティカル率は増分と累計を%表示")
	_check(run.state.cards[2].info.desc == "+1%" and run.state.cards[2].info.tooltip_desc.contains("1%"), "修理キットの割合も%表示")
	await _shot("postmax_crit_charge_repair")
	for id in [&"W03", &"W04", &"W08", &"W17"]: run.loadout.remove_weapon(id)
	for id in [&"W01", &"W05", &"W07", &"W23"]: run.loadout.grant(&"weapon", id, 5)
	_show([&"followup", &"weapon_interval", &"duration"])
	await _ready_cards()
	await _shot("postmax_followup")
	var hp := run.state.ship_hp
	_show([&"heal", &"max_hp", &"max_speed"])
	await _ready_cards()
	var point: Vector2 = hud._cards_row.get_child(0).get_global_rect().get_center()
	_click(point)
	await _settle_choice()
	_check(is_equal_approx(run.state.ship_hp, hp + run.state.stats.max_hp * 0.3), "同じカード領域のクリックで即時30%回復")
	TranslationServer.set_locale("en")
	_show([&"crit_chance", &"max_hp", &"heal"])
	await _ready_cards()
	_check(run.state.cards[0].info.desc == "+1%", "英語でも追加確率の増分を%表示")
	await _shot("postmax_english")
	for button in hud._cards_row.get_children():
		_check(not button.tooltip_text.contains("postmax."), "英語表示の翻訳キーを解決")
	if DisplayServer.get_name() != "headless":
		for dimensions in [Vector2i(960, 720), Vector2i(960, 540)]:
			DisplayServer.window_set_size(dimensions)
			await get_tree().process_frame
			await get_tree().process_frame
			var viewport_rect := get_viewport().get_visible_rect()
			for button in hud._cards_row.get_children():
				_check(viewport_rect.encloses(button.get_global_rect()), "追加強化カードが異なる画面比率でも画面内に収まる")
		await _shot("postmax_small_english")
	for ids: Array in [[&"T08"], [&"T08", &"T03"]]:
		run.state.cards = []
		for id in ids:
			run.state.cards.append({"kind": &"trait", "id": id, "level": 3})
		run.loadout._publish_cards()
		await _ready_cards()
		_check(hud._cards_row.get_child_count() == ids.size(), "通常候補%d枚を表示" % ids.size())
		var first: Control = hud._cards_row.get_child(0)
		_check(first.size.x <= 145.0 and first.position.x >= 169.0, "少数候補もカード幅を保って中央へ配置")
	await _close()
	print("[post_max_ui] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _show(ids: Array) -> void:
	run.state.cards = []
	for id in ids:
		run.state.cards.append({"kind": &"post_max", "id": id, "level": 1, "info": run.loadout.post_max.card_info(id)})
	run.loadout._publish_cards()

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
