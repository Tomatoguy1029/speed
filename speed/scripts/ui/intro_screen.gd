## 原画の配置を保ち、文章と重ね絵を順に再生する導入。
extends Control

const STORY := preload("res://scripts/ui/intro_story.gd")
const ART_SIZE := Vector2(640, 360)

@export_range(5.0, 100.0, 1.0) var characters_per_second := 28.0
@export_range(0.0, 10.0, 0.1) var text_hold_seconds := 2.8
@export_range(0.0, 3.0, 0.05) var scene_fade_seconds := 0.8
@export_range(0.0, 3.0, 0.05) var star_fade_seconds := 0.9
@export_range(0.0, 2.0, 0.05) var star_gap_seconds := 0.3

var scene_index := 0
var paragraph_index := 0
var _canvas: Control
var _picture: Control
var _text: Label
var _next: Button
var _auto_play: Button
var _hint: Label
var _stars: Array[TextureRect] = []
var _transition: Tween
var _transitioning := false
var _ending := false
var _characters := 0.0
var _hold := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = ART_SIZE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_canvas)
	var frame := _art(preload("res://assets/ui/intro/outline.png"), _canvas)
	frame.name = "ArtFrame"
	frame.z_index = 1
	var panel := ColorRect.new()
	panel.position = Vector2(64, 248)
	panel.size = Vector2(512, 100)
	panel.color = Color(0.02, 0.025, 0.05, 0.9)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 1
	_canvas.add_child(panel)
	_text = Label.new()
	_text.position = Vector2(82, 258)
	_text.size = Vector2(476, 66)
	_text.add_theme_font_override("font", preload("res://assets/ui/aseprite_font.tres"))
	_text.add_theme_font_size_override("font_size", 14)
	_text.add_theme_color_override("font_color", Color("e6f1f6"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_sibling(_text)
	_text.z_index = 2
	_hint = Label.new()
	_hint.position = Vector2(82, 328)
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.modulate = Color("92a7b3")
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.z_index = 2
	_canvas.add_child(_hint)
	_next = _button("NextIntro", tr("intro.next"), Vector2(492, 325), Vector2(66, 20))
	_next.pressed.connect(advance)
	_auto_play = _button("AutoPlayIntro", "", Vector2(378, 325), Vector2(106, 20))
	_auto_play.toggle_mode = true
	_auto_play.set_pressed_no_signal(bool(SaveManager.settings.get("intro_auto_advance", false)))
	_auto_play.toggled.connect(_set_auto_play)
	_update_playback_labels()
	var skip := _button("SkipIntro", tr("intro.skip"), Vector2(548, 10), Vector2(80, 23))
	skip.pressed.connect(func():
		AudioManager.play(&"ui.title.intro_skip")
		_finish())
	resized.connect(_layout)
	_layout()
	_show_scene(0)
	GameManager.screen_ready.emit(self)

func _button(node_name: String, caption: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 10)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.85)
	style.set_content_margin_all(3.0)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.z_index = 3
	_canvas.add_child(button)
	button.size = dimensions
	return button

func _set_auto_play(enabled: bool) -> void:
	SaveManager.set_setting("intro_auto_advance", enabled)
	# 切替前の待ち時間を持ち越さず、今の文章から読み進める。
	_hold = 0.0
	_update_playback_labels()

func _update_playback_labels() -> void:
	_auto_play.text = tr("intro.auto_on" if _auto_play.button_pressed else "intro.auto_off")
	_hint.text = tr("intro.auto_hint" if _auto_play.button_pressed else "intro.continue")

func _layout() -> void:
	if _canvas == null:
		return
	var factor := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - ART_SIZE * factor) * 0.5

func _art(texture: Texture2D, parent: Control) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = ART_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _show_scene(index: int) -> void:
	if index > 0: AudioManager.play(&"ui.title.intro_scene")
	scene_index = index
	paragraph_index = 0
	_stars.clear()
	_transitioning = true
	_text.text = ""
	_next.disabled = true
	var data: Dictionary = STORY.SCENES[index]
	var fade_target: CanvasItem
	if index == 1:
		# Scene1の原画を残し、竜のレイヤーだけを重ねてフェードする。
		fade_target = _art(data.layers[1], _picture)
	else:
		var previous := _picture
		var image := ColorRect.new()
		image.color = Color.BLACK
		image.size = ART_SIZE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(image)
		_picture = image
		for texture: Texture2D in data.layers:
			_art(texture, image)
		for texture: Texture2D in data.get("stars", []):
			_stars.append(_art(texture, image))
		fade_target = image
		if previous != null:
			# 前の絵は新しい絵のフェードが終わるまで保持する。
			_transition = create_tween()
			fade_target.modulate.a = 0.0
			_transition.tween_property(fade_target, "modulate:a", 1.0, scene_fade_seconds)
			_transition.tween_callback(previous.queue_free)
			_transition.tween_callback(_begin_paragraph)
			return
	fade_target.modulate.a = 0.0
	_transition = create_tween()
	_transition.tween_property(fade_target, "modulate:a", 1.0, scene_fade_seconds)
	_transition.tween_callback(_begin_paragraph)

func _begin_paragraph() -> void:
	_transitioning = false
	_characters = 0.0
	_hold = 0.0
	_text.text = tr(STORY.SCENES[scene_index].text[paragraph_index])
	_text.visible_characters = 0
	_next.disabled = false
	_next.text = tr("intro.reveal")

func _process(delta: float) -> void:
	if _transitioning or _ending or _text == null:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_characters += delta * characters_per_second
		var shown := _text.visible_characters
		_text.visible_characters = mini(int(_characters), total)
		if _text.visible_characters > shown: AudioManager.play(&"ui.title.intro_type")
		if _text.visible_characters == total:
			_next.text = tr("intro.next")
	elif _auto_play.button_pressed:
		_hold += delta
		if _hold >= text_hold_seconds:
			advance()

func advance() -> void:
	if _transitioning or _ending:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_characters = total
		_text.visible_characters = total
		_next.text = tr("intro.next")
		_hold = 0.0
		return
	if paragraph_index + 1 < STORY.SCENES[scene_index].text.size():
		paragraph_index += 1
		_begin_paragraph()
	elif not _stars.is_empty():
		_fade_stars()
	elif scene_index + 1 < STORY.SCENES.size():
		_show_scene(scene_index + 1)
	else:
		_finish()

func _fade_stars() -> void:
	_transitioning = true
	_next.disabled = true
	_transition = create_tween()
	for star in _stars:
		_transition.tween_property(star, "modulate:a", 0.0, star_fade_seconds)
		_transition.tween_interval(star_gap_seconds)
	_transition.tween_callback(_show_scene.bind(scene_index + 1))

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		advance()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.back()
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		advance()

func _finish() -> void:
	if _ending:
		return
	_ending = true
	if _transition != null:
		_transition.kill()
	GameManager.finish_intro()
