## タイトルのロゴを、メニュー・星図の遷移中に再表示しない。
extends "res://tests/integration/thrill_acceptance.gd"

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): shots = argument.trim_prefix("--out=")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	var saved_settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = saved_settings
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true
	GameManager.screen = GameManager.Screen.TITLE
	var title: Control = load("res://scenes/app/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	var logo := title.find_child("TitleLogo", true, false) as TextureRect
	_check(logo != null, "title has a separate hand-drawn logo")
	if logo == null:
		title.free()
		get_tree().quit(1)
		return
	_check(logo.visible and logo.texture is AtlasTexture, "title shows the supplied logo")
	_check(logo.texture.atlas.resource_path.ends_with("ui_title_screen_stars_new_title_log.png"), "logo uses the supplied artwork")
	await _shot("starward_title")
	GameManager.screen = GameManager.Screen.MAIN_MENU
	title.show_screen(GameManager.Screen.MAIN_MENU, false)
	_check(not logo.visible, "mode menu hides title logo immediately")
	GameManager.screen = GameManager.Screen.STAGE_SELECT
	title.show_screen(GameManager.Screen.STAGE_SELECT)
	_check(not logo.visible, "starting map transition keeps title logo hidden")
	for i in 12:
		await get_tree().create_timer(0.1).timeout
		_check(not logo.visible, "map transition keeps title logo hidden (%d)" % i)
	await _shot("starward_stage_select")
	GameManager.screen = GameManager.Screen.MAIN_MENU
	title.show_screen(GameManager.Screen.MAIN_MENU)
	await get_tree().create_timer(1.9).timeout
	_check(not logo.visible, "returning to mode menu keeps title logo hidden")
	GameManager.screen = GameManager.Screen.TITLE
	title.show_screen(GameManager.Screen.TITLE, false)
	_check(logo.visible, "returning to title restores hand-drawn logo")
	title.free()
	print("TITLE_LOGO_RESULT passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
