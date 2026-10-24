## 強化率の反復操作と機体強化画面の保存値を確認する。セーブはメモリだけで扱う。
extends Node

class MemorySave:
	extends "res://scripts/managers/save_manager.gd"
	var writes := 0
	func save() -> void:
		writes += 1
		save_changed.emit()
	func _save_settings() -> void:
		pass

var failed := 0
var shots := ""

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): shots = arg.trim_prefix("--out=")
	var had_save := FileAccess.file_exists(SaveManager.SAVE_PATH)
	var disk_save := FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if had_save else PackedByteArray()
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings_copy
	SaveManager.data = SaveManager._migrate({"coins": 321, "meta": {"speed": 2, "hp": 1}}, SaveManager.default_data())
	var saved := SaveManager.data.duplicate(true)
	var panel := preload("res://scripts/dev/debug_panel.gd").new()
	# ランを進めず、実際の入力欄とプリセットのシグナルを使う。
	var controls := VBoxContainer.new()
	panel._add_meta_levels(controls)
	add_child(controls)
	var entries := ContentManager.sorted(ContentManager.catalog.table(&"meta_upgrades"))
	var maximum := 0
	for entry: ContentEntry in entries:
		maximum += entry.costs.size()
		check(panel._meta_boxes[entry.id].value == SaveManager.meta_level(entry.id), "初期表示は保存された段: %s" % entry.id)
	for tenths in [7, 0, 2, 5, 7, 9, 7]:
		_button(controls, "%d割" % tenths).pressed.emit()
		var total := 0
		for entry: ContentEntry in entries:
			var level := SaveManager.run_meta_level(entry.id)
			total += level
			check(level >= 0 and level <= entry.costs.size(), "段の上限を守る: %s" % entry.id)
			check(panel._meta_boxes[entry.id].value == level, "入力欄とランの段が一致: %s" % entry.id)
		check(total == roundi(maximum * tenths / 10.0), "%d割の合計を四捨五入する" % tenths)
		check(SaveManager.data == saved and SaveManager.writes == 0, "強化率は保存値と部品を変更しない")
	check(SaveManager.dev_meta_override == {"speed": 4, "hp": 4, "atk": 4, "charge": 4, "pickup": 3, "xp": 3, "reroll": 2, "length": 3}, "7割の端数は同率なら画面順で配る")
	check(ProfileManager.for_run(false) == ProfileManager.compute(SaveManager.dev_meta_override), "次のランの性能へ強化率を反映する")
	for entry: ContentEntry in entries:
		check(not ResourceLoader.has_cached(entry.path), "強化率は索引だけで計算する: %s" % entry.id)
	_button(controls, "セーブの段に戻す").pressed.emit()
	check(SaveManager.dev_meta_override.is_empty(), "保存値へ戻すと上書きを解放する")
	for entry: ContentEntry in entries:
		check(panel._meta_boxes[entry.id].value == SaveManager.meta_level(entry.id), "保存値へ戻した入力欄: %s" % entry.id)
	panel._meta_boxes[&"speed"].value = 3
	check(SaveManager.run_meta_level(&"speed") == 3 and SaveManager.meta_level(&"speed") == 2, "個別入力も保存値と独立する")
	_button(controls, "7割").pressed.emit()
	controls.free()
	panel.free()
	await _test_upgrade_screen()
	check(FileAccess.file_exists(SaveManager.SAVE_PATH) == had_save, "セーブの有無を保持する")
	if had_save:
		check(FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == disk_save, "既存セーブのファイルを保持する")
	print("[debug_meta_ratio] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _test_upgrade_screen() -> void:
	GameManager.boot_request = Callable()
	GameManager.screen = GameManager.Screen.MAIN_MENU
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	for visit in 2:
		GameManager.goto(GameManager.Screen.UPGRADE)
		await get_tree().create_timer(1.0).timeout
		var screen: Control = app._current
		check(screen.get_script().resource_path == "res://scripts/ui/upgrade_screen.gd", "機体強化画面へ遷移する")
		screen.find_child("Part_speed", true, false).pressed.emit()
		check(screen._information.text.contains("2 / 5"), "購入画面はデバッグの4段でなく保存された2段を表示する")
		check(screen._price.text.contains("90"), "保存された次の段の費用を表示する")
		if visit == 1:
			screen._buy_button.pressed.emit()
			check(SaveManager.meta_level(&"speed") == 3 and SaveManager.coins() == 231, "購入した段と費用を保存する")
			check(SaveManager.writes == 1 and screen._information.text.contains("3 / 5"), "購入後の保存と表示を揃える")
			check(SaveManager.run_meta_level(&"speed") == 4, "購入してもランのデバッグ上書きを保つ")
			await _shot()
		GameManager.back()
		await get_tree().create_timer(1.0).timeout
		check(GameManager.screen == GameManager.Screen.MAIN_MENU, "機体強化画面から戻る")
	app.queue_free()
	await get_tree().process_frame

func _button(controls: Control, text: String) -> Button:
	for button: Button in controls.find_children("*", "Button", true, false):
		if button.text == text: return button
	return null

func _shot() -> void:
	if shots.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(shots)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join("debug_meta_upgrade.png"))
