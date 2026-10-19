extends Control

signal back_requested
signal rotation_changed(radians: float)

const CYAN := Color("5bc8db")
const ORIGIN := Vector2(198, 195)
const CONSTELLATION_RADIUS := 84.0
const SYMBOL_ANGLES := [90.0, 180.0, 270.0, 0.0]
const TEXTURES := [
	preload("res://assets/ui/map/constellations_unicorn.png"),
	preload("res://assets/ui/map/constellations_centeur.png"),
	preload("res://assets/ui/map/constellations_dog.png"),
	preload("res://assets/ui/map/constellations_snake.png"),
]
var _stars: Array[TextureButton] = []
var _inner1: Sprite2D
var _inner2: Sprite2D
var _preview: TextureRect
var _heading: Label
var _status: Label
var _launch: Button
var _slider: HSlider
var _selected := 0
var _angle := 0.0
var _turn: Tween
var _projection: Node2D
var _origin := ORIGIN
var _flatten := 0.5
var _details: Control
var _detail_fade: Tween
var _transition_progress := 0.0
var _dragging := false

func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := _artwork(preload("res://assets/ui/map/selection_screen_ui.png"), self)
	var frame_material := ShaderMaterial.new()
	frame_material.shader = preload("res://assets/ui/map/selection_frame.gdshader")
	frame.material = frame_material
	var projection := Node2D.new()
	_projection = projection
	projection.position = ORIGIN
	projection.scale = Vector2(1, 0.5)
	add_child(projection)
	_inner1 = _ring(projection, preload("res://assets/ui/map/ui_inner_circle1.png"))
	_inner1.offset = Vector2(48, 1)
	_inner2 = _ring(projection, preload("res://assets/ui/map/ui_inner_circle2.png"))
	_inner2.offset = Vector2(61, 35)
	_inner2.scale = Vector2.ONE * 0.7
	for i in TEXTURES.size():
		var star := TextureButton.new()
		star.name = "Constellation%d" % (i + 1)
		star.texture_normal = TEXTURES[i]
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.tooltip_text = tr("stage.%d.name" % (i + 1))
		star.pressed.connect(select_constellation.bind(i))
		add_child(star)
		_stars.append(star)
	var back_fill := Polygon2D.new()
	back_fill.polygon = PackedVector2Array([Vector2(9, 9), Vector2(46, 9), Vector2(74, 34), Vector2(9, 34)])
	back_fill.color = Color("1f323d")
	add_child(back_fill)
	back_fill.hide()
	_artwork(preload("res://assets/ui/map/selection_screen_back_button.png"), self)
	var back := _button("", Vector2(7, 7), Vector2(74, 30))
	back.tooltip_text = tr("common.back")
	_transparent_button(back)
	back.mouse_entered.connect(back_fill.show)
	back.mouse_exited.connect(back_fill.hide)
	back.focus_entered.connect(back_fill.show)
	back.focus_exited.connect(back_fill.hide)
	back.pressed.connect(func(): back_requested.emit())
	_details = Control.new()
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.size = size
	add_child(_details)
	_artwork(preload("res://assets/ui/map/selection_screen_decorations.png"), _details)
	_preview = TextureRect.new()
	_preview.position = Vector2(451, 88)
	_preview.size = Vector2(135, 82)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(_preview)
	_heading = _label(Vector2(444, 188), Vector2(152, 38), 14)
	_status = _label(Vector2(444, 235), Vector2(152, 24), 10)
	_launch = _button(tr("stage_select.launch"), Vector2(431, 293), Vector2(175, 34))
	_transparent_button(_launch)
	for content: Control in [_heading, _status, _launch]:
		content.reparent(_details)
	_launch.pressed.connect(_start)
	if ConfigManager.stage_count() > 4:
		var final_stage := _button(tr("stage.5.name"), Vector2(224, 333), Vector2(150, 16))
		final_stage.add_theme_font_size_override("font_size", 11)
		_transparent_button(final_stage)
		final_stage.size = Vector2(150, 16)
		final_stage.pressed.connect(func():
			if _turn != null:
				_turn.kill()
			_select(4)
			_reveal_details()
		)
	_slider = HSlider.new()
	_slider.position = Vector2(34, 333)
	_slider.size = Vector2(170, 14)
	_slider.min_value = -180
	_slider.max_value = 180
	_slider.step = 0.1
	_slider.value_changed.connect(_slide)
	_slider.drag_started.connect(func(): _dragging = true)
	_slider.drag_ended.connect(func(_changed: bool):
		_dragging = false
		select_constellation(posmod(roundi(-_angle / 90.0), 4))
	)
	add_child(_slider)
	_select(0)
	_apply_rotation(0.0)
	_hide_details()

func _artwork(texture: Texture2D, parent: Control) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = Vector2(640, 360)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _transparent_button(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_hover_color", CYAN)

func _hide_details() -> void:
	if _detail_fade != null:
		_detail_fade.kill()
	_details.modulate.a = 0.0
	_details.hide()

func _reveal_details() -> void:
	if _transition_progress < 1.0:
		return
	_hide_details()
	_details.show()
	_detail_fade = create_tween()
	_detail_fade.tween_property(_details, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)

func _ring(parent: Node2D, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite

func _button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 16)
	add_child(button)
	return button

func _label(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func select_constellation(index: int) -> void:
	if _turn != null:
		_turn.kill()
	_hide_details()
	_select(index)
	var target := _angle + wrapf(90.0 - SYMBOL_ANGLES[index] - _angle, -180.0, 180.0)
	_turn = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_turn.tween_method(_apply_rotation, _angle, target, 0.65)
	_turn.tween_callback(_reveal_details)

func _slide(value: float) -> void:
	if _turn != null:
		_turn.kill()
	_hide_details()
	_select(posmod(roundi(-value / 90.0), 4))
	_apply_rotation(value)
	if not _dragging:
		_turn = create_tween()
		_turn.tween_interval(0.15)
		_turn.tween_callback(func(): select_constellation(_selected))

func _select(index: int) -> void:
	_selected = index
	var stage := index + 1
	var unlocked := OS.is_debug_build() or SaveManager.is_stage_unlocked(stage)
	_heading.text = tr("stage.%d.name" % stage)
	_preview.texture = TEXTURES[index] if index < TEXTURES.size() else null
	_launch.disabled = not unlocked
	_status.text = tr("stage_select.debug") if OS.is_debug_build() else (tr("stage_select.available") if unlocked else tr("stage_select.locked").format({n = stage}))
	_apply_rotation(_angle)

func _apply_rotation(degrees: float) -> void:
	_angle = degrees
	var radians := deg_to_rad(degrees)
	rotation_changed.emit(radians)
	_inner1.position = Vector2(0, -48).rotated(-radians)
	_inner1.rotation = -radians * 5.0
	_inner2.position = _inner1.position + Vector2(-40, 38).rotated(radians)
	_inner2.rotation = radians * 35.0 / 30.0
	for i in _stars.size():
		var angle := deg_to_rad(degrees + SYMBOL_ANGLES[i])
		var depth := sin(angle)
		var factor := 0.85 + depth * 0.15
		var star := _stars[i]
		star.scale = Vector2.ONE * factor
		star.position = _origin + Vector2(cos(angle), depth * _flatten) * CONSTELLATION_RADIUS - TEXTURES[i].get_size() * factor * 0.5
		star.z_index = roundi(10 + depth * 4)
		star.modulate = Color.WHITE if i == _selected else Color(0.55, 0.55, 0.55)
	if _slider != null:
		_slider.set_value_no_signal(wrapf(degrees, -180.0, 180.0))

func set_transition(progress: float) -> void:
	_transition_progress = progress
	if progress < 1.0:
		_hide_details()
	_origin = Vector2(462, 176).lerp(ORIGIN, progress)
	_flatten = lerpf(1.0, 0.5, progress)
	_projection.position = _origin
	_projection.scale.y = _flatten
	_apply_rotation(_angle)

func focus_selection() -> void:
	_stars[mini(_selected, 3)].grab_focus()
	_reveal_details()

func _start() -> void:
	if OS.is_debug_build() or SaveManager.is_stage_unlocked(_selected + 1):
		AudioManager.play(&"ui")
		GameManager.start_run(_selected + 1)
