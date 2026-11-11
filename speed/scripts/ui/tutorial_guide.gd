## ポーズ中に開く操作ガイド。操作練習の説明パネルを一覧で見返す。
extends UiScreen

const LESSONS := preload("res://scripts/ui/tutorial_lessons.gd")
const PANEL := preload("res://scripts/ui/tutorial_panel.gd")
const DESIGN := Vector2(1280, 720)
var _canvas: Control

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
	add_child(_canvas)
	var column := VBoxContainer.new()
	column.size = DESIGN
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	_canvas.add_child(column)
	var title := Label.new()
	title.text = tr("tutorial.guide")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for lesson: Dictionary in LESSONS.LESSONS:
		var card := PANEL.new(lesson, 280.0, 18, 12, true)
		card.size_flags_vertical = Control.SIZE_FILL
		grid.add_child(card)
	var back := Button.new()
	back.name = "BackButton"
	back.unique_name_in_owner = true
	back.text = tr("common.back")
	back.custom_minimum_size = Vector2(240, 40)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back)
	column.add_child(back)
	resized.connect(_layout)

func _ready() -> void:
	super()
	_layout()

func _layout() -> void:
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - DESIGN * factor) * 0.5
