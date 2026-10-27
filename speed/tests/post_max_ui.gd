## 同じ武器選択UIで追加強化を表示し、Viewport入力と描画を確認する。
extends "res://tests/selection_menus.gd"

func _ready() -> void:
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
	for id in [&"T01", &"T03", &"T04", &"T05", &"T06"]: run.loadout.grant(&"trait", id, 3)
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
	_check(run.state.cards[0].info.desc == "+1 points", "英語の追加強化は英語の増分を表示")
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
	for ids: Array in [[&"T01"], [&"T01", &"T03"]]:
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
