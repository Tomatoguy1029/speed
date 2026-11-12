## デバッグ入口の表示設定を保存し、開いている画面と後から開く画面へ反映する。
extends "res://tests/integration/thrill_acceptance.gd"

class VisibilitySave:
	extends "res://scripts/managers/save_manager.gd"
	func settings_path() -> String:
		return "user://debug_button_visibility_test.cfg"
	func _apply_window_mode() -> void:
		pass
	func save() -> void:
		pass

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): shots = argument.trim_prefix("--out=")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	SaveManager.set_script(VisibilitySave)
	SaveManager.settings = SaveManager.default_settings()
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true
	_check(SaveManager.settings.show_debug_buttons, "existing settings default to visible debug buttons")
	var old_settings := ConfigFile.new()
	old_settings.set_value("settings", "muted", true)
	old_settings.save(SaveManager.settings_path())
	_check(SaveManager._load_settings().show_debug_buttons, "settings without the new key keep debug buttons visible")
	GameManager.screen = GameManager.Screen.TITLE
	var title: Control = load("res://scenes/app/title.tscn").instantiate()
	add_child(title)
	GameManager.screen = GameManager.Screen.UPGRADE
	var upgrade: Control = load("res://scenes/app/upgrade.tscn").instantiate()
	add_child(upgrade)
	await get_tree().process_frame
	var buttons: Array[Control] = [
		title.find_child("EnemyLabButton", true, false),
		title.find_child("BackgroundLabButton", true, false),
		title._map._debug_unlock,
		upgrade.find_child("DebugResetUpgrades", true, false),
		upgrade.find_child("DebugInfiniteParts", true, false),
	]
	for button in buttons:
		_check(button != null and button.visible, "debug entry starts visible: " + button.name)
	SaveManager.dev_infinite_parts = true
	title._map._debug_unlock.button_pressed = true
	var options: Control = load("res://scenes/app/settings.tscn").instantiate()
	add_child(options)
	options._select_tab(2)
	var checkbox := options.get_node("%Content").get_child(-1) as CheckBox
	_check(checkbox != null and checkbox.text == tr("settings.show_debug_buttons"), "controls tab ends with debug button visibility checkbox")
	checkbox.button_pressed = false
	for button in buttons:
		_check(not button.visible, "changing the option immediately hides: " + button.name)
	_check(SaveManager.dev_infinite_parts and title._map._debug_unlock.button_pressed, "hiding buttons keeps infinite parts and unlock state")
	_check(not SaveManager._load_settings().show_debug_buttons, "hidden setting survives loading the saved settings")
	title.menu_accessory.hide()
	title.menu_accessory.show()
	_check(not buttons[0].visible and not buttons[1].visible, "menu transition cannot reveal hidden lab buttons")
	var later: Control = load("res://scenes/app/upgrade.tscn").instantiate()
	add_child(later)
	_check(not later.find_child("DebugResetUpgrades", true, false).visible, "new screens honor the hidden setting")
	later.free()
	title.hide()
	upgrade.hide()
	await get_tree().process_frame
	options.get_node("%Scroll").scroll_vertical = 100000
	await _shot("controls_debug_buttons")
	checkbox.button_pressed = true
	for button in buttons:
		_check(button.visible, "re-enabling restores: " + button.name)
	_check(SaveManager._load_settings().show_debug_buttons, "visible setting survives reloading")
	options.free()
	upgrade.free()
	title.free()
	_check(get_tree().get_nodes_in_group(&"debug_buttons").is_empty(), "closing screens releases registered debug controls")
	SaveManager.dev_infinite_parts = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.settings_path()))
	print("DEBUG_BUTTON_VISIBILITY_RESULT passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
