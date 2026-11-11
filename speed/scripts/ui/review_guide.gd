extends Node
const SPOTLIGHT := preload("res://scripts/ui/review_spotlight.gd")
var _skip := false

func _process(_delta: float) -> void:
	if not has_meta("title_screen"): return
	var main := get_tree().current_scene
	if main == null or not main.get("startup_complete"): return
	var screen: Control = get_meta("title_screen")
	remove_meta("title_screen")
	title(screen)


func show_step(target: Control, key: String, action := false) -> void:
	if _skip: return
	var layer := CanvasLayer.new()
	layer.layer = 110
	preload("res://scripts/ui/canvas_order.gd").register(layer, 1)
	add_child(layer)
	var overlay := SPOTLIGHT.new()
	overlay.target = target
	overlay.message = key
	overlay.action = action
	layer.add_child(overlay)
	await overlay.finished
	_skip = overlay.get_meta("skipped", false)
	layer.queue_free()
	await get_tree().process_frame

func _done(key: String) -> void:
	SaveManager.settings[key] = true
	SaveManager._save_settings()
	queue_free()

func title(screen: Control) -> void:
	if not SaveManager.is_review_build() or SaveManager.settings.get("review_guide_title", false):
		queue_free()
		return
	await get_tree().process_frame
	await show_step(null, "review.guide.welcome")
	await show_step(screen.get_node("%SettingsButton"), "review.guide.settings")
	if screen.get_node("%QuitButton").visible:
		await show_step(screen.get_node("%QuitButton"), "review.guide.quit")
	await show_step(screen.get_node("%StartButton"), "review.guide.start", true)
	if not _skip:
		for button in screen._menu_options.get_children():
			if button != screen._stage_button:
				await show_step(button, "review.guide.upgrade" if button.get_index() == 1 else "review.guide.codex")
	await show_step(screen._stage_button, "review.guide.stage", true)
	_done("review_guide_title")

func map(screen: Control) -> void:
	if not SaveManager.is_review_build() or SaveManager.settings.get("review_guide_map", false):
		queue_free()
		return
	await get_tree().create_timer(1.4).timeout
	await show_step(screen._debug_unlock, "review.guide.unlock")
	await show_step(screen._launch, "review.guide.launch", true)
	_done("review_guide_map")

func run(hud: Control) -> void:
	if not SaveManager.is_review_build() or SaveManager.settings.get("review_guide_run", false):
		queue_free()
		return
	# 操作練習が終了した直後の、通常プレイへ戻る境目で停止する。
	hud.bridge.command("pause", {"paused": true})
	await show_step(null, "review.guide.pause", true)
	await get_tree().process_frame
	await show_step(hud.find_child("ReviewSettingsButton", true, false), "review.guide.custom", true)
	_done("review_guide_run")

func settings(panel: Control) -> void:
	if not SaveManager.is_review_build() or SaveManager.settings.get("review_guide_settings", false):
		queue_free()
		return
	await get_tree().process_frame
	for key: String in ["weapon", "trait", "hero", "meta", "invincible", "boss"]:
		var target: Control = panel.get_meta("guide_" + key, null)
		if target != null:
			panel.get_meta("guide_scroll").ensure_control_visible(target)
			await get_tree().process_frame
			await show_step(target, "review.guide." + key)
	await show_step(null, "review.guide.finish")
	_done("review_guide_settings")
