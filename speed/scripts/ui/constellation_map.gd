extends Control

signal back_requested

const CYAN := Color("5bc8db")
const ORIGIN := Vector2(198, 195)
const TEXTURES := [
	preload("res://assets/ui/map/constellations_unicorn.png"),
	preload("res://assets/ui/map/constellations_centeur.png"),
	preload("res://assets/ui/map/constellations_dog.png"),
	preload("res://assets/ui/map/constellations_snake.png"),
]
var _stars: Array[TextureButton] = []
var _outer: Sprite2D
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

func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var projection := Node2D.new()
	_projection = projection
	projection.position = ORIGIN
	projection.scale = Vector2(1, 0.5)
	add_child(projection)
	_outer = _ring(projection, preload("res://assets/ui/map/ui_circle.png"))
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
	var back := _button(tr("common.back"), Vector2(24, 18), Vector2(70, 28))
	back.pressed.connect(func(): back_requested.emit())
	_preview = TextureRect.new()
	_preview.position = Vector2(420, 50)
	_preview.size = Vector2(172, 106)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)
	_heading = _label(Vector2(420, 175), Vector2(172, 50), 16)
	_status = _label(Vector2(420, 229), Vector2(172, 38), 12)
	_launch = _button(tr("stage_select.launch"), Vector2(420, 275), Vector2(172, 38))
	_launch.pressed.connect(_start)
	if ConfigManager.stage_count() > 4:
		var final_stage := _button(tr("stage.5.name"), Vector2(224, 304), Vector2(150, 24))
		final_stage.add_theme_font_size_override("font_size", 11)
		final_stage.pressed.connect(func(): _select(4))
	_slider = HSlider.new()
	_slider.position = Vector2(34, 300)
	_slider.size = Vector2(170, 24)
	_slider.min_value = -180
	_slider.max_value = 180
	_slider.step = 0.1
	_slider.value_changed.connect(_slide)
	add_child(_slider)
	_select(0)
	_apply_rotation(0.0)

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

func _draw() -> void:
	draw_rect(Rect2(14, 14, 612, 332), CYAN, false, 1)
	draw_line(Vector2(112, 24), Vector2(616, 24), CYAN)
	draw_rect(Rect2(402, 32, 208, 298), Color("20343e"))
	draw_rect(Rect2(402, 32, 208, 298), CYAN, false)
	draw_rect(Rect2(418, 48, 176, 110), Color("03151d"))
	draw_rect(Rect2(418, 48, 176, 110), CYAN, false)

func select_constellation(index: int) -> void:
	if _turn != null:
		_turn.kill()
	_select(index)
	var target := _angle + wrapf(-index * 90.0 - _angle, -180.0, 180.0)
	_turn = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_turn.tween_method(_apply_rotation, _angle, target, 0.65)

func _slide(value: float) -> void:
	if _turn != null:
		_turn.kill()
	_select(posmod(roundi(-value / 90.0), 4))
	_apply_rotation(value)

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
	_outer.rotation = radians
	_inner1.position = Vector2(0, -48).rotated(-radians)
	_inner1.rotation = -radians * 5.0
	_inner2.position = _inner1.position + Vector2(-40, 38).rotated(radians)
	_inner2.rotation = radians * 35.0 / 30.0
	for i in _stars.size():
		var angle := deg_to_rad(degrees + i * 90.0 + 90.0)
		var depth := sin(angle)
		var factor := 0.85 + depth * 0.15
		var star := _stars[i]
		star.scale = Vector2.ONE * factor
		star.position = _origin + Vector2(cos(angle), depth * _flatten) * 108.0 - TEXTURES[i].get_size() * factor * 0.5
		star.z_index = roundi(10 + depth * 4)
		star.modulate = Color.WHITE if i == _selected else Color(0.55, 0.55, 0.55)
	if _slider != null:
		_slider.set_value_no_signal(wrapf(degrees, -180.0, 180.0))

func set_transition(progress: float) -> void:
	_origin = Vector2(462, 176).lerp(ORIGIN, progress)
	_flatten = lerpf(1.0, 0.5, progress)
	_projection.position = _origin
	_projection.scale.y = _flatten
	_apply_rotation(_angle)

func focus_selection() -> void:
	_stars[mini(_selected, 3)].grab_focus()

func _start() -> void:
	if OS.is_debug_build() or SaveManager.is_stage_unlocked(_selected + 1):
		AudioManager.play(&"ui")
		GameManager.start_run(_selected + 1)
