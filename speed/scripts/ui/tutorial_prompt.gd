## 初回の操作練習で、段の前に出す説明。クリック・タップ・決定で閉じる。
extends Control

signal closed
const PANEL := preload("res://scripts/ui/tutorial_panel.gd")
const DESIGN := Vector2(1280, 720)
var _canvas: Control
var _hint: Label
var _clock := 0.0
var _accept_at := 0

func _init(lesson: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_canvas = Control.new()
	_canvas.size = DESIGN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	var center := CenterContainer.new()
	center.size = DESIGN
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	column.add_child(PANEL.new(lesson))
	_hint = Label.new()
	_hint.text = tr("tutorial.next")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color("5fe3ff"))
	column.add_child(_hint)
	resized.connect(_layout)
	# 直前の操作の押下で閉じないよう、少し待ってから受け付ける。
	_accept_at = Time.get_ticks_msec() + 500

func _ready() -> void:
	_layout()

func _layout() -> void:
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - DESIGN * factor) * 0.5

func _process(delta: float) -> void:
	_clock += delta
	_hint.modulate.a = 0.55 + 0.45 * sin(_clock * 4.0)

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if Time.get_ticks_msec() < _accept_at:
		return
	AudioManager.play(&"ui.common.confirm")
	closed.emit()
