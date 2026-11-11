## その画面に必要な説明を一度だけ表示する。画面移動や操作を制限しない。
extends Node
const SPOTLIGHT := preload("res://scripts/ui/review_spotlight.gd")
var _notice: Control
var _hud: Control
var _pause_hud: Control

func _process(_delta: float) -> void:
	if is_instance_valid(_pause_hud) and not _pause_hud._pause_box.visible:
		queue_free()
		return
	if has_meta("title_screen"):
		var main := get_tree().current_scene
		if main == null or not main.get("startup_complete"): return
		remove_meta("title_screen")
		if GameManager.screen == GameManager.Screen.TITLE:
			_show("title", null, "review.guide.welcome")
		else:
			queue_free()
	if is_instance_valid(_hud) and is_instance_valid(_notice):
		if int(_hud._cpp_ui.get("phase", -1)) == 2:
			queue_free()

func _show(section: String, target: Control, message: String) -> void:
	var key := "review_guide_" + section
	if not SaveManager.is_review_build() or SaveManager.settings.get(key, false):
		queue_free()
		return
	var layer := CanvasLayer.new()
	layer.layer = 110
	preload("res://scripts/ui/canvas_order.gd").register(layer, 1)
	add_child(layer)
	_notice = SPOTLIGHT.new()
	_notice.target = target
	_notice.message = message
	layer.add_child(_notice)
	_notice.finished.connect(queue_free)
	GameManager.screen_changed.connect(_leave_screen)
	SaveManager.settings[key] = true
	SaveManager._save_settings()

func _leave_screen(_screen: int) -> void:
	queue_free()

func map(screen: Control) -> void:
	if not SaveManager.is_review_build():
		queue_free()
		return
	await get_tree().create_timer(1.4).timeout
	if GameManager.screen != GameManager.Screen.STAGE_SELECT:
		queue_free()
		return
	_show("map", screen._debug_unlock, "review.guide.unlock")

func run(hud: Control) -> void:
	_hud = hud
	_show("run", null, "review.guide.pause")

func pause_menu(hud: Control) -> void:
	_pause_hud = hud
	await get_tree().process_frame
	if not hud._pause_box.visible:
		queue_free()
		return
	_show("pause", hud._review_entry, "review.guide.custom")
	if is_instance_valid(_notice): _notice.top_aligned = true
