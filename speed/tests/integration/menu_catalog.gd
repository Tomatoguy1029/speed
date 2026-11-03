## メニューを開いても、戦闘用の定義を読み込まずに表示できる。
extends Node
var failed := 0
func _ready() -> void:
	if "--operation-pages" in OS.get_cmdline_user_args():
		await _operation_pages()
		print("[画面の実操作] 失敗=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var paths := []
	for category in [&"stages", &"weapons", &"traits", &"legendary_modules", &"meta_upgrades"]:
		for entry in ContentManager.catalog.table(category).values(): paths.append(entry.path)
	for name in ["title", "stage_select", "encyclopedia", "upgrade"]:
		var screen: Node = load("res://scenes/app/%s.tscn" % name).instantiate()
		add_child(screen)
		await get_tree().process_frame
		await get_tree().process_frame
		for path in paths:
			if ResourceLoader.has_cached(path):
				failed += 1
				push_error("%sが定義を読んだ: %s" % [name, path])
		screen.queue_free()
		await get_tree().process_frame
	print("[menu_catalog] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
	else: print("[画面の実操作] ",label)

func _click(button: Control) -> void:
	var point := button.get_global_transform_with_canvas()*(button.size*0.5)
	var target := button.get_viewport()
	if target is SubViewport and target.get_parent() is SubViewportContainer:
		var container := target.get_parent() as SubViewportContainer
		point = container.get_global_transform_with_canvas()*(point*container.stretch_shrink)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		get_viewport().push_input(event,true)

func _frames() -> void:
	for i in 3: await get_tree().process_frame

func _operation_pages() -> void:
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(preload("res://tests/integration/thrill_acceptance.gd").MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	SaveManager.data.intro_seen = true
	SaveManager.data.coins = 9999
	SaveManager.data.encyclopedia = ["W01","W02","T08"]
	TranslationServer.set_locale("ja")
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var page = load("res://scenes/app/encyclopedia.tscn").instantiate()
	add_child(page)
	await _frames()
	for i in [1,2,0]:
		_click(page._tab_buttons[i])
		await _frames()
		_check(page._tab==i and page._pages[i].visible,"図鑑タブの実クリックで一覧を切り替える: %d" % i)
	var card: Button = page._grids[0].get_child(1)
	_click(card)
	_check(page._selection==card and not page._detail.text.is_empty(),"図鑑の項目をクリックして詳細を表示する")
	page.free()
	page = load("res://scenes/app/upgrade.tscn").instantiate()
	add_child(page)
	await _frames()
	_click(page.find_child("Part_speed",true,false))
	var level: int = SaveManager.meta_level(&"speed")
	_click(page._buy_button)
	_check(SaveManager.meta_level(&"speed")==level+1 and SaveManager.coins()<9999,"強化項目と購入の実クリックで段と所持部品を更新する")
	_click(page.find_child("DebugInfiniteParts",true,false))
	_check(SaveManager.dev_infinite_parts,"部品無限の実クリックで開発設定を切り替える")
	_click(page.find_child("DebugResetUpgrades",true,false))
	_check(SaveManager.meta_level(&"speed")==0,"強化リセットの実クリックで保存された段を戻す")
	SaveManager.dev_infinite_parts = false
	page.free()
	var starts: Array = []
	GameManager.run_requested.connect(func(stage,endless):starts.append([stage,endless]))
	GameManager.run_stage = 1
	GameManager.last_result = {"stage":1,"cleared":false,"time":0.0}
	GameManager.screen = GameManager.Screen.RESULT
	page = load("res://scenes/app/result.tscn").instantiate()
	add_child(page)
	await _frames()
	_click(page.get_node("%RetryButton"))
	_check(starts==[[1,false]] and GameManager.screen==GameManager.Screen.RUN,"結果画面の再挑戦クリックで同じステージの開始を依頼する")
	page.free()
	GameManager.screen = GameManager.Screen.RESULT
	page = load("res://scenes/app/result.tscn").instantiate()
	add_child(page)
	await _frames()
	_click(page.get_node("%MenuButton"))
	_check(GameManager.screen==GameManager.Screen.MAIN_MENU,"結果画面の戻るクリックでメインメニューへ戻る")
	page.free()
