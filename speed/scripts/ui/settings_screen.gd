## 設定（仕様書 3）。音量・演出・画面モード・言語・キー設定。変えるとすぐ反映し、設定のファイルに保存する。
extends UiScreen

const VOLUMES := ["master_volume", "sfx_volume", "engine_volume"]
const WINDOW_MODES := ["windowed", "fullscreen", "exclusive"]

## キーの割り当てを待っているアクション（なければ空）
var _waiting: StringName = &""
var _bind_buttons: Dictionary = {}

func _ready() -> void:
	_build()
	super()

## 言語を変えたら、文章を読み直すために作り直す。
func _build() -> void:
	for c in %Content.get_children():
		%Content.remove_child(c)
		c.queue_free()
	_bind_buttons.clear()
	_section(tr("settings.volume"))
	for key in VOLUMES:
		_slider_row(key, tr("settings." + key))
	var mute := CheckBox.new()
	mute.text = tr("settings.mute")
	mute.button_pressed = bool(SaveManager.settings.muted)
	mute.toggled.connect(func(on): SaveManager.set_setting("muted", on))
	%Content.add_child(mute)
	_section(tr("settings.effects"))
	_slider_row("screen_shake", tr("settings.screen_shake"))
	var hitstop := CheckBox.new()
	hitstop.text = tr("settings.hitstop")
	hitstop.button_pressed = bool(SaveManager.settings.hitstop)
	hitstop.toggled.connect(func(on): SaveManager.set_setting("hitstop", on))
	%Content.add_child(hitstop)
	_section(tr("settings.window_mode"))
	var mode := _options(WINDOW_MODES, SaveManager.settings.window_mode)
	mode.item_selected.connect(func(i): SaveManager.set_setting("window_mode", WINDOW_MODES[i]))
	_section(tr("settings.language"))
	var language := _options(SaveManager.LANGUAGES, SaveManager.settings.language, "language_")
	language.item_selected.connect(_set_language)
	_section(tr("settings.key_bindings"))
	for action in InputActions.REBINDABLE:
		_binding_row(action, tr("action." + action))
	var reset := Button.new()
	reset.text = tr("settings.reset_bindings")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(_reset_bindings)
	%Content.add_child(reset)

## 選択肢の文章は settings.<接頭辞><値>。
func _options(values: Array, current: String, prefix := "") -> OptionButton:
	var b := OptionButton.new()
	b.custom_minimum_size = Vector2(320, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for i in values.size():
		b.add_item(tr("settings." + prefix + values[i]), i)
		if values[i] == current:
			b.select(i)
	%Content.add_child(b)
	return b

func _set_language(i: int) -> void:
	SaveManager.set_setting("language", SaveManager.LANGUAGES[i])
	_build()
	_focus_first()

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
	s.custom_minimum_size = Vector2(360, 32)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(SaveManager.settings[key])
	s.value_changed.connect(func(v): SaveManager.set_setting(key, v))
	row.add_child(s)
	%Content.add_child(row)

func _binding_row(action: StringName, label_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size = Vector2(300, 0)
	label.text = label_text
	row.add_child(label)
	var b := Button.new()
	b.custom_minimum_size = Vector2(220, 44)
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
