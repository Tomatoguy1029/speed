## 画面の確認用：決まった手順で画面を移り、それぞれの画面を PNG に保存する（tasks/plan.md の確認のコマンド）。
## 実行中はセーブを退避し、終わったら元に戻す。
##
##   Godot --path speed res://tests/screen_capture.tscn -- --out=<フォルダ> [--steps=flow|run]
extends Node

const SAVE := "user://save.json"
const BACKUP := "user://save.json.capture_backup"

var out_dir := "user://captures"
var steps := "flow"
var main: Node

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--steps="):
			steps = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_backup()
	SaveManager.data = SaveManager.default_data()
	main = load("res://scenes/app/main.tscn").instantiate()
	add_child(main)
	await _wait(0.5)
	match steps:
		"run":
			await _run_steps()
		_:
			await _flow_steps()
	_restore()
	get_tree().quit()

func _flow_steps() -> void:
	await _shot("01_title")
	GameManager.goto(GameManager.Screen.SETTINGS)
	await _shot("02_settings")
	GameManager.back()
	GameManager.goto(GameManager.Screen.MAIN_MENU)
	await _shot("03_main_menu")
	GameManager.goto(GameManager.Screen.STAGE_SELECT)
	await _shot("04_stage_select")
	GameManager.start_run(1)
	await _shot("05_run")
	_run_manager().command(&"debug_clear")
	await _shot("06_result")
	GameManager.reset_to_main_menu()
	GameManager.goto(GameManager.Screen.STAGE_SELECT)
	await _shot("07_stage_select_after_clear")
	GameManager.back()
	GameManager.goto(GameManager.Screen.UPGRADE)
	await _shot("08_upgrade")
	GameManager.back()
	GameManager.goto(GameManager.Screen.ENCYCLOPEDIA)
	await _shot("09_encyclopedia")

## ランの中の確認（段階2以降で使う）。
func _run_steps() -> void:
	GameManager.start_run(1)
	for i in 6:
		await _shot("run_%02d" % i, 1.0)

func _run_manager() -> RunManager:
	return get_tree().root.find_child("RunManager", true, false) as RunManager

func _shot(name: String, wait := 0.4) -> void:
	await _wait(wait)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("[capture] ", name)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _backup() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE), ProjectSettings.globalize_path(BACKUP))

func _restore() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP), ProjectSettings.globalize_path(SAVE))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
