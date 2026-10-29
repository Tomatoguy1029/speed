## 両機能を同じ実行体に読み込み、編集画面の開閉がランと追加成長を変更しないことを確認する。
extends "res://tests/post_max_ui.gd"

func _ready() -> void:
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	var saved := JSON.stringify(SaveManager.data)
	scene = RunManager.create_session(self, {"lab": true, "seed": 42}, true)
	scene.auto_step = false
	run = scene.sim
	hud = scene.view.get_node("Hud/HudRoot")
	for id in [&"W03", &"W04", &"W08", &"W17"]:
		run.loadout.grant(&"weapon", id, run.cfg.weapon_max_level)
	for id in [&"T01", &"T03", &"T04", &"T09"]:
		run.loadout.grant(&"trait", id, run.cfg.trait_max_stacks)
	for i in 4: _check(run.loadout.post_max.select(&"crit_chance"), "追加クリティカルを取得")
	run.loadout.refresh_stats()
	run.state.ship_hp = 40.0
	run.state.pending_levels = 2
	_show([&"area", &"max_hp", &"heal"])
	await _ready_cards()
	var cards := run.state.cards.duplicate(true)
	var screen: int = GameManager.screen
	var connections := GameManager.screen_changed.get_connections().size()
	for iteration in 3:
		var editor = load("res://gyms/visual_editor.tscn").instantiate()
		add_child(editor)
		await get_tree().process_frame
		var preview: WeakRef = weakref(editor._current().stage)
		editor._current().settings.birth_rate += 1.0
		for tool in [1, 2, 3, 0]: editor.select_tool(tool)
		_check(editor.dirty_paths().size() == 1, "編集中の値をツール間で保持")
		editor.free()
		await get_tree().process_frame
		_check(preview.get_ref() == null, "ランを残して編集プレビューを解放")
		_check(GameManager.screen == screen and GameManager.screen_changed.get_connections().size() == connections, "編集の開閉でゲーム画面と接続を維持")
		_check(run.state.cards == cards and run.state.pending_levels == 2, "編集の開閉で追加成長の候補を維持")
		_check(is_equal_approx(run.state.stats.crit_chance, 0.3) and int(run.state.post_max_stacks[&"crit_chance"]) == 4, "T09と追加成長の上限を維持")
	var hp := run.state.ship_hp
	run.loadout.choose_card(2)
	_check(is_equal_approx(run.state.ship_hp, hp + run.state.stats.max_hp * 0.3), "編集を閉じた後も同じカードから30%回復")
	_check(run.state.pending_levels == 1, "編集を閉じた後に選択を1回だけ消費")
	_check(JSON.stringify(SaveManager.data) == saved, "両機能の操作を永続セーブへ漏らさない")
	await _close()
	var fresh := RunManager.create_session(self, {"lab": true, "seed": 84}, false)
	_check(fresh.sim.state.post_max_stacks.is_empty(), "編集後も次ランの追加成長を初期化")
	fresh.free()
	print("[visual_editor_post_max] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
