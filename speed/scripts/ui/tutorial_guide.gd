## ポーズ中に開く操作ガイド。操作練習の説明パネルを1枚ずつめくって見返す。
extends UiScreen

const LESSONS := preload("res://scripts/ui/tutorial_lessons.gd")
const PANEL := preload("res://scripts/ui/tutorial_panel.gd")
const DESIGN := Vector2(640, 360)
var _canvas: Control
var _title: Label
var _holder: CenterContainer
var _page := 0

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_canvas = Control.new()
	_canvas.size = DESIGN
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_canvas)
	var column := VBoxContainer.new()
	column.size = DESIGN
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 5)
	_canvas.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 11)
	column.add_child(_title)
	_holder = CenterContainer.new()
	column.add_child(_holder)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for item: Array in [["tutorial.guide.prev", _turn.bind(-1), ""], ["common.back", _on_back, "BackButton"], ["tutorial.guide.next", _turn.bind(1), ""]]:
		var button := Button.new()
		button.text = tr(item[0])
		button.custom_minimum_size = Vector2(80, 18)
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(item[1])
		if item[2] != "":
			button.name = item[2]
		row.add_child(button)
	resized.connect(_layout)
	_show(0)

func _ready() -> void:
	super()
	_layout()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		get_viewport().set_input_as_handled()
		_turn(-1)
	elif event.is_action_pressed(&"ui_right"):
		get_viewport().set_input_as_handled()
		_turn(1)
	else:
		super(event)

func _turn(step: int) -> void:
	AudioManager.play(&"ui.common.confirm")
	_show(posmod(_page + step, LESSONS.LESSONS.size()))

func _show(page: int) -> void:
	_page = page
	for child in _holder.get_children():
		child.queue_free()
	_holder.add_child(PANEL.new(LESSONS.LESSONS[page]))
	_title.text = "%s　%d / %d" % [tr("tutorial.guide"), page + 1, LESSONS.LESSONS.size()]

func _layout() -> void:
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - DESIGN * factor) * 0.5
