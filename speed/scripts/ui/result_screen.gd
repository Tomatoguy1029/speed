## 原画の結果画面にランの記録を重ねる。
extends UiScreen

const CLEARED := preload("res://assets/ui/results/stage_cleared.png")
const FAILED := preload("res://assets/ui/results/game_over_screen.png")
const RESULT_FONT := preload("res://assets/ui/aseprite_font.tres")
const DESIGN_SIZE := Vector2(640, 360)

func _ready() -> void:
	can_go_back = false
	%Modules.add_theme_font_override("font", RESULT_FONT)
	var result := GameManager.last_result
	var cleared: bool = result.get("cleared", false)
	%Heading.text = tr("result.cleared") if cleared else tr("result.failed")
	%Artwork.texture = CLEARED if cleared else FAILED
	var seconds := maxi(0, int(result.get("time", 0.0)))
	_value("%d:%02d" % [seconds / 60, seconds % 60], Rect2(175, 89, 139, 24))
	_value(str(result.get("coins", 0)), Rect2(175, 130, 139, 24))
	_value(str(result.get("level", 1)), Rect2(175, 176, 139, 24))
	_value(str(result.get("kills", 0)), Rect2(175, 221, 139, 24))
	%Scroll.visible = cleared
	AudioManager.play(&"ui.result.show")
	if result.get("new_record", false): AudioManager.play(&"ui.result.record")
	if cleared:
		_show_modules(result)
		if not result.get("modules", []).is_empty() or not str(result.get("legendary", "")).is_empty(): AudioManager.play(&"ui.result.module")
	%RetryButton.pressed.connect(func(): AudioManager.play(&"ui.common.confirm"); GameManager.retry_run())
	%MenuButton.pressed.connect(func(): AudioManager.play(&"ui.common.confirm"); GameManager.reset_to_main_menu())
	resized.connect(_fit_canvas)
	_fit_canvas()
	super()

func _fit_canvas() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	%Canvas.scale = Vector2.ONE * factor
	%Canvas.position = ((size - DESIGN_SIZE * factor) * 0.5).floor()

func _value(value: String, rect: Rect2) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", RESULT_FONT)
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("56cee1"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Canvas.add_child(label)

func _show_modules(result: Dictionary) -> void:
	var ids: Array = result.get("modules", []).duplicate()
	var legendary := str(result.get("legendary", ""))
	if not legendary.is_empty() and not ids.has(legendary):
		ids.append(legendary)
	var names := PackedStringArray()
	for id in ids:
		for category in [&"weapons", &"traits", &"legendary_modules"]:
			var entry = ContentManager.catalog.find(category, StringName(id))
			if entry != null:
				var display_name: String = entry.get_display_name()
				if not names.has(display_name):
					names.append(display_name)
				break
	%Modules.text = "\n".join(names) if not names.is_empty() else "—"
