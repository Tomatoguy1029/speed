## 原画の結果画面にランの記録を重ねる。
extends UiScreen

const CLEARED := preload("res://assets/ui/results/stage_cleared.png")
const FAILED := preload("res://assets/ui/results/game_over_screen.png")
const RESULT_FONT := preload("res://assets/ui/aseprite_font.tres")
const DESIGN_SIZE := Vector2(640, 360)
## 数え上げを始めるまでの秒数・1項目を数え上げる秒数・加算の音の最短間隔
const COUNT_DELAY := 0.2
const COUNT_TIME := 0.5
const COUNT_TICK := 0.05

var _last_tick := -1.0

func _ready() -> void:
	can_go_back = false
	%Modules.add_theme_font_override("font", RESULT_FONT)
	var result := GameManager.last_result
	var cleared: bool = result.get("cleared", false)
	%Heading.text = tr("result.cleared") if cleared else tr("result.failed")
	%Artwork.texture = CLEARED if cleared else FAILED
	var seconds := maxi(0, int(result.get("time", 0.0)))
	_count_up([
		[_value(Rect2(175, 89, 139, 24)), seconds, true],
		[_value(Rect2(175, 130, 139, 24)), int(result.get("coins", 0)), false],
		[_value(Rect2(175, 176, 139, 24)), int(result.get("level", 1)), false],
		[_value(Rect2(175, 221, 139, 24)), int(result.get("kills", 0)), false],
	])
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

## 記録を上から順に0から数え上げ、数字が進むたびに加算の音を鳴らす。
func _count_up(rows: Array) -> void:
	for row: Array in rows:
		_show_count(row[0], 0, row[2])
	var tween := create_tween()
	tween.tween_interval(COUNT_DELAY)
	for row: Array in rows:
		if int(row[1]) > 0:
			tween.tween_method(_step_count.bind(row[0], row[2]), 0.0, float(row[1]), COUNT_TIME)

func _step_count(value: float, label: Label, clock: bool) -> void:
	var before := label.text
	_show_count(label, roundi(value), clock)
	if label.text == before: return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_tick < COUNT_TICK: return
	_last_tick = now
	AudioManager.play(&"ui.result.count")

func _show_count(label: Label, value: int, clock: bool) -> void:
	label.text = "%d:%02d" % [value / 60, value % 60] if clock else str(value)

func _value(rect: Rect2) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", RESULT_FONT)
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("56cee1"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Canvas.add_child(label)
	return label

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
