## 導入の最小 UI。映像・練習の進行は IntroScreen が持つ。
extends CanvasLayer

var intro: Node
var hint: Label
var motive: Label
var draw_button: Button

func _ready() -> void:
	layer = 80
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skip := Button.new()
	skip.name = "SkipIntro"
	skip.text = tr("intro.skip")
	skip.pressed.connect(GameManager.finish_intro)
	root.add_child(skip)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -150
	skip.offset_right = -24
	skip.offset_top = 24
	skip.offset_bottom = 64
	hint = _label(root, 18, -100, -55)
	motive = _label(root, 28, -135, -65)
	motive.text = tr("intro.motive")
	motive.hide()
	draw_button = Button.new()
	draw_button.text = tr("intro.touch_draw")
	root.add_child(draw_button)
	draw_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	draw_button.offset_left = -170
	draw_button.offset_right = -24
	draw_button.offset_top = -160
	draw_button.offset_bottom = -104
	draw_button.pressed.connect(func(): RunManager.command(intro.session.id, &"draw_button"))
	draw_button.hide()
	var panel := PanelContainer.new()
	panel.name = "Pause"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -90
	panel.offset_bottom = 90
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	for item in [["hud.resume", intro._resume], ["common.to_main_menu", GameManager.reset_to_main_menu]]:
		var button := Button.new()
		button.text = tr(item[0])
		button.custom_minimum_size = Vector2(280, 56)
		button.pressed.connect(item[1])
		box.add_child(button)
	panel.hide()

func _label(root: Control, font_size: int, top: float, bottom: float) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 24
	label.offset_right = -24
	label.offset_top = top
	label.offset_bottom = bottom
	label.hide()
	return label
