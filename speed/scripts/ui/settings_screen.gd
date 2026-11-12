## 設定（仕様書 3）。音量・演出・画面モード・キー設定。変えるとすぐ反映し、設定のファイルに保存する。
extends UiScreen

const LAYOUT_ART := preload("res://assets/ui/options/layout.png")
const GADGET_ART := preload("res://assets/ui/options/gadgets.png")
const TAB_ART := [
	LAYOUT_ART,
	preload("res://assets/ui/options/layout_display.png"),
	preload("res://assets/ui/options/layout_controls.png"),
]
const TAB_WIDTHS := [76, 116, 82]
const TAB_NAMES := ["音量", "画面／演出", "操作"]
const OPTION_ROW := Rect2(220, 136, 126, 26)
const VOLUMES := ["master_volume", "sfx_volume", "music_volume", "engine_volume"]
const WINDOW_MODES := ["windowed", "fullscreen", "exclusive"]

## キーの割り当てを待っているアクション（なければ空）
var _waiting: StringName = &""
var _bind_buttons: Dictionary = {}
var _tab := 0
var _tab_group := ButtonGroup.new()
var _display_header: Button
var _focus_skin: StyleBoxFlat

func _ready() -> void:
	_setup_art()
	_build()
	super()

## 選択されたタブの項目を並べる。
func _build() -> void:
	for c in %Content.get_children():
		%Content.remove_child(c)
		c.queue_free()
	_display_header = null
	_bind_buttons.clear()
	_waiting = &""
	%Scroll.scroll_vertical = 0
	match _tab:
		0:
			for key in VOLUMES:
				_slider_row(key, tr("settings." + key))
			_toggle("muted", "settings.mute")
		1:
			_slider_row("screen_shake", tr("settings.screen_shake"))
			_toggle("hitstop", "settings.hitstop")
			_toggle("intro_auto_advance", "settings.intro_auto_advance")
			_section(tr("settings.window_mode"))
			_display_dropdown()
		2:
			_build_bindings()
			_toggle("show_debug_buttons", "settings.show_debug_buttons")

func _toggle(key: String, label_key: String) -> void:
	var box := CheckBox.new()
	box.text = tr(label_key)
	box.button_pressed = bool(SaveManager.settings[key])
	box.add_theme_icon_override("unchecked", _region(GADGET_ART, Rect2(42, 260, 30, 30)))
	box.add_theme_icon_override("checked", _region(GADGET_ART, Rect2(42, 308, 30, 30)))
	box.add_theme_constant_override("h_separation", 16)
	box.add_theme_stylebox_override("focus", _focus_skin)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.toggled.connect(func(on): SaveManager.set_setting(key, on))
	%Content.add_child(box)

func _build_bindings() -> void:
	_section(tr("settings.key_bindings"))
	for action in InputActions.REBINDABLE:
		_binding_row(action, tr("action." + action))
	var reset := Button.new()
	reset.text = tr("settings.reset_bindings")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.flat = true
	reset.add_theme_stylebox_override("focus", _focus_skin)
	reset.pressed.connect(_reset_bindings)
	%Content.add_child(reset)

func _display_dropdown() -> void:
	var dropdown := VBoxContainer.new()
	dropdown.add_theme_constant_override("separation", 2)
	%Content.add_child(dropdown)

	var header := _art_button(Rect2(42, 66, 162, 30), 36)
	_display_header = header
	header.toggle_mode = true
	var selected := String(SaveManager.settings.window_mode)
	if selected not in WINDOW_MODES:
		selected = WINDOW_MODES[0]
	header.text = tr("settings." + selected)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	dropdown.add_child(header)

	var opened := _skin(GADGET_ART, Rect2(42, 104, 162, 30), 0, 0, 0)
	opened.content_margin_left = 8
	opened.content_margin_right = 72
	header.add_theme_stylebox_override("pressed", opened)
	header.add_theme_stylebox_override("hover_pressed", opened)

	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 4)
	inset.hide()
	dropdown.add_child(inset)
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 0)
	inset.add_child(choices)
	var selected_button: Button
	for mode in WINDOW_MODES:
		var choice := _art_button(OPTION_ROW)
		choice.text = tr("settings." + mode)
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choices.add_child(choice)
		if mode == selected:
			selected_button = choice
		choice.pressed.connect(func():
			SaveManager.set_setting("window_mode", mode)
			header.text = choice.text
			header.button_pressed = false
			header.grab_focus())
	header.toggled.connect(func(open: bool):
		inset.visible = open
		if open:
			selected_button.grab_focus())

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_display_header) and _display_header.button_pressed and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_display_header.button_pressed = false
		_display_header.grab_focus()
		return
	super(event)

func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	%Content.add_child(l)

func _slider_row(key: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size = Vector2(220, 0)
	label.text = label_text
	row.add_child(label)
	var s := HSlider.new()
	s.custom_minimum_size = Vector2(492, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := _skin(GADGET_ART, Rect2(42, 226, 246, 16), 0, 0, 8)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	s.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	s.draw.connect(func():
		if s.has_focus():
			s.draw_style_box(_focus_skin, Rect2(Vector2.ZERO, s.size)))
	var thumb := _region(GADGET_ART, Rect2(332, 228, 12, 12))
	s.add_theme_icon_override("grabber", thumb)
	s.add_theme_icon_override("grabber_highlight", thumb)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(SaveManager.settings[key])
	var value := Label.new()
	value.custom_minimum_size.x = 70
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text = "%d%%" % roundi(s.value * 100)
	s.value_changed.connect(func(v):
		value.text = "%d%%" % roundi(v * 100)
		SaveManager.set_setting(key, v))
	row.add_child(s)
	row.add_child(value)
	%Content.add_child(row)

func _binding_row(action: StringName, label_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size = Vector2(300, 0)
	label.text = label_text
	row.add_child(label)
	var b := _art_button(OPTION_ROW)
	b.pressed.connect(func(): _wait_for_key(action))
	row.add_child(b)
	_bind_buttons[action] = b
	_refresh_binding(action)
	%Content.add_child(row)

func _refresh_binding(action: StringName) -> void:
	var code := InputActions.key_of(action)
	_bind_buttons[action].text = OS.get_keycode_string(code) if code != 0 else tr("settings.no_key")

func _wait_for_key(action: StringName) -> void:
	_waiting = action
	_bind_buttons[action].text = tr("settings.press_key")

func _input(event: InputEvent) -> void:
	if _waiting == &"" or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var action := _waiting
	_waiting = &""
	SaveManager.set_binding(action, event.physical_keycode)
	_refresh_binding(action)

func _reset_bindings() -> void:
	SaveManager.settings.bindings = {}
	SaveManager.set_setting("bindings", {})
	for action in _bind_buttons:
		_refresh_binding(action)


func _setup_art() -> void:
	%HeaderArt.texture = _region(LAYOUT_ART, Rect2(7, 7, 344, 30))
	var frame := _skin(LAYOUT_ART, Rect2(7, 35, 626, 325), 2, 13, 3)
	frame.content_margin_left = 70
	frame.content_margin_right = 18
	frame.content_margin_top = 52
	frame.content_margin_bottom = 20
	%Panel.add_theme_stylebox_override("panel", frame)
	_focus_skin = StyleBoxFlat.new()
	_focus_skin.bg_color = Color.TRANSPARENT
	_focus_skin.border_color = Color("#a5dae5")
	_focus_skin.set_border_width_all(2)
	%BackButton.add_theme_stylebox_override("focus", _focus_skin)
	var blank := StyleBoxEmpty.new()
	for i in TAB_ART.size():
		var tab := Button.new()
		tab.tooltip_text = TAB_NAMES[i]
		tab.custom_minimum_size = Vector2(TAB_WIDTHS[i] * 2, 56)
		tab.toggle_mode = true
		tab.button_group = _tab_group
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			tab.add_theme_stylebox_override(state, blank)
		tab.add_theme_stylebox_override("focus", _focus_skin)
		%Tabs.add_child(tab)
		tab.set_pressed_no_signal(i == _tab)
		tab.pressed.connect(_select_tab.bind(i))
	var scroll := %Scroll.get_v_scroll_bar() as VScrollBar
	scroll.custom_minimum_size.x = 10
	var grip := _skin(GADGET_ART, Rect2(619, 44, 5, 31), 2, 2, 4)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scroll.add_theme_stylebox_override(state, grip)
	scroll.add_theme_stylebox_override("scroll", blank)
	scroll.add_theme_stylebox_override("scroll_focus", _focus_skin)

func _select_tab(index: int) -> void:
	if _tab != index:
		_tab = index
		%HeaderArt.texture = _region(TAB_ART[_tab], Rect2(7, 7, 344, 30))
		_build()

func _art_button(rect: Rect2, right_padding := 4) -> Button:
	var button := Button.new()
	button.custom_minimum_size = rect.size * 2
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 26)
	var skin := _skin(GADGET_ART, rect, 0, 0, 0)
	skin.content_margin_left = 8
	skin.content_margin_right = right_padding * 2
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, skin)
	button.add_theme_stylebox_override("focus", _focus_skin)
	button.add_theme_color_override("font_hover_color", Color("#a5dae5"))
	return button

func _region(atlas: Texture2D, rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(rect.position * 2, rect.size * 2)
	texture.filter_clip = true
	return texture

func _skin(atlas: Texture2D, rect: Rect2, left: int, right: int, vertical: int) -> StyleBoxTexture:
	var skin := StyleBoxTexture.new()
	skin.texture = _region(atlas, rect)
	skin.texture_margin_left = left * 2
	skin.texture_margin_right = right * 2
	skin.texture_margin_top = vertical * 2
	skin.texture_margin_bottom = vertical * 2
	return skin
