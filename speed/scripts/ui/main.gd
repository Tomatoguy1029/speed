## 起動時のシーンのルート。GameManager の画面に合わせて、表示する画面のシーンを差し替える。
##
## 起動側の予約があれば、タイトルの表示より先に受け付ける（設計書 14.1）。
extends Node

const SCREENS := {
	GameManager.Screen.TITLE: "res://scenes/app/title.tscn",
	GameManager.Screen.SETTINGS: "res://scenes/app/settings.tscn",
	GameManager.Screen.MAIN_MENU: "res://scenes/app/title.tscn",
	GameManager.Screen.STAGE_SELECT: "res://scenes/app/title.tscn",
	GameManager.Screen.UPGRADE: "res://scenes/app/upgrade.tscn",
	GameManager.Screen.ENCYCLOPEDIA: "res://scenes/app/encyclopedia.tscn",
	GameManager.Screen.RESULT: "res://scenes/app/result.tscn",
}

var _current: Node = null
var _prepared_run: RunSession
var _screen_request := 0
var _displayed_screen := -1
var _fade := preload("res://scripts/ui/screen_fade.gd").new()

## 仮の画面フェード。暗転と表示の時間を個別に調整する。
@export_range(0.0, 1.0, 0.01) var fade_out_time := 0.14
@export_range(0.0, 1.0, 0.01) var fade_in_time := 0.18

func _ready() -> void:
	add_child(_fade)
	GameManager.screen_changed.connect(_show)
	if GameManager.boot_request.is_valid() and GameManager.boot_request.call(): return
	_show(GameManager.screen)

func _show(screen: GameManager.Screen) -> void:
	if _prepared_run != null:
		_prepared_run.free()
		_prepared_run = null
	_screen_request += 1
	var request := _screen_request
	var fade: bool = (
		(_displayed_screen == GameManager.Screen.STAGE_SELECT and screen == GameManager.Screen.RUN)
		or (_displayed_screen == GameManager.Screen.RUN and screen == GameManager.Screen.RESULT)
		or (_displayed_screen == GameManager.Screen.RESULT and screen in [GameManager.Screen.RUN, GameManager.Screen.MAIN_MENU])
	)
	if fade:
		GameManager.screen_transition_active = true
		_current.process_mode = Node.PROCESS_MODE_DISABLED
		if screen == GameManager.Screen.RUN:
			_prepared_run = RunManager.create_run()
		await _fade.cover(fade_out_time)
		if request != _screen_request:
			return
	await _replace_screen(screen, request)
	if request != _screen_request:
		return
	_displayed_screen = screen
	# 最後の子で先に入力を受け、GUI やランへ演出中の操作を渡さない。
	move_child(_fade, -1)
	if fade:
		# 資源準備はフェード中も進め、戦闘の時計だけを保留する。
		if not _current is RunSession:
			_current.process_mode = Node.PROCESS_MODE_DISABLED
		await _fade.reveal(fade_in_time)
		if request != _screen_request: return
		_current.process_mode = Node.PROCESS_MODE_INHERIT
		if _current is RunSession: _current.auto_step = true
		GameManager.screen_transition_active = false

func _replace_screen(screen: GameManager.Screen, request: int) -> void:
	var morph: bool = screen == GameManager.Screen.UPGRADE and is_instance_valid(_current) and _current.has_method("can_morph_to_upgrade") and _current.can_morph_to_upgrade()
	var return_morph: bool = screen == GameManager.Screen.MAIN_MENU and is_instance_valid(_current) and _current.has_method("transition_to_menu")
	if morph:
		await _current.transition_to_upgrade()
		if request != _screen_request:
			return
	if return_morph:
		await _current.transition_to_menu()
		if request != _screen_request:
			return
	if screen in [GameManager.Screen.TITLE, GameManager.Screen.MAIN_MENU, GameManager.Screen.STAGE_SELECT] and is_instance_valid(_current) and _current.has_method("show_screen"):
		_current.show_screen(screen)
		return
	if _current != null:
		_current.queue_free()
		_current = null
	if screen == GameManager.Screen.RUN:
		_current = _prepared_run if _prepared_run != null else RunManager.create_run()
		_prepared_run = null
		_current.auto_step = false
	else:
		_current = (load(SCREENS.get(screen, GameManager.extension_screens.get(screen, ""))) as PackedScene).instantiate()
	if morph:
		_current.set_meta("fade_from_menu", true)
	if return_morph:
		_current.set_meta("morph_from_upgrade", true)
	add_child(_current)
	if screen == GameManager.Screen.RUN and not GameManager.screen_transition_active:
		_current.auto_step = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_prepared_run):
		_prepared_run.free()
